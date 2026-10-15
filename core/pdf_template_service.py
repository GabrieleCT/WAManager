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

