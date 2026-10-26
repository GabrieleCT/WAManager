import datetime
import logging
import re
import requests
from django.utils import timezone
from .models import GoogleContactsConfig, GoogleContactsSyncLog, Allievo, Scuola, Corso

logger = logging.getLogger(__name__)


def normalize_phone(phone_str):
    """Normalizza il numero di telefono estraendo solo le cifre significative."""
    if not phone_str:
        return ''
    digits = re.sub(r'\D', '', str(phone_str))
    # Se ha prefisso italiano 39 con 12 cifre, togli 39
    if digits.startswith('39') and len(digits) >= 12:
        digits = digits[2:]
    # Se ha zeri iniziali es. 0039
    elif digits.startswith('0039') and len(digits) >= 14:
        digits = digits[4:]
    return digits[-10:] if len(digits) >= 10 else digits


def get_valid_contacts_access_token():
    """
    Restituisce un access_token valido per Google Contacts (People API).
    Se il token attuale è scaduto o prossimo alla scadenza, esegue il refresh automatico
    tramite l'endpoint OAuth 2.0 di Google.
    """
    config = GoogleContactsConfig.get_instance()
    if not config.refresh_token:
        return None, "Nessun account Google Contacts collegato via OAuth 2.0"

    access_token = config.access_token
    now = timezone.now()

    # Controlla se il token deve essere rinnovato (scaduto o scade entro 60 secondi)
    need_refresh = (
        not access_token or
        not config.token_expiry or
        config.token_expiry <= now + datetime.timedelta(seconds=60)
    )

    if need_refresh:
        token_url = 'https://oauth2.googleapis.com/token'
        payload = {
            'client_id': config.client_id,
            'client_secret': config.client_secret,
            'refresh_token': config.refresh_token,
            'grant_type': 'refresh_token'
        }
        try:
            resp = requests.post(token_url, data=payload, timeout=15)
            if resp.status_code == 200:
                t_data = resp.json()
                access_token = t_data.get('access_token')
                expires_in = t_data.get('expires_in', 3600)
                config.access_token = access_token
                config.token_expiry = now + datetime.timedelta(seconds=expires_in)
                config.save(update_fields=['access_token', 'token_expiry'])
                logger.info("Access token Google Contacts rinnovato con successo.")
            else:
                err_msg = resp.text
                logger.error(f"Errore rinnovo token Google Contacts: {err_msg}")
                return None, f"Errore rinnovo token Google: {err_msg}"
        except Exception as e:
            logger.error(f"Eccezione rinnovo token Google Contacts: {str(e)}")
            return None, f"Eccezione connessione Google: {str(e)}"

    return access_token, None


def is_allievo_donna(allievo):
    """
    Determina se l'allievo/prospect è donna:
    - Controllo sul nome proprio (nomi femminili o maschili tipici italiani)
    - Se ambiguo o neutro, fa fede il ruolo di ballo (follower = donna, leader = uomo)
    """
    maschili_in_a = {
        'andrea', 'luca', 'nicola', 'mattia', 'elia', 'gianluca',
        'gianandrea', 'pierluca', 'tobia', 'sasha', 'battista', 'damiano'
    }
    femminili_non_a = {
        'alice', 'beatrice', 'carmen', 'irene', 'noemi', 'rachele',
        'nicole', 'adele', 'miriam', 'matilde', 'cleo', 'iris',
        'ester', 'agnes', 'agnese', 'chloe', 'zoe'
    }

    first_name = (allievo.nome or '').strip().split()[0].lower() if allievo.nome else ''

    if first_name in femminili_non_a:
        return True
    if first_name in maschili_in_a:
        return False
    if first_name.endswith('a'):
        return True
    if first_name.endswith(('o', 'i')):
        return False

    ruolo = (allievo.ruolo or '').lower()
    if ruolo == 'follower':
        return True

    return False


def remove_potenziale_from_note(note_str: str) -> str:
    """
    Rimuove la parola 'potenziale' (o 'potenziali') dal testo delle note,
    lasciando inalterato il resto del contenuto.
    """
    if not note_str:
        return ""
    cleaned = re.sub(r'\bpotenzial[ei]\b', '', note_str, flags=re.IGNORECASE)
    cleaned = re.sub(r'[ \t]+', ' ', cleaned).strip()
    cleaned = re.sub(r'^[,\-–—\s]+', '', cleaned).strip()
    cleaned = re.sub(r'[,\-–—\s]+$', '', cleaned).strip()
    if cleaned and cleaned[0].islower():
        cleaned = cleaned[0].upper() + cleaned[1:]
    return cleaned


def build_contact_note(allievo):
    """
    Costruisce il campo note per Google Contacts:
    - Se donna: "Allieva <nome_scuola>" oppure "Potenziale Allieva <nome_scuola>"
    - Se uomo: "Allievo <nome_scuola>" oppure "Potenziale Allievo <nome_scuola>"
    """
    scuola_nome = ''
    if allievo.corso_id:
        try:
            c = Corso.objects.select_related('scuola').filter(id=allievo.corso_id).first()
            if c and c.scuola and c.scuola.nome:
                scuola_nome = c.scuola.nome.strip()
        except Exception:
            pass
    elif allievo.corso and allievo.corso.scuola and allievo.corso.scuola.nome:
        scuola_nome = allievo.corso.scuola.nome.strip()
    else:
        prima_scuola = Scuola.objects.first()
        if prima_scuola and prima_scuola.nome:
            scuola_nome = prima_scuola.nome.strip()

    scuola_suffix = f" {scuola_nome}" if scuola_nome else ""
    is_donna = is_allievo_donna(allievo)

    if allievo.is_prospect:
        titolo = "Potenziale Allieva" if is_donna else "Potenziale Allievo"
    else:
        titolo = "Allieva" if is_donna else "Allievo"

    return f"{titolo}{scuola_suffix}".strip()


def sync_allievo_to_google_contacts(allievo, clean_potenziale=False):
    """
    Crea o aggiorna il contatto per l'allievo/prospect nella rubrica di Google Contacts.
    - Nome e Cognome
    - Telefono
    - Email (se presente)
    - Note: 'Allievo <nome_scuola>' oppure 'Allieva <nome_scuola>'...
    """
    config = GoogleContactsConfig.get_instance()
    if not config.is_connected or not config.is_active:
        return {
            'success': False,
            'skipped': True,
            'message': 'Integrazione Google Contacts non configurata o disattivata.'
        }

    access_token, err = get_valid_contacts_access_token()
    if not access_token:
        return {'success': False, 'error': err}

    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }

    names_payload = [{
        'givenName': allievo.nome.strip(),
        'familyName': allievo.cognome.strip(),
    }]

    phones_payload = []
    if allievo.telefono and allievo.telefono.strip():
        phones_payload.append({
            'value': allievo.telefono.strip(),
            'type': 'mobile'
        })

    emails_payload = []
    if allievo.email and allievo.email.strip():
        emails_payload.append({
            'value': allievo.email.strip(),
            'type': 'home'
        })

    # Se l'allievo non ha google_contact_id registrato, cerca se esiste già su Google Contacts
    if not allievo.google_contact_id:
        target_phone = normalize_phone(allievo.telefono) if getattr(allievo, 'telefono', None) else None
        target_name = f"{getattr(allievo, 'nome', '')} {getattr(allievo, 'cognome', '')}".strip().lower()
        if target_phone or target_name:
            try:
                connections, _ = fetch_google_contacts_connections(access_token)
                if connections:
                    for c in connections:
                        r_name = c.get('resource_name')
                        c_phone = normalize_phone(c.get('phone', ''))
                        if target_phone and c_phone and (c_phone == target_phone or c_phone.endswith(target_phone) or target_phone.endswith(c_phone)):
                            allievo.google_contact_id = r_name
                            allievo.save(update_fields=['google_contact_id'])
                            break
                        c_name = f"{c.get('given_name', '')} {c.get('family_name', '')}".strip().lower()
                        c_display = c.get('display_name', '').strip().lower()
                        if target_name and (target_name == c_name or target_name == c_display):
                            allievo.google_contact_id = r_name
                            allievo.save(update_fields=['google_contact_id'])
                            break
            except Exception as e:
                logger.warning(f"Errore ricerca contatto Google pre-esistente per sync: {e}")

    # Se l'allievo ha già un resourceName Google salvato, prova ad aggiornarlo
    if allievo.google_contact_id:
        try:
            get_url = f"https://people.googleapis.com/v1/{allievo.google_contact_id}?personFields=names,phoneNumbers,emailAddresses,biographies"
            get_resp = requests.get(get_url, headers=headers, timeout=15)

            if get_resp.status_code == 200:
                contact_data = get_resp.json()
                etag = contact_data.get('etag')

                existing_bios = contact_data.get('biographies', [])
                existing_note = existing_bios[0].get('value', '').strip() if existing_bios else ''

                # Se richiesto o se l'allievo non è prospect e la nota contiene 'potenziale'
                if (clean_potenziale or not allievo.is_prospect) and existing_note and re.search(r'\bpotenzial[ei]\b', existing_note, flags=re.IGNORECASE):
                    cleaned_note = remove_potenziale_from_note(existing_note)
                    note_to_use = cleaned_note if cleaned_note else build_contact_note(allievo)
                elif existing_note:
                    note_to_use = existing_note
                else:
                    note_to_use = build_contact_note(allievo)

                biographies_payload = [{
                    'value': note_to_use,
                    'contentType': 'TEXT_PLAIN'
                }]

                update_url = f"https://people.googleapis.com/v1/{allievo.google_contact_id}:updateContact?updatePersonFields=names,phoneNumbers,emailAddresses,biographies"
                update_body = {
                    'etag': etag,
                    'names': names_payload,
                    'phoneNumbers': phones_payload,
                    'emailAddresses': emails_payload,
                    'biographies': biographies_payload
                }
                upd_resp = requests.patch(update_url, headers=headers, json=update_body, timeout=15)
                if upd_resp.status_code == 200:
                    config.last_sync_at = timezone.now()
                    config.save(update_fields=['last_sync_at'])
                    logger.info(f"Contatto Google aggiornato per {allievo.nome} {allievo.cognome} ({allievo.google_contact_id}) con nota '{note_to_use}'")
                    return {
                        'success': True,
                        'action': 'updated',
                        'resource_name': allievo.google_contact_id,
                        'note': note_to_use,
                        'message': f"Contatto '{allievo.nome} {allievo.cognome}' aggiornato in Google Contacts con nota '{note_to_use}'."
                    }
                else:
                    err_data = upd_resp.json() if upd_resp.headers.get('content-type', '').startswith('application/json') else {}
                    err_msg = err_data.get('error', {}).get('message') or upd_resp.text
                    logger.warning(f"Errore update contatto Google ({upd_resp.status_code}): {err_msg}")
                    return {
                        'success': False,
                        'error': f"Errore Google People API ({upd_resp.status_code}): {err_msg}"
                    }
            elif get_resp.status_code == 404:
                allievo.google_contact_id = ''
                allievo.save(update_fields=['google_contact_id'])
            else:
                err_data = get_resp.json() if get_resp.headers.get('content-type', '').startswith('application/json') else {}
                err_msg = err_data.get('error', {}).get('message') or get_resp.text
                logger.warning(f"Errore recupero contatto Google ({get_resp.status_code}): {err_msg}")
                return {
                    'success': False,
                    'error': f"Errore Google People API ({get_resp.status_code}): {err_msg}"
                }
        except Exception as e:
            logger.error(f"Eccezione aggiornamento contatto Google: {str(e)}")
            return {'success': False, 'error': f"Eccezione aggiornamento Google Contacts: {str(e)}"}

    # Creazione nuovo contatto
    note_to_use = build_contact_note(allievo)
    if (clean_potenziale or not allievo.is_prospect) and re.search(r'\bpotenzial[ei]\b', note_to_use, flags=re.IGNORECASE):
        note_to_use = remove_potenziale_from_note(note_to_use) or note_to_use

    biographies_payload = [{
        'value': note_to_use,
        'contentType': 'TEXT_PLAIN'
    }]

    # Creazione nuovo contatto
    try:
        create_url = "https://people.googleapis.com/v1/people:createContact"
        create_body = {
            'names': names_payload,
            'phoneNumbers': phones_payload,
            'emailAddresses': emails_payload,
            'biographies': biographies_payload
        }
        create_resp = requests.post(create_url, headers=headers, json=create_body, timeout=15)

        if create_resp.status_code == 200:
            created_data = create_resp.json()
            resource_name = created_data.get('resourceName', '')
            allievo.google_contact_id = resource_name
            allievo.save(update_fields=['google_contact_id'])

            config.last_sync_at = timezone.now()
            config.save(update_fields=['last_sync_at'])
            logger.info(f"Contatto Google creato per {allievo.nome} {allievo.cognome} ({resource_name}) con nota '{note_text}'")

            return {
                'success': True,
                'action': 'created',
                'resource_name': resource_name,
                'note': note_text,
                'message': f"Contatto '{allievo.nome} {allievo.cognome}' creato in Google Contacts con nota '{note_text}'."
            }
        else:
            err_data = create_resp.json() if create_resp.headers.get('content-type', '').startswith('application/json') else {}
            err_msg = err_data.get('error', {}).get('message') or create_resp.text
            logger.error(f"Errore creazione contatto Google ({create_resp.status_code}): {err_msg}")
            return {
                'success': False,
                'error': f"Errore Google People API ({create_resp.status_code}): {err_msg}"
            }
    except Exception as e:
        logger.error(f"Eccezione creazione contatto Google: {str(e)}")
        return {'success': False, 'error': f"Eccezione chiamata Google Contacts: {str(e)}"}


def delete_google_contact(google_contact_id):
    """
    Elimina il contatto dalla rubrica di Google Contacts (People API).
    """
    if not google_contact_id or not str(google_contact_id).strip():
        return {'success': True, 'skipped': True, 'message': 'Nessun ID contatto Google.'}

    config = GoogleContactsConfig.get_instance()
    if not config.is_connected or not config.is_active:
        return {'success': False, 'skipped': True, 'message': 'Google Contacts non configurato o disattivato.'}

    access_token, err = get_valid_contacts_access_token()
    if not access_token:
        return {'success': False, 'error': err}

    headers = {
        'Authorization': f'Bearer {access_token}',
    }

    try:
        delete_url = f"https://people.googleapis.com/v1/{google_contact_id}:deleteContact"
        resp = requests.delete(delete_url, headers=headers, timeout=15)

        if resp.status_code in (200, 204, 404):
            config.last_sync_at = timezone.now()
            config.save(update_fields=['last_sync_at'])
            logger.info(f"Contatto Google {google_contact_id} eliminato con successo.")
            return {'success': True, 'message': f'Contatto {google_contact_id} eliminato da Google Contacts.'}
        else:
            err_data = resp.json() if resp.headers.get('content-type', '').startswith('application/json') else {}
            err_msg = err_data.get('error', {}).get('message') or resp.text
            logger.warning(f"Errore eliminazione contatto Google ({resp.status_code}): {err_msg}")
            return {'success': False, 'error': f"Errore Google People API ({resp.status_code}): {err_msg}"}
    except Exception as e:
        logger.error(f"Eccezione eliminazione contatto Google: {str(e)}")
        return {'success': False, 'error': f"Eccezione Google Contacts: {str(e)}"}


def delete_google_contact_for_allievo(allievo):
    """
    Elimina il contatto dalla rubrica di Google Contacts.
    Se l'allievo ha google_contact_id registrato, lo elimina direttamente.
    Se non ha google_contact_id, ricerca il contatto su Google Contacts tramite
    telefono o nome che abbia nelle note 'allievo' o 'allieva' e lo rimuove.
    """
    if getattr(allievo, 'google_contact_id', None):
        return delete_google_contact(allievo.google_contact_id)

    # Ricerca di fallback per telefono o nome
    target_phone = normalize_phone(allievo.telefono) if getattr(allievo, 'telefono', None) else None
    target_name = f"{getattr(allievo, 'nome', '')} {getattr(allievo, 'cognome', '')}".strip().lower()

    if not target_phone and not target_name:
        return {'success': True, 'skipped': True, 'message': 'Nessun identificativo per la ricerca Google.'}

    try:
        connections, err = fetch_google_contacts_connections()
        if not connections:
            return {'success': True, 'skipped': True, 'message': f'Nessun contatto Google o errore: {err}'}

        for c in connections:
            r_name = c.get('resourceName')
            # 1. Match sul telefono
            phones = [normalize_phone(p.get('value', '')) for p in c.get('phoneNumbers', [])]
            if target_phone and any(p and (p == target_phone or p.endswith(target_phone) or target_phone.endswith(p)) for p in phones):
                logger.info(f"Contatto Google trovato per telefono ({target_phone}): {r_name}. Procedo con eliminazione.")
                return delete_google_contact(r_name)

            # 2. Match sul nome completo
            names = [n.get('displayName', '').strip().lower() for n in c.get('names', [])]
            if target_name and target_name in names:
                logger.info(f"Contatto Google trovato per nome ({target_name}): {r_name}. Procedo con eliminazione.")
                return delete_google_contact(r_name)

        return {'success': True, 'skipped': True, 'message': 'Contatto non presente nella Rubrica Google.'}
    except Exception as e:
        logger.error(f"Errore ricerca contatto Google per eliminazione: {e}")
        return {'success': False, 'error': str(e)}


def fetch_google_contacts_connections(access_token=None):
    """
    Recupera tutti i contatti da Google Contacts gestendo la paginazione di Google People API.
    Filtra ESCLUSIVAMENTE i contatti che contengono nel campo Note ("biographies")
    le parole chiave "allievo" o "allieva" (case-insensitive).
    """
    if not access_token:
        access_token, err = get_valid_contacts_access_token()
        if not access_token:
            return None, err

    headers = {'Authorization': f'Bearer {access_token}'}
    base_url = 'https://people.googleapis.com/v1/people/me/connections'
    params = {
        'personFields': 'names,phoneNumbers,emailAddresses,biographies,metadata',
        'pageSize': 200,
    }

    filtered_contacts = []
    page_token = None
    total_fetched = 0

    while True:
        req_params = dict(params)
        if page_token:
            req_params['pageToken'] = page_token

        try:
            resp = requests.get(base_url, headers=headers, params=req_params, timeout=20)
            if resp.status_code != 200:
                err_data = resp.json() if resp.headers.get('content-type', '').startswith('application/json') else {}
                err_msg = err_data.get('error', {}).get('message') or resp.text
                return None, f"Errore People API ({resp.status_code}): {err_msg}"

            data = resp.json()
            connections = data.get('connections', [])
            total_fetched += len(connections)

            for person in connections:
                resource_name = person.get('resourceName', '')
                etag = person.get('etag', '')

                # Estrazione Note (biographies)
                biographies = person.get('biographies', [])
                note_text = ' '.join(b.get('value', '') for b in biographies).strip()
                note_lower = note_text.lower()

                # Filtro obbligatorio: contiene 'allievo' oppure 'allieva'
                if 'allievo' not in note_lower and 'allieva' not in note_lower:
                    continue

                # Estrazione Nomi
                names = person.get('names', [])
                given_name = ''
                family_name = ''
                display_name = ''
                if names:
                    n = names[0]
                    given_name = n.get('givenName', '').strip()
                    family_name = n.get('familyName', '').strip()
                    display_name = n.get('displayName', '').strip()
                    if not given_name and display_name:
                        parts = display_name.split(' ', 1)
                        given_name = parts[0]
                        family_name = parts[1] if len(parts) > 1 else ''

                # Estrazione Telefono
                phones = person.get('phoneNumbers', [])
                phone_val = phones[0].get('value', '').strip() if phones else ''

                # Estrazione Email
                emails = person.get('emailAddresses', [])
                email_val = emails[0].get('value', '').strip() if emails else ''

                # Estrazione Data Ultima Modifica Google
                update_time = None
                metadata = person.get('metadata', {})
                sources = metadata.get('sources', [])
                for s in sources:
                    if s.get('type') == 'CONTACT' and s.get('updateTime'):
                        update_time = s.get('updateTime')
                        break

                filtered_contacts.append({
                    'resource_name': resource_name,
                    'etag': etag,
                    'given_name': given_name,
                    'family_name': family_name,
                    'display_name': display_name or f"{given_name} {family_name}".strip(),
                    'phone': phone_val,
                    'email': email_val,
                    'note': note_text,
                    'update_time': update_time,
                })

            page_token = data.get('nextPageToken')
            if not page_token:
                break
        except Exception as e:
            logger.error(f"Eccezione fetch_google_contacts_connections: {e}")
            return None, str(e)

    logger.info(f"Google Contacts: scaricati {total_fetched} contatti totali, trovati {len(filtered_contacts)} con nota allievo/allieva.")
    return filtered_contacts, None


def get_contacts_comparison_report():
    """
    Costruisce la tabella di confronto tra Gestionale e Google Contacts.
    - Prospect del sistema
    - Allievi del sistema
    - Contatti Google con note 'allievo' o 'allieva'

    Determina lo stato:
    - 'synced' (Sincronizzato)
    - 'modified_system' (Modificato nel sistema)
    - 'modified_google' (Modificato su Google)
    - 'only_system' (Presente solo nel sistema)
    - 'only_google' (Presente solo su Google)
    """
    config = GoogleContactsConfig.get_instance()
    if not config.is_connected:
        return {
            'connected': False,
            'message': 'Account Google Contacts non collegato via OAuth 2.0.',
            'last_sync_at': config.last_sync_at.isoformat() if config.last_sync_at else None,
            'last_sync_status': config.last_sync_status or 'not_connected',
            'last_sync_summary': config.last_sync_summary,
            'stats': {'total': 0, 'synced': 0, 'modified_system': 0, 'modified_google': 0, 'only_system': 0, 'only_google': 0},
            'records': []
        }

    access_token, err = get_valid_contacts_access_token()
    if not access_token:
        return {
            'connected': False,
            'message': err or 'Impossibile ottenere token di accesso Google Contacts.',
            'last_sync_at': config.last_sync_at.isoformat() if config.last_sync_at else None,
            'last_sync_status': 'error',
            'last_sync_summary': err,
            'stats': {'total': 0, 'synced': 0, 'modified_system': 0, 'modified_google': 0, 'only_system': 0, 'only_google': 0},
            'records': []
        }

    google_contacts, g_err = fetch_google_contacts_connections(access_token)
    if google_contacts is None:
        return {
            'connected': True,
            'error': g_err,
            'message': f"Errore recupero contatti Google: {g_err}",
            'last_sync_at': config.last_sync_at.isoformat() if config.last_sync_at else None,
            'last_sync_status': 'error',
            'last_sync_summary': g_err,
            'stats': {'total': 0, 'synced': 0, 'modified_system': 0, 'modified_google': 0, 'only_system': 0, 'only_google': 0},
            'records': []
        }

    allievi = list(Allievo.objects.select_related('corso', 'corso__scuola').all())

    # Indicizzazione contatti Google
    google_by_id = {c['resource_name']: c for c in google_contacts if c.get('resource_name')}
    google_by_phone = {}
    for c in google_contacts:
        np = normalize_phone(c.get('phone'))
        if np and len(np) >= 7:
            google_by_phone[np] = c

    google_by_name = {}
    for c in google_contacts:
        gn = (c.get('given_name') or '').strip().lower()
        fn = (c.get('family_name') or '').strip().lower()
        if gn and fn:
            google_by_name[f"{gn} {fn}"] = c

    matched_google_ids = set()
    records = []

    # 1. Analisi record presenti nel Sistema
    for a in allievi:
        expected_note = build_contact_note(a)
        sys_phone = a.telefono.strip() if a.telefono else ''
        sys_norm_phone = normalize_phone(sys_phone)
        sys_email = (a.email or '').strip()

        # Match primario per ID
        g_match = None
        if a.google_contact_id and a.google_contact_id in google_by_id:
            g_match = google_by_id[a.google_contact_id]
        elif sys_norm_phone and sys_norm_phone in google_by_phone:
            candidate = google_by_phone[sys_norm_phone]
            if candidate['resource_name'] not in matched_google_ids:
                g_match = candidate
        elif a.nome and a.cognome:
            name_key = f"{a.nome.strip().lower()} {a.cognome.strip().lower()}"
            if name_key in google_by_name:
                candidate = google_by_name[name_key]
                if candidate['resource_name'] not in matched_google_ids:
                    g_match = candidate

        system_data = {
            'id': str(a.id),
            'nome': a.nome.strip(),
            'cognome': a.cognome.strip(),
            'telefono': sys_phone,
            'email': sys_email,
            'note': expected_note,
            'is_prospect': a.is_prospect,
            'scuola_nome': a.corso.scuola.nome if a.corso and a.corso.scuola else '',
            'corso_descrizione': str(a.corso) if a.corso else 'Nessun corso',
            'updated_at': a.updated_at.isoformat() if a.updated_at else None,
        }

        if g_match:
            matched_google_ids.add(g_match['resource_name'])
            g_phone = g_match.get('phone', '').strip()
            g_email = g_match.get('email', '').strip()
            g_note = g_match.get('note', '').strip()
            g_given = g_match.get('given_name', '').strip()
            g_family = g_match.get('family_name', '').strip()

            google_data = {
                'resource_name': g_match['resource_name'],
                'etag': g_match.get('etag', ''),
                'nome': g_given,
                'cognome': g_family,
                'telefono': g_phone,
                'email': g_email,
                'note': g_note,
                'update_time': g_match.get('update_time'),
            }

            # Confronto campi
            diffs = []
            if a.nome.strip().lower() != g_given.lower():
                diffs.append('nome')
            if a.cognome.strip().lower() != g_family.lower():
                diffs.append('cognome')
            if sys_norm_phone != normalize_phone(g_phone):
                diffs.append('telefono')
            if sys_email.lower() != g_email.lower() and (sys_email or g_email):
                diffs.append('email')
            if expected_note.strip().lower() != g_note.lower():
                diffs.append('note')

            if not diffs:
                status = 'synced'
                action = 'none'
            else:
                # Determina se modificato nel sistema o su Google in base a timestamp
                sys_dt = a.updated_at
                g_dt = None
                if g_match.get('update_time'):
                    try:
                        iso_clean = g_match['update_time'].replace('Z', '+00:00')
                        g_dt = datetime.datetime.fromisoformat(iso_clean)
                    except Exception:
                        pass

                if sys_dt and g_dt:
                    if sys_dt > g_dt + datetime.timedelta(seconds=5):
                        status = 'modified_system'
                        action = 'aggiorna_google'
                    else:
                        status = 'modified_google'
                        action = 'aggiorna_sistema'
                else:
                    status = 'modified_system'
                    action = 'aggiorna_google'

            records.append({
                'system_id': str(a.id),
                'google_id': g_match['resource_name'],
                'nome': a.nome.strip(),
                'cognome': a.cognome.strip(),
                'telefono': sys_phone or g_phone,
                'email': sys_email or g_email,
                'is_prospect': a.is_prospect,
                'status': status,
                'action': action,
                'differences': diffs,
                'system_data': system_data,
                'google_data': google_data,
            })
        else:
            # Presente solo nel sistema
            records.append({
                'system_id': str(a.id),
                'google_id': a.google_contact_id or '',
                'nome': a.nome.strip(),
                'cognome': a.cognome.strip(),
                'telefono': sys_phone,
                'email': sys_email,
                'is_prospect': a.is_prospect,
                'status': 'only_system',
                'action': 'crea_google',
                'differences': ['tutti'],
                'system_data': system_data,
                'google_data': None,
            })

    # 2. Contatti presenti solo su Google (con nota allievo/allieva ma non nel gestionale)
    for g_contact in google_contacts:
        r_name = g_contact['resource_name']
        if r_name in matched_google_ids:
            continue

        g_given = g_contact.get('given_name', '').strip()
        g_family = g_contact.get('family_name', '').strip()
        g_phone = g_contact.get('phone', '').strip()
        g_email = g_contact.get('email', '').strip()
        g_note = g_contact.get('note', '').strip()
        is_potenziale = 'potenziale' in g_note.lower() or 'prospect' in g_note.lower()

        google_data = {
            'resource_name': r_name,
            'etag': g_contact.get('etag', ''),
            'nome': g_given,
            'cognome': g_family,
            'telefono': g_phone,
            'email': g_email,
            'note': g_note,
            'update_time': g_contact.get('update_time'),
        }

        records.append({
            'system_id': None,
            'google_id': r_name,
            'nome': g_given or '(Senza nome)',
            'cognome': g_family or '',
            'telefono': g_phone,
            'email': g_email,
            'is_prospect': is_potenziale,
            'status': 'only_google',
            'action': 'importa_sistema',
            'differences': ['tutti'],
            'system_data': None,
            'google_data': google_data,
        })

    # Ordinamento alfabetico per cognome, nome
    records.sort(key=lambda r: (r['cognome'].lower(), r['nome'].lower()))

    stats = {
        'total': len(records),
        'synced': sum(1 for r in records if r['status'] == 'synced'),
        'modified_system': sum(1 for r in records if r['status'] == 'modified_system'),
        'modified_google': sum(1 for r in records if r['status'] == 'modified_google'),
        'only_system': sum(1 for r in records if r['status'] == 'only_system'),
        'only_google': sum(1 for r in records if r['status'] == 'only_google'),
    }

    return {
        'connected': True,
        'user_email': config.user_email,
        'last_sync_at': config.last_sync_at.isoformat() if config.last_sync_at else None,
        'last_sync_status': config.last_sync_status or 'success',
        'last_sync_summary': config.last_sync_summary,
        'stats': stats,
        'records': records,
    }


def pull_google_to_system(allievo_id, google_resource_name=None):
    """
    Aggiorna il record di sistema con i dati presenti in Google Contacts.
    """
    allievo = Allievo.objects.filter(id=allievo_id).first()
    if not allievo:
        return {'success': False, 'error': f"Allievo {allievo_id} non trovato."}

    res_name = google_resource_name or allievo.google_contact_id
    if not res_name:
        return {'success': False, 'error': "Nessun Google Contact ID specificato per questo allievo."}

    access_token, err = get_valid_contacts_access_token()
    if not access_token:
        return {'success': False, 'error': err}

    headers = {'Authorization': f'Bearer {access_token}'}
    try:
        url = f"https://people.googleapis.com/v1/{res_name}?personFields=names,phoneNumbers,emailAddresses,biographies"
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code != 200:
            return {'success': False, 'error': f"Errore recupero contatto Google ({resp.status_code}): {resp.text}"}

        p_data = resp.json()
        names = p_data.get('names', [])
        if names:
            gn = names[0].get('givenName', '').strip()
            fn = names[0].get('familyName', '').strip()
            if gn:
                allievo.nome = gn
            if fn:
                allievo.cognome = fn

        phones = p_data.get('phoneNumbers', [])
        if phones:
            allievo.telefono = phones[0].get('value', '').strip()

        emails = p_data.get('emailAddresses', [])
        if emails:
            allievo.email = emails[0].get('value', '').strip()

        allievo.google_contact_id = res_name
        allievo.save()

        # Registra log
        GoogleContactsSyncLog.objects.create(
            status='success',
            action='pull_from_google',
            details=f"Allievo '{allievo.nome} {allievo.cognome}' aggiornato dai dati di Google Contacts.",
            items_updated=1
        )

        return {'success': True, 'message': f"Allievo '{allievo.nome} {allievo.cognome}' aggiornato dal contatto Google."}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def import_google_contact_to_system(google_resource_name, as_prospect=None, corso_id=None):
    """
    Crea un nuovo Prospect o Allievo nel sistema utilizzando i dati del contatto Google.
    Garantisce idempotenza ed evita duplicati.
    """
    if not google_resource_name:
        return {'success': False, 'error': 'Google Resource Name obbligatorio.'}

    # Verifica se esiste già un allievo con questo google_contact_id
    existing = Allievo.objects.filter(google_contact_id=google_resource_name).first()
    if existing:
        return {
            'success': True,
            'action': 'already_exists',
            'allievo_id': str(existing.id),
            'message': f"L'allievo '{existing.nome} {existing.cognome}' è già associato a questo contatto Google."
        }

    access_token, err = get_valid_contacts_access_token()
    if not access_token:
        return {'success': False, 'error': err}

    headers = {'Authorization': f'Bearer {access_token}'}
    try:
        url = f"https://people.googleapis.com/v1/{google_resource_name}?personFields=names,phoneNumbers,emailAddresses,biographies"
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code != 200:
            return {'success': False, 'error': f"Errore recupero contatto Google ({resp.status_code}): {resp.text}"}

        p_data = resp.json()
        names = p_data.get('names', [])
        given_name = ''
        family_name = ''
        if names:
            given_name = names[0].get('givenName', '').strip()
            family_name = names[0].get('familyName', '').strip()
            if not given_name:
                disp = names[0].get('displayName', '').strip()
                parts = disp.split(' ', 1)
                given_name = parts[0]
                family_name = parts[1] if len(parts) > 1 else ''

        if not given_name and not family_name:
            given_name = 'Contatto Google'
            family_name = google_resource_name.split('/')[-1]

        phones = p_data.get('phoneNumbers', [])
        phone_val = phones[0].get('value', '').strip() if phones else ''

        emails = p_data.get('emailAddresses', [])
        email_val = emails[0].get('value', '').strip() if emails else ''

        biographies = p_data.get('biographies', [])
        note_text = ' '.join(b.get('value', '') for b in biographies).strip()

        # Determina is_prospect se non specificato esplicitamente
        if as_prospect is None:
            as_prospect = ('potenziale' in note_text.lower() or 'prospect' in note_text.lower())

        # Ruolo dedotto: se la nota ha allieva o il nome è femminile, follower, altrimenti leader
        is_female = ('allieva' in note_text.lower())
        if not is_female and given_name.lower().endswith('a') and given_name.lower() not in {'andrea', 'luca', 'mattia', 'nicola', 'elia'}:
            is_female = True
        ruolo = 'follower' if is_female else 'leader'

        corso = None
        if corso_id:
            corso = Corso.objects.filter(id=corso_id).first()

        new_allievo = Allievo.objects.create(
            nome=given_name,
            cognome=family_name,
            telefono=phone_val,
            email=email_val,
            is_prospect=as_prospect,
            ruolo=ruolo,
            corso=corso,
            note=note_text,
            google_contact_id=google_resource_name
        )

        GoogleContactsSyncLog.objects.create(
            status='success',
            action='import_allievo',
            details=f"Importato { 'Prospect' if as_prospect else 'Allievo' } '{given_name} {family_name}' da Google Contacts.",
            items_created=1
        )

        return {
            'success': True,
            'action': 'imported',
            'allievo_id': str(new_allievo.id),
            'message': f"Importato con successo '{given_name} {family_name}' ({'Prospect' if as_prospect else 'Allievo'})."
        }
    except Exception as e:
        return {'success': False, 'error': str(e)}


def run_full_sync():
    """
    Esegue la sincronizzazione globale completa tra il Sistema e Google Contacts:
    1. Per i record 'only_system' e 'modified_system': invia e aggiorna su Google.
    2. Per i record 'modified_google': aggiorna i dati nel sistema.
    3. Aggiorna lo stato, il timestamp e registra il log dell'operazione.
    """
    config = GoogleContactsConfig.get_instance()
    config.last_sync_status = 'in_progress'
    config.save(update_fields=['last_sync_status'])

    report = get_contacts_comparison_report()
    if not report.get('connected') or report.get('error'):
        err = report.get('error') or report.get('message') or 'Google Contacts non raggiungibile.'
        config.last_sync_status = 'error'
        config.last_sync_summary = f"Sincronizzazione fallita: {err}"
        config.save(update_fields=['last_sync_status', 'last_sync_summary'])
        GoogleContactsSyncLog.objects.create(
            status='error',
            action='bulk_sync',
            details=err,
            errors_count=1
        )
        return {'success': False, 'error': err}

    records = report.get('records', [])
    created = 0
    updated = 0
    errors = []

    for r in records:
        status = r['status']
        sys_id = r.get('system_id')
        g_id = r.get('google_id')

        # 1. Da Sistema a Google
        if status in ('only_system', 'modified_system') and sys_id:
            allievo = Allievo.objects.filter(id=sys_id).first()
            if allievo:
                res = sync_allievo_to_google_contacts(allievo)
                if res.get('success'):
                    if res.get('action') == 'created':
                        created += 1
                    else:
                        updated += 1
                else:
                    errors.append(f"{allievo.nome} {allievo.cognome}: {res.get('error')}")

        # 2. Da Google a Sistema
        elif status == 'modified_google' and sys_id:
            res = pull_google_to_system(sys_id, g_id)
            if res.get('success'):
                updated += 1
            else:
                errors.append(f"{r['nome']} {r['cognome']}: {res.get('error')}")

    now = timezone.now()
    summary = f"Sincronizzazione completata: {created} creati su Google, {updated} aggiornati, {len(errors)} errori."
    config.last_sync_at = now
    config.last_sync_status = 'success' if not errors else ('partial' if (created or updated) else 'error')
    config.last_sync_summary = summary
    config.save(update_fields=['last_sync_at', 'last_sync_status', 'last_sync_summary'])

    GoogleContactsSyncLog.objects.create(
        status=config.last_sync_status,
        action='bulk_sync',
        details=summary + (f" Errori: {'; '.join(errors[:5])}" if errors else ""),
        items_created=created,
        items_updated=updated,
        errors_count=len(errors)
    )

    return {
        'success': len(errors) == 0,
        'status': config.last_sync_status,
        'summary': summary,
        'created': created,
        'updated': updated,
        'errors_count': len(errors),
        'errors': errors[:10]
    }
