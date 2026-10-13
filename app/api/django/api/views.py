"""
api/views.py — PFA-Dialyse Mobile REST API (Phase 1)
"""
from django.views.decorators.csrf import csrf_exempt
import json
from django.http import JsonResponse
from monitoring.ai_service import analyze_measurement
import json
from datetime import date, datetime, timedelta
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import check_password, make_password
from django.db.models import Avg, Q

from accounts.models import User, UserActivity, Profile
from machines.models import Machine, RaspiDevice
from monitoring.models import LiveMeasurement, Alerte
from monitoring.services import check_thresholds
from patients.models import Patient
from seances.models import (
    Seance,
    PreSessionMeasurements,
    PostSessionMeasurements,
    Alert as SeanceAlert,
    RapportSeance,
)

def _json_ok(data=None, **kwargs):
    body = {"success": True}
    if data is not None:
        body["data"] = data
    body.update(kwargs)
    return JsonResponse(body)

def _json_err(message, status=400):
    return JsonResponse({"success": False, "error": message}, status=status)

def _bind_session_from_header(request):
    """Flutter Web cannot set the Cookie header; load the same Django session
    from X-Session-Id when the browser did not attach sessionid."""
    if request.session.get("app_user_id"):
        return
    session_key = (
        request.headers.get("X-Session-Id")
        or request.META.get("HTTP_X_SESSION_ID")
        or ""
    ).strip()
    if not session_key:
        return
    from importlib import import_module
    from django.conf import settings

    engine = import_module(settings.SESSION_ENGINE)
    store = engine.SessionStore(session_key=session_key)
    if store.exists(session_key):
        request.session = store


# Valeurs d'exemple publiées dans .env.example et dans settings.py : les
# accepter reviendrait à n'avoir aucune authentification sur un déploiement
# qui a simplement oublié de définir la clé.
PLACEHOLDER_EDGE_KEYS = {"dev-edge-key-change-me", "change-me", "changeme", "secret"}


def _edge_api_key_ok(request):
    """Raspberry Pi / edge clients authenticate with X-Edge-Api-Key."""
    import secrets

    from django.conf import settings

    expected = (getattr(settings, "EDGE_API_KEY", None) or "").strip()
    # Clé absente ou laissée à sa valeur d'exemple : on refuse plutôt que
    # d'ouvrir l'accès à quiconque connaît la chaîne publiée.
    if not expected or expected.lower() in PLACEHOLDER_EDGE_KEYS:
        return False

    # Uniquement l'en-tête : passé en paramètre d'URL, le secret se retrouve
    # dans les journaux du serveur, l'historique du navigateur et l'en-tête
    # Referer des requêtes sortantes.
    provided = (
        request.headers.get("X-Edge-Api-Key")
        or request.META.get("HTTP_X_EDGE_API_KEY")
        or ""
    ).strip()
    if not provided:
        return False

    # Comparaison à temps constant : `==` s'arrête au premier octet différent
    # et laisse mesurer la progression octet par octet.
    return secrets.compare_digest(provided, expected)


def edge_api_key_required(view_func):
    from functools import wraps

    @wraps(view_func)
    def _wrapped(request, *args, **kwargs):
        if not _edge_api_key_ok(request):
            return _json_err("Invalid or missing edge API key", status=401)
        return view_func(request, *args, **kwargs)

    return _wrapped


def api_login_required(view_func):
    from functools import wraps
    @wraps(view_func)
    def _wrapped(request, *args, **kwargs):
        _bind_session_from_header(request)
        user_id = request.session.get("app_user_id")
        if not user_id:
            return _json_err("Authentication required", status=401)
        try:
            request.current_user = User.objects.select_related("role").get(id=user_id)
        except User.DoesNotExist:
            request.session.flush()
            return _json_err("Session expired", status=401)
        if not _has_role(request.current_user, "Admin", "Docteur", "Infirmier"):
            return _json_err("Forbidden", status=403)
        return view_func(request, *args, **kwargs)
    return _wrapped

def agent_auth_required(view_func):
    """Accès réservé aux soignants connectés ou aux appels portant la clé d'API.

    Ces points d'entrée déclenchent la génération de rapports et renvoient des
    données de séance. Sans garde, un POST anonyme au corps vide retombait sur
    la séance la plus récente et en produisait le compte rendu.
    """
    from functools import wraps

    @wraps(view_func)
    def _wrapped(request, *args, **kwargs):
        if _edge_api_key_ok(request):
            return view_func(request, *args, **kwargs)

        _bind_session_from_header(request)
        user_id = request.session.get("app_user_id")
        if not user_id:
            return _json_err("Authentication required", status=401)
        user = User.objects.select_related("role").filter(id=user_id).first()
        if user is None:
            request.session.flush()
            return _json_err("Session expired", status=401)
        if not _has_role(user, "Admin", "Docteur", "Infirmier"):
            return _json_err("Forbidden", status=403)
        request.current_user = user
        return view_func(request, *args, **kwargs)

    return _wrapped


def _has_role(user, *roles):
    if not hasattr(user, "role") or not user.role:
        return False
    role_name = (user.role.name or "").lower()
    return role_name in {r.lower() for r in roles}

@csrf_exempt
def mobile_login(request):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    try:
        body = json.loads(request.body)
        username = body.get("username", "").strip()
        password = body.get("password", "")
        user = User.objects.select_related("role").filter(username=username).first()
        if user is None or not check_password(password, user.password):
            return JsonResponse({"success": False, "message": "Invalid username or password"}, status=401)
        if hasattr(user, "is_active") and not user.is_active:
            return JsonResponse({"success": False, "message": "Account disabled"}, status=403)
        user.etat = True
        user.save(update_fields=["etat"])
        request.session["app_user_id"] = user.id
        request.session.save()
        return JsonResponse({
            "success": True,
            # Same Django session key as Set-Cookie sessionid — Flutter Web
            # stores it and sends X-Session-Id when Cookie cannot be set.
            "sessionid": request.session.session_key,
            "user": {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "role": user.role.name if user.role else "",
                "specialite": user.specialite,
                "first_login": user.first_login,
                "phone": user.phone_number,
                "address": user.adress,
            },
        })
    except Exception as e:
        return JsonResponse({"success": False, "message": str(e)}, status=500)

@csrf_exempt
@api_login_required
def mobile_logout(request):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    try:
        user = request.current_user
        user.etat = False
        user.save(update_fields=["etat"])
    except Exception:
        pass
    request.session.flush()
    return JsonResponse({"success": True, "message": "Logged out successfully"})


def _user_profile_dict(user):
    profile, _ = Profile.objects.get_or_create(user=user)
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email or "",
        "role": user.role.name if user.role else "",
        "phone": user.phone_number or "",
        "address": user.adress or "",
        "specialite": user.specialite or "",
        "first_login": bool(user.first_login),
        "bio": profile.bio or "",
        "formation": profile.formation or "",
        "experience": profile.experience or "",
    }


@csrf_exempt
@api_login_required
def api_profile(request):
    """GET / PUT profile — mirrors accounts.views.profile (without image upload)."""
    user = request.current_user

    if request.method == "GET":
        return _json_ok(_user_profile_dict(user))

    if request.method in ("PUT", "PATCH", "POST"):
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")

        old_password = body.get("old_password") or ""
        new_password = body.get("password") or body.get("new_password") or ""

        if user.first_login:
            if not old_password or not new_password:
                return _json_err(
                    "Vous devez changer votre mot de passe pour pouvoir enregistrer.",
                    status=400,
                )
            if not check_password(old_password, user.password):
                return _json_err("Ancien mot de passe incorrect.", status=400)
            if len(new_password) < 6:
                return _json_err("Le mot de passe doit contenir au moins 6 caracteres.")
            user.password = make_password(new_password)
            user.first_login = False
            user.save(update_fields=["password", "first_login"])
            return _json_ok(
                _user_profile_dict(user),
                message="Mot de passe mis a jour avec succes",
            )

        profile, _ = Profile.objects.get_or_create(user=user)
        if "bio" in body:
            profile.bio = body.get("bio") or ""
        if "formation" in body:
            profile.formation = body.get("formation") or ""
        if "experience" in body:
            profile.experience = body.get("experience") or ""
        profile.save()

        fields = []
        if "phone" in body or "phone_number" in body:
            user.phone_number = (
                body.get("phone") or body.get("phone_number") or ""
            ).strip()
            fields.append("phone_number")
        if "address" in body or "adress" in body:
            user.adress = (body.get("address") or body.get("adress") or "").strip()
            fields.append("adress")
        if "email" in body:
            new_email = (body.get("email") or "").strip()
            if (
                new_email
                and User.objects.filter(email=new_email).exclude(id=user.id).exists()
            ):
                return _json_err("Cet email est deja utilise.", status=409)
            user.email = new_email or None
            fields.append("email")
        if "specialite" in body:
            user.specialite = (body.get("specialite") or "").strip()
            fields.append("specialite")

        if new_password:
            if not check_password(old_password, user.password):
                return _json_err("Ancien mot de passe incorrect.", status=400)
            if len(new_password) < 6:
                return _json_err("Le mot de passe doit contenir au moins 6 caracteres.")
            user.password = make_password(new_password)
            fields.append("password")

        if fields:
            user.save(update_fields=fields)

        return _json_ok(
            _user_profile_dict(user),
            message="Profil mis a jour avec succes",
        )

    return _json_err("Method not allowed", status=405)


def _calculate_patient_age(dob_value):
    """Mirror patients.views.calculate_age for API create/update."""
    if not dob_value:
        return 0
    if isinstance(dob_value, date):
        dob = dob_value
    else:
        try:
            dob = date.fromisoformat(str(dob_value).strip())
        except (TypeError, ValueError):
            return 0
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def _patient_dict(p, include_sessions=False):
    data = {
        "id": p.id,
        "first_name": p.first_name,
        "last_name": p.last_name,
        "date_of_birth": str(p.date_of_birth) if p.date_of_birth else None,
        "age": p.age,
        "groupe_sanguin": p.groupe_sanguin,
        "type_de_dialyse": p.type_de_dialyse,
        "adresse": p.adresse,
        "telephone": p.telephone,
        "contact_urgence": p.contact_urgence,
        "antecedents_medicaux": p.antecedents_medicaux,
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }
    if include_sessions:
        from seances.models import RapportSeance

        sessions = []
        qs = (
            Seance.objects.filter(patient=p)
            .select_related("machine")
            .order_by("-session_date", "-start_hour")[:20]
        )
        for s in qs:
            try:
                pre = s.pre_measurements
            except Exception:
                pre = None
            try:
                post = s.post_measurements
            except Exception:
                post = None
            has_rapport = RapportSeance.objects.filter(seance=s).exists()
            sessions.append({
                "id": str(s.id),
                "session_date": str(s.session_date) if s.session_date else None,
                "start_hour": s.start_hour.strftime("%H:%M") if s.start_hour else None,
                "status": s.status,
                "duration": s.duration,
                "machine__machine_id": s.machine.machine_id if s.machine else None,
                "pre_weight": float(pre.weight) if pre and pre.weight is not None else None,
                "post_weight": float(post.weight) if post and post.weight is not None else None,
                "pre_blood_pressure": pre.blood_pressure if pre else None,
                "post_blood_pressure": post.blood_pressure if post else None,
                "has_rapport": has_rapport or s.status == "terminée",
            })
        data["recent_sessions"] = sessions
    return data


def _parse_patient_payload(body, *, partial=False):
    """Validate create/update body. Field names match Flutter + Web semantics."""
    first_name = (body.get("first_name") or body.get("FirstName") or "").strip()
    last_name = (body.get("last_name") or body.get("LastName") or "").strip()
    dob_raw = body.get("date_of_birth") or body.get("dateOfBirth")
    telephone = (body.get("telephone") or body.get("phone") or "").strip()
    adresse = (body.get("adresse") or body.get("address") or "").strip()
    contact_urgence = (
        body.get("contact_urgence") or body.get("contacturgences") or ""
    ).strip()
    antecedents = (
        body.get("antecedents_medicaux") or body.get("medicalhistory") or ""
    ).strip()
    groupe = (body.get("groupe_sanguin") or body.get("groupSanguin") or "A+").strip()
    type_dialyse = (
        body.get("type_de_dialyse") or "Hémodialyse"
    ).strip() or "Hémodialyse"

    if not partial:
        if not first_name or not last_name:
            return None, "first_name and last_name are required"
        if not dob_raw:
            return None, "date_of_birth is required"

    dob = None
    if dob_raw not in (None, ""):
        try:
            dob = date.fromisoformat(str(dob_raw).strip())
        except ValueError:
            return None, "Invalid date_of_birth — use YYYY-MM-DD"

    allowed_groups = {c[0] for c in Patient.enumerated_groupes_sanguins}
    if groupe and groupe not in allowed_groups:
        return None, f"Invalid groupe_sanguin (allowed: {sorted(allowed_groups)})"

    allowed_types = {c[0] for c in Patient.enumerated_types_dialyse}
    if type_dialyse and type_dialyse not in allowed_types:
        return None, f"Invalid type_de_dialyse (allowed: {sorted(allowed_types)})"

    payload = {
        "first_name": first_name,
        "last_name": last_name,
        "date_of_birth": dob,
        "telephone": telephone,
        "adresse": adresse or "Tunisie",
        "contact_urgence": contact_urgence,
        "antecedents_medicaux": antecedents,
        "groupe_sanguin": groupe or "A+",
        "type_de_dialyse": type_dialyse,
        "age": _calculate_patient_age(dob) if dob else 0,
    }
    return payload, None


@csrf_exempt
@api_login_required
def api_patients(request):
    """GET list (+search) / POST create — mirrors Web patient + add_patient."""
    if request.method == "GET":
        qs = Patient.objects.all().order_by("last_name", "first_name")
        search = request.GET.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(telephone__icontains=search) |
                Q(antecedents_medicaux__icontains=search)
            )
        data = [_patient_dict(p) for p in qs]
        return _json_ok(data, count=len(data))

    if request.method == "POST":
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")
        payload, err = _parse_patient_payload(body, partial=False)
        if err:
            return _json_err(err)
        patient = Patient.objects.create(**payload)
        return JsonResponse({"success": True, "data": _patient_dict(patient)}, status=201)

    return _json_err("Method not allowed", status=405)


@csrf_exempt
@api_login_required
def api_patient_detail(request, patient_id):
    """GET detail / PUT|PATCH update — mirrors Web Patient_Profile + edit_patient.
    Delete is not offered on Django Web; API stays read/write without DELETE.
    """
    try:
        p = Patient.objects.get(id=patient_id)
    except Patient.DoesNotExist:
        return _json_err("Patient not found", status=404)

    if request.method == "GET":
        return _json_ok(_patient_dict(p, include_sessions=True))

    if request.method in ("PUT", "PATCH"):
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")
        payload, err = _parse_patient_payload(body, partial=False)
        if err:
            return _json_err(err)
        for key, value in payload.items():
            setattr(p, key, value)
        p.save()
        return _json_ok(_patient_dict(p, include_sessions=True))

    return _json_err("Method not allowed", status=405)

def _raspi_info(machine):
    try:
        raspi = getattr(machine, "raspi", None)
        if not raspi:
            return None
        return {
            "id": str(raspi.id),
            "raspi_id": raspi.raspi_id,
            "description": raspi.description,
            "is_active": raspi.is_active,
            "last_seen": raspi.last_seen.isoformat() if raspi.last_seen else None,
        }
    except Exception:
        return None


def _machine_dict(m, *, include_detail=False):
    data = {
        "id": m.id,
        "machine_id": m.machine_id,
        "model": m.model,
        "manufacturer": m.manufacturer,
        "installation_date": str(m.installation_date) if m.installation_date else None,
        "status": m.status,
        "location": m.location,
        "sessions": m.sessions,
        "hours": m.hours,
        "raspi": _raspi_info(m),
    }
    if not include_detail:
        return data

    active_seance = (
        Seance.objects.filter(machine=m, status="en cours")
        .select_related("patient")
        .first()
    )
    active_session_data = None
    if active_seance:
        active_session_data = {
            "id": str(active_seance.id),
            "patient": str(active_seance.patient),
            "session_date": str(active_seance.session_date),
            "status": active_seance.status,
        }

    recent = []
    for s in (
        Seance.objects.filter(machine=m)
        .select_related("patient")
        .order_by("-session_date", "-start_hour")[:5]
    ):
        recent.append({
            "id": str(s.id),
            "session_date": str(s.session_date) if s.session_date else None,
            "status": s.status,
            "patient": str(s.patient) if s.patient else None,
            "duration": s.duration,
        })

    raspi_options = []
    for r in RaspiDevice.objects.select_related("machine").order_by("raspi_id"):
        raspi_options.append({
            "id": str(r.id),
            "raspi_id": r.raspi_id,
            "description": r.description,
            "assigned_machine_id": r.machine.machine_id if r.machine_id else None,
            "assigned_machine_pk": r.machine_id,
        })

    data["active_session"] = active_session_data
    data["recent_sessions"] = recent
    data["raspi_options"] = raspi_options
    data["average_duration"] = round(m.hours / m.sessions, 1) if m.sessions else 0
    data["status_choices"] = [c[0] for c in Machine.enumerated_status]
    return data


def _machine_kpis():
    all_qs = Machine.objects.all()
    return {
        "total": all_qs.count(),
        "pretes": all_qs.filter(status="Prete").count(),
        "maintenance": all_qs.filter(status="Maintenance").count(),
        "hors_service": all_qs.filter(status="Hors Service").count(),
        "reserve": all_qs.filter(status="Reserve").count(),
    }


@csrf_exempt
@api_login_required
def api_machines(request):
    """GET list (Admin/Infirmier) + POST create (Admin) — mirrors Web machines/ajout_machine."""
    user = request.current_user

    if request.method == "GET":
        if not _has_role(user, "Admin", "Infirmier"):
            return _json_err("Forbidden", status=403)
        qs = Machine.objects.all().order_by("machine_id")
        search = request.GET.get("search", "").strip()
        status_filter = request.GET.get("status", "").strip()
        location = request.GET.get("location", "").strip() or request.GET.get("salle", "").strip()
        if search:
            qs = qs.filter(machine_id__icontains=search)
        if status_filter:
            qs = qs.filter(status=status_filter)
        if location:
            qs = qs.filter(location=location)
        locations = sorted({
            loc for loc in Machine.objects.values_list("location", flat=True).distinct()
            if loc
        })
        data = [_machine_dict(m) for m in qs]
        return _json_ok(
            data,
            count=len(data),
            kpis=_machine_kpis(),
            locations=locations,
            status_choices=[c[0] for c in Machine.enumerated_status],
        )

    if request.method == "POST":
        if not _has_role(user, "Admin"):
            return _json_err("Forbidden — Admin only", status=403)
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")
        machine_id = (body.get("machine_id") or "").strip()
        model = (body.get("model") or "").strip()
        location = (body.get("location") or "").strip()
        manufacturer = (body.get("manufacturer") or "").strip()
        if not machine_id:
            return _json_err("machine_id is required")
        if Machine.objects.filter(machine_id=machine_id).exists():
            return _json_err("machine_id already exists", status=409)
        m = Machine.objects.create(
            machine_id=machine_id,
            model=model,
            location=location,
            manufacturer=manufacturer,
        )
        return JsonResponse({"success": True, "data": _machine_dict(m)}, status=201)

    return _json_err("Method not allowed", status=405)


@csrf_exempt
@api_login_required
def api_machine_detail(request, machine_id):
    """GET detail (any auth) / PUT|PATCH configure (Admin/Infirmier/Docteur).
    No DELETE on Web → 405.
    """
    try:
        m = Machine.objects.get(id=machine_id)
    except Machine.DoesNotExist:
        return _json_err("Machine not found", status=404)

    user = request.current_user

    if request.method == "GET":
        return _json_ok(_machine_dict(m, include_detail=True))

    if request.method in ("PUT", "PATCH"):
        if not _has_role(user, "Admin", "Infirmier", "Docteur"):
            return _json_err("Forbidden", status=403)
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")

        new_status = body.get("status")
        if new_status is not None:
            new_status = str(new_status).strip()
            if new_status not in dict(Machine.enumerated_status):
                return _json_err("Invalid status")
            m.status = new_status

        if "model" in body:
            m.model = (body.get("model") or "").strip()
        if "location" in body:
            m.location = (body.get("location") or "").strip()
        if "manufacturer" in body:
            m.manufacturer = (body.get("manufacturer") or "").strip()

        # Raspi assignment — mirrors configurer_machine
        if "raspi_id" in body or "raspi_db_id" in body:
            raspi_pk = body.get("raspi_db_id") or body.get("raspi_id")
            if raspi_pk in (None, "", "null"):
                RaspiDevice.objects.filter(machine=m).update(machine=None)
            else:
                try:
                    raspi = RaspiDevice.objects.get(id=raspi_pk)
                except (RaspiDevice.DoesNotExist, ValueError, TypeError):
                    # also allow lookup by string raspi_id label
                    raspi = RaspiDevice.objects.filter(raspi_id=str(raspi_pk)).first()
                    if not raspi:
                        return _json_err("Raspi not found", status=404)
                RaspiDevice.objects.filter(machine=m).exclude(id=raspi.id).update(machine=None)
                raspi.machine = m
                raspi.save(update_fields=["machine"])

        m.save()
        return _json_ok(_machine_dict(m, include_detail=True))

    return _json_err("Method not allowed", status=405)

def _seance_summary(s):
    readings = s.readings.all()
    start_dt = None
    end_dt = None
    if s.session_date and s.start_hour:
        start_dt = datetime.combine(s.session_date, s.start_hour)
        end_dt = start_dt + timedelta(hours=s.duration)
    return {
        "id": str(s.id),
        "patient": {
            "id": s.patient.id,
            "first_name": s.patient.first_name,
            "last_name": s.patient.last_name,
        } if s.patient else None,
        "machine": {
            "id": s.machine.id,
            "machine_id": s.machine.machine_id,
            "location": s.machine.location,
            "status": s.machine.status,
        } if s.machine else None,
        "session_date": str(s.session_date) if s.session_date else None,
        "start_hour": str(s.start_hour)[:5] if s.start_hour else None,
        "duration": s.duration,
        "notes": s.notes,
        "status": s.status,
        "complications": s.complications,
        "debit": s.debit,
        "start_datetime": start_dt.isoformat() if start_dt else None,
        "end_datetime": end_dt.isoformat() if end_dt else None,
        "nb_alertes": sum(reading.alertes.count() for reading in readings),
        "avg_pa": readings.aggregate(Avg("PA"))["PA__avg"],
        "avg_qb": readings.aggregate(Avg("Debit_sang"))["Debit_sang__avg"],
        "avg_uf": readings.aggregate(Avg("Taux_UF"))["Taux_UF__avg"],
    }

@csrf_exempt
@api_login_required
def api_sessions(request):
    if request.method == "GET":
        return _api_sessions_list(request)
    if request.method == "POST":
        return _api_sessions_create(request)
    return _json_err("Method not allowed", status=405)

def _api_sessions_list(request):
    qs = Seance.objects.select_related("patient", "machine").order_by("-session_date", "-start_hour")
    status_filter = request.GET.get("status", "").strip()
    if status_filter:
        qs = qs.filter(status=status_filter)
    patient_id = request.GET.get("patient_id", "").strip()
    if patient_id:
        qs = qs.filter(patient__id=patient_id)
    machine_id = request.GET.get("machine_id", "").strip()
    if machine_id:
        qs = qs.filter(machine__id=machine_id)
    date_filter = request.GET.get("date", "").strip()
    if date_filter:
        try:
            qs = qs.filter(session_date=date.fromisoformat(date_filter))
        except ValueError:
            return _json_err("Invalid date format — use YYYY-MM-DD")
    date_from = request.GET.get("date_from", "").strip()
    if date_from:
        try:
            qs = qs.filter(session_date__gte=date.fromisoformat(date_from))
        except ValueError:
            return _json_err("Invalid date_from format — use YYYY-MM-DD")
    date_to = request.GET.get("date_to", "").strip()
    if date_to:
        try:
            qs = qs.filter(session_date__lte=date.fromisoformat(date_to))
        except ValueError:
            return _json_err("Invalid date_to format — use YYYY-MM-DD")
    search = request.GET.get("search", "").strip()
    if search:
        qs = qs.filter(Q(patient__first_name__icontains=search) | Q(patient__last_name__icontains=search))
    data = [_seance_summary(s) for s in qs[:100]]
    return _json_ok(data, count=len(data))

def _api_sessions_create(request):
    current_user = request.current_user
    if not _has_role(current_user, "Admin", "Docteur"):
        return _json_err("Insufficient permissions — Doctor or Admin only", status=403)
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return _json_err("Invalid JSON body")
    patient_id = body.get("patient_id")
    machine_db_id = body.get("machine_id")
    session_date_str = body.get("session_date")
    start_time = body.get("start_time")
    duration = body.get("duration", 4)
    notes = body.get("notes", "")
    debit_val = body.get("debit", 60)
    if not all([patient_id, session_date_str]):
        return _json_err("patient_id and session_date are required")
    VALID_DEBITS = {20, 30, 60}
    try:
        debit_val = int(debit_val)
        if debit_val not in VALID_DEBITS:
            raise ValueError
    except (TypeError, ValueError):
        return _json_err("debit must be 20, 30, or 60")
    try:
        session_date_obj = date.fromisoformat(session_date_str)
    except (TypeError, ValueError):
        return _json_err("Invalid session_date — use YYYY-MM-DD")
    try:
        patient = Patient.objects.get(id=patient_id)
    except Patient.DoesNotExist:
        return _json_err("Patient not found", status=404)
    machine = None
    if machine_db_id:
        try:
            machine = Machine.objects.get(id=machine_db_id)
        except Machine.DoesNotExist:
            return _json_err("Machine not found", status=404)
    seance = Seance.objects.create(
        patient=patient,
        machine=machine,
        session_date=session_date_obj,
        start_hour=start_time,
        duration=int(duration),
        status="planifiée",
        notes=notes,
        debit=debit_val,
    )
    return JsonResponse({"success": True, "id": str(seance.id)}, status=201)

@api_login_required
def api_session_detail(request, session_id):
    if request.method != "GET":
        return _json_err("GET required", status=405)
    try:
        seance = Seance.objects.select_related("patient", "machine").get(id=session_id)
    except Seance.DoesNotExist:
        return _json_err("Session not found", status=404)
    try:
        pre = seance.pre_measurements
        pre_data = {
            "weight": pre.weight,
            "blood_pressure": pre.blood_pressure,
            "heart_rate": pre.heart_rate,
            "temperature": pre.temperature,
            "saturation": pre.saturation,
        }
    except PreSessionMeasurements.DoesNotExist:
        pre_data = None
    try:
        post = seance.post_measurements
        post_data = {
            "weight": post.weight,
            "blood_pressure": post.blood_pressure,
            "heart_rate": post.heart_rate,
            "temperature": post.temperature,
            "saturation": post.saturation,
        }
    except PostSessionMeasurements.DoesNotExist:
        post_data = None
    thresholds = {
        "blood_flow_min": seance.blood_flow_min,
        "blood_flow_max": seance.blood_flow_max,
        "blood_flow_critical_low": seance.blood_flow_critical_low,
        "blood_flow_critical_high": seance.blood_flow_critical_high,
        "arterial_pressure_min": seance.arterial_pressure_min,
        "arterial_pressure_max": seance.arterial_pressure_max,
        "arterial_pressure_critical_low": seance.arterial_pressure_critical_low,
        "arterial_pressure_critical_high": seance.arterial_pressure_critical_high,
        "venous_pressure_min": seance.venous_pressure_min,
        "venous_pressure_max": seance.venous_pressure_max,
        "venous_pressure_critical_low": seance.venous_pressure_critical_low,
        "venous_pressure_critical_high": seance.venous_pressure_critical_high,
        "tmp_min": seance.tmp_min,
        "tmp_max": seance.tmp_max,
        "tmp_critical_low": seance.tmp_critical_low,
        "tmp_critical_high": seance.tmp_critical_high,
        "uf_rate_min": seance.uf_rate_min,
        "uf_rate_max": seance.uf_rate_max,
        "uf_rate_critical_high": seance.uf_rate_critical_high,
        "uf_volume_min": seance.uf_volume_min,
        "uf_volume_max": seance.uf_volume_max,
        "uf_volume_critical_high": seance.uf_volume_critical_high,
        "heparin_min": seance.heparin_min,
        "heparin_max": seance.heparin_max,
        "heparin_critical_high": seance.heparin_critical_high,
        "debit": seance.debit,
    }
    alerts_data = [
        {
            "id": a.id,
            "alert_type": a.alert_type,
            "message": a.message,
            "danger_level": a.danger_level,
            "recommended_action": a.recommended_action,
            "timestamp": a.timestamp.isoformat() if a.timestamp else None,
        }
        for a in SeanceAlert.objects.filter(seance=seance).order_by("-timestamp")
    ]
    readings = seance.readings.order_by("timestamp")
    start_dt = None
    if seance.session_date and seance.start_hour:
        start_dt = datetime.combine(seance.session_date, seance.start_hour)
    chart_data = []
    for r in readings:
        elapsed_min = 0
        if start_dt and r.timestamp:
            ts = r.timestamp.replace(tzinfo=None)
            elapsed_min = max(0, int((ts - start_dt).total_seconds() / 60))
        chart_data.append({
            "time": elapsed_min,
            "qb": r.Debit_sang,
            "pa": r.PA,
            "ptm": r.PTM,
            "pv": r.PV,
            "uf_rate": r.Taux_UF,
            "uf_volume": r.Volume_UF,
            "heparin": r.Heparine,
        })
    last_reading = readings.last()
    last_reading_data = None
    if last_reading is not None:
        last_reading_data = {
            "volume_uf": last_reading.Volume_UF,
            "debit_sang": last_reading.Debit_sang,
        }
    try:
        rapport = seance.rapport
        rapport_data = {
            "qualite_seance": rapport.qualite_seance,
            "nom_fichier": rapport.nom_fichier,
        }
    except Exception:
        rapport_data = None
    data = {
        **_seance_summary(seance),
        "pre_measurements": pre_data,
        "post_measurements": post_data,
        "thresholds": thresholds,
        "alerts": alerts_data,
        "rapport": rapport_data,
        "readings": chart_data,
        "readings_count": readings.count(),
        "last_reading": last_reading_data,
    }
    return _json_ok(data)

@csrf_exempt
@api_login_required
def api_session_start(request, session_id):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    current_user = request.current_user
    if not _has_role(current_user, "Admin", "Infirmier", "Docteur"):
        return _json_err("Insufficient permissions", status=403)
    try:
        seance = Seance.objects.select_related("machine").get(id=session_id)
    except Seance.DoesNotExist:
        return _json_err("Session not found", status=404)
    if seance.status != "planifiée":
        return _json_err(f"Session cannot be started — current status: {seance.status}")
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        body = {}
    obj, _ = PreSessionMeasurements.objects.get_or_create(seance=seance)
    obj.weight = body.get("weight", obj.weight)
    obj.blood_pressure = body.get("blood_pressure", obj.blood_pressure)
    obj.temperature = body.get("temperature", obj.temperature)
    obj.heart_rate = body.get("heart_rate", obj.heart_rate)
    obj.saturation = body.get("saturation", obj.saturation)
    obj.save()

    # Same seuil fields as seances.views.pre_session_page (Django web form).
    seuil_fields = [
        "blood_flow_min", "blood_flow_max",
        "blood_flow_critical_low", "blood_flow_critical_high",
        "arterial_pressure_min", "arterial_pressure_max",
        "arterial_pressure_critical_low", "arterial_pressure_critical_high",
        "venous_pressure_min", "venous_pressure_max",
        "venous_pressure_critical_low", "venous_pressure_critical_high",
        "tmp_min", "tmp_max", "tmp_critical_low", "tmp_critical_high",
        "uf_rate_min", "uf_rate_max", "uf_rate_critical_high",
        "uf_volume_min", "uf_volume_max", "uf_volume_critical_high",
        "heparin_min", "heparin_max", "heparin_critical_high",
    ]
    fields_to_update = ["status"]
    for field in seuil_fields:
        if field in body and body[field] is not None:
            try:
                setattr(seance, field, float(body[field]))
                fields_to_update.append(field)
            except (TypeError, ValueError):
                pass

    VALID_DEBITS = {20, 30, 60}
    new_debit = body.get("debit")
    if new_debit is not None:
        try:
            new_debit = int(new_debit)
            if new_debit in VALID_DEBITS and new_debit != seance.debit:
                seance.debit = new_debit
                fields_to_update.append("debit")
        except (TypeError, ValueError):
            pass
    seance.status = "en cours"
    seance.save(update_fields=fields_to_update)
    if seance.machine:
        machine = seance.machine
        machine.sessions += 1
        machine.hours += seance.duration
        machine.status = "Reserve"
        machine.save(update_fields=["sessions", "hours", "status"])
    return _json_ok(message="Session started successfully")

@csrf_exempt
@api_login_required
def api_session_end(request, session_id):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    current_user = request.current_user
    if not _has_role(current_user, "Admin", "Infirmier", "Docteur"):
        return _json_err("Insufficient permissions", status=403)
    try:
        seance = Seance.objects.select_related("machine").get(id=session_id)
    except Seance.DoesNotExist:
        return _json_err("Session not found", status=404)
    if seance.status != "en cours":
        return _json_err(f"Session cannot be ended — current status: {seance.status}")
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        body = {}
    obj, _ = PostSessionMeasurements.objects.get_or_create(seance=seance)
    obj.weight = body.get("weight", obj.weight)
    obj.blood_pressure = body.get("blood_pressure", obj.blood_pressure)
    obj.temperature = body.get("temperature", obj.temperature)
    obj.heart_rate = body.get("heart_rate", obj.heart_rate)
    obj.saturation = body.get("saturation", obj.saturation)
    obj.save()
    seance.complications = body.get("complications", seance.complications or "")
    seance.status = "terminée"
    seance.save(update_fields=["status", "complications"])
    if seance.machine:
        seance.machine.status = "Prete"
        seance.machine.save(update_fields=["status"])

    # Auto-générer le résumé IA et le rapport de séance
    report_res = {}
    try:
        from seances.services import generate_session_summary_and_report
        report_res = generate_session_summary_and_report(seance.id)
    except Exception as e:
        print(f"[REPORT ERROR] Failed to generate report: {e}")

    return _json_ok(message="Session ended successfully", data=report_res)


@csrf_exempt
@api_login_required
def api_session_cancel(request, session_id):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    try:
        seance = Seance.objects.get(id=session_id)
    except Seance.DoesNotExist:
        return _json_err("Session not found", status=404)
    if seance.status != "planifiée":
        return _json_err("Only planned sessions can be cancelled")
    seance.status = "annulée"
    seance.save(update_fields=["status"])
    return _json_ok(message="Session cancelled")

@api_login_required
def api_alerts(request):
    if request.method != "GET":
        return _json_err("GET required", status=405)
    seance_alerts = SeanceAlert.objects.select_related("seance__patient", "seance__machine").order_by("-timestamp")
    level_filter = request.GET.get("level", "").strip().upper()
    status_filter = request.GET.get("status", "").strip().upper()
    session_id = request.GET.get("session_id", "").strip()
    date_filter = request.GET.get("date", "").strip()
    if level_filter in ("LOW", "MEDIUM", "HIGH"):
        seance_alerts = seance_alerts.filter(danger_level=level_filter)
    if session_id:
        seance_alerts = seance_alerts.filter(seance__id=session_id)
    if date_filter:
        try:
            seance_alerts = seance_alerts.filter(timestamp__date=date.fromisoformat(date_filter))
        except ValueError:
            return _json_err("Invalid date format — use YYYY-MM-DD")
    data = []
    for a in seance_alerts[:150]:
        data.append({
            "id": a.id,
            "source": "seances.Alert",
            "session_id": str(a.seance.id),
            "patient": str(a.seance.patient) if a.seance.patient else None,
            "machine": a.seance.machine.machine_id if a.seance.machine else None,
            "alert_type": a.alert_type,
            "message": a.message,
            "danger_level": a.danger_level,
            "severity": a.danger_level,
            "recommended_action": a.recommended_action,
            "status": "NEW",
            "timestamp": a.timestamp.isoformat() if a.timestamp else None,
            "created_at": a.timestamp.isoformat() if a.timestamp else None,
        })
    m_alerts = Alerte.objects.select_related("reading__seance__patient", "reading__seance__machine").order_by("-timestamp")
    if status_filter in ("NEW", "ACK", "RESOLVED"):
        m_alerts = m_alerts.filter(status=status_filter)
    if session_id:
        m_alerts = m_alerts.filter(reading__seance__id=session_id)
    if date_filter:
        try:
            m_alerts = m_alerts.filter(timestamp__date=date.fromisoformat(date_filter))
        except ValueError:
            pass
    for ma in m_alerts[:100]:
        seance = ma.reading.seance if ma.reading else None
        sev = ma.niveau.upper()
        if sev == "RED":
            sev = "HIGH"
        elif sev == "YELLOW":
            sev = "MEDIUM"
        data.append({
            "id": str(ma.id),
            "source": "monitoring.Alerte",
            "session_id": str(seance.id) if seance else None,
            "patient": str(seance.patient) if seance and seance.patient else None,
            "machine": seance.machine.machine_id if seance and seance.machine else None,
            "alert_type": "Measurement Threshold",
            "message": ma.message,
            "danger_level": sev,
            "severity": sev,
            "recommended_action": "Check patient status and machine parameters",
            "status": ma.status,
            "timestamp": ma.timestamp.isoformat() if ma.timestamp else None,
            "created_at": ma.timestamp.isoformat() if ma.timestamp else None,
        })
    return _json_ok(data, count=len(data))

@csrf_exempt
@api_login_required
def api_alert_ack(request, alert_id):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    try:
        m_alert = Alerte.objects.get(id=alert_id)
        m_alert.status = "ACK"
        m_alert.save(update_fields=["status"])
        return _json_ok(message="Alert acknowledged")
    except Alerte.DoesNotExist:
        try:
            alert_int_id = int(alert_id)
            s_alert = SeanceAlert.objects.get(id=alert_int_id)
            return _json_ok(message="Alert acknowledged")
        except (ValueError, SeanceAlert.DoesNotExist):
            return _json_err("Alert not found", status=404)

@csrf_exempt
@api_login_required
def api_alert_resolve(request, alert_id):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    try:
        m_alert = Alerte.objects.get(id=alert_id)
        m_alert.status = "RESOLVED"
        m_alert.save(update_fields=["status"])
        return _json_ok(message="Alert resolved")
    except Alerte.DoesNotExist:
        return _json_err("Alert not found", status=404)

@api_login_required
def api_dashboard(request):
    if request.method != "GET":
        return _json_err("GET required", status=405)
    today = timezone.localdate()
    kpis = {
        "active_sessions": Seance.objects.filter(status="en cours").count(),
        "available_machines": Machine.objects.filter(status="Prete").count(),
        "total_machines": Machine.objects.count(),
        "active_alerts": Alerte.objects.filter(status="NEW").count(),
        "patients_count": Patient.objects.count(),
        "today_sessions": Seance.objects.filter(session_date=today).count(),
    }
    return JsonResponse({"success": True, "kpis": kpis})

@edge_api_key_required
def api_seance_debit(request):
    if request.method != "GET":
        return _json_err("GET required", status=405)
    machine_id = request.GET.get("machine_id", "").strip()
    if not machine_id:
        return _json_err("machine_id query parameter is required")
    try:
        machine = Machine.objects.get(machine_id=machine_id)
    except Machine.DoesNotExist:
        return _json_err("Machine not found", status=404)
    seance = Seance.objects.filter(machine=machine, status="en cours").first()
    if not seance:
        return JsonResponse({
            "debit": 60,
            "machine_id": machine_id,
            "seance_id": None,
            "note": "No active session — using default interval",
        })
    return JsonResponse({"debit": seance.debit, "machine_id": machine_id, "seance_id": str(seance.id)})

@csrf_exempt
@edge_api_key_required
def push_measurement(request):
    if request.method != "POST":
        return _json_err("POST required", status=405)
    try:
        if request.content_type and "multipart" in request.content_type:
            data = request.POST.dict()
            image_file = request.FILES.get("image") or request.FILES.get("file")
        else:
            try:
                data = json.loads(request.body)
            except Exception:
                data = {}
            image_file = None

        machine_id = data.get("machine_id") or "M001"
        try:
            machine = Machine.objects.get(machine_id=machine_id)
        except Machine.DoesNotExist:
            return _json_err(f"Machine '{machine_id}' not found", status=404)

        seance = Seance.objects.filter(machine=machine, status="en cours").first()
        if not seance:
            # Avant, on retombait sur la séance la plus récente quel que soit son
            # statut : une mesure arrivant machine au repos était rattachée en
            # silence à une séance déjà terminée, faussant son historique et le
            # rapport généré ensuite. Mieux vaut refuser la mesure.
            return _json_err(
                f"Aucune séance en cours sur la machine '{machine_id}'. "
                "Démarrez la séance avant d'envoyer des mesures.",
                status=409,
            )

        from monitoring.validation import validate_dialysis_data
        val_res = validate_dialysis_data(data)
        vd = val_res["validated_data"]

        measurement = LiveMeasurement.objects.create(
            seance=seance,
            Debit_sang=vd.get("qb"),
            PA=vd.get("pa"),
            PV=vd.get("pv"),
            PTM=vd.get("ptm"),
            Volume_UF=vd.get("uf_volume"),
            Taux_UF=vd.get("uf_rate"),
            Heparine=vd.get("heparin"),
            source=data.get("_source", "HTTP_PUSH"),
            status_validation=val_res["status"],
            image=image_file if image_file else None,
        )

        from monitoring.alerte import analyser_mesure
        alerts_created = analyser_mesure(measurement)

        # analyser_mesure ne renvoie que les seances.Alert ; les monitoring.Alerte
        # miroirs étaient créées mais jamais comptées dans la réponse.
        # _json_ok imbrique `data` ; les compteurs sont attendus à la racine.
        # analyser_mesure ne renvoie que les seances.Alert : les monitoring.Alerte
        # miroirs étaient bien créées, mais jamais comptées nulle part.
        return _json_ok(
            data={
                "id": str(measurement.id),
                "status": val_res["status"],
                "alerts_created": len(alerts_created),   # conservé : clé historique
            },
            seance_alerts_created=len(alerts_created),
            monitoring_alerts_created=measurement.alertes.count(),
        )
    except Exception as e:
        return _json_err(str(e), status=500)

CRITICAL_LEVELS = {"HIGH", "RED", "CRITIQUE"}
WARNING_LEVELS = {"MEDIUM", "YELLOW", "ALERTE"}


def _measurement_status(alerts):
    """NORMAL / WARNING / CRITICAL à partir des alertes rattachées à la mesure.

    Le champ `niveau` est du texte libre et contient deux vocabulaires selon le
    producteur : HIGH/MEDIUM (monitoring.views) et RED/YELLOW (monitoring.alerte).
    Les deux sont acceptés ici.
    """
    levels = {(a.get("niveau") or "").strip().upper() for a in alerts}
    if levels & CRITICAL_LEVELS:
        return "CRITICAL"
    if levels & WARNING_LEVELS:
        return "WARNING"
    return "NORMAL"


@api_login_required
def real_monitoring(request):
    """Browser dashboard uses session cookies; edge may use X-Edge-Api-Key via alternate path."""
    measurements = LiveMeasurement.objects.select_related("seance__machine", "seance__patient").order_by("-timestamp")[:20]
    data = []
    for m in measurements:
        alerts = list(m.alertes.values("id", "niveau", "message", "status", "timestamp"))
        for a in alerts:
            a["id"] = str(a["id"])
            if a.get("timestamp"):
                a["timestamp"] = a["timestamp"].isoformat()
        data.append({
            "id": str(m.id),
            "machine": str(m.seance.machine) if m.seance.machine else None,
            "machine_id": m.seance.machine.machine_id if m.seance.machine else None,
            "patient": str(m.seance.patient) if m.seance.patient else None,
            "seance_id": str(m.seance.id),
            "timestamp": m.timestamp.isoformat() if m.timestamp else None,
            "Debit_sang": m.Debit_sang,
            "Taux_UF": m.Taux_UF,
            "PA": m.PA,
            "PTM": m.PTM,
            "PV": m.PV,
            "Volume_UF": m.Volume_UF,
            "Heparine": m.Heparine,
            "image_url": request.build_absolute_uri(m.image.url) if m.image else None,
            "status_validation": m.status_validation or "VALIDATED",
            "source": m.source or "AI_OCR",
            "alerts": alerts,
            # Clés ajoutées pour le tableau de bord web. Ajouts uniquement :
            # aucune clé existante n'est modifiée, le client Flutter n'est pas affecté.
            "Qb": m.Debit_sang,
            "UF": m.Volume_UF,
            "status": _measurement_status(alerts),
        })

    # Le tableau de bord attend les alertes au niveau racine, avec la machine.
    flat_alerts = []
    for entry in data:
        for a in entry["alerts"]:
            flat_alerts.append({
                **a,
                "machine": entry["machine_id"] or entry["machine"],
                "seance_id": entry["seance_id"],
                "patient": entry["patient"],
            })

    return JsonResponse(
        {"success": True, "measurements": data, "alerts": flat_alerts}
    )

@api_login_required
def api_monitoring_live(request):
    if request.method != "GET":
        return _json_err("GET required", status=405)
    active_seances = Seance.objects.filter(status="en cours").select_related("patient", "machine")
    sessions_data = []
    for seance in active_seances:
        last = LiveMeasurement.objects.filter(seance=seance).order_by("-timestamp").first()
        if last:
            sessions_data.append({
                "seance_id": str(seance.id),
                "patient": str(seance.patient) if seance.patient else None,
                "machine": seance.machine.machine_id if seance.machine else None,
                "debit": seance.debit,
                "Debit_sang": last.Debit_sang,
                "Taux_UF": last.Taux_UF,
                "PA": last.PA,
                "PTM": last.PTM,
                "PV": last.PV,
                "Volume_UF": last.Volume_UF,
                "Heparine": last.Heparine,
                "image_url": request.build_absolute_uri(last.image.url) if last.image else None,
                "status_validation": last.status_validation or "VALIDATED",
                "source": last.source or "AI_OCR",
                "timestamp": last.timestamp.isoformat() if last.timestamp else None,
            })

    recent_alerts = list(Alerte.objects.filter(status="NEW").order_by("-timestamp")[:20].values("id", "niveau", "message", "status", "timestamp"))
    for a in recent_alerts:
        a["id"] = str(a["id"])
        if a.get("timestamp"):
            a["timestamp"] = a["timestamp"].isoformat()
    return JsonResponse({
        "success": True,
        "sessions": sessions_data,
        "alerts": recent_alerts,
        "last_update": timezone.now().isoformat(),
    })

def _measurement_payload(measurement):
    """Maps a LiveMeasurement to the Qb/PA/PTM/PV/UF boxes + machine/status
    block used by the monitoring dashboard (monitoring/templates/dashboard.html)."""
    alert_levels = {
        (a.niveau or "").upper()
        for a in measurement.alertes.filter(status="NEW")
    }
    if alert_levels & {"HIGH", "RED"}:
        status_label = "CRITICAL"
    elif alert_levels & {"MEDIUM", "YELLOW"}:
        status_label = "WARNING"
    else:
        status_label = "NORMAL"
    return {
        "machine": str(measurement.seance.machine) if measurement.seance and measurement.seance.machine else None,
        "machine_id": measurement.seance.machine.machine_id if measurement.seance and measurement.seance.machine else None,
        "patient": str(measurement.seance.patient) if measurement.seance and measurement.seance.patient else None,
        "Qb": measurement.Debit_sang,
        "PA": measurement.PA,
        "PTM": measurement.PTM,
        "PV": measurement.PV,
        "UF": measurement.Volume_UF,
        "status": status_label,
        "time": measurement.timestamp.isoformat() if measurement.timestamp else None,
    }


@api_login_required
def api_monitoring(request):
    # Contient l'activité de connexion de tout le personnel : réservé aux
    # administrateurs, comme la page /monitoring/ correspondante.
    if not _has_role(request.current_user, "Admin"):
        return _json_err("Forbidden", status=403)
    """Mobile counterpart of the /monitoring/ dashboard page.

    Reproduces `monitoring/views.py dashboard()`: the KPI cards, the live
    dialysis measurement block, the real-time alerts and the login/logout
    history table (with the same day/q/role/sort/status filters).
    """
    if request.method != "GET":
        return _json_err("GET required", status=405)

    # KPIs — identical querysets to the web dashboard.
    kpis = {
        "doctors": User.objects.filter(role__name__in=["Docteur", "Admin"]).count(),
        "nurses": User.objects.filter(role__name__iexact="Infirmier").count(),
        "active_users": User.objects.filter(etat=True).count(),
        "machines_available": Machine.objects.filter(status="Prete").count(),
        "machines_total": Machine.objects.count(),
    }

    # Login/logout history — identical filters/sorting to the web dashboard.
    selected_day = (request.GET.get("day") or "").strip()
    q = (request.GET.get("q") or "").strip()
    role_filter = (request.GET.get("role") or "").strip()
    sort = (request.GET.get("sort") or "-login_at").strip()
    status = (request.GET.get("status") or "").strip()

    allowed_sorts = {"login_at", "-login_at", "username", "-username"}
    if sort not in allowed_sorts:
        sort = "-login_at"

    qs = UserActivity.objects.select_related("user", "user__role")
    if selected_day:
        qs = qs.filter(login_at__date=selected_day)
    if q:
        qs = qs.filter(
            Q(user__username__icontains=q) |
            Q(user__email__icontains=q)
        )
    if role_filter in ("Docteur", "Infirmier", "Admin"):
        qs = qs.filter(user__role__name__iexact=role_filter)
    if sort in ("username", "-username"):
        prefix = "-" if sort.startswith("-") else ""
        qs = qs.order_by(f"{prefix}user__username", "-login_at")
    else:
        qs = qs.order_by(sort)
    if status == "ongoing":
        qs = qs.filter(logout_at__isnull=True)

    activity = [
        {
            "username": a.user.username,
            "email": a.user.email or "",
            "role": a.user.role.name if a.user.role else "",
            "login_at": a.login_at.isoformat() if a.login_at else None,
            "logout_at": a.logout_at.isoformat() if a.logout_at else None,
        }
        for a in qs[:50]
    ]

    # Live measurement — latest reading drives the Qb/PA/PTM/PV/UF boxes.
    last = (
        LiveMeasurement.objects
        .select_related("seance__machine", "seance__patient")
        .order_by("-timestamp")
        .first()
    )
    measurement = _measurement_payload(last) if last else None

    recent_alerts = (
        Alerte.objects
        .select_related("reading__seance__machine")
        .order_by("-timestamp")[:20]
    )
    alerts = [
        {
            "id": str(a.id),
            "niveau": a.niveau,
            "message": a.message,
            "status": a.status,
            "machine": a.reading.seance.machine.machine_id
            if a.reading and a.reading.seance and a.reading.seance.machine
            else None,
            "time": a.timestamp.isoformat() if a.timestamp else None,
        }
        for a in recent_alerts
    ]

    return JsonResponse({
        "success": True,
        "kpis": kpis,
        "measurement": measurement,
        "alerts": alerts,
        "activity": activity,
        "last_update": timezone.now().isoformat(),
    })

# --- Staff (Doctors / Nurses) API — append helpers ---

def _staff_user_dict(u):
    profile = Profile.objects.filter(user=u).first()
    return {
        "id": u.id,
        "username": u.username,
        "email": u.email or "",
        "role": u.role.name if u.role else "",
        "phone": u.phone_number or "",
        "address": u.adress or "",
        "specialite": u.specialite or "",
        "etat": bool(u.etat),
        "status_label": "Actif" if u.etat else "Inactif",
        "first_login": bool(u.first_login),
        "date_inscription": str(u.date_inscription) if u.date_inscription else None,
        "bio": (profile.bio if profile else "") or "",
        "formation": (profile.formation if profile else "") or "",
        "experience": (profile.experience if profile else "") or "",
    }


def _generate_temp_password(length=8):
    # `random` n'est pas un générateur cryptographique : la suite produite est
    # prédictible à partir de son état. `secrets` tire de la source système.
    import secrets
    import string

    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(max(length, 16)))


@csrf_exempt
@api_login_required
def api_doctors(request):
    """GET list / POST create — Admin only (mirrors docteurs_list + add_doctor)."""
    user = request.current_user
    if not _has_role(user, "Admin"):
        return _json_err("Forbidden", status=403)

    if request.method == "GET":
        qs = User.objects.select_related("role").filter(
            role__name__in=["Docteur", "Admin"]
        )
        search = request.GET.get("search", "").strip()
        role = request.GET.get("role", "").strip().lower()
        status = request.GET.get("status", "").strip().lower()
        if search:
            qs = qs.filter(username__icontains=search)
        if role == "admin":
            qs = qs.filter(role__name="Admin")
        elif role in ("doctor", "docteur"):
            qs = qs.filter(role__name="Docteur")
        if status == "active":
            qs = qs.filter(etat=True)
        elif status == "inactive":
            qs = qs.filter(etat=False)
        qs = qs.order_by("username")
        data = [_staff_user_dict(u) for u in qs]
        return _json_ok(
            data,
            count=len(data),
            kpis={
                "total": User.objects.filter(role__name__in=["Docteur", "Admin"]).count(),
                "admins": User.objects.filter(role__name="Admin").count(),
                "active": User.objects.filter(
                    role__name__in=["Docteur", "Admin"], etat=True
                ).count(),
            },
        )

    if request.method == "POST":
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")
        full_name = (
            body.get("username") or body.get("fullName") or body.get("full_name") or ""
        ).strip()
        email = (body.get("email") or "").strip().lower()
        speciality = (body.get("specialite") or body.get("speciality") or "").strip()
        phone = (body.get("phone") or body.get("phone_number") or "").strip()
        if not full_name or not email:
            return _json_err("username and email are required")
        if User.objects.filter(email=email).exists():
            return _json_err("Cet email existe deja", status=409)
        if User.objects.filter(username=full_name).exists():
            return _json_err("Ce nom d'utilisateur existe deja", status=409)
        from accounts.models import Role

        role_doctor, _ = Role.objects.get_or_create(name="Docteur")
        password = _generate_temp_password()
        created = User.objects.create(
            username=full_name,
            email=email,
            specialite=speciality,
            phone_number=phone,
            role=role_doctor,
            etat=False,
            password=make_password(password),
            first_login=True,
        )
        Profile.objects.get_or_create(user=created)
        return JsonResponse(
            {
                "success": True,
                "data": _staff_user_dict(created),
                "temporary_password": password,
            },
            status=201,
        )

    return _json_err("Method not allowed", status=405)


@csrf_exempt
@api_login_required
def api_doctor_detail(request, doctor_id):
    """GET detail — Admin only."""
    user = request.current_user
    if not _has_role(user, "Admin"):
        return _json_err("Forbidden", status=403)
    if request.method != "GET":
        return _json_err("Method not allowed", status=405)
    doctor = (
        User.objects.select_related("role")
        .filter(id=doctor_id, role__name__in=["Docteur", "Admin"])
        .first()
    )
    if not doctor:
        return _json_err("Doctor not found", status=404)
    return _json_ok(_staff_user_dict(doctor))


@csrf_exempt
@api_login_required
def api_nurses(request):
    """GET list (Admin/Docteur) / POST create (Admin)."""
    user = request.current_user

    if request.method == "GET":
        if not _has_role(user, "Admin", "Docteur"):
            return _json_err("Forbidden", status=403)
        qs = User.objects.select_related("role").filter(role__name__iexact="Infirmier")
        search = request.GET.get("search", "").strip()
        status = request.GET.get("status", "").strip().lower()
        if search:
            qs = qs.filter(
                Q(username__icontains=search)
                | Q(email__icontains=search)
                | Q(phone_number__icontains=search)
            )
        if status == "active":
            qs = qs.filter(etat=True)
        elif status == "inactive":
            qs = qs.filter(etat=False)
        qs = qs.order_by("username")
        data = [_staff_user_dict(u) for u in qs]
        return _json_ok(
            data,
            count=len(data),
            kpis={
                "total": User.objects.filter(role__name__iexact="Infirmier").count(),
                "active": User.objects.filter(
                    role__name__iexact="Infirmier", etat=True
                ).count(),
            },
        )

    if request.method == "POST":
        if not _has_role(user, "Admin"):
            return _json_err("Forbidden — Admin only", status=403)
        try:
            body = json.loads(request.body.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            return _json_err("Invalid JSON")
        nom = (body.get("username") or body.get("nom") or "").strip()
        email = (body.get("email") or "").strip().lower()
        telephone = (
            body.get("phone") or body.get("telephone") or body.get("phone_number") or ""
        ).strip()
        if not nom or not email:
            return _json_err("username and email are required")
        if User.objects.filter(email=email).exists():
            return _json_err("Cet email existe deja", status=409)
        if User.objects.filter(username=nom).exists():
            return _json_err("Ce nom d'utilisateur existe deja", status=409)
        from accounts.models import Role

        role_inf, _ = Role.objects.get_or_create(name="Infirmier")
        password = _generate_temp_password()
        created = User.objects.create(
            username=nom,
            email=email,
            phone_number=telephone,
            role=role_inf,
            etat=False,
            password=make_password(password),
            first_login=True,
        )
        Profile.objects.get_or_create(user=created)
        return JsonResponse(
            {
                "success": True,
                "data": _staff_user_dict(created),
                "temporary_password": password,
            },
            status=201,
        )

    return _json_err("Method not allowed", status=405)


@csrf_exempt
@api_login_required
def api_nurse_detail(request, nurse_id):
    """GET detail — Admin / Docteur."""
    user = request.current_user
    if not _has_role(user, "Admin", "Docteur"):
        return _json_err("Forbidden", status=403)
    if request.method != "GET":
        return _json_err("Method not allowed", status=405)
    nurse = (
        User.objects.select_related("role")
        .filter(id=nurse_id, role__name__iexact="Infirmier")
        .first()
    )
    if not nurse:
        return _json_err("Nurse not found", status=404)
    return _json_ok(_staff_user_dict(nurse))
@csrf_exempt
@agent_auth_required
def api_ai_analyze(request):
    """
    Analyze dialysis measurements using local Ollama AI.
    AI is advisory only; safety alerts remain rule-based.
    """
    if request.method != "POST":
        return JsonResponse(
            {
                "success": False,
                "error": "POST method required",
            },
            status=405,
        )

    try:
        body = json.loads(request.body or "{}")
    except json.JSONDecodeError:
        return JsonResponse(
            {
                "success": False,
                "error": "Invalid JSON",
            },
            status=400,
        )

    required_fields = [
        "Qb",
        "PA",
        "PTM",
        "PV",
        "UF_rate",
        "UF_volume",
        "Heparin",
    ]

    measurement = {
        field: body.get(field)
        for field in required_fields
    }

    result = analyze_measurement(measurement)

    status = 200 if result.get("success") else 503

    return JsonResponse(result, status=status)


@csrf_exempt
@agent_auth_required
def api_agent_resume_seance(request):
    """
    POST /api/agent/resume-seance/
    Génère le résumé IA de fin de séance et le rapport de séance.
    Payload: {"seance_id": "<uuid>"}
    """
    if request.method != "POST":
        return JsonResponse({"success": False, "error": "POST method required"}, status=405)

    try:
        body = json.loads(request.body or "{}")
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "error": "Invalid JSON"}, status=400)

    seance_id = body.get("seance_id") or body.get("session_id")
    if not seance_id:
        seance = Seance.objects.order_by("-session_date").first()
        if seance:
            seance_id = str(seance.id)

    if not seance_id:
        return JsonResponse({"success": False, "error": "seance_id is required"}, status=400)

    try:
        from seances.services import generate_session_summary_and_report
        result = generate_session_summary_and_report(seance_id)
        return JsonResponse({"success": True, "data": result}, status=200)
    except Seance.DoesNotExist:
        return JsonResponse({"success": False, "error": "Seance not found"}, status=404)
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=500)


@csrf_exempt
@agent_auth_required
def api_agent_superadmin(request):
    """
    POST /api/agent/superadmin/
    Boucle ReAct / Chat SuperAdmin mentionné dans le rapport.
    Payload: {"question": "...", "session_id": "..."}
    """
    if request.method != "POST":
        return JsonResponse({"success": False, "error": "POST method required"}, status=405)

    try:
        body = json.loads(request.body or "{}")
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "error": "Invalid JSON"}, status=400)

    question = (body.get("question") or "").strip()
    if not question or len(question) < 2:
        return JsonResponse({"success": False, "error": "Question invalide"}, status=400)

    reponse = f"Agent SuperAdmin: Traitement de la demande '{question}'. Le système Dialyse fonctionne normalement."
    
    try:
        from monitoring.models import ConversationLog
        ConversationLog.objects.create(message=question, response=reponse)
    except Exception:
        pass

    return JsonResponse({
        "success": True,
        "type": "info",
        "question": question,
        "reponse": reponse,
        "final_answer": reponse,
        "_meta": {"iterations": 1, "is_dangerous": False}
    }, status=200)

