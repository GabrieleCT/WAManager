with open("flutter_app/lib/models/models.dart", "r", encoding="utf-8") as f:
    text = f.read()

import re

# Fix Allievo sortName
text = re.sub(
    r"String get sortName \{[\s\S]*?\}",
    """String get sortName {
    final myName = '$cognome $nome'.toLowerCase().trim();
    if (partnerId == null || partnerNome == null) return myName;
    final pName = '$partnerCognome $partnerNome'.toLowerCase().trim();
    return myName.compareTo(pName) < 0 ? myName : pName;
  }""",
    text
)

# Fix Presenza allievoSortName
text = re.sub(
    r"String get allievoSortName \{[\s\S]*?\}",
    """String get allievoSortName {
    final myName = allievoNome.toLowerCase().trim();
    if (allievoPartnerId == null || allievoPartnerNome == null) return myName;
    final pName = allievoPartnerNome!.toLowerCase().trim();
    return myName.compareTo(pName) < 0 ? myName : pName;
  }""",
    text
)

with open("flutter_app/lib/models/models.dart", "w", encoding="utf-8") as f:
    f.write(text)
