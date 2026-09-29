import re
with open("flutter_app/lib/screens/presenze_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Just inject partner info inside the subtitle
text = re.sub(
    r"(Ruolo: \$\{p\.allievoRuolo\.toUpperCase\(\)\} \W Tel: \$\{p\.allievoTelefono\.isNotEmpty \? p\.allievoTelefono : \"N/D\"})",
    r"\1${p.allievoPartnerId != null ? ' | Partner: ' + p.allievoPartnerNome! : ''}",
    text
)
with open("flutter_app/lib/screens/presenze_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
