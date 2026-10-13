"""Expose l'utilisateur applicatif et la navigation à tous les gabarits.

L'application n'utilise pas django.contrib.auth pour ses propres comptes :
l'identité vit dans request.session["app_user_id"] et @app_login_required la
pose sur request.current_user. Chaque vue devait donc penser à repasser
`current_user` dans son contexte — une vingtaine d'endroits — et les pages qui
l'oubliaient rendaient une navigation vide sans erreur.
"""

from accounts.models import User

from .navigation import build_nav


def current_user(request):
    user = getattr(request, "current_user", None)

    if user is None:
        user_id = request.session.get("app_user_id")
        if user_id:
            user = User.objects.select_related("role").filter(id=user_id).first()
            # Mémorisé sur la requête : le décorateur et ce processeur ne font
            # ainsi qu'une seule requête SQL par cycle.
            request.current_user = user

    return {
        "current_user": user,
        "nav_groups": build_nav(user, request),
    }
