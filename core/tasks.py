import datetime
from django.utils import timezone
from django.template import Template, Context
from .models import (
    Lezione, Corso, Allievo, Presenza, Match, MessageTemplate, MessageLog, RecurringSchedule
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
