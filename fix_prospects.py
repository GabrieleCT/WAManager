import re
with open("flutter_app/lib/screens/prospects_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

sort_code = """
  void _sortProspects(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  Future<void> _loadData() async {"""
text = text.replace("  Future<void> _loadData() async {", sort_code)

text = text.replace('''    if (mounted) {
      setState(() {
        _prospects = prospects;
        _scuole = scuole;
        _corsi = corsi;
        _loading = false;
      });
    }''', '''    _sortProspects(prospects);
    if (mounted) {
      setState(() {
        _prospects = prospects;
        _scuole = scuole;
        _corsi = corsi;
        _loading = false;
      });
    }''')

text = re.sub(
    r"title: Text\(p\.nomeCompleto, style: const TextStyle\(fontWeight: FontWeight\.bold\)\),",
    "title: Row(children: [Text(p.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)), if (p.partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 16, color: Colors.pink)]]),",
    text
)

text = re.sub(
    r"Text\('?? \$\{p\.corsoDescrizione!\}\', style: const TextStyle\(fontSize: 12, color: Colors\.grey\)\),",
    "Text('?? ${p.corsoDescrizione!}', style: const TextStyle(fontSize: 12, color: Colors.grey)), if (p.partnerId != null) Text('Partner: ${p.partnerNomeCompleto}', style: const TextStyle(fontSize: 12, color: Colors.pink)),",
    text
)
# Wait, prospects might use a different icon or format? Let's check how the tile is built in prospects_screen.dart.
