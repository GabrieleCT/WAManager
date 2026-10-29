import threading
import time
import datetime
from django.utils import timezone
from django.db.models import Q
from django.template import Template, Context
from .models import (
    Lezione, Corso, Allievo, Presenza, Match, MessageTemplate, MessageLog, RecurringSchedule,
    SondaggioMattutinoConfig
)
from .wa_client import send_whatsapp_message
from .services import generate_matches


def scheduled_rsvp_announcement(force_lezione_id=None):
    """
    Task programmato per inviare l'apertura adesioni / sondaggio per le prossime lezioni.
    """
    now = timezone.now()

    if force_lezione_id:
        lezioni = Lezione.objects.filter(id=force_lezione_id)
    else:
        # Trova lezioni da oggi ai prossimi 7 giorni
        lezioni = Lezione.objects.filter(data__gte=now.date(), data__lte=now.date() + datetime.timedelta(days=7))

    schedule = RecurringSchedule.objects.first()
    rsvp_mode = schedule.rsvp_mode if schedule else 'POLL'

    for lezione in lezioni:
        template = MessageTemplate.objects.filter(name='RSVP').first()
        if not template:
            print("AVVISO: Nessun MessageTemplate trovato per RSVP.")
            continue

        group_target = lezione.corso.gruppo_whatsapp or (lezione.corso.scuola.gruppo_whatsapp if lezione.corso.scuola else '')
        if not group_target:
            print(f"Nessun gruppo WhatsApp impostato per il corso {lezione.corso}.")
            continue

        t = Template(template.body)
        c = Context({
            'event_date': lezione.data.strftime('%d/%m/%Y'),
            'orario': lezione.corso.orario.strftime('%H:%M') if lezione.corso.orario else '',
            'corso': str(lezione.corso),
            'argomento': lezione.argomento.titolo if lezione.argomento else 'Da definire',
            'rsvp_link': 'Rispondete al sondaggio!' if rsvp_mode == 'POLL' else 'Rispondete liberamente a questo messaggio!'
        })
        message = t.render(c)

        log = MessageLog(
            lezione=lezione,
            template=template,
            rendered_text=message,
            status='Inviato'
        )

        try:
            print(f"Inviando annuncio WhatsApp per lezione {lezione.id} al gruppo {group_target}...")
            if rsvp_mode == 'POLL':
                response = send_whatsapp_message(
                    group_target,
                    message,
                    is_group=True,
                    is_poll=True,
                    poll_options=["Ci sono! 🕺💃", "Non ci sono 🚫"]
                )
            else:
                response = send_whatsapp_message(
                    group_target,
                    message,
                    is_group=True
                )

            if not response.get('success'):
                log.status = 'Errore'
                log.error_message = response.get('error', 'Unknown Error')

            log.save()
        except Exception as e:
            log.status = 'Errore'
            log.error_message = str(e)
            log.save()
            print(f"Errore durante l'invio RSVP: {e}")


def scheduled_match_announcement(force_lezione_id=None):
    """
    Task programmato per generare le coppie e inviarle sul gruppo del corso.
    """
    now = timezone.now()

    if force_lezione_id:
        lezioni = Lezione.objects.filter(id=force_lezione_id)
    else:
        lezioni = Lezione.objects.filter(data=now.date())

    for lezione in lezioni:
        template = MessageTemplate.objects.filter(name='MATCH').first()
        if not template:
            print("AVVISO: Nessun MessageTemplate trovato per MATCH.")
            continue

        group_target = lezione.corso.gruppo_whatsapp or (lezione.corso.scuola.gruppo_whatsapp if lezione.corso.scuola else '')
        if not group_target:
            print(f"Nessun gruppo WhatsApp impostato per il corso {lezione.corso}.")
            continue

        # Genera i match
        generate_matches(lezione.id)

        pairs = Match.objects.filter(lezione=lezione, is_rotation=False).select_related('leader', 'follower')
        rotations = Match.objects.filter(lezione=lezione, is_rotation=True).select_related('leader', 'follower')

        pairs_text = "\n".join([f"🕺 {m.leader.nome} {m.leader.cognome}  ↔️  💃 {m.follower.nome} {m.follower.cognome}" for m in pairs if m.leader and m.follower])
        rotations_text = ""
        if rotations.exists():
            rot_names = []
            for r in rotations:
                p = r.leader or r.follower
                if p:
                    rot_names.append(f"{p.nome} {p.cognome} ({p.get_ruolo_display()})")
            rotations_text = "\nIn rotazione: " + ", ".join(rot_names)

        t = Template(template.body)
        c = Context({
            'event_date': lezione.data.strftime('%d/%m/%Y'),
            'corso': str(lezione.corso),
            'pairs': pairs_text + ("\n" + rotations_text if rotations_text else "")
        })
        message = t.render(c)

        log = MessageLog(
            lezione=lezione,
            template=template,
            rendered_text=message,
            status='Inviato'
        )

        try:
            print(f"Inviando coppie definitive per lezione {lezione.id} al gruppo {group_target}...")
            response = send_whatsapp_message(
                group_target,
                message,
                is_group=True
            )
            if not response.get('success'):
                log.status = 'Errore'
                log.error_message = response.get('error', 'Unknown Error')
            log.save()
        except Exception as e:
            log.status = 'Errore'
            log.error_message = str(e)
            log.save()
            print(f"Errore durante l'invio coppie: {e}")


def auto_generate_events():
    """
    Controlla la RecurringSchedule e, per ogni corso attivo o per la schedulazione globale,
    crea le lezioni per i prossimi 7 giorni.
    """
    now = timezone.now()
    today = now.date()

    schedules = RecurringSchedule.objects.all()
    if not schedules.exists():
        return

    for schedule in schedules:
        if not schedule.days_of_week:
            continue

        days = [int(x.strip()) for x in schedule.days_of_week.split(',') if x.strip().isdigit()]
        if not days:
            continue

        corsi = [schedule.corso] if schedule.corso else list(Corso.objects.all())

        for corso in corsi:
            if not corso:
                continue

            for target_day in days:
                days_ahead = target_day - today.weekday()
                if days_ahead < 0:
                    days_ahead += 7

                next_date = today + datetime.timedelta(days=days_ahead)

                if schedule.start_date and next_date < schedule.start_date:
                    continue
                if schedule.end_date and next_date > schedule.end_date:
                    continue

                existing = Lezione.objects.filter(corso=corso, data=next_date).first()
                if not existing:
                    Lezione.objects.create(corso=corso, data=next_date)
                    print(f"Creata automaticamente lezione per {corso} in data {next_date}")


def invia_sondaggio_mattutino_giornaliero():
    """
    Task demone giornaliero: verifica se il giorno odierno è compreso nei giorni abilitati,
    individua tutti i corsi attivi quel giorno (in base al giorno della settimana del corso o lezione prevista oggi)
    e invia il sondaggio (o messaggio) WhatsApp al rispettivo gruppo.
    """
    now = timezone.localtime(timezone.now())
    today = now.date()
    current_weekday = today.weekday()  # 0=Lun ... 6=Dom

    WEEKDAY_TO_GIORNO = {
        0: 'LUNEDI',
        1: 'MARTEDI',
        2: 'MERCOLEDI',
        3: 'GIOVEDI',
        4: 'VENERDI',
        5: 'SABATO',
        6: 'DOMENICA',
    }
    current_giorno = WEEKDAY_TO_GIORNO.get(current_weekday)

    global_config = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
    if not global_config:
        global_config = SondaggioMattutinoConfig.objects.create(
            corso=None,
            orario='08:00',
            giorni_settimana='0,1,2,3,4,5,6',
            testo="Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c'è lezione per il corso {corso} alle {orario}.\nChi di voi sarà presente stasera? Rispondete al sondaggio per confermare la vostra presenza!",
            is_poll=True,
            poll_opzione_1="Ci sono! 🕺💃",
            poll_opzione_2="Non ci sono 🚫",
            is_active=True
        )

    if not global_config.is_active:
        print("[Sondaggio Mattutino] Demone disattivato a livello globale.")
        return

    giorni_globali = [int(x.strip()) for x in global_config.giorni_settimana.split(',') if x.strip().isdigit()]
    if current_weekday not in giorni_globali:
        print(f"[Sondaggio Mattutino] Oggi (weekday {current_weekday}, {current_giorno}) non è tra i giorni abilitati ({giorni_globali}).")
        return

    # Trova i corsi attivi quel giorno:
    # 1) Corsi che hanno giorno_settimana corrispondente al giorno odierno (es. MERCOLEDI)
    # 2) Oppure corsi che hanno esplicitamente una Lezione registrata per oggi
    corsi_attivi_oggi = Corso.objects.filter(
        Q(giorno_settimana=current_giorno) | Q(lezioni__data=today)
    ).select_related('scuola').distinct()

    if not corsi_attivi_oggi.exists():
        print(f"[Sondaggio Mattutino] Nessun corso attivo per il giorno {current_giorno} in data {today.strftime('%d/%m/%Y')}.")
        return

    print(f"[Sondaggio Mattutino] Trovati {corsi_attivi_oggi.count()} corsi attivi per oggi ({current_giorno}): {[c.nome for c in corsi_attivi_oggi]}")

    inviati = 0
    for corso in corsi_attivi_oggi:
        # Configurazione specifica per il corso o globale
        cfg = SondaggioMattutinoConfig.objects.filter(corso=corso).first() or global_config
        if not cfg.is_active:
            print(f"[Sondaggio Mattutino] Configurazione disattiva per il corso {corso.nome}.")
            continue

        group_target = corso.gruppo_whatsapp or (corso.scuola.gruppo_whatsapp if corso.scuola else '')
        if not group_target:
            print(f"[Sondaggio Mattutino] Nessun gruppo WhatsApp impostato per il corso {corso.nome}.")
            continue

        # Recupera o crea la Lezione odierna per il corso attivo
        lezione, created = Lezione.objects.get_or_create(
            corso=corso,
            data=today,
            defaults={'titolo': f"Lezione {today.strftime('%d/%m/%Y')}"}
        )

        # Se la lezione è stata appena creata, inizializza le presenze per gli allievi del corso
        if created:
            for allievo in Allievo.objects.filter(corso=corso, is_active=True):
                Presenza.objects.get_or_create(
                    lezione=lezione,
                    allievo=allievo,
                    defaults={'presente': False, 'fonte': 'whatsapp', 'is_jolly': False}
                )

        orario_str = corso.orario.strftime('%H:%M') if corso.orario else ''
        data_str = today.strftime('%d/%m/%Y')
        scuola_str = corso.scuola.nome if corso.scuola else ''
        argomento_str = (lezione.argomento.titolo if (lezione and lezione.argomento) else 'Da definire')
        corso_str = corso.nome

        testo_renderizzato = (cfg.testo or '')\
            .replace('{corso}', corso_str)\
            .replace('{orario}', orario_str)\
            .replace('{data}', data_str)\
            .replace('{scuola}', scuola_str)\
            .replace('{argomento}', argomento_str)

        try:
            if cfg.is_poll:
                opzioni = [cfg.poll_opzione_1, cfg.poll_opzione_2]
                res = send_whatsapp_message(
                    to=group_target,
                    message=testo_renderizzato,
                    is_group=True,
                    is_poll=True,
                    poll_options=opzioni
                )
            else:
                res = send_whatsapp_message(
                    to=group_target,
                    message=testo_renderizzato,
                    is_group=True
                )

            tmpl, _ = MessageTemplate.objects.get_or_create(
                name='SONDAGGIO_MATTUTINO',
                defaults={'body': cfg.testo}
            )
            status_log = 'Inviato' if res.get('success') else 'Errore'
            err_msg = res.get('error', '')
            MessageLog.objects.create(
                lezione=lezione,
                template=tmpl,
                rendered_text=testo_renderizzato,
                status=status_log,
                error_message=err_msg
            )
            if res.get('success'):
                inviati += 1
                print(f"[Sondaggio Mattutino] Inviato con successo a {group_target} per {corso.nome}")
                # Programma controllo solleciti mancata risposta dopo intervallo ore configurato
                if getattr(cfg, 'sollecito_attivo', False):
                    ore_attesa = getattr(cfg, 'sollecito_ore_attesa', 3) or 3
                    timer = threading.Timer(
                        ore_attesa * 3600,
                        controlla_e_invia_solleciti_mancata_risposta,
                        kwargs={'lezione_id': lezione.id}
                    )
                    timer.daemon = True
                    timer.start()
                    print(f"[Sondaggio Mattutino] Timer sollecito mancata risposta programmato tra {ore_attesa}h per lezione {lezione.id}")
            else:
                print(f"[Sondaggio Mattutino] Errore invio a {group_target}: {err_msg}")
        except Exception as e:
            print(f"[Sondaggio Mattutino] Eccezione invio per {corso.nome}: {e}")

    print(f"[Sondaggio Mattutino] Completato. Inviati con successo {inviati} su {corsi_attivi_oggi.count()} corsi attivi.")



def invia_sondaggio_manuale_corsi(corso_ids, testo_custom=None, is_poll=True, poll_opzioni=None):
    """
    Invia manualmente il sondaggio a una lista di ID corsi.
    Utilizza i placeholder dinamici ({corso}, {orario}, {data}, {scuola}, {argomento}).
    Restituisce la lista degli esiti per ciascun corso.
    """
    now = timezone.localtime(timezone.now())
    today = now.date()

    global_config = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
    default_testo = global_config.testo if global_config else (
        "Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c'è lezione per il corso {corso} alle {orario}.\n"
        "Chi di voi sarà presente stasera? Rispondete al sondaggio per confermare la vostra presenza!"
    )
    base_testo = testo_custom if (testo_custom and testo_custom.strip()) else default_testo

    corsi = Corso.objects.filter(id__in=corso_ids).select_related('scuola')
    results = []

    for corso in corsi:
        group_target = corso.gruppo_whatsapp or (corso.scuola.gruppo_whatsapp if corso.scuola else '')
        if not group_target:
            results.append({
                'corso_id': str(corso.id),
                'corso_nome': corso.nome,
                'scuola_nome': corso.scuola.nome if corso.scuola else '',
                'gruppo_whatsapp': '',
                'success': False,
                'error': "Nessun gruppo WhatsApp configurato per questo corso o scuola."
            })
            continue

        # Cerca la lezione di oggi o la prossima lezione programmata
        lezione = Lezione.objects.filter(corso=corso, data=today).first()
        if not lezione:
            lezione = Lezione.objects.filter(corso=corso, data__gte=today).order_by('data').first()

        orario_str = corso.orario.strftime('%H:%M') if corso.orario else ''
        data_str = lezione.data.strftime('%d/%m/%Y') if lezione else today.strftime('%d/%m/%Y')
        scuola_str = corso.scuola.nome if corso.scuola else ''
        argomento_str = (lezione.argomento.titolo if (lezione and lezione.argomento) else 'Da definire')

        testo_renderizzato = base_testo\
            .replace('{corso}', str(corso.nome))\
            .replace('{orario}', orario_str)\
            .replace('{data}', data_str)\
            .replace('{scuola}', scuola_str)\
            .replace('{argomento}', argomento_str)

        try:
            if is_poll:
                opts = poll_opzioni if (poll_opzioni and len(poll_opzioni) >= 2) else ["Ci sono! 🕺💃", "Non ci sono 🚫"]
                res = send_whatsapp_message(
                    to=group_target,
                    message=testo_renderizzato,
                    is_group=True,
                    is_poll=True,
                    poll_options=opts
                )
            else:
                res = send_whatsapp_message(
                    to=group_target,
                    message=testo_renderizzato,
                    is_group=True
                )

            is_ok = bool(res.get('success'))
            err_msg = res.get('error', '')

            if lezione:
                tmpl, _ = MessageTemplate.objects.get_or_create(
                    name='SONDAGGIO_MANUALE',
                    defaults={'body': base_testo}
                )
                MessageLog.objects.create(
                    lezione=lezione,
                    template=tmpl,
                    rendered_text=testo_renderizzato,
                    status='Inviato' if is_ok else 'Errore',
                    error_message=err_msg
                )

            if is_ok and lezione:
                g_cfg = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
                if g_cfg and getattr(g_cfg, 'sollecito_attivo', False):
                    ore_attesa = getattr(g_cfg, 'sollecito_ore_attesa', 3) or 3
                    timer = threading.Timer(
                        ore_attesa * 3600,
                        controlla_e_invia_solleciti_mancata_risposta,
                        kwargs={'lezione_id': lezione.id}
                    )
                    timer.daemon = True
                    timer.start()
                    print(f"[Sondaggio Manuale] Timer sollecito mancata risposta programmato tra {ore_attesa}h per lezione {lezione.id}")

            results.append({
                'corso_id': str(corso.id),
                'corso_nome': corso.nome,
                'scuola_nome': corso.scuola.nome if corso.scuola else '',
                'gruppo_whatsapp': group_target,
                'success': is_ok,
                'error': err_msg
            })
        except Exception as e:
            results.append({
                'corso_id': str(corso.id),
                'corso_nome': corso.nome,
                'scuola_nome': corso.scuola.nome if corso.scuola else '',
                'gruppo_whatsapp': group_target,
                'success': False,
                'error': str(e)
            })

    return results


def invia_messaggio_sollecito(corso_ids=None):
    """
    Invia il messaggio di sollecito per i corsi specificati oppure per tutti i corsi attivi oggi.
    Sostituisce i placeholder dinamici: {corso}, {orario}, {data}, {scuola}, {argomento}.
    """
    now = timezone.localtime(timezone.now())
    today = now.date()
    current_weekday = today.weekday()

    WEEKDAY_TO_GIORNO = {
        0: 'LUNEDI',
        1: 'MARTEDI',
        2: 'MERCOLEDI',
        3: 'GIOVEDI',
        4: 'VENERDI',
        5: 'SABATO',
        6: 'DOMENICA',
    }
    current_giorno = WEEKDAY_TO_GIORNO.get(current_weekday)

    global_config = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
    default_testo = (
        "⚠️ *Sollecito Presenze - Lezione di stasera*\n"
        "Ragazzi, chi di voi non ha ancora confermato la presenza al corso {corso} ({orario}) è pregato di farlo subito per consentirci di bilanciare coppie e jolly. Grazie! 🙏"
    )
    base_testo = global_config.sollecito_testo if (global_config and global_config.sollecito_testo and global_config.sollecito_testo.strip()) else default_testo

    if corso_ids:
        corsi = Corso.objects.filter(id__in=corso_ids).select_related('scuola')
    else:
        corsi = Corso.objects.filter(
            Q(giorno_settimana=current_giorno) | Q(lezioni__data=today)
        ).select_related('scuola').distinct()

    results = []

    for corso in corsi:
        group_target = corso.gruppo_whatsapp or (corso.scuola.gruppo_whatsapp if corso.scuola else '')
        if not group_target:
            results.append({
                'corso_id': str(corso.id),
                'corso_nome': corso.nome,
                'scuola_nome': corso.scuola.nome if corso.scuola else '',
                'gruppo_whatsapp': '',
                'success': False,
                'error': "Nessun gruppo WhatsApp configurato per questo corso o scuola."
            })
            continue

        lezione = Lezione.objects.filter(corso=corso, data=today).first()
        if not lezione:
            lezione = Lezione.objects.filter(corso=corso, data__gte=today).order_by('data').first()

        orario_str = corso.orario.strftime('%H:%M') if corso.orario else ''
        data_str = lezione.data.strftime('%d/%m/%Y') if lezione else today.strftime('%d/%m/%Y')
        scuola_str = corso.scuola.nome if corso.scuola else ''
        argomento_str = (lezione.argomento.titolo if (lezione and lezione.argomento) else 'Da definire')

        testo_renderizzato = base_testo\
            .replace('{corso}', str(corso.nome))\
            .replace('{orario}', orario_str)\
            .replace('{data}', data_str)\
            .replace('{scuola}', scuola_str)\
            .replace('{argomento}', argomento_str)

        try:
            res = send_whatsapp_message(
                to=group_target,
                message=testo_renderizzato,
                is_group=True
            )
            is_ok = bool(res.get('success'))
            err_msg = res.get('error', '')

            tmpl, _ = MessageTemplate.objects.get_or_create(
                name='SOLLECITO',
                defaults={'body': base_testo}
            )
            MessageLog.objects.create(
                lezione=lezione,
                template=tmpl,
                rendered_text=testo_renderizzato,
                status='Inviato' if is_ok else 'Errore',
                error_message=err_msg
            )

            results.append({
                'corso_id': str(corso.id),
                'corso_nome': corso.nome,
                'scuola_nome': corso.scuola.nome if corso.scuola else '',
                'gruppo_whatsapp': group_target,
                'success': is_ok,
                'error': err_msg
            })
        except Exception as e:
            results.append({
                'corso_id': str(corso.id),
                'corso_nome': corso.nome,
                'scuola_nome': corso.scuola.nome if corso.scuola else '',
                'gruppo_whatsapp': group_target,
                'success': False,
                'error': str(e)
            })

    success_count = sum(1 for r in results if r.get('success'))
    return {
        'success': True,
        'totale_corsi': len(results),
        'inviati_con_successo': success_count,
        'dettagli': results
    }


def invia_sollecito_giornaliero():
    """
    Task demone per l'invio del messaggio di sollecito pomeridiano.
    Verifica se il sollecito è attivo e invia ai corsi odierni.
    """
    global_config = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
    if not global_config or not global_config.sollecito_attivo:
        print("[Sollecito Giornaliero] Sollecito disattivato.")
        return

    now = timezone.localtime(timezone.now())
    today = now.date()
    current_weekday = today.weekday()
    giorni_globali = [int(x.strip()) for x in global_config.giorni_settimana.split(',') if x.strip().isdigit()]
    if current_weekday not in giorni_globali:
        print(f"[Sollecito Giornaliero] Oggi ({current_weekday}) non è tra i giorni abilitati.")
        return

    res = invia_messaggio_sollecito()
    print(f"[Sollecito Giornaliero] Inviati {res['inviati_con_successo']} su {res['totale_corsi']}.")




def controlla_e_invia_solleciti_mancata_risposta(lezione_id=None, corso_ids=None, force=False):
    """
    Controlla se dopo l'intervallo specificato (sollecito_ore_attesa, default 3 ore) dall'invio del sondaggio
    ci sono allievi che NON hanno ancora registrato una risposta (né PRESENTE né ASSENTE).
    Invia a ciascuno di essi il messaggio individuale di sollecito configurato in 'Configurazione Messaggio di Sollecito'.
    Evita invii duplicati registrando lo stato sollecito_inviato su Presenza e in MessageLog.
    """
    now = timezone.localtime(timezone.now())
    today = now.date()

    global_config = SondaggioMattutinoConfig.objects.filter(corso__isnull=True).first()
    if not global_config:
        return {'success': False, 'message': 'Nessuna configurazione globale trovata.'}

    if not global_config.sollecito_attivo and not force:
        return {'success': False, 'message': 'Invio automatico solleciti disattivato nelle impostazioni.'}

    ore_attesa = getattr(global_config, 'sollecito_ore_attesa', 3) or 3
    base_template = (global_config.sollecito_testo or '').strip()
    if not base_template:
        base_template = "Ciao {nickname}, ci sei stasera al corso?"

    if lezione_id:
        lezioni = Lezione.objects.filter(id=lezione_id).select_related('corso', 'corso__scuola')
    elif corso_ids:
        lezioni = Lezione.objects.filter(corso_id__in=corso_ids, data=today).select_related('corso', 'corso__scuola')
    else:
        lezioni = Lezione.objects.filter(data=today).select_related('corso', 'corso__scuola')

    results = []
    solleciti_inviati_totali = 0

    for lezione in lezioni:
        corso = lezione.corso
        if not corso:
            continue

        # Cerca l'ultimo sondaggio inviato per questa lezione
        poll_log = MessageLog.objects.filter(
            lezione=lezione,
            template__name__in=['SONDAGGIO_MATTUTINO', 'SONDAGGIO_MANUALE'],
            status='Inviato'
        ).order_by('-timestamp').first()

        # Se non è stato inviato alcun sondaggio e non è forzato, non inviare solleciti
        if not poll_log and not force:
            continue

        # Verifica se sono trascorse almeno ore_attesa ore
        if poll_log and not force:
            poll_time = timezone.localtime(poll_log.timestamp)
            ore_trascorse = (now - poll_time).total_seconds() / 3600.0
            if ore_trascorse < ore_attesa:
                continue

        allievi = Allievo.objects.filter(corso=corso, is_active=True).order_by('cognome', 'nome')
        allievi_sollecitati = []

        orario_str = corso.orario.strftime('%H:%M') if corso.orario else ''
        data_str = lezione.data.strftime('%d/%m/%Y')
        scuola_str = corso.scuola.nome if corso.scuola else ''
        argomento_str = lezione.argomento.titolo if lezione.argomento else 'Da definire'

        for allievo in allievi:
            p, _ = Presenza.objects.get_or_create(
                lezione=lezione,
                allievo=allievo,
                defaults={'presente': None, 'fonte': 'manuale'}
            )

            # Se ha risposto (sia PRESENTE [True] che ASSENTE [False]), NON sollecitare
            if p.presente is not None:
                continue

            # Se ha già ricevuto il sollecito per questa lezione e non è richiesta forzata, salta
            if p.sollecito_inviato and not force:
                continue

            telefono = (allievo.telefono or '').strip()
            if not telefono:
                continue

            nick = (getattr(allievo, 'nickname', '') or '').strip() or (allievo.nome or '').strip()
            testo_msg = base_template\
                .replace('{nickname}', nick)\
                .replace('<nickname>', nick)\
                .replace('<nome_allievo>', nick)\
                .replace('{nome_allievo}', nick)\
                .replace('<nome>', nick)\
                .replace('{nome}', nick)\
                .replace('{allievo}', nick)\
                .replace('{corso}', str(corso.nome))\
                .replace('{orario}', orario_str)\
                .replace('{data}', data_str)\
                .replace('{scuola}', scuola_str)\
                .replace('{argomento}', argomento_str)

            try:
                res = send_whatsapp_message(
                    to=telefono,
                    message=testo_msg,
                    is_group=False
                )
                is_ok = bool(res.get('success'))
                err_msg = res.get('error', '')

                if is_ok:
                    p.sollecito_inviato = True
                    p.sollecito_inviato_at = timezone.now()
                    p.save(update_fields=['sollecito_inviato', 'sollecito_inviato_at'])

                    tmpl, _ = MessageTemplate.objects.get_or_create(
                        name='SOLLECITO_INDIVIDUALE',
                        defaults={'body': base_template}
                    )
                    MessageLog.objects.create(
                        lezione=lezione,
                        template=tmpl,
                        rendered_text=testo_msg,
                        status='Inviato',
                        error_message=f"Allievo: {allievo.nome} {allievo.cognome} ({telefono})"
                    )

                    allievi_sollecitati.append({
                        'allievo_id': str(allievo.id),
                        'allievo_nome': f"{allievo.nome} {allievo.cognome}",
                        'telefono': telefono,
                        'success': True
                    })
                    solleciti_inviati_totali += 1
                else:
                    allievi_sollecitati.append({
                        'allievo_id': str(allievo.id),
                        'allievo_nome': f"{allievo.nome} {allievo.cognome}",
                        'telefono': telefono,
                        'success': False,
                        'error': err_msg
                    })
            except Exception as e:
                allievi_sollecitati.append({
                    'allievo_id': str(allievo.id),
                    'allievo_nome': f"{allievo.nome} {allievo.cognome}",
                    'telefono': telefono,
                    'success': False,
                    'error': str(e)
                })

        results.append({
            'lezione_id': str(lezione.id),
            'corso': str(corso),
            'data': data_str,
            'totale_allievi_senza_risposta': len(allievi_sollecitati),
            'sollecitati_con_successo': sum(1 for a in allievi_sollecitati if a.get('success')),
            'dettagli_allievi': allievi_sollecitati
        })

    return {
        'success': True,
        'solleciti_inviati_totali': solleciti_inviati_totali,
        'lezioni_elaborate': len(results),
        'dettagli': results
    }


_sollecito_daemon_started = False

def start_sollecito_checker_daemon():
    """
    Avvia un demone in background per verificare ogni 10 minuti se ci sono lezioni
    per cui sono trascorse almeno sollecito_ore_attesa ore dall'invio del sondaggio,
    inviando i solleciti WhatsApp agli allievi che non hanno ancora risposto.
    """
    global _sollecito_daemon_started
    if _sollecito_daemon_started:
        return
    _sollecito_daemon_started = True

    def _loop():
        time.sleep(20)  # Breve attesa iniziale
        while True:
            try:
                controlla_e_invia_solleciti_mancata_risposta()
            except Exception as e:
                print(f"[Demone Solleciti Mancata Risposta] Errore: {e}")
            time.sleep(600)  # Controlla ogni 10 minuti

    t = threading.Thread(target=_loop, daemon=True, name="SollecitoMancataRispostaDaemon")
    t.start()
    print("[Demone Solleciti Mancata Risposta] Avviato con successo.")
