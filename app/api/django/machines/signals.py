from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Machine, MachineModuleStatus, MachineTypeModule

@receiver(post_save, sender=Machine)
def create_machine_modules(sender, instance, created, **kwargs):
    if not created:
        return

    # Vérifie si un MachineModuleStatus existe déjà
    if MachineModuleStatus.objects.filter(machine=instance).exists():
        return

    modules = {}
    type_modules = MachineTypeModule.objects.filter(machine_type=instance.type)
    for module in type_modules:
        modules[module.code] = True  # OK par défaut

    MachineModuleStatus.objects.create(
        machine=instance,
        modules=modules
    )
