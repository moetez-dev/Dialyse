import json
import re

from django.test import Client, TestCase
from django.urls import reverse
from django.utils import timezone

from accounts.models import Role, User
from machines.models import Machine
from patients.models import Patient
from seances.models import Seance


SEUIL_NOMS = [
    "blood_flow_min", "blood_flow_max", "blood_flow_critical_low", "blood_flow_critical_high",
    "arterial_pressure_min", "arterial_pressure_max", "arterial_pressure_critical_low",
    "arterial_pressure_critical_high",
    "venous_pressure_min", "venous_pressure_max", "venous_pressure_critical_low",
    "venous_pressure_critical_high",
    "tmp_min", "tmp_max", "tmp_critical_low", "tmp_critical_high",
    "uf_rate_min", "uf_rate_max", "uf_rate_critical_high",
    "uf_volume_min", "uf_volume_max", "uf_volume_critical_high",
    "heparin_min", "heparin_max", "heparin_critical_high",
]


class SeanceTestMixin:
    """Patient, machine, séance et compte de test, communs aux cas ci-dessous."""

    def setUp(self):
        self.client = Client()
        self.role = Role.objects.create(name="Admin")
        self.user = User.objects.create(
            username="seance_test",
            password="password123",
            role=self.role,
            email="seance@test.com",
            first_login=False,
        )
        self.patient = Patient.objects.create(
            first_name="Alice",
            last_name="Durand",
            date_of_birth="1990-01-01",
            age=35,
            groupe_sanguin="A+",
            type_de_dialyse="Hémodialyse",
        )
        self.machine = Machine.objects.create(machine_id="M-100", status="Prete")
        self.seance = Seance.objects.create(
            patient=self.patient,
            machine=self.machine,
            status="planifiée",
            session_date=timezone.localdate(),
            start_hour="08:00:00",
            duration=4,
        )
        self._login()

    def _login(self):
        session = self.client.session
        session["app_user_id"] = self.user.id
        session.save()

    def _payload(self, **overrides):
        """Charge utile valide du formulaire de lancement,issue de la séance."""
        payload = {
            "weight": "72.5",
            "blood_pressure": "120/80",
            "temperature": "36.8",
            "heart_rate": "78",
            "saturation": "98",
            "debit": "60",
        }
        for name in SEUIL_NOMS:
            payload[name] = str(getattr(self.seance, name))
        payload.update(overrides)
        return payload


class PreSessionLaunchTests(SeanceTestMixin, TestCase):
    """A-01 — le formulaire de lancement doit pré-remplir des seuils exploitables.

    Les seuils étaient rendus avec la virgule décimale française (« 150,0 »).
    Un `<input type="number">` rejette cette valeur : le navigateur vidait les
    24 champs, le formulaire était renvoyé sans erreur affichée, et la séance
    restait « planifiée ».
    """

    def _pre_url(self):
        return reverse("seances:pre_session_page", kwargs={"session_id": self.seance.id})

    def test_seuils_rendus_exploitables_par_le_navigateur(self):
        response = self.client.get(self._pre_url())
        self.assertEqual(response.status_code, 200)
        html = response.content.decode()

        valeurs = re.findall(
            r'<input[^>]*type="number"[^>]*name="([a-z_]+)"[^>]*value="([^"]*)"', html
        )
        self.assertTrue(valeurs, "aucun champ de seuil rendu")

        for nom, valeur in valeurs:
            self.assertNotIn(",", valeur, f"{nom} rendu avec une virgule décimale : {valeur!r}")
            float(valeur)  # lève si la valeur n'est pas un nombre

    def test_aucun_champ_de_seuil_vide_au_rendu(self):
        html = self.client.get(self._pre_url()).content.decode()
        for nom in SEUIL_NOMS:
            motif = re.compile(
                r'<input[^>]*type="number"[^>]*name="%s"[^>]*>' % re.escape(nom)
            )
            found = motif.search(html)
            self.assertIsNotNone(found, f"champ {nom} absent du formulaire")
            self.assertIn("value=", found.group(0), f"champ {nom} sans attribut value")

    def test_lancement_valide_demarre_la_seance(self):
        response = self.client.post(self._pre_url(), self._payload())

        self.assertEqual(response.status_code, 302, "le lancement valide doit rediriger")
        self.seance.refresh_from_db()
        self.assertEqual(self.seance.status, "en cours")
        self.assertEqual(self.seance.pre_measurements.weight, 72.5)
        self.machine.refresh_from_db()
        self.assertEqual(self.machine.status, "Reserve")

    def test_seuils_saisis_sont_enregistres(self):
        payload = self._payload(tmp_max="275.5", blood_flow_min="160.25")
        self.client.post(self._pre_url(), payload)

        self.seance.refresh_from_db()
        self.assertEqual(self.seance.tmp_max, 275.5)
        self.assertEqual(self.seance.blood_flow_min, 160.25)

    def test_soumission_invalide_affiche_les_erreurs_et_ne_demarre_pas(self):
        payload = self._payload()
        for nom in SEUIL_NOMS:
            payload[nom] = ""

        response = self.client.post(self._pre_url(), payload)

        self.assertEqual(response.status_code, 200)
        html = response.content.decode()
        self.assertIn("Ce champ est obligatoire", html)
        self.assertIn("champ", html.lower())
        self.seance.refresh_from_db()
        self.assertEqual(self.seance.status, "planifiée", "une séance invalide ne doit pas démarrer")

    def test_saisie_invalide_est_conservee_au_rerendu(self):
        payload = self._payload(tmp_max="")
        response = self.client.post(self._pre_url(), payload)

        self.assertEqual(response.status_code, 200)
        html = response.content.decode()
        # La valeur saisie par l'utilisateur est réinjectée, pas écrasée.
        self.assertIn("name=\"tmp_max\"", html)


class SearchSessionsTests(SeanceTestMixin, TestCase):
    """A-08 — la recherche de séances doit passer par le client de test.

    Le test appelait la vue avec un `WSGIRequest` fabriqué à la main : sans la
    couche de session, `request.session` n'existait pas et la vue levait une
    AttributeError. L'authentification n'est pas contournée : elle est
    vérifiée par une requête non authentifiée.
    """

    def test_search_sessions_filters_active_sessions(self):
        self.seance.status = "en cours"
        self.seance.save(update_fields=["status"])
        # Une séance planifiée du même patient : le filtre doit l'exclure.
        Seance.objects.create(
            patient=self.patient,
            machine=self.machine,
            status="planifiée",
            session_date=timezone.localdate(),
            start_hour="10:00:00",
            duration=4,
        )

        response = self.client.get(
            reverse("seances:search_sessions"),
            {"status": "en cours"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )

        self.assertEqual(response.status_code, 200)
        payload = json.loads(response.content)
        self.assertEqual(payload["count"], 1)
        self.assertEqual(payload["sessions"][0]["id"], str(self.seance.id))

    def test_search_sessions_exige_une_authentification(self):
        self.client.session.flush()
        response = self.client.get(
            reverse("seances:search_sessions"),
            {"status": "en cours"},
            HTTP_X_REQUESTED_WITH="XMLHttpRequest",
        )
        self.assertNotEqual(response.status_code, 200)
        self.assertIn(response.status_code, (302, 403))
