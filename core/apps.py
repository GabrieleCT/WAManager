import os
from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = 'core'

    def ready(self):
        # Evita esecuzione duplicata con il reloader di Django runserver
        if os.environ.get('RUN_MAIN') == 'true' or not os.environ.get('DJANGO_SETTINGS_MODULE'):
            try:
                from .tasks import start_sollecito_checker_daemon
                start_sollecito_checker_daemon()
            except Exception as e:
                print(f"[CoreConfig] Errore avvio daemon solleciti: {e}")
