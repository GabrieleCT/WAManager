import json
import requests
from datetime import timedelta, datetime
from django.shortcuts import render, redirect, get_object_or_404
from django.utils import timezone
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .models import (
    Allievo, Corso, Scuola, Argomento, Lezione, Presenza, Match, MessageTemplate,
    MessageLog, RecurringSchedule, Role, Level, Recensione
)


# ─── RSVP Pubblico (per lezione) ────────────────────────────────

def rsvp_view(request, event_id):
    """Visualizzazione pubblica per confermare presenza a una lezione."""
    lezione = get_object_or_404(Lezione, id=event_id)

    if request.method == 'POST':
        phone = request.POST.get('phone', '').strip()
        status_val = request.POST.get('status', 'attending')

        phone_digits = ''.join(filter(str.isdigit, phone))
        last_10 = phone_digits[-10:] if len(phone_digits) >= 10 else phone_digits

        allievo = None
        for a in Allievo.objects.filter(is_active=True):
            a_digits = ''.join(filter(str.isdigit, a.telefono))
            if a_digits.endswith(last_10):
                allievo = a
                break

        if not allievo:
            return render(request, 'core/rsvp.html', {
                'event': lezione,
                'error': 'Numero non trovato nell\'elenco allievi. Contatta la scuola.'
            })

        is_present = (status_val == 'attending')
        Presenza.objects.update_or_create(
            lezione=lezione,
            allievo=allievo,
            defaults={'presente': is_present}
        )

        return render(request, 'core/rsvp.html', {
            'event': lezione,
            'success': True,
            'allievo': allievo,
            'is_present': is_present
        })

    return render(request, 'core/rsvp.html', {'event': lezione})


# ─── WhatsApp Gateway Status & Onboarding ───────────────────────

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def wa_status(request):
    try:
        resp = requests.get('http://127.0.0.1:4002/api/status', timeout=3)
        return Response(resp.json())
    except Exception as e:
        return Response({'status': 'OFFLINE', 'error': str(e)})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def wa_logout(request):
    try:
        resp = requests.post('http://127.0.0.1:4002/api/logout', timeout=5)
        data = resp.json()
        return Response({'success': True, 'message': data.get('message', 'Disconnesso')})
    except Exception as e:
        return Response({'success': False, 'error': str(e)})


@login_required(login_url='/admin/login/')
def onboarding(request):
    try:
        resp = requests.get('http://127.0.0.1:4002/api/status', timeout=3)
        data = resp.json()
        if data.get('status') == 'CONNECTED':
            return redirect('core:dashboard')
    except Exception:
        pass
    return render(request, 'core/onboarding.html')


# ─── Dashboard Web ──────────────────────────────────────────────

@login_required(login_url='/admin/login/')
def dashboard(request):
    try:
        resp = requests.get('http://127.0.0.1:4002/api/status', timeout=2)
        data = resp.json()
        if data.get('status') != 'CONNECTED':
            return redirect('core:onboarding')
    except Exception:
        return redirect('core:onboarding')

    now = timezone.now()
    next_week = now + timedelta(days=7)

    prossima_lezione = Lezione.objects.filter(
        data__gte=now.date(),
        data__lte=next_week.date()
    ).order_by('data').first()

    context = {
        'upcoming_event': prossima_lezione,
        'scuole': Scuola.objects.all(),
        'corsi': Corso.objects.all(),
        'argomenti': Argomento.objects.all(),
        'recent_logs': MessageLog.objects.order_by('-timestamp')[:10],
        'rsvp_template': MessageTemplate.objects.filter(name='RSVP').first(),
        'match_template': MessageTemplate.objects.filter(name='MATCH').first(),
        'recurring': RecurringSchedule.objects.first(),
    }

    if prossima_lezione:
        presenze = Presenza.objects.filter(lezione=prossima_lezione, presente=True)
        leaders = sum(1 for p in presenze if p.allievo.ruolo == Role.LEADER)
        followers = sum(1 for p in presenze if p.allievo.ruolo == Role.FOLLOWER)
        both = sum(1 for p in presenze if p.allievo.ruolo == Role.BOTH)

        context['stats'] = {
            'total': presenze.count(),
            'leaders': leaders,
            'followers': followers,
            'both': both,
        }
        context['matches'] = Match.objects.filter(lezione=prossima_lezione, is_rotation=False)
        context['rotations'] = Match.objects.filter(lezione=prossima_lezione, is_rotation=True)

    return render(request, 'core/dashboard.html', context)


# ─── Trigger e impostazioni rapide ──────────────────────────────

@login_required
def update_group(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            corso_id = data.get('corso_id')
            if corso_id:
                corso = Corso.objects.get(id=corso_id)
                corso.gruppo_whatsapp = data.get('group_name', '')
                corso.save()
            return JsonResponse({'success': True, 'message': 'Gruppo salvato!'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False}, status=405)


@login_required
def update_templates(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            rsvp_body = data.get('rsvp_body')
            match_body = data.get('match_body')

            if rsvp_body:
                MessageTemplate.objects.update_or_create(name='RSVP', defaults={'body': rsvp_body})
            if match_body:
                MessageTemplate.objects.update_or_create(name='MATCH', defaults={'body': match_body})

            return JsonResponse({'success': True, 'message': 'Template salvati!'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False}, status=405)


@login_required
def update_scheduling(request):
    return JsonResponse({'success': True, 'message': 'Schedulazione aggiornata!'})


@login_required
def update_recurring(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            recurring = RecurringSchedule.objects.first()
            if not recurring:
                recurring = RecurringSchedule()

            recurring.days_of_week = data.get('days_of_week', "0")
            recurring.time = datetime.strptime(data.get('time', '21:00'), '%H:%M').time()

            if data.get('start_date'):
                recurring.start_date = datetime.strptime(data.get('start_date'), '%Y-%m-%d').date()
            if data.get('end_date'):
                recurring.end_date = datetime.strptime(data.get('end_date'), '%Y-%m-%d').date()

            recurring.rsvp_days_before = int(data.get('rsvp_days', 0))
            recurring.rsvp_time = datetime.strptime(data.get('rsvp_time', '10:00'), '%H:%M').time()

            if data.get('match_time'):
                recurring.match_time = datetime.strptime(data.get('match_time', '19:00'), '%H:%M').time()
            if 'rsvp_mode' in data:
                recurring.rsvp_mode = data.get('rsvp_mode')
            if 'gemini_api_key' in data:
                recurring.gemini_api_key = data.get('gemini_api_key')
            if 'debug_mode' in data:
                recurring.debug_mode = data.get('debug_mode')
                try:
                    requests.post('http://127.0.0.1:4002/api/settings', json={'debug_mode': recurring.debug_mode}, timeout=3)
                except Exception:
                    pass

            recurring.save()
            return JsonResponse({'success': True, 'message': 'Schedulazione salvata!'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False}, status=405)


@login_required
def trigger_rsvp(request):
    if request.method == 'POST':
        try:
            from .tasks import scheduled_rsvp_announcement
            scheduled_rsvp_announcement()
            return JsonResponse({'success': True, 'message': 'Adesioni avviate!'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False}, status=405)


@login_required
def trigger_match(request):
    if request.method == 'POST':
        try:
            from .tasks import scheduled_match_announcement
            scheduled_match_announcement()
            return JsonResponse({'success': True, 'message': 'Coppie generate e inviate!'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False}, status=405)


# ─── Webhook per voti sondaggi WhatsApp ─────────────────────────

@csrf_exempt
def poll_vote_webhook(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        data = json.loads(request.body)
        voter_id = data.get('voter', '')
        selected_options = data.get('selectedOptions', [])

        if 'payload' in data:
            payload = data['payload']
            voter_id = payload.get('voter', payload.get('author', payload.get('from', '')))
            if isinstance(voter_id, dict):
                voter_id = voter_id.get('_serialized', '') or voter_id.get('user', '')
            selected_options = payload.get('selectedOptions', [])
            if selected_options and isinstance(selected_options[0], dict):
                selected_options = [opt.get('name', '') for opt in selected_options]

        if not voter_id:
            return JsonResponse({'success': False, 'message': 'Voter mancante.'})

        phone_digits = ''.join(filter(str.isdigit, str(voter_id)))
        last_10 = phone_digits[-10:] if len(phone_digits) >= 10 else phone_digits

        allievo = None
        for a in Allievo.objects.filter(is_active=True):
            a_digits = ''.join(filter(str.isdigit, a.telefono))
            if a_digits.endswith(last_10):
                allievo = a
                break

        if not allievo:
            return JsonResponse({'success': False, 'message': 'Allievo sconosciuto, voto ignorato.'})

        is_present = any('Ci sono' in str(opt) or '🕺' in str(opt) or '💃' in str(opt) for opt in selected_options)

        # Cerca la prossima lezione per il corso dell'allievo (o la più vicina)
        now = timezone.now()
        lezione_query = Lezione.objects.filter(data__gte=now.date())
        if allievo.corso:
            lezione_query = lezione_query.filter(corso=allievo.corso)
        prossima_lezione = lezione_query.order_by('data').first()

        if not prossima_lezione:
            return JsonResponse({'success': False, 'message': 'Nessuna lezione imminente trovata per questo allievo.'})

        Presenza.objects.update_or_create(
            lezione=prossima_lezione,
            allievo=allievo,
            defaults={'presente': is_present}
        )

        return JsonResponse({
            'success': True,
            'allievo': f"{allievo.nome} {allievo.cognome}",
            'presente': is_present,
            'lezione': str(prossima_lezione)
        })
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)


# ─── API Partecipanti / Allievi (Retrocompatibile con dashboard) ──

@login_required
def list_participants(request):
    allievi = Allievo.objects.all().order_by('cognome', 'nome')
    data = []
    for a in allievi:
        data.append({
            'id': str(a.id),
            'first_name': a.nome,
            'last_name': a.cognome,
            'phone_number': a.telefono,
            'gender': 'M',
            'role': a.ruolo,
            'level': a.livello,
            'is_active': a.is_active,
            'is_prospect': a.is_prospect,
            'recensione': a.recensione,
            'corso': str(a.corso) if a.corso else None,
            'corso_id': str(a.corso_id) if a.corso_id else None,
            'note': a.note
        })
    return JsonResponse({'participants': data})


@login_required
def save_participant(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            p_id = data.get('id')

            corso_obj = None
            corso_id = data.get('corso') or data.get('corso_id')
            if corso_id:
                corso_obj = Corso.objects.filter(id=corso_id).first()

            defaults = {
                'nome': data.get('first_name', data.get('nome', '')),
                'cognome': data.get('last_name', data.get('cognome', '')),
                'telefono': data.get('phone_number', data.get('telefono', '')),
                'ruolo': data.get('role', data.get('ruolo', Role.LEADER)),
                'livello': data.get('level', data.get('livello', Level.PRINCIPIANTE)),
                'corso': corso_obj,
                'recensione': data.get('recensione', Recensione.NO),
                'is_active': data.get('is_active', True),
                'is_prospect': data.get('is_prospect', False),
                'note': data.get('note', '')
            }

            if p_id:
                Allievo.objects.update_or_create(id=p_id, defaults=defaults)
            else:
                Allievo.objects.create(**defaults)

            return JsonResponse({'success': True, 'message': 'Allievo salvato con successo!'})
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False}, status=405)


@login_required
def delete_participant(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            p_id = data.get('id')
            if p_id:
                Allievo.objects.filter(id=p_id).delete()
                return JsonResponse({'success': True, 'message': 'Allievo eliminato!'})
            return JsonResponse({'success': False, 'message': 'ID mancante.'}, status=400)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False}, status=405)

