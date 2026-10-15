import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PdfReportService {
  /// Genera e mostra il PDF con l'elenco degli iscritti di un corso
  static Future<void> generaElencoCorso({
    required BuildContext context,
    required Corso corso,
    required List<Allievo> iscritti,
    required List<Allievo> prospects,
  }) async {
    final tutti = [...iscritti, ...prospects];
    tutti.sort((a, b) => a.cognome.compareTo(b.cognome));

    if (tutti.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun iscritto o prospect trovato per questo corso.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final doc = pw.Document(
      title: 'Elenco Iscritti - ${corso.scuolaNome} ${corso.livelloDisplay}',
      author: 'TantoTango Manager',
    );

    // Dati di sintesi
    final leaderCount = iscritti.where((a) => a.ruolo == 'leader').length;
    final followerCount = iscritti.where((a) => a.ruolo == 'follower').length;
    final prospectCount = prospects.length;
    final totale = tutti.length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildElencoHeader(corso, leaderCount, followerCount, prospectCount, totale),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          _buildElencoTable(tutti),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Elenco_Corso_${corso.id}.pdf',
    );
  }

  static pw.Widget _buildElencoHeader(Corso c, int leaderCount, int followerCount, int prospectCount, int totale) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ELENCO ISCRITTI E PROSPECT',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${c.scuolaNome} - ${c.livelloDisplay}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '${c.giornoSettimanaDisplay} - Ore ${c.orario}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.indigo200, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Totale: $totale', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Text('Iscritti: ${totale - prospectCount}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Text('Leader: $leaderCount  |  Follower: $followerCount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Text('In Prova (Prospect): $prospectCount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.8, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildElencoTable(List<Allievo> tutti) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(25),  // N
        1: pw.FlexColumnWidth(3),    // Nome
        2: pw.FlexColumnWidth(3),    // Cognome
        3: pw.FlexColumnWidth(2),    // Ruolo
        4: pw.FlexColumnWidth(3),    // Telefono
        5: pw.FlexColumnWidth(3),    // Partner
        6: pw.FixedColumnWidth(45),  // Stato (Iscritto/Prova)
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo800),
          children: [
            _buildHeaderCell('N.', align: pw.TextAlign.center),
            _buildHeaderCell('Nome'),
            _buildHeaderCell('Cognome'),
            _buildHeaderCell('Ruolo', align: pw.TextAlign.center),
            _buildHeaderCell('Telefono', align: pw.TextAlign.center),
            _buildHeaderCell('Partner'),
            _buildHeaderCell('Stato', align: pw.TextAlign.center),
          ],
        ),
        for (int i = 0; i < tutti.length; i++)
          _buildElencoRow(i + 1, tutti[i], isEven: i % 2 == 0),
      ],
    );
  }

  static pw.TableRow _buildElencoRow(int index, Allievo a, {required bool isEven}) {
    final bgColor = isEven ? PdfColors.white : PdfColors.grey50;
    final isProva = a.isProspect;
    final ruoloDisplay = a.ruolo.toLowerCase() == 'leader' ? 'Leader' : 'Follower';

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text('$index', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(a.nome, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(a.cognome, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            ruoloDisplay,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: ruoloDisplay == 'Leader' ? PdfColors.blue800 : PdfColors.purple800,
            ),
          ),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(a.telefono, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(a.partnerNomeCompleto, style: pw.TextStyle(fontSize: 9, color: PdfColors.pink800)),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            isProva ? 'PROVA' : 'ISCRITTO',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isProva ? PdfColors.orange800 : PdfColors.green800,
            ),
          ),
        ),
      ],
    );
  }

  /// Genera e mostra il PDF di appello per la lezione selezionata
  static Future<void> generaFoglioAppello({
    required BuildContext context,
    required Lezione lezione,
    required List<Presenza> presenze,
    String? scuolaNome,
  }) async {
    // 1. Filtra solo i presenti
    final presenti = presenze.where((p) => p.presente == true).toList();

    if (presenti.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun allievo o prospect presente per questa lezione. Impossibile generare il PDF.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Ordinamento: non-jolly con coppie vicine, e i jolly in fondo
    final ordinati = _ordinaPresenzePerReport(presenti);

    // 3. Calcolo statistiche
    final leaderCount = ordinati.where((p) => p.allievoRuolo.toLowerCase() == 'leader').length;
    final followerCount = ordinati.where((p) => p.allievoRuolo.toLowerCase() == 'follower').length;
    final jollyCount = ordinati.where((p) => p.isJolly).length;
    final provaCount = ordinati.where((p) => p.allievoIsProspect).length;

    // 4. Formattazione data
    String dataFormattata = lezione.data;
    final parsedDate = DateTime.tryParse(lezione.data);
    if (parsedDate != null) {
      const giorni = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
      final giorno = giorni[parsedDate.weekday - 1];
      dataFormattata = '$giorno ${DateFormat('dd/MM/yyyy').format(parsedDate)}';
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        header: (pw.Context ctx) => _buildHeader(
          lezione: lezione,
          scuolaNome: scuolaNome ?? lezione.scuolaNome ?? '',
          dataFormattata: dataFormattata,
          totale: ordinati.length,
          leaderCount: leaderCount,
          followerCount: followerCount,
          jollyCount: jollyCount,
          provaCount: provaCount,
        ),
        footer: (pw.Context ctx) => _buildFooter(ctx),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 12),
          _buildTable(ordinati),
        ],
      ),
    );

    // 5. Anteprima e stampa/download tramite printing
    final fileName = 'Appello_${lezione.corsoDescrizione.replaceAll(RegExp(r'[^\w\d_-]'), '_')}_${lezione.data}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: fileName,
    );
  }

  /// Ordina mettendo le coppie vicine e i jolly in fondo
  static List<Presenza> _ordinaPresenzePerReport(List<Presenza> presenti) {
    final nonJolly = presenti.where((p) => !p.isJolly).toList();
    final jolly = presenti.where((p) => p.isJolly).toList();

    // Ordina i non-jolly con partner raggruppati
    nonJolly.sort((a, b) => a.allievoSortName.compareTo(b.allievoSortName));

    final result = <Presenza>[];
    final visited = <String>{};

    for (final p in nonJolly) {
      if (visited.contains(p.allievoId)) continue;
      visited.add(p.allievoId);

      // Se ha un partner presente nella lista, ordiniamo la coppia (es. Leader prima, poi Follower)
      if (p.allievoPartnerId != null) {
        final partner = nonJolly.where((other) => other.allievoId == p.allievoPartnerId).firstOrNull;
        if (partner != null && !visited.contains(partner.allievoId)) {
          visited.add(partner.allievoId);
          if (p.allievoRuolo.toLowerCase() == 'leader') {
            result.add(p);
            result.add(partner);
          } else {
            result.add(partner);
            result.add(p);
          }
          continue;
        }
      }

      result.add(p);
    }

    // Jolly ordinati in fondo
    jolly.sort((a, b) => a.cleanNome.compareTo(b.cleanNome));
    result.addAll(jolly);

    return result;
  }

  static pw.Widget _buildHeader({
    required Lezione lezione,
    required String scuolaNome,
    required String dataFormattata,
    required int totale,
    required int leaderCount,
    required int followerCount,
    required int jollyCount,
    required int provaCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FOGLIO APPELLO LEZIONE',
                  style: const pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Corso: ${lezione.corsoDescrizione}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                if (scuolaNome.isNotEmpty)
                  pw.Text(
                    'Sede: $scuolaNome',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  dataFormattata,
                  style: const pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                if (lezione.argomentoTitolo != null && lezione.argomentoTitolo!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Argomento: ${lezione.argomentoTitolo}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Barra riepilogativa statistiche
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.indigo200, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Totale Presenti: $totale',
                style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
              pw.Text(
                'Leader: $leaderCount  |  Follower: $followerCount',
                style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
              pw.Text(
                'Jolly: $jollyCount  |  In Prova: $provaCount',
                style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.8, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildTable(List<Presenza> presenze) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(30),  // Numero
        1: pw.FlexColumnWidth(3.2), // Nome
        2: pw.FlexColumnWidth(3.2), // Cognome
        3: pw.FlexColumnWidth(2.2), // Ruolo
        4: pw.FixedColumnWidth(48),  // PROVA
        5: pw.FixedColumnWidth(48),  // JOLLY
        6: pw.FixedColumnWidth(55),  // Presente (appello a lezione)
      },
      children: [
        // Intestazione tabella
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo800),
          children: [
            _buildHeaderCell('N°', align: pw.TextAlign.center),
            _buildHeaderCell('Nome'),
            _buildHeaderCell('Cognome'),
            _buildHeaderCell('Ruolo', align: pw.TextAlign.center),
            _buildHeaderCell('PROVA', align: pw.TextAlign.center),
            _buildHeaderCell('JOLLY', align: pw.TextAlign.center),
            _buildHeaderCell('Presente', align: pw.TextAlign.center),
          ],
        ),
        // Righe studenti
        for (int i = 0; i < presenze.length; i++)
          _buildRow(i + 1, presenze[i], isEven: i % 2 == 0),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.TableRow _buildRow(int index, Presenza p, {required bool isEven}) {
    final bgColor = isEven ? PdfColors.white : PdfColors.grey50;

    final ruoloDisplay = p.allievoRuolo.toLowerCase() == 'leader' ? 'Leader' : 'Follower';
    final isProva = p.allievoIsProspect;
    final isJolly = p.isJolly;

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        // 1. Numero progressivo
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            '$index',
            style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
        ),
        // 2. Nome
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            p.nomeSolo,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        // 3. Cognome
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(
            p.cognomeSolo,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        // 4. Ruolo
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            ruoloDisplay,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: ruoloDisplay == 'Leader' ? PdfColors.blue800 : PdfColors.purple800,
            ),
          ),
        ),
        // 5. PROVA (Sì/No)
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            isProva ? 'Sì' : 'No',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isProva ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isProva ? PdfColors.orange800 : PdfColors.grey600,
            ),
          ),
        ),
        // 6. JOLLY (Sì/No)
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Text(
            isJolly ? 'Sì' : 'No',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isJolly ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isJolly ? PdfColors.purple800 : PdfColors.grey600,
            ),
          ),
        ),
        // 7. Presente: casella vuota per l'appello a mano
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pw.Container(
            width: 14,
            height: 14,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700, width: 1.2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} - TantoTango Manager',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Pagina ${ctx.pageNumber} di ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
  /// Genera e mostra il PDF con il report dei pagamenti
  static Future<void> generaReportPagamenti({
    required BuildContext context,
    required List<Pagamento> pagamenti,
    String? filtriAttivi,
  }) async {
    if (pagamenti.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun pagamento trovato con i filtri correnti.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totale = pagamenti.fold<double>(0.0, (sum, p) => sum + p.importo);

    final doc = pw.Document(
      title: 'Report Pagamenti',
      author: 'TantoTango Manager',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              title: 'Report Pagamenti',
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Report Pagamenti', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
            ),
            if (filtriAttivi != null && filtriAttivi.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text('Filtri: $filtriAttivi', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo400),
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                ['Trimestre', 'Data', 'Allievo', 'Corso/Scuola', 'Causale', 'Importo'],
                ...pagamenti.map((p) => [
                      p.trimestre,
                      p.dataPagamento,
                      p.allievoNome,
                      '${p.scuolaNome} - ${p.corsoDescrizione}',
                      p.causaleDisplay,
                      'E. ${p.importo.toStringAsFixed(2)}',
                    ])
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Totale Incassato: E. ${totale.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Report_Pagamenti_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  /// Genera la ricevuta per un singolo pagamento
  static Future<void> generaRicevutaPagamento({
    required BuildContext context,
    required Pagamento pagamento,
  }) async {
    final doc = pw.Document(
      title: 'Ricevuta Pagamento - ${pagamento.allievoNome}',
      author: 'TantoTango Manager',
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TantoTango ASD', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.Text('Associazione Sportiva Dilettantistica', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('RICEVUTA DI PAGAMENTO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Data: ${pagamento.dataPagamento}', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('ID: ${pagamento.id.split('-').first.toUpperCase()}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 1.5),
              pw.SizedBox(height: 20),
              pw.Text('Dettagli Allievo', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
              pw.SizedBox(height: 8),
              pw.Text('Nome: ${pagamento.allievoNome}', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Text('Dettagli Iscrizione', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
              pw.SizedBox(height: 8),
              pw.Text('Scuola: ${pagamento.scuolaNome}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Corso: ${pagamento.corsoDescrizione}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Trimestre: ${pagamento.trimestreDisplay}', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text('Causale: ${pagamento.causaleDisplay}', style: const pw.TextStyle(fontSize: 14)),
              if (pagamento.note.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('Note: ${pagamento.note}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
              ],
              pw.SizedBox(height: 40),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('IMPORTO PAGATO:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('E. ${pagamento.importo.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Documento generato automaticamente - TantoTango Manager', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Ricevuta_${pagamento.allievoNome.replaceAll(' ', '_')}_${pagamento.dataPagamento}.pdf',
    );
  }

  /// Genera la ricevuta fiscale per un'istanza di Ricevuta
  static Future<void> generaRicevutaFiscale({
    required BuildContext context,
    required Ricevuta ricevuta,
  }) async {
    final doc = pw.Document(
      title: 'Ricevuta ${ricevuta.numeroDisplay} - ${ricevuta.intestatario}',
      author: 'TantoTango Manager',
    );

    String dataFormattata = ricevuta.data;
    final parsedDate = DateTime.tryParse(ricevuta.data);
    if (parsedDate != null) {
      dataFormattata = DateFormat('dd/MM/yyyy').format(parsedDate);
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TantoTango ASD', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.Text('Associazione Sportiva Dilettantistica', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('Attività sportiva dilettantistica e culturale', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.indigo50,
                          border: pw.Border.all(color: PdfColors.indigo300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          'RICEVUTA ${ricevuta.numeroDisplay}',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Data: $dataFormattata', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400, thickness: 1.5),
              pw.SizedBox(height: 20),
              pw.Text('Intestatario / Ricevuto Da', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(ricevuta.intestatario, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 24),
              pw.Text('Dettaglio Versamento', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 100,
                    child: pw.Text('Causale:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  ),
                  pw.Expanded(
                    child: pw.Text(ricevuta.causale, style: const pw.TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              if (ricevuta.note.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text('Note:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    ),
                    pw.Expanded(
                      child: pw.Text(ricevuta.note, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 35),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  border: pw.Border.all(color: PdfColors.teal300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('IMPORTO CORRISPOSTO:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('E. ${ricevuta.importo.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Operazione fuori campo IVA ai sensi dell\'art. 4 del D.P.R. 633/1972 e successive modificazioni.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TantoTango ASD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 30),
                      pw.Text('Firma e timbro del ricevente', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 30),
                      pw.Container(width: 160, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma per quietanza', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Documento gestionale generato tramite TantoTango Manager', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Ricevuta_${ricevuta.numero}_${ricevuta.anno}_${ricevuta.intestatario.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Genera e mostra il PDF con il report di tutte le ricevute
  static Future<void> generaReportRicevute({
    required BuildContext context,
    required List<Ricevuta> ricevute,
    required int? anno,
  }) async {
    if (ricevute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuna ricevuta presente per l\'esportazione.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totale = ricevute.fold<double>(0.0, (sum, r) => sum + r.importo);

    final doc = pw.Document(
      title: 'Elenco Ricevute ${anno != null ? anno.toString() : ''}',
      author: 'TantoTango Manager',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              title: 'Elenco Ricevute Emesse',
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Elenco Ricevute Emesse ${anno != null ? "Anno $anno" : ""}',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo500),
              cellAlignment: pw.Alignment.centerLeft,
              data: [
                ['Numero', 'Data', 'Intestatario', 'Causale', 'Importo'],
                ...ricevute.map((r) => [
                      r.numeroDisplay,
                      r.data,
                      r.intestatario,
                      r.causale,
                      'E. ${r.importo.toStringAsFixed(2)}',
                    ])
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Totale Ricevute: ${ricevute.length}   |   Totale Incassato: E. ${totale.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Elenco_Ricevute_${anno ?? "Tutti"}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}

