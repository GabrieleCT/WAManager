import re
with open("flutter_app/lib/screens/corsi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Fix emoji for prospect
text = text.replace("?? ${p.telefono}", "?? ${p.telefono}")

# Fix effettivi title
text = re.sub(
    r"title: Text\(effettivi\[idx\]\.nomeCompleto,\s*style: const TextStyle\(fontWeight: FontWeight\.w600,\s*fontSize: 14\)\),",
    r"title: Row(children: [Text(effettivi[idx].nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), if (effettivi[idx].partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 14, color: Colors.pink)]]),",
    text
)

# Fix effettivi subtitle
text = re.sub(
    r"subtitle: Text\('. \$\{effettivi\[idx\]\.telefono\}', style: const TextStyle\(fontSize: 12\)\),",
    r"subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('?? ${effettivi[idx].telefono}', style: const TextStyle(fontSize: 12)), if (effettivi[idx].partnerId != null) Text('Partner: ${effettivi[idx].partnerNomeCompleto}', style: const TextStyle(fontSize: 11, color: Colors.pink))]),",
    text
)

with open("flutter_app/lib/screens/corsi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
