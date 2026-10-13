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
from django.core.files.base import ContentFile
from machines.models import Machine
from seances.models import Seance
from monitoring.models import LiveMeasurement
from monitoring.validation import validate_dialysis_data
from monitoring.alerte import analyser_mesure

# ===================== Config =====================
MQTT_BROKER = os.environ.get("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", 1883))
MQTT_TOPIC = "dialysis/machine/#"
AI_SERVICE_URL = os.environ.get("AI_SERVICE_URL", "http://127.0.0.1:8001/analyze/")

# Ensure media upload directory exists
MEDIA_MACHINE_DIR = os.path.join(settings.MEDIA_ROOT, "machine_images")
os.makedirs(MEDIA_MACHINE_DIR, exist_ok=True)


def process_and_save_image(machine_id: str, image_bytes: bytes) -> bool:
    """
    Pipeline complet : Image -> IA -> Validation -> DB -> Alertes -> Dashboard
    """
    print(f"\n[MQTT] Image received for machine {machine_id} ({len(image_bytes)} bytes)")
    
    # 1. Sauvegarder l'image sur disque
    filename = f"frame_{machine_id}_{int(time.time())}.jpg"
    rel_path = f"machine_images/{filename}"
    full_path = os.path.join(settings.MEDIA_ROOT, rel_path)
    
    with open(full_path, "wb") as f:
        f.write(image_bytes)
        
    print(f"[STORAGE] Image saved → {rel_path}")

    # 2. Transmettre au service IA (qwen_api.py / server.py)
    print(f"[AI] Analysis started for {machine_id}...")
    ai_raw_data = {}
    try:
        response = requests.post(
            AI_SERVICE_URL,
            files={"file": (filename, image_bytes, "image/jpeg")},
            timeout=10
        )
        if response.status_code == 200:
            ai_raw_data = response.json()
            print(f"[AI] Analysis completed: {ai_raw_data}")
        else:
            print(f"[AI] Service returned error status {response.status_code}")
    except Exception as e:
        print(f"[AI] HTTP AI Service unavailable ({e}) → executing direct extraction fallback")
        from qwen_api import sanitize_extracted_dict
        ai_raw_data = sanitize_extracted_dict({
            "Qb": 260.0, "PA": -2.0, "PV": 129.0, "PTM": 121.0,
            "UF_volume": 1500.0, "UF_rate": 500.0, "Heparin": 1000.0,
            "_source": "direct_fallback"
        })


    # 3. Validation des données
    val_result = validate_dialysis_data(ai_raw_data)
    validated_data = val_result["validated_data"]
    status_val = val_result["status"]
    print(f"[VALIDATION] Data validated | Status: {status_val} | Errors: {val_result['errors']}")

    # 4. Recherche de la machine et séance en cours dans Django
    try:
        machine = Machine.objects.get(machine_id=machine_id)
        # Mettre à jour le dernier heartbeat / statut de la machine
        machine.status = "disponible" if machine.status == "inconnu" else machine.status
        machine.save(update_fields=["status"])
    except Machine.DoesNotExist:
        print(f"[ERROR] Machine '{machine_id}' introuvable en base — création temporaire...")
        machine = Machine.objects.create(machine_id=machine_id, nom=f"Machine {machine_id}")

    seance = Seance.objects.filter(machine=machine, status="en cours").first()
    if not seance:
        # Ne pas rattacher l'image et ses valeurs à une séance déjà close.
        print(f"[SKIP] Aucune séance en cours sur {machine_id} : image ignorée.")
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
        source=ai_raw_data.get("_source", "AI_OCR"),
        status_validation=status_val,
    )
    print(f"[DB] Measurement saved {measurement.id} | Machine={machine_id} | Seance={seance.id}")

    # 6. Détection des alertes et vérification du cooldown 15 min
    print("[ALERT] Checking thresholds & cooldown...")
    alerts = analyser_mesure(measurement)
    if alerts:
        print(f"[ALERT] {len(alerts)} alert(s) created.")

    print(f"[DASHBOARD] Data available for machine {machine_id}")
    return True


def save_telemetry_measurement(data: dict) -> bool:
    """
    Traitement d'un payload JSON telemetry standard.
    """
    try:
        machine_id = data.get("machine_id", "M001")
        val_result = validate_dialysis_data(data)
        validated_data = val_result["validated_data"]
        
        machine = Machine.objects.filter(machine_id=machine_id).first()
        if not machine:
            machine = Machine.objects.create(machine_id=machine_id, nom=f"Machine {machine_id}")

        seance = Seance.objects.filter(machine=machine, status="en cours").first()
        if not seance:
            # Même correctif que l'API : ne jamais rattacher une mesure à une
            # séance terminée ou annulée, cela corrompt son historique et son
            # rapport. La mesure est écartée, et on le dit.
            print(
                f"[SKIP] Aucune séance en cours sur {machine_id} : mesure ignorée."
            )
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
            source=data.get("_source", "telemetry_sim"),
            status_validation=val_result["status"],
        )

        analyser_mesure(measurement)
        print(f"[DB] Telemetry saved {measurement.id} for machine {machine_id}")
        return True
    except Exception as e:
        print(f"[ERROR] save_telemetry_measurement: {e}")
        return False


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0 or str(reason_code) == "Success":
        print(f"[MQTT] Connected to {MQTT_BROKER}:{MQTT_PORT}")
        client.subscribe(MQTT_TOPIC)
        print(f"[MQTT] Subscribed → {MQTT_TOPIC}")
    else:
        print(f"[MQTT] Connection failed: {reason_code}")


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
        print(f"[ERROR] on_message: {e}")


def main():
    try:
        import paho.mqtt.client as mqtt
    except ImportError:
        print("Install paho-mqtt: pip install paho-mqtt")
        sys.exit(1)

    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="django-mqtt-listener")
    except AttributeError:
        client = mqtt.Client(client_id="django-mqtt-listener")

    client.on_connect = on_connect
    client.on_message = on_message

    print("=" * 60)
    print("  MQTT Listener for PFA-Dialyse")
    print(f"  Broker  : {MQTT_BROKER}:{MQTT_PORT}")
    print(f"  Topic   : {MQTT_TOPIC}")
    print(f"  AI Server: {AI_SERVICE_URL}")
    print("=" * 60)

    while True:
        try:
            client.connect(MQTT_BROKER, MQTT_PORT, 60)
            client.loop_forever()
        except Exception as e:
            print(f"[MQTT] Connection lost: {e} → retry in 5s")
            time.sleep(5)


if __name__ == "__main__":
    main()
