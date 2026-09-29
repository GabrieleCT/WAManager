void main() {
  var p1 = Presenza(allievoNome: 'Mario Rossi', allievoPartnerNome: 'Anna Bianchi', ruolo: 'leader', presente: false);
  var p2 = Presenza(allievoNome: 'Anna Bianchi', allievoPartnerNome: 'Mario Rossi', ruolo: 'follower', presente: false);
  var p3 = Presenza(allievoNome: 'Zebra', allievoPartnerNome: null, ruolo: 'leader', presente: false);
  
  var list = [p3, p1, p2];
  
  list.sort((a, b) {
    if (a.presente != b.presente) return a.presente ? -1 : 1;
    int cmp = a.allievoSortName.compareTo(b.allievoSortName);
    if (cmp != 0) return cmp;
    return b.ruolo.compareTo(a.ruolo);
  });
  
  for (var p in list) {
    print('${p.allievoNome} (Sort: ${p.allievoSortName})');
  }
}

class Presenza {
  String allievoNome;
  String? allievoPartnerNome;
  String ruolo;
  bool presente;
  
  Presenza({required this.allievoNome, this.allievoPartnerNome, required this.ruolo, required this.presente});
  
  String get allievoSortName {
    if (allievoPartnerNome == null) return allievoNome;
    return allievoNome.compareTo(allievoPartnerNome!) < 0 ? allievoNome : allievoPartnerNome!;
  }
}
