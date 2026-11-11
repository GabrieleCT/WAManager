import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/models/models.dart';
import 'package:wamanager_flutter/services/api_service.dart';
import 'package:wamanager_flutter/widgets/invia_modulo_tesseramento_dialog.dart';

class _FakeApiService implements ApiService {
  String? lastAllievoId;
  String? lastTelefono;
  String? lastMessaggio;

  @override
  Future<SondaggioMattutinoConfig?> getDaemonConfig() async => null;

  @override
  Future<Map<String, dynamic>> sendModuloTesseramentoWhatsApp({
    required String allievoId,
    required String telefono,
    String? messaggio,
  }) async {
    lastAllievoId = allievoId;
    lastTelefono = telefono;
    lastMessaggio = messaggio;
    return {
      'success': true,
      'message': 'Modulo di tesseramento inviato con successo!',
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Allievo _makeProspect({String telefono = '393401234567'}) {
  return Allievo(
    id: 'prospect-1',
    nome: 'Luca',
    cognome: 'Verdi',
    ruolo: 'leader',
    ruoloDisplay: 'Leader',
    telefono: telefono,
    recensione: 'no',
    recensioneDisplay: 'No',
    livello: 'principiante',
    livelloDisplay: 'Principiante',
    isProspect: true,
  );
}

void main() {
  testWidgets('mostraInviaModuloTesseramentoDialog supports prospects and submits WhatsApp send', (WidgetTester tester) async {
    final fakeApi = _FakeApiService();
    final prospect = _makeProspect();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => mostraInviaModuloTesseramentoDialog(
                context,
                prospect,
                api: fakeApi,
              ),
              child: const Text('Apri Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Invia Modulo Tesseramento'), findsOneWidget);
    expect(find.textContaining('Prospect: Luca Verdi'), findsOneWidget);
    expect(find.text('Numero registrato per il prospect'), findsOneWidget);

    await tester.tap(find.text('Invia PDF via WhatsApp'));
    await tester.pumpAndSettle();

    expect(fakeApi.lastAllievoId, 'prospect-1');
    expect(fakeApi.lastTelefono, '393401234567');
    expect(fakeApi.lastMessaggio, contains('Gentile Luca'));
    expect(find.text('Modulo di tesseramento inviato con successo!'), findsOneWidget);
  });

  testWidgets('mostraInviaModuloTesseramentoDialog clears TBD phone for prospects', (WidgetTester tester) async {
    final fakeApi = _FakeApiService();
    final prospect = _makeProspect(telefono: 'TBD');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => mostraInviaModuloTesseramentoDialog(
                context,
                prospect,
                api: fakeApi,
              ),
              child: const Text('Apri Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('TBD'), findsNothing);
    expect(find.text('Inserisci il numero con prefisso internazionale (es. 39...)'), findsOneWidget);
  });
}
