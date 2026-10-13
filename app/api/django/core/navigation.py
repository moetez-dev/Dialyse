"""Définition unique de la navigation latérale.

Avant, chaque entrée était une balise <a> écrite à la main dans sidebar.html,
avec un espacement, un arrondi et une couleur d'icône différents à chaque fois,
et un filtrage par comparaison de chaînes sur le nom du rôle. Tout est ici
désormais : le gabarit se contente de boucler.
"""

from django.urls import NoReverseMatch, reverse

# `cap` est le nom d'une propriété de capacité sur accounts.User
# (voir accounts/models.py). None = visible par tous les rôles.
NAV = [
    {
        "group": "Soins",
        "items": [
            {"label": "Tableau de bord", "url": "monitoring:dashboard",
             "icon": "layout-dashboard", "cap": "can_view_admin_dashboard"},
            {"label": "Surveillance", "url": "monitoring:surveillance",
             "icon": "monitor-heart", "cap": "can_view_clinical"},
            {"label": "Alertes", "url": "monitoring:alerts_history",
             "icon": "alert-triangle", "cap": "can_view_clinical"},
            {"label": "Séances", "url": "seances:planning",
             "icon": "calendar", "cap": "can_view_clinical"},
            {"label": "Historique des séances", "url": "monitoring:seances_history",
             "icon": "clock", "cap": "can_view_clinical"},
        ],
    },
    {
        "group": "Référentiel",
        "items": [
            {"label": "Patients", "url": "patients:patient",
             "icon": "users", "cap": "can_view_clinical"},
            {"label": "Machines", "url": "machines:machines",
             "icon": "waves", "cap": "can_manage_machines"},
            {"label": "Appareils de lecture", "url": "machines:raspi-management",
             "icon": "camera", "cap": "can_manage_devices"},
        ],
    },
    {
        "group": "Personnel",
        "items": [
            {"label": "Docteurs", "url": "accounts:docteurs",
             "icon": "stethoscope", "cap": "can_manage_doctors"},
            {"label": "Infirmiers", "url": "accounts:nurses",
             "icon": "user", "cap": "can_manage_nurses"},
        ],
    },
]


def build_nav(user, request):
    """Groupes de navigation visibles par cet utilisateur, état actif résolu."""
    if user is None:
        return []

    # Un rôle non géré par les vues n'a accès à rien : afficher la navigation
    # lui proposerait sept liens menant tous à un refus d'accès.
    if not getattr(user, "is_known_role", False):
        return []

    current = request.resolver_match.view_name if request.resolver_match else ""
    # Pendant le changement de mot de passe obligatoire, tout est inerte.
    locked = bool(getattr(user, "first_login", False))

    groups = []
    for group in NAV:
        items = []
        for item in group["items"]:
            if item["cap"] and not getattr(user, item["cap"], False):
                continue
            try:
                href = reverse(item["url"])
            except NoReverseMatch:
                # Une entrée mal nommée ne doit pas faire tomber toute la page.
                continue
            items.append({
                **item,
                "href": href,
                "active": current == item["url"],
                "locked": locked,
            })
        if items:
            groups.append({"group": group["group"], "items": items})
    return groups
