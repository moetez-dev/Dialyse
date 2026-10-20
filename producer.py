import os
import requests
import time

# ===================== CONFIG =====================
EDGE_API_KEY = os.environ.get('EDGE_API_KEY', 'dev-edge-key-change-me')
EDGE_HEADERS = {'X-Edge-Api-Key': EDGE_API_KEY}
LOCAL_AI_API  = "http://127.0.0.1:8001/analyze/"

DJANGO_API = "http://127.0.0.1:8000/api/push/"
DEBIT_API     = "http://127.0.0.1:8000/api/seance/debit/"
HEARTBEAT_URL = "http://127.0.0.1:8000/machines/raspi/heartbeat/"

RASPI_ID      = "RASPI-02"   # â† identifiant unique de ce Raspi, codÃ© en dur une seule fois
IMAGE_PATH = "frame.jpg"
DEFAULT_DEBIT = 60

# Machine assignÃ©e â€” rÃ©cupÃ©rÃ©e dynamiquement via heartbeat, pas codÃ©e en dur
MACHINE_ID = None


# ===================== HEARTBEAT =====================
def send_heartbeat() -> str | None:
    """
    Signale que ce Raspi est en ligne.
    Retourne le machine_id assignÃ© Ã  ce Raspi, ou None si non assignÃ©.
    """
    try:
        r = requests.post(
            HEARTBEAT_URL,
            json={"raspi_id": RASPI_ID},
            timeout=5
        )
        if r.status_code == 200:
            data       = r.json()
            machine_id = data.get("machine_id")
            is_active  = data.get("is_active", True)

            if not is_active:
                print(f"[HEARTBEAT] Raspi dÃ©sactivÃ© sur le serveur.")
                return None

            if machine_id:
                print(f"[HEARTBEAT] Machine assignÃ©e : {machine_id}")
            else:
                print(f"[HEARTBEAT] Aucune machine assignÃ©e Ã  ce Raspi.")

            return machine_id
        else:
            print(f"[HEARTBEAT] RÃ©ponse inattendue {r.status_code}")
            return None
    except Exception as e:
        print(f"[HEARTBEAT] Erreur rÃ©seau : {e}")
        return None


# ===================== RÃ‰CUPÃ‰RATION DU DÃ‰BIT =====================
def get_debit(machine_id: str) -> int:
    try:
        r = requests.get(
            DEBIT_API,
            params={"machine_id": machine_id},
            headers=EDGE_HEADERS,
            timeout=5
        )
        if r.status_code == 200:
            debit = r.json().get("debit", DEFAULT_DEBIT)
            print(f"[DEBIT] Intervalle reÃ§u : {debit}s")
            return int(debit)
        else:
            print(f"[DEBIT] RÃ©ponse inattendue {r.status_code}, fallback {DEFAULT_DEBIT}s")
            return DEFAULT_DEBIT
    except Exception as e:
        print(f"[DEBIT] Erreur rÃ©seau : {e}, fallback {DEFAULT_DEBIT}s")
        return DEFAULT_DEBIT


# ===================== ANALYSE IMAGE =====================
def analyze_image(image_path: str):
    try:
        with open(image_path, "rb") as f:
            response = requests.post(LOCAL_AI_API, files={"file": f}, timeout=60)

        print("AI Status:", response.status_code)
        print("AI Raw   :", response.text[:500])

        if response.status_code == 200:
            data = response.json()
            print("RÃ©sultat IA:", data)
            return data
        else:
            print("Erreur serveur IA:", response.text)
            return None

    except Exception as e:
        print("Erreur analyse:", e)
        return None


# ===================== ENVOI DJANGO =====================
def send_to_django(values: dict, machine_id: str):
    if not values or "error" in values:
        print("DonnÃ©es invalides, non envoyÃ©es.")
        return

    # machine_id injectÃ© dynamiquement â€” plus codÃ© en dur
    payload = {"machine_id": machine_id, **values}

    try:
        r = requests.post(
            DJANGO_API,
            json=payload,
            headers=EDGE_HEADERS,
            timeout=10,
        )
        print("Django Status:", r.status_code)
    except Exception as e:
        print("Erreur Django:", e)


# ===================== BOUCLE PRINCIPALE =====================
if __name__ == "__main__":
    print(f"DÃ©marrage du client Raspberry Pi [{RASPI_ID}]...")

    while True:
        # 1. Heartbeat â†’ rÃ©cupÃ¨re la machine assignÃ©e dynamiquement
        machine_id = send_heartbeat()

        if not machine_id:
            print("Aucune machine assignÃ©e â€” attente 30s avant de rÃ©essayer...\n")
            time.sleep(30)
            continue

        # 2. RÃ©cupÃ©rer l'intervalle d'envoi configurÃ© pour cette sÃ©ance
        debit = get_debit(machine_id)

        # 3. Capturer et analyser l'image
        ai_values = analyze_image(IMAGE_PATH)
        

        # 4. Envoyer les rÃ©sultats Ã  Django
        if ai_values:
            send_to_django(ai_values, machine_id)

        # 5. Attendre l'intervalle configurÃ©
        print(f"Attente {debit} secondes...\n")
        time.sleep(debit)
