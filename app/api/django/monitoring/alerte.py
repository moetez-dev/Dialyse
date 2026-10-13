import logging
import requests
from datetime import timedelta
from django.utils import timezone
from django.conf import settings

logger = logging.getLogger(__name__)

SEUILS_DEFAUT = {
    "Debit_sang": {"min": 150, "max": 400, "crit_min": 100, "crit_max": 450, "unite": "mL/min",  "label": "Débit sanguin"},
    "PA":         {"min": 90,  "max": 180, "crit_min": 70,  "crit_max": 200, "unite": "mmHg",    "label": "Pression artérielle"},
    "PV":         {"min": 50,  "max": 250, "crit_min": 30,  "crit_max": 280, "unite": "mmHg",    "label": "Pression veineuse"},
    "PTM":        {"min": -50, "max": 300, "crit_min": -80, "crit_max": 350, "unite": "mmHg",    "label": "Pression transmembranaire"},
    "Taux_UF":    {"min": 0,   "max": 1000,"crit_min": 0,   "crit_max": 1200,"unite": "mL/h",    "label": "Taux UF"},
    "Volume_UF":  {"min": 0,   "max": 4000,"crit_min": 0,   "crit_max": 5000,"unite": "mL",      "label": "Volume UF"},
    "Heparine":   {"min": 0,   "max": 2000,"crit_min": 0,   "crit_max": 2500,"unite": "UI/h",    "label": "Héparine"},
}

COOLDOWN_MINUTES = 15

def dispatch_n8n_critical_risk(alert_obj, measurement, seance):
    """
    Envoie le payload de risque critique au webhook n8n configuré.
    """
    n8n_url = getattr(settings, 'N8N_CRITICAL_RISK_WEBHOOK_URL', 'http://localhost:5678/webhook/dialysis-critical-risk')
    payload = {
        "machine_id": getattr(seance.machine, "machine_id", "M001") if seance.machine else "M001",
        "seance_id": str(seance.id),
        "patient_id": str(seance.patient.id) if seance.patient else None,
        "parameter": alert_obj.alert_type,
        "danger_level": alert_obj.danger_level,
        "message": alert_obj.message,
        "recommended_action": alert_obj.recommended_action,
        "timestamp": alert_obj.timestamp.isoformat() if hasattr(alert_obj, 'timestamp') and alert_obj.timestamp else timezone.now().isoformat(),
        "ready": True,
        "risque_critique": True,
        "measurement": {
            "Qb": measurement.Debit_sang,
            "PA": measurement.PA,
            "PV": measurement.PV,
            "PTM": measurement.PTM,
            "UF_rate": measurement.Taux_UF,
            "UF_volume": measurement.Volume_UF,
            "Heparin": measurement.Heparine,
        }
    }
    
    try:
        response = requests.post(n8n_url, json=payload, timeout=5)
        print(f"[N8N] Webhook dispatched to {n8n_url} | Status {response.status_code}")
    except Exception as e:
        print(f"[N8N] Webhook dispatch warning: {e}")


def analyser_mesure(mesure):
    """
    Analyse une mesure (LiveMeasurement), vérifie les seuils, applique le cooldown 
    de 15 minutes par machine/séance et paramètre, puis persiste les alertes.
    """
    from seances.models import Alert
    from monitoring.models import Alerte

    seance = mesure.seance
    created_alerts = []
    
    if not seance:
        return created_alerts

    # Construire la grille de seuils effective (séance ou défaut)
    seuils = {
        "Debit_sang": {
            "min": getattr(seance, "blood_flow_min", 150),
            "max": getattr(seance, "blood_flow_max", 400),
            "crit_min": getattr(seance, "blood_flow_critical_low", 100),
            "crit_max": getattr(seance, "blood_flow_critical_high", 450),
            "unite": "mL/min", "label": "Débit sanguin"
        },
        "PA": {
            "min": getattr(seance, "arterial_pressure_min", 90),
            "max": getattr(seance, "arterial_pressure_max", 180),
            "crit_min": getattr(seance, "arterial_pressure_critical_low", 70),
            "crit_max": getattr(seance, "arterial_pressure_critical_high", 200),
            "unite": "mmHg", "label": "Pression artérielle"
        },
        "PV": {
            "min": getattr(seance, "venous_pressure_min", 50),
            "max": getattr(seance, "venous_pressure_max", 250),
            "crit_min": getattr(seance, "venous_pressure_critical_low", 30),
            "crit_max": getattr(seance, "venous_pressure_critical_high", 280),
            "unite": "mmHg", "label": "Pression veineuse"
        },
        "PTM": {
            "min": getattr(seance, "tmp_min", -50),
            "max": getattr(seance, "tmp_max", 300),
            "crit_min": getattr(seance, "tmp_critical_low", -80),
            "crit_max": getattr(seance, "tmp_critical_high", 350),
            "unite": "mmHg", "label": "Pression transmembranaire"
        },
        "Taux_UF": {
            "min": getattr(seance, "uf_rate_min", 0),
            "max": getattr(seance, "uf_rate_max", 1000),
            "crit_min": 0,
            "crit_max": getattr(seance, "uf_rate_critical_high", 1200),
            "unite": "mL/h", "label": "Taux UF"
        },
        "Volume_UF": {
            "min": getattr(seance, "uf_volume_min", 0),
            "max": getattr(seance, "uf_volume_max", 4000),
            "crit_min": 0,
            "crit_max": getattr(seance, "uf_volume_critical_high", 5000),
            "unite": "mL", "label": "Volume UF"
        },
        "Heparine": {
            "min": getattr(seance, "heparin_min", 0),
            "max": getattr(seance, "heparin_max", 2000),
            "crit_min": 0,
            "crit_max": getattr(seance, "heparin_critical_high", 2500),
            "unite": "UI/h", "label": "Héparine"
        },
    }

    now = timezone.now()
    cooldown_cutoff = now - timedelta(minutes=COOLDOWN_MINUTES)

    for champ, s in seuils.items():
        valeur = getattr(mesure, champ, None)
        if valeur is None:
            continue

        label  = s["label"]
        unite  = s["unite"]
        niveau = None
        message = None
        action  = None

        # CRITIQUE (HIGH)
        if s["crit_min"] is not None and valeur < s["crit_min"]:
            niveau  = "HIGH"
            message = f"🔴 CRITIQUE — {label} très bas : {valeur} {unite} (seuil critique min: {s['crit_min']} {unite})"
            action  = f"Vérifier immédiatement la ligne et alerter l'équipe soignante pour {label}."
        elif s["crit_max"] is not None and valeur > s["crit_max"]:
            niveau  = "HIGH"
            message = f"🔴 CRITIQUE — {label} très élevé : {valeur} {unite} (seuil critique max: {s['crit_max']} {unite})"
            action  = f"Ajuster d'urgence les paramètres de la machine pour {label}."

        # ATTENTION (MEDIUM)
        elif s["min"] is not None and valeur < s["min"]:
            niveau  = "MEDIUM"
            message = f"🟡 ATTENTION — {label} bas : {valeur} {unite} (min normal: {s['min']} {unite})"
            action  = f"Surveiller {label} et vérifier la consigne machine."
        elif s["max"] is not None and valeur > s["max"]:
            niveau  = "MEDIUM"
            message = f"🟡 ATTENTION — {label} élevé : {valeur} {unite} (max normal: {s['max']} {unite})"
            action  = f"Surveiller {label} et adapter l'ultrafiltration/débit."

        if niveau:
            # Vérifier le Cooldown de 15 minutes sur la séance pour ce paramètre
            recent_alert = Alert.objects.filter(
                seance=seance,
                alert_type=label,
                timestamp__gte=cooldown_cutoff
            ).first()

            if recent_alert:
                print(f"[COOLDOWN] Alert for '{label}' suppressed on session {seance.id} (last alert at {recent_alert.timestamp})")
                continue

            # Créer l'alerte principale (seances.Alert)
            alert_obj = Alert.objects.create(
                seance=seance,
                alert_type=label,
                message=message,
                danger_level=niveau,
                recommended_action=action or "Surveillance clinique requise.",
            )

            # Créer l'alerte miroir (monitoring.Alerte) pour rétrocompatibilité
            try:
                Alerte.objects.create(
                    reading=mesure,
                    niveau="RED" if niveau == "HIGH" else "YELLOW",
                    message=message,
                    status="NEW"
                )
            except Exception as e:
                logger.warning(f"Failed to create mirror Alerte: {e}")

            created_alerts.append(alert_obj)
            print(f"[ALERT CREATED] {niveau} - {label}: {valeur} {unite} | Seance {seance.id}")

            # Déclencher le webhook n8n pour les alertes critiques
            if niveau == "HIGH":
                dispatch_n8n_critical_risk(alert_obj, mesure, seance)

    return created_alerts
