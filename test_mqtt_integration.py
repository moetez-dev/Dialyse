"""
test_mqtt_integration.py
------------------------
Test d'integration du pipeline MQTT, **entierement isole** :

  * broker Mosquitto dedie (conteneur a part, port distinct) ;
  * base SQLite dediee (`DJANGO_DB_PATH`) ;
  * repertoire media dedie (`DJANGO_MEDIA_ROOT`) ;
  * service IA simule par un stub HTTP local (aucune dependance a Ollama) ;
  * patient, machine, seance et mesures **synthetiques**, crees pour le
    test ; aucune donnee existante n'est lue ni modifiee.

Scenarios couverts :
  1. une telemetrie valide est persistee, avec sa provenance ;
  2. une valeur hors seuil cree une alerte, et une seule (cooldown) ;
  3. une charge utile sans valeur exploitable est ignoree ;
  4. une machine inconnue est explicitement rejetee ;
  5. une image illisible (IA indisponible) ne cree aucune mesure
     inventee, et aucune alerte ;
  6. une reponse IA valide est persistee comme releve OCR ;
  7. un message malforme ne fait pas tomber le listener ;
  8. un message publie deux fois ne cree pas de doublon.

Execution (depuis la racine du depot) :

    python test_mqtt_integration.py

Le script orchestre Docker ; la phase de test s'execute dans un conteneur
du reseau Compose, pour que le broker isole soit joignable.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
DJANGO_ROOT = os.path.join(REPO_ROOT, "app", "api", "django")
MQTT_ROOT = os.path.join(REPO_ROOT, "app", "api", "mqtt")
sys.path.insert(0, DJANGO_ROOT)
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "PFA.settings")

BROKER_NAME = "dialyse-it-broker"
TEST_MACHINE = "M-ITEST"
TEST_TOPIC = f"dialysis/machine/{TEST_MACHINE}"


# ==========================================================================
#  Stub du service IA - comportement pilote par AI_STUB_MODE
# ==========================================================================
AI_STUB_MODE = {"value": "unavailable"}


class _AIStubHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):        # silence le journal du stub
        pass

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        mode = AI_STUB_MODE["value"]

        if mode == "unavailable":
            self.send_response(503)
            self.end_headers()
            self.wfile.write(b'{"error": "ollama indisponible"}')
            return

        if mode == "empty":
            payload = {
                "qb": None, "pa": None, "pv": None, "ptm": None,
                "uf_volume": None, "uf_rate": None, "heparin": None,
                "_source": "ollama_fallback", "status": "unavailable",
                "extracted": 0,
            }
        elif mode == "malformed":
            payload = {"qb": "pas un nombre", "pa": None, "pv": None, "ptm": None,
                       "uf_volume": None, "uf_rate": None, "heparin": None,
                       "_source": "qwen_ollama", "status": "ok"}
        else:  # "valid"
            payload = {
                "qb": 260.0, "pa": 120.0, "pv": 129.0, "ptm": 121.0,
                "uf_volume": 1500.0, "uf_rate": 500.0, "heparin": 1000.0,
                "_source": "qwen_ollama", "status": "ok", "extracted": 7,
            }

        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def demarrer_stub_ia():
    """Demarre le service IA simule et retourne son URL."""
    server = HTTPServer(("127.0.0.1", 0), _AIStubHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_port}/analyze/"


# ==========================================================================
#  Phase executee dans le conteneur
# ==========================================================================
def phase_conteneur():
    import django

    django.setup()
    from datetime import date, timedelta

    from django.core.management import call_command
    from django.db import connection
    from django.utils import timezone

    from machines.models import Machine
    from monitoring.models import Alerte, LiveMeasurement
    from patients.models import Patient
    from seances.models import Alert as SeanceAlert
    from seances.models import Seance

    # 1. Schema de la base isolee
    call_command("migrate", verbosity=0, interactive=False)
    # WAL : le lecteur (ce script) ne bloque plus l'ecrivain (le listener),
    # qui ecrit dans la meme base depuis un autre processus.
    with connection.cursor() as curseur:
        curseur.execute("PRAGMA journal_mode=WAL;")
        print("journal_mode de la base isolee :",
              curseur.execute("PRAGMA journal_mode;").fetchone()[0])

    # 2. Enregistrements synthetiques
    patient = Patient.objects.create(
        first_name="ITEST", last_name="Synthese",
        date_of_birth=date(1990, 1, 1), age=40,
        groupe_sanguin="A+", type_de_dialyse="Hemodialyse",
    )
    machine = Machine.objects.create(machine_id=TEST_MACHINE, status="Prete")
    seance = Seance.objects.create(
        patient=patient, machine=machine, status="en cours",
        session_date=timezone.localdate(),
        start_hour=(timezone.localtime() - timedelta(hours=1)).time().replace(second=0, microsecond=0),
        duration=4,
    )
    # Les fixtures sont enregistrees : on relache le verrou d'ecriture avant
    # que le listener (autre processus) n'ecrive dans la meme base.
    connection.close()

    # 3. Stub IA + listener
    server, ai_url = demarrer_stub_ia()
    env = dict(os.environ)
    env["MQTT_BROKER"] = os.environ["MQTT_BROKER"]
    env["MQTT_PORT"] = os.environ.get("MQTT_PORT", "1883")
    env["AI_SERVICE_URL"] = ai_url
    env["DJANGO_DB_PATH"] = os.environ["DJANGO_DB_PATH"]
    env["DJANGO_MEDIA_ROOT"] = os.environ.get("DJANGO_MEDIA_ROOT", "/audit/media")
    env["DJANGO_DB_TIMEOUT"] = "30"
    env["PYTHONUNBUFFERED"] = "1"

    # Journal du listener : sur le système de fichiers DU CONTENEUR. Sur un
    # bind-mount (partage de fichiers Docker Desktop), chaque écriture
    #Costs plusieurs secondes et fausse les mesures de latence.
    log_path = "/tmp/listener.log"
    log = open(log_path, "w", encoding="utf-8")
    listener = subprocess.Popen(
        [sys.executable, "-u", "mqtt_listener.py"],
        cwd=MQTT_ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
    )

    resultats = []
    echecs = []

    def relire(qs):
        """Relit la base apres avoir relache le verrou de lecture.

        La base est partagee avec le listener (autre processus) : une
        connexion ouverte peut rester sur un instantane de lecture
        anterieur aux dernieres ecritures.
        """
        connection.close()
        return list(qs)

    def compte(qs):
        connection.close()
        return qs.count()

    def attendre(condition, delai=25.0):
        """Attend qu'une condition devienne vraie."""
        limite = time.time() + delai
        while time.time() < limite:
            connection.close()
            if condition():
                return True
            time.sleep(0.4)
        connection.close()
        return bool(condition())

    def verifier(nom, condition, detail=""):
        resultats.append((nom, bool(condition), detail))
        if not condition:
            echecs.append(f"{nom}: {detail}")
        marque = "OK  " if condition else "ECHEC"
        print(f"  {marque} {nom}" + (f" -- {detail}" if detail and not condition else ""))

    try:
        import paho.mqtt.client as mqtt

        connecte = threading.Event()

        def on_connect(client, userdata, flags, reason_code, properties=None):
            connecte.set()

        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="audit-integrateur")
        client.on_connect = on_connect
        client.connect(os.environ["MQTT_BROKER"], int(env["MQTT_PORT"]), 30)
        client.loop_start()
        # On attend la confirmation de connexion : publier avant le CONNACK
        # peut faire perdre le message.
        if not connecte.wait(timeout=15):
            verifier("connexion au broker de test", False, "aucun CONNACK")
            raise SystemExit(2)
        time.sleep(1.0)   # laisse le listener s'abonner

        def publier(payload, topic=TEST_TOPIC):
            info = client.publish(topic, json.dumps(payload), qos=1)
            if info.rc != 0:
                raise AssertionError(f"publication refusee (rc={info.rc})")
            time.sleep(0.3)

        def journal_contient(mot):
            try:
                with open(log_path, encoding="utf-8", errors="replace") as f:
                    return mot in f.read()
            except OSError:
                return False

        # Mise en route : on attend que le listener soit abonne au topic
        # avant de publier. Un message publie avant l'abonnement est perdu
        # (session ephemere) : le test ne doit pas dependre de l'ordre de
        # demarrage.
        warmup_deadline = time.time() + 90
        while time.time() < warmup_deadline and not journal_contient("abonnement"):
            time.sleep(0.3)
        verifier("listener abonne au topic", journal_contient("abonnement"),
                 "le listener ne s'est pas abonne en 90 s")
        time.sleep(1.0)

        def mesures():
            return LiveMeasurement.objects.filter(seance=seance)

        def derniere_mesure():
            """La plus recente : le queryset sans tri renvoie la premiere."""
            return relire(mesures().order_by("-timestamp"))[:1]

        def alertes():
            return SeanceAlert.objects.filter(seance=seance)

        # -- 1. Telemetrie valide -------------------------------------
        publier({
            "machine_id": TEST_MACHINE, "Qb": 280, "PA": 120, "PTM": 70,
            "PV": 100, "UF_rate": 400, "UF_volume": 900, "Heparin": 700,
            "_source": "simulation",
        })
        attendre(lambda: compte(mesures()) == 1)
        lot = relire(mesures())
        verifier("telemetrie valide persistee", len(lot) == 1, f"{len(lot)} mesure(s)")
        if lot:
            m = lot[0]
            verifier("provenance de la mesure conservee", m.source == "simulation", str(m.source))
            verifier("valeurs de la mesure correctes", m.Debit_sang == 280, str(m.Debit_sang))
            verifier("statut de validation coherent", m.status_validation == "VALIDATED",
                     str(m.status_validation))

        # -- 2. Depassement de seuil + cooldown ------------------------
        avant_alertes = compte(alertes())
        publier({
            "machine_id": TEST_MACHINE, "Qb": 50, "PA": 120, "PTM": 70,
            "PV": 100, "UF_rate": 400, "UF_volume": 900, "Heparin": 700,
            "_source": "simulation",
        })
        attendre(lambda: compte(alertes()) > avant_alertes)
        creer = compte(alertes()) - avant_alertes
        verifier("alerte creee sur depassement de seuil", creer == 1, f"{creer} alerte(s)")
        publier({
            "machine_id": TEST_MACHINE, "Qb": 45, "PA": 120, "PTM": 70,
            "PV": 100, "UF_rate": 400, "UF_volume": 900, "Heparin": 700,
            "_source": "simulation",
        })
        time.sleep(3.0)
        total = compte(alertes()) - avant_alertes
        verifier("cooldown : pas de doublon d'alerte", total == 1, f"{total} alerte(s)")
        verifier("miroir monitoring.Alerte cree",
                 Alerte.objects.filter(reading__seance=seance).exists())

        # Provenance : une alerte issue d'une mesure simulee ne doit pas etre
        # presentee comme un evenement clinique.
        from monitoring.provenance import est_alerte_clinique, provenance_alerte

        alerte = SeanceAlert.objects.filter(seance=seance).order_by("-id").first()
        if alerte:
            prov_source, prov_simule = provenance_alerte(alerte)
            verifier("alerte simulee marquee dans le message",
                     alerte.message.startswith("\u26a0 SIMULATION"), alerte.message[:40])
            verifier("alerte simulee : source et indicateur exposes",
                     prov_source == "simulation" and prov_simule is True,
                     f"{prov_source}/{prov_simule}")
            verifier("alerte simulee non clinique",
                     est_alerte_clinique(prov_source, prov_simule) is False, "classee clinique")
        else:
            verifier("alerte simulee marquee dans le message", False, "aucune alerte")

        # -- 3. Charge utile sans valeur exploitable -------------------
        avant = compte(mesures())
        publier({"machine_id": TEST_MACHINE, "Qb": None, "PA": None, "_source": "simulation"})
        time.sleep(3.0)
        verifier("charge utile sans valeur ignoree", compte(mesures()) == avant,
                 "une mesure sans valeur a ete enregistree")

        # -- 4. Machine inconnue --------------------------------------
        avant = compte(mesures())
        publier({"machine_id": "M-INCONNUE", "Qb": 300, "PA": 120, "_source": "simulation"})
        time.sleep(3.0)
        verifier("machine inconnue rejetee", compte(mesures()) == avant,
                 "une mesure a ete attribuee a une machine inconnue")
        verifier("aucune machine creee automatiquement",
                 not Machine.objects.filter(machine_id="M-INCONNUE").exists(),
                 "une machine a ete creee automatiquement")

        # -- 5. Image illisible (IA indisponible) ----------------------
        AI_STUB_MODE["value"] = "unavailable"
        avant = compte(mesures())
        avant_alertes = compte(alertes())
        with open(os.path.join(REPO_ROOT, "data", "6.jpeg"), "rb") as f:
            image = f.read()
        client.publish(f"{TEST_TOPIC}/image", image, qos=1)
        attendre(lambda: compte(mesures()) > avant)
        time.sleep(1.0)
        lot = derniere_mesure()
        if lot:
            trace = lot[0]
            verifier("image illisible : aucune mesure a valeurs",
                     trace.Debit_sang is None and trace.PA is None,
                     "une mesure a valeurs a ete creee")
            verifier("tentative illisible tracee sans valeur",
                     trace.status_validation == "AI_UNAVAILABLE" and trace.source == "ai_unavailable",
                     f"{trace.source}/{trace.status_validation}")
        else:
            verifier("image illisible : aucune mesure a valeurs", False, "aucune trace")
        verifier("image illisible : aucune alerte", compte(alertes()) == avant_alertes,
                 "une alerte a ete creee depuis une image illisible")

        # -- 6. Reponse IA valide -> releve OCR ------------------------
        AI_STUB_MODE["value"] = "valid"
        avant = compte(mesures())
        client.publish(f"{TEST_TOPIC}/image", image, qos=1)
        attendre(lambda: compte(mesures()) > avant)
        time.sleep(1.0)
        lot = derniere_mesure()
        ocr = lot[0] if lot else None
        verifier("releve OCR persiste", ocr is not None, "aucun releve OCR")
        if ocr:
            verifier("provenance OCR conservee", ocr.source == "qwen_ollama", str(ocr.source))
            verifier("valeurs OCR correctes", ocr.Debit_sang == 260.0, str(ocr.Debit_sang))

        # -- 7. Message malforme --------------------------------------
        client.publish(TEST_TOPIC, "{ceci n'est pas du json", qos=1)
        time.sleep(2.0)
        verifier("listener toujours vivant apres un message malforme", listener.poll() is None,
                 "le listener s'est arrete")
        client.publish(TEST_TOPIC, json.dumps({
            "machine_id": TEST_MACHINE, "Qb": 275, "PA": 120, "PTM": 70,
            "PV": 100, "UF_rate": 400, "UF_volume": 900, "Heparin": 700,
            "_source": "simulation",
        }), qos=1)
        attendre(lambda: mesure_valeur(mesures(), "Debit_sang", 275))
        verifier("listener toujours operationnel apres un message malforme",
                 mesure_valeur(mesures(), "Debit_sang", 275),
                 "le listener n'a plus traite les messages")

        # -- 8. Pas de doublon -----------------------------------------
        avant = compte(mesures())
        publier({
            "machine_id": TEST_MACHINE, "Qb": 281, "PA": 121, "PTM": 71,
            "PV": 101, "UF_rate": 401, "UF_volume": 901, "Heparin": 701,
            "_source": "simulation",
        })
        attendre(lambda: compte(mesures()) == avant + 1)
        verifier("un message = une mesure", compte(mesures()) == avant + 1,
                 f"{compte(mesures()) - avant} mesure(s)")

        client.loop_stop()
    finally:
        listener.terminate()
        try:
            listener.wait(timeout=10)
        except subprocess.TimeoutExpired:
            listener.kill()
        server.shutdown()
        log.close()

    with open(log_path, encoding="utf-8", errors="replace") as lecteur:
        journal = lecteur.read()
    with open("/audit/listener.log", "w", encoding="utf-8") as sortie:
        sortie.write(journal)

    print("\n--- journal du listener (extrait) ---")
    for ligne in journal.splitlines():
        if any(mot in ligne for mot in ("REJET", "IA INDISPONIBLE", "valeurs exploitables",
                                        "mesure enregistr", "message reçu", "ignoré",
                                        "connecté", "abonnement", "erreur")):
            print("   ", ligne)

    print(f"\n{'=' * 60}")
    print(f"  {len(resultats)} verification(s), {len(echecs)} echec(s)")
    print("=" * 60)
    for echec in echecs:
        print("  ECHEC:", echec)
    return 1 if echecs else 0


def mesure_valeur(qs, champ, valeur):
    """Une mesure du queryset porte-t-elle cette valeur ?"""
    connection = None
    from django.db import connection as _connection
    connection = _connection
    connection.close()
    return any(getattr(m, champ) == valeur for m in qs)


# ==========================================================================
#  Orchestration (executee sur l'hote)
# ==========================================================================
def reseau_compose():
    try:
        out = subprocess.run(
            ["docker", "network", "ls", "--format", "{{.Name}}"],
            capture_output=True, text=True, check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    for nom in out.splitlines():
        if nom.endswith("_default") and "dialyse" in nom.lower():
            return nom
    return None


def orchestrer():
    if "--in-container" in sys.argv:
        return phase_conteneur()

    reseau = reseau_compose()
    if not reseau:
        print("Reseau Docker Compose introuvable : lancez d'abord `docker compose up -d`.")
        return 2

    travail = tempfile.mkdtemp(prefix="dialyse-it-")
    port = "18830"
    code = 1
    try:
        subprocess.run(["docker", "rm", "-f", BROKER_NAME], capture_output=True)
        # Configuration du broker de test : journalisation exhaustive, pour
        # dater les evenements (abonnement, publication, livraison).
        config = os.path.join(travail, "mosquitto.conf")
        with open(config, "w", encoding="utf-8") as f:
            f.write("listener 1883\nallow_anonymous true\nlog_type all\nlog_timestamp true\n")

        demarrage = subprocess.run(
            ["docker", "run", "-d", "--name", BROKER_NAME, "--network", reseau,
             "-p", f"{port}:1883",
             "-v", f"{config}:/mosquitto/config/mosquitto.conf:ro",
             "eclipse-mosquitto:2",
             "mosquitto", "-c", "/mosquitto/config/mosquitto.conf"],
            capture_output=True, text=True,
        )
        if demarrage.returncode != 0:
            print("Broker de test impossible a demarrer :", demarrage.stderr)
            return 2
        print(f"Broker de test isole demarre : {BROKER_NAME} ({reseau}, port {port})")
        time.sleep(2)

        commande = [
            "docker", "run", "--rm", "--network", reseau,
            "-v", f"{REPO_ROOT}:/workspace:ro",
            "-v", f"{travail}:/audit",
            "-w", "/workspace",
            "-e", "DJANGO_DB_PATH=/audit/isolated.sqlite3",
            "-e", "DJANGO_DB_TIMEOUT=30",
            "-e", "DJANGO_MEDIA_ROOT=/audit/media",
            "-e", f"MQTT_BROKER={BROKER_NAME}",
            "-e", "MQTT_PORT=1883",
            "--entrypoint", "python", "dialyse-backend",
            "-u", "test_mqtt_integration.py", "--in-container",
        ]
        code = subprocess.run(commande).returncode
        journal_broker = subprocess.run(
            ["docker", "logs", "--timestamps", BROKER_NAME],
            capture_output=True, text=True,
        )
        lignes_broker = (journal_broker.stdout or "") + (journal_broker.stderr or "")
        if lignes_broker.strip():
            print("\n--- journal du broker de test (debut) ---")
            for ligne in lignes_broker.splitlines()[:34]:
                print("   ", ligne)
    finally:
        subprocess.run(["docker", "rm", "-f", BROKER_NAME], capture_output=True)
        shutil.rmtree(travail, ignore_errors=True)
    return code


if __name__ == "__main__":
    sys.exit(orchestrer())
