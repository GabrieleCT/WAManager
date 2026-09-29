import os

apps_path = r'C:\Users\gabriele.cataldo\OneDrive - Banca Mediolanum SPA\Desktop\private\tango\gestionale\WAManager\core\apps.py'
with open(apps_path, 'r', encoding='utf-8') as f:
    content = f.read()

ready_code = '''
    def ready(self):
        try:
            from django_q.models import Schedule
            import datetime
            # Check if schedule exists
            if not Schedule.objects.filter(func="core.tasks.invia_sondaggio_mattutino").exists():
                Schedule.objects.create(
                    func="core.tasks.invia_sondaggio_mattutino",
                    schedule_type=Schedule.DAILY,
                    time=datetime.time(8, 0, 0)
                )
        except Exception:
            pass
'''

if 'def ready(self):' not in content:
    content = content.replace("class CoreConfig(AppConfig):\n    default_auto_field = 'django.db.models.BigAutoField'\n    name = 'core'", "class CoreConfig(AppConfig):\n    default_auto_field = 'django.db.models.BigAutoField'\n    name = 'core'\n" + ready_code)

with open(apps_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Modified apps.py')
