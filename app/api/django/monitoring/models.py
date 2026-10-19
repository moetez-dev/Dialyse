from django.db import models
import uuid
from seances.models import Seance


class VitalReading(models.Model):
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


    timestamp = models.DateTimeField(
        auto_now_add=True
    )