from django.apps import AppConfig

class ClinicaConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'clinica'
    def ready(self):
        # Регистрация сигналов — только здесь
        from . import signals  # noqa

