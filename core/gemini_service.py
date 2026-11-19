import time
import requests
import logging
import threading
import json
import io
import re
import base64
import datetime
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


def call_gemini_with_fallback(prompt, api_key, max_attempts=3, backoff_seconds=2.0, parts=None):
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
    if parts:
        payload = {
            "contents": [{"parts": parts}]
        }
    else:
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


def build_gemini_presence_prompt(corso_label, mittente_label, lezione_label, text):
    """
    Costruisce un prompt ottimizzato con regole esplicite ed esempi per la classificazione presenze con Gemini.
    """
    return f'''Analizza il seguente messaggio inviato nel gruppo WhatsApp della scuola di tango per il {corso_label} da {mittente_label} in merito alla lezione {lezione_label}.
Messaggio: "{text}"

Devi interpretare l'intenzione di presenza/assenza e restituire SOLO UNA di queste 5 stringhe esatte, senza spiegazioni, punteggiatura o parole aggiuntive:
- PRESENTE_SINGOLO
- ASSENTE_SINGOLO
- PRESENTE_COPPIA
- ASSENTE_COPPIA
- IGNOTA

Regole di classificazione ed esempi:
1. PRESENTE_COPPIA:
   - Se il mittente parla al plurale o conferma la presenza per la coppia / partner.
   - Esempi: "Presenti", "presenti!", "Ci siamo", "Noi ci siamo", "Veniamo", "Arriviamo", "Presenti entrambi", "Ci siamo entrambi", "Presenti tutti e due", "🙋‍♀️🙋‍♂️", "🙋🏼‍♀️🙋🏻‍♂️", "👫", "🧑‍🤝‍🧑".
   - ATTENZIONE CRITICA: La parola "Presenti" (al plurale) indica SEMPRE PRESENTE_COPPIA. Solo "Presente" (al singolare) indica PRESENTE_SINGOLO.
   - ATTENZIONE CRITICA EMOJI: Se compaiono due o più emoji di persone che alzano la mano (es. "🙋‍♀️🙋‍♂️", "🙋🏼‍♀️🙋🏻‍♂️") o emoji di coppia ("👫", "🧑‍🤝‍🧑"), indica SEMPRE PRESENTE_COPPIA.

2. PRESENTE_SINGOLO:
   - Se il mittente conferma la propria presenza da solo/a, anche con risposte brevi, informali, in inglese, con emoji o con ringraziamenti/saluti.
   - Esempi: "Presente", "Ci sono", "Vengo", "Arrivo", "Io ci sono", "Presente 💃", "Sì", "Si", "Yes", "Yess", "Yess!", "Yes, Grazie!", "Presente grazie!", "Ok grazie", "Ok ci sono", "Confermo", "Presente io", "🙋‍♀️", "🙋‍♂️", "🙋", "✋", "👍", "👌", "💃".
   - ATTENZIONE CRITICA: Messaggi affermativi come "Yes", "Yess", "Yes grazie", "Sì grazie", "Ok ci sono" scritti nell'appello presenze indicano SEMPRE conferma di presenza (PRESENTE_SINGOLO) e NON devono essere etichettati come IGNOTA.
   - ATTENZIONE CRITICA EMOJI: L'uso di una singola emoji di presenza, mano alzata o approvazione (es. "🙋‍♀️", "🙋‍♂️", "🙋", "✋", "👍", "👌"), anche DA SOLA E SENZA ALCUN TESTO AGGIUNTIVO, indica SEMPRE conferma di presenza (PRESENTE_SINGOLO) e NON deve MAI essere etichettata come IGNOTA.

3. ASSENTE_COPPIA:
   - Se comunica l'assenza al plurale o per entrambi i membri della coppia.
   - Esempi: "Non ci siamo", "Assenti", "Saltiamo stasera", "Stasera non riusciamo", "Non possiamo venire".

4. ASSENTE_SINGOLO:
   - Se comunica la propria assenza da solo/a.
   - Esempi: "Non ci sono", "Assente", "Non riesco a venire", "Stasera salto", "Oggi non posso", "👎".

5. IGNOTA:
   - SOLO se il messaggio non esprime alcuna intenzione di presenza o assenza (es. "A che ora inizia?", "Qualcuno ha visto le mie scarpe?", "Auguri!", "Ci vediamo sabato alla milonga").'''


def parse_and_apply_presenze(allievo, prossima_lezione, risposta_ai, mittente_label, corso, original_text=None):
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

    # Regole euristiche di sicurezza sul testo originale del messaggio
    if original_text:
        import re
        txt_clean = re.sub(r'[^\w\s]', ' ', original_text.lower()).strip()
        words = [w for w in txt_clean.split() if w]
        # 1. Se contiene "presenti" al plurale (senza negazioni), è SEMPRE PRESENTE_COPPIA
        if 'presenti' in words and not any(neg in words for neg in ('non', 'assenti', 'salto', 'saltiamo')):
            if esito in ('PRESENTE_SINGOLO', 'IGNOTA'):
                esito = 'PRESENTE_COPPIA'
        # 2. Conferme affermative singolari (es. "yes", "yess", "si", "presente")
        affirmative_tokens = {'yes', 'yess', 'yep', 'yeah', 'si', 'sì', 'presente', 'ci sono', 'confermo'}
        if any(w in affirmative_tokens for w in words) and not any(neg in words for neg in ('non', 'mai', 'assente', 'salto')):
            if esito == 'IGNOTA':
                esito = 'PRESENTE_SINGOLO'

        # 3. Riconoscimento euristico emoji di presenza (es. 🙋, 🙋‍♀️, 🙋‍♂️, ✋, 👍, 👫)
        has_negative = any(neg in words for neg in ('non', 'mai', 'assente', 'assenti', 'salto', 'saltiamo', 'no'))
        if not has_negative:
            # Conta le emoji di persone con mano alzata (🙋, \U0001F64B)
            person_raising_hand = len(re.findall(r'🙋|[\U0001F64B]', original_text))
            has_couple_emoji = any(c in original_text for c in ['👫', '👬', '👭', '🧑‍🤝‍🧑'])
            if person_raising_hand >= 2 or has_couple_emoji:
                if esito in ('PRESENTE_SINGOLO', 'IGNOTA'):
                    esito = 'PRESENTE_COPPIA'
            elif person_raising_hand == 1 or any(e in original_text for e in ['👍', '✋', '👌']):
                if esito == 'IGNOTA':
                    esito = 'PRESENTE_SINGOLO' 

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
        prompt = build_gemini_presence_prompt(corso_label, mittente_label, lezione_label, log_entry.testo_originale)
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
        corso=corso,
        original_text=log_entry.testo_originale
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


def _extract_dates_from_text(text):
    """
    Estrae date in formato italiano o testuale (es. 15/10/2026, 15 ottobre 2026, 15 / 10 / 2026).
    Restituisce una lista ordinata di tuple: (indice_inizio, datetime.date, stringa_originale).
    """
    if not text:
        return []

    mesi = {
        'gennaio': 1, 'febbraio': 2, 'marzo': 3, 'aprile': 4, 'maggio': 5, 'giugno': 6,
        'luglio': 7, 'agosto': 8, 'settembre': 9, 'ottobre': 10, 'novembre': 11, 'dicembre': 12
    }
    dates = []
    # 1. DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY anche con spazi OCR (es. 12 / 10 / 2026 o 12/10/26)
    for m in re.finditer(r'\b(\d{1,2})\s*[\/\-\.]\s*(\d{1,2})\s*[\/\-\.]\s*(\d{2,4})\b', text):
        try:
            d, mth, y_raw = int(m.group(1)), int(m.group(2)), int(m.group(3))
            y = y_raw + 2000 if y_raw < 100 else y_raw
            if 1 <= mth <= 12 and 1 <= d <= 31 and 2000 <= y <= 2040:
                dt = datetime.date(y, mth, d)
                dates.append((m.start(), dt, m.group(0)))
        except ValueError:
            pass

    # 2. DD Mese YYYY
    pattern_month = r'\b(\d{1,2})\s+([a-zA-Z]+)\s+(\d{4})\b'
    for m in re.finditer(pattern_month, text, re.IGNORECASE):
        d_str, mon_str, y_str = m.group(1), m.group(2).lower(), m.group(3)
        if mon_str in mesi:
            try:
                dt = datetime.date(int(y_str), mesi[mon_str], int(d_str))
                dates.append((m.start(), dt, m.group(0)))
            except ValueError:
                pass

    return sorted(dates, key=lambda x: x[0])


def _heuristic_analyze_certificate_text(text):
    """
    Analisi euristica basata su espressioni regolari per certificati medici italiani.
    Riconosce la data di scadenza esplicita o calcola la scadenza annuale (+1 anno) dalla data di rilascio.
    """
    if not text:
        return None

    dates = _extract_dates_from_text(text)
    if not dates:
        return None

    # Filtra la data del DM (24/04/2013 o 08/08/2014) se presente come citazione normativa
    filtered_dates = []
    for pos, dt, raw in dates:
        surrounding = text[max(0, pos - 45):min(len(text), pos + 45)].lower()
        if dt.year in (2013, 2014) and any(w in surrounding for w in ('d.m', 'decreto', 'minister', 'gazzetta')):
            continue
        filtered_dates.append((pos, dt, raw, surrounding))

    if not filtered_dates:
        return None

    scadenza_date = None
    rilascio_date = None

    scadenza_keywords = ['scadenza', 'scade', 'valido fino', 'validita fino', 'validità fino', 'termine', 'scadrà', 'scadra', 'validita:']
    rilascio_keywords = ['rilasciato', 'rilascio', 'visita', 'data:', 'in data', 'emissione', 'firmato', 'effettuata', 'certifica', 'del']

    for pos, dt, raw, surrounding in filtered_dates:
        before = text[max(0, pos - 45):pos + len(raw)].lower()
        if any(kw in before for kw in scadenza_keywords):
            scadenza_date = dt
            break

    for pos, dt, raw, surrounding in filtered_dates:
        before = text[max(0, pos - 45):pos + len(raw)].lower()
        if dt != scadenza_date and any(kw in before for kw in rilascio_keywords):
            rilascio_date = dt
            break

    if scadenza_date:
        return {
            'data_scadenza': scadenza_date.strftime('%Y-%m-%d'),
            'data_scadenza_italiana': scadenza_date.strftime('%d/%m/%Y'),
            'data_rilascio': rilascio_date.strftime('%Y-%m-%d') if rilascio_date else None,
            'source': 'ocr_locale',
            'confidence': 'alta',
            'note': f"Data di scadenza ({scadenza_date.strftime('%d/%m/%Y')}) identificata nel testo."
        }

    # Se non c'è una data di scadenza esplicita, usiamo la data di rilascio (+1 anno per legge D.M. 24/04/2013)
    target_rel = rilascio_date or filtered_dates[-1][1]
    try:
        calculated_scadenza = target_rel.replace(year=target_rel.year + 1)
    except ValueError:
        calculated_scadenza = target_rel + datetime.timedelta(days=365)

    return {
        'data_scadenza': calculated_scadenza.strftime('%Y-%m-%d'),
        'data_scadenza_italiana': calculated_scadenza.strftime('%d/%m/%Y'),
        'data_rilascio': target_rel.strftime('%Y-%m-%d'),
        'source': 'ocr_locale',
        'confidence': 'media',
        'note': f"Calcolata scadenza annuale (+1 anno) dalla data di rilascio/visita {target_rel.strftime('%d/%m/%Y')} (D.M. 24/04/2013)."
    }


def _run_local_ocr_on_image_bytes(image_bytes):
    """Esegue OCR locale su un'immagine tramite pytesseract se installato."""
    try:
        import pytesseract
        from PIL import Image
        img = Image.open(io.BytesIO(image_bytes))
        try:
            return pytesseract.image_to_string(img, lang='ita+eng')
        except Exception:
            return pytesseract.image_to_string(img)
    except Exception as e:
        logger.debug(f"Pytesseract non disponibile o errore: {e}")
        return ""


def _run_local_ocr_on_pdf_pages(doc, max_pages=2):
    """Esegue OCR locale sulle prime pagine di un documento PDF scansionato."""
    full_ocr = ""
    for i in range(min(len(doc), max_pages)):
        page = doc[i]
        try:
            import pytesseract
            from PIL import Image
            pix = page.get_pixmap(dpi=200)
            img = Image.open(io.BytesIO(pix.tobytes("png")))
            try:
                txt = pytesseract.image_to_string(img, lang='ita+eng')
            except Exception:
                txt = pytesseract.image_to_string(img)
            if txt:
                full_ocr += txt + "\n"
        except Exception:
            try:
                tp = page.get_textpage_ocr(dpi=200, language='ita')
                txt = tp.extractText()
                if txt:
                    full_ocr += txt + "\n"
            except Exception:
                pass
    return full_ocr


def analizza_certificato_medico_locale(file_bytes, mime_type='application/pdf', filename=None, allievo_nome=None):
    """
    Analizza un certificato medico (PDF o immagine) per estrarre la data di scadenza.
    Esecuzione 100% LOCALE (On-Premise) tramite OCR e Regex.
    Nessun dato o immagine esce dal perimetro aziendale verso API esterne (Privacy Totale).
    """
    if not file_bytes:
        return {
            'success': False,
            'found': False,
            'data_scadenza': None,
            'data_scadenza_italiana': None,
            'error': 'Nessun file fornito per l\'analisi.'
        }

    extracted_text = ""
    fn_lower = (filename or '').lower()
    is_pdf = (mime_type == 'application/pdf') or fn_lower.endswith('.pdf') or file_bytes.startswith(b'%PDF')

    # 1. Estrazione testo nativo da PDF
    if is_pdf:
        try:
            import pymupdf
            doc = pymupdf.open(stream=file_bytes, filetype="pdf")
            for page in doc:
                extracted_text += page.get_text() + "\n"

            # Se il PDF ha poco o nessun testo nativo (scansione), esegui OCR locale
            if len(extracted_text.strip()) < 30 and len(doc) > 0:
                ocr_res = _run_local_ocr_on_pdf_pages(doc)
                if ocr_res:
                    extracted_text += "\n" + ocr_res
        except Exception as e:
            logger.warning(f"pymupdf non disponibile o errore: {e}")
            try:
                import pypdf
                reader = pypdf.PdfReader(io.BytesIO(file_bytes))
                for page in reader.pages:
                    t = page.extract_text()
                    if t:
                        extracted_text += t + "\n"
            except Exception as pe:
                logger.warning(f"pypdf errore: {pe}")
    elif mime_type.startswith('image/') or any(fn_lower.endswith(ext) for ext in ('.jpg', '.jpeg', '.png', '.webp', '.bmp')):
        extracted_text = _run_local_ocr_on_image_bytes(file_bytes)
    else:
        try:
            extracted_text = file_bytes.decode('utf-8')
        except Exception:
            pass

    # 2. Analisi euristica su testo estratto (Regole euristiche e normative D.M. 24/04/2013)
    heuristic_res = _heuristic_analyze_certificate_text(extracted_text)

    if heuristic_res and heuristic_res.get('data_scadenza'):
        scad_iso = heuristic_res['data_scadenza']
        scad_it = heuristic_res.get('data_scadenza_italiana')
        if not scad_it:
            try:
                p_date = datetime.datetime.strptime(scad_iso, '%Y-%m-%d').date()
                scad_it = p_date.strftime('%d/%m/%Y')
            except Exception:
                scad_it = scad_iso

        return {
            'success': True,
            'found': True,
            'data_scadenza': scad_iso,
            'data_scadenza_italiana': scad_it,
            'data_rilascio': heuristic_res.get('data_rilascio'),
            'confidence': heuristic_res.get('confidence', 'alta'),
            'note': heuristic_res.get('note', ''),
            'source': 'ocr_locale'
        }

    return {
        'success': True,
        'found': False,
        'data_scadenza': None,
        'data_scadenza_italiana': None,
        'source': 'ocr_locale',
        'message': 'Nessuna data di scadenza o rilascio identificata tramite OCR locale.'
    }


# Alias retrocompatibile
analizza_certificato_medico_ai = analizza_certificato_medico_locale

