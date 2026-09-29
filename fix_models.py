import re
with open("flutter_app/lib/models/models.dart", "r", encoding="utf-8") as f:
    text = f.read()

text = text.replace(
    "final bool allievoIsProspect;\n  bool presente;\n  String fonte;",
    "final bool allievoIsProspect;\n  final String? allievoPartnerId;\n  final String? allievoPartnerNome;\n  bool presente;\n  String fonte;"
)

text = text.replace(
    "this.allievoIsProspect = false,\n    required this.presente,\n    this.fonte = 'manuale',",
    "this.allievoIsProspect = false,\n    this.allievoPartnerId,\n    this.allievoPartnerNome,\n    required this.presente,\n    this.fonte = 'manuale',"
)

text = text.replace(
    "allievoIsProspect: json['allievo_is_prospect'] ?? false,\n      presente: json['presente'] ?? false,\n      fonte: json['fonte'] ?? 'manuale',",
    "allievoIsProspect: json['allievo_is_prospect'] ?? false,\n      allievoPartnerId: json['allievo_partner_id'],\n      allievoPartnerNome: json['allievo_partner_nome'],\n      presente: json['presente'] ?? false,\n      fonte: json['fonte'] ?? 'manuale',"
)

with open("flutter_app/lib/models/models.dart", "w", encoding="utf-8") as f:
    f.write(text)
