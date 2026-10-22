import os
import pymupdf
from django.utils import timezone
from .models import DocumentTemplate


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


def genera_pdf_ricevuta_da_template(numero, anno, intestatario, importo, causale, data_emissione):
    """
    Carica il template PDF 'ricevuta' da DocumentTemplate e compila i campi:
      - Numero/Anno (N° <numero>/<anno>)
      - Nome e Cognome (<nome_intestatario> <cognome_intestatario>)
      - Importo (<importo>)
      - Causale (<causale>)
      - Luogo e Data (Milano, lì <data_di_emissione>)
    Ritorna i byte del PDF compilato, o None se il template non è presente.
    """
    tmpl = DocumentTemplate.objects.filter(chiave='ricevuta').first()
    if not tmpl or not tmpl.file or not os.path.exists(tmpl.file.path):
        return None

    doc = pymupdf.open(tmpl.file.path)
    page = doc[0]

    # 1. Cancellazione / Redaction dei placeholder nel template
    # Header: N° <numero>/<anno >
    page.add_redact_annot(pymupdf.Rect(420.0, 110.0, 534.5, 125.0), fill=(1, 1, 1))

    # Celle della tabella (colonna di destra) - interne per NON toccare i bordi neri
    # Divisorio centrale: 204.36 - 207.36 | Bordo destro: 535.44 - 538.44
    page.add_redact_annot(pymupdf.Rect(208.0, 262.2, 534.5, 278.2), fill=(1, 1, 1))  # Riga 1: Nome e Cognome
    page.add_redact_annot(pymupdf.Rect(208.0, 282.2, 534.5, 298.4), fill=(1, 1, 1))  # Riga 2: Importo
    page.add_redact_annot(pymupdf.Rect(208.0, 302.4, 534.5, 318.4), fill=(1, 1, 1))  # Riga 3: Causale
    page.add_redact_annot(pymupdf.Rect(208.0, 322.4, 534.5, 338.6), fill=(1, 1, 1))  # Riga 4: Luogo e Data

    page.apply_redactions()

    # 2. Configurazione font con supporto TrueType (€, lettere accentate)
    font_path = get_system_font_path()
    font = pymupdf.Font(fontfile=font_path) if font_path else None
    fontname = 'custom_font' if font_path else 'helv'
    if font_path:
        page.insert_font(fontname=fontname, fontfile=font_path)

    # Formattazione stringhe
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
            if len(parts) == 3:
                data_str = f"{parts[2]}/{parts[1]}/{parts[0]}"
            else:
                data_str = data_s
        else:
            data_str = data_s

    data_luogo_str = f"Milano, lì {data_str}"

    # Inserimento N° <numero>/<anno> nell'intestazione
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

    # Inserimento celle tabella con allineamento millimetrico alla linea di base delle etichette a sinistra:
    # Nome e Cognome: baseline 274.8
    # Importo: baseline 294.8
    # Causale: baseline 315.0
    # Luogo e Data: baseline 335.0
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
    Se in DocumentTemplate è presente un file caricato per 'modulo_tesseramento',
    carica e ritorna quel file.
    In alternativa, genera un PDF A4 ufficiale, pulito e vettoriale con i dati dell'allievo
    (se fornito) e gli spazi per la compilazione manuale e la firma.
    """
    tmpl = DocumentTemplate.objects.filter(chiave='modulo_tesseramento').first()
    if tmpl and tmpl.file and os.path.exists(tmpl.file.path):
        try:
            with open(tmpl.file.path, 'rb') as f:
                return f.read()
        except Exception as e:
            print(f"Errore lettura file template modulo_tesseramento: {e}")

    # Fallback: Genera PDF standard con PyMuPDF
    doc = pymupdf.open()
    page = doc.new_page(width=595.3, height=841.9)  # A4

    font_path = get_system_font_path()
    fontname = 'custom_font' if font_path else 'helv'
    if font_path:
        try:
            page.insert_font(fontname=fontname, fontfile=font_path)
        except Exception:
            fontname = 'helv'

    # Box Intestazione Associazione
    page.draw_rect(pymupdf.Rect(40, 35, 555, 105), color=(0.1, 0.3, 0.5), fill=(0.95, 0.97, 1.0), width=1.5)
    page.insert_text(pymupdf.Point(55, 60), "ASD TANTOTANGO", fontsize=18, fontname=fontname, color=(0.08, 0.2, 0.4))
    page.insert_text(pymupdf.Point(55, 78), "Associazione Sportiva Dilettantistica e Culturale", fontsize=11, fontname=fontname, color=(0.25, 0.25, 0.25))
    page.insert_text(pymupdf.Point(55, 95), "C.F. / P.IVA: 97812340152 - Affiliata ACSI / FIDS", fontsize=9, fontname=fontname, color=(0.4, 0.4, 0.4))

    # Titolo Modulo
    page.insert_text(pymupdf.Point(55, 134), "MODULO DI RICHIESTA TESSERAMENTO ED ISCRIZIONE", fontsize=14, fontname=fontname, color=(0.1, 0.1, 0.1))
    page.insert_text(pymupdf.Point(55, 149), "Anno Sociale / Sportivo 2025 - 2026", fontsize=10.5, fontname=fontname, color=(0.4, 0.4, 0.4))
    page.draw_line(pymupdf.Point(40, 158), pymupdf.Point(555, 158), color=(0.7, 0.7, 0.7), width=1)

    # 1. Dati Anagrafici
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

    # 2. Attività e Corso
    y += 35
    page.insert_text(pymupdf.Point(45, y), "2. ATTIVITÀ ISTITUZIONALE E CORSO", fontsize=11, fontname=fontname, color=(0.08, 0.2, 0.4))
    y += 22
    page.insert_text(pymupdf.Point(55, y), f"Disciplina / Corso:  {corso_nome}", fontsize=11, fontname=fontname)

    # 3. Dichiarazioni
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

    # 4. Privacy
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

    # 5. Firme
    y += 35
    page.insert_text(pymupdf.Point(55, y), "Luogo e Data: _________________________", fontsize=10, fontname=fontname)
    page.insert_text(pymupdf.Point(340, y), "Firma del Richiedente: _________________________", fontsize=10, fontname=fontname)

    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes


