import os
from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = 'core'

    def ready(self):
        # In Django runserver con autoreload ci sono due processi:
        # il processo principale (RUN_MAIN non presente) e il processo worker (RUN_MAIN == 'true').
        # Se non siamo in runserver con reloader (es. --noreload o altro server), avviamo comunque.
        import sys
        is_runserver = any('runserver' in arg for arg in sys.argv)
        run_main = os.environ.get('RUN_MAIN') == 'true'

        if not is_runserver or run_main:
            try:
                from .tasks import start_sollecito_checker_daemon
                start_sollecito_checker_daemon()
            except Exception as e:
                print(f"[CoreConfig] Errore avvio daemon solleciti: {e}")
