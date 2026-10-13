import json

from django.http import JsonResponse
from django.shortcuts import render
from django.db.models import Q, Avg, Count
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from datetime import datetime, timedelta

from accounts.models import User, UserActivity
from accounts.decorator import app_login_required, role_required

from machines.models import Machine
from seances.models import Seance
from monitoring.models import LiveMeasurement, Alerte
from monitoring.services import check_thresholds
from django.http import JsonResponse
from monitoring.models import Alerte


def live_alerts(request):

    alerts = Alerte.objects.filter(
        status="NEW"
    ).order_by("-timestamp")[:10]


    data = []

    for alert in alerts:
        data.append({
            "niveau": alert.niveau,
            "message": alert.message,
            "status": alert.status,
        })


    return JsonResponse({
        "alerts": data
    })

def ia_conseil(request):
    return JsonResponse({"message": "Test ia_conseil"})

@app_login_required
@role_required("Admin", redirect_to="accounts:error")
def dashboard(request):
    current_user = request.current_user

    # KPIs (comme avant)
    # La carte est intitulée « Nombre total de docteurs » : ne compter que les docteurs.
    kpi_doctors = User.objects.filter(role__name__iexact="Docteur").count()
    kpi_nurses = User.objects.filter(role__name__iexact="Infirmier").count()
    # Ces deux KPI étaient codés en dur à 0 : la carte « Machines disponibles »
    # affichait toujours 0 quel que soit l'état du parc.
    kpi_machines_total = Machine.objects.count()
    kpi_machines_available = Machine.objects.filter(status="Prete").count()
    # « Actif » = vu récemment, et non le drapeau etat qui reste vrai quand un
    # utilisateur ferme son onglet sans se déconnecter.
    limit = timezone.now() - timedelta(minutes=5)
    kpi_active_users = User.objects.filter(etat=True, last_seen__gte=limit).count()

    # GET params (on garde day et on ajoute q/role/sort)
    selected_day = (request.GET.get("day") or "").strip()
    q = (request.GET.get("q") or "").strip()
    role_filter = (request.GET.get("role") or "").strip()
    sort = (request.GET.get("sort") or "-login_at").strip()
    status = (request.GET.get("status") or "").strip()   # <-- AJOUT

    allowed_sorts = {"login_at", "-login_at", "username", "-username"}
    if sort not in allowed_sorts:
        sort = "-login_at"

    # Base queryset
    qs = UserActivity.objects.select_related("user", "user__role")

    # Filtre par date (comme avant)
    if selected_day:
        qs = qs.filter(login_at__date=selected_day)

    # Recherche utilisateur (username ou email)
    if q:
        qs = qs.filter(
            Q(user__username__icontains=q) |
            Q(user__email__icontains=q)
        )

    # Filtre rôle (liste Docteur/Infirmier)
    if role_filter in ("Docteur", "Infirmier", "Admin"):
        qs = qs.filter(user__role__name__iexact=role_filter)
    
    
    if sort in ("username", "-username"):
        prefix = "-" if sort.startswith("-") else ""
        qs = qs.order_by(f"{prefix}user__username", "-login_at")
    else:
        qs = qs.order_by(sort)
    
    if status == "ongoing":

        qs = qs.filter(logout_at__isnull=True)

    activity_rows = qs[:50]

    context = {
        "current_user": current_user,
        "kpi_doctors": kpi_doctors,
        "kpi_nurses": kpi_nurses,
        "kpi_machines_total": kpi_machines_total,
        "kpi_machines_available": kpi_machines_available,
        "machines_hint": f"sur {kpi_machines_total} générateurs",
        "kpi_active_users": kpi_active_users,
        "activity_rows": activity_rows,
        # pour garder les valeurs dans dashboard.html
        "selected_day": selected_day,
        "q": q,
        "role_filter": role_filter,
        "sort": sort,
        "status":status,
    }
    return render(request, "dashboard.html", context)


@app_login_required
@role_required("Admin", "Docteur", "Infirmier", redirect_to="accounts:error")
def surveillance_view(request):
    current_user = request.current_user
    active_sessions = (
           Seance.objects.filter(status="en cours")
          .select_related("patient", "machine")
    )
    return render(request, "surveillance.html", {"current_user": current_user ,"sessions": active_sessions})
from django.http import JsonResponse
from django.utils import timezone


def live_data(request):

    sessions = []

    active_seances = Seance.objects.filter(
        status="en cours"
    ).select_related(
        "patient",
        "machine"
    )


    for seance in active_seances:

        last = LiveMeasurement.objects.filter(
            seance=seance
        ).order_by(
            "-timestamp"
        ).first()


        if last:

            sessions.append({
                "patient": str(seance.patient),
                "machine": str(seance.machine),

                "Qb": last.Debit_sang,
                "PA": last.PA,
                "PTM": last.PTM,
                "PV": last.PV,
                "UF": last.Volume_UF,

                "time": last.timestamp.isoformat()
            })


    alerts = []

    last_alerts = Alerte.objects.all().order_by(
        "-timestamp"
    )[:20]


    for alert in last_alerts:

        alerts.append({

    "id": str(alert.id),

    "niveau": alert.niveau,

    "message": alert.message,

    "status": alert.status,

    "time": alert.timestamp

})


    return JsonResponse({
        "sessions": sessions,
        "alerts": alerts,
        "last_update": timezone.now()
    })
@csrf_exempt
def real_monitoring(request):
    last = (
        LiveMeasurement.objects
        .select_related("seance__machine")
        .order_by("-timestamp")
        .first()
    )

    if not last:
        return JsonResponse({
            "measurements": []
        })

    return JsonResponse({
        "measurements": [
            {
                "machine": str(last.seance.machine),
                "Qb": last.Debit_sang,
                "PA": last.PA,
                "PTM": last.PTM,
                "PV": last.PV,
                "UF": last.Volume_UF,
                "time": last.timestamp.isoformat(),
            }
        ]
    })
def push_measurement(request):

    if request.method != "POST":
        return JsonResponse(
            {"error": "POST required"},
            status=405
        )

    try:
        data = json.loads(request.body)

        machine_id = data.get("machine_id")

        machine = Machine.objects.get(
            machine_id=machine_id
        )

        seance = Seance.objects.filter(
            machine=machine,
            status="en cours"
        ).first()

        if not seance:
            return JsonResponse({
                "error": "No active seance for this machine"
            }, status=400)


        measurement = LiveMeasurement.objects.create(
            seance=seance,
            Debit_sang=data.get("Qb"),
            Taux_UF=data.get("UF_rate"),
            PA=data.get("PA"),
            PTM=data.get("PTM"),
            PV=data.get("PV"),
            Volume_UF=data.get("UF_volume"),
            Heparine=data.get("Heparin"),
        )
        from monitoring.services import check_thresholds
        from monitoring.models import Alerte
        alerts = check_thresholds(measurement)

        for niveau, message in alerts:

            exists = Alerte.objects.filter(
                reading__seance=seance,
                niveau=niveau,
                message=message,
                timestamp__gte=timezone.now()-timedelta(minutes=5)
            ).exists()


            if not exists:
                Alerte.objects.create(
                    reading=measurement,
                    niveau=niveau,
                    message=message
                )


        return JsonResponse({
    "success": True,
    "id": str(measurement.id),
    "alerts_created": len(alerts)
})


    except Machine.DoesNotExist:
        return JsonResponse({
            "error": "Machine not found"
        }, status=404)


    except Exception as e:
        return JsonResponse({
            "error": str(e)
        }, status=500)


from django.shortcuts import get_object_or_404
from django.views.decorators.http import require_POST
@require_POST
@app_login_required
@role_required("Admin", "Docteur", "Infirmier", redirect_to="accounts:error")
def ack_alert(request, alert_id):

    alert = get_object_or_404(
        Alerte,
        id=alert_id
    )


    alert.status = "ACK"

    alert.save()


    return JsonResponse({
        "success": True,
        "message": "Alerte acquittée"
    })
@app_login_required
@role_required("Admin", "Docteur", "Infirmier", redirect_to="accounts:error")
def alerts_history(request):

    current_user = request.current_user

    alerts = (
        Alerte.objects
        .select_related(
            "reading",
            "reading__seance",
            "reading__seance__patient",
            "reading__seance__machine",
        )
        .order_by("-timestamp")
    )

    return render(
        request,
        "alerts_history.html",
        {
            "current_user": current_user,
            "alerts": alerts,

            "total_alerts": alerts.count(),
            "new_alerts": alerts.filter(status="NEW").count(),
            "ack_alerts": alerts.filter(status="ACK").count(),
            "resolved_alerts": alerts.filter(status="RESOLVED").count(),
        },
    )
@require_POST
@app_login_required
@role_required("Admin", "Docteur", "Infirmier", redirect_to="accounts:error")
def resolve_alert(request, alert_id):

    alert = get_object_or_404(
        Alerte,
        id=alert_id
    )

    alert.status = "RESOLVED"
    alert.save()

    return JsonResponse({
        "success": True,
        "message": "Alerte résolue"
    })
@app_login_required
@role_required("Admin", "Docteur", "Infirmier", redirect_to="accounts:error")
def seances_history(request):

    current_user = request.current_user

    seances = Seance.objects.select_related(
        "patient",
        "machine"
    ).prefetch_related(
        "readings__alertes"
    ).all().order_by("-session_date")


    for seance in seances:

        readings = seance.readings.all()

        seance.nb_alertes = sum(
            reading.alertes.count()
            for reading in readings
        )

        seance.avg_pa = readings.aggregate(
            Avg("PA")
        )["PA__avg"]

        seance.avg_qb = readings.aggregate(
            Avg("Debit_sang")
        )["Debit_sang__avg"]

        seance.avg_uf = readings.aggregate(
            Avg("Taux_UF")
        )["Taux_UF__avg"]


        if seance.session_date and seance.start_hour:

            start = datetime.combine(
                seance.session_date,
                seance.start_hour
            )

            seance.start_datetime = start

            seance.end_datetime = (
                start +
                timedelta(hours=seance.duration)
            )


    return render(
    request,
    "seances_history.html",
    {
        "seances": seances,
        "current_user": current_user
    }
)
   
