"""
mqtt_simulator.py
-----------------
Simulateur MQTT minimal : publie des relevés de dialyse sur
`dialysis/machine/<machine_id>`.

Le broker n'est plus codé en dur (A-02) : `localhost` ne désigne pas le même
broker depuis l'hôte et depuis un conteneur, et un Mosquitto natif sur le
port 1883 captait les publications destinées au broker Docker — sans la
moindre erreur visible. L'adresse effective est affichée au démarrage.

Usage :
  python mqtt_simulator.py
  python mqtt_simulator.py --broker mqtt --port 1883
  python mqtt_simulator.py --machine-id M900 --interval 5
"""

import argparse
import json
import os
import time

BROKER = os.environ.get("MQTT_BROKER", "localhost")
PORT = int(os.environ.get("MQTT_PORT", "1883"))
TOPIC_PREFIX = os.environ.get("MQTT_TOPIC_PREFIX", "dialysis/machine")
MACHINE_ID = os.environ.get("MACHINE_ID_SIM", "M001")
INTERVAL = int(os.environ.get("EDGE_INTERVAL", "3"))

#: Les valeurs publiées sont explicitement synthétiques.
PAYLOAD = {
    "Qb": 280,
    "UF_rate": 500,
    "PA": 220,
    "PTM": 70,
    "PV": 200,
    "UF_volume": 500,
    "Heparin": 5,
    "_source": "simulation",
}


def main():
    global BROKER, PORT, MACHINE_ID, INTERVAL

    parser = argparse.ArgumentParser(description="Simulateur MQTT de dialyse")
    parser.add_argument("--broker", default=None, help="Broker MQTT")
    parser.add_argument("--port", type=int, default=None, help="Port MQTT")
    parser.add_argument("--machine-id", default=None, help="Machine alimentée")
    parser.add_argument("--interval", type=int, default=None, help="Secondes entre deux publications")
    args = parser.parse_args()

    if args.broker:
        BROKER = args.broker
    if args.port:
        PORT = args.port
    if args.machine_id:
        MACHINE_ID = args.machine_id
    if args.interval:
        INTERVAL = args.interval

    import paho.mqtt.client as mqtt

    try:
        # paho >= 2 : l'API de rappel des versions doit être déclarée.
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="dialyse-simulateur")
    except AttributeError:
        client = mqtt.Client(client_id="dialyse-simulateur")
    client.connect(BROKER, PORT, 60)
    client.loop_start()

    topic = f"{TOPIC_PREFIX}/{MACHINE_ID}"
    print(f"MQTT SIMULATOR -> {BROKER}:{PORT} | topic {topic} | interval {INTERVAL}s")

    while True:
        payload = dict(PAYLOAD, machine_id=MACHINE_ID)
        message = json.dumps(payload)
        # QoS 1 + attente de l'acquittement : comme le client edge, un
        # message n'est considéré envoyé que lorsque le broker l'a acquitté.
        info = client.publish(topic, message, qos=1)
        try:
            info.wait_for_publish(timeout=10)
            acquittee = info.is_published()
        except Exception as exc:
            acquittee = False
            print(f"[MQTT] PUBACK absent ({type(exc).__name__})")
        print("MQTT SENT:" + (" (acquitté)" if acquittee else " (non acquitté)"))
        print(message)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
