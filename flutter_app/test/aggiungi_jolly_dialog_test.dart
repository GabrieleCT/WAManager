import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/models/models.dart';
import 'package:wamanager_flutter/screens/gestione_presenze_screen.dart';
import 'package:wamanager_flutter/widgets/aggiungi_jolly_dialog.dart';

void main() {
  testWidgets('GestionePresenzeScreen does not show Jolly subsection tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GestionePresenzeScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Gestione Presenze'), findsOneWidget);
  });

  testWidgets(
      'AggiungiJollyDialog filters by name, ruolo and scuola and submits editable WhatsApp preview',
      (tester) async {
    final scuole = [
      Scuola(id: 's1', nome: 'Sede Centro', sede: 'Milano', gruppoWhatsapp: ''),
      Scuola(id: 's2', nome: 'Sede Nord', sede: 'Monza', gruppoWhatsapp: ''),
    ];
    final lezione = Lezione(
      id: 'l1',
      corsoId: 'c1',
      corsoDescrizione: 'Sede Centro - Principianti (20:30)',
      data: '2026-11-12',
    );
    final allievi = [
      Allievo(
        id: 'a1',
        nome: 'Mario',
        cognome: 'Rossi',
        nickname: 'SuperMario',
        ruolo: 'leader',
        ruoloDisplay: 'Leader',
        telefono: '+393331111111',
        scuolaId: 's1',
        scuolaNome: 'Sede Centro',
        recensione: 'no',
        recensioneDisplay: 'No',
        livello: 'principiante',
        livelloDisplay: 'Principianti',
      ),
      Allievo(
        id: 'a2',
        nome: 'Laura',
        cognome: 'Bianchi',
        nickname: 'Laury',
        ruolo: 'follower',
        ruoloDisplay: 'Follower',
        telefono: '+393332222222',
        scuolaId: 's2',
        scuolaNome: 'Sede Nord',
        recensione: 'no',
        recensioneDisplay: 'No',
        livello: 'intermedio',
        livelloDisplay: 'Intermedio',
      ),
    ];

    Allievo? submittedAllievo;
    String? submittedTesto;
    bool? submittedInviaWa;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AggiungiJollyDialog(
                    lezione: lezione,
                    presenze: const [],
                    scuole: scuole,
                    infoBilanciamento: 'Serve 1 Follower',
                    initialAllievi: allievi,
                    initialJollyTemplate: 'Ciao {nickname}, puoi fare da Jolly?',
                    onSubmit: (a, testo, inviaWa) async {
                      submittedAllievo = a;
                      submittedTesto = testo;
                      submittedInviaWa = inviaWa;
                      return {'success': true};
                    },
                  ),
                );
              },
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Laura Bianchi'), findsOneWidget);

    // Filter by ruolo = Follower
    await tester.tap(find.text('Tutti i ruoli'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follower').last);
    await tester.pumpAndSettle();

    expect(find.text('Mario Rossi'), findsNothing);
    expect(find.text('Laura Bianchi'), findsOneWidget);

    // Filter by scuola = Sede Nord
    await tester.tap(find.text('Tutte le scuole'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sede Nord').last);
    await tester.pumpAndSettle();
    expect(find.text('Laura Bianchi'), findsOneWidget);

    // Filter by free-text search on name/surname
    await tester.enterText(find.byType(TextField).first, 'Bianchi');
    await tester.pumpAndSettle();
    expect(find.text('Laura Bianchi'), findsOneWidget);

    // Select Laura Bianchi and edit the WhatsApp preview
    await tester.tap(find.text('Laura Bianchi'));
    await tester.pumpAndSettle();

    expect(find.text('Ciao Laury, puoi fare da Jolly?'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Testo messaggio (modificabile)',
      ),
      'Ciao Laury, ci sei stasera come Jolly alle 20:30?',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggiungi e Invia WhatsApp'));
    await tester.pumpAndSettle();

    expect(submittedAllievo?.id, 'a2');
    expect(submittedTesto, 'Ciao Laury, ci sei stasera come Jolly alle 20:30?');
    expect(submittedInviaWa, isTrue);
  });
}
