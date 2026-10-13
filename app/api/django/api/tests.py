import json
from datetime import date
from django.conf import settings
from django.test import TestCase, Client
from django.urls import reverse
from accounts.models import User, Role
from patients.models import Patient
from machines.models import Machine, RaspiDevice
from seances.models import Seance, Alert as SeanceAlert
from monitoring.models import LiveMeasurement, Alerte


class Phase1ApiTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.admin_role = Role.objects.create(name="Admin")
        self.doctor_role = Role.objects.create(name="Docteur")
        self.nurse_role = Role.objects.create(name="Infirmier")
        self.tech_role = Role.objects.create(name="Technicien")
        self.admin_user = User.objects.create(
            username="admin_test",
            password="password123",
            role=self.admin_role,
            email="admin@test.com",
        )
        self.doctor_user = User.objects.create(
            username="doc_test",
            password="password123",
            role=self.doctor_role,
            email="doc@test.com",
        )
        self.nurse_user = User.objects.create(
            username="nurse_test",
            password="password123",
            role=self.nurse_role,
            email="nurse@test.com",
        )
        self.tech_user = User.objects.create(
            username="tech_test",
            password="password123",
            role=self.tech_role,
            email="tech@test.com",
        )
        self.patient = Patient.objects.create(
            first_name="Ahmed",
            last_name="Ben Salah",
            date_of_birth=date(1980, 5, 20),
            age=45,
            groupe_sanguin="O+",
            type_de_dialyse="Hémodialyse",
        )
        self.machine = Machine.objects.create(
            machine_id="M100",
            model="Model-X",
            manufacturer="DialysisCorp",
            status="Prete",
        )
        self.raspi = RaspiDevice.objects.create(
            raspi_id="RASPI-TEST",
            machine=self.machine,
            is_active=True,
        )
        self.seance = Seance.objects.create(
            patient=self.patient,
            machine=self.machine,
            session_date=date.today(),
            start_hour="08:00",
            duration=4,
            status="planifiée",
            debit=60,
        )
        self.edge_headers = {"HTTP_X_EDGE_API_KEY": settings.EDGE_API_KEY}

    def _login(self, user):
        session = self.client.session
        session["app_user_id"] = user.id
        session.save()

    def test_mobile_login_success(self):
        res = self.client.post(
            "/api/login/",
            data=json.dumps({"username": "doc_test", "password": "password123"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get("success"))
        self.assertEqual(data["user"]["username"], "doc_test")
        self.assertTrue(data.get("sessionid"))

    def test_monitoring_live_via_session_header(self):
        """Flutter Web sends X-Session-Id when Cookie cannot be set."""
        login = self.client.post(
            "/api/login/",
            data=json.dumps({"username": "doc_test", "password": "password123"}),
            content_type="application/json",
        )
        session_id = login.json()["sessionid"]
        bare = Client()
        res = bare.get(
            "/api/monitoring/live/",
            HTTP_X_SESSION_ID=session_id,
        )
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json()["success"])
        # /api/monitoring/ expose l'historique de connexion de tout le
        # personnel (identifiants, e-mails) : réservé à l'administrateur, comme
        # la page /monitoring/ correspondante. Un docteur doit être refusé.
        res2 = bare.get(
            "/api/monitoring/?sort=-login_at",
            HTTP_X_SESSION_ID=session_id,
        )
        self.assertEqual(res2.status_code, 403)

        admin_login = Client().post(
            "/api/login/",
            data=json.dumps({"username": "admin_test", "password": "password123"}),
            content_type="application/json",
        )
        admin_session = admin_login.json()["sessionid"]
        res3 = Client().get(
            "/api/monitoring/?sort=-login_at",
            HTTP_X_SESSION_ID=admin_session,
        )
        self.assertEqual(res3.status_code, 200)

    def test_mobile_login_fail(self):
        res = self.client.post(
            "/api/login/",
            data=json.dumps({"username": "doc_test", "password": "wrongpassword"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 401)
        data = res.json()
        self.assertFalse(data.get("success"))

    def test_mobile_logout(self):
        self._login(self.doctor_user)
        res = self.client.post("/api/logout/")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json().get("success"))
        self.assertNotIn("app_user_id", self.client.session)

    def test_patients_api_unauthorized(self):
        res = self.client.get("/api/patients/")
        self.assertEqual(res.status_code, 401)

    def test_patients_api(self):
        self._login(self.doctor_user)
        res = self.client.get("/api/patients/")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get("success"))
        self.assertEqual(len(data["data"]), 1)
        self.assertEqual(data["data"][0]["first_name"], "Ahmed")

    def test_patients_api_search(self):
        self._login(self.doctor_user)
        res = self.client.get("/api/patients/?search=Ahmed")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.json()["data"]), 1)

    def test_patient_detail_api(self):
        self._login(self.doctor_user)
        res = self.client.get(f"/api/patients/{self.patient.id}/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["data"]["last_name"], "Ben Salah")

    def test_machines_api(self):
        self._login(self.nurse_user)
        res = self.client.get("/api/machines/")
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["data"][0]["machine_id"], "M100")
        self.assertIn("kpis", body)
        self.assertIn("locations", body)

    def test_machines_api_forbidden_for_doctor(self):
        self._login(self.doctor_user)
        res = self.client.get("/api/machines/")
        self.assertEqual(res.status_code, 403)

    def test_machine_detail_api(self):
        self._login(self.doctor_user)
        res = self.client.get(f"/api/machines/{self.machine.id}/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("raspi", res.json()["data"])

    def test_sessions_list_api(self):
        self._login(self.doctor_user)
        res = self.client.get("/api/sessions/")
        self.assertEqual(res.status_code, 200)
        self.assertGreaterEqual(len(res.json()["data"]), 1)

    def test_session_create_api_doctor(self):
        self._login(self.doctor_user)
        payload = {
            "patient_id": self.patient.id,
            "machine_id": self.machine.id,
            "session_date": "2026-09-01",
            "start_hour": "10:00",
            "duration": 4,
            "debit": 60,
        }
        res = self.client.post("/api/sessions/", data=json.dumps(payload), content_type="application/json")
        self.assertEqual(res.status_code, 201)

    def test_session_start_end_cancel(self):
        self._login(self.doctor_user)
        res = self.client.post(
            f"/api/sessions/{self.seance.id}/start/",
            data=json.dumps({"poids": 70, "tension": "120/80", "debit": 60}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.seance.refresh_from_db()
        self.assertEqual(self.seance.status, "en cours")
        res = self.client.post(
            f"/api/sessions/{self.seance.id}/end/",
            data=json.dumps({"poids": 68, "tension": "110/70"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.seance.refresh_from_db()
        self.assertEqual(self.seance.status, "terminée")

    def test_session_detail_api(self):
        self._login(self.doctor_user)
        self.seance.status = "en cours"
        self.seance.save()
        LiveMeasurement.objects.create(seance=self.seance, PA=180, Debit_sang=300)
        res = self.client.get(f"/api/sessions/{self.seance.id}/")
        self.assertEqual(res.status_code, 200)
        data = res.json()["data"]
        self.assertIn("readings", data)
        if data["readings"]:
            self.assertGreaterEqual(data["readings"][0]["time"], 0)

    def test_dashboard_api(self):
        self._login(self.doctor_user)
        res = self.client.get("/api/dashboard/")
        self.assertEqual(res.status_code, 200)
        kpis = res.json()["kpis"]
        self.assertIn("active_sessions", kpis)
        self.assertIn("available_machines", kpis)
        self.assertIn("total_machines", kpis)

    def test_monitoring_live_requires_session(self):
        res = self.client.get("/api/monitoring/live/")
        self.assertEqual(res.status_code, 401)
        self._login(self.doctor_user)
        res = self.client.get("/api/monitoring/live/")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json()["success"])

    def test_real_monitoring_requires_session(self):
        res = self.client.get("/api/real-monitoring/")
        self.assertEqual(res.status_code, 401)
        self._login(self.doctor_user)
        res = self.client.get("/api/real-monitoring/")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json()["success"])

    def test_seance_debit_api(self):
        self.seance.status = "en cours"
        self.seance.debit = 30
        self.seance.save()
        res = self.client.get("/api/seance/debit/?machine_id=M100")
        self.assertEqual(res.status_code, 401)
        res = self.client.get(
            "/api/seance/debit/?machine_id=M100",
            **self.edge_headers,
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["debit"], 30)

    def test_push_measurement_pipeline(self):
        self.seance.status = "en cours"
        self.seance.save()
        payload = {
            "machine_id": "M100",
            "Qb": 80,
            "UF_rate": 500,
            "PA": 190,
            "PTM": 50,
            "PV": 100,
            "UF_volume": 1000,
            "Heparin": 5,
        }
        res = self.client.post(
            "/api/push/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 401)
        res = self.client.post(
            "/api/push/",
            data=json.dumps(payload),
            content_type="application/json",
            **self.edge_headers,
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get("success"))
        self.assertGreater(data.get("monitoring_alerts_created", 0), 0)
        self.assertGreater(data.get("seance_alerts_created", 0), 0)

    def test_alerts_api_and_ack_resolve(self):
        self._login(self.doctor_user)
        self.seance.status = "en cours"
        self.seance.save()
        meas = LiveMeasurement.objects.create(seance=self.seance, PA=210)
        m_alert = Alerte.objects.create(
            reading=meas, niveau="RED", message="PA trop élevée", status="NEW"
        )
        SeanceAlert.objects.create(
            seance=self.seance,
            alert_type="PA",
            message="PA très élevée",
            danger_level="HIGH",
            recommended_action="Réduire débit",
        )
        res = self.client.get("/api/alerts/")
        self.assertEqual(res.status_code, 200)
        self.assertGreaterEqual(len(res.json()["data"]), 2)

        res_ack = self.client.post(f"/api/alerts/{m_alert.id}/ack/")
        self.assertEqual(res_ack.status_code, 200)
        m_alert.refresh_from_db()
        self.assertEqual(m_alert.status, "ACK")

        res_res = self.client.post(f"/api/alerts/{m_alert.id}/resolve/")
        self.assertEqual(res_res.status_code, 200)
        m_alert.refresh_from_db()
        self.assertEqual(m_alert.status, "RESOLVED")


    def test_patient_create_api(self):
        self._login(self.doctor_user)
        payload = {
            "first_name": "Sami",
            "last_name": "Trabelsi",
            "date_of_birth": "1990-01-15",
            "telephone": "20111222",
            "adresse": "Sfax",
            "contact_urgence": "20999888",
            "antecedents_medicaux": "HTA",
            "groupe_sanguin": "A+",
            "type_de_dialyse": "Hémodialyse",
        }
        res = self.client.post(
            "/api/patients/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["first_name"], "Sami")
        self.assertEqual(data["data"]["age"], date.today().year - 1990 - (
            (date.today().month, date.today().day) < (1, 15)
        ))
        self.assertTrue(Patient.objects.filter(first_name="Sami", last_name="Trabelsi").exists())

    def test_patient_create_requires_auth(self):
        res = self.client.post(
            "/api/patients/",
            data=json.dumps({
                "first_name": "X",
                "last_name": "Y",
                "date_of_birth": "1990-01-01",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 401)

    def test_patient_create_validation(self):
        self._login(self.nurse_user)
        res = self.client.post(
            "/api/patients/",
            data=json.dumps({"first_name": "Only"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 400)

    def test_patient_update_api(self):
        self._login(self.admin_user)
        res = self.client.put(
            f"/api/patients/{self.patient.id}/",
            data=json.dumps({
                "first_name": "Ahmed",
                "last_name": "Ben Salah",
                "date_of_birth": "1980-05-20",
                "telephone": "21111000",
                "adresse": "Tunis Centre",
                "contact_urgence": "22000000",
                "antecedents_medicaux": "Diabète type 2",
                "groupe_sanguin": "O+",
                "type_de_dialyse": "Hémodialyse",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.patient.refresh_from_db()
        self.assertEqual(self.patient.telephone, "21111000")
        self.assertEqual(self.patient.antecedents_medicaux, "Diabète type 2")
        self.assertIn("recent_sessions", res.json()["data"])

    def test_patient_delete_not_allowed(self):
        """Web has no patient delete — API must reject DELETE."""
        self._login(self.admin_user)
        res = self.client.delete(f"/api/patients/{self.patient.id}/")
        self.assertEqual(res.status_code, 405)
        self.assertTrue(Patient.objects.filter(id=self.patient.id).exists())



    def test_machine_create_admin_only(self):
        self._login(self.doctor_user)
        res = self.client.post(
            "/api/machines/",
            data=json.dumps({"machine_id": "M200", "model": "X", "location": "Salle A"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 403)

        self._login(self.admin_user)
        res = self.client.post(
            "/api/machines/",
            data=json.dumps({"machine_id": "M200", "model": "Model-Y", "location": "Salle A"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertTrue(Machine.objects.filter(machine_id="M200").exists())

    def test_machine_configure_status_and_raspi(self):
        # Le docteur était utilisé ici, alors que la vue Web
        # configurer_machine le refuse et que la barre latérale ne lui montre
        # même pas les générateurs : le test figeait une permission que
        # l'application n'accorde pas.
        self._login(self.nurse_user)
        res = self.client.put(
            f"/api/machines/{self.machine.id}/",
            data=json.dumps({
                "status": "Maintenance",
                "location": "Salle B",
                "raspi_db_id": str(self.raspi.id),
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.machine.refresh_from_db()
        self.assertEqual(self.machine.status, "Maintenance")
        self.assertEqual(self.machine.location, "Salle B")
        self.raspi.refresh_from_db()
        self.assertEqual(self.raspi.machine_id, self.machine.id)
        self.assertIn("raspi_options", res.json()["data"])

    def test_machine_configure_refused_to_doctor(self):
        """Le parc n'est pas du ressort du soin — comme la vue Web."""
        self._login(self.doctor_user)
        res = self.client.put(
            f"/api/machines/{self.machine.id}/",
            data=json.dumps({"location": "Salle C"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 403)
        self.machine.refresh_from_db()
        self.assertNotEqual(self.machine.location, "Salle C")

    def test_machine_status_allowed_to_doctor(self):
        """update_status reste ouverte au soin, elle aussi comme le Web."""
        self._login(self.doctor_user)
        res = self.client.put(
            f"/api/machines/{self.machine.id}/",
            data=json.dumps({"status": "Maintenance"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.machine.refresh_from_db()
        self.assertEqual(self.machine.status, "Maintenance")

    def test_machine_detail_hides_patients_from_technicien(self):
        """Le parc n'emporte pas le dossier patient.

        Le détail d'un générateur liste ses dernières séances ; ouvrir cet
        écran au technicien lui montrait le nom des patients dialysés.
        """
        self._login(self.tech_user)
        res = self.client.get(f"/api/machines/{self.machine.id}/")
        self.assertEqual(res.status_code, 200)
        data = res.json()["data"]
        self.assertNotIn("patient", data.get("active_session") or {})
        for seance in data["recent_sessions"]:
            self.assertNotIn("patient", seance)
        # L'historique lui-même reste nécessaire à l'entretien.
        self.assertIn("recent_sessions", data)

    def test_machine_detail_keeps_patients_for_soignants(self):
        self._login(self.nurse_user)
        res = self.client.get(f"/api/machines/{self.machine.id}/")
        self.assertEqual(res.status_code, 200)
        for seance in res.json()["data"]["recent_sessions"]:
            self.assertIn("patient", seance)

    def test_technicien_refused_patient_data(self):
        """Aucun point d'entrée clinique n'est ouvert au technicien."""
        self._login(self.tech_user)
        for path in ("/api/patients/", "/api/doctors/", "/api/nurses/"):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 403)

    def test_machine_delete_not_allowed(self):
        self._login(self.admin_user)
        res = self.client.delete(f"/api/machines/{self.machine.id}/")
        self.assertEqual(res.status_code, 405)

    def test_machines_search_and_status_filter(self):
        self._login(self.admin_user)
        res = self.client.get("/api/machines/?search=M100&status=Prete")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.json()["data"]), 1)



    def test_profile_get_and_update(self):
        self.doctor_user.first_login = False
        self.doctor_user.save(update_fields=["first_login"])
        self._login(self.doctor_user)
        res = self.client.get("/api/profile/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["data"]["username"], "doc_test")

        res = self.client.put(
            "/api/profile/",
            data=json.dumps({
                "phone": "21111222",
                "address": "Tunis",
                "email": "doc_updated@test.com",
                "bio": "Nephrologue",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.doctor_user.refresh_from_db()
        self.assertEqual(self.doctor_user.phone_number, "21111222")
        self.assertEqual(self.doctor_user.adress, "Tunis")
        self.assertEqual(res.json()["data"]["bio"], "Nephrologue")

    def test_profile_password_change(self):
        self.doctor_user.first_login = False
        self.doctor_user.save(update_fields=["first_login"])
        self._login(self.doctor_user)
        res = self.client.put(
            "/api/profile/",
            data=json.dumps({
                "old_password": "password123",
                "new_password": "newpass99",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.doctor_user.refresh_from_db()
        from django.contrib.auth.hashers import check_password
        self.assertTrue(check_password("newpass99", self.doctor_user.password))

    def test_first_login_requires_password_change(self):
        self.doctor_user.first_login = True
        self.doctor_user.save(update_fields=["first_login"])
        self._login(self.doctor_user)
        res = self.client.put(
            "/api/profile/",
            data=json.dumps({"phone": "20000000"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 400)

        res = self.client.put(
            "/api/profile/",
            data=json.dumps({
                "old_password": "password123",
                "new_password": "changed1",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        self.doctor_user.refresh_from_db()
        self.assertFalse(self.doctor_user.first_login)



    def test_doctors_api_admin_only(self):
        self._login(self.doctor_user)
        self.assertEqual(self.client.get("/api/doctors/").status_code, 403)

        self._login(self.admin_user)
        res = self.client.get("/api/doctors/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("kpis", res.json())

        res = self.client.post(
            "/api/doctors/",
            data=json.dumps({
                "username": "Dr New",
                "email": "drnewapi@test.com",
                "specialite": "Nephrologie",
                "phone": "20111000",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.json().get("temporary_password"))
        self.assertTrue(User.objects.filter(email="drnewapi@test.com").exists())

    def test_nurses_api_roles(self):
        self._login(self.nurse_user)
        self.assertEqual(self.client.get("/api/nurses/").status_code, 403)

        self._login(self.doctor_user)
        res = self.client.get("/api/nurses/")
        self.assertEqual(res.status_code, 200)

        res = self.client.post(
            "/api/nurses/",
            data=json.dumps({"username": "NurseX", "email": "nx@test.com"}),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 403)

        self._login(self.admin_user)
        res = self.client.post(
            "/api/nurses/",
            data=json.dumps({
                "username": "NurseY",
                "email": "ny@test.com",
                "phone": "20999000",
            }),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 201)
        nurse_id = res.json()["data"]["id"]
        res = self.client.get(f"/api/nurses/{nurse_id}/")
        self.assertEqual(res.status_code, 200)



class StaffCreatePermissionTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.admin_role = Role.objects.create(name="Admin")
        self.doctor_role = Role.objects.create(name="Docteur")
        self.admin_user = User.objects.create(
            username="admin_staff",
            password="password123",
            role=self.admin_role,
            email="admin_staff@test.com",
            first_login=False,
        )
        self.doctor_user = User.objects.create(
            username="doc_staff",
            password="password123",
            role=self.doctor_role,
            email="doc_staff@test.com",
            first_login=False,
        )

    def _login(self, user):
        session = self.client.session
        session["app_user_id"] = user.id
        session.save()

    def test_add_doctor_requires_login(self):
        res = self.client.post(
            "/add-doctor/",
            data={
                "fullName": "Dr New",
                "email": "drnew@test.com",
                "speciality": "Néphrologie",
                "phone": "20000000",
            },
        )
        self.assertEqual(res.status_code, 302)
        # Résolu par nom : la page de connexion a déménagé de / vers /connexion/.
        self.assertEqual(res.url, reverse("accounts:login_view"), msg=res.url)
        self.assertFalse(User.objects.filter(email="drnew@test.com").exists())

    def test_add_doctor_forbidden_for_doctor_role(self):
        self._login(self.doctor_user)
        before = User.objects.count()
        res = self.client.post(
            "/add-doctor/",
            data={
                "fullName": "Dr Blocked",
                "email": "drblocked@test.com",
                "speciality": "Néphrologie",
                "phone": "20000001",
            },
        )
        # Non-admin is redirected to the error page (HTML UX), creation denied.
        self.assertEqual(res.status_code, 302)
        self.assertIn("/error", res.url)
        self.assertEqual(User.objects.count(), before)
        self.assertFalse(User.objects.filter(email="drblocked@test.com").exists())

    def test_add_doctor_allowed_for_admin(self):
        self._login(self.admin_user)
        res = self.client.post(
            "/add-doctor/",
            data={
                "fullName": "Dr Allowed",
                "email": "drallowed@test.com",
                "speciality": "Néphrologie",
                "phone": "20000002",
            },
        )
        self.assertEqual(res.status_code, 302)
        self.assertTrue(User.objects.filter(email="drallowed@test.com").exists())

    def test_ajout_infirmier_forbidden_for_doctor(self):
        self._login(self.doctor_user)
        before = User.objects.count()
        res = self.client.post(
            "/nurses/ajouter/",
            data={
                "nom": "NurseBlocked",
                "email": "nurseblocked@test.com",
                "telephone": "20000003",
            },
        )
        self.assertEqual(res.status_code, 302)
        self.assertIn("/error", res.url)
        self.assertEqual(User.objects.count(), before)

    def test_ajout_infirmier_allowed_for_admin(self):
        self._login(self.admin_user)
        res = self.client.post(
            "/nurses/ajouter/",
            data={
                "nom": "NurseAllowed",
                "email": "nurseallowed@test.com",
                "telephone": "20000004",
            },
        )
        self.assertEqual(res.status_code, 302)
        self.assertTrue(User.objects.filter(email="nurseallowed@test.com").exists())
