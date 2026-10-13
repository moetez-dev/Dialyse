"""
test_e2e_pipeline.py
--------------------
Suite de tests End-to-End pour le système PFA-Dialyse.
Teste le pipeline complet:
  IMAGE -> AI/OCR -> VALIDATION -> DJANGO DB -> ALERTS & COOLDOWN -> N8N -> SUMMARY & REPORT
"""

import os
import sys
import json
import time
from datetime import datetime, timezone

sys.stdout.reconfigure(encoding='utf-8')

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
DJANGO_ROOT = os.path.join(REPO_ROOT, "app", "api", "django")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "PFA.settings")
sys.path.insert(0, DJANGO_ROOT)
import django
django.setup()

from machines.models import Machine
from patients.models import Patient
from seances.models import Seance, Alert, RapportSeance
from monitoring.models import LiveMeasurement, Alerte
from monitoring.validation import validate_dialysis_data
from monitoring.alerte import analyser_mesure
from seances.services import generate_session_summary_and_report


def run_tests():
    print("=" * 60)
    print("  LANCEMENT DU TEST END-TO-END PFA-DIALYSE")
    print("=" * 60)

    # 1. Préparation des données de test (Patient & Machine & Séance)
    print("\n[TEST 1] Initialisation du Patient, Machine et Séance de test...")
    patient = Patient.objects.first()
    if not patient:
        patient = Patient.objects.create(
            first_name="Mohamed",
            last_name="Ben Ali",
            date_of_birth="1980-05-15",
            age=44,
            telephone="98765432",
            groupe_sanguin="O+",
        )

    machine = Machine.objects.filter(machine_id="M001").first()
    if not machine:
        machine = Machine.objects.create(
            machine_id="M001",
            nom="Dialyse-M001",
            status="en cours",
            location="Salle A"
        )

    seance = Seance.objects.filter(patient=patient, machine=machine).first()
    if not seance:
        seance = Seance.objects.create(
            patient=patient,
            machine=machine,
            status="en cours",
            session_date=datetime.now(timezone.utc).date(),
            start_hour="08:00:00",
            duration=4,
            arterial_pressure_min=90.0,
            arterial_pressure_max=180.0,
            tmp_max=250.0,
            tmp_critical_high=300.0,
        )
    else:
        seance.status = "en cours"
        seance.save()

    # Nettoyer les anciennes alertes de test pour isoler les mesures
    Alert.objects.filter(seance=seance).delete()
    LiveMeasurement.objects.filter(seance=seance).delete()

    print(f"-> Patient: {patient} | Machine: {machine.machine_id} | Seance ID: {seance.id}")

    # 2. Test du module de validation
    print("\n[TEST 2] Test du module de validation (monitoring/validation.py)...")
    raw_ai_sample = {
        "Qb": 260.0,
        "PA": 120.0,
        "PV": 129.0,
        "PTM": 320.0,  # Dépasse 300 -> alerte critique
        "UF_volume": 1500.0,
        "UF_rate": 500.0,
        "Heparin": 1000.0,
    }
    val_res = validate_dialysis_data(raw_ai_sample)
    print(f"-> Validation result status: {val_res['status']}")
    assert val_res["status"] in ["VALIDATED", "UNCERTAIN"]
    assert val_res["validated_data"]["qb"] == 260.0
    assert val_res["validated_data"]["pa"] == 120.0

    # Test d'inversion PA/PV
    inverted_sample = {"Qb": 260, "PA": 150.0, "PV": -30.0}
    val_inv = validate_dialysis_data(inverted_sample)
    print(f"-> Test inversion PA/PV: errors={val_inv['errors']}")
    assert val_inv["validated_data"]["pa"] is None
    assert val_inv["validated_data"]["pv"] is None

    # 3. Test d'enregistrement de LiveMeasurement et moteur d'alertes
    print("\n[TEST 3] Enregistrement d'une mesure et test d'alerte...")
    vd = val_res["validated_data"]
    measurement1 = LiveMeasurement.objects.create(
        seance=seance,
        Debit_sang=vd["qb"],
        PA=vd["pa"],
        PV=vd["pv"],
        PTM=vd["ptm"],
        Volume_UF=vd["uf_volume"],
        Taux_UF=vd["uf_rate"],
        Heparine=vd["heparin"],
        source="AI_OCR_TEST",
        status_validation=val_res["status"],
    )
    print(f"-> LiveMeasurement 1 créé (ID: {measurement1.id})")

    alerts1 = analyser_mesure(measurement1)
    print(f"-> Alertes générées pour mesure 1: {len(alerts1)}")
    assert len(alerts1) > 0, "Au moins une alerte PTM aurait dû être créée"
    ptm_alert = alerts1[0]
    print(f"-> Alerte créée: {ptm_alert.danger_level} - {ptm_alert.alert_type}: {ptm_alert.message}")

    # 4. Test du Cooldown de 15 minutes
    print("\n[TEST 4] Test du Cooldown de 15 minutes sur les alertes identiques...")
    measurement2 = LiveMeasurement.objects.create(
        seance=seance,
        Debit_sang=vd["qb"],
        PA=vd["pa"],
        PV=vd["pv"],
        PTM=325.0, # Toujours en alerte PTM
        Volume_UF=vd["uf_volume"],
        Taux_UF=vd["uf_rate"],
        Heparine=vd["heparin"],
        source="AI_OCR_TEST",
        status_validation=val_res["status"],
    )
    alerts2 = analyser_mesure(measurement2)
    print(f"-> Alertes générées pour mesure 2 (sous cooldown): {len(alerts2)}")
    assert len(alerts2) == 0, "L'alerte PTM doit être bloquée par le cooldown de 15 min"
    print("-> COOLDOWN 15 MIN VALIDÉ AVEC SUCCÈS !")

    # 5. Test du résumé de séance et rapport HTML
    print("\n[TEST 5] Test de la génération automatique du résumé IA et du rapport de séance...")
    seance.status = "terminée"
    seance.save(update_fields=["status"])

    report_result = generate_session_summary_and_report(seance.id)
    print(f"-> Rapport généré ID: {report_result['rapport_id']} | Fichier: {report_result['filename']}")
    assert "summary" in report_result
    assert "resume_court" in report_result["summary"]
    
    rapport_db = RapportSeance.objects.filter(seance=seance).first()
    assert rapport_db is not None
    assert len(rapport_db.contenu_html) > 500
    print("-> RAPPORT DE SÉANCE ET RÉSUMÉ IA VALIDÉS !")

    # 6. Clean up test objects
    print("\n[CLEANUP] Nettoyage des mesures et alertes de test...")
    LiveMeasurement.objects.filter(seance=seance).delete()
    Alert.objects.filter(seance=seance).delete()
    RapportSeance.objects.filter(seance=seance).delete()

    print("\n" + "=" * 60)
    print("  TOUS LES TESTS END-TO-END ONT RÉUSSI AVEC SUCCÈS !")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
