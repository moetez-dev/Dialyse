from django.db import models
from django.core.validators import MinLengthValidator
from django.utils import timezone
from django.contrib.auth.hashers import make_password

# Create your models here.
class Role(models.Model):
    name = models.CharField(max_length=50)

    def __str__(self):
        return self.name
class User(models.Model):
    id = models.AutoField(primary_key=True)
    username = models.CharField(max_length=150, unique=True)
    password = models.CharField(max_length=128,validators=[MinLengthValidator(6)], blank=False, null=False)
    email = models.EmailField(unique=True,blank=True, null=True)
    role = models.ForeignKey(Role, on_delete=models.CASCADE)
    adress = models.CharField(max_length=255, blank=True, null=True)
    phone_number = models.CharField(max_length=20,blank=True, null=True)
    etat=models.BooleanField(default=False,null=True,blank=True)
    date_inscription=models.DateField(auto_now_add=True, null=True)
    specialite = models.CharField(max_length=100, blank=True, null=True)
    first_login = models.BooleanField(default=True)
    last_seen = models.DateTimeField(null=True, blank=True, default=timezone.now)
    is_active = models.BooleanField(default=True)
    def save(self, *args, **kwargs):
        # Si le mot de passe n'est pas déjà hashé, on le hash
        if self.password and not self.password.startswith('pbkdf2_'):
            self.password = make_password(self.password)
        super().save(*args, **kwargs)




    # ------------------------------------------------------------------
    # Rôles et capacités
    #
    # `Role.name` est du texte libre : "Admin", "admin" ou "Admin " existent
    # tous en base. Les comparaisons de chaînes dispersées dans les gabarits
    # étaient sensibles à la casse, si bien qu'un rôle "admin" donnait l'accès
    # aux vues mais masquait toute la navigation d'administration.
    # ------------------------------------------------------------------
    ADMIN = "admin"
    DOCTEUR = "docteur"
    INFIRMIER = "infirmier"
    # Le technicien entretient le parc : générateurs et appareils de lecture.
    # Il n'intervient pas dans le soin et ne voit donc aucune donnée patient.
    TECHNICIEN = "technicien"

    @property
    def role_slug(self):
        if not self.role_id or not self.role or not self.role.name:
            return ""
        return self.role.name.strip().casefold()

    @property
    def role_label(self):
        if not self.role_id or not self.role or not self.role.name:
            return "Utilisateur"
        return self.role.name.strip().title()

    @property
    def is_admin(self):
        return self.role_slug == self.ADMIN

    @property
    def is_docteur(self):
        return self.role_slug == self.DOCTEUR

    @property
    def is_infirmier(self):
        return self.role_slug == self.INFIRMIER

    @property
    def is_technicien(self):
        return self.role_slug == self.TECHNICIEN

    @property
    def is_known_role(self):
        """Le rôle correspond-il à l'un de ceux que l'application gère ?

        `Role.name` est du texte libre : rien n'empêche de créer un rôle que
        les vues ne reconnaissent pas. Sans ce garde-fou, un tel utilisateur
        voyait une navigation complète dont chaque lien menait à un 403.
        """
        return self.role_slug in {self.ADMIN, self.DOCTEUR,
                                  self.INFIRMIER, self.TECHNICIEN}

    # Capacités : ce que la navigation demande réellement, exprimé par
    # l'intention plutôt que par des comparaisons négatives de rôle.
    @property
    def can_view_admin_dashboard(self):
        return self.is_admin

    @property
    def can_manage_devices(self):
        return self.is_admin or self.is_technicien

    @property
    def can_manage_machines(self):
        return self.is_admin or self.is_infirmier or self.is_technicien

    @property
    def can_manage_doctors(self):
        return self.is_admin

    @property
    def can_manage_nurses(self):
        return self.is_admin or self.is_docteur

    # Actions : les boutons doivent suivre les mêmes règles que les vues,
    # sinon on propose une action qui renvoie vers la page d'erreur.
    @property
    def can_add_machine(self):
        return self.is_admin or self.is_technicien

    @property
    def can_add_staff(self):
        return self.is_admin

    @property
    def can_create_session(self):
        return self.is_admin or self.is_docteur

    @property
    def can_view_clinical(self):
        """Surveillance, alertes, séances, patients : le soin.

        Sépare le parc matériel du dossier patient, afin que le technicien
        puisse entretenir les générateurs sans accéder aux données de santé.
        """
        return self.is_admin or self.is_docteur or self.is_infirmier

    def get_specialite(self):
        if self.role and self.role.name == "Docteur":
            return self.specialite
        return None
    def __str__(self):
        return self.username
    
class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    bio = models.TextField(blank=True, null=True)
    image = models.ImageField(upload_to='photos_profils/', blank=True, null=True)
    formation = models.TextField(blank=True, null=True)
    experience = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.user.username}'s Profile"
    
class PasswordResetRequest(models.Model):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    used_at = models.DateTimeField(null=True, blank=True)

    def is_used(self):
        return self.used_at is not None
    
class UserActivity(models.Model):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    login_at = models.DateTimeField(default=timezone.now)
    logout_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):

        return f"{self.user_id} {self.login_at} -> {self.logout_at}"