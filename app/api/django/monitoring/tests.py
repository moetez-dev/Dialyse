from unittest.mock import patch

from django.test import SimpleTestCase, TestCase
from django.utils import timezone

from accounts.models import Role, User
from machines.models import Machine
from monitoring.ai_service import build_alert_guidance
from monitoring.models import Alerte, LiveMeasurement
from monitoring.provenance import (
    SOURCE_AI_UNAVAILABLE,
    VALIDATION_AI_UNAVAILABLE,
    describe_source,
    has_usable_values,
    is_simulated,
)
from patients.models import Patient
from seances.models import Alert as SeanceAlert
from seances.models import Seance


class AlertGuidanceTests(SimpleTestCase):
    def test_guidance_uses_the_structured_parameter(self):
        pa_guidance = build_alert_guidance(
            parameter="PA",
            severity="HIGH",
            measured_value=205,
            unit="mmHg",
            threshold=200,
            threshold_type="critical_max",
        )
        pv_guidance = build_alert_guidance(
            parameter="PV",
            severity="MEDIUM",
            measured_value=270,
            unit="mmHg",
            threshold=250,
            threshold_type="normal_max",
        )

        self.assertIn("pression artérielle du circuit", pa_guidance["recommendations"][0])
        self.assertIn("pression veineuse du circuit", pv_guidance["recommendations"][0])
        self.assertNotEqual(pv_guidance["recommendations"][0], pa_guidance["recommendations"][0])
        self.assertIn("pression artérielle du circuit", pa_guidance["cause"])
        self.assertTrue(pa_guidance["urgent_escalation"])
        self.assertFalse(pv_guidance["urgent_escalation"])

    def test_guidance_is_unavailable_for_missing_or_invalid_structured_data(self):
        guidance = build_alert_guidance(
            parameter=None,
            severity="HIGH",
            measured_value=-1,
            unit="mmHg",
            threshold=None,
            threshold_type="critical_min",
        )
        invalid = build_alert_guidance(
            parameter="PA",
            severity="UNKNOWN",
            measured_value=float("nan"),
            unit="mmHg",
            threshold=200,
            threshold_type="critical_max",
        )
        inconsistent = build_alert_guidance(
            parameter="PA",
            severity="HIGH",
            measured_value=190,
            unit="mL/min",
            threshold=200,
            threshold_type="normal_max",
        )

        self.assertEqual(guidance["status"], "unavailable")
        self.assertTrue(guidance["urgent_escalation"])
        self.assertEqual(invalid["status"], "unavailable")
        self.assertEqual(inconsistent["status"], "unavailable")


class ProvenanceTests(SimpleTestCase):
    """Vocabulaire de provenance : simulation, valeur inexploitable."""

    def test_simulation_sources_are_recognised(self):
        for source in ("simulation", "telemetry_sim", "SIMULATION", "simulateur"):
            self.assertTrue(is_simulated(source), source)

    def test_real_sources_are_not_simulations(self):
        for source in ("AI_OCR", "qwen_ollama", "telemetry", "HTTP_PUSH"):
            self.assertFalse(is_simulated(source), source)

    def test_has_usable_values(self):
        self.assertTrue(has_usable_values({"qb": 260.0}))
        self.assertTrue(has_usable_values({"qb": 0.0}))
        self.assertFalse(has_usable_values({"qb": None, "pa": None}))
        self.assertFalse(has_usable_values({}))
        self.assertFalse(has_usable_values({"qb": ""}))

    def test_describe_source_is_explicit(self):
        self.assertIn("Simulateur", describe_source("simulation"))
        self.assertIn("illisible", describe_source(SOURCE_AI_UNAVAILABLE))


class NoFabricatedMeasurementTests(TestCase):
    """A-09 — une source illisible ne doit produire aucune mesure.

    Le listener MQTT remplaçait une image illisible par des constantes
    plausibles, enregistrées avec le statut `VALIDATED`. La base affirmait
    alors une mesure que personne n'avait relevée, et cette mesure pouvait
    déclencher une alerte critique.
    """

    def setUp(self):
        self.role = Role.objects.create(name="Admin")
        self.user = User.objects.create(
            username="prov_test", password="password123", role=self.role,
            email="prov@test.com", first_login=False,
        )
        self.patient = Patient.objects.create(
            first_name="Test", last_name="Provenance",
            date_of_birth="1990-01-01", age=35,
            groupe_sanguin="A+", type_de_dialyse="Hémodialyse",
        )
        self.machine = Machine.objects.create(machine_id="M-PROV", status="Prete")
        self.seance = Seance.objects.create(
            patient=self.patient, machine=self.machine, status="en cours",
            session_date=timezone.localdate(), start_hour="08:00:00", duration=4,
        )

    def test_mesure_sans_valeur_ne_declenche_aucune_alerte(self):
        from monitoring.alerte import analyser_mesure

        measurement = LiveMeasurement.objects.create(
            seance=self.seance,
            source=SOURCE_AI_UNAVAILABLE,
            status_validation=VALIDATION_AI_UNAVAILABLE,
        )

        alertes = analyser_mesure(measurement)

        self.assertEqual(alertes, [], "une mesure sans valeur ne peut pas alerter")
        self.assertEqual(SeanceAlert.objects.count(), 0)
        self.assertEqual(Alerte.objects.count(), 0)

    def test_mesure_sans_valeur_n_est_pas_validee(self):
        from monitoring.alerte import analyser_mesure

        measurement = LiveMeasurement.objects.create(
            seance=self.seance,
            source=SOURCE_AI_UNAVAILABLE,
            status_validation=VALIDATION_AI_UNAVAILABLE,
        )
        analyser_mesure(measurement)

        self.assertNotEqual(measurement.status_validation, "VALIDATED")
        for champ in ("Debit_sang", "PA", "PV", "PTM", "Volume_UF", "Taux_UF", "Heparine"):
            self.assertIsNone(getattr(measurement, champ), champ)

    def test_notification_externe_ignoree_pour_une_mesure_simulee(self):
        """Une mesure simulée ne doit déclencher aucun webhook n8n."""
        from monitoring import alerte as alerte_module

        measurement = LiveMeasurement.objects.create(
            seance=self.seance, Debit_sang=50.0, PA=120.0, PV=100.0, PTM=60.0,
            source="simulation", status_validation="VALIDATED",
        )

        with patch.object(alerte_module, "dispatch_n8n_critical_risk") as dispatch:
            alerte_module.analyser_mesure(measurement)

        self.assertEqual(SeanceAlert.objects.count(), 1, "l'alerte locale doit être créée")
        dispatch.assert_not_called()

    def test_notification_externe_conservee_pour_une_mesure_reelle(self):
        from monitoring import alerte as alerte_module

        measurement = LiveMeasurement.objects.create(
            seance=self.seance, Debit_sang=50.0, PA=120.0, PV=100.0, PTM=60.0,
            source="telemetry", status_validation="VALIDATED",
        )

        with patch.object(alerte_module, "dispatch_n8n_critical_risk") as dispatch:
            alerte_module.analyser_mesure(measurement)

        dispatch.assert_called_once()

    def test_alerte_simulee_est_marquee_non_clinique(self):
        """Une alerte issue d'une simulation ne doit pas être clinique."""
        from monitoring import alerte as alerte_module
        from monitoring.provenance import est_alerte_clinique, provenance_alerte

        measurement = LiveMeasurement.objects.create(
            seance=self.seance, Debit_sang=50.0, PA=120.0, PV=100.0, PTM=60.0,
            source="simulation", status_validation="VALIDATED",
        )

        with patch.object(alerte_module, "dispatch_n8n_critical_risk") as dispatch:
            alertes = alerte_module.analyser_mesure(measurement)

        self.assertEqual(len(alertes), 1)
        dispatch.assert_not_called()
        alerte = alertes[0]
        self.assertTrue(alerte.message.startswith("⚠ SIMULATION"))
        source, simule = provenance_alerte(alerte)
        self.assertEqual(source, "simulation")
        self.assertTrue(simule)
        self.assertFalse(est_alerte_clinique(source, simule))

    def test_alerte_origine_inconnue_est_marquee_non_clinique(self):
        """Une source déclarée que le code ne reconnaît pas n'est pas clinique."""
        from monitoring import alerte as alerte_module

        measurement = LiveMeasurement.objects.create(
            seance=self.seance, Debit_sang=50.0, PA=120.0, PV=100.0, PTM=60.0,
            source="source_inconnue", status_validation="VALIDATED",
        )

        with patch.object(alerte_module, "dispatch_n8n_critical_risk") as dispatch:
            alertes = alerte_module.analyser_mesure(measurement)

        self.assertEqual(len(alertes), 1)
        dispatch.assert_not_called()
        self.assertTrue(alertes[0].message.startswith("⚠ ORIGINE NON IDENTIFIÉE"))

    def test_alerte_reelle_reste_clinique(self):
        from monitoring import alerte as alerte_module
        from monitoring.provenance import est_alerte_clinique, provenance_alerte

        measurement = LiveMeasurement.objects.create(
            seance=self.seance, Debit_sang=50.0, PA=120.0, PV=100.0, PTM=60.0,
            source="telemetry", status_validation="VALIDATED",
        )

        with patch.object(alerte_module, "dispatch_n8n_critical_risk"):
            alertes = alerte_module.analyser_mesure(measurement)

        alerte = alertes[0]
        self.assertFalse(alerte.message.startswith("⚠"))
        source, simule = provenance_alerte(alerte)
        self.assertFalse(simule)
        self.assertTrue(est_alerte_clinique(source, simule))

    def test_alerte_heritee_sans_provenance_reste_clinique(self):
        """Les alertes antérieures à la traçabilité ne sont pas requalifiées."""
        from monitoring.provenance import est_alerte_clinique, provenance_alerte

        alerte = SeanceAlert.objects.create(
            seance=self.seance, alert_type="Pression artérielle",
            message="🔴 CRITIQUE — Pression artérielle très bas : 50.0 mmHg",
            danger_level="HIGH", recommended_action="Vérifier",
        )
        source, simule = provenance_alerte(alerte)
        self.assertEqual(source, "")
        self.assertFalse(simule)
        self.assertTrue(est_alerte_clinique(source, simule))


class SourceAssainieTests(SimpleTestCase):
    """La source déclarée par un client n'est pas prise pour argent comptant."""

    def test_source_connue_conservee(self):
        from monitoring.provenance import normalise_source_declaree

        source, declaree = normalise_source_declaree("simulation")
        self.assertEqual(source, "simulation")
        self.assertTrue(declaree)

    def test_source_inconnue_ne_devient_pas_reelle(self):
        from monitoring.provenance import normalise_source_declaree

        source, declaree = normalise_source_declaree("mon-generateur-2026")
        self.assertEqual(source, "source_inconnue")
        self.assertTrue(declaree)

    def test_source_absente_replie_sur_le_canal(self):
        from monitoring.provenance import normalise_source_declaree

        source, declaree = normalise_source_declaree(None)
        self.assertEqual(source, "HTTP_PUSH")
        self.assertFalse(declaree)


class StatutPartielTests(SimpleTestCase):
    """Une lecture incomplète est signalée sans casser les statuts existants."""

    def test_lecture_complete_vaut_validated(self):
        from monitoring.validation import validate_dialysis_data

        resultat = validate_dialysis_data({
            "qb": 260, "pa": 120, "pv": 129, "ptm": 121,
            "uf_volume": 1500, "uf_rate": 500, "heparin": 1000,
        })
        self.assertEqual(resultat["status"], "VALIDATED")

    def test_lecture_partielle_vaut_partiel(self):
        from monitoring.validation import validate_dialysis_data

        resultat = validate_dialysis_data({"qb": 260, "pa": 120})
        self.assertEqual(resultat["status"], "PARTIEL")
        self.assertEqual(resultat["validated_data"]["qb"], 260.0)
        self.assertIsNone(resultat["validated_data"]["pv"])

    def test_lecture_partielle_ninvente_aucune_valeur(self):
        from monitoring.validation import validate_dialysis_data

        resultat = validate_dialysis_data({"qb": 260})
        for cle in ("pa", "pv", "ptm", "uf_volume", "uf_rate", "heparin"):
            self.assertIsNone(resultat["validated_data"][cle], cle)

    def test_aucune_valeur_vaut_invalid(self):
        from monitoring.validation import validate_dialysis_data

        resultat = validate_dialysis_data({"qb": None, "pa": None})
        self.assertEqual(resultat["status"], "INVALID")
