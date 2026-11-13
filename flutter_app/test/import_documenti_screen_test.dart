import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/screens/import_documenti_screen.dart';

void main() {
  testWidgets('ImportDocumentiScreen renders step 1 and wizard elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImportDocumentiScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Wizard Importazione Documenti su Google Drive'), findsOneWidget);
    expect(find.text('Passo 1: Scegli l\'allievo'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Avanti'), findsOneWidget);
  });
}
