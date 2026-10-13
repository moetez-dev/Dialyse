from django.urls import path
from . import views


app_name = "monitoring"


urlpatterns = [

    path(
        '',
        views.dashboard,
        name="dashboard"
    ),

    path(
        'surveillance/',
        views.surveillance_view,
        name="surveillance"
    ),

    path(
        'alerts-history/',
        views.alerts_history,
        name="alerts_history"
    ),

    path(
        'seances-history/',
        views.seances_history,
        name="seances_history"
    ),

    # Les boutons Acquitter / Résoudre des tableaux de bord postaient déjà ici ;
    # les routes manquaient, donc chaque clic recevait un 404 avalé par le .catch.
    path(
        'alert/<uuid:alert_id>/ack/',
        views.ack_alert,
        name="ack_alert"
    ),

    path(
        'alert/<uuid:alert_id>/resolve/',
        views.resolve_alert,
        name="resolve_alert"
    ),

]