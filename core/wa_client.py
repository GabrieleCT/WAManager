import os
import requests

GATEWAY_BASE = os.environ.get("GATEWAY_BASE_URL", "http://localhost:4002")
GATEWAY_URL = os.environ.get("GATEWAY_URL", f"{GATEWAY_BASE}/api/send")

def send_whatsapp_message(to: str, message: str, is_group: bool = True, is_poll: bool = False, poll_options: list = None) -> dict:
    """
    Invia un messaggio o sondaggio a WhatsApp tramite il gateway Node.js locale.
    Pulisce e normalizza automaticamente i numeri di telefono individuali.
    """
    if poll_options is None:
        poll_options = []

    clean_to = str(to or '').strip()
    if not is_group and not clean_to.endswith('@g.us') and not clean_to.endswith('@lid'):
        digits = ''.join(c for c in clean_to if c.isdigit())
        if digits.startswith('00'):
            digits = digits[2:]
        if len(digits) in (9, 10) and digits.startswith('3'):
            digits = '39' + digits
        clean_to = digits

    payload = {
        "to": clean_to,
        "message": message,
        "isGroup": is_group,
        "isPoll": is_poll,
        "pollOptions": poll_options
    }

    try:
        response = requests.post(GATEWAY_URL, json=payload, timeout=20)
        data = {}
        try:
            data = response.json()
        except Exception:
            pass

        if response.status_code in (200, 201) and data.get('success'):
            return {"success": True, "response": data}
        else:
            err = data.get('error') or f"HTTP {response.status_code}"
            return {"success": False, "error": err}
    except requests.exceptions.Timeout:
        return {"success": False, "error": "Timeout durante l'invio al Gateway WhatsApp (la risposta ha impiegato più di 20s)."}
    except requests.exceptions.RequestException as e:
        print(f"Errore di comunicazione col Gateway WhatsApp: {e}")
        return {"success": False, "error": str(e)}


def send_whatsapp_document(to: str, file_bytes: bytes, filename: str, caption: str = '', is_group: bool = False) -> dict:
    """
    Invia un documento/file (es. PDF) via WhatsApp tramite il gateway locale.
    """
    import base64

    clean_to = str(to or '').strip()
    if not is_group and not clean_to.endswith('@g.us') and not clean_to.endswith('@lid'):
        digits = ''.join(c for c in clean_to if c.isdigit())
        if digits.startswith('00'):
            digits = digits[2:]
        if len(digits) in (9, 10) and digits.startswith('3'):
            digits = '39' + digits
        clean_to = digits

    payload = {
        "to": clean_to,
        "message": caption,
        "isGroup": is_group,
        "fileBase64": base64.b64encode(file_bytes).decode('utf-8'),
        "fileName": filename,
        "mimetype": "application/pdf"
    }

    try:
        response = requests.post(GATEWAY_URL, json=payload, timeout=65)
        data = {}
        try:
            data = response.json()
        except Exception:
            pass

        if response.status_code in (200, 201) and data.get('success'):
            return {"success": True, "response": data}
        else:
            err = data.get('error') or f"HTTP {response.status_code}"
            return {"success": False, "error": err}
    except requests.exceptions.Timeout:
        return {"success": False, "error": "Timeout durante l'invio al Gateway WhatsApp (la risposta ha impiegato più di 65s)."}
    except requests.exceptions.RequestException as e:
        print(f"Errore di comunicazione col Gateway WhatsApp: {e}")
        return {"success": False, "error": str(e)}


def get_whatsapp_status() -> dict:
    """
    Recupera lo stato attuale della connessione WhatsApp dal Gateway.
    """
    try:
        r = requests.get(f"{GATEWAY_BASE}/api/status", timeout=5)
        return r.json()
    except Exception as e:
        return {"status": "UNREACHABLE", "error": str(e)}


def get_group_participants(group_id: str) -> dict:
    """
    Recupera la lista dei partecipanti di un gruppo WhatsApp dal Gateway.
    """
    try:
        gid = group_id.strip()
        r = requests.get(f"{GATEWAY_BASE}/api/groups/{gid}/participants", timeout=12)
        if r.status_code == 200:
            return r.json()
        data = r.json() if r.headers.get('content-type', '').startswith('application/json') else {}
        return {"success": False, "error": data.get("error", f"HTTP {r.status_code}")}
    except Exception as e:
        return {"success": False, "error": str(e)}


def add_group_participant(group_id: str, phone: str) -> dict:
    """
    Aggiunge un partecipante a un gruppo WhatsApp tramite il Gateway.
    """
    try:
        gid = group_id.strip()
        r = requests.post(
            f"{GATEWAY_BASE}/api/groups/{gid}/participants/add",
            json={"phone": phone},
            timeout=15
        )
        if r.status_code in (200, 201):
            return r.json()
        data = r.json() if r.headers.get('content-type', '').startswith('application/json') else {}
        return {"success": False, "error": data.get("error", f"HTTP {r.status_code}")}
    except Exception as e:
        return {"success": False, "error": str(e)}


def resolve_group_link(link_or_code: str) -> dict:
    """
    Risolve un link di invito (o codice) di un gruppo WhatsApp
    nel suo JID reale (es. 120363... @g.us) e ne ricava il nome (subject).
    """
    try:
        clean = (link_or_code or "").strip()
        if not clean:
            return {"success": False, "error": "Link o codice d'invito mancante"}
        r = requests.post(
            f"{GATEWAY_BASE}/api/groups/resolve",
            json={"link": clean},
            timeout=10
        )
        if r.status_code in (200, 201):
            return r.json()
        data = r.json() if r.headers.get('content-type', '').startswith('application/json') else {}
        return {"success": False, "error": data.get("error", f"HTTP {r.status_code}")}
    except Exception as e:
        return {"success": False, "error": str(e)}


