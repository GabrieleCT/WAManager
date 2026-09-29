with open("flutter_app/lib/screens/allievi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("Text('?? ${a.corsoDescrizione!}'", "Text('🎓 ${a.corsoDescrizione!}'")

with open("flutter_app/lib/screens/allievi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)

with open("flutter_app/lib/screens/corsi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("Text('?? ${effettivi[idx].telefono}'", "Text('📞 ${effettivi[idx].telefono}'")
text = text.replace("Text('?? ${p.telefono}'", "Text('📞 ${p.telefono}'")

with open("flutter_app/lib/screens/corsi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
