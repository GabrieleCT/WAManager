import urllib.request
import json
import time

messages = [
    ('120363413142077023@g.us', '393462388507@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '393357462477@s.whatsapp.net', 'Buongiorno presente!'),
    ('120363413761223316@g.us', '393473389154@s.whatsapp.net', 'Presente \U0001f601'),
    ('120363413761223316@g.us', '393357275908@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '393498121417@s.whatsapp.net', 'Buongiorno ci sono'),
    ('120363413142077023@g.us', '393468007656@s.whatsapp.net', 'Presente'),
    ('120363413142077023@g.us', '393346673495@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '39335470519@s.whatsapp.net', 'Presente'),
    ('120363413761223316@g.us', '393461786973@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '393280946683@s.whatsapp.net', 'Assente.'),
    ('120363413761223316@g.us', '393451711691@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '39335226434@s.whatsapp.net', 'Assente'),
    ('120363413761223316@g.us', '393405966826@s.whatsapp.net', 'Presente'),
    ('120363413142077023@g.us', '393289165320@s.whatsapp.net', 'Presente'),
    ('120363413761223316@g.us', '393313256357@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '39335250018@s.whatsapp.net', 'Presente'),
    ('120363429231746469@g.us', '393349084699@s.whatsapp.net', 'Presente'),
    ('120363413142077023@g.us', '393393834326@s.whatsapp.net', 'Presente x 2'),
]

url = 'http://80.211.58.251:8000/api/webhook/whatsapp-message/'

print(f"Inizio inoltro di {len(messages)} messaggi persi al backend Django + Gemini AI...\n")

success_count = 0
for idx, (gid, sender, txt) in enumerate(messages, 1):
    payload = json.dumps({
        'action': 'text_message',
        'groupId': gid,
        'voter': sender,
        'text': txt
    }).encode('utf-8')
    
    req = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            res = json.loads(r.read().decode('utf-8'))
            succ = res.get('success')
            esito = res.get('esito')
            allievo = res.get('allievo')
            azione = res.get('azione_presenze')
            risposta_ai = res.get('risposta_ai')
            if succ:
                success_count += 1
            print(f"[{idx}/{len(messages)}] {sender} | \"{txt}\"")
            print(f"       -> Esito: {esito} | Allievo: {allievo} | Azione: {azione} | Risposta AI: {risposta_ai}")
    except Exception as e:
        print(f"[{idx}/{len(messages)}] {sender} | \"{txt}\" -> ERRORE: {e}")
    time.sleep(0.5)

print(f"\nCompletato: {success_count}/{len(messages)} elaborati con successo da Gemini AI e registrati nelle presenze!")
