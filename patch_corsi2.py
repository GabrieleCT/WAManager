import re
with open("flutter_app/lib/screens/corsi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = re.sub(
    r"Text\(\s*p\.nomeCompleto,\s*style: const TextStyle\(fontWeight: FontWeight\.bold,\s*fontSize: 14\),\s*\),\s*const SizedBox\(width: 8\),\s*Container\(",
    r"Text(p.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),\n                                  if (p.partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 14, color: Colors.pink)],\n                                  const SizedBox(width: 8),\n                                  Container(",
    text
)

text = re.sub(
    r"Text\('. \$\{p\.telefono\}', style: const TextStyle\(fontSize: 12\)\),\s*const SizedBox\(width: 8\),\s*_buildRuoloBadge\(p\.ruolo\),",
    r"Text('?? ${p.telefono}', style: const TextStyle(fontSize: 12)), const SizedBox(width: 8), _buildRuoloBadge(p.ruolo), if (p.partnerId != null) ...[const SizedBox(width: 8), Text('Partner: ${p.partnerNomeCompleto}', style: const TextStyle(fontSize: 11, color: Colors.pink))],",
    text
)

with open("flutter_app/lib/screens/corsi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
