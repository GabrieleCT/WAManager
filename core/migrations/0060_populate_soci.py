import datetime
from decimal import Decimal
from django.db import migrations


def populate_soci_from_allievi(apps, schema_editor):
    Allievo = apps.get_model('core', 'Allievo')
    Socio = apps.get_model('core', 'Socio')

    # Trova tutti gli allievi con tessera non vuota ordinati per data creazione o data ammissione
    allievi = Allievo.objects.exclude(tessera_associativa__isnull=True).exclude(tessera_associativa__exact='')

    # Recupera il massimo numero progressivo attuale
    from django.db.models import Max
    max_num = Socio.objects.aggregate(m=Max('numero_progressivo'))['m'] or 0

    for allievo in allievi:
        tessera = (allievo.tessera_associativa or '').strip()
        if not tessera:
            continue

        # Idempotenza: controlla se esiste già un socio con questa allievo o numero_tessera
        if Socio.objects.filter(allievo=allievo).exists() or Socio.objects.filter(numero_tessera=tessera).exists():
            continue

        luogo_nasc = (allievo.comune_nascita or '').strip()
        prov_nasc = (allievo.provincia_nascita or '').strip()
        if luogo_nasc and prov_nasc:
            luogo_nasc = f"{luogo_nasc} ({prov_nasc})"
        elif not luogo_nasc:
            luogo_nasc = prov_nasc

        residenza_parts = [
            p.strip() for p in [
                allievo.indirizzo_residenza or '',
                allievo.comune_residenza or '',
                allievo.provincia_residenza or ''
            ] if p and p.strip()
        ]
        indirizzo_res = ", ".join(residenza_parts)

        data_iscr = None
        if hasattr(allievo, 'data_ammissione') and allievo.data_ammissione:
            data_iscr = allievo.data_ammissione
        elif hasattr(allievo, 'created_at') and allievo.created_at:
            data_iscr = allievo.created_at.date()
        else:
            data_iscr = datetime.date.today()

        max_num += 1
        Socio.objects.create(
            numero_progressivo=max_num,
            numero_tessera=tessera,
            cognome=(allievo.cognome or '').strip(),
            nome=(allievo.nome or '').strip(),
            data_nascita=allievo.data_nascita,
            luogo_nascita=luogo_nasc,
            codice_fiscale=(allievo.codice_fiscale or '').strip().upper(),
            indirizzo_residenza=indirizzo_res,
            telefono=(allievo.telefono or '').strip(),
            email=(allievo.email or '').strip().lower(),
            data_iscrizione=data_iscr,
            categoria='ORDINARIO',
            quota_associativa=Decimal('20.00'),
            attivo=True,
            origine='STUDENTE',
            allievo=allievo
        )


def rollback_soci(apps, schema_editor):
    Socio = apps.get_model('core', 'Socio')
    Socio.objects.filter(origine='STUDENTE').delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0059_socio'),
    ]

    operations = [
        migrations.RunPython(populate_soci_from_allievi, rollback_soci),
    ]
