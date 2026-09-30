import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PdfReportService {
  /// Genera e mostra il PDF di appello per la lezione selezionata
  static Future<void> generaFoglioAppello({
    required BuildContext context,
    required Lezione lezione,
    required List<Presenza> presenze,
    String? scuolaNome,
  }) async {
    // 1. Filtra solo i presenti
    final presenti = presenze.where((p) => p.presente).toList();

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
            'Generato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} - WAManager',
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
}
