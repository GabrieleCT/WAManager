import json
import os
import requests
from datetime import timedelta, datetime

GATEWAY_URL = os.environ.get("GATEWAY_BASE_URL", "http://127.0.0.1:4002")
from django.shortcuts import render, redirect, get_object_or_404
from django.utils import timezone
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .models import (
    Allievo, Corso, Scuola, Argomento, Lezione, Presenza, Match, MessageTemplate,
    MessageLog, RecurringSchedule, Role, Level, Recensione, GeminiLog
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
        if last_10:
            for a in Allievo.objects.filter(is_active=True):
                a_digits = ''.join(filter(str.isdigit, a.telefono))
                if a_digits and a_digits.endswith(last_10):
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
        resp = requests.get(f'{GATEWAY_URL}/api/status', timeout=3)
        return Response(resp.json())
    except Exception as e:
        return Response({'status': 'OFFLINE', 'error': str(e)})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def wa_logout(request):
    try:
        resp = requests.post(f'{GATEWAY_URL}/api/logout', timeout=5)
        data = resp.json()
        return Response({'success': True, 'message': data.get('message', 'Disconnesso')})
    except Exception as e:
        return Response({'success': False, 'error': str(e)})


@login_required(login_url='/admin/login/')
def onboarding(request):
    try:
        resp = requests.get(f'{GATEWAY_URL}/api/status', timeout=3)
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
        resp = requests.get(f'{GATEWAY_URL}/api/status', timeout=2)
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
                    requests.post(f'{GATEWAY_URL}/api/settings', json={'debug_mode': recurring.debug_mode}, timeout=3)
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
        if last_10:
            for a in Allievo.objects.filter(is_active=True):
                a_digits = ''.join(filter(str.isdigit, a.telefono))
                if a_digits and a_digits.endswith(last_10):
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


@csrf_exempt
def whatsapp_message_webhook(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'POST only'}, status=405)

    try:
        data = json.loads(request.body)
        
        # Estrarre voter_id, group_id, push_name e text
        voter_id = data.get('voter', data.get('from', data.get('author', data.get('sender', ''))))
        text = data.get('text', data.get('body', ''))
        group_id = data.get('groupId', data.get('remoteJid', ''))
        push_name = data.get('pushName', '')

        if 'payload' in data:
            payload = data['payload']
            voter_id = payload.get('voter', payload.get('author', payload.get('from', payload.get('sender', voter_id))))
            if isinstance(voter_id, dict):
                voter_id = voter_id.get('_serialized', '') or voter_id.get('user', '')
            text = payload.get('body', payload.get('text', text))
            group_id = payload.get('groupId', payload.get('remoteJid', group_id))
            push_name = payload.get('pushName', push_name)
            
        with open('webhook_debug.log', 'a', encoding='utf-8') as f:
            f.write(f"[{timezone.now()}] Webhook ricevuto: voter={voter_id}, group={group_id}, text={text}\n")
        
        if not text:
            return JsonResponse({'success': False, 'message': 'Testo mancante.'})

        # 1. VERIFICA RIGOROSA: Il messaggio DEVE provenire esclusivamente da uno dei 7 gruppi dei corsi!
        # Se proviene da un gruppo scuola (es. San Donato o Ripamonti generale), chat 1:1 o altri gruppi -> IGNORA TOTALMENTE.
        if not group_id or not str(group_id).strip().endswith('@g.us'):
            with open('webhook_debug.log', 'a', encoding='utf-8') as f:
                f.write(f"[{timezone.now()}] Messaggio SCARTATO: non e un gruppo WhatsApp ({group_id}).\n")
            return JsonResponse({'success': False, 'message': 'Ignorato: non e un gruppo.'})

        clean_gid = str(group_id).strip()
        gid_no_suffix = clean_gid.replace('@g.us', '')
        gid_with_suffix = gid_no_suffix + '@g.us'
        from django.db.models import Q
        corso = Corso.objects.filter(
            Q(gruppo_whatsapp__iexact=clean_gid) |
            Q(gruppo_whatsapp__iexact=gid_no_suffix) |
            Q(gruppo_whatsapp__iexact=gid_with_suffix)
        ).first()

        if not corso:
            with open('webhook_debug.log', 'a', encoding='utf-8') as f:
                f.write(f"[{timezone.now()}] Messaggio SCARTATO: gruppo {group_id} NON appartiene a nessun corso (es. gruppo scuola o gruppo esterno).\n")
            return JsonResponse({'success': False, 'message': f'Gruppo {group_id} ignorato: appartiene alla scuola o a chat esterna, non a uno dei 7 corsi.'})

        # 1.1 VERIFICA FINESTRA TEMPORALE E GIORNI DI MONITORAGGIO GEMINI
        import datetime as dt_mod
        now_local = timezone.localtime()
        current_time = now_local.time()

        sched = RecurringSchedule.objects.first()
        monitoring_active = sched.gemini_monitoring_active if (sched and hasattr(sched, 'gemini_monitoring_active')) else True
        time_start = sched.gemini_time_start if (sched and hasattr(sched, 'gemini_time_start') and sched.gemini_time_start) else dt_mod.time(7, 0)
        time_end = sched.gemini_time_end if (sched and hasattr(sched, 'gemini_time_end') and sched.gemini_time_end) else dt_mod.time(13, 0)
        only_course_days = sched.gemini_only_course_days if (sched and hasattr(sched, 'gemini_only_course_days')) else True
        custom_days = (sched.gemini_custom_days if (sched and hasattr(sched, 'gemini_custom_days') and sched.gemini_custom_days) else "LUNEDI,MERCOLEDI,GIOVEDI").upper()

        if not monitoring_active:
            with open('webhook_debug.log', 'a', encoding='utf-8') as f:
                f.write(f"[{now_local}] Messaggio SCARTATO: Monitoraggio Gemini disattivato da configurazione.\n")
            return JsonResponse({'success': False, 'message': 'Monitoraggio Gemini disattivato da configurazione.'})

        # Verifica finestra oraria
        if time_start <= time_end:
            in_time_window = (time_start <= current_time <= time_end)
        else:
            in_time_window = (current_time >= time_start or current_time <= time_end)

        if not in_time_window:
            with open('webhook_debug.log', 'a', encoding='utf-8') as f:
                f.write(f"[{now_local}] Messaggio SCARTATO: fuori orario monitoraggio ({current_time.strftime('%H:%M')} fuori da {time_start.strftime('%H:%M')} - {time_end.strftime('%H:%M')}).\n")
            return JsonResponse({
                'success': False,
                'message': f"Fuori finestra oraria di monitoraggio ({current_time.strftime('%H:%M')} non compreso tra {time_start.strftime('%H:%M')} e {time_end.strftime('%H:%M')})."
            })

        # Verifica giorni monitoraggio
        giorni_map = {
            0: 'LUNEDI',
            1: 'MARTEDI',
            2: 'MERCOLEDI',
            3: 'GIOVEDI',
            4: 'VENERDI',
            5: 'SABATO',
            6: 'DOMENICA',
        }
        today_giorno = giorni_map.get(now_local.weekday(), '')

        if only_course_days:
            is_course_day = (corso.giorno_settimana and corso.giorno_settimana.upper() == today_giorno)
            has_lesson_today = Lezione.objects.filter(corso=corso, data=now_local.date()).exists()
            if not is_course_day and not has_lesson_today:
                with open('webhook_debug.log', 'a', encoding='utf-8') as f:
                    f.write(f"[{now_local}] Messaggio SCARTATO: oggi ({today_giorno}) non e il giorno di corso per {corso} ({corso.giorno_settimana}).\n")
                return JsonResponse({
                    'success': False,
                    'message': f"Oggi ({today_giorno}) non e il giorno di lezione per {corso.nome_display if hasattr(corso, 'nome_display') else corso}."
                })
        else:
            allowed_days = [d.strip() for d in custom_days.split(',') if d.strip()]
            if today_giorno not in allowed_days:
                with open('webhook_debug.log', 'a', encoding='utf-8') as f:
                    f.write(f"[{now_local}] Messaggio SCARTATO: oggi ({today_giorno}) non e tra i giorni abilitati ({custom_days}).\n")
                return JsonResponse({
                    'success': False,
                    'message': f"Oggi ({today_giorno}) non rientra nei giorni di monitoraggio abilitati ({custom_days})."
                })

        # 2. Cerca l'allievo associato al mittente
        phone_digits = ''.join(filter(str.isdigit, str(voter_id)))
        last_10 = phone_digits[-10:] if len(phone_digits) >= 10 else phone_digits

        allievo = None
        if last_10:
            # Cerca prima tra gli allievi iscritti a questo corso
            for a in corso.allievi.filter(is_active=True):
                a_digits = ''.join(filter(str.isdigit, a.telefono or ''))
                if a_digits and a_digits.endswith(last_10):
                    allievo = a
                    break
            # Se non trovato nel corso specifico, cerca tra tutti gli allievi attivi
            if not allievo:
                for a in Allievo.objects.filter(is_active=True):
                    a_digits = ''.join(filter(str.isdigit, a.telefono or ''))
                    if a_digits and a_digits.endswith(last_10):
                        allievo = a
                        break

        # 3. Cerca la lezione imminente o piu recente del corso
        now = timezone.now()
        prossima_lezione = Lezione.objects.filter(corso=corso, data__gte=now.date()).order_by('data').first()
        if not prossima_lezione:
            prossima_lezione = Lezione.objects.filter(corso=corso).order_by('-data').first()

        # 4. Recupero API Key Gemini
        sched = RecurringSchedule.objects.first()
        api_key = sched.gemini_api_key if sched else None

        # 5. Costruzione del prompt per Gemini
        mittente_label = f"{allievo.nome} {allievo.cognome}" if allievo else (push_name or (f"+{phone_digits}" if phone_digits else str(voter_id)) or "Allievo")
        corso_label = str(corso)
        lezione_label = f"del {prossima_lezione.data.strftime('%d/%m/%Y')} ore {prossima_lezione.corso.orario.strftime('%H:%M')}" if (prossima_lezione and prossima_lezione.corso and prossima_lezione.corso.orario) else ("imminente" if prossima_lezione else "")

        prompt = f'''Analizza il seguente messaggio inviato nel gruppo WhatsApp del {corso_label} da {mittente_label} per la lezione {lezione_label}.
Messaggio: "{text}"

Devi interpretare l'intenzione di presenza/assenza e restituire SOLO UNA di queste 5 stringhe esatte, senza spiegazioni, punteggiatura o spazi aggiuntivi:
- PRESENTE_SINGOLO (se ha confermato la sua presenza da solo/a)
- ASSENTE_SINGOLO (se ha comunicato che non ci sarà, solo per sé)
- PRESENTE_COPPIA (se ha parlato al plurale, es. "ci siamo", "veniamo", confermando per sé e per il partner)
- ASSENTE_COPPIA (se ha parlato al plurale, es. "non ci siamo", "saltiamo", confermando l'assenza per entrambi)
- IGNOTA (se non è un messaggio di conferma presenza/assenza o è una domanda/saluto/battuta)'''

        risposta_ai = ""
        esito = "IGNOTA"

        if not api_key:
            risposta_ai = "ERRORE: API Key di Gemini non configurata. Impostala nella sezione Impostazioni -> Gemini AI."
            esito = "ERRORE"
        else:
            headers = {'Content-Type': 'application/json'}
            payload_ai = {
                "contents": [{"parts": [{"text": prompt}]}]
            }
            # Fallback cascade su modelli disponibili per evitare blocchi quota HTTP 429
            candidate_models = ['gemini-3.5-flash', 'gemini-3.1-flash-lite', 'gemini-3.6-flash', 'gemini-3.8-flash']
            success_call = False
            last_err = ""

            for model_name in candidate_models:
                gemini_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
                try:
                    res = requests.post(gemini_url, headers=headers, json=payload_ai, timeout=15)
                    if res.status_code == 200:
                        res_data = res.json()
                        candidates = res_data.get('candidates', [])
                        if candidates and 'content' in candidates[0] and 'parts' in candidates[0]['content']:
                            risposta_ai = candidates[0]['content']['parts'][0]['text'].strip()
                            success_call = True
                            break
                        else:
                            risposta_ai = res.text
                            success_call = True
                            break
                    elif res.status_code == 429:
                        last_err = f"HTTP 429 ({model_name}): {res.text}"
                        continue
                    else:
                        last_err = f"HTTP {res.status_code} ({model_name}): {res.text}"
                except Exception as e:
                    last_err = f"ERRORE ({model_name}): {str(e)}"
                    continue

            if not success_call:
                risposta_ai = last_err or "ERRORE: Impossibile completare la chiamata a Gemini."

            # Pulisci eventuali formattazioni o markdown
            r_upper = risposta_ai.upper()
            if "PRESENTE_COPPIA" in r_upper: esito = "PRESENTE_COPPIA"
            elif "ASSENTE_COPPIA" in r_upper: esito = "ASSENTE_COPPIA"
            elif "PRESENTE_SINGOLO" in r_upper: esito = "PRESENTE_SINGOLO"
            elif "ASSENTE_SINGOLO" in r_upper: esito = "ASSENTE_SINGOLO"
            elif "ERRORE" in r_upper or "HTTP " in r_upper: esito = "ERRORE"
            else: esito = "IGNOTA"

        # 6. Aggiorna Presenze e determina ESATTAMENTE quale allievo o coppia viene modificata
        azione_presenze = ""
        partner_coinvolto = None

        if not allievo:
            azione_presenze = f"Nessun allievo identificato nel database per il mittente ({mittente_label}). Nessuna presenza modificata."
        elif not prossima_lezione:
            azione_presenze = f"Nessuna lezione imminente trovata per il corso {corso}. Nessuna presenza modificata."
        elif 'PRESENTE' in esito or 'ASSENTE' in esito:
            is_present = 'PRESENTE' in esito
            is_coppia = 'COPPIA' in esito
            stato_label = "PRESENTE" if is_present else "ASSENTE"

            # 1. Imposta la presenza dell'allievo mittente
            Presenza.objects.update_or_create(
                lezione=prossima_lezione,
                allievo=allievo,
                defaults={'presente': is_present, 'fonte': 'whatsapp'}
            )

            # 2. Se risposta plurale/coppia, verifica presenza del partner
            if is_coppia:
                partner_coinvolto = allievo.partner
                if partner_coinvolto:
                    Presenza.objects.update_or_create(
                        lezione=prossima_lezione,
                        allievo=partner_coinvolto,
                        defaults={'presente': is_present, 'fonte': 'whatsapp'}
                    )
                    azione_presenze = f"Coppia impostata come {stato_label}: {allievo.nome} {allievo.cognome} & {partner_coinvolto.nome} {partner_coinvolto.cognome}"
                else:
                    azione_presenze = f"Allievo impostato come {stato_label}: {allievo.nome} {allievo.cognome} (Risposta plurale, ma nessun partner associato a sistema per questo allievo)"
            else:
                azione_presenze = f"Allievo impostato come {stato_label}: {allievo.nome} {allievo.cognome}"
        elif esito == "IGNOTA":
            azione_presenze = f"Nessuna presenza modificata per {allievo.nome} {allievo.cognome} (il messaggio non e una conferma di presenza o assenza)"
        else:
            azione_presenze = f"Nessuna presenza modificata (errore elaborazione AI: {risposta_ai})"

        # 7. Registra SEMPRE il log completo in GeminiLog
        mittente_str = f"{allievo.nome} {allievo.cognome}" if allievo else (f"{push_name} ({voter_id})".strip() if push_name else str(voter_id))
        log_entry = GeminiLog.objects.create(
            allievo=allievo,
            corso=corso,
            gruppo_whatsapp=group_id or '',
            mittente=mittente_str,
            lezione=prossima_lezione,
            testo_originale=text,
            chiamata_ai=prompt,
            risposta_ai=risposta_ai,
            esito_interpretato=esito,
            azione_presenze=azione_presenze,
            partner_coinvolto=partner_coinvolto
        )

        with open('webhook_debug.log', 'a', encoding='utf-8') as f:
            f.write(f"[{timezone.now()}] GeminiLog creato: ID={log_entry.id}, esito={esito}, azione={azione_presenze}\n")

        return JsonResponse({
            'success': True,
            'log_id': str(log_entry.id),
            'esito': esito,
            'allievo': str(allievo) if allievo else None,
            'corso': str(corso) if corso else None,
            'azione_presenze': azione_presenze,
            'risposta_ai': risposta_ai
        })

    except Exception as e:
        with open('webhook_debug.log', 'a', encoding='utf-8') as f:
            f.write(f"[{timezone.now()}] Errore webhook: {e}\n")
        return JsonResponse({'success': False, 'error': str(e)}, status=500)
