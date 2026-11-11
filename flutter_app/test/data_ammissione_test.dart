import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/models/models.dart';
import 'package:wamanager_flutter/widgets/data_ammissione_field.dart';

void main() {
  test('Allievo serializes and deserializes data_ammissione', () {
    final allievo = Allievo.fromJson({
      'id': '1',
      'nome': 'Mario',
      'cognome': 'Rossi',
      'ruolo': 'L',
      'ruolo_display': 'Leader',
      'telefono': '+393331112233',
      'recensione': 'N',
      'recensione_display': 'Nessuna',
      'livello': 'PRINCIPIANTI',
      'livello_display': 'Principianti',
      'tessera_associativa': '42',
      'data_ammissione': '2026-03-15',
    });

    expect(allievo.tesseraAssociativa, '42');
    expect(allievo.dataAmmissione, '2026-03-15');
    expect(allievo.toJson()['data_ammissione'], '2026-03-15');
    expect(allievo.toJson().containsKey('data_emissione_tessera'), isFalse);
  });

  testWidgets('DataAmmissioneField displays value and clears on button tap', (
    tester,
  ) async {
    final controller = TextEditingController(text: '15/03/2026');
    DateTime? currentValue = DateTime(2026, 3, 15);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return DataAmmissioneField(
                controller: controller,
                value: currentValue,
                onChanged: (next) => setState(() => currentValue = next),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Data Ammissione'), findsOneWidget);
    expect(find.text('15/03/2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Rimuovi data ammissione'));
    await tester.pumpAndSettle();

    expect(currentValue, isNull);
    expect(controller.text, isEmpty);
    controller.dispose();
  });
}
