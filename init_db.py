import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'wamanager.settings')
django.setup()

from django.db import connection


def pre_migrate():
    """Risolve il disallineamento della tabella django_migrations per l'app core."""
    try:
        with connection.cursor() as cursor:
            tables = connection.introspection.table_names()
            print(f"[init_db] Tabelle rilevate nel database: {len(tables)}")

            if 'django_migrations' in tables:
                cursor.execute("SELECT name FROM django_migrations WHERE app = 'core'")
                core_mig_names = [row[0] for row in cursor.fetchall()]

                # Se 0001_initial è presente in django_migrations ma core_presenza non esiste,
                # significa che la migrazione registrata è quella obsoleta dei vecchi modelli.
                if '0001_initial' in core_mig_names and 'core_presenza' not in tables:
                    print("[init_db] Rilevata storia migrazioni 'core' obsoleta (manca core_presenza). Reset record migrazioni core...")
                    cursor.execute("DELETE FROM django_migrations WHERE app = 'core'")

                    old_tables = [
                        'core_eventattendance',
                        'core_participant',
                        'core_event',
                        'core_match',
                        'core_messagelog',
                        'core_recurringschedule',
                        'core_messagetemplate'
                    ]
                    for ot in old_tables:
                        if ot in tables:
                            print(f"[init_db] Rimozione tabella obsoleta {ot}...")
                            cursor.execute(f'DROP TABLE IF EXISTS "{ot}" CASCADE')

                    print("[init_db] Riparazione completata: ora migrate eseguira 0001_initial da zero.")
    except Exception as e:
        print(f"[init_db] Errore durante pre_migrate: {e}")


def post_migrate():
    """Assicura che l'utente superuser admin esista con password admin."""
    try:
        from django.contrib.auth import get_user_model
        User = get_user_model()
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser('admin', 'admin@example.com', 'admin')
            print("[init_db] Superuser 'admin' creato con password 'admin'")
        else:
            print("[init_db] Superuser 'admin' gia presente.")
    except Exception as e:
        print(f"[init_db] Errore durante post_migrate: {e}")


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'pre'
    if mode == 'pre':
        pre_migrate()
    elif mode == 'post':
        post_migrate()
    else:
        print(f"Modalita non riconosciuta: {mode}")
