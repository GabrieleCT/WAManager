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
      prospectsCount: json['prospects_count'] ?? 0,
      pagantiCount: json['paganti_count'] ?? 0,
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
  final bool inGruppoCorsoWhatsapp;
  final String? corsoGruppoWhatsapp;
  final bool corsoHasWhatsapp;
  final String numeroTessera;
  final String? dataEmissioneTessera;
  final String statoTessera;

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
    this.inGruppoCorsoWhatsapp = false,
    this.corsoGruppoWhatsapp,
    this.corsoHasWhatsapp = false,
    this.numeroTessera = '',
    this.dataEmissioneTessera,
    this.statoTessera = 'NON TESSERATO',
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
      inGruppoCorsoWhatsapp: json['in_gruppo_corso_whatsapp'] ?? false,
      corsoGruppoWhatsapp: json['corso_gruppo_whatsapp'],
      corsoHasWhatsapp: json['corso_has_whatsapp'] ?? false,
      numeroTessera: json['numero_tessera'] ?? '',
      dataEmissioneTessera: json['data_emissione_tessera'],
      statoTessera: json['stato_tessera'] ?? 'NON TESSERATO',
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
    'numero_tessera': numeroTessera,
    'data_emissione_tessera': dataEmissioneTessera,
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

  bool? presente;
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
    this.presente,
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
      presente: json['presente'],
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
  final String causale;
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
    this.causale = '',
    this.note = '',
  });

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
      corsoId: json['corso'] ?? '',
      corsoDescrizione: json['corso_descrizione'] ?? '',
      scuolaNome: json['scuola_nome'] ?? '',
      importo: double.tryParse(json['importo']?.toString() ?? '150.0') ?? 150.0,
      trimestre: json['trimestre'] ?? 'T1',
      trimestreDisplay: json['trimestre_display'] ?? json['trimestre'] ?? '',
      dataPagamento: json['data_pagamento'] ?? '',
      causale: json['causale'] ?? '',
      note: json['note'] ?? '',
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
  final String sollecitoOrario;
  final String sollecitoTesto;
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
    this.sollecitoOrario = '16:00',
    this.sollecitoTesto = '',
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
      sollecitoOrario: json['sollecito_orario'] ?? '16:00',
      sollecitoTesto: json['sollecito_testo'] ?? '',
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
    'sollecito_orario': sollecitoOrario,
    'sollecito_testo': sollecitoTesto,
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
      numeroDisplay: json['numero_display'] ?? 'N. ${json['numero']}/${json['anno']}',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
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
  final bool isConfigured;
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
  final bool isActive;
  final String? lastTestedAt;
  final String lastTestStatus;
  final String lastTestMessage;
  final String createdAt;
  final String updatedAt;

  GoogleDriveConfig({
    required this.id,
    required this.isConfigured,
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
    required this.isActive,
    this.lastTestedAt,
    required this.lastTestStatus,
    required this.lastTestMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoogleDriveConfig.fromJson(Map<String, dynamic> json) {
    return GoogleDriveConfig(
      id: json['id'] ?? '',
      isConfigured: json['is_configured'] ?? false,
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



