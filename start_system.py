"""Print the commands for starting the Dialyse services locally."""

import sys
from pathlib import Path

PYTHON_EXEC = sys.executable
REPO_ROOT = Path(__file__).resolve().parent
DJANGO_ROOT = REPO_ROOT / "app" / "api" / "django"
AI_ROOT = REPO_ROOT / "app" / "api" / "ai"
MQTT_ROOT = REPO_ROOT / "app" / "api" / "mqtt"
WEB_ROOT = REPO_ROOT / "app" / "web"


def print_banner():
    print("=" * 65)
    print("      SYSTÈME PFA-DIALYSE — PROCÉDURE DE DÉMARRAGE RAPIDE")
    print("=" * 65)
    print("\nPour démarrer le système complet, ouvrez 5 terminaux :\n")
    print("TERMINAL 1 — Service IA (qwen_api.py) :")
    print(f"  cd {AI_ROOT} && {PYTHON_EXEC} -m uvicorn qwen_api:app --port 8001 --reload\n")
    print("TERMINAL 2 — API Django :")
    print(f"  cd {DJANGO_ROOT} && {PYTHON_EXEC} manage.py runserver 8000\n")
    print("TERMINAL 3 — Interface Next.js :")
    print(f"  cd {WEB_ROOT} && npm ci && npm run dev\n")
    print("TERMINAL 4 — Receiver MQTT Image → AI → Django :")
    print(f"  cd {MQTT_ROOT} && {PYTHON_EXEC} mqtt_listener.py\n")
    print("TERMINAL 5 — Client Raspberry Pi / Simulateur Edge :")
    print(f"  cd {MQTT_ROOT} && {PYTHON_EXEC} edge_client.py\n")
    print("=" * 65)


if __name__ == "__main__":
    print_banner()
