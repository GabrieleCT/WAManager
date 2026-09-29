import re
with open("flutter_app/lib/screens/presenze_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Add sort helper
sort_code = """  void _sortPresenze(List<Presenza> list) {
    list.sort((a, b) {
      if (a.presente != b.presente) return a.presente ? -1 : 1; // Presenti prima
      // We want to sort by couple. 
      // But we don't have sortName directly in Presenza... Presenza has allievo_nome, allievo_cognome...
      // Does Presenza have partner info? Let's check.
      return a.allievoNomeCompleto.compareTo(b.allievoNomeCompleto);
    });
  }

  Future<void> _loadPresenze(String lezioneId) async {"""
# Wait, let's see how Presenza is defined. I don't need python to guess, let me look at models.dart for Presenza.
