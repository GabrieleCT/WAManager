import re
with open("core/serializers.py", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    "allievo_is_prospect = serializers.BooleanField(source='allievo.is_prospect', read_only=True)",
    "allievo_is_prospect = serializers.BooleanField(source='allievo.is_prospect', read_only=True)\n    allievo_partner_id = serializers.UUIDField(source='allievo.partner.id', read_only=True)\n    allievo_partner_nome = serializers.CharField(source='allievo.partner.__str__', read_only=True)"
)

text = text.replace(
    "'allievo_nome', 'allievo_ruolo', 'allievo_telefono', 'allievo_is_prospect',",
    "'allievo_nome', 'allievo_ruolo', 'allievo_telefono', 'allievo_is_prospect', 'allievo_partner_id', 'allievo_partner_nome',"
)

with open("core/serializers.py", "w", encoding="utf-8") as f:
    f.write(text)
