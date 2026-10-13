from functools import wraps
from django.shortcuts import redirect
from django.contrib import messages
from .models import User

def app_login_required(view_func):
    @wraps(view_func)
    def _wrapped(request, *args, **kwargs):
        user_id = request.session.get("app_user_id")
        if not user_id:
            return redirect("accounts:login_view")

        try:
            request.current_user = User.objects.select_related("role").get(id=user_id)
        except User.DoesNotExist:
            request.session.flush()
            return redirect("accounts:login_view")
        if request.current_user.first_login:
            # Le nom de l'URL doit être EXACTEMENT celui de urls.py
            if request.resolver_match.url_name not in ["profile", "logout"]:
                messages.error(request, "Vous devez changer votre mot de passe avant d’accéder au site.")
                return redirect("accounts:profile")

        return view_func(request, *args, **kwargs)
    return _wrapped

# "accounts:home" n'existe pas : tout appel omettant le kwarg levait un
# NoReverseMatch au moment du refus. Tous les sites d'appel passent déjà
# "accounts:error", qui devient la valeur par défaut.
def role_required(*allowed_roles, redirect_to="accounts:error"):
    def decorator(view_func):
        @wraps(view_func)
        def _wrapped(request, *args, **kwargs):
            user = getattr(request, "current_user", None)
            if not user:
                return redirect("accounts:login_view")

            role_name = user.role_slug
            allowed = {r.lower() for r in allowed_roles}

            if role_name not in allowed:
                return redirect(redirect_to)

            return view_func(request, *args, **kwargs)
        return _wrapped
    return decorator
