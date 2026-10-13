"""
seances/services.py
-------------------
Service de génération automatique du résumé de séance et du rapport de séance (HTML & RapportSeance DB).
"""

import json
import logging
import requests
from django.template.loader import render_to_string
from django.utils import timezone
from seances.models import Seance, RapportSeance
from monitoring.models import LiveMeasurement

logger = logging.getLogger(__name__)


def generate_session_summary_and_report(seance_id):
    """
    Calcule les statistiques de la séance, invoque l'IA pour générer le résumé,
    et enregistre/met à jour le modèle RapportSeance.
    """
    seance = Seance.objects.select_related("patient", "machine").get(id=seance_id)
    readings = LiveMeasurement.objects.filter(seance=seance).order_by("timestamp")
    alerts = seance.alerts.all().order_by("timestamp")

    readings_count = readings.count()
    nb_alertes = alerts.count()
    nb_critiques = alerts.filter(danger_level="HIGH").count()

    # Calcul des min, max, moyennes
    def calc_stats(field):
        vals = [getattr(r, field) for r in readings if getattr(r, field) is not None]
        if not vals:
            return {"min": None, "max": None, "avg": None}
        return {
            "min": round(min(vals), 1),
            "max": round(max(vals), 1),
            "avg": round(sum(vals) / len(vals), 1),
        }

    stats = {
        "qb": calc_stats("Debit_sang"),
        "pa": calc_stats("PA"),
        "pv": calc_stats("PV"),
        "ptm": calc_stats("PTM"),
        "uf_rate": calc_stats("Taux_UF"),
        "uf_volume": calc_stats("Volume_UF"),
        "heparin": calc_stats("Heparine"),
    }

    # Prompt LLM pour le résumé de séance
    prompt = f"""
Vous êtes un assistant IA médical spécialisé en hémodialyse.
Analyse les données de la séance du patient {seance.patient.first_name} {seance.patient.last_name}:
- Durée: {seance.duration}h
- Mesures enregistrées: {readings_count}
- Alertes: {nb_alertes} (dont {nb_critiques} critiques)
- Stats: Qb moyen={stats['qb']['avg']} mL/min, PA moyenne={stats['pa']['avg']} mmHg, PV moyenne={stats['pv']['avg']} mmHg, PTM moyenne={stats['ptm']['avg']} mmHg.

Retournez UNIQUEMENT un JSON valide avec ce format exact:
{{
  "resume_court": "synthèse concise de 2 phrases",
  "qualite_seance": "normale" ou "difficile",
  "points_attention": ["point 1", "point 2"],
  "resume_complet": "analyse médicale détaillée"
}}
"""

    summary_ai = None
    try:
        res = requests.post(
            "http://127.0.0.1:11434/api/generate",
            json={"model": "qwen2.5:3b", "prompt": prompt, "stream": False, "format": "json"},
            timeout=10
        )
        if res.status_code == 200:
            resp_data = res.json().get("response", "")
            summary_ai = json.loads(resp_data)
    except Exception as e:
        logger.warning(f"Ollama call for session summary failed/timed out: {e}")

    # Fallback si l'IA n'a pas répondu
    if not summary_ai or not isinstance(summary_ai, dict) or "resume_court" not in summary_ai:
        qualite_default = "difficile" if nb_critiques > 0 else "normale"
        attention_points = [a.message for a in alerts[:5]]
        if not attention_points:
            attention_points = ["Paramètres stables durant toute la séance."]

        summary_ai = {
            "resume_court": f"Séance d'hémodialyse de {seance.duration}h réalisée le {seance.session_date}. {readings_count} mesures enregistrées avec {nb_alertes} alerte(s).",
            "qualite_seance": qualite_default,
            "points_attention": attention_points,
            "resume_complet": f"La séance s'est déroulée avec un débit sanguin moyen de {stats['qb']['avg'] or 0} mL/min, une pression artérielle moyenne de {stats['pa']['avg'] or 0} mmHg et une PTM moyenne de {stats['ptm']['avg'] or 0} mmHg. {nb_alertes} évènement(s) ont été notés.",
        }

    qualite_final = str(summary_ai.get("qualite_seance", "normale")).lower()
    if qualite_final not in ["normale", "difficile"]:
        qualite_final = "difficile" if nb_critiques > 0 else "normale"

    # Pré-séance et Post-séance
    pre = getattr(seance, "pre_measurements", None)
    post = getattr(seance, "post_measurements", None)

    chart_data = []
    for r in readings:
        chart_data.append({
            "time": r.timestamp.strftime("%H:%M") if r.timestamp else "",
            "qb": r.Debit_sang,
            "pa": r.PA,
            "pv": r.PV,
            "ptm": r.PTM,
            "uf_rate": r.Taux_UF,
            "uf_volume": r.Volume_UF,
            "heparin": r.Heparine,
        })

    alerts_list = [
        {
            "message": a.message,
            "danger_level": a.danger_level,
            "timestamp": a.timestamp.strftime("%H:%M") if a.timestamp else "",
        }
        for a in alerts
    ]

    context = {
        "seance": seance,
        "patient": seance.patient,
        "machine": seance.machine,
        "pre": pre,
        "post": post,
        "chart_data": json.dumps(chart_data),
        "alerts_json": json.dumps(alerts_list),
        "readings_count": readings_count,
        "nb_alertes": nb_alertes,
        "nb_critiques": nb_critiques,
        "qualite": qualite_final,
        "summary_ai": summary_ai,
        "stats": stats,
    }

    html_content = render_to_string("rapport_seance.html", context)
    filename = f"seance_{seance.session_date}_{seance.patient.last_name}.html"

    rapport, _ = RapportSeance.objects.update_or_create(
        seance=seance,
        defaults={
            "nom_fichier": filename,
            "contenu_html": html_content,
            "qualite_seance": qualite_final,
        },
    )

    print(f"[REPORT GENERATED] RapportSeance {rapport.id} saved for Seance {seance.id}")

    return {
        "summary": summary_ai,
        "stats": stats,
        "rapport_id": str(rapport.id),
        "filename": filename,
    }
