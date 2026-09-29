with open("flutter_app/lib/screens/corsi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("?? ${effettivi[idx].telefono}", "?? ${effettivi[idx].telefono}")
text = text.replace("?? ${p.telefono}", "?? ${p.telefono}")

with open("flutter_app/lib/screens/corsi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
