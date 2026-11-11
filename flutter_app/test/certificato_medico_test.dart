import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wamanager_flutter/models/models.dart';
import 'package:wamanager_flutter/widgets/manual_date_field.dart';

void main() {
  test('Allievo serializes scadenza_certificato_medico and computes status', () {
    final futureStr = DateFormat('yyyy-MM-dd').format(
      DateTime.now().add(const Duration(days: 30)),
    );
    final pastStr = DateFormat('yyyy-MM-dd').format(
      DateTime.now().subtract(const Duration(days: 5)),
    );

    final baseJson = {
      'id': '1',
      'nome': 'Giulia',
      'cognome': 'Verdi',
      'ruolo': 'follower',
      'ruolo_display': 'Follower',
      'telefono': '+393330001122',
      'recensione': 'no',
      'recensione_display': 'No',
      'livello': 'intermedio',
      'livello_display': 'Intermedio',
    };

    final senza = Allievo.fromJson({...baseJson, 'scadenza_certificato_medico': null});
    expect(senza.isSenzaCertificatoMedico, isTrue);
    expect(senza.hasCertificatoMedico, isFalse);
    expect(senza.isCertificatoMedicoValido, isFalse);
    expect(senza.isCertificatoMedicoScaduto, isFalse);

    final valido = Allievo.fromJson({...baseJson, 'scadenza_certificato_medico': futureStr});
    expect(valido.isSenzaCertificatoMedico, isFalse);
    expect(valido.hasCertificatoMedico, isTrue);
    expect(valido.isCertificatoMedicoValido, isTrue);
    expect(valido.isCertificatoMedicoScaduto, isFalse);
    expect(valido.toJson()['scadenza_certificato_medico'], futureStr);

    final scaduto = Allievo.fromJson({...baseJson, 'scadenza_certificato_medico': pastStr});
    expect(scaduto.isSenzaCertificatoMedico, isFalse);
    expect(scaduto.hasCertificatoMedico, isTrue);
    expect(scaduto.isCertificatoMedicoValido, isFalse);
    expect(scaduto.isCertificatoMedicoScaduto, isTrue);
  });

  test('parseItalianDateToIso and formatIsoDateToItalian handle valid, empty and invalid dates', () {
    expect(formatIsoDateToItalian('2027-05-20'), '20/05/2027');
    expect(formatIsoDateToItalian(null), '');

    final empty = parseItalianDateToIso('');
    expect(empty.isValid, isTrue);
    expect(empty.isoDate, isNull);

    final validFuture = parseItalianDateToIso('31/12/2028', minYear: 2000, maxYear: 2100);
    expect(validFuture.isValid, isTrue);
    expect(validFuture.isoDate, '2028-12-31');

    final invalidDay = parseItalianDateToIso('31/02/2027', minYear: 2000, maxYear: 2100);
    expect(invalidDay.isValid, isFalse);
    expect(invalidDay.isoDate, isNull);
  });

  testWidgets('ManualDateField supports manual typing without date picker and clear button', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualDateField(
            controller: controller,
            labelText: 'Scadenza Certificato Medico',
            clearTooltip: 'Rimuovi scadenza certificato medico',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '20052027');
    await tester.pump();

    expect(controller.text, '20/05/2027');
    expect(find.byType(DatePickerDialog), findsNothing);

    await tester.tap(find.byTooltip('Rimuovi scadenza certificato medico'));
    await tester.pump();

    expect(controller.text, isEmpty);
    controller.dispose();
  });
}
