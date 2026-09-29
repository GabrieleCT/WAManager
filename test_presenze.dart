import 'dart:convert';
import 'dart:io';

class Presenza {
  String id;
  String allievoId;
  String allievoNome;
  String allievoRuolo;
  bool allievoIsProspect;
  String? allievoPartnerId;
  String? allievoPartnerNome;
  bool presente;

  Presenza({
    required this.id,
    required this.allievoId,
    required this.allievoNome,
    required this.allievoRuolo,
    required this.allievoIsProspect,
    this.allievoPartnerId,
    this.allievoPartnerNome,
    required this.presente,
  });

  String get allievoSortName {
    if (allievoPartnerId == null || allievoPartnerNome == null) return allievoNome;
    return allievoNome.compareTo(allievoPartnerNome!) < 0 ? allievoNome : allievoPartnerNome!;
  }
}

void main() async {
  // Read from API output saved to file
  final jsonStr = await File('api_data.json').readAsString();
  final data = jsonDecode(jsonStr) as List;
  
  var presenze = data.map((json) => Presenza(
    id: json['id'] ?? '',
    allievoId: json['allievo'] ?? '',
    allievoNome: json['allievo_nome'] ?? '',
    allievoRuolo: json['allievo_ruolo'] ?? '',
    allievoIsProspect: json['allievo_is_prospect'] ?? false,
    allievoPartnerId: json['allievo_partner_id'],
    allievoPartnerNome: json['allievo_partner_nome'],
    presente: json['presente'] ?? false,
  )).toList();

  presenze.sort((a, b) {
    if (a.presente != b.presente) return a.presente ? -1 : 1;
    int cmp = a.allievoSortName.compareTo(b.allievoSortName);
    if (cmp != 0) return cmp;
    return b.allievoRuolo.compareTo(a.allievoRuolo);
  });

  for (var i = 0; i < presenze.length; i++) {
    var p = presenze[i];
    print('${i.toString().padLeft(2)}: ${p.allievoNome.padRight(25)} (Sort: ${p.allievoSortName.padRight(25)}) - Partner: ${p.allievoPartnerNome}');
  }
}
