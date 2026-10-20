"""Normalise les statuts de séance.

Les statuts sont stockés en texte libre : la base contenait « En cours »
(majuscule) à côté de « en cours ». Toutes les vues, le listener MQTT et le
client Flutter filtrent sur la valeur exacte « en cours » : une séance
« En cours » restait donc invisible du tableau de bord tout en étant active,
et son générateur lui était réservé.

La migration ne ferme aucune séance et ne supprime rien : elle réécrit la
seule casse divergente vers la valeur canonique du modèle.
"""

from django.db import migrations


def _variantes(canonique):
    """Écritures possibles d'un même état métier."""
    return {
        canonique,
        canonique.upper(),
        canonique.capitalize(),
        canonique.title(),
        f" {canonique}",
        f"{canonique} ",
    }


def normaliser_statuts(apps, schema_editor):
    Seance = apps.get_model("seances", "Seance")
    canoniques = [choix[0] for choix in Seance._meta.get_field("status").choices]

    for canonique in canoniques:
        for variante in _variantes(canonique):
            if variante == canonique:
                continue
            Seance.objects.filter(status=variante).update(status=canonique)


def ne_rien_faire(apps, schema_editor):
    """Retour impossible : la casse d'origine n'est pas conservée.

    Le schéma n'est pas modifié par cette migration : l'opération inverse
    n'a donc rien à rétablir.
    """


class Migration(migrations.Migration):

    dependencies = [
        ("seances", "0003_alert_status"),
    ]

    operations = [
        migrations.RunPython(normaliser_statuts, ne_rien_faire),
    ]
