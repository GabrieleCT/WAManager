import re
with open("flutter_app/lib/screens/presenze_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Resort after toggling presence
text = text.replace(
    "p.fonte = 'manuale'; // Modifica esplicita dall'utente\n                              });",
    "p.fonte = 'manuale'; // Modifica esplicita dall'utente\n                                _sortPresenze(_presenze);\n                              });"
)

with open("flutter_app/lib/screens/presenze_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
