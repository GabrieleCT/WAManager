with open("core/serializers.py", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    "allievo_partner_nome = serializers.CharField(source='allievo.partner.__str__', read_only=True)",
    "allievo_partner_nome = serializers.SerializerMethodField()\n\n    def get_allievo_partner_nome(self, obj):\n        if obj.allievo.partner:\n            return str(obj.allievo.partner)\n        return None"
)

with open("core/serializers.py", "w", encoding="utf-8") as f:
    f.write(text)
