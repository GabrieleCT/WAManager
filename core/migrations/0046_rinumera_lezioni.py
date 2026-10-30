import re
from django.db import migrations


def rinumera_tutte_lezioni(apps, schema_editor):
    Corso = apps.get_model('core', 'Corso')
    Lezione = apps.get_model('core', 'Lezione')

    def _get_trimestre_gruppo(lez):
        if lez.titolo:
            titolo_lower = lez.titolo.lower()
            m = re.search(r'(\d+)\s*[°ª\xb0]?\s*trimestre', lez.titolo, re.IGNORECASE)
            if m:
                return f"{m.group(1)}° Trimestre"
            if 'primo trimestre' in titolo_lower:
                return '1° Trimestre'
            if 'secondo trimestre' in titolo_lower:
                return '2° Trimestre'
            if 'terzo trimestre' in titolo_lower:
                return '3° Trimestre'
            if 'quarto trimestre' in titolo_lower:
                return '4° Trimestre'
            if ' - ' in lez.titolo:
                return lez.titolo.split(' - ')[-1].strip()

        m_num = lez.data.month
        if m_num in (9, 10, 11, 12):
            return '1° Trimestre'
        elif m_num in (1, 2, 3):
            return '2° Trimestre'
        elif m_num in (4, 5, 6):
            return '3° Trimestre'
        else:
            return '4° Trimestre'

    for corso in Corso.objects.all():
        lezioni = list(Lezione.objects.filter(corso=corso).order_by('data', 'id'))
        if not lezioni:
            continue

        groups = {}
        for l in lezioni:
            trim = _get_trimestre_gruppo(l)
            groups.setdefault(trim, []).append(l)

        to_update = []
        for trim, lista_lezioni in groups.items():
            total = len(lista_lezioni)
            for idx, lez in enumerate(lista_lezioni, start=1):
                nuovo_titolo = f"{idx}/{total} - {trim}"
                if lez.titolo != nuovo_titolo:
                    lez.titolo = nuovo_titolo
                    to_update.append(lez)

        if to_update:
            Lezione.objects.bulk_update(to_update, ['titolo'])


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0045_sondaggiomattutinoconfig_istruzioni_pagamento_testo'),
    ]

    operations = [
        migrations.RunPython(rinumera_tutte_lezioni, migrations.RunPython.noop),
    ]

