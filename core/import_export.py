import csv
import io
import datetime
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.authtoken.models import Token
import openpyxl

from .models import (
    Allievo, Corso, Lezione, Presenza, Pagamento
)


# ─── Autenticazione (Token o Sessione) ───────────────────────────

def _authenticate_request(request):
    """Verifica autenticazione tramite Sessione, Token Header o query param ?token=..."""
    if request.user and request.user.is_authenticated:
        return True, request.user

    auth_header = request.headers.get('Authorization', '')
    token_key = None
    if auth_header.startswith('Token '):
        token_key = auth_header.split(' ')[1]
    elif request.GET.get('token'):
        token_key = request.GET.get('token')

    if token_key:
        try:
            token = Token.objects.select_related('user').get(key=token_key)
            return True, token.user
        except Token.DoesNotExist:
            pass

    return False, None


def auth_required(view_func):
    """Decorator per proteggere le viste di import/export."""
    def _wrapped_view(request, *args, **kwargs):
        is_auth, user = _authenticate_request(request)
        if not is_auth:
            return JsonResponse({'detail': 'Autenticazione richiesta.'}, status=401)
        request.user = user
        return view_func(request, *args, **kwargs)
    return _wrapped_view


# ─── Utility Generazione File Tabellari ──────────────────────────

def _build_tabular_response(headers, rows, filename_base, fmt='csv'):
    """Genera una risposta HTTP per il download in formato CSV o Excel."""
    fmt = (fmt or 'csv').lower()

    if fmt == 'xlsx':
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "Dati"
        ws.append(headers)
        for r in rows:
            ws.append([str(x) if x is not None else '' for x in r])

        output = io.BytesIO()
        wb.save(output)
        output.seek(0)

        response = HttpResponse(
            output.getvalue(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
        response['Content-Disposition'] = f'attachment; filename="{filename_base}.xlsx"'
        return response

    # Default CSV
    output = io.StringIO()
    writer = csv.writer(output, delimiter=';')
    writer.writerow(headers)
    for r in rows:
        writer.writerow([str(x) if x is not None else '' for x in r])

    response = HttpResponse(output.getvalue().encode('utf-8-sig'), content_type='text/csv; charset=utf-8')
    response['Content-Disposition'] = f'attachment; filename="{filename_base}.csv"'
    return response


# ─── 5.1 Endpoint Export ────────────────────────────────────────

@csrf_exempt
@auth_required
def export_allievi(request):
    """Esporta gli allievi in CSV o Excel (parametro ?format=xlsx)."""
    fmt = request.GET.get('format', 'csv')
    scuola_id = request.GET.get('scuola')
    corso_id = request.GET.get('corso')
    is_prospect = request.GET.get('is_prospect')

    qs = Allievo.objects.select_related('corso', 'corso__scuola').all()
    if scuola_id:
        qs = qs.filter(corso__scuola_id=scuola_id)
    if corso_id:
        qs = qs.filter(corso_id=corso_id)
    if is_prospect is not None:
        qs = qs.filter(is_prospect=(is_prospect.lower() in ['true', '1']))

    headers = [
        'ID', 'Cognome', 'Nome', 'Ruolo', 'Telefono', 'Livello',
        'Scuola', 'Corso', 'Anno Accademico', 'Recensione', 'Prospect', 'Attivo', 'Note'
    ]
    rows = []
    for a in qs:
        rows.append([
            str(a.id),
            a.cognome,
            a.nome,
            a.get_ruolo_display(),
            a.telefono,
            a.get_livello_display(),
            a.corso.scuola.nome if a.corso else '',
            f"{a.corso.get_livello_display()} ({a.corso.orario.strftime('%H:%M')})" if a.corso else '',
            a.corso.anno_accademico if a.corso else '',
            a.get_recensione_display(),
            'Sì' if a.is_prospect else 'No',
            'Sì' if a.is_active else 'No',
            a.note
        ])

    return _build_tabular_response(headers, rows, f'allievi_{datetime.date.today()}', fmt)


@csrf_exempt
@auth_required
def export_presenze(request):
    """Esporta le presenze in CSV o Excel."""
    fmt = request.GET.get('format', 'csv')
    lezione_id = request.GET.get('lezione')
    corso_id = request.GET.get('corso')

    qs = Presenza.objects.select_related('lezione', 'lezione__corso', 'lezione__corso__scuola', 'allievo').all()
    if lezione_id:
        qs = qs.filter(lezione_id=lezione_id)
    if corso_id:
        qs = qs.filter(lezione__corso_id=corso_id)

    headers = [
        'ID Presenza', 'Data Lezione', 'Scuola', 'Corso', 'Allievo',
        'Ruolo', 'Telefono', 'Presente', 'Orario Registrazione'
    ]
    rows = []
    for p in qs:
        rows.append([
            str(p.id),
            p.lezione.data.strftime('%d/%m/%Y'),
            p.lezione.corso.scuola.nome,
            f"{p.lezione.corso.get_livello_display()} ({p.lezione.corso.orario.strftime('%H:%M')})",
            f"{p.allievo.cognome} {p.allievo.nome}",
            p.allievo.get_ruolo_display(),
            p.allievo.telefono,
            'Presente' if p.presente else 'Assente',
            p.timestamp.strftime('%d/%m/%Y %H:%M')
        ])

    return _build_tabular_response(headers, rows, f'presenze_{datetime.date.today()}', fmt)


@csrf_exempt
@auth_required
def export_pagamenti(request):
    """Esporta i pagamenti in CSV o Excel con totali e dettagli."""
    fmt = request.GET.get('format', 'csv')
    corso_id = request.GET.get('corso')
    scuola_id = request.GET.get('scuola')
    trimestre = request.GET.get('trimestre')

    qs = Pagamento.objects.select_related('allievo', 'corso', 'corso__scuola').all()
    if corso_id:
        qs = qs.filter(corso_id=corso_id)
    if scuola_id:
        qs = qs.filter(corso__scuola_id=scuola_id)
    if trimestre:
        qs = qs.filter(trimestre=trimestre)

    headers = [
        'ID Pagamento', 'Allievo', 'Telefono', 'Scuola', 'Corso',
        'Trimestre', 'Importo (€)', 'Data Pagamento', 'Note'
    ]
    rows = []
    for p in qs:
        rows.append([
            str(p.id),
            f"{p.allievo.cognome} {p.allievo.nome}",
            p.allievo.telefono,
            p.corso.scuola.nome,
            f"{p.corso.get_livello_display()} ({p.corso.orario.strftime('%H:%M')})",
            p.get_trimestre_display(),
            str(p.importo),
            p.data_pagamento.strftime('%d/%m/%Y'),
            p.note
        ])

    return _build_tabular_response(headers, rows, f'pagamenti_{datetime.date.today()}', fmt)


@csrf_exempt
@auth_required
def export_lezioni(request):
    """Esporta le lezioni in CSV o Excel."""
    fmt = request.GET.get('format', 'csv')
    corso_id = request.GET.get('corso')

    qs = Lezione.objects.select_related('corso', 'corso__scuola', 'argomento').all()
    if corso_id:
        qs = qs.filter(corso_id=corso_id)

    headers = ['ID Lezione', 'Data', 'Scuola', 'Corso', 'Orario', 'Argomento', 'Totale Iscritti', 'Presenti']
    rows = []
    for lez in qs:
        rows.append([
            str(lez.id),
            lez.data.strftime('%d/%m/%Y'),
            lez.corso.scuola.nome,
            lez.corso.get_livello_display(),
            lez.corso.orario.strftime('%H:%M'),
            lez.argomento.titolo if lez.argomento else 'Da definire',
            lez.presenze.count(),
            lez.presenze.filter(presente=True).count()
        ])

    return _build_tabular_response(headers, rows, f'lezioni_{datetime.date.today()}', fmt)


# ─── 5.2 Template Esempio per Import ────────────────────────────

@csrf_exempt
@auth_required
def get_import_template(request, model_name):
    """
    Restituisce un file CSV o Excel vuoto con intestazioni e righe di esempio.
    Supporta: 'allievi', 'presenze', 'pagamenti'
    """
    fmt = request.GET.get('format', 'csv')
    model_name = model_name.lower()

    if model_name == 'allievi':
        headers = ['nome', 'cognome', 'ruolo', 'telefono', 'livello', 'recensione', 'nome_scuola', 'livello_corso', 'is_prospect', 'note']
        rows = [
            ['Mario', 'Rossi', 'leader', '+393331112233', 'principiante', 'si', 'Tango Milano', 'principiante', 'no', 'Iscritto da settembre'],
            ['Laura', 'Bianchi', 'follower', '+393334445566', 'intermedio', 'no', '', '', 'si', 'Interessata a prova gratuita']
        ]
        return _build_tabular_response(headers, rows, 'template_import_allievi', fmt)

    elif model_name == 'presenze':
        headers = ['data_lezione', 'telefono_allievo', 'presente']
        rows = [
            [datetime.date.today().strftime('%Y-%m-%d'), '+393331112233', 'si'],
            [datetime.date.today().strftime('%Y-%m-%d'), '+393334445566', 'no']
        ]
        return _build_tabular_response(headers, rows, 'template_import_presenze', fmt)

    elif model_name == 'pagamenti':
        headers = ['telefono_allievo', 'trimestre', 'importo', 'data_pagamento', 'note']
        rows = [
            ['+393331112233', 'T1', '150.00', datetime.date.today().strftime('%Y-%m-%d'), 'Bonifico bancario'],
            ['+393334445566', 'T1', '150.00', datetime.date.today().strftime('%Y-%m-%d'), 'Contanti']
        ]
        return _build_tabular_response(headers, rows, 'template_import_pagamenti', fmt)

    return JsonResponse({'error': f'Modello {model_name} non supportato.'}, status=400)


# ─── Helper Lettura File Caricato ───────────────────────────────

def _extract_rows_from_file(uploaded_file):
    """Estrae le righe come lista di dizionari da un file CSV o XLSX."""
    filename = uploaded_file.name.lower()

    if filename.endswith('.xlsx') or filename.endswith('.xls'):
        wb = openpyxl.load_workbook(uploaded_file, data_only=True)
        ws = wb.active
        raw_rows = list(ws.iter_rows(values_only=True))
        if not raw_rows:
            return []
        headers = [str(h).strip().lower() if h is not None else '' for h in raw_rows[0]]
        records = []
        for r in raw_rows[1:]:
            if not any(r):
                continue
            item = {}
            for idx, val in enumerate(r):
                if idx < len(headers):
                    item[headers[idx]] = str(val).strip() if val is not None else ''
            records.append(item)
        return records

    content = uploaded_file.read()
    try:
        text = content.decode('utf-8-sig')
    except UnicodeDecodeError:
        text = content.decode('latin-1')

    delimiter = ';' if ';' in text.splitlines()[0] else ','
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    records = []
    for r in reader:
        records.append({k.strip().lower(): (v.strip() if v else '') for k, v in r.items() if k})
    return records


# ─── 5.1 Endpoint Import ────────────────────────────────────────

@csrf_exempt
@auth_required
def import_allievi(request):
    """Importa allievi da file CSV o Excel."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST richiesto.'}, status=405)

    uploaded_file = request.FILES.get('file')
    if not uploaded_file:
        return JsonResponse({'error': 'Nessun file fornito. Usa la chiave multipart "file".'}, status=400)

    try:
        records = _extract_rows_from_file(uploaded_file)
    except Exception as e:
        return JsonResponse({'error': f'Impossibile leggere il file: {e}'}, status=400)

    created_count = 0
    updated_count = 0
    errors = []

    for idx, row in enumerate(records, start=2):
        nome = row.get('nome', '')
        cognome = row.get('cognome', '')
        telefono = row.get('telefono', '')

        if not nome or not cognome or not telefono:
            errors.append(f'Riga {idx}: Nome, Cognome e Telefono sono obbligatori.')
            continue

        ruolo = row.get('ruolo', 'leader').lower()
        if ruolo not in ['leader', 'follower', 'both']:
            ruolo = 'leader'

        livello = row.get('livello', 'principiante').lower()
        if livello not in ['principiante', 'intermedio', 'avanzato']:
            livello = 'principiante'

        recensione = 'si' if row.get('recensione', '').lower() in ['si', 'sì', 'true', '1'] else 'no'
        is_prospect = row.get('is_prospect', '').lower() in ['si', 'sì', 'true', '1']
        note = row.get('note', '')

        corso_obj = None
        nome_scuola = row.get('nome_scuola', '')
        livello_corso = row.get('livello_corso', '')
        if nome_scuola:
            corso_query = Corso.objects.filter(scuola__nome__icontains=nome_scuola)
            if livello_corso:
                corso_query = corso_query.filter(livello__icontains=livello_corso)
            corso_obj = corso_query.first()

        _, created = Allievo.objects.update_or_create(
            telefono=telefono,
            defaults={
                'nome': nome,
                'cognome': cognome,
                'ruolo': ruolo,
                'livello': livello,
                'recensione': recensione,
                'is_prospect': is_prospect,
                'corso': corso_obj,
                'note': note
            }
        )
        if created:
            created_count += 1
        else:
            updated_count += 1

    return JsonResponse({
        'success': True,
        'creati': created_count,
        'aggiornati': updated_count,
        'totale_processati': len(records),
        'errori': errors
    })


@csrf_exempt
@auth_required
def import_presenze(request):
    """Importa presenze da file CSV o Excel."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST richiesto.'}, status=405)

    uploaded_file = request.FILES.get('file')
    if not uploaded_file:
        return JsonResponse({'error': 'Nessun file fornito.'}, status=400)

    try:
        records = _extract_rows_from_file(uploaded_file)
    except Exception as e:
        return JsonResponse({'error': f'Impossibile leggere il file: {e}'}, status=400)

    saved_count = 0
    errors = []

    for idx, row in enumerate(records, start=2):
        data_lezione_str = row.get('data_lezione', '')
        tel_allievo = row.get('telefono_allievo', '')
        presente_val = row.get('presente', '').lower() in ['si', 'sì', 'true', '1', 'presente']

        if not data_lezione_str or not tel_allievo:
            errors.append(f'Riga {idx}: data_lezione e telefono_allievo sono obbligatori.')
            continue

        clean_tel = ''.join(filter(str.isdigit, tel_allievo))
        last_10 = clean_tel[-10:] if len(clean_tel) >= 10 else clean_tel

        allievo = None
        for a in Allievo.objects.all():
            if ''.join(filter(str.isdigit, a.telefono)).endswith(last_10):
                allievo = a
                break

        if not allievo:
            errors.append(f'Riga {idx}: Allievo con telefono {tel_allievo} non trovato.')
            continue

        try:
            data_obj = datetime.datetime.strptime(data_lezione_str, '%Y-%m-%d').date()
        except ValueError:
            try:
                data_obj = datetime.datetime.strptime(data_lezione_str, '%d/%m/%Y').date()
            except ValueError:
                errors.append(f'Riga {idx}: Formato data non valido ({data_lezione_str}).')
                continue

        lezione_query = Lezione.objects.filter(data=data_obj)
        if allievo.corso:
            lezione_query = lezione_query.filter(corso=allievo.corso)
        lezione = lezione_query.first()

        if not lezione:
            errors.append(f'Riga {idx}: Nessuna lezione trovata in data {data_obj} per il corso dell\'allievo.')
            continue

        Presenza.objects.update_or_create(
            lezione=lezione,
            allievo=allievo,
            defaults={'presente': presente_val}
        )
        saved_count += 1

    return JsonResponse({
        'success': True,
        'presenze_salvate': saved_count,
        'totale_processati': len(records),
        'errori': errors
    })


@csrf_exempt
@auth_required
def import_pagamenti(request):
    """Importa pagamenti da file CSV o Excel."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST richiesto.'}, status=405)

    uploaded_file = request.FILES.get('file')
    if not uploaded_file:
        return JsonResponse({'error': 'Nessun file fornito.'}, status=400)

    try:
        records = _extract_rows_from_file(uploaded_file)
    except Exception as e:
        return JsonResponse({'error': f'Impossibile leggere il file: {e}'}, status=400)

    saved_count = 0
    errors = []

    for idx, row in enumerate(records, start=2):
        tel_allievo = row.get('telefono_allievo', '')
        trimestre = row.get('trimestre', 'T1').upper()
        importo_str = row.get('importo', '150.00').replace(',', '.')
        data_str = row.get('data_pagamento', '')
        note = row.get('note', '')

        if not tel_allievo:
            errors.append(f'Riga {idx}: telefono_allievo obbligatorio.')
            continue

        clean_tel = ''.join(filter(str.isdigit, tel_allievo))
        last_10 = clean_tel[-10:] if len(clean_tel) >= 10 else clean_tel

        allievo = None
        for a in Allievo.objects.select_related('corso').all():
            if ''.join(filter(str.isdigit, a.telefono)).endswith(last_10):
                allievo = a
                break

        if not allievo:
            errors.append(f'Riga {idx}: Allievo con telefono {tel_allievo} non trovato.')
            continue

        if not allievo.corso:
            errors.append(f'Riga {idx}: L\'allievo {allievo} non è iscritto ad alcun corso.')
            continue

        try:
            importo = float(importo_str)
        except ValueError:
            importo = 150.00

        try:
            data_obj = datetime.datetime.strptime(data_str, '%Y-%m-%d').date() if data_str else datetime.date.today()
        except ValueError:
            try:
                data_obj = datetime.datetime.strptime(data_str, '%d/%m/%Y').date()
            except ValueError:
                data_obj = datetime.date.today()

        Pagamento.objects.create(
            allievo=allievo,
            corso=allievo.corso,
            importo=importo,
            trimestre=trimestre if trimestre in ['T1', 'T2', 'T3'] else 'T1',
            data_pagamento=data_obj,
            note=note
        )
        saved_count += 1

    return JsonResponse({
        'success': True,
        'pagamenti_salvati': saved_count,
        'totale_processati': len(records),
        'errori': errors
    })


# ─── 5.3 Endpoint Globali (Multi-sheet) ───────────────────────────────────

from .models import (
    Scuola, Corso, Argomento, Allievo, Jolly, Lezione, Presenza, Pagamento,
    SondaggioMattutinoConfig, Role, Level, Recensione, Trimestre
)

@csrf_exempt
@auth_required
def export_global(request):
    """Esporta tutto il database in un singolo file Excel multi-foglio."""
    wb = openpyxl.Workbook()
    
    # Rimuovi il foglio di default
    default_sheet = wb.active
    wb.remove(default_sheet)

    # 1. Scuole
    ws = wb.create_sheet("Scuole")
    ws.append(["ID", "Nome", "Sede", "Gruppo WhatsApp"])
    for s in Scuola.objects.all():
        ws.append([str(s.id), s.nome, s.sede, s.gruppo_whatsapp])

    # 2. Corsi
    ws = wb.create_sheet("Corsi")
    ws.append(["ID", "Scuola ID", "Scuola Nome", "Livello", "Giorno", "Orario", "Anno Accademico", "Gruppo WhatsApp"])
    for c in Corso.objects.select_related('scuola').all():
        orario_str = c.orario.strftime('%H:%M') if c.orario else ''
        ws.append([
            str(c.id),
            str(c.scuola.id),
            c.scuola.nome,
            c.livello,
            c.giorno_settimana,
            orario_str,
            c.anno_accademico,
            c.gruppo_whatsapp
        ])

    # 3. Argomenti
    ws = wb.create_sheet("Argomenti")
    ws.append(["ID", "Livello", "Titolo", "Descrizione"])
    for a in Argomento.objects.all():
        ws.append([str(a.id), a.livello, a.titolo, a.descrizione])

    # 4. Allievi
    ws = wb.create_sheet("Allievi")
    ws.append(["ID", "Nome", "Cognome", "Telefono", "Ruolo", "Livello", "Corso ID", "Partner ID", "Prospect", "Recensione", "Attivo", "Note"])
    for a in Allievo.objects.select_related('corso', 'partner').all():
        ws.append([
            str(a.id),
            a.nome,
            a.cognome,
            a.telefono,
            a.ruolo,
            a.livello,
            str(a.corso.id) if a.corso else "",
            str(a.partner_id) if a.partner_id else "",
            "Sì" if a.is_prospect else "No",
            a.recensione,
            "Sì" if a.is_active else "No",
            a.note
        ])

    # 5. Jolly
    ws = wb.create_sheet("Jolly")
    ws.append(["ID", "Allievo ID", "Allievo Nome", "Priorità"])
    for j in Jolly.objects.select_related('allievo').all():
        ws.append([
            str(j.id),
            str(j.allievo.id),
            f"{j.allievo.nome} {j.allievo.cognome}",
            j.priorita
        ])

    # 6. Lezioni
    ws = wb.create_sheet("Lezioni")
    ws.append(["ID", "Corso ID", "Data", "Titolo", "Argomento ID"])
    for l in Lezione.objects.select_related('corso', 'argomento').all():
        ws.append([
            str(l.id),
            str(l.corso.id),
            l.data.strftime('%Y-%m-%d'),
            l.titolo,
            str(l.argomento.id) if l.argomento else ""
        ])

    # 7. Presenze
    ws = wb.create_sheet("Presenze")
    ws.append(["ID", "Allievo ID", "Lezione ID", "Presente", "Fonte", "Jolly", "Data Registrazione"])
    for p in Presenza.objects.all():
        ws.append([
            str(p.id),
            str(p.allievo_id),
            str(p.lezione_id),
            "Sì" if p.presente else "No",
            p.fonte,
            "Sì" if p.is_jolly else "No",
            p.timestamp.strftime('%Y-%m-%d %H:%M') if p.timestamp else ""
        ])

    # 8. Pagamenti
    ws = wb.create_sheet("Pagamenti")
    ws.append(["ID", "Allievo ID", "Corso ID", "Importo", "Trimestre", "Data Pagamento", "Note"])
    for p in Pagamento.objects.all():
        ws.append([
            str(p.id),
            str(p.allievo_id),
            str(p.corso_id) if p.corso_id else "",
            float(p.importo),
            p.trimestre,
            p.data_pagamento.strftime('%Y-%m-%d') if p.data_pagamento else "",
            p.note
        ])

    # 9. Sondaggi Mattutini
    ws = wb.create_sheet("SondaggiMattutini")
    ws.append(["ID", "Corso ID", "Testo", "Attivo"])
    for s in SondaggioMattutinoConfig.objects.select_related('corso').all():
        ws.append([
            str(s.id),
            str(s.corso.id),
            s.testo,
            "Sì" if s.is_active else "No"
        ])

    output = io.BytesIO()
    wb.save(output)
    output.seek(0)

    response = HttpResponse(
        output.getvalue(),
        content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
    response['Content-Disposition'] = f'attachment; filename="WAManager_Backup_{datetime.date.today()}.xlsx"'
    return response


@csrf_exempt
@auth_required
def import_global(request):
    """Importa tutto il database da un file Excel multi-foglio, in ordine logico."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Richiesto metodo POST'}, status=405)
    
    file_obj = request.FILES.get('file')
    if not file_obj:
        return JsonResponse({'error': 'Nessun file fornito'}, status=400)
    
    if not file_obj.name.endswith('.xlsx'):
        return JsonResponse({'error': 'Il file globale deve essere in formato .xlsx'}, status=400)

    try:
        wb = openpyxl.load_workbook(file_obj)
        sheets = wb.sheetnames
        stats = {}

        def get_rows(sheet_name):
            if sheet_name not in sheets:
                return []
            ws = wb[sheet_name]
            rows = list(ws.iter_rows(values_only=True))
            if not rows or len(rows) < 2:
                return []
            return rows[1:]  # Salta l'header

        def parse_date(val):
            if not val:
                return None
            if isinstance(val, (datetime.date, datetime.datetime)):
                return val.date() if isinstance(val, datetime.datetime) else val
            val_str = str(val).strip()
            for fmt in ('%Y-%m-%d', '%d/%m/%Y'):
                try:
                    return datetime.datetime.strptime(val_str, fmt).date()
                except ValueError:
                    pass
            return None

        def parse_time(val):
            if not val:
                return datetime.time(20, 0)
            if isinstance(val, datetime.time):
                return val
            if isinstance(val, datetime.datetime):
                return val.time()
            val_str = str(val).strip()
            for fmt in ('%H:%M:%S', '%H:%M'):
                try:
                    return datetime.datetime.strptime(val_str, fmt).time()
                except ValueError:
                    pass
            return datetime.time(20, 0)

        def normalize_level(val):
            val_str = str(val or '').strip().lower()
            if 'inter' in val_str:
                return 'intermedio'
            elif 'avanz' in val_str or 'adv' in val_str:
                return 'avanzato'
            return 'principiante'

        # 1. Scuole
        scuole_count = 0
        for r in get_rows("Scuole"):
            if not r or len(r) < 2 or not r[1]:
                continue
            scuola_defaults = {'nome': str(r[1]).strip()}
            if len(r) > 2 and r[2]:
                scuola_defaults['sede'] = str(r[2]).strip()
            if len(r) > 3 and r[3]:
                scuola_defaults['gruppo_whatsapp'] = str(r[3]).strip()
            Scuola.objects.update_or_create(id=r[0], defaults=scuola_defaults)
            scuole_count += 1
        stats['scuole'] = scuole_count

        # 2. Corsi
        corsi_count = 0
        for r in get_rows("Corsi"):
            if not r or len(r) < 2 or not r[1]:
                continue
            try:
                livello_val = normalize_level(r[3] if len(r) > 3 else None)
                giorno_val = str(r[4]).strip().upper() if len(r) > 4 and r[4] else 'LUNEDI'
                giorno_map = {
                    'LUNEDÌ': 'LUNEDI', 'LUNEDI': 'LUNEDI',
                    'MARTEDÌ': 'MARTEDI', 'MARTEDI': 'MARTEDI',
                    'MERCOLEDÌ': 'MERCOLEDI', 'MERCOLEDI': 'MERCOLEDI',
                    'GIOVEDÌ': 'GIOVEDI', 'GIOVEDI': 'GIOVEDI',
                    'VENERDÌ': 'VENERDI', 'VENERDI': 'VENERDI',
                    'SABATO': 'SABATO',
                    'DOMENICA': 'DOMENICA',
                }
                giorno_key = giorno_map.get(giorno_val, 'LUNEDI')
                orario_obj = parse_time(r[5]) if len(r) > 5 else datetime.time(20, 0)
                anno_acc = str(r[6]).strip() if len(r) > 6 and r[6] else '2025/2026'
                whatsapp = str(r[7]).strip() if len(r) > 7 and r[7] else ''

                Corso.objects.update_or_create(id=r[0], defaults={
                    'scuola_id': r[1],
                    'livello': livello_val,
                    'giorno_settimana': giorno_key,
                    'orario': orario_obj,
                    'anno_accademico': anno_acc,
                    'gruppo_whatsapp': whatsapp,
                })
                corsi_count += 1
            except Exception:
                pass
        stats['corsi'] = corsi_count

        # 3. Argomenti
        arg_count = 0
        for r in get_rows("Argomenti"):
            if not r or len(r) < 3 or not r[2]:
                continue
            livello_val = normalize_level(r[1] if len(r) > 1 else None)
            Argomento.objects.update_or_create(id=r[0], defaults={
                'livello': livello_val,
                'titolo': str(r[2]).strip(),
                'descrizione': str(r[3]).strip() if len(r) > 3 and r[3] else ""
            })
            arg_count += 1
        stats['argomenti'] = arg_count

        # 4. Allievi
        allievi_count = 0
        partner_pairs = []  # (allievo_id, partner_id)
        for r in get_rows("Allievi"):
            if not r or len(r) < 4 or not r[1]:
                continue
            try:
                # Colonne: [ID, Nome, Cognome, Telefono, Ruolo, Livello, Corso ID, (Partner ID), Prospect, Recensione, Attivo, Note]
                ruolo_str = str(r[4]).strip().lower() if len(r) > 4 and r[4] else 'leader'
                if 'foll' in ruolo_str:
                    ruolo_val = 'follower'
                elif 'both' in ruolo_str or 'entrambi' in ruolo_str:
                    ruolo_val = 'both'
                else:
                    ruolo_val = 'leader'

                livello_val = normalize_level(r[5] if len(r) > 5 else None)
                corso_id = str(r[6]).strip() if len(r) > 6 and r[6] else None
                if corso_id == "" or corso_id == "None":
                    corso_id = None

                # Verifica se la colonna 7 è Partner ID o Prospect
                col7 = str(r[7]).strip() if len(r) > 7 and r[7] is not None else ""
                has_partner_col = False
                partner_id = None
                if len(r) > 11 or (len(col7) > 10 and '-' in col7):
                    has_partner_col = True
                    partner_id = col7 if col7 and col7 != "None" else None

                offset = 1 if has_partner_col else 0
                prospect_idx = 7 + offset
                recensione_idx = 8 + offset
                attivo_idx = 9 + offset
                note_idx = 10 + offset

                is_prosp = str(r[prospect_idx]).strip().lower() in ['si', 'sì', 'true', '1'] if len(r) > prospect_idx and r[prospect_idx] is not None else False
                rec_str = str(r[recensione_idx]).strip().lower() if len(r) > recensione_idx and r[recensione_idx] else 'no'
                if rec_str in ['si', 'sì', 'true', '1']:
                    rec_val = 'si'
                else:
                    rec_val = 'no'

                is_act = str(r[attivo_idx]).strip().lower() not in ['no', 'false', '0'] if len(r) > attivo_idx and r[attivo_idx] is not None else True
                note_val = str(r[note_idx]).strip() if len(r) > note_idx and r[note_idx] else ""

                Allievo.objects.update_or_create(id=r[0], defaults={
                    'nome': str(r[1]).strip(),
                    'cognome': str(r[2]).strip() if len(r) > 2 and r[2] else "",
                    'telefono': str(r[3]).strip() if len(r) > 3 and r[3] else "",
                    'ruolo': ruolo_val,
                    'livello': livello_val,
                    'corso_id': corso_id,
                    'is_prospect': is_prosp,
                    'recensione': rec_val,
                    'is_active': is_act,
                    'note': note_val
                })
                allievi_count += 1
                if partner_id:
                    partner_pairs.append((str(r[0]), partner_id))
            except Exception:
                pass
        stats['allievi'] = allievi_count

        # Second pass per ripristinare i partner
        for a_id, p_id in partner_pairs:
            try:
                Allievo.objects.filter(id=a_id).update(partner_id=p_id)
            except Exception:
                pass

        # 5. Jolly
        jolly_count = 0
        for r in get_rows("Jolly"):
            if not r or len(r) < 2 or not r[1]:
                continue
            try:
                prio = int(r[3]) if len(r) > 3 and r[3] else 1
                Jolly.objects.update_or_create(id=r[0], defaults={
                    'allievo_id': r[1],
                    'priorita': prio,
                })
                jolly_count += 1
            except Exception:
                pass
        stats['jolly'] = jolly_count

        # 6. Lezioni
        lezioni_count = 0
        for r in get_rows("Lezioni"):
            if not r or len(r) < 3 or not r[1]:
                continue
            try:
                data_obj = parse_date(r[2])
                if not data_obj:
                    continue
                titolo_val = str(r[3]).strip() if len(r) > 3 and r[3] else ''
                arg_id = str(r[4]).strip() if len(r) > 4 and r[4] and str(r[4]).strip() != "None" else None
                Lezione.objects.update_or_create(id=r[0], defaults={
                    'corso_id': r[1],
                    'data': data_obj,
                    'titolo': titolo_val,
                    'argomento_id': arg_id,
                })
                lezioni_count += 1
            except Exception:
                pass
        stats['lezioni'] = lezioni_count

        # 7. Presenze
        presenze_count = 0
        for r in get_rows("Presenze"):
            if not r or len(r) < 3 or not r[1] or not r[2]:
                continue
            try:
                pres_val = str(r[3]).strip().lower() in ['si', 'sì', 'true', '1', 'presente'] if len(r) > 3 and r[3] else False
                fonte_val = 'whatsapp' if len(r) > 4 and 'what' in str(r[4]).lower() else 'manuale'
                is_jolly_val = str(r[5]).strip().lower() in ['si', 'sì', 'true', '1'] if len(r) > 5 and r[5] else False
                Presenza.objects.update_or_create(
                    lezione_id=r[2],
                    allievo_id=r[1],
                    defaults={
                        'presente': pres_val,
                        'fonte': fonte_val,
                        'is_jolly': is_jolly_val,
                    }
                )
                presenze_count += 1
            except Exception:
                pass
        stats['presenze'] = presenze_count

        # 8. Pagamenti
        pag_count = 0
        for r in get_rows("Pagamenti"):
            if not r or len(r) < 3 or not r[1]:
                continue
            try:
                corso_id = str(r[2]).strip() if len(r) > 2 and r[2] and str(r[2]).strip() != "None" else None
                importo_val = float(str(r[3]).replace(',', '.')) if len(r) > 3 and r[3] else 150.0
                trim_str = str(r[4]).strip().upper() if len(r) > 4 and r[4] else 'T1'
                if 'T2' in trim_str or 'SECONDO' in trim_str or '2' in trim_str:
                    trim_val = 'T2'
                elif 'T3' in trim_str or 'TERZO' in trim_str or '3' in trim_str:
                    trim_val = 'T3'
                else:
                    trim_val = 'T1'

                data_obj = parse_date(r[5]) if len(r) > 5 else datetime.date.today()
                note_val = str(r[6]).strip() if len(r) > 6 and r[6] else ""

                Pagamento.objects.update_or_create(id=r[0], defaults={
                    'allievo_id': r[1],
                    'corso_id': corso_id,
                    'importo': importo_val,
                    'trimestre': trim_val,
                    'data_pagamento': data_obj or datetime.date.today(),
                    'note': note_val
                })
                pag_count += 1
            except Exception:
                pass
        stats['pagamenti'] = pag_count

        # 9. Sondaggi Mattutini
        sondaggi_count = 0
        for r in get_rows("SondaggiMattutini"):
            if not r or len(r) < 3 or not r[1]:
                continue
            try:
                is_act = str(r[3]).strip().lower() not in ['no', 'false', '0'] if len(r) > 3 and r[3] is not None else True
                SondaggioMattutinoConfig.objects.update_or_create(id=r[0], defaults={
                    'corso_id': r[1],
                    'testo': str(r[2]),
                    'is_active': is_act
                })
                sondaggi_count += 1
            except Exception:
                pass
        stats['sondaggi_mattutini'] = sondaggi_count

        return JsonResponse({
            'success': True,
            'messaggio': 'Importazione globale completata con successo!',
            'statistiche': stats
        })

    except Exception as e:
        return JsonResponse({'error': f'Errore durante l\'importazione: {str(e)}'}, status=500)

