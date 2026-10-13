from django.urls import path
from . import views

app_name = "api"

urlpatterns = [
    # Auth
    path("login/", views.mobile_login, name="mobile_login"),
    path("logout/", views.mobile_logout, name="mobile_logout"),
    path("profile/", views.api_profile, name="api_profile"),

    # Patients
    path("patients/", views.api_patients, name="api_patients"),
    path("patients/<int:patient_id>/", views.api_patient_detail, name="api_patient_detail"),

    # Machines
    path("machines/", views.api_machines, name="api_machines"),
    path("machines/<int:machine_id>/", views.api_machine_detail, name="api_machine_detail"),

    # Sessions / Seances
    path("sessions/", views.api_sessions, name="api_sessions"),
    path("sessions/<uuid:session_id>/", views.api_session_detail, name="api_session_detail"),
    path("sessions/<uuid:session_id>/start/", views.api_session_start, name="api_session_start"),
    path("sessions/<uuid:session_id>/end/", views.api_session_end, name="api_session_end"),
    path("sessions/<uuid:session_id>/cancel/", views.api_session_cancel, name="api_session_cancel"),

    # Alerts
    path("alerts/", views.api_alerts, name="api_alerts"),
    path("alerts/<str:alert_id>/ack/", views.api_alert_ack, name="api_alert_ack"),
    path("alerts/<str:alert_id>/resolve/", views.api_alert_resolve, name="api_alert_resolve"),

    # Staff
    path("doctors/", views.api_doctors, name="api_doctors"),
    path("doctors/<int:doctor_id>/", views.api_doctor_detail, name="api_doctor_detail"),
    path("nurses/", views.api_nurses, name="api_nurses"),
    path("nurses/<int:nurse_id>/", views.api_nurse_detail, name="api_nurse_detail"),

    # Dashboard
    path("dashboard/", views.api_dashboard, name="api_dashboard"),

    # Raspberry Pi & Edge Pipeline
    path("seance/debit/", views.api_seance_debit, name="api_seance_debit"),
    path("push/", views.push_measurement, name="push_measurement"),
    path("ai/analyze/", views.api_ai_analyze, name="api_ai_analyze"),

    # Monitoring
    path("real-monitoring/", views.real_monitoring, name="real_monitoring"),
    path("monitoring/live/", views.api_monitoring_live, name="api_monitoring_live"),
    path("monitoring/", views.api_monitoring, name="api_monitoring"),

    # AI Agents & Workflows (n8n integration)
    path("agent/resume-seance/", views.api_agent_resume_seance, name="api_agent_resume_seance"),
    path("agent/superadmin/", views.api_agent_superadmin, name="api_agent_superadmin"),
]

