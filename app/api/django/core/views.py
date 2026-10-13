from django.shortcuts import redirect, render

from accounts.models import User


def landing(request):
    """Page d'accueil publique.

    Un visiteur déjà connecté n'a rien à faire ici : on l'envoie directement
    vers son espace de travail, comme le fait ``login_view`` après connexion.
    """
    user_id = request.session.get("app_user_id")
    if user_id:
        user = User.objects.filter(id=user_id).first()
        if user:
            if user.first_login:
                return redirect("accounts:profile")
            return redirect("monitoring:surveillance")
        # Session orpheline (utilisateur supprimé) : on repart propre.
        request.session.flush()

    return render(request, "landing.html")
