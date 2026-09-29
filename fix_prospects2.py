import re
with open("flutter_app/lib/screens/prospects_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    "child: const Text('PROSPECT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),\n                            ),\n                          ],",
    "child: const Text('PROSPECT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),\n                            ),\n                            if (p.partnerId != null) ...[\n                              const SizedBox(width: 8),\n                              const Icon(Icons.favorite, size: 16, color: Colors.pink),\n                            ],\n                          ],"
)

text = text.replace(
    "Text('?? ${p.telefono} | Ruolo: ${p.ruoloDisplay} | Livello: ${p.livelloDisplay}'),",
    "Text('?? ${p.telefono} | Ruolo: ${p.ruoloDisplay} | Livello: ${p.livelloDisplay}'),\n                            if (p.partnerId != null) Text('Partner: ${p.partnerNomeCompleto}', style: const TextStyle(fontSize: 12, color: Colors.pink)),"
)

# And fix the emoji encoding since python read might not have it properly if it was not utf-8 in powershell cat, but file is UTF-8. Let's not touch emojis just use the exact text.
