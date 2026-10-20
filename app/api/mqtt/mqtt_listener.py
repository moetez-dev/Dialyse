"""
mqtt_listener.py
----------------
Écoute les messages MQTT (topic dialysis/machine/#)
Traitement automatique :
- Réception d'image JPEG (topic: dialysis/machine/{machine_id}/image)
- Analyse IA / OCR via qwen_api
- Validation des données (monitoring.validation)
- Sauvegarde dans Django (LiveMeasurement + image)
- Détection des alertes avec Cooldown 15 min et notifications n8n
- Support rétrocompatible des payloads JSON telemetry

Règle de provenance (A-09) : **aucune valeur n'est inventée**. Si la source
est illisible (service IA injoignable, OCR sans résultat, image vide), la
mesure n'est pas enregistrée comme mesurée : elle est conservée avec un
statut explicite et des valeurs nulles, et ne déclenche aucune alerte.
"""

import os
import sys
import json
import time
import requests
import base64
from datetime import datetime, timezone

# ===================== Django setup =====================
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
DJANGO_ROOT = os.path.join(REPO_ROOT, "app", "api", "django")
AI_ROOT = os.path.join(REPO_ROOT, "app", "api", "ai")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "PFA.settings")
sys.path.insert(0, DJANGO_ROOT)
sys.path.insert(0, AI_ROOT)
import django
django.setup()

from django.conf import settings
from machines.models import Machine
from seances.models import Seance
from monitoring.models import LiveMeasurement
from monitoring.validation import PHYSICAL_LIMITS, validate_dialysis_data
from monitoring.alerte import analyser_mesure
from monitoring.provenance import (
    SOURCE_AI_OCR,
    SOURCE_AI_UNAVAILABLE,
    SOURCE_TELEMETRY,
    VALIDATION_AI_UNAVAILABLE,
    VALIDATION_INVALID,
    describe_source,
    has_usable_values,
    is_simulated,
    normalise_source_declaree,
)

# ===================== Config =====================
# Le broker est configurable : `localhost` ne désigne pas le même broker
# depuis l'hôte et depuis un conteneur (A-02). Sans variable explicite, on
# suppose le broker local, mais l'adresse effective est affichée au démarrage
# afin qu'une erreur de routage soit visible dans les journaux.
MQTT_BROKER = os.environ.get("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_TOPIC = os.environ.get("MQTT_TOPIC", "dialysis/machine/#")
MQTT_CLIENT_ID = os.environ.get("MQTT_CLIENT_ID", "django-mqtt-listener")
AI_SERVICE_URL = os.environ.get("AI_SERVICE_URL", "http://127.0.0.1:8001/analyze/")
AI_TIMEOUT = int(os.environ.get("AI_TIMEOUT", "10"))

# Ensure media upload directory exists
MEDIA_MACHINE_DIR = os.path.join(settings.MEDIA_ROOT, "machine_images")
os.makedirs(MEDIA_MACHINE_DIR, exist_ok=True)


def log(message):
    """Journalisation horodatée (stdout non tamponné dans les conteneurs)."""
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[MQTT {stamp}] {message}", flush=True)


def _resolve_machine(machine_id):
    """Retourne la machine connue, ou None si elle n'existe pas.

    Le modèle `Machine` n'a pas de champ `nom` : la création automatique
    échouait sur `TypeError` et la mesure était perdue de toute façon
    (A-10). On n'invente pas de générateur : une machine inconnue est
    explicitement rejetée, et le rejet est journalisé.
    """
    machine = Machine.objects.filter(machine_id=machine_id).first()
    if machine is None:
        log(f"[REJET] machine inconnue « {machine_id} » : mesure ignorée "
            f"(aucune inscription automatique)")
        return None
    return machine


def _find_active_session(machine):
    """Séance en cours rattachée à la machine, ou None."""
    return Seance.objects.filter(machine=machine, status="en cours").first()


def _call_ai_service(image_bytes, filename):
    """Interroge le service IA.

    Retourne (donnees, source, erreur). `donnees` est None quand la source
    n'a pas pu être lue : aucune valeur de remplacement n'est produite.
    """
    try:
        response = requests.post(
            AI_SERVICE_URL,
            files={"file": (filename, image_bytes, "image/jpeg")},
            timeout=AI_TIMEOUT,
        )
    except Exception as exc:
        return None, SOURCE_AI_UNAVAILABLE, f"service IA injoignable ({type(exc).__name__})"

    if response.status_code != 200:
        return None, SOURCE_AI_UNAVAILABLE, f"service IA : HTTP {response.status_code}"

    try:
        payload = response.json()
    except ValueError:
        return None, SOURCE_AI_UNAVAILABLE, "réponse du service IA illisible (JSON invalide)"

    if not isinstance(payload, dict):
        return None, SOURCE_AI_UNAVAILABLE, "réponse du service IA inattendue"

    source = payload.get("_source") or SOURCE_AI_OCR
    # Une réponse IA n'est exploitable que si elle porte au moins une
    # VALEUR de mesure. Ses métadonnées (`status`, `extracted`, `model`)
    # ne sont pas des relevés : sans ce filtre, le repli du service IA
    # (toutes valeurs nulles) passerait pour une lecture exploitable.
    valeurs_lues = {cle: payload.get(cle) for cle in PHYSICAL_LIMITS}
    if not has_usable_values(valeurs_lues):
        return None, source, "aucune valeur lisible dans la réponse du service IA"
    return payload, source, None


def process_and_save_image(machine_id: str, image_bytes: bytes) -> bool:
    """
    Pipeline complet : Image -> IA -> Validation -> DB -> Alertes -> Dashboard

    Retourne True seulement si une mesure exploitable a été enregistrée.
    """
    log(f"image reçue pour la machine {machine_id} ({len(image_bytes)} octets)")

    # 1. Conserver l'image source (provenance de la tentative de lecture)
    filename = f"frame_{machine_id}_{int(time.time())}.jpg"
    rel_path = f"machine_images/{filename}"
    full_path = os.path.join(settings.MEDIA_ROOT, rel_path)

    with open(full_path, "wb") as f:
        f.write(image_bytes)
    log(f"image conservée -> {rel_path}")

    # 2. Lire l'image par le service IA
    log(f"analyse IA en cours pour {machine_id}...")
    ai_raw_data, ai_source, ai_error = _call_ai_service(image_bytes, filename)

    if ai_error:
        # Échec de lecture : on enregistre la tentative, pas une mesure.
        log(f"[IA INDISPONIBLE] {ai_error} : aucune mesure enregistrée")
        return _record_unreadable_source(machine_id, rel_path, ai_source, ai_error)

    # 3. Validation des données
    val_result = validate_dialysis_data(ai_raw_data)
    validated_data = val_result["validated_data"]
    status_val = val_result["status"]
    log(f"validation : statut={status_val} erreurs={val_result['errors']}")

    if not has_usable_values(validated_data):
        log("[IA] aucune valeur exploitable après validation : aucune mesure enregistrée")
        return _record_unreadable_source(
            machine_id, rel_path, ai_source, "aucune valeur valide après contrôle physique"
        )

    # 4. Machine et séance en cours
    machine = _resolve_machine(machine_id)
    if machine is None:
        return False

    seance = _find_active_session(machine)
    if not seance:
        # Ne pas rattacher l'image et ses valeurs à une séance déjà close.
        log(f"aucune séance en cours sur {machine_id} : image ignorée")
        return False

    # 5. Persistance dans Django (LiveMeasurement)
    measurement = LiveMeasurement.objects.create(
        seance=seance,
        Debit_sang=validated_data.get("qb"),
        PA=validated_data.get("pa"),
        PV=validated_data.get("pv"),
        PTM=validated_data.get("ptm"),
        Volume_UF=validated_data.get("uf_volume"),
        Taux_UF=validated_data.get("uf_rate"),
        Heparine=validated_data.get("heparin"),
        image=rel_path,
        source=ai_source,
        status_validation=status_val,
    )
    log(f"mesure enregistrée {measurement.id} | machine={machine_id} | séance={seance.id} "
        f"| source={describe_source(ai_source)}")

    # 6. Détection des alertes et vérification du cooldown 15 min
    log("contrôle des seuils et du cooldown...")
    alerts = analyser_mesure(measurement)
    if alerts:
        log(f"{len(alerts)} alerte(s) créée(s).")

    log(f"données disponibles pour la machine {machine_id}")
    return True


def _record_unreadable_source(machine_id, rel_path, source, reason):
    """Conserve la trace d'une source illisible, sans inventer de mesure.

    La ligne enregistrée ne porte aucune valeur : elle documente qu'une
    image a été reçue et n'a pas pu être lue. Elle ne déclenche aucune
    alerte, et le tableau de bord n'affiche pas de « dernière mesure »
    à partir d'une ligne sans valeur.
    """
    machine = _resolve_machine(machine_id)
    if machine is None:
        return False

    seance = _find_active_session(machine)
    if not seance:
        log(f"aucune séance en cours sur {machine_id} : tentative d'ignorée")
        return False

    measurement = LiveMeasurement.objects.create(
        seance=seance,
        image=rel_path,
        source=SOURCE_AI_UNAVAILABLE,
        status_validation=VALIDATION_AI_UNAVAILABLE,
    )
    log(f"tentative non lisible enregistrée {measurement.id} | raison : {reason} "
        f"| aucune valeur, aucune alerte")
    return False


def save_telemetry_measurement(data: dict) -> bool:
    """
    Traitement d'un payload JSON telemetry standard.
    """
    try:
        machine_id = data.get("machine_id", "M001")
        log(f"message reçu ({machine_id})")
        val_result = validate_dialysis_data(data)
        validated_data = val_result["validated_data"]
        status_val = val_result["status"]
        # La source déclarée par l'expéditeur est assainie : une origine
        # inconnue n'est jamais présentée comme un relevé de générateur.
        source, _declaree = normalise_source_declaree(
            data.get("_source"), defaut=SOURCE_TELEMETRY
        )

        if not has_usable_values(validated_data):
            log(f"payload sans valeur exploitable ({machine_id}) : mesure ignorée")
            return False

        machine = _resolve_machine(machine_id)
        if machine is None:
            return False

        seance = _find_active_session(machine)
        if not seance:
            # Même correctif que l'API : ne jamais rattacher une mesure à une
            # séance terminée ou annulée, cela corrompt son historique et son
            # rapport. La mesure est écartée, et on le dit.
            log(f"aucune séance en cours sur {machine_id} : mesure ignorée")
            return False

        measurement = LiveMeasurement.objects.create(
            seance=seance,
            Debit_sang=validated_data.get("qb"),
            PA=validated_data.get("pa"),
            PV=validated_data.get("pv"),
            PTM=validated_data.get("ptm"),
            Volume_UF=validated_data.get("uf_volume"),
            Taux_UF=validated_data.get("uf_rate"),
            Heparine=validated_data.get("heparin"),
            source=source,
            status_validation=status_val,
        )

        analyser_mesure(measurement)
        log(f"mesure enregistrée {measurement.id} pour la machine {machine_id} "
            f"| source={describe_source(source, status_val)}")
        return True
    except Exception as e:
        log(f"erreur save_telemetry_measurement : {type(e).__name__}: {e}")
        return False


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0 or str(reason_code) == "Success":
        log(f"connecté au broker {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(MQTT_TOPIC)
        log(f"abonnement -> {MQTT_TOPIC}")
    else:
        log(f"ÉCHEC de connexion au broker {MQTT_BROKER}:{MQTT_PORT} : {reason_code}")


def on_disconnect(client, userdata, disconnect_flags, reason_code=None, properties=None):
    log(f"déconnexion du broker {MQTT_BROKER}:{MQTT_PORT} ({reason_code})")


def on_message(client, userdata, msg):
    try:
        topic_parts = msg.topic.split("/")
        # format: dialysis/machine/{machine_id}/image OU dialysis/machine/{machine_id}
        machine_id = "M001"
        if len(topic_parts) >= 3:
            machine_id = topic_parts[2]

        is_image_topic = (len(topic_parts) >= 4 and topic_parts[3] == "image") or msg.topic.endswith("/image")

        # Cas 1: Image binaire JPEG reçue
        if is_image_topic:
            process_and_save_image(machine_id, msg.payload)
            return

        # Cas 2: Payload JSON
        try:
            payload_str = msg.payload.decode("utf-8")
            data = json.loads(payload_str)

            # Si le JSON contient une image base64 dans le champ 'image_b64'
            if "image_b64" in data:
                img_bytes = base64.b64decode(data["image_b64"])
                process_and_save_image(machine_id, img_bytes)
            else:
                save_telemetry_measurement(data)
        except UnicodeDecodeError:
            # Traiter comme une image binaire si le décodage utf-8 échoue
            process_and_save_image(machine_id, msg.payload)

    except Exception as e:
        log(f"erreur on_message : {type(e).__name__}: {e}")


def main():
    try:
        import paho.mqtt.client as mqtt
    except ImportError:
        print("Installer paho-mqtt : pip install paho-mqtt", flush=True)
        sys.exit(1)

    try:
        # Session persistante (clean_session=False) : le broker met les
        # messages en file pendant un redémarrage du listener et les livre
        # à la reconnexion. Avec une session éphémère, les relevés publiés
        # pendant les quelques secondes de démarrage du listener étaient
        # perdus — et, sur une séance de dialyse, une mesure perdue est une
        # mesure absente du dossier.
        client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2,
            client_id=MQTT_CLIENT_ID,
            clean_session=False,
        )
    except AttributeError:
        client = mqtt.Client(client_id=MQTT_CLIENT_ID, clean_session=False)

    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect

    print("=" * 60, flush=True)
    print("  MQTT Listener for PFA-Dialyse", flush=True)
    print(f"  Broker   : {MQTT_BROKER}:{MQTT_PORT}", flush=True)
    print(f"  Topic    : {MQTT_TOPIC}", flush=True)
    print(f"  AI Server: {AI_SERVICE_URL}", flush=True)
    print("=" * 60, flush=True)

    while True:
        try:
            client.connect(MQTT_BROKER, MQTT_PORT, 60)
            client.loop_forever()
        except Exception as e:
            log(f"connexion perdue ({type(e).__name__}: {e}) -> nouvelle tentative dans 5 s")
            time.sleep(5)


if __name__ == "__main__":
    main()
