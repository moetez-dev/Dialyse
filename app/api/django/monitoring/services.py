"""
monitoring/services.py
-----------------------
Service d'analyse des seuils et des alertes.
"""

from monitoring.alerte import analyser_mesure

def check_thresholds(reading):
    """
    Délègue l'analyse à la fonction centrale analyser_mesure()
    pour bénéficier de la gestion des seuils de séance et du cooldown de 15 min.
    """
    alerts = analyser_mesure(reading)
    return [(a.danger_level, a.message) for a in alerts]