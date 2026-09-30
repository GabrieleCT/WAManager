import os
import requests

GATEWAY_BASE = os.environ.get("GATEWAY_BASE_URL", "http://localhost:4002")
GATEWAY_URL = os.environ.get("GATEWAY_URL", f"{GATEWAY_BASE}/api/send")

def send_whatsapp_message(to: str, message: str, is_group: bool = True, is_poll: bool = False, poll_options: list = None) -> dict:
    """
    Invia un messaggio o sondaggio a WhatsApp tramite il gateway Node.js locale.
    """
    if poll_options is None:
        poll_options = []
        
    payload = {
        "to": to,
        "message": message,
        "isGroup": is_group,
        "isPoll": is_poll,
        "pollOptions": poll_options
    }
    
    try:
        response = requests.post(GATEWAY_URL, json=payload, timeout=15)
        response.raise_for_status()
        return {"success": True, "response": response.json()}
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
