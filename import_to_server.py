import urllib.request
import json
import uuid
import os

SERVER_URL = 'http://80.211.58.251:8000'
USERNAME = 'admin'
PASSWORD = 'admin'
DUMP_FILE = 'WAManager_Dump_Pulito.json'

print(f"1. Effettuo login su {SERVER_URL}...")
login_req = urllib.request.Request(
    f"{SERVER_URL}/api/auth/login/",
    data=json.dumps({'username': USERNAME, 'password': PASSWORD}).encode('utf-8'),
    headers={'Content-Type': 'application/json'}
)
with urllib.request.urlopen(login_req, timeout=10) as r:
    login_data = json.loads(r.read().decode('utf-8'))
    token = login_data['token']

print(f"   Login riuscito! Token: {token[:10]}...")

print(f"2. Preparo l'invio del file {DUMP_FILE}...")
boundary = f"----FormBoundary{uuid.uuid4().hex}"
with open(DUMP_FILE, 'rb') as f:
    file_bytes = f.read()

header_part = (
    f"--{boundary}\r\n"
    f"Content-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(DUMP_FILE)}\"\r\n"
    f"Content-Type: application/json\r\n\r\n"
).encode('utf-8')

footer_part = f"\r\n--{boundary}--\r\n".encode('utf-8')
payload = header_part + file_bytes + footer_part

upload_req = urllib.request.Request(
    f"{SERVER_URL}/api/import/global/",
    data=payload,
    headers={
        'Authorization': f'Token {token}',
        'Content-Type': f'multipart/form-data; boundary={boundary}',
    }
)

print(f"3. Invio file ({len(file_bytes)} bytes) al server...")
try:
    with urllib.request.urlopen(upload_req, timeout=120) as r:
        res = json.loads(r.read().decode('utf-8'))
        print("\n=== RIPRISTINO COMPLETATO CON SUCCESSO! ===")
        print(f"Messaggio: {res.get('messaggio')}")
        print(f"Totale oggetti importati: {res.get('totale_oggetti')}")
        print("Dettaglio per entità:")
        for k, v in sorted(res.get('statistiche', {}).items()):
            print(f"  • {k}: {v}")
except urllib.error.HTTPError as e:
    err_body = e.read().decode('utf-8')
    print(f"\nERRORE HTTP {e.code}: {err_body}")
except Exception as e:
    print(f"\nERRORE: {e}")
