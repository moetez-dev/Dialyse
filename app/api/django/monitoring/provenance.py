"""Provenance des mesures de dialyse.

Une mesure enregistrée doit dire d'où elle vient, et ce statut doit
signifier la même chose partout : service IA, télémétrie du générateur,
simulateur, ou échec de lecture.

Avant ce module, une image illisible (service IA ou Ollama indisponible)
était remplacée par des constantes plausibles, enregistrées avec le statut
`VALIDATED` : la base affirmait alors une mesure que personne n'avait
relevée, et cette mesure pouvait déclencher une alerte critique.

Règle appliquée : **aucune valeur n'est inventée**. Un échec de lecture est
enregistré comme tel (valeurs nulles, statut explicite), et ne participe
jamais à la détection de seuil.
"""

# ── Origines (valeur stockée dans LiveMeasurement.source) ────────────────
SOURCE_AI_OCR = "AI_OCR"                 # lecture d'image par le service IA
SOURCE_AI_OLLAMA = "qwen_ollama"          # lecture d'image par un modèle réellement exécuté
SOURCE_TELEMETRY = "telemetry"            # télémétrie poussée par un générateur
SOURCE_HTTP_PUSH = "HTTP_PUSH"            # push HTTP générique
SOURCE_SIMULATION = "simulation"          # valeurs produites par un simulateur
SOURCE_AI_UNAVAILABLE = "ai_unavailable"  # la source n'a pas pu être lue

#: Statuts de validation d'une mesure (LiveMeasurement.status_validation).
VALIDATION_VALIDATED = "VALIDATED"        # toutes les valeurs lues sont exploitables
VALIDATION_UNCERTAIN = "UNCERTAIN"        # au moins une valeur hors bornes physiques
VALIDATION_PARTIEL = "PARTIEL"            # lecture incomplète : certaines valeurs lues, d'autres absentes
VALIDATION_INVALID = "INVALID"            # aucune valeur exploitable
VALIDATION_AI_UNAVAILABLE = "AI_UNAVAILABLE"  # source illisible : aucune valeur

#: Valeurs de `source` qui ne proviennent pas d'un générateur réel.
SIMULATION_SOURCES = frozenset({
    SOURCE_SIMULATION,
    "telemetry_sim",      # valeur par défaut historique de save_telemetry_measurement
    "simulateur",
    "simulated",
})

#: Marqueurs reconnus dans un nom de source pour y repérer une simulation.
SIMULATION_MARKERS = ("simul", "_sim", "sim_")

#: Sources dont on sait qu'elles désignent un relevé réel (télémétrie ou OCR).
SOURCES_REELLES = frozenset({
    SOURCE_AI_OCR,
    SOURCE_AI_OLLAMA,
    SOURCE_TELEMETRY,
    SOURCE_HTTP_PUSH,
})

#: Toutes les sources que le code sait interpréter. Une source déclarée par
#: un client qui n'est pas dans cette liste n'est **pas** prise pour argent
#: comptant : elle devient `source_inconnue`, et les alertes qu'elle produit
#: ne sont pas présentées comme cliniques.
SOURCES_CONNUES = SOURCES_REELLES | SIMULATION_SOURCES | frozenset({
    SOURCE_AI_UNAVAILABLE,
})

#: Source attribuée à une origine déclarée que le code ne reconnaît pas.
SOURCE_INCONNUE = "source_inconnue"

#: Comparaisons : les sources sont normalisées en minuscules avant comparaison,
#: les constantes ci-dessus conservent leur casse d'affichage.
SOURCES_REELLES_NORMALISEES = frozenset(s.casefold() for s in SOURCES_REELLES)
SOURCES_CONNUES_NORMALISEES = frozenset(s.casefold() for s in SOURCES_CONNUES)
SIMULATION_SOURCES_NORMALISEES = frozenset(s.casefold() for s in SIMULATION_SOURCES)

#: Marqueurs de provenance portés par le message d'alerte.
#:
#: Ils garantissent qu'une alerte issue d'une mesure simulée ou d'une origine
#: non identifiée ne peut pas être lue comme un événement clinique, y
#: compris avant l'application de la migration qui porte les colonnes
#: `source` / `is_simulated`.
MARQUEUR_SIMULATION = "⚠ SIMULATION"
MARQUEUR_ORIGINE_INCONNUE = "⚠ ORIGINE NON IDENTIFIÉE"

#: Cache de l'état du schéma (colonnes de provenance présentes ou non).
_PROVENANCE_DISPONIBLE = {}


def provenance_kwargs(modele, source, is_simulated=False):
    """Champs de provenance à écrire sur une alerte.

    Aucun champ n'est nécessaire : la provenance est portée par le message
    (marqueur). La fonction reste pour le cas où un modèle exposerait un
    jour une colonne dédiée.
    """
    return {}


def marqueur_source(source, is_simulated=False):
    """Marqueur à apposer au message d'une alerte non clinique."""
    if is_simulated:
        return MARQUEUR_SIMULATION
    if source and not is_attestee(source):
        return MARQUEUR_ORIGINE_INCONNUE
    return ""


def source_depuis_message(message):
    """Relit la provenance portée par le message d'alerte.

    Retourne (source, is_simulated). Une alerte sans marqueur est une alerte
    clinique (héritage : le message n'a jamais été marqué).
    """
    if not message:
        return ("", False)
    if message.startswith(MARQUEUR_SIMULATION):
        return (SOURCE_SIMULATION, True)
    if message.startswith(MARQUEUR_ORIGINE_INCONNUE):
        return (SOURCE_INCONNUE, False)
    return ("", False)


def provenance_alerte(alerte):
    """Provenance d'une alerte : (source, is_simulated).

    La provenance est portée par le marqueur du message : aucun champ
    supplémentaire n'est nécessaire en base, donc aucune migration n'est à
    appliquer sur une base existante. Si le modèle expose un jour une
    colonne dédiée, elle est prioritaire.
    """
    source = (getattr(alerte, "source", "") or "").strip()
    simule = bool(getattr(alerte, "is_simulated", False))
    if source:
        return (source, simule)
    return source_depuis_message(getattr(alerte, "message", ""))


def normalise_source(source):
    """Source normalisée, en minuscules, pour comparaison."""
    return (source or "").strip().casefold()


def is_simulated(source):
    """Vrai si la mesure provient d'un simulateur et non d'un générateur.

    Une mesure simulée reste affichable, mais elle ne doit déclencher ni
    notification externe ni être présentée comme une mesure de machine.
    """
    if not source:
        return False
    norm = normalise_source(source)
    if norm in SIMULATION_SOURCES_NORMALISEES:
        return True
    return any(marker in norm for marker in SIMULATION_MARKERS)


def has_usable_values(values):
    """Vrai si au moins une valeur exploitable est présente.

    `values` : dictionnaire de mesures. Une réponse IA entièrement nulle
    n'est pas une mesure : c'est un échec de lecture.

    Attention : n'appliquer qu'aux **valeurs de mesure**. Une charge utile
    ne contenant que des métadonnées (`status`, `extracted`, `model`…)
    contient des chaînes et des entiers : elle serait sinon tenue pour une
    mesure exploitable.
    """
    if not values:
        return False
    for value in values.values():
        if value is None:
            continue
        if isinstance(value, bool):
            continue
        if isinstance(value, (int, float)):
            return True
        if isinstance(value, str) and value.strip() not in ("", "None", "null"):
            return True
    return False


def normalise_source_declaree(raw, defaut=SOURCE_HTTP_PUSH):
    """Assainit une source déclarée par un client.

    Un client contrôle le contenu de la charge utile : `_source` n'est donc
    pas une preuve. Seules les sources connues sont conservées telles
    quelles ; toute autre valeur devient `source_inconnue`, et les alertes
    qu'elle produit ne sont pas présentées comme des relevés cliniques.

    Retourne (source, declaree) : la source retenue et un booléen
    indiquant si elle a été fournie par le client.
    """
    if raw is None or str(raw).strip() == "":
        return (defaut, False)
    norm = str(raw).strip()
    if norm.casefold() in SOURCES_CONNUES_NORMALISEES:
        return (norm, True)
    return (SOURCE_INCONNUE, True)


def is_attestee(source):
    """Vrai si la source est connue et désigne un relevé réel.

    Une source vide (héritage : alerte créée avant la traçabilité) n'est
    ni attestée ni simulée : elle reste consultable, sans être présentée
    comme un relevé attesté.
    """
    if not source:
        return False
    return normalise_source(source) in SOURCES_REELLES_NORMALISEES


def est_alerte_clinique(source, is_simulated=False):
    """Une alerte est-elle présentée comme un événement clinique ?

    Faux si la mesure est simulée, ou si sa source n'est pas attestée
    (origine déclarée inconnue). Les alertes héritées (source vide) restent
    classées comme cliniques : on ne requalifie pas l'existant.
    """
    if is_simulated:
        return False
    if not source:
        return True
    return is_attestee(source)


def is_unavailable(status_validation):
    """Vrai si la mesure n'a pas pu être lue (aucune valeur exploitable)."""
    return (status_validation or "").strip().upper() in {
        VALIDATION_INVALID,
        VALIDATION_AI_UNAVAILABLE,
    }


def describe_source(source, status_validation=None):
    """Libellé lisible de la provenance, pour l'interface et les journaux."""
    if is_simulated(source):
        return "Simulateur (données synthétiques)"
    norm = normalise_source(source)
    if norm in (SOURCE_AI_OCR, SOURCE_AI_OLLAMA):
        return "Lecture automatique (IA)"
    if norm == SOURCE_AI_UNAVAILABLE:
        return "Source illisible (aucune mesure)"
    if norm in (SOURCE_TELEMETRY, SOURCE_HTTP_PUSH):
        return "Télémétrie du générateur"
    if is_unavailable(status_validation):
        return "Source illisible (aucune mesure)"
    return source or "Origine inconnue"
