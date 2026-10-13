"""Composants d'interface partagés.

Chaque écran réécrivait ses propres cartes, tableaux et pastilles de statut,
avec un espacement et des couleurs légèrement différents à chaque fois. Ces
balises donnent une seule définition pour chacun.

Usage dans un gabarit :

    {% load ui %}

    {% ui_page_header "Patients" subtitle="Liste des patients suivis" %}
      <a href="...">Ajouter</a>
    {% endui_page_header %}

    {% ui_card title="Résultats" %} ... {% endui_card %}
    {% ui_badge "En cours" tone="brand" %}
    {% ui_status seance.status kind="seance" %}
"""

from django import template
from django.template.loader import render_to_string

register = template.Library()


# Les statuts stockés en base sont du texte libre et incohérents entre modèles :
# minuscules accentuées pour les séances, CamelCase pour les machines, et deux
# vocabulaires concurrents pour les alertes. On les traduit ici, en un endroit,
# sans jamais réécrire les valeurs stockées (le listener MQTT et le client
# Flutter filtrent sur ces chaînes exactes).
SEANCE_TONE = {
    "planifiée": "info",
    "en cours": "brand",
    "terminée": "ok",
    "annulée": "neutral",
    "difficile": "warn",
}

MACHINE_TONE = {
    "prete": "ok",
    "reserve": "info",
    "maintenance": "warn",
    "hors service": "crit",
    "inactive": "neutral",
}

ALERTE_TONE = {
    "high": "crit",
    "red": "crit",
    "critique": "crit",
    "medium": "warn",
    "yellow": "warn",
    "alerte": "warn",
    "low": "info",
    "info": "info",
    "new": "crit",
    "ack": "warn",
    "resolved": "ok",
}

TONE_CLASSES = {
    "neutral": "bg-idle-soft text-idle",
    "brand": "bg-brand-50 text-brand-800 dark:bg-brand-950 dark:text-brand-200",
    "ok": "bg-stable-soft text-stable",
    "warn": "bg-warning-soft text-warning",
    "crit": "bg-critical-soft text-critical",
    "info": "bg-brand-50 text-brand-700 dark:bg-brand-950 dark:text-brand-300",
}

_TONE_MAPS = {
    "seance": SEANCE_TONE,
    "machine": MACHINE_TONE,
    "alerte": ALERTE_TONE,
}

# Libellés affichés. Les valeurs stockées restent intactes : on ne traduit qu'à
# l'affichage, pour ne pas casser les filtres du listener MQTT ni du client Flutter.
ALERTE_LABEL = {
    "high": "Critique",
    "red": "Critique",
    "critique": "Critique",
    "medium": "Avertissement",
    "yellow": "Avertissement",
    "alerte": "Avertissement",
    "low": "Information",
    "info": "Information",
    "new": "Nouvelle",
    "ack": "Acquittée",
    "resolved": "Résolue",
}

MACHINE_LABEL = {
    "prete": "Prête",
    "reserve": "Réservée",
    "maintenance": "Maintenance",
    "hors service": "Hors service",
    "inactive": "Inactive",
}

_LABEL_MAPS = {
    "alerte": ALERTE_LABEL,
    "machine": MACHINE_LABEL,
    "seance": {},  # déjà en français lisible en base
}


def tone_for(value, kind="seance"):
    """Tonalité d'un statut métier, insensible à la casse et aux espaces."""
    key = (value or "").strip().casefold()
    return _TONE_MAPS.get(kind, {}).get(key, "neutral")


@register.filter
def tone_classes(tone):
    return TONE_CLASSES.get(tone, TONE_CLASSES["neutral"])


@register.inclusion_tag("ui/badge.html")
def ui_badge(label, tone="neutral", dot=False, icon=None):
    return {
        "label": label,
        "classes": TONE_CLASSES.get(tone, TONE_CLASSES["neutral"]),
        "tone": tone,
        "dot": dot,
        "icon": icon,
    }


@register.inclusion_tag("ui/badge.html")
def ui_status(value, kind="seance", dot=False):
    """Pastille pour un statut venu de la base (séance, machine, alerte)."""
    tone = tone_for(value, kind)
    key = (value or "").strip().casefold()
    label = _LABEL_MAPS.get(kind, {}).get(key) or (value or "—").strip().capitalize()
    return {
        "label": label,
        "classes": TONE_CLASSES.get(tone, TONE_CLASSES["neutral"]),
        "tone": tone,
        "dot": dot,
        "icon": None,
    }


@register.inclusion_tag("ui/stat_card.html")
def ui_stat_card(label, value, hint=None, tone="neutral", icon=None, unit=None):
    return {
        "label": label,
        "value": value,
        "unit": unit,
        "hint": hint,
        "icon": icon,
        "value_class": {
            "neutral": "text-body",
            "brand": "text-brand-700 dark:text-brand-300",
            "ok": "text-stable",
            "warn": "text-warning",
            "crit": "text-critical",
            "info": "text-brand-700 dark:text-brand-300",
        }.get(tone, "text-body"),
    }


@register.inclusion_tag("ui/empty_state.html")
def ui_empty_state(title, body=None, icon="file-text", action_label=None, action_href=None):
    return {
        "title": title,
        "body": body,
        "icon": icon,
        "action_label": action_label,
        "action_href": action_href,
    }


@register.simple_block_tag
def ui_page_header(content, title, subtitle=None):
    """En-tête de page. Le corps de la balise sert de zone d'actions."""
    return render_to_string(
        "ui/page_header.html",
        {"title": title, "subtitle": subtitle, "actions": content},
    )


@register.simple_block_tag
def ui_card(content, title=None, subtitle=None, padded=True):
    return render_to_string(
        "ui/card.html",
        {"title": title, "subtitle": subtitle, "body": content, "padded": padded},
    )


@register.simple_block_tag
def ui_table(content, columns=None, empty=None):
    """Habillage d'un tableau. Les lignes restent écrites dans le gabarit :
    chaque écran y met des boutons et des pastilles qu'un rendu générique ne
    saurait pas exprimer."""
    return render_to_string(
        "ui/table.html",
        {"columns": columns or [], "rows": content, "empty": empty},
    )
