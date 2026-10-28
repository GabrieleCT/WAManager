import time
import requests
import logging
import threading
from django.utils import timezone
from .models import Lezione, Presenza, Allievo, RecurringSchedule, GeminiLog

logger = logging.getLogger(__name__)

# Modelli Gemini candidati ordinati per affidabilità, ampiezza quota e velocità
CANDIDATE_GEMINI_MODELS = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-3.5-flash',
    'gemini-flash-latest',
    'gemini-3.7-flash',
    'gemini-3.8-flash',
]


def call_gemini_with_fallback(prompt, api_key, max_attempts=3, backoff_seconds=2.0):
    """
    Esegue la chiamata all'API di Gemini con:
    1. Cascata automatica su altri motori se quello attuale restituisce 503 (sovraccarico), 429 (quota) o errore transitorio.
    2. Ripetizione della chiamata con backoff progressivo fino a un massimo di max_attempts tentativi completi.

    Ritorna:
      (success: bool, text_response: str, used_model: str, attempts_made: int, error_log: str)
    """
    if not api_key:
        return False, "ERRORE: API Key di Gemini non configurata.", "", 0, "Missing API Key"

    headers = {'Content-Type': 'application/json'}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}]
    }

    last_err = ""
    attempt_errors = []

    for attempt in range(1, max_attempts + 1):
        for model_name in CANDIDATE_GEMINI_MODELS:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
            try:
                res = requests.post(url, headers=headers, json=payload, timeout=12)
                if res.status_code == 200:
                    res_data = res.json()
                    candidates = res_data.get('candidates', [])
                    if candidates and 'content' in candidates[0] and 'parts' in candidates[0]['content']:
                        text = candidates[0]['content']['parts'][0]['text'].strip()
                        return True, text, model_name, attempt, ""
                    else:
                        text = res.text.strip()
                        return True, text, model_name, attempt, ""

                # Errore transitorio (503 Service Unavailable, 429 Quota/Rate Limit, 500, 502, 504)
                if res.status_code in (503, 429, 500, 502, 504):
                    err_msg = f"HTTP {res.status_code} ({model_name}, tentativo {attempt}): {res.text[:180]}"
                    attempt_errors.append(err_msg)
                    last_err = err_msg
                    logger.warning("Gemini transient error, fallback to next model: %s", err_msg)
                    # Passa subito al motore successivo nella lista
                    continue
                elif res.status_code == 404:
                    # Modello non disponibile per l'account
                    continue
                elif res.status_code in (400, 401, 403):
                    # Errore permanente
                    err_msg = f"HTTP {res.status_code} ({model_name}): {res.text[:180]}"
                    return False, err_msg, model_name, attempt, err_msg
                else:
                    last_err = f"HTTP {res.status_code} ({model_name}): {res.text[:180]}"
                    continue
            except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as e:
                err_msg = f"Timeout/Connessione ({model_name}, tentativo {attempt}): {str(e)[:120]}"
                attempt_errors.append(err_msg)
                last_err = err_msg
                logger.warning("Gemini network error, fallback to next model: %s", err_msg)
                continue
            except Exception as e:
                err_msg = f"Eccezione ({model_name}, tentativo {attempt}): {str(e)[:120]}"
                attempt_errors.append(err_msg)
                last_err = err_msg
                continue

        # Se tutti i modelli hanno restituito errori temporanei in questo ciclo e abbiamo altri tentativi disponibili
        if attempt < max_attempts:
            sleep_duration = backoff_seconds * attempt
            time.sleep(sleep_duration)

    summary_errors = " | ".join(attempt_errors[-3:]) if attempt_errors else last_err
    return False, last_err or "ERRORE: Impossibile completare la chiamata a Gemini.", "", max_attempts, summary_errors


def parse_and_apply_presenze(allievo, prossima_lezione, risposta_ai, mittente_label, corso):
    """
    Interpreta l'esito dal testo restituito da Gemini e aggiorna il record Presenza.
    Ritorna:
      (esito, azione_presenze, partner_coinvolto)
    """
    r_upper = risposta_ai.upper() if risposta_ai else ""
    if "PRESENTE_COPPIA" in r_upper: esito = "PRESENTE_COPPIA"
    elif "ASSENTE_COPPIA" in r_upper: esito = "ASSENTE_COPPIA"
    elif "PRESENTE_SINGOLO" in r_upper: esito = "PRESENTE_SINGOLO"
    elif "ASSENTE_SINGOLO" in r_upper: esito = "ASSENTE_SINGOLO"
    elif "ERRORE" in r_upper or "HTTP " in r_upper: esito = "ERRORE"
    else: esito = "IGNOTA"

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
        azione_presenze = f"Nessuna presenza modificata per {allievo.nome} {allievo.cognome} (il messaggio non è una conferma di presenza o assenza)"
    else:
        azione_presenze = f"Nessuna presenza modificata (errore elaborazione AI: {risposta_ai})"

    return esito, azione_presenze, partner_coinvolto


def retry_gemini_log(log_id):
    """
    Riesegue la chiamata a Gemini per un GeminiLog specifico (ad es. dopo un 503 o errore transitorio),
    aggiornando l'esito, le presenze collegate e il log stesso.
    """
    try:
        log_entry = GeminiLog.objects.get(id=log_id)
    except GeminiLog.DoesNotExist:
        return False, "Log non trovato"

    sched = RecurringSchedule.objects.first()
    api_key = sched.gemini_api_key if sched else None
    if not api_key:
        return False, "API Key di Gemini non configurata"

    prompt = log_entry.chiamata_ai
    if not prompt:
        # Se non era stato salvato il prompt, ricostruiscilo
        corso_label = str(log_entry.corso) if log_entry.corso else ""
        lezione = log_entry.lezione
        lezione_label = f"del {lezione.data.strftime('%d/%m/%Y')} ore {lezione.corso.orario.strftime('%H:%M')}" if (lezione and lezione.corso and lezione.corso.orario) else ""
        mittente_label = log_entry.mittente or (f"{log_entry.allievo.nome} {log_entry.allievo.cognome}" if log_entry.allievo else "Allievo")
        prompt = f'''Analizza il seguente messaggio inviato nel gruppo WhatsApp del {corso_label} da {mittente_label} per la lezione {lezione_label}.
Messaggio: "{log_entry.testo_originale}"

Devi interpretare l'intenzione di presenza/assenza e restituire SOLO UNA di queste 5 stringhe esatte, senza spiegazioni, punteggiatura o spazi aggiuntivi:
- PRESENTE_SINGOLO (se ha confermato la sua presenza da solo/a)
- ASSENTE_SINGOLO (se ha comunicato che non ci sarà, solo per sé)
- PRESENTE_COPPIA (se ha parlato al plurale, es. "ci siamo", "veniamo", confermando per sé e per il partner)
- ASSENTE_COPPIA (se ha parlato al plurale, es. "non ci siamo", "saltiamo", confermando l'assenza per entrambi)
- IGNOTA (se non è un messaggio di conferma presenza/assenza o è una domanda/saluto/battuta)'''
        log_entry.chiamata_ai = prompt

    success, risposta_ai, model_used, attempts, err_summary = call_gemini_with_fallback(
        prompt=prompt,
        api_key=api_key,
        max_attempts=3,
        backoff_seconds=2.0
    )

    allievo = log_entry.allievo
    corso = log_entry.corso
    lezione = log_entry.lezione
    mittente_label = log_entry.mittente

    esito, azione_presenze, partner_coinvolto = parse_and_apply_presenze(
        allievo=allievo,
        prossima_lezione=lezione,
        risposta_ai=risposta_ai,
        mittente_label=mittente_label,
        corso=corso
    )

    log_entry.risposta_ai = f"{risposta_ai} (motore: {model_used}, tentativo: {attempts})" if success else risposta_ai
    log_entry.esito_interpretato = esito
    log_entry.azione_presenze = azione_presenze
    log_entry.partner_coinvolto = partner_coinvolto
    log_entry.save()

    with open('webhook_debug.log', 'a', encoding='utf-8') as f:
        f.write(f"[{timezone.now()}] Retry GeminiLog completato: ID={log_entry.id}, esito={esito}, model={model_used}, azione={azione_presenze}\n")

    return True, log_entry


def start_background_retry(log_id, delay_seconds=120, max_attempts=3):
    """
    Avvia un thread in background che attende delay_seconds (default 2 minuti)
    e tenta fino a max_attempts volte di ripetere la chiamata Gemini se il primo round è fallito con 503/transient.
    """
    def _worker():
        for i in range(1, max_attempts + 1):
            time.sleep(delay_seconds)
            try:
                log_entry = GeminiLog.objects.filter(id=log_id).first()
                if not log_entry:
                    break
                # Se nel frattempo è già stato risolto con successo, fermati
                if log_entry.esito_interpretato not in ('ERRORE', 'IN_ATTESA_RETRY'):
                    break

                success, result = retry_gemini_log(log_id)
                if success and result.esito_interpretato != 'ERRORE':
                    break
            except Exception as e:
                logger.error("Errore nel background retry per GeminiLog %s (ciclo %d): %s", log_id, i, e)

    t = threading.Thread(target=_worker, daemon=True)
    t.start()

