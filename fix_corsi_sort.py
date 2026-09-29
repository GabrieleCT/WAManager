with open("flutter_app/lib/screens/corsi_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

import re
text = re.sub(
    r"void _sortIscritti\(List<Allievo> list\) \{[\s\S]*?\}",
    """void _sortIscritti(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }""",
    text
)

with open("flutter_app/lib/screens/corsi_screen.dart", "w", encoding="utf-8") as f:
    f.write(text)
