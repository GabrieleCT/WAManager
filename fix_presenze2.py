import re
with open("flutter_app/lib/models/models.dart", "r", encoding="utf-8") as f:
    text = f.read()

# I also need a sortName in Presenza!
sort_code = """
  String get allievoSortName {
    if (allievoPartnerId == null || allievoPartnerNome == null) return allievoNome;
    return allievoNome.compareTo(allievoPartnerNome!) < 0 ? allievoNome : allievoPartnerNome!;
  }
"""
text = text.replace("final String? allievoPartnerNome;", "final String? allievoPartnerNome;" + sort_code)

with open("flutter_app/lib/models/models.dart", "w", encoding="utf-8") as f:
    f.write(text)

with open("flutter_app/lib/screens/presenze_screen.dart", "r", encoding="utf-8") as f:
    ptext = f.read()

sort_fn = """  void _sortPresenze(List<Presenza> list) {
    list.sort((a, b) {
      if (a.presente != b.presente) return a.presente ? 1 : -1; // Presenti in fondo
      int cmp = a.allievoSortName.compareTo(b.allievoSortName);
      if (cmp != 0) return cmp;
      return b.allievoRuolo.compareTo(a.allievoRuolo); // Leader prima
    });
  }

  Future<void> _loadPresenze(String lezioneId) async {"""
ptext = ptext.replace("  Future<void> _loadPresenze(String lezioneId) async {", sort_fn)

ptext = ptext.replace(
    "_presenze = presenze;\n        _matchStats = null;\n        _loading = false;",
    "_sortPresenze(presenze);\n        _presenze = presenze;\n        _matchStats = null;\n        _loading = false;"
)

# And in build(), we also need to sort them before displaying? Wait, _presenze is sorted in _loadPresenze. But when we toggle checkbox we need to re-sort!
# Actually, the user asked: "Quando segno i presenti nella sezione presenze non avviene lo scorrimento che ti ho chiesto, ovvero quello di portare gli assenti in fondo" -> Wait, wait. "Una volta che metto le persone presenti, gli assenti me li devi mettere in fondo" -> "Presenti in cima, assenti in fondo". Wait, no, he said "gli assenti me li devi mettere in fondo". So present=True goes TOP (or bottom?). He said "gli assenti me li devi mettere in fondo". So absent goes to BOTTOM. So Present goes to TOP.
# Ah, the previous fix I did put absent at top? Let's check the old sorting in presenze_screen.dart

with open("flutter_app/lib/screens/presenze_screen.dart", "w", encoding="utf-8") as f:
    f.write(ptext)
