import json
import urllib.request
import urllib.error

# get data
req = urllib.request.Request('http://127.0.0.1:8080/api/lezioni/f4db4f84-f564-4931-a324-de77fdcfaf79/presenze/')
req.add_header('Authorization', 'Basic YWRtaW46YWRtaW4=') # assuming admin:admin if basic auth is enabled. Oh wait DRF uses Token or Session.

# Let's just query from DB!
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'wamanager.settings')
django.setup()
from core.models import Lezione
from rest_framework.test import APIClient
from django.contrib.auth.models import User

c = APIClient()
c.force_authenticate(user=User.objects.first())

for lezione in Lezione.objects.all():
    response = c.get(f"/api/lezioni/{lezione.id}/presenze/")
    data = response.json()
    
    # Dart sorting logic translation
    def get_sort_name(p):
        nome = p.get("allievo_nome", "")
        partner = p.get("allievo_partner_nome")
        if not partner:
            return nome
        if nome < partner:
            return nome
        return partner
        
    def compare(a, b):
        if a["presente"] != b["presente"]:
            return -1 if a["presente"] else 1
        
        sa = get_sort_name(a)
        sb = get_sort_name(b)
        if sa != sb:
            return -1 if sa < sb else 1
            
        ra = a.get("allievo_ruolo", "")
        rb = b.get("allievo_ruolo", "")
        if ra != rb:
            return -1 if rb < ra else 1
            
        return 0

    from functools import cmp_to_key
    data.sort(key=cmp_to_key(compare))
    
    # check if couples are separated
    for i, p in enumerate(data):
        partner_id = p.get("allievo_partner_id")
        if partner_id:
            # find partner in the list
            partner_idx = next((j for j, op in enumerate(data) if op["allievo"] == partner_id), None)
            if partner_idx is not None and abs(partner_idx - i) > 1:
                print(f"SEPARATED in lezione {lezione.id}: {p['allievo_nome']} at {i} and partner at {partner_idx}")

print("Done checking all lezioni.")
