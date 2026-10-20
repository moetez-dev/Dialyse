from django.db import models
import uuid
from seances.models import Seance


class VitalReading(models.Model):
    """Relevé « vital » de séance — modèle historique, non alimenté.

    Rôle dans le projet (A-13) :
      * `LiveMeasurement` est le modèle **makeur** des relevés de dialyse.
        C'est le seul alimenté par le listener MQTT, par le push HTTP et par
        l'API : alertes, tableaux de bord, historiques et rapports de séance
        s'appuient tous dessus.
      * `VitalReading` est un modèle de la même forme, jamais écrit par le
        pipeline actuel (0 ligne). Il a été conservé : le supprimer aurait
        fait disparaître un modèle public sans décision explicite, et un
        usage externe (application mobile, exports) pourrait encore le
        consulter.

    Risque de synchronisation à garder en tête : les deux modèles portent les
    mêmes colonnes. Si un jour `VitalReading` est alimenté, il faudra
    décider explicitement lequel fait foi, sous peine de deux séries de
    données divergentes pour une même séance. Tant qu'il reste vide, il n'y a
    pas de doublon possible : une mesure entrante ne crée qu'une ligne,
    dans `LiveMeasurement`.
    """

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )

    seance = models.ForeignKey(
        Seance,
        on_delete=models.CASCADE,
        related_name="vital_readings"
    )

    timestamp = models.DateTimeField(auto_now_add=True)

    Debit_sang = models.FloatField(null=True, blank=True)
    Taux_UF = models.FloatField(null=True, blank=True)
    PA = models.FloatField(null=True, blank=True)
    PTM = models.FloatField(null=True, blank=True)
    PV = models.FloatField(null=True, blank=True)
    Volume_UF = models.FloatField(null=True, blank=True)
    Heparine = models.FloatField(null=True, blank=True)


    class Meta:
        db_table = "vital_readings"





class ConversationLog(models.Model):

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )

    message = models.TextField()

    response = models.TextField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )


    class Meta:
        db_table = "conversation_logs"
class LiveMeasurement(models.Model):

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )

    seance = models.ForeignKey(
        Seance,
        on_delete=models.CASCADE,
        related_name="readings"
    )

    timestamp = models.DateTimeField(
        auto_now_add=True
    )

    Debit_sang = models.FloatField(null=True, blank=True)
    Taux_UF = models.FloatField(null=True, blank=True)
    PA = models.FloatField(null=True, blank=True)
    PTM = models.FloatField(null=True, blank=True)
    PV = models.FloatField(null=True, blank=True)
    Volume_UF = models.FloatField(null=True, blank=True)
    Heparine = models.FloatField(null=True, blank=True)

    image = models.ImageField(upload_to="machine_images/", null=True, blank=True)
    source = models.CharField(max_length=50, default="AI_OCR", null=True, blank=True)
    status_validation = models.CharField(max_length=20, default="VALIDATED", null=True, blank=True)

    class Meta:
        db_table = "live_measurements"
class Alerte(models.Model):

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )

    reading = models.ForeignKey(
        LiveMeasurement,
        on_delete=models.CASCADE,
        related_name="alertes"
    )
    source_alert = models.ForeignKey(
        "seances.Alert",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="measurement_alerts",
    )

    niveau = models.CharField(
        max_length=20
    )

    message = models.TextField()

    parameter = models.CharField(max_length=30, null=True, blank=True)
    measured_value = models.FloatField(null=True, blank=True)
    unit = models.CharField(max_length=20, null=True, blank=True)
    threshold = models.FloatField(null=True, blank=True)
    threshold_type = models.CharField(max_length=20, null=True, blank=True)

    status = models.CharField(
        max_length=10,
        default="NEW"
    )

    # Provenance : portée par le message (voir seances.Alert). Aucun champ
    # supplémentaire : le miroir ne duplique que ce qui est nécessaire.


    timestamp = models.DateTimeField(
        auto_now_add=True
    )