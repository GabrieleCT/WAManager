import datetime
import os
import pymupdf
from django.utils import timezone
from django.db.models import Sum
from .models import DocumentTemplate, ConfigurazioneASD, MembroDirettivo, MovimentoPrimaNota


def get_system_font_path():
    candidates = [
        r'C:\Windows\Fonts\arial.ttf',
        r'C:\Windows\Fonts\calibri.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def numero_in_lettere(n):
    """Converte un numero intero positivo (0-999999) in parola in italiano."""
    unita = ['', 'uno', 'due', 'tre', 'quattro', 'cinque', 'sei', 'sette', 'otto', 'nove']
    decine = ['', 'dieci', 'venti', 'trenta', 'quaranta', 'cinquanta', 'sessanta', 'settanta', 'ottanta', 'novanta']
    speciali = {
        10: 'dieci', 11: 'undici', 12: 'dodici', 13: 'tredici', 14: 'quattordici',
        15: 'quindici', 16: 'sedici', 17: 'diciassette', 18: 'diciotto', 19: 'diciannove'
    }
    try:
        n = int(n)
    except Exception:
        return str(n)

    if n == 0:
        return 'zero'
    if n in speciali:
        return speciali[n]
    if n < 10:
        return unita[n]
    if n < 100:
        d = n // 10
        u = n % 10
        dec_str = decine[d]
        if u in (1, 8):
            dec_str = dec_str[:-1]
        u_str = 'tré' if u == 3 and d > 0 else unita[u]
        return dec_str + u_str
    if n < 1000:
        h = n // 100
        rem = n % 100
        h_str = 'cento' if h == 1 else unita[h] + 'cento'
        return h_str + (numero_in_lettere(rem) if rem else '')
    if n < 2000:
        rem = n % 1000
        return 'mille' + (numero_in_lettere(rem) if rem else '')
    if n < 1000000:
        k = n // 1000
        rem = n % 1000
        return numero_in_lettere(k) + 'mila' + (numero_in_lettere(rem) if rem else '')
    return str(n)


def giorno_in_lettere(d):
    """Converte il giorno del mese in lettere (1 -> primo, 2 -> due, ..., 31 -> trentuno)."""
    try:
        d = int(d)
        if d == 1:
            return 'primo'
        return numero_in_lettere(d)
    except Exception:
        return str(d)


def mese_in_lettere(m):
    """Restituisce il nome italiano del mese (1 -> gennaio, ..., 12 -> dicembre)."""
    mesi = [
        '', 'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
        'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'
    ]
    try:
        m = int(m)
        if 1 <= m <= 12:
            return mesi[m]
    except Exception:
        pass
    return str(m)


def genera_pdf_ricevuta_da_template(numero, anno, intestatario, importo, causale, data_emissione):
    """
    Carica il template PDF 'ricevuta' da DocumentTemplate e compila i campi.
    """
    tmpl = DocumentTemplate.objects.filter(chiave='ricevuta').first()
    if not tmpl or not tmpl.file or not os.path.exists(tmpl.file.path):
        return None

    doc = pymupdf.open(tmpl.file.path)
    page = doc[0]

    # Cancellazione / Redaction dei placeholder nel template
    page.add_redact_annot(pymupdf.Rect(420.0, 110.0, 534.5, 125.0), fill=(1, 1, 1))
    page.add_redact_annot(pymupdf.Rect(208.0, 262.2, 534.5, 278.2), fill=(1, 1, 1))
    page.add_redact_annot(pymupdf.Rect(208.0, 282.2, 534.5, 298.4), fill=(1, 1, 1))
    page.add_redact_annot(pymupdf.Rect(208.0, 302.4, 534.5, 318.4), fill=(1, 1, 1))
    page.add_redact_annot(pymupdf.Rect(208.0, 322.4, 534.5, 338.6), fill=(1, 1, 1))
    page.apply_redactions()

    font_path = get_system_font_path()
    font = pymupdf.Font(fontfile=font_path) if font_path else None
    fontname = 'custom_font' if font_path else 'helv'
    if font_path:
        page.insert_font(fontname=fontname, fontfile=font_path)

    num_anno_str = f"{numero}/{anno}"
    try:
        importo_val = float(importo)
        importo_str = f"€ {importo_val:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
    except Exception:
        importo_str = f"€ {importo}"

    if hasattr(data_emissione, 'strftime'):
        data_str = data_emissione.strftime('%d/%m/%Y')
    else:
        data_s = str(data_emissione)
        if '-' in data_s:
            parts = data_s.split('-')
            data_str = f"{parts[2]}/{parts[1]}/{parts[0]}" if len(parts) == 3 else data_s
        else:
            data_str = data_s

    data_luogo_str = f"Milano, lì {data_str}"
    num_header_text = f"N° {num_anno_str}"
    page.insert_text(pymupdf.Point(427.8, 121.4), num_header_text, fontsize=11.0, fontname=fontname)

    def insert_right(text, baseline_y, default_size=12.5, right_x=530.0, max_w=315.0):
        size = default_size
        while size > 7.5:
            if font:
                tl = font.text_length(text, fontsize=size)
            else:
                tl = pymupdf.get_text_length(text, fontname=fontname, fontsize=size)
            if tl <= max_w:
                break
            size -= 0.5
        x = right_x - tl
        page.insert_text(pymupdf.Point(x, baseline_y), text, fontsize=size, fontname=fontname)

    insert_right(str(intestatario), 274.8, default_size=12.5)
    insert_right(importo_str, 294.8, default_size=12.5)
    insert_right(str(causale), 315.0, default_size=12.0)
    insert_right(data_luogo_str, 335.0, default_size=12.0)

    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes


def genera_pdf_modulo_tesseramento(allievo=None):
    """
    Ritorna i byte del PDF del Modulo di Tesseramento / Iscrizione.
    """
    tmpl = DocumentTemplate.objects.filter(chiave='modulo_tesseramento').first()
    if tmpl and tmpl.file and os.path.exists(tmpl.file.path):
        with open(tmpl.file.path, 'rb') as f:
            return f.read()

    doc = pymupdf.open()
    page = doc.new_page(width=595.3, height=841.9)

    font_path = get_system_font_path()
    fontname = 'custom_font' if font_path else 'helv'
    if font_path:
        try:
            page.insert_font(fontname=fontname, fontfile=font_path)
        except Exception:
            fontname = 'helv'

    page.draw_rect(pymupdf.Rect(40, 35, 555, 105), color=(0.1, 0.3, 0.5), fill=(0.95, 0.97, 1.0), width=1.5)
    page.insert_text(pymupdf.Point(55, 60), "ASD TANTOTANGO", fontsize=18, fontname=fontname, color=(0.08, 0.2, 0.4))
    page.insert_text(pymupdf.Point(55, 78), "Associazione Sportiva Dilettantistica e Culturale", fontsize=11, fontname=fontname, color=(0.25, 0.25, 0.25))
    page.insert_text(pymupdf.Point(55, 95), "C.F. / P.IVA: 97812340152 - Affiliata ACSI / FIDS", fontsize=9, fontname=fontname, color=(0.4, 0.4, 0.4))

    page.insert_text(pymupdf.Point(55, 134), "MODULO DI RICHIESTA TESSERAMENTO ED ISCRIZIONE", fontsize=14, fontname=fontname, color=(0.1, 0.1, 0.1))
    page.insert_text(pymupdf.Point(55, 149), "Anno Sociale / Sportivo 2025 - 2026", fontsize=10.5, fontname=fontname, color=(0.4, 0.4, 0.4))
    page.draw_line(pymupdf.Point(40, 158), pymupdf.Point(555, 158), color=(0.7, 0.7, 0.7), width=1)

    page.insert_text(pymupdf.Point(45, 180), "1. DATI ANAGRAFICI DEL RICHIEDENTE", fontsize=11, fontname=fontname, color=(0.08, 0.2, 0.4))

    nome_completo = f"{allievo.cognome} {allievo.nome}" if allievo else "________________________________________"
    telefono = allievo.telefono if (allievo and allievo.telefono) else "________________________________________"
    corso_nome = f"{allievo.corso.descrizione} ({allievo.corso.scuola.nome})" if (allievo and allievo.corso) else "Tango Argentino"

    y = 205
    page.insert_text(pymupdf.Point(55, y), f"Cognome e Nome:  {nome_completo}", fontsize=11, fontname=fontname)
    y += 24
    page.insert_text(pymupdf.Point(55, y), "Codice Fiscale:  ________________________________________", fontsize=11, fontname=fontname)
    y += 24
    page.insert_text(pymupdf.Point(55, y), "Nato/a a:  ____________________________________  il:  ___/___/______", fontsize=11, fontname=fontname)
    y += 24
    page.insert_text(pymupdf.Point(55, y), "Residente in Via/Piazza:  __________________________________________________", fontsize=11, fontname=fontname)
    y += 24
    page.insert_text(pymupdf.Point(55, y), "Città:  ____________________________  Prov:  ____  CAP:  ________", fontsize=11, fontname=fontname)
    y += 24
    page.insert_text(pymupdf.Point(55, y), f"Telefono / Cellulare:  {telefono}", fontsize=11, fontname=fontname)
    y += 24
    page.insert_text(pymupdf.Point(55, y), "Email:  ____________________________________________________________", fontsize=11, fontname=fontname)

    y += 35
    page.insert_text(pymupdf.Point(45, y), "2. ATTIVITÀ ISTITUZIONALE E CORSO", fontsize=11, fontname=fontname, color=(0.08, 0.2, 0.4))
    y += 22
    page.insert_text(pymupdf.Point(55, y), f"Disciplina / Corso:  {corso_nome}", fontsize=11, fontname=fontname)

    y += 35
    page.insert_text(pymupdf.Point(45, y), "3. DICHIARAZIONI DEL RICHIEDENTE", fontsize=11, fontname=fontname, color=(0.08, 0.2, 0.4))
    y += 20
    dichiarazioni = [
        "- Di voler essere iscritto/a come socio/tesserato per l'anno sociale in corso.",
        "- Di aver preso visione dello Statuto, del Regolamento sociale e di accettarli integralmente.",
        "- Di essere in possesso di certificato medico per attività sportiva non agonistica in corso di validità.",
        "- Di impegnarsi a corrispondere le quote sociali e associative stabilite dal Consiglio Direttivo."
    ]
    for d in dichiarazioni:
        page.insert_text(pymupdf.Point(55, y), d, fontsize=9.5, fontname=fontname, color=(0.2, 0.2, 0.2))
        y += 18

    y += 15
    page.insert_text(pymupdf.Point(45, y), "4. INFORMATIVA E CONSENSO PRIVACY (GDPR 2016/679)", fontsize=11, fontname=fontname, color=(0.08, 0.2, 0.4))
    y += 18
    privacy_text = (
        "Il richiedente acconsente al trattamento dei dati personali forniti per le finalità istituzionali dell'ASD,\n"
        "nonché per le comunicazioni organizzative e associative ai sensi del Regolamento UE 2016/679."
    )
    for line in privacy_text.split('\n'):
        page.insert_text(pymupdf.Point(55, y), line, fontsize=9.0, fontname=fontname, color=(0.3, 0.3, 0.3))
        y += 14

    y += 35
    page.insert_text(pymupdf.Point(55, y), "Luogo e Data: _________________________", fontsize=10, fontname=fontname)
    page.insert_text(pymupdf.Point(340, y), "Firma del Richiedente: _________________________", fontsize=10, fontname=fontname)

    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes



def format_valuta_italiana(val):
    if val is None:
        val = 0.0
    return f"{float(val):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def genera_pdf_allegati_bilancio(
    anno_esercizio,
    asd=None,
    data_assemblea="",
    nome_presidente="",
    nome_segretario="",
    tot_entrate=0.0,
    tot_uscite=0.0,
    saldo=0.0
):
    """
    Genera le pagine di allegato al Verbale di approvazione:
    1. Rendiconto Economico-Finanziario Consuntivo (Entrate/Uscite per categoria e Quadro di Sintesi)
    2. Bilancio Mensile (12 mesi: Entrate, Uscite, Saldo e Risultato)
    3. Registro Analitico dei Movimenti di Prima Nota Cassa
    """
    import io
    from reportlab.lib.pagesizes import A4
    from reportlab.platypus import (
        SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
    )
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors
    from reportlab.pdfgen import canvas
    from django.db.models import Sum
    from .models import MovimentoPrimaNota

    class NumberedCanvas(canvas.Canvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self._saved_page_states = []

        def showPage(self):
            self._saved_page_states.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            num_pages = len(self._saved_page_states)
            for state in self._saved_page_states:
                self.__dict__.update(state)
                self.draw_page_number(num_pages)
                super().showPage()
            super().save()

        def draw_page_number(self, page_count):
            self.saveState()
            self.setFont("Helvetica", 8)
            self.setFillColor(colors.HexColor('#64748B'))
            # Intestazione superiore
            self.drawString(36, 810, "Tanto Tango ASD — Allegati al Verbale di Approvazione Rendiconto")
            self.setStrokeColor(colors.HexColor('#CBD5E1'))
            self.setLineWidth(0.5)
            self.line(36, 804, 559, 804)

            # Piè di pagina
            page_text = f"Allegato - Pagina {self._pageNumber} di {page_count}"
            self.drawRightString(559, 24, page_text)
            self.drawString(36, 24, "Documento contabile ufficiale generato tramite TantoTango Manager")
            self.line(36, 32, 559, 32)
            self.restoreState()

    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        leftMargin=36,
        rightMargin=36,
        topMargin=46,
        bottomMargin=46
    )

    styles = getSampleStyleSheet()
    primary = colors.HexColor('#8B2529')
    dark = colors.HexColor('#1E293B')
    gray = colors.HexColor('#64748B')
    light_bg = colors.HexColor('#F8FAFC')
    border_col = colors.HexColor('#CBD5E1')
    green_text = colors.HexColor('#166534')
    red_text = colors.HexColor('#991B1B')

    h1_style = ParagraphStyle('H1', fontName='Helvetica-Bold', fontSize=14, textColor=primary, alignment=1, spaceAfter=3)
    sub_style = ParagraphStyle('Sub', fontName='Helvetica', fontSize=9, textColor=gray, alignment=1, spaceAfter=12)
    sec_style = ParagraphStyle('Sec', fontName='Helvetica-Bold', fontSize=11, textColor=dark, spaceBefore=8, spaceAfter=4)
    th_style = ParagraphStyle('TH', fontName='Helvetica-Bold', fontSize=8, textColor=colors.white, alignment=1)
    td_style = ParagraphStyle('TD', fontName='Helvetica', fontSize=8, textColor=dark)
    td_r = ParagraphStyle('TDR', fontName='Helvetica', fontSize=8, textColor=dark, alignment=2)
    td_bold_r = ParagraphStyle('TDBR', fontName='Helvetica-Bold', fontSize=8, textColor=dark, alignment=2)
    td_center = ParagraphStyle('TDC', fontName='Helvetica', fontSize=8, textColor=dark, alignment=1)

    elements = []
    qs = MovimentoPrimaNota.objects.filter(data__year=anno_esercizio)

    # =========================================================================
    # ALLEGATO 1: RENDICONTO ECONOMICO FINANZIARIO ANNUALE (PER CATEGORIA)
    # =========================================================================
    elements.append(Paragraph("ALLEGATO 1: RENDICONTO ECONOMICO-FINANZIARIO", h1_style))
    elements.append(Paragraph(f"Consuntivo per Categorie di Entrata e Spesa — Esercizio {anno_esercizio}", sub_style))

    # Tabella Entrate per Categoria
    elements.append(Paragraph("Proventi ed Entrate Istituzionali", sec_style))
    entrate_cat = qs.filter(tipo='entrata').values('categoria').annotate(tot=Sum('importo')).order_by('-tot')
    t_entrate_data = [[Paragraph('Categoria di Entrata', th_style), Paragraph('Importo (€)', th_style), Paragraph('Incidenza %', th_style)]]
    
    tot_e_val = float(tot_entrate or 0.0)
    if entrate_cat.exists():
        for item in entrate_cat:
            cat_nome = item['categoria'] or 'Altro'
            cat_tot = float(item['tot'] or 0.0)
            inc = (cat_tot / tot_e_val * 100) if tot_e_val > 0 else 0.0
            t_entrate_data.append([
                Paragraph(cat_nome, td_style),
                Paragraph(format_valuta_italiana(cat_tot), td_r),
                Paragraph(f"{inc:.1f}%", td_center),
            ])
    else:
        t_entrate_data.append([Paragraph('Nessuna entrata registrata', td_style), Paragraph('0,00', td_r), Paragraph('0,0%', td_center)])

    t_entrate_data.append([
        Paragraph('<b>TOTALE ENTRATE</b>', td_style),
        Paragraph(f"<b>{format_valuta_italiana(tot_e_val)}</b>", td_bold_r),
        Paragraph('<b>100,0%</b>', td_center),
    ])

    t_entrate = Table(t_entrate_data, colWidths=[310, 110, 103])
    t_entrate.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), primary),
        ('GRID', (0,0), (-1,-1), 0.5, border_col),
        ('BACKGROUND', (0,-1), (-1,-1), light_bg),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
    ]))
    elements.append(t_entrate)
    elements.append(Spacer(1, 10))

    # Tabella Uscite per Categoria
    elements.append(Paragraph("Oneri e Spese Istituzionali", sec_style))
    uscite_cat = qs.filter(tipo='uscita').values('categoria').annotate(tot=Sum('importo')).order_by('-tot')
    t_uscite_data = [[Paragraph('Categoria di Uscita', th_style), Paragraph('Importo (€)', th_style), Paragraph('Incidenza %', th_style)]]
    
    tot_u_val = float(tot_uscite or 0.0)
    if uscite_cat.exists():
        for item in uscite_cat:
            cat_nome = item['categoria'] or 'Altro'
            cat_tot = float(item['tot'] or 0.0)
            inc = (cat_tot / tot_u_val * 100) if tot_u_val > 0 else 0.0
            t_uscite_data.append([
                Paragraph(cat_nome, td_style),
                Paragraph(format_valuta_italiana(cat_tot), td_r),
                Paragraph(f"{inc:.1f}%", td_center),
            ])
    else:
        t_uscite_data.append([Paragraph('Nessuna uscita registrata', td_style), Paragraph('0,00', td_r), Paragraph('0,0%', td_center)])

    t_uscite_data.append([
        Paragraph('<b>TOTALE USCITE</b>', td_style),
        Paragraph(f"<b>{format_valuta_italiana(tot_u_val)}</b>", td_bold_r),
        Paragraph('<b>100,0%</b>', td_center),
    ])

    t_uscite = Table(t_uscite_data, colWidths=[310, 110, 103])
    t_uscite.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), primary),
        ('GRID', (0,0), (-1,-1), 0.5, border_col),
        ('BACKGROUND', (0,-1), (-1,-1), light_bg),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
    ]))
    elements.append(t_uscite)
    elements.append(Spacer(1, 12))

    # Quadro di sintesi di gestione
    saldo_val = float(saldo or 0.0)
    is_avanzo = saldo_val >= 0
    sintesi_label = "AVANZO DI GESTIONE (Utile)" if is_avanzo else "DISAVANZO DI GESTIONE (Perdita)"
    sintesi_color = green_text if is_avanzo else red_text
    sintesi_bg = colors.HexColor('#DCFCE7') if is_avanzo else colors.HexColor('#FEE2E2')

    t_sintesi_data = [
        [Paragraph('<b>QUADRO DI SINTESI ECONOMICA DI ESERCIZIO</b>', ParagraphStyle('QS', fontName='Helvetica-Bold', fontSize=9, textColor=dark)), Paragraph('', td_style)],
        [Paragraph('Totale Proventi ed Entrate Istituzionali', td_style), Paragraph(f"€ {format_valuta_italiana(tot_e_val)}", td_bold_r)],
        [Paragraph('Totale Oneri e Spese Istituzionali', td_style), Paragraph(f"€ {format_valuta_italiana(tot_u_val)}", td_bold_r)],
        [
            Paragraph(f"<b>{sintesi_label}</b>", ParagraphStyle('SL', fontName='Helvetica-Bold', fontSize=9, textColor=sintesi_color)),
            Paragraph(f"<b>€ {format_valuta_italiana(saldo_val)}</b>", ParagraphStyle('SV', fontName='Helvetica-Bold', fontSize=10, textColor=sintesi_color, alignment=2))
        ],
    ]
    t_sintesi = Table(t_sintesi_data, colWidths=[360, 163])
    t_sintesi.setStyle(TableStyle([
        ('SPAN', (0,0), (1,0)),
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#E2E8F0')),
        ('GRID', (0,0), (-1,-1), 0.5, border_col),
        ('BACKGROUND', (0,-1), (-1,-1), sintesi_bg),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('TOPPADDING', (0,0), (-1,-1), 5),
    ]))
    elements.append(t_sintesi)

    elements.append(PageBreak())

    # =========================================================================
    # ALLEGATO 2: BILANCIO MENSILE (12 MESI)
    # =========================================================================
    elements.append(Paragraph("ALLEGATO 2: RIEPILOGO MENSILE DI BILANCIO", h1_style))
    elements.append(Paragraph(f"Andamento e Rendiconto Mensile Cassa — Esercizio {anno_esercizio}", sub_style))

    mesi_nomi = [
        'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
        'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ]
    t_mesi_data = [[
        Paragraph('Mese', th_style),
        Paragraph('Entrate (€)', th_style),
        Paragraph('Uscite (€)', th_style),
        Paragraph('Saldo Mensile (€)', th_style),
        Paragraph('Esito', th_style),
    ]]

    tot_m_e = 0.0
    tot_m_u = 0.0

    for idx, m_nome in enumerate(mesi_nomi, start=1):
        m_e = float(qs.filter(tipo='entrata', data__month=idx).aggregate(s=Sum('importo'))['s'] or 0.0)
        m_u = float(qs.filter(tipo='uscita', data__month=idx).aggregate(s=Sum('importo'))['s'] or 0.0)
        m_s = m_e - m_u
        tot_m_e += m_e
        tot_m_u += m_u

        if m_s > 0:
            esito_text = "Utile"
            esito_col = green_text
        elif m_s < 0:
            esito_text = "Perdita"
            esito_col = red_text
        else:
            esito_text = "Pareggio"
            esito_col = gray

        t_mesi_data.append([
            Paragraph(m_nome, td_style),
            Paragraph(format_valuta_italiana(m_e), td_r),
            Paragraph(format_valuta_italiana(m_u), td_r),
            Paragraph(format_valuta_italiana(m_s), ParagraphStyle('MS', fontName='Helvetica', fontSize=8, textColor=esito_col, alignment=2)),
            Paragraph(esito_text, ParagraphStyle('ES', fontName='Helvetica-Bold', fontSize=8, textColor=esito_col, alignment=1)),
        ])

    tot_m_s = tot_m_e - tot_m_u
    tot_esito = "Utile" if tot_m_s > 0 else ("Perdita" if tot_m_s < 0 else "Pareggio")
    tot_col = green_text if tot_m_s > 0 else (red_text if tot_m_s < 0 else gray)

    t_mesi_data.append([
        Paragraph('<b>TOTALE ANNUALE</b>', td_style),
        Paragraph(f"<b>{format_valuta_italiana(tot_m_e)}</b>", td_bold_r),
        Paragraph(f"<b>{format_valuta_italiana(tot_m_u)}</b>", td_bold_r),
        Paragraph(f"<b>{format_valuta_italiana(tot_m_s)}</b>", ParagraphStyle('MTS', fontName='Helvetica-Bold', fontSize=8, textColor=tot_col, alignment=2)),
        Paragraph(f"<b>{tot_esito}</b>", ParagraphStyle('MET', fontName='Helvetica-Bold', fontSize=8, textColor=tot_col, alignment=1)),
    ])

    t_mesi = Table(t_mesi_data, colWidths=[120, 100, 100, 110, 93])
    t_mesi.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), primary),
        ('GRID', (0,0), (-1,-1), 0.5, border_col),
        ('BACKGROUND', (0,-1), (-1,-1), light_bg),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
    ]))
    elements.append(t_mesi)

    elements.append(PageBreak())

    # =========================================================================
    # ALLEGATO 3: REGISTRO DEI MOVIMENTI DI PRIMA NOTA CASSA
    # =========================================================================
    elements.append(Paragraph("ALLEGATO 3: REGISTRO MOVIMENTI PRIMA NOTA CASSA", h1_style))
    elements.append(Paragraph(f"Dettaglio Analitico delle Registrazioni di Cassa — Anno {anno_esercizio}", sub_style))

    movimenti = qs.order_by('data', 'created_at')
    t_pn_data = [[
        Paragraph('Data', th_style),
        Paragraph('Descrizione', th_style),
        Paragraph('Categoria', th_style),
        Paragraph('Tipo', th_style),
        Paragraph('Importo (€)', th_style),
    ]]

    if movimenti.exists():
        for m in movimenti:
            is_e = (m.tipo == 'entrata')
            tipo_label = "Entrata" if is_e else "Uscita"
            tipo_color = green_text if is_e else red_text
            sign = "+" if is_e else "-"
            t_pn_data.append([
                Paragraph(m.data.strftime('%d/%m/%Y'), td_center),
                Paragraph(m.descrizione or '-', td_style),
                Paragraph(m.categoria or '-', td_style),
                Paragraph(tipo_label, ParagraphStyle('MT', fontName='Helvetica', fontSize=8, textColor=tipo_color, alignment=1)),
                Paragraph(f"{sign}{format_valuta_italiana(m.importo)}", ParagraphStyle('MI', fontName='Helvetica', fontSize=8, textColor=tipo_color, alignment=2)),
            ])
    else:
        t_pn_data.append([
            Paragraph('-', td_center),
            Paragraph('Nessun movimento registrato in prima nota per questo esercizio.', td_style),
            Paragraph('-', td_style),
            Paragraph('-', td_center),
            Paragraph('0,00', td_r),
        ])

    t_pn_data.append([
        Paragraph('<b>TOTALE</b>', td_center),
        Paragraph(f"<b>N. {movimenti.count()} movimenti registrati</b>", td_style),
        Paragraph('-', td_center),
        Paragraph('<b>SALDO CASSA</b>', td_center),
        Paragraph(f"<b>{format_valuta_italiana(tot_m_s)}</b>", ParagraphStyle('PNS', fontName='Helvetica-Bold', fontSize=8, textColor=tot_col, alignment=2)),
    ])

    t_pn = Table(t_pn_data, colWidths=[70, 183, 140, 60, 70], repeatRows=1)
    t_pn.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), primary),
        ('GRID', (0,0), (-1,-1), 0.5, border_col),
        ('BACKGROUND', (0,-1), (-1,-1), light_bg),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('TOPPADDING', (0,0), (-1,-1), 4),
    ]))
    elements.append(t_pn)

    doc.build(elements, canvasmaker=NumberedCanvas)
    return buf.getvalue()


def genera_pdf_verbale_rendiconto(data_assemblea, orario_assemblea, data_affissione, anno_esercizio=None):
    """
    Compila il template PDF 'verbale_rendiconto' con i dati dell'assemblea, dell'ASD,
    del rendiconto economico e appone le firme digitali/scansionate.
    
    Ritorna:
      tuple: (pdf_bytes, filename, dict_info)
    """
    def parse_date(d_val):
        if not d_val:
            return timezone.now().date()
        if isinstance(d_val, (datetime.date, datetime.datetime)):
            return d_val if isinstance(d_val, datetime.date) else d_val.date()
        d_str = str(d_val).strip()
        for fmt in ('%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y'):
            try:
                return datetime.datetime.strptime(d_str, fmt).date()
            except ValueError:
                pass
        return timezone.now().date()

    d_ass = parse_date(data_assemblea)
    d_aff = parse_date(data_affissione)

    if not anno_esercizio:
        anno_esercizio = d_ass.year - 1 if d_ass.month <= 6 else d_ass.year
    else:
        try:
            anno_esercizio = int(anno_esercizio)
        except ValueError:
            anno_esercizio = d_ass.year - 1

    orario_str = str(orario_assemblea or '20:00').strip()
    if len(orario_str) == 4 and orario_str[1] == ':':
        orario_str = '0' + orario_str

    # Calcolo orario di fine seduta (default 1 ora e 30 minuti dopo)
    orario_fine_str = '21:30'
    try:
        parts = orario_str.split(':')
        h, m = int(parts[0]), int(parts[1])
        end_h = (h + 1 + (m + 30) // 60) % 24
        end_m = (m + 30) % 60
        orario_fine_str = f"{end_h:02d}:{end_m:02d}"
    except Exception:
        orario_fine_str = '21:30'

    anno_in_lettere_val = numero_in_lettere(d_ass.year)
    giorno_in_lettere_val = giorno_in_lettere(d_ass.day)
    nome_mese_in_lettere_val = mese_in_lettere(d_ass.month)
    data_affissione_str = d_aff.strftime('%d/%m/%Y')

    asd = ConfigurazioneASD.get_instance()
    sede_legale = (asd.sede_legale or 'via Benaco 17, 20139 - Milano (MI)').strip()

    pres = MembroDirettivo.objects.filter(ruolo='presidente').first()
    vice = MembroDirettivo.objects.filter(ruolo='vicepresidente').first()
    seg = MembroDirettivo.objects.filter(ruolo='segretario').first()

    nome_pres = pres.nome_completo if pres else 'Angelo Gabriele Cataldo'
    nome_vice = vice.nome_completo if vice else 'Ioana-Maria Gavrilescu'
    nome_seg = seg.nome_completo if seg else 'Salvatore Cataldo'

    # Calcolo entrate, uscite e saldo per l'anno di esercizio
    tot_entrate = MovimentoPrimaNota.objects.filter(data__year=anno_esercizio, tipo='entrata').aggregate(s=Sum('importo'))['s'] or 0.0
    tot_uscite = MovimentoPrimaNota.objects.filter(data__year=anno_esercizio, tipo='uscita').aggregate(s=Sum('importo'))['s'] or 0.0
    saldo = round(float(tot_entrate) - float(tot_uscite), 2)

    def format_euro(val):
        return f"{val:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')

    if saldo > 0:
        risultato_desc = f"un avanzo di gestione di euro {format_euro(saldo)}"
        utili_str = f"euro {format_euro(saldo)}"
    elif saldo < 0:
        risultato_desc = f"un disavanzo di gestione di euro {format_euro(abs(saldo))}"
        utili_str = f"- euro {format_euro(abs(saldo))}"
    else:
        risultato_desc = "un pareggio di gestione (euro 0,00)"
        utili_str = "euro 0,00"

    substitutions = {
        '<anno_in_lettere>': anno_in_lettere_val,
        '<giorno_del_mese_in_lettere>': giorno_in_lettere_val,
        '<nome_del_mese_in_lettere>': nome_mese_in_lettere_val,
        '<sede_legale_ASD>': sede_legale,
        '<anno_esercizio>': str(anno_esercizio),
        '<nome_e_cognome_presidente>': nome_pres,
        '<nome_e_cognome_vicepresidente>': nome_vice,
        '<nome_e_cognome_segretario>': nome_seg,
        '<data_affissione_convocazione>': data_affissione_str,
        '<risultato_gestione_descrizione>': risultato_desc,
        '<utili_di_fine_anno>': utili_str,
    }

    # Individua il file di template
    tmpl = DocumentTemplate.objects.filter(chiave='verbale_rendiconto').first()
    template_path = None
    if tmpl and tmpl.file and os.path.exists(tmpl.file.path):
        template_path = tmpl.file.path
    else:
        from django.conf import settings
        candidate = os.path.join(settings.MEDIA_ROOT, 'templates_pdf', 'Verbale.pdf')
        if os.path.exists(candidate):
            template_path = candidate

    if not template_path:
        raise ValueError("Nessun template PDF caricato per 'Verbale Approvazione Rendiconto'. Vai in Impostazioni > Template per caricarlo.")

    doc = pymupdf.open(template_path)
    font_path = get_system_font_path()
    font = pymupdf.Font(fontfile=font_path) if font_path else None
    fontname = 'custom_font' if font_path else 'helv'

    for pno, page in enumerate(doc):
        page_substitutions = []

        # 1. Rileva i placeholder
        for ph, val in substitutions.items():
            rects = page.search_for(ph)
            for r in rects:
                page_substitutions.append((r, val, ph))
                page.add_redact_annot(r, fill=(1, 1, 1))

        # 2. Orario assemblea
        if pno == 0 and orario_str != '20:00':
            time_rects = page.search_for('20:00')
            for r in time_rects:
                page_substitutions.append((r, orario_str, '20:00'))
                page.add_redact_annot(r, fill=(1, 1, 1))

        if pno == 1 and orario_fine_str != '21:30':
            end_rects = page.search_for('21:30')
            for r in end_rects:
                page_substitutions.append((r, orario_fine_str, '21:30'))
                page.add_redact_annot(r, fill=(1, 1, 1))

        # 3. Applica sbiancamenti
        page.apply_redactions()

        if font_path:
            try:
                page.insert_font(fontname=fontname, fontfile=font_path)
            except Exception:
                fontname = 'helv'

        # 4. Inserimento testo con font adattivo
        for r, val, ph in page_substitutions:
            fontsize = 12.0
            if 'presidente' in ph or 'segretario' in ph:
                fontsize = 11.0
            if font:
                tl = font.text_length(val, fontsize=fontsize)
            else:
                tl = pymupdf.get_text_length(val, fontname=fontname, fontsize=fontsize)

            if tl > r.width and r.width > 0:
                scale = r.width / tl
                if scale < 0.95:
                    fontsize = max(8.0, fontsize * scale)

            baseline_y = r.y1 - 2.5
            page.insert_text(pymupdf.Point(r.x0, baseline_y), val, fontname=fontname, fontsize=fontsize, color=(0, 0, 0))

        # 5. Firme su Pagina 2
        if pno == 1:
            # Inserire l'immagine della firma del Vicepresidente sovrapposta ai puntini sotto "il Segretario"
            if vice and vice.firma and os.path.exists(vice.firma.path):
                rect_sec = pymupdf.Rect(80, 382, 255, 432)
                page.insert_image(rect_sec, filename=vice.firma.path, keep_proportion=True)

            # Inserire l'immagine della firma del Presidente sovrapposta ai puntini sotto "il Presidente"
            if pres and pres.firma and os.path.exists(pres.firma.path):
                rect_pres = pymupdf.Rect(320, 382, 495, 432)
                page.insert_image(rect_pres, filename=pres.firma.path, keep_proportion=True)

    # 6. Generazione e inclusione Pagine di Allegato (Rendiconto Annuale, Bilancio Mensile, Prima Nota)
    try:
        allegati_pdf_bytes = genera_pdf_allegati_bilancio(
            anno_esercizio=anno_esercizio,
            asd=asd,
            data_assemblea=d_ass.strftime('%d/%m/%Y'),
            nome_presidente=nome_pres,
            nome_segretario=nome_seg or nome_vice,
            tot_entrate=tot_entrate,
            tot_uscite=tot_uscite,
            saldo=saldo,
        )
        if allegati_pdf_bytes:
            doc_allegati = pymupdf.open("pdf", allegati_pdf_bytes)
            doc.insert_pdf(doc_allegati)
            doc_allegati.close()
    except Exception as e:
        import logging
        logging.error(f"Errore generazione allegati bilancio: {e}", exc_info=True)

    filename = f"Verbale_Approvazione_Rendiconto_{anno_esercizio}.pdf"
    pdf_bytes = doc.tobytes()
    doc.close()

    info = {
        'anno_esercizio': anno_esercizio,
        'data_assemblea': d_ass.strftime('%d/%m/%Y'),
        'orario_assemblea': orario_str,
        'data_affissione': data_affissione_str,
        'risultato_desc': risultato_desc,
        'saldo': saldo,
        'tot_entrate': tot_entrate,
        'tot_uscite': tot_uscite,
        'presidente': nome_pres,
        'vicepresidente': nome_vice,
        'segretario': nome_seg,
        'has_firma_pres': bool(pres and pres.firma),
        'has_firma_vice': bool(vice and vice.firma),
        'filename': filename,
    }

    return pdf_bytes, filename, info
