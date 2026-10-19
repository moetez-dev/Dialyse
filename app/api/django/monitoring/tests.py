from django.test import SimpleTestCase

from monitoring.ai_service import build_alert_guidance


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
        self.assertNotEqual(pa_guidance["recommendations"][0], pv_guidance["recommendations"][0])
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
