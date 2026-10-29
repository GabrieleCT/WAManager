class Scuola {
  final String id;
  final String nome;
  final String sede;
  final String gruppoWhatsapp;
  final int corsiCount;
  final int allieviCount;
  final int prospectsCount;
  final int pagantiCount;

  Scuola({
    required this.id,
    required this.nome,
    required this.sede,
    required this.gruppoWhatsapp,
    this.corsiCount = 0,
    this.allieviCount = 0,
    this.prospectsCount = 0,
    this.pagantiCount = 0,
  });

  factory Scuola.fromJson(Map<String, dynamic> json) {
    return Scuola(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      sede: json['sede'] ?? '',
      gruppoWhatsapp: json['gruppo_whatsapp'] ?? '',
      corsiCount: json['corsi_count'] ?? 0,
      allieviCount: json['allievi_count'] ?? 0,
      prospectsCount: json['prospects_count'] ?? 0,
      pagantiCount: json['paganti_count'] ?? 0,
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
  final int prospectsCount;
  final int pagantiCount;
  final int leadersCount;
  final int followersCount;
  final int jollyNecessari;
  final int lezioniFatte;

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
    this.prospectsCount = 0,
    this.pagantiCount = 0,
    this.leadersCount = 0,
    this.followersCount = 0,
    this.jollyNecessari = 0,
    this.lezioniFatte = 0,
  });

  String get nomeDisplay => '$scuolaNome - $livelloDisplay ($giornoSettimanaDisplay $orario)';

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
      prospectsCount: json['prospects_count'] ?? 0,
      pagantiCount: json['paganti_count'] ?? 0,
      leadersCount: json['leaders_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      jollyNecessari: json['jolly_necessari'] ?? 0,
      lezioniFatte: json['lezioni_fatte'] ?? 0,
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
  final int ordine;

  Argomento({
    required this.id,
    required this.titolo,
    required this.descrizione,
    required this.livello,
    required this.livelloDisplay,
    this.ordine = 0,
  });

  factory Argomento.fromJson(Map<String, dynamic> json) {
    return Argomento(
      id: json['id'] ?? '',
      titolo: json['titolo'] ?? '',
      descrizione: json['descrizione'] ?? '',
      livello: json['livello'] ?? 'principiante',
      livelloDisplay: json['livello_display'] ?? json['livello'] ?? '',
      ordine: json['ordine'] is int ? json['ordine'] : int.tryParse(json['ordine']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'titolo': titolo,
    'descrizione': descrizione,
    'livello': livello,
    'ordine': ordine,
  };

  Argomento copyWith({
    String? id,
    String? titolo,
    String? descrizione,
    String? livello,
    String? livelloDisplay,
    int? ordine,
  }) {
    return Argomento(
      id: id ?? this.id,
      titolo: titolo ?? this.titolo,
      descrizione: descrizione ?? this.descrizione,
      livello: livello ?? this.livello,
      livelloDisplay: livelloDisplay ?? this.livelloDisplay,
      ordine: ordine ?? this.ordine,
    );
  }
}
class Allievo {
  final String id;
  final String nome;
  final String cognome;
  final String nickname;
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
  final bool inGruppoCorsoWhatsapp;
  final String? corsoGruppoWhatsapp;
  final bool corsoHasWhatsapp;
  final String numeroTessera;
  final String? dataEmissioneTessera;
  final String statoTessera;
  final String email;
  final String? googleContactId;
  final String? googleSyncError;

  Allievo({
    required this.id,
    required this.nome,
    required this.cognome,
    this.nickname = '',
    required this.ruolo,
    required this.ruoloDisplay,
    required this.telefono,
    this.email = '',
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
    this.inGruppoCorsoWhatsapp = false,
    this.corsoGruppoWhatsapp,
    this.corsoHasWhatsapp = false,
    this.numeroTessera = '',
    this.dataEmissioneTessera,
    this.statoTessera = 'NON TESSERATO',
    this.googleContactId,
    this.googleSyncError,
  });

  String get nomeCompleto => '$nome $cognome';
  String get partnerNomeCompleto => partnerNome != null ? '$partnerNome $partnerCognome' : '';

  bool get hasTesseraOk => statoTessera == 'TESSERA OK';
  bool get hasTesseraScaduta => statoTessera == 'TESSERA SCADUTA' || statoTessera == 'TESSERA SCADUTO';
  bool get isNonTesserato => statoTessera == 'NON TESSERATO';

  String get sortName {
    final myName = '$cognome $nome'.toLowerCase().trim();
    if (partnerId == null || partnerNome == null) return myName;
    final pName = '$partnerCognome $partnerNome'.toLowerCase().trim();
    return myName.compareTo(pName) < 0 ? myName : pName;
  }

  factory Allievo.fromJson(Map<String, dynamic> json) {
    String? googleSyncError;
    if (json['google_sync'] != null && json['google_sync'] is Map) {
      final gs = json['google_sync'] as Map;
      if (gs['success'] == false && gs['skipped'] != true) {
        googleSyncError = gs['error']?.toString();
      }
    }
    final nomeVal = (json['nome'] ?? '').toString();
    final nickVal = json['nickname']?.toString().trim();
    final nicknameVal = (nickVal != null && nickVal.isNotEmpty) ? nickVal : nomeVal;

    return Allievo(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      cognome: json['cognome'] ?? '',
      nickname: nicknameVal,
      ruolo: json['ruolo'] ?? 'leader',
      ruoloDisplay: json['ruolo_display'] ?? json['ruolo'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
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
      inGruppoCorsoWhatsapp: json['in_gruppo_corso_whatsapp'] ?? false,
      corsoGruppoWhatsapp: json['corso_gruppo_whatsapp'],
      corsoHasWhatsapp: json['corso_has_whatsapp'] ?? false,
      numeroTessera: json['numero_tessera'] ?? '',
      dataEmissioneTessera: json['data_emissione_tessera'],
      statoTessera: json['stato_tessera'] ?? 'NON TESSERATO',
      googleContactId: json['google_contact_id'],
      googleSyncError: googleSyncError,
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'cognome': cognome,
    'nickname': nickname,
    'ruolo': ruolo,
    'telefono': telefono,
    'email': email,
    'corso': corsoId,
    'recensione': recensione,
    'livello': livello,
    'is_active': isActive,
    'is_prospect': isProspect,
    'note': note,
    'in_gruppo_scuola_whatsapp': inGruppoScuolaWhatsapp,
    'numero_tessera': numeroTessera,
    'data_emissione_tessera': dataEmissioneTessera,
  };
}

class Jolly {
  final String id;
  final String allievoId;
  final String nickname;
  final String allievoNome;
  final String allievoTelefono;
  final String allievoRuolo;
  final String allievoRuoloDisplay;
  final String allievoLivello;
  final int priorita;

  Jolly({
    required this.id,
    required this.allievoId,
    this.nickname = '',
    required this.allievoNome,
    required this.allievoTelefono,
    required this.allievoRuolo,
    required this.allievoRuoloDisplay,
    required this.allievoLivello,
    required this.priorita,
  });

  String get displayName => allievoNome;

  String get effectiveNickname {
    if (nickname.trim().isNotEmpty) return nickname.trim();
    if (allievoNome.trim().isNotEmpty) return allievoNome.trim().split(' ').first;
    return 'Jolly';
  }

  factory Jolly.fromJson(Map<String, dynamic> json) {
    return Jolly(
      id: json['id'] ?? '',
      allievoId: json['allievo'] ?? '',
      nickname: json['nickname'] ?? '',
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
  final String? corsoOrario;
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
    this.corsoOrario,
    this.scuolaId,
    this.scuolaNome,
    required this.data,
    this.titolo = '',
    this.argomentoId,
    this.argomentoTitolo,
    this.presenzeTotali = 0,
    this.presentiCount = 0,
  });

  String get orarioEffettivo {
    if (corsoOrario != null && corsoOrario!.isNotEmpty) return corsoOrario!;
    final match = RegExp(r'\((\d{1,2}:\d{2})\)').firstMatch(corsoDescrizione);
    if (match != null) return match.group(1)!;
    return '';
  }

  factory Lezione.fromJson(Map<String, dynamic> json) {
    String? orario = json['corso_orario'] ?? json['orario'];
    if (orario == null || orario.isEmpty) {
      final desc = json['corso_descrizione'] ?? '';
      final match = RegExp(r'\((\d{1,2}:\d{2})\)').firstMatch(desc);
      if (match != null) {
        orario = match.group(1);
      }
    }

    return Lezione(
      id: json['id'] ?? '',
      corsoId: json['corso'] ?? '',
      corsoDescrizione: json['corso_descrizione'] ?? '',
      corsoOrario: orario,
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
  final String allievoNickname;
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

  String get nickname {
    if (allievoNickname.trim().isNotEmpty) return allievoNickname.trim();
    return nomeSolo;
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

  bool? presente;
  String fonte;
  final bool sollecitoInviato;
  final String? sollecitoInviatoAt;

  Presenza({
    required this.id,
    required this.lezioneId,
    required this.allievoId,
    required this.allievoNome,
    this.allievoNomeSolo = '',
    this.allievoCognome = '',
    this.allievoNickname = '',
    required this.allievoRuolo,
    required this.allievoTelefono,
    this.allievoIsProspect = false,
    this.isJolly = false,
    this.allievoPartnerId,
    this.allievoPartnerNome,
    this.presente,
    this.fonte = 'manuale',
    this.sollecitoInviato = false,
    this.sollecitoInviatoAt,
  });

  factory Presenza.fromJson(Map<String, dynamic> json) {
    return Presenza(
      id: json['id'] ?? '',
      lezioneId: json['lezione'] ?? '',
      allievoId: json['allievo'] ?? '',
      allievoNome: json['allievo_nome'] ?? '',
      allievoNomeSolo: json['allievo_nome_solo'] ?? '',
      allievoCognome: json['allievo_cognome'] ?? '',
      allievoNickname: json['allievo_nickname'] ?? '',
      allievoRuolo: json['allievo_ruolo'] ?? '',
      allievoTelefono: json['allievo_telefono'] ?? '',
      allievoIsProspect: json['allievo_is_prospect'] ?? false,
      isJolly: json['is_jolly'] ?? false,
      allievoPartnerId: json['allievo_partner_id'],
      allievoPartnerNome: json['allievo_partner_nome'],
      presente: json['presente'],
      fonte: json['fonte'] ?? 'manuale',
      sollecitoInviato: json['sollecito_inviato'] ?? false,
      sollecitoInviatoAt: json['sollecito_inviato_at'],
    );
  }
}

class Pagamento {
  final String id;
  final String allievoId;
  final String allievoNome;
  final String allievoNomeSolo;
  final String allievoCognome;
  final String corsoId;
  final String corsoDescrizione;
  final String scuolaNome;
  final double importo;
  final String trimestre;
  final String trimestreDisplay;
  final String dataPagamento;
  final String causale;
  final String note;
  final bool hasRicevuta;
  final String? ricevutaId;
  final String? ricevutaNumero;

  Pagamento({
    required this.id,
    required this.allievoId,
    required this.allievoNome,
    this.allievoNomeSolo = '',
    this.allievoCognome = '',
    required this.corsoId,
    required this.corsoDescrizione,
    required this.scuolaNome,
    required this.importo,
    required this.trimestre,
    required this.trimestreDisplay,
    required this.dataPagamento,
    this.causale = '',
    this.note = '',
    this.hasRicevuta = false,
    this.ricevutaId,
    this.ricevutaNumero,
  });

  String get nome {
    if (allievoNomeSolo.isNotEmpty) return allievoNomeSolo;
    final clean = allievoNome.replaceAll('[Prospect]', '').trim();
    final parts = clean.split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  String get cognome {
    if (allievoCognome.isNotEmpty) return allievoCognome;
    final clean = allievoNome.replaceAll('[Prospect]', '').trim();
    final parts = clean.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String get causaleDisplay {
    if (causale.isNotEmpty) return causale;
    if (note.isNotEmpty) return note;
    return 'Quota $trimestreDisplay';
  }

  factory Pagamento.fromJson(Map<String, dynamic> json) {
    return Pagamento(
      id: json['id'] ?? '',
      allievoId: json['allievo'] ?? '',
      allievoNome: json['allievo_nome'] ?? '',
      allievoNomeSolo: json['allievo_nome_solo'] ?? '',
      allievoCognome: json['allievo_cognome'] ?? '',
      corsoId: json['corso'] ?? '',
      corsoDescrizione: json['corso_descrizione'] ?? '',
      scuolaNome: json['scuola_nome'] ?? '',
      importo: double.tryParse(json['importo']?.toString() ?? '150.0') ?? 150.0,
      trimestre: json['trimestre'] ?? 'T1',
      trimestreDisplay: json['trimestre_display'] ?? json['trimestre'] ?? '',
      dataPagamento: json['data_pagamento'] ?? '',
      causale: json['causale'] ?? '',
      note: json['note'] ?? '',
      hasRicevuta: json['has_ricevuta'] ?? false,
      ricevutaId: json['ricevuta_id'],
      ricevutaNumero: json['ricevuta_numero'],
    );
  }

  Map<String, dynamic> toJson() => {
    'allievo': allievoId,
    'corso': corsoId,
    'importo': importo.toStringAsFixed(2),
    'trimestre': trimestre,
    'data_pagamento': dataPagamento,
    'causale': causale,
    'note': note,
  };
}

class SondaggioMattutinoConfig {
  final String id;
  final String? corsoId;
  final String corsoDescrizione;
  final String scuolaNome;
  final String orario;
  final String giorniSettimana;
  final String testo;
  final bool isPoll;
  final String pollOpzione1;
  final String pollOpzione2;
  final int oreAscoltoRisposte;
  final bool isActive;
  final bool sollecitoAttivo;
  final int sollecitoOreAttesa;
  final String sollecitoOrario;
  final String sollecitoTesto;
  final String jollyTesto;
  final String moduloTesseramentoTesto;
  final String ricevutaTesto;
  final String istruzioniPagamentoTesto;
  final String createdAt;
  final String updatedAt;

  SondaggioMattutinoConfig({
    required this.id,
    this.corsoId,
    this.corsoDescrizione = '',
    this.scuolaNome = '',
    this.orario = '08:00',
    this.giorniSettimana = '0,1,2,3,4,5,6',
    this.testo = '',
    this.isPoll = true,
    this.pollOpzione1 = 'Ci sono! 🕺💃',
    this.pollOpzione2 = 'Non ci sono 🚫',
    this.oreAscoltoRisposte = 5,
    this.isActive = true,
    this.sollecitoAttivo = false,
    this.sollecitoOreAttesa = 3,
    this.sollecitoOrario = '16:00',
    this.sollecitoTesto = '',
    this.jollyTesto = 'Ciao {nickname}! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺',
    this.moduloTesseramentoTesto = 'Gentile {nickname}, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all\'ASD TantoTango da compilare e firmare. A presto!',
    this.ricevutaTesto = 'Gentile {nickname}, in allegato la ricevuta {numero} del {data} di € {importo} per "{causale}".',
    this.istruzioniPagamentoTesto = 'Ciao {nickname}, per effettuare il pagamento della quota a favore di {nome_asd}, puoi effettuare un bonifico alle seguenti coordinate bancarie:\n\nIBAN: {iban}\nIntestato a: {nome_asd}\nCausale: Quota corso {nickname}\n\nGrazie e a presto! 💃🕺',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory SondaggioMattutinoConfig.fromJson(Map<String, dynamic> json) {
    return SondaggioMattutinoConfig(
      id: json['id'] ?? '',
      corsoId: json['corso'],
      corsoDescrizione: json['corso_nome'] ?? json['corso_descrizione'] ?? '',
      scuolaNome: json['scuola_nome'] ?? '',
      orario: json['orario'] ?? '08:00',
      giorniSettimana: json['giorni_settimana'] ?? '0,1,2,3,4,5,6',
      testo: json['testo'] ?? '',
      isPoll: json['is_poll'] ?? true,
      pollOpzione1: json['poll_opzione_1'] ?? 'Ci sono! 🕺💃',
      pollOpzione2: json['poll_opzione_2'] ?? 'Non ci sono 🚫',
      oreAscoltoRisposte: json['ore_ascolto_risposte'] ?? 5,
      isActive: json['is_active'] ?? true,
      sollecitoAttivo: json['sollecito_attivo'] ?? false,
      sollecitoOreAttesa: json['sollecito_ore_attesa'] ?? 3,
      sollecitoOrario: json['sollecito_orario'] ?? '16:00',
      sollecitoTesto: json['sollecito_testo'] ?? '',
      jollyTesto: json['jolly_testo'] ?? 'Ciao {nickname}! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺',
      moduloTesseramentoTesto: json['modulo_tesseramento_testo'] ?? 'Gentile {nickname}, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all\'ASD TantoTango da compilare e firmare. A presto!',
      ricevutaTesto: json['ricevuta_testo'] ?? 'Gentile {nickname}, in allegato la ricevuta {numero} del {data} di € {importo} per "{causale}".',
      istruzioniPagamentoTesto: json['istruzioni_pagamento_testo'] ?? 'Ciao {nickname}, per effettuare il pagamento della quota a favore di {nome_asd}, puoi effettuare un bonifico alle seguenti coordinate bancarie:\n\nIBAN: {iban}\nIntestato a: {nome_asd}\nCausale: Quota corso {nickname}\n\nGrazie e a presto! 💃🕺',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    if (corsoId != null && corsoId!.isNotEmpty) 'corso': corsoId,
    'orario': orario,
    'giorni_settimana': giorniSettimana,
    'testo': testo,
    'is_poll': isPoll,
    'poll_opzione_1': pollOpzione1,
    'poll_opzione_2': pollOpzione2,
    'ore_ascolto_risposte': oreAscoltoRisposte,
    'is_active': isActive,
    'sollecito_attivo': sollecitoAttivo,
    'sollecito_ore_attesa': sollecitoOreAttesa,
    'sollecito_orario': sollecitoOrario,
    'sollecito_testo': sollecitoTesto,
    'jolly_testo': jollyTesto,
    'modulo_tesseramento_testo': moduloTesseramentoTesto,
    'ricevuta_testo': ricevutaTesto,
    'istruzioni_pagamento_testo': istruzioniPagamentoTesto,
  };
}

class DocumentTemplate {
  final String id;
  final String chiave;
  final String nome;
  final String descrizione;
  final String filename;
  final int fileSize;
  final String? fileUrl;
  final String updatedAt;

  DocumentTemplate({
    required this.id,
    required this.chiave,
    required this.nome,
    required this.descrizione,
    this.filename = '',
    this.fileSize = 0,
    this.fileUrl,
    this.updatedAt = '',
  });

  bool get hasFile => filename.isNotEmpty && fileUrl != null;

  String get fileSizeFormatted {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  factory DocumentTemplate.fromJson(Map<String, dynamic> json) {
    return DocumentTemplate(
      id: json['id'] ?? '',
      chiave: json['chiave'] ?? '',
      nome: json['nome'] ?? '',
      descrizione: json['descrizione'] ?? '',
      filename: json['filename'] ?? '',
      fileSize: json['file_size'] is int
          ? json['file_size']
          : int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      fileUrl: json['file_url'],
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class Ricevuta {
  final String id;
  final int numero;
  final int anno;
  final String data;
  final String intestatario;
  final String causale;
  final double importo;
  final String note;
  final String? allievoId;
  final String? allievoNome;
  final String? allievoTelefono;
  final String? allievoNickname;
  final String? pagamentoId;
  final String? movimentoCassaId;
  final bool inBilancio;
  final String numeroDisplay;
  final String createdAt;
  final String updatedAt;

  Ricevuta({
    required this.id,
    required this.numero,
    required this.anno,
    required this.data,
    required this.intestatario,
    required this.causale,
    required this.importo,
    this.note = '',
    this.allievoId,
    this.allievoNome,
    this.allievoTelefono,
    this.allievoNickname,
    this.pagamentoId,
    this.movimentoCassaId,
    this.inBilancio = false,
    required this.numeroDisplay,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Ricevuta.fromJson(Map<String, dynamic> json) {
    return Ricevuta(
      id: json['id'] ?? '',
      numero: json['numero'] is int
          ? json['numero']
          : int.tryParse(json['numero']?.toString() ?? '0') ?? 0,
      anno: json['anno'] is int
          ? json['anno']
          : int.tryParse(json['anno']?.toString() ?? '2026') ?? 2026,
      data: json['data'] ?? '',
      intestatario: json['intestatario'] ?? '',
      causale: json['causale'] ?? '',
      importo: double.tryParse(json['importo']?.toString() ?? '0.0') ?? 0.0,
      note: json['note'] ?? '',
      allievoId: json['allievo'],
      allievoNome: json['allievo_nome'],
      allievoTelefono: json['allievo_telefono'],
      allievoNickname: json['allievo_nickname'],
      pagamentoId: json['pagamento'],
      movimentoCassaId: json['movimento_cassa']?.toString(),
      inBilancio: json['in_bilancio'] == true || json['movimento_cassa'] != null,
      numeroDisplay: json['numero_display'] ?? 'N. ${json['numero']}/${json['anno']}',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Ricevuta copyWith({
    String? id,
    int? numero,
    int? anno,
    String? data,
    String? intestatario,
    String? causale,
    double? importo,
    String? note,
    String? allievoId,
    String? allievoNome,
    String? allievoTelefono,
    String? pagamentoId,
    String? movimentoCassaId,
    bool? inBilancio,
    String? numeroDisplay,
    String? createdAt,
    String? updatedAt,
  }) {
    return Ricevuta(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      anno: anno ?? this.anno,
      data: data ?? this.data,
      intestatario: intestatario ?? this.intestatario,
      causale: causale ?? this.causale,
      importo: importo ?? this.importo,
      note: note ?? this.note,
      allievoId: allievoId ?? this.allievoId,
      allievoNome: allievoNome ?? this.allievoNome,
      allievoTelefono: allievoTelefono ?? this.allievoTelefono,
      pagamentoId: pagamentoId ?? this.pagamentoId,
      movimentoCassaId: movimentoCassaId ?? this.movimentoCassaId,
      inBilancio: inBilancio ?? this.inBilancio,
      numeroDisplay: numeroDisplay ?? this.numeroDisplay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'anno': anno,
    'data': data,
    'intestatario': intestatario,
    'causale': causale,
    'importo': importo.toStringAsFixed(2),
    'note': note,
    if (allievoId != null) 'allievo': allievoId,
    if (pagamentoId != null) 'pagamento': pagamentoId,
  };
}

class ContatoreRicevuteInfo {
  final int anno;
  final int ultimoNumero;
  final int prossimoNumero;
  final int conteggioEmesse;
  final bool isAnnoCorrente;

  ContatoreRicevuteInfo({
    required this.anno,
    required this.ultimoNumero,
    required this.prossimoNumero,
    required this.conteggioEmesse,
    required this.isAnnoCorrente,
  });

  factory ContatoreRicevuteInfo.fromJson(Map<String, dynamic> json) {
    return ContatoreRicevuteInfo(
      anno: json['anno'] is int ? json['anno'] : int.tryParse(json['anno']?.toString() ?? '2026') ?? 2026,
      ultimoNumero: json['ultimo_numero'] is int ? json['ultimo_numero'] : int.tryParse(json['ultimo_numero']?.toString() ?? '0') ?? 0,
      prossimoNumero: json['prossimo_numero'] is int ? json['prossimo_numero'] : int.tryParse(json['prossimo_numero']?.toString() ?? '1') ?? 1,
      conteggioEmesse: json['conteggio_emesse'] is int ? json['conteggio_emesse'] : int.tryParse(json['conteggio_emesse']?.toString() ?? '0') ?? 0,
      isAnnoCorrente: json['is_anno_corrente'] ?? true,
    );
  }
}

class GoogleDriveConfig {
  final String id;
  final String authType; // 'oauth' or 'service_account'
  final bool isConfigured;
  final bool isSaConfigured;
  final bool isOauthConnected;
  final String oauthClientId;
  final String oauthUserEmail;
  final String oauthUserName;
  final bool hasOauthClientSecret;
  final String filename;
  final int fileSize;
  final String clientEmail;
  final String projectId;
  final String privateKeyId;
  final String folderId;
  final String folderRicevuteId;
  final String folderRicevuteNome;
  final String folderTessereId;
  final String folderTessereNome;
  final String folderVerbaliId;
  final String folderVerbaliNome;
  final bool isActive;
  final String? lastTestedAt;
  final String lastTestStatus;
  final String lastTestMessage;
  final String createdAt;
  final String updatedAt;

  GoogleDriveConfig({
    required this.id,
    this.authType = 'oauth',
    required this.isConfigured,
    this.isSaConfigured = false,
    this.isOauthConnected = false,
    this.oauthClientId = '',
    this.oauthUserEmail = '',
    this.oauthUserName = '',
    this.hasOauthClientSecret = false,
    required this.filename,
    required this.fileSize,
    required this.clientEmail,
    required this.projectId,
    required this.privateKeyId,
    required this.folderId,
    this.folderRicevuteId = '',
    this.folderRicevuteNome = '',
    this.folderTessereId = '',
    this.folderTessereNome = '',
    this.folderVerbaliId = '',
    this.folderVerbaliNome = '',
    required this.isActive,
    this.lastTestedAt,
    required this.lastTestStatus,
    required this.lastTestMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOAuth => authType == 'oauth';

  factory GoogleDriveConfig.fromJson(Map<String, dynamic> json) {
    return GoogleDriveConfig(
      id: json['id'] ?? '',
      authType: json['auth_type'] ?? 'oauth',
      isConfigured: json['is_configured'] ?? false,
      isSaConfigured: json['is_sa_configured'] ?? false,
      isOauthConnected: json['is_oauth_connected'] ?? false,
      oauthClientId: json['oauth_client_id'] ?? '',
      oauthUserEmail: json['oauth_user_email'] ?? '',
      oauthUserName: json['oauth_user_name'] ?? '',
      hasOauthClientSecret: json['has_oauth_client_secret'] ?? false,
      filename: json['filename'] ?? '',
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      clientEmail: json['client_email'] ?? '',
      projectId: json['project_id'] ?? '',
      privateKeyId: json['private_key_id'] ?? '',
      folderId: json['folder_id'] ?? '',
      folderRicevuteId: json['folder_ricevute_id'] ?? '',
      folderRicevuteNome: json['folder_ricevute_nome'] ?? '',
      folderTessereId: json['folder_tessere_id'] ?? '',
      folderTessereNome: json['folder_tessere_nome'] ?? '',
      folderVerbaliId: json['folder_verbali_id'] ?? '',
      folderVerbaliNome: json['folder_verbali_nome'] ?? '',
      isActive: json['is_active'] ?? true,
      lastTestedAt: json['last_tested_at'],
      lastTestStatus: json['last_test_status'] ?? '',
      lastTestMessage: json['last_test_message'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  String get fileSizeFormatted {
    if (fileSize <= 0) return '0 B';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class GoogleContactsConfig {
  final String id;
  final String clientId;
  final bool hasClientSecret;
  final bool isConnected;
  final String userEmail;
  final String userName;
  final String syncGroupName;
  final bool isActive;
  final String? lastSyncAt;
  final String lastTestStatus;
  final String lastTestMessage;
  final String createdAt;
  final String updatedAt;

  GoogleContactsConfig({
    required this.id,
    this.clientId = '',
    this.hasClientSecret = false,
    this.isConnected = false,
    this.userEmail = '',
    this.userName = '',
    this.syncGroupName = 'Allievi Tango',
    this.isActive = true,
    this.lastSyncAt,
    this.lastTestStatus = '',
    this.lastTestMessage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoogleContactsConfig.fromJson(Map<String, dynamic> json) {
    return GoogleContactsConfig(
      id: json['id'] ?? '',
      clientId: json['client_id'] ?? '',
      hasClientSecret: json['has_client_secret'] ?? false,
      isConnected: json['is_connected'] ?? false,
      userEmail: json['user_email'] ?? '',
      userName: json['user_name'] ?? '',
      syncGroupName: json['sync_group_name'] ?? 'Allievi Tango',
      isActive: json['is_active'] ?? true,
      lastSyncAt: json['last_sync_at'],
      lastTestStatus: json['last_test_status'] ?? '',
      lastTestMessage: json['last_test_message'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class GoogleDriveFolderItem {
  final String id;
  final String name;
  final bool isShared;
  final bool isDrive;
  final List<String> parents;

  GoogleDriveFolderItem({
    required this.id,
    required this.name,
    this.isShared = false,
    this.isDrive = false,
    this.parents = const [],
  });

  factory GoogleDriveFolderItem.fromJson(Map<String, dynamic> json) {
    return GoogleDriveFolderItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isShared: json['is_shared'] ?? false,
      isDrive: json['is_drive'] ?? false,
      parents: (json['parents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class MovimentoPrimaNota {
  final String id;
  final String data;
  final String descrizione;
  final String categoria;
  final String tipo; // 'entrata' or 'uscita'
  final String tipoDisplay;
  final double importo;
  final String note;
  final String createdAt;
  final String updatedAt;

  MovimentoPrimaNota({
    required this.id,
    required this.data,
    required this.descrizione,
    required this.categoria,
    required this.tipo,
    required this.tipoDisplay,
    required this.importo,
    this.note = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  bool get isEntrata => tipo == 'entrata';
  bool get isUscita => tipo == 'uscita';

  factory MovimentoPrimaNota.fromJson(Map<String, dynamic> json) {
    return MovimentoPrimaNota(
      id: json['id'] ?? '',
      data: json['data'] ?? '',
      descrizione: json['descrizione'] ?? '',
      categoria: json['categoria'] ?? 'Generale',
      tipo: json['tipo'] ?? 'entrata',
      tipoDisplay: json['tipo_display'] ?? (json['tipo'] == 'uscita' ? 'Uscita' : 'Entrata'),
      importo: double.tryParse(json['importo']?.toString() ?? '0.0') ?? 0.0,
      note: json['note'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'data': data,
    'descrizione': descrizione,
    'categoria': categoria,
    'tipo': tipo,
    'importo': importo.toStringAsFixed(2),
    'note': note,
  };
}

class RiepilogoPrimaNota {
  final int conteggio;
  final double totaleEntrate;
  final double totaleUscite;
  final double saldo;
  final List<String> categorie;
  final List<String> categorieEntrate;
  final List<String> categorieUscite;
  final List<int> anni;

  RiepilogoPrimaNota({
    required this.conteggio,
    required this.totaleEntrate,
    required this.totaleUscite,
    required this.saldo,
    required this.categorie,
    this.categorieEntrate = const [],
    this.categorieUscite = const [],
    required this.anni,
  });

  factory RiepilogoPrimaNota.fromJson(Map<String, dynamic> json) {
    final catList = json['categorie'] as List? ?? [];
    final catEntrateList = json['categorie_entrate'] as List? ?? [];
    final catUsciteList = json['categorie_uscite'] as List? ?? [];
    final anniList = json['anni'] as List? ?? [];
    return RiepilogoPrimaNota(
      conteggio: json['conteggio'] ?? 0,
      totaleEntrate: double.tryParse(json['totale_entrate']?.toString() ?? '0.0') ?? 0.0,
      totaleUscite: double.tryParse(json['totale_uscite']?.toString() ?? '0.0') ?? 0.0,
      saldo: double.tryParse(json['saldo']?.toString() ?? '0.0') ?? 0.0,
      categorie: catList.map((e) => e.toString()).toList(),
      categorieEntrate: catEntrateList.map((e) => e.toString()).toList(),
      categorieUscite: catUsciteList.map((e) => e.toString()).toList(),
      anni: anniList.map((e) => int.tryParse(e.toString()) ?? DateTime.now().year).toList(),
    );
  }
}

class CategoriaBilancio {
  final String id;
  final String nome;
  final String tipo; // 'entrata' o 'uscita'
  final String tipoDisplay;
  final String descrizione;
  final String colore;
  final int ordine;
  final int movimentiCount;
  final String createdAt;
  final String updatedAt;

  CategoriaBilancio({
    required this.id,
    required this.nome,
    required this.tipo,
    this.tipoDisplay = '',
    this.descrizione = '',
    this.colore = '',
    this.ordine = 0,
    this.movimentiCount = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  bool get isEntrata => tipo.toLowerCase() == 'entrata';
  bool get isUscita => tipo.toLowerCase() == 'uscita';

  factory CategoriaBilancio.fromJson(Map<String, dynamic> json) {
    return CategoriaBilancio(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? 'entrata',
      tipoDisplay: json['tipo_display'] ?? (json['tipo'] == 'uscita' ? 'Uscita' : 'Entrata'),
      descrizione: json['descrizione'] ?? '',
      colore: json['colore'] ?? '',
      ordine: json['ordine'] is int
          ? json['ordine']
          : int.tryParse(json['ordine']?.toString() ?? '0') ?? 0,
      movimentiCount: json['movimenti_count'] is int
          ? json['movimenti_count']
          : int.tryParse(json['movimenti_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'tipo': tipo,
    'descrizione': descrizione,
    'colore': colore,
    'ordine': ordine,
  };
}

class MeseBilancio {
  final int mese;
  final String nomeMese;
  final double entrate;
  final double uscite;
  final double saldo;
  final String stato; // 'avanzo', 'perdita', 'pareggio'
  final String statoDisplay;
  final int movimentiCount;

  MeseBilancio({
    required this.mese,
    required this.nomeMese,
    required this.entrate,
    required this.uscite,
    required this.saldo,
    required this.stato,
    required this.statoDisplay,
    required this.movimentiCount,
  });

  bool get isAvanzo => stato == 'avanzo';
  bool get isPerdita => stato == 'perdita';
  bool get isPareggio => stato == 'pareggio';

  factory MeseBilancio.fromJson(Map<String, dynamic> json) {
    return MeseBilancio(
      mese: json['mese'] is int ? json['mese'] : int.tryParse(json['mese']?.toString() ?? '1') ?? 1,
      nomeMese: json['nome_mese'] ?? '',
      entrate: double.tryParse(json['entrate']?.toString() ?? '0.0') ?? 0.0,
      uscite: double.tryParse(json['uscite']?.toString() ?? '0.0') ?? 0.0,
      saldo: double.tryParse(json['saldo']?.toString() ?? '0.0') ?? 0.0,
      stato: json['stato'] ?? 'pareggio',
      statoDisplay: json['stato_display'] ?? (json['stato'] == 'avanzo' ? 'Avanzo' : (json['stato'] == 'perdita' ? 'Perdita' : 'Pareggio')),
      movimentiCount: json['movimenti_count'] is int ? json['movimenti_count'] : int.tryParse(json['movimenti_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class BilancioMensileAnno {
  final int anno;
  final List<int> anniDisponibili;
  final List<MeseBilancio> mesi;
  final double totaleEntrate;
  final double totaleUscite;
  final double saldoTotale;
  final String statoTotale;
  final String statoTotaleDisplay;

  BilancioMensileAnno({
    required this.anno,
    required this.anniDisponibili,
    required this.mesi,
    required this.totaleEntrate,
    required this.totaleUscite,
    required this.saldoTotale,
    required this.statoTotale,
    required this.statoTotaleDisplay,
  });

  bool get isAvanzo => statoTotale == 'avanzo';
  bool get isPerdita => statoTotale == 'perdita';
  bool get isPareggio => statoTotale == 'pareggio';

  factory BilancioMensileAnno.fromJson(Map<String, dynamic> json) {
    final mesiList = json['mesi'] as List? ?? [];
    final anniList = json['anni_disponibili'] as List? ?? [];

    return BilancioMensileAnno(
      anno: json['anno'] is int ? json['anno'] : int.tryParse(json['anno']?.toString() ?? '') ?? DateTime.now().year,
      anniDisponibili: anniList.map((e) => int.tryParse(e.toString()) ?? DateTime.now().year).toList(),
      mesi: mesiList.map((m) => MeseBilancio.fromJson(m)).toList(),
      totaleEntrate: double.tryParse(json['totale_entrate']?.toString() ?? '0.0') ?? 0.0,
      totaleUscite: double.tryParse(json['totale_uscite']?.toString() ?? '0.0') ?? 0.0,
      saldoTotale: double.tryParse(json['saldo_totale']?.toString() ?? '0.0') ?? 0.0,
      statoTotale: json['stato_totale'] ?? 'pareggio',
      statoTotaleDisplay: json['stato_totale_display'] ?? 'Pareggio',
    );
  }
}

class RigaBilancioAnnuale {
  final String categoria;
  final List<double> mesi;
  final double totale;

  RigaBilancioAnnuale({
    required this.categoria,
    required this.mesi,
    required this.totale,
  });

  factory RigaBilancioAnnuale.fromJson(Map<String, dynamic> json) {
    final mesiRaw = json['mesi'] as List? ?? [];
    return RigaBilancioAnnuale(
      categoria: json['categoria'] ?? '',
      mesi: mesiRaw.map((e) => double.tryParse(e.toString()) ?? 0.0).toList(),
      totale: double.tryParse(json['totale']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class TabellaBilancioAnnuale {
  final List<RigaBilancioAnnuale> righe;
  final List<double> totaliMesi;
  final double totaleComplessivo;

  TabellaBilancioAnnuale({
    required this.righe,
    required this.totaliMesi,
    required this.totaleComplessivo,
  });

  factory TabellaBilancioAnnuale.fromJson(Map<String, dynamic> json) {
    final righeRaw = json['righe'] as List? ?? [];
    final totaliRaw = json['totali_mesi'] as List? ?? [];
    return TabellaBilancioAnnuale(
      righe: righeRaw.map((r) => RigaBilancioAnnuale.fromJson(r)).toList(),
      totaliMesi: totaliRaw.map((e) => double.tryParse(e.toString()) ?? 0.0).toList(),
      totaleComplessivo: double.tryParse(json['totale_complessivo']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class BilancioAnnualeData {
  final int anno;
  final List<int> anniDisponibili;
  final List<String> mesiLabels;
  final TabellaBilancioAnnuale entrate;
  final TabellaBilancioAnnuale uscite;
  final List<double> saldoMesi;
  final double saldoComplessivo;

  BilancioAnnualeData({
    required this.anno,
    required this.anniDisponibili,
    required this.mesiLabels,
    required this.entrate,
    required this.uscite,
    required this.saldoMesi,
    required this.saldoComplessivo,
  });

  factory BilancioAnnualeData.fromJson(Map<String, dynamic> json) {
    final anniRaw = json['anni_disponibili'] as List? ?? [];
    final labelsRaw = json['mesi_labels'] as List? ?? [];
    final saldoRaw = json['saldo_mesi'] as List? ?? [];

    return BilancioAnnualeData(
      anno: json['anno'] is int ? json['anno'] : int.tryParse(json['anno']?.toString() ?? '') ?? DateTime.now().year,
      anniDisponibili: anniRaw.map((e) => int.tryParse(e.toString()) ?? DateTime.now().year).toList(),
      mesiLabels: labelsRaw.map((e) => e.toString()).toList(),
      entrate: TabellaBilancioAnnuale.fromJson(json['entrate'] ?? {}),
      uscite: TabellaBilancioAnnuale.fromJson(json['uscite'] ?? {}),
      saldoMesi: saldoRaw.map((e) => double.tryParse(e.toString()) ?? 0.0).toList(),
      saldoComplessivo: double.tryParse(json['saldo_complessivo']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONFIGURAZIONE ASD & DIRETTIVO
// ─────────────────────────────────────────────────────────────

class ConfigurazioneASD {
  final String id;
  final String nome;
  final String codiceFiscale;
  final String partitaIva;
  final String sedeLegale;
  final String sedeOperativa;
  final String telefono;
  final String email;
  final String pec;
  final String sitoWeb;
  final String codiceAffiliazione;
  final String iban;
  final String createdAt;
  final String updatedAt;

  ConfigurazioneASD({
    required this.id,
    this.nome = '',
    this.codiceFiscale = '',
    this.partitaIva = '',
    this.sedeLegale = '',
    this.sedeOperativa = '',
    this.telefono = '',
    this.email = '',
    this.pec = '',
    this.sitoWeb = '',
    this.codiceAffiliazione = '',
    this.iban = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory ConfigurazioneASD.fromJson(Map<String, dynamic> json) {
    return ConfigurazioneASD(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] ?? '',
      codiceFiscale: json['codice_fiscale'] ?? '',
      partitaIva: json['partita_iva'] ?? '',
      sedeLegale: json['sede_legale'] ?? '',
      sedeOperativa: json['sede_operativa'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
      pec: json['pec'] ?? '',
      sitoWeb: json['sito_web'] ?? '',
      codiceAffiliazione: json['codice_affiliazione'] ?? '',
      iban: json['iban'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'codice_fiscale': codiceFiscale,
    'partita_iva': partitaIva,
    'sede_legale': sedeLegale,
    'sede_operativa': sedeOperativa,
    'telefono': telefono,
    'email': email,
    'pec': pec,
    'sito_web': sitoWeb,
    'codice_affiliazione': codiceAffiliazione,
    'iban': iban,
  };

  ConfigurazioneASD copyWith({
    String? id,
    String? nome,
    String? codiceFiscale,
    String? partitaIva,
    String? sedeLegale,
    String? sedeOperativa,
    String? telefono,
    String? email,
    String? pec,
    String? sitoWeb,
    String? codiceAffiliazione,
    String? iban,
    String? createdAt,
    String? updatedAt,
  }) {
    return ConfigurazioneASD(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      codiceFiscale: codiceFiscale ?? this.codiceFiscale,
      partitaIva: partitaIva ?? this.partitaIva,
      sedeLegale: sedeLegale ?? this.sedeLegale,
      sedeOperativa: sedeOperativa ?? this.sedeOperativa,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      pec: pec ?? this.pec,
      sitoWeb: sitoWeb ?? this.sitoWeb,
      codiceAffiliazione: codiceAffiliazione ?? this.codiceAffiliazione,
      iban: iban ?? this.iban,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MembroDirettivo {
  final String id;
  final String ruolo; // 'presidente', 'vicepresidente', 'segretario'
  final String ruoloDisplay;
  final String nome;
  final String cognome;
  final String nomeCompleto;
  final String codiceFiscale;
  final String? dataNascita;
  final String luogoNascita;
  final String telefono;
  final String email;
  final String? firmaUrl;
  final bool hasFirma;
  final int ordine;
  final String createdAt;
  final String updatedAt;

  MembroDirettivo({
    required this.id,
    required this.ruolo,
    this.ruoloDisplay = '',
    this.nome = '',
    this.cognome = '',
    this.nomeCompleto = '',
    this.codiceFiscale = '',
    this.dataNascita,
    this.luogoNascita = '',
    this.telefono = '',
    this.email = '',
    this.firmaUrl,
    this.hasFirma = false,
    this.ordine = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory MembroDirettivo.fromJson(Map<String, dynamic> json) {
    return MembroDirettivo(
      id: json['id']?.toString() ?? '',
      ruolo: json['ruolo'] ?? 'presidente',
      ruoloDisplay: json['ruolo_display'] ?? '',
      nome: json['nome'] ?? '',
      cognome: json['cognome'] ?? '',
      nomeCompleto: json['nome_completo'] ?? '',
      codiceFiscale: json['codice_fiscale'] ?? '',
      dataNascita: json['data_nascita']?.toString(),
      luogoNascita: json['luogo_nascita'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
      firmaUrl: json['firma_url'],
      hasFirma: json['has_firma'] ?? false,
      ordine: json['ordine'] is int ? json['ordine'] : int.tryParse(json['ordine']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'cognome': cognome,
    'codice_fiscale': codiceFiscale,
    'data_nascita': dataNascita,
    'luogo_nascita': luogoNascita,
    'telefono': telefono,
    'email': email,
  };

  MembroDirettivo copyWith({
    String? id,
    String? ruolo,
    String? ruoloDisplay,
    String? nome,
    String? cognome,
    String? nomeCompleto,
    String? codiceFiscale,
    String? dataNascita,
    String? luogoNascita,
    String? telefono,
    String? email,
    String? firmaUrl,
    bool? hasFirma,
    int? ordine,
    String? createdAt,
    String? updatedAt,
  }) {
    return MembroDirettivo(
      id: id ?? this.id,
      ruolo: ruolo ?? this.ruolo,
      ruoloDisplay: ruoloDisplay ?? this.ruoloDisplay,
      nome: nome ?? this.nome,
      cognome: cognome ?? this.cognome,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      codiceFiscale: codiceFiscale ?? this.codiceFiscale,
      dataNascita: dataNascita ?? this.dataNascita,
      luogoNascita: luogoNascita ?? this.luogoNascita,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      firmaUrl: firmaUrl ?? this.firmaUrl,
      hasFirma: hasFirma ?? this.hasFirma,
      ordine: ordine ?? this.ordine,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}








class GoogleContactComparisonRecord {
  final String? systemId;
  final String? googleId;
  final String nome;
  final String cognome;
  final String telefono;
  final String email;
  final bool isProspect;
  final String status;
  final String action;
  final List<String> differences;
  final Map<String, dynamic>? systemData;
  final Map<String, dynamic>? googleData;

  GoogleContactComparisonRecord({
    this.systemId,
    this.googleId,
    required this.nome,
    required this.cognome,
    required this.telefono,
    required this.email,
    required this.isProspect,
    required this.status,
    required this.action,
    required this.differences,
    this.systemData,
    this.googleData,
  });

  String get nomeCompleto => '$nome $cognome'.trim();

  String get statusDisplay {
    switch (status) {
      case 'synced':
        return 'Sincronizzato';
      case 'modified_system':
        return 'Modificato nel sistema';
      case 'modified_google':
        return 'Modificato su Google';
      case 'only_system':
        return 'Presente solo nel sistema';
      case 'only_google':
        return 'Presente solo su Google';
      default:
        return status;
    }
  }

  factory GoogleContactComparisonRecord.fromJson(Map<String, dynamic> json) {
    return GoogleContactComparisonRecord(
      systemId: json['system_id'],
      googleId: json['google_id'],
      nome: json['nome'] ?? '',
      cognome: json['cognome'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
      isProspect: json['is_prospect'] ?? false,
      status: json['status'] ?? 'synced',
      action: json['action'] ?? 'none',
      differences: (json['differences'] as List?)?.map((e) => e.toString()).toList() ?? [],
      systemData: json['system_data'] is Map ? Map<String, dynamic>.from(json['system_data']) : null,
      googleData: json['google_data'] is Map ? Map<String, dynamic>.from(json['google_data']) : null,
    );
  }
}

class GoogleContactComparisonReport {
  final bool connected;
  final String? message;
  final String? error;
  final String? userEmail;
  final DateTime? lastSyncAt;
  final String lastSyncStatus;
  final String? lastSyncSummary;
  final Map<String, int> stats;
  final List<GoogleContactComparisonRecord> records;

  GoogleContactComparisonReport({
    required this.connected,
    this.message,
    this.error,
    this.userEmail,
    this.lastSyncAt,
    required this.lastSyncStatus,
    this.lastSyncSummary,
    required this.stats,
    required this.records,
  });

  factory GoogleContactComparisonReport.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'] is Map ? json['stats'] as Map : {};
    final statsMap = {
      'total': (rawStats['total'] as num?)?.toInt() ?? 0,
      'synced': (rawStats['synced'] as num?)?.toInt() ?? 0,
      'modified_system': (rawStats['modified_system'] as num?)?.toInt() ?? 0,
      'modified_google': (rawStats['modified_google'] as num?)?.toInt() ?? 0,
      'only_system': (rawStats['only_system'] as num?)?.toInt() ?? 0,
      'only_google': (rawStats['only_google'] as num?)?.toInt() ?? 0,
    };

    final rawRecords = json['records'] as List? ?? [];
    return GoogleContactComparisonReport(
      connected: json['connected'] ?? false,
      message: json['message'],
      error: json['error'],
      userEmail: json['user_email'],
      lastSyncAt: json['last_sync_at'] != null ? DateTime.tryParse(json['last_sync_at']) : null,
      lastSyncStatus: json['last_sync_status'] ?? '',
      lastSyncSummary: json['last_sync_summary'],
      stats: statsMap,
      records: rawRecords.map((r) => GoogleContactComparisonRecord.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }
}

class GoogleContactsSyncLog {
  final String id;
  final String timestampDisplay;
  final String status;
  final String action;
  final String details;
  final int itemsCreated;
  final int itemsUpdated;
  final int itemsDeleted;
  final int errorsCount;

  GoogleContactsSyncLog({
    required this.id,
    required this.timestampDisplay,
    required this.status,
    required this.action,
    required this.details,
    required this.itemsCreated,
    required this.itemsUpdated,
    required this.itemsDeleted,
    required this.errorsCount,
  });

  factory GoogleContactsSyncLog.fromJson(Map<String, dynamic> json) {
    return GoogleContactsSyncLog(
      id: json['id'] ?? '',
      timestampDisplay: json['timestamp_display'] ?? '',
      status: json['status'] ?? 'success',
      action: json['action'] ?? '',
      details: json['details'] ?? '',
      itemsCreated: (json['items_created'] as num?)?.toInt() ?? 0,
      itemsUpdated: (json['items_updated'] as num?)?.toInt() ?? 0,
      itemsDeleted: (json['items_deleted'] as num?)?.toInt() ?? 0,
      errorsCount: (json['errors_count'] as num?)?.toInt() ?? 0,
    );
  }
}
