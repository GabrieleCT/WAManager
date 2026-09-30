class Scuola {
  final String id;
  final String nome;
  final String sede;
  final String gruppoWhatsapp;
  final int corsiCount;

  Scuola({
    required this.id,
    required this.nome,
    required this.sede,
    required this.gruppoWhatsapp,
    this.corsiCount = 0,
  });

  factory Scuola.fromJson(Map<String, dynamic> json) {
    return Scuola(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      sede: json['sede'] ?? '',
      gruppoWhatsapp: json['gruppo_whatsapp'] ?? '',
      corsiCount: json['corsi_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'sede': sede,
    'gruppo_whatsapp': gruppoWhatsapp,
  };
}

class Corso {
  final String id;
  final String scuolaId;
  final String scuolaNome;
  final String livello;
  final String livelloDisplay;
  final String giornoSettimana;
  final String orario;
  final String annoAccademico;
  final String gruppoWhatsapp;
  final int allieviCount;

  Corso({
    required this.id,
    required this.scuolaId,
    required this.scuolaNome,
    required this.livello,
    required this.livelloDisplay,
    required this.giornoSettimana,
    required this.orario,
    required this.annoAccademico,
    required this.gruppoWhatsapp,
    this.allieviCount = 0,
  });

  String get giornoSettimanaDisplay {
    const map = {
      'LUNEDI': 'Lunedì',
      'MARTEDI': 'Martedì',
      'MERCOLEDI': 'Mercoledì',
      'GIOVEDI': 'Giovedì',
      'VENERDI': 'Venerdì',
      'SABATO': 'Sabato',
      'DOMENICA': 'Domenica',
    };
    return map[giornoSettimana.toUpperCase()] ?? giornoSettimana;
  }

  factory Corso.fromJson(Map<String, dynamic> json) {
    return Corso(
      id: json['id'] ?? '',
      scuolaId: json['scuola'] ?? '',
      scuolaNome: json['scuola_nome'] ?? '',
      livello: json['livello'] ?? 'principiante',
      livelloDisplay: json['livello_display'] ?? json['livello'] ?? '',
      giornoSettimana: json['giorno_settimana'] ?? 'LUNEDI',
      orario: (json['orario'] != null && json['orario'].toString().length >= 5) ? json['orario'].toString().substring(0, 5) : (json['orario'] ?? ''),
      annoAccademico: json['anno_accademico'] ?? '2025/2026',
      gruppoWhatsapp: json['gruppo_whatsapp'] ?? '',
      allieviCount: json['allievi_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'scuola': scuolaId,
    'livello': livello,
    'giorno_settimana': giornoSettimana,
    'orario': orario,
    'anno_accademico': annoAccademico,
    'gruppo_whatsapp': gruppoWhatsapp,
  };
}

class Argomento {
  final String id;
  final String titolo;
  final String descrizione;
  final String livello;
  final String livelloDisplay;

  Argomento({
    required this.id,
    required this.titolo,
    required this.descrizione,
    required this.livello,
    required this.livelloDisplay,
  });

  factory Argomento.fromJson(Map<String, dynamic> json) {
    return Argomento(
      id: json['id'] ?? '',
      titolo: json['titolo'] ?? '',
      descrizione: json['descrizione'] ?? '',
      livello: json['livello'] ?? 'principiante',
      livelloDisplay: json['livello_display'] ?? json['livello'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'titolo': titolo,
    'descrizione': descrizione,
    'livello': livello,
  };
}
class Allievo {
  final String id;
  final String nome;
  final String cognome;
  final String ruolo;
  final String ruoloDisplay;
  final String telefono;
  final String? corsoId;
  final String? corsoDescrizione;
  final String? scuolaId;
  final String? scuolaNome;
  final String recensione;
  final String recensioneDisplay;
  final String livello;
  final String livelloDisplay;
  final bool isActive;
  final bool isProspect;
  final String note;
  final String? partnerId;
  final String? partnerNome;
  final String? partnerCognome;
  final bool inGruppoScuolaWhatsapp;

  Allievo({
    required this.id,
    required this.nome,
    required this.cognome,
    required this.ruolo,
    required this.ruoloDisplay,
    required this.telefono,
    this.corsoId,
    this.corsoDescrizione,
    this.scuolaId,
    this.scuolaNome,
    required this.recensione,
    required this.recensioneDisplay,
    required this.livello,
    required this.livelloDisplay,
    this.isActive = true,
    this.isProspect = false,
    this.note = '',
    this.partnerId,
    this.partnerNome,
    this.partnerCognome,
    this.inGruppoScuolaWhatsapp = false,
  });

  String get nomeCompleto => '$nome $cognome';
  String get partnerNomeCompleto => partnerNome != null ? '$partnerNome $partnerCognome' : '';

  String get sortName {
    final myName = '$cognome $nome'.toLowerCase().trim();
    if (partnerId == null || partnerNome == null) return myName;
    final pName = '$partnerCognome $partnerNome'.toLowerCase().trim();
    return myName.compareTo(pName) < 0 ? myName : pName;
  }

  factory Allievo.fromJson(Map<String, dynamic> json) {
    return Allievo(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      cognome: json['cognome'] ?? '',
      ruolo: json['ruolo'] ?? 'leader',
      ruoloDisplay: json['ruolo_display'] ?? json['ruolo'] ?? '',
      telefono: json['telefono'] ?? '',
      corsoId: json['corso'],
      corsoDescrizione: json['corso_descrizione'],
      scuolaId: json['scuola_id'],
      scuolaNome: json['scuola_nome'],
      recensione: json['recensione'] ?? 'no',
      recensioneDisplay: json['recensione_display'] ?? json['recensione'] ?? '',
      livello: json['livello'] ?? 'principiante',
      livelloDisplay: json['livello_display'] ?? json['livello'] ?? '',
      isActive: json['is_active'] ?? true,
      isProspect: json['is_prospect'] ?? false,
      note: json['note'] ?? '',
      partnerId: json['partner'],
      partnerNome: json['partner_nome'],
      partnerCognome: json['partner_cognome'],
      inGruppoScuolaWhatsapp: json['in_gruppo_scuola_whatsapp'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'cognome': cognome,
    'ruolo': ruolo,
    'telefono': telefono,
    'corso': corsoId,
    'recensione': recensione,
    'livello': livello,
    'is_active': isActive,
    'is_prospect': isProspect,
    'note': note,
    'in_gruppo_scuola_whatsapp': inGruppoScuolaWhatsapp,
  };
}

class Jolly {
  final String id;
  final String allievoId;
  final String allievoNome;
  final String allievoTelefono;
  final String allievoRuolo;
  final String allievoRuoloDisplay;
  final String allievoLivello;
  final int priorita;

  Jolly({
    required this.id,
    required this.allievoId,
    required this.allievoNome,
    required this.allievoTelefono,
    required this.allievoRuolo,
    required this.allievoRuoloDisplay,
    required this.allievoLivello,
    required this.priorita,
  });

  factory Jolly.fromJson(Map<String, dynamic> json) {
    return Jolly(
      id: json['id'] ?? '',
      allievoId: json['allievo'] ?? '',
      allievoNome: json['allievo_nome'] ?? '',
      allievoTelefono: json['allievo_telefono'] ?? '',
      allievoRuolo: json['allievo_ruolo'] ?? '',
      allievoRuoloDisplay: json['allievo_ruolo_display'] ?? '',
      allievoLivello: json['allievo_livello'] ?? '',
      priorita: json['priorita'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'allievo': allievoId,
    'priorita': priorita,
  };
}

class Lezione {
  final String id;
  final String corsoId;
  final String corsoDescrizione;
  final String? scuolaId;
  final String? scuolaNome;
  final String data;
  final String titolo;
  final String? argomentoId;
  final String? argomentoTitolo;
  final int presenzeTotali;
  final int presentiCount;

  Lezione({
    required this.id,
    required this.corsoId,
    required this.corsoDescrizione,
    this.scuolaId,
    this.scuolaNome,
    required this.data,
    this.titolo = '',
    this.argomentoId,
    this.argomentoTitolo,
    this.presenzeTotali = 0,
    this.presentiCount = 0,
  });

  factory Lezione.fromJson(Map<String, dynamic> json) {
    return Lezione(
      id: json['id'] ?? '',
      corsoId: json['corso'] ?? '',
      corsoDescrizione: json['corso_descrizione'] ?? '',
      scuolaId: json['scuola_id'],
      scuolaNome: json['scuola_nome'],
      data: json['data'] ?? '',
      titolo: json['titolo'] ?? '',
      argomentoId: json['argomento'],
      argomentoTitolo: json['argomento_titolo'],
      presenzeTotali: json['presenze_totali'] ?? 0,
      presentiCount: json['presenti_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'corso': corsoId,
    'data': data,
    'titolo': titolo,
    'argomento': argomentoId,
  };
}

class Presenza {
  final String id;
  final String lezioneId;
  final String allievoId;
  final String allievoNome;
  final String allievoNomeSolo;
  final String allievoCognome;
  final String allievoRuolo;
  final String allievoTelefono;
  final bool allievoIsProspect;
  final bool isJolly;
  final String? allievoPartnerId;
  final String? allievoPartnerNome;
  String get cleanNome => allievoNome.replaceAll(RegExp(r'\[Prospect\]\s*', caseSensitive: false), '').trim();
  String get cleanPartnerNome => (allievoPartnerNome ?? '').replaceAll(RegExp(r'\[Prospect\]\s*', caseSensitive: false), '').trim();

  String get nomeSolo {
    if (allievoNomeSolo.isNotEmpty) return allievoNomeSolo.trim();
    final parts = cleanNome.split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  String get cognomeSolo {
    if (allievoCognome.isNotEmpty) return allievoCognome.trim();
    final parts = cleanNome.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String get allievoSortName {
    final myName = cleanNome.toLowerCase().trim();
    if (allievoPartnerId == null || allievoPartnerNome == null) return myName;
    final pName = cleanPartnerNome.toLowerCase().trim();
    return myName.compareTo(pName) < 0 ? myName : pName;
  }

  bool presente;
  String fonte;

  Presenza({
    required this.id,
    required this.lezioneId,
    required this.allievoId,
    required this.allievoNome,
    this.allievoNomeSolo = '',
    this.allievoCognome = '',
    required this.allievoRuolo,
    required this.allievoTelefono,
    this.allievoIsProspect = false,
    this.isJolly = false,
    this.allievoPartnerId,
    this.allievoPartnerNome,
    required this.presente,
    this.fonte = 'manuale',
  });

  factory Presenza.fromJson(Map<String, dynamic> json) {
    return Presenza(
      id: json['id'] ?? '',
      lezioneId: json['lezione'] ?? '',
      allievoId: json['allievo'] ?? '',
      allievoNome: json['allievo_nome'] ?? '',
      allievoNomeSolo: json['allievo_nome_solo'] ?? '',
      allievoCognome: json['allievo_cognome'] ?? '',
      allievoRuolo: json['allievo_ruolo'] ?? '',
      allievoTelefono: json['allievo_telefono'] ?? '',
      allievoIsProspect: json['allievo_is_prospect'] ?? false,
      isJolly: json['is_jolly'] ?? false,
      allievoPartnerId: json['allievo_partner_id'],
      allievoPartnerNome: json['allievo_partner_nome'],
      presente: json['presente'] ?? false,
      fonte: json['fonte'] ?? 'manuale',
    );
  }
}

class Pagamento {
  final String id;
  final String allievoId;
  final String allievoNome;
  final String corsoId;
  final String corsoDescrizione;
  final String scuolaNome;
  final double importo;
  final String trimestre;
  final String trimestreDisplay;
  final String dataPagamento;
  final String note;

  Pagamento({
    required this.id,
    required this.allievoId,
    required this.allievoNome,
    required this.corsoId,
    required this.corsoDescrizione,
    required this.scuolaNome,
    required this.importo,
    required this.trimestre,
    required this.trimestreDisplay,
    required this.dataPagamento,
    this.note = '',
  });

  factory Pagamento.fromJson(Map<String, dynamic> json) {
    return Pagamento(
      id: json['id'] ?? '',
      allievoId: json['allievo'] ?? '',
      allievoNome: json['allievo_nome'] ?? '',
      corsoId: json['corso'] ?? '',
      corsoDescrizione: json['corso_descrizione'] ?? '',
      scuolaNome: json['scuola_nome'] ?? '',
      importo: double.tryParse(json['importo']?.toString() ?? '150.0') ?? 150.0,
      trimestre: json['trimestre'] ?? 'T1',
      trimestreDisplay: json['trimestre_display'] ?? json['trimestre'] ?? '',
      dataPagamento: json['data_pagamento'] ?? '',
      note: json['note'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'allievo': allievoId,
    'corso': corsoId,
    'importo': importo.toStringAsFixed(2),
    'trimestre': trimestre,
    'data_pagamento': dataPagamento,
    'note': note,
  };
}

class SondaggioMattutinoConfig {
  final String id;
  final String corsoId;
  final String corsoDescrizione;
  final String scuolaNome;
  final String gruppoWhatsapp;
  final String testo;
  final bool isActive;
  final String createdAt;

  SondaggioMattutinoConfig({
    required this.id,
    required this.corsoId,
    required this.corsoDescrizione,
    required this.scuolaNome,
    required this.gruppoWhatsapp,
    required this.testo,
    required this.isActive,
    required this.createdAt,
  });

  factory SondaggioMattutinoConfig.fromJson(Map<String, dynamic> json) {
    return SondaggioMattutinoConfig(
      id: json['id'] ?? '',
      corsoId: json['corso'] ?? '',
      corsoDescrizione: json['corso_descrizione'] ?? '',
      scuolaNome: json['scuola_nome'] ?? '',
      gruppoWhatsapp: json['gruppo_whatsapp'] ?? '',
      testo: json['testo'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'corso': corsoId,
    'testo': testo,
    'is_active': isActive,
  };
}


