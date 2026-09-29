import re
with open("flutter_app/lib/screens/allievi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = re.sub(
    r"title: Text\(a\.nomeCompleto, style: const TextStyle\(fontWeight: FontWeight\.bold\)\),",
    "title: Row(children: [Text(a.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)), if (a.partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 16, color: Colors.pink)]]),",
    text
)

text = re.sub(
    r"Text\('. \$\{a\.corsoDescrizione!\}\', style: const TextStyle\(fontSize: 12, color: Colors\.grey\)\),",
    "Text('?? ${a.corsoDescrizione!}', style: const TextStyle(fontSize: 12, color: Colors.grey)), if (a.partnerId != null) Text('Partner: ${a.partnerNomeCompleto}', style: const TextStyle(fontSize: 12, color: Colors.pink)),",
    text
)

with open("flutter_app/lib/screens/allievi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
