"""
monitoring/validation.py
------------------------
Couche centralisée de validation des données extraites par le modèle IA/OCR.
Vérifie la conformité des types, des bornes physiques, des PA/PV et préserve les null.
"""

import logging

logger = logging.getLogger(__name__)

PHYSICAL_LIMITS = {
    "qb":        {"min": 0,    "max": 600,   "unit": "mL/min"},
    "pa":        {"min": -400, "max": 300,   "unit": "mmHg"},
    "pv":        {"min": -50,  "max": 400,   "unit": "mmHg"},
    "ptm":       {"min": -150, "max": 500,   "unit": "mmHg"},
    "uf_volume": {"min": 0,    "max": 10000, "unit": "mL"},
    "uf_rate":   {"min": 0,    "max": 3000,  "unit": "mL/h"},
    "heparin":   {"min": 0,    "max": 5000,  "unit": "UI/h"},
}

def validate_dialysis_data(data: dict) -> dict:
    """
    Valide et nettoie les paramètres extraits de la machine de dialyse.
    
    Retourne un dictionnaire enrichi avec:
      - 'validated_data': dict avec les valeurs validées (ou None)
      - 'status': 'VALIDATED' | 'UNCERTAIN' | 'INVALID'
      - 'errors': list d'avertissements/erreurs
    """
    errors = []
    validated_data = {}
    is_uncertain = False
    
    # 1. Vérification des clés principales
    for key, bounds in PHYSICAL_LIMITS.items():
        # Accepter aussi les noms en majuscules (Qb, PA, etc.)
        val = data.get(key)
        if val is None:
            # Chercher dans les équivalents
            alt_key_map = {
                "qb": ["Qb", "Debit_sang"],
                "pa": ["PA"],
                "pv": ["PV"],
                "ptm": ["PTM"],
                "uf_volume": ["UF_volume", "Volume_UF"],
                "uf_rate": ["UF_rate", "Taux_UF"],
                "heparin": ["Heparin", "Heparine"]
            }
            for alt in alt_key_map.get(key, []):
                if alt in data and data[alt] is not None:
                    val = data[alt]
                    break

        if val is None:
            validated_data[key] = None
            continue
            
        # Conversion numérique
        try:
            val_float = float(val)
        except (ValueError, TypeError):
            errors.append(f"Valeur non numérique rejetée pour {key}: '{val}'")
            validated_data[key] = None
            is_uncertain = True
            continue
            
        # Vérification des bornes physiques
        if val_float < bounds["min"] or val_float > bounds["max"]:
            errors.append(
                f"Valeur aberrante pour {key}: {val_float} {bounds['unit']} "
                f"(bornes autorisées: [{bounds['min']}, {bounds['max']}])"
            )
            validated_data[key] = None
            is_uncertain = True
        else:
            validated_data[key] = val_float

    # 2. Contrôle de non-inversion PA et PV
    # Si PA est nettement positif et PV nettement négatif, suspecter une inversion
    pa_val = validated_data.get("pa")
    pv_val = validated_data.get("pv")
    if pa_val is not None and pv_val is not None:
        if pa_val > 100 and pv_val < 0:
            errors.append("Inversion probable détectée entre PA et PV — réinitialisées à None")
            validated_data["pa"] = None
            validated_data["pv"] = None
            is_uncertain = True

    # Déterminer le statut global
    valid_count = sum(1 for v in validated_data.values() if v is not None)
    if valid_count == 0:
        status = "INVALID"
    elif is_uncertain or errors:
        status = "UNCERTAIN"
    else:
        status = "VALIDATED"

    return {
        "validated_data": validated_data,
        "status": status,
        "errors": errors,
    }
