from django.test import TestCase

from machines.models import Machine


class MachineModelTests(TestCase):
    """Le modèle Machine fait foi pour le parc de générateurs.

    Les scripts de validation historiques construisaient une Machine avec
    `nom=` — un champ qui n'existe pas — et avec le statut « en cours »,
    absent des choix du modèle. La création échouait alors sur une base
    où la machine n'existait pas encore.
    """

    def test_champs_du_modele(self):
        champs = {champ.name for champ in Machine._meta.get_fields()}
        self.assertNotIn("nom", champs)
        self.assertIn("model", champs)
        self.assertIn("location", champs)
        self.assertIn("status", champs)

    def test_statuts_valides(self):
        valides = {choix[0] for choix in Machine.enumerated_status}
        self.assertEqual(valides, {"Prete", "Reserve", "Maintenance", "Hors Service"})
        self.assertNotIn("en cours", valides)

    def test_creation_avec_les_champs_du_modele(self):
        machine, cree = Machine.objects.get_or_create(
            machine_id="M-TEST-SCRIPT",
            defaults={"model": "Dialyse-M001", "status": "Prete"},
        )
        self.assertTrue(cree)
        self.assertEqual(machine.status, "Prete")
        self.assertEqual(machine.model, "Dialyse-M001")
