with open("flutter_app/lib/screens/allievi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace("?? ${a.corsoDescrizione!}", "?? ${a.corsoDescrizione!}")

with open("flutter_app/lib/screens/allievi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
