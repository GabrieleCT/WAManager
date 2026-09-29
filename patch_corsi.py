import re
with open("flutter_app/lib/screens/corsi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

sort_code = """
  void _sortIscritti(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  Future<void> _fetchIscritti(String corsoId) async {"""
text = text.replace("  Future<void> _fetchIscritti(String corsoId) async {", sort_code)

text = text.replace(
    "final list = await _api.getAllievi(corsoId: corsoId);",
    "final list = await _api.getAllievi(corsoId: corsoId);\n        _sortIscritti(list);"
)

# For effettivi title:
text = re.sub(
    r"title: Text\(effettivi\[idx\]\.nomeCompleto, style: const TextStyle\(fontWeight: FontWeight\.w600, fontSize: 14\)\),",
    r"title: Row(children: [Text(effettivi[idx].nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), if (effettivi[idx].partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 14, color: Colors.pink)]]),",
    text
)

# For effettivi subtitle:
text = re.sub(
    r"subtitle: Text\('. \$\{effettivi\[idx\]\.telefono\}', style: const TextStyle\(fontSize: 12\)\),",
    r"subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('?? ${effettivi[idx].telefono}', style: const TextStyle(fontSize: 12)), if (effettivi[idx].partnerId != null) Text('Partner: ${effettivi[idx].partnerNomeCompleto}', style: const TextStyle(fontSize: 11, color: Colors.pink))]),",
    text
)

# For prospects tile title and subtitle, let's see how they are formatted.
