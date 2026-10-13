import json

from django.test import RequestFactory, TestCase
from django.utils import timezone

from machines.models import Machine
from patients.models import Patient
from seances.models import Seance
from seances.views import search_sessions


class SearchSessionsTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.patient = Patient.objects.create(
            first_name="Alice",
            last_name="Durand",
            date_of_birth="1990-01-01",
            age=35,
            groupe_sanguin="A+",
            type_de_dialyse="Hémodialyse",
        )
        self.machine = Machine.objects.create(machine_id="M-100")
        self.session = Seance.objects.create(
            patient=self.patient,
            machine=self.machine,
            status="en cours",
            session_date=timezone.localdate(),
            start_hour="08:00:00",
        )

    def test_search_sessions_filters_active_sessions(self):
        request = self.factory.get(
            "/seances/search/",
            {"status": "en cours"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        response = search_sessions(request)

        self.assertEqual(response.status_code, 200)
        payload = json.loads(response.content)
        self.assertEqual(payload["count"], 1)
        self.assertEqual(payload["sessions"][0]["id"], str(self.session.id))
