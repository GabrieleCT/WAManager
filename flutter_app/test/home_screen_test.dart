import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/screens/home_screen.dart';

void main() {
  testWidgets('Mobile HomeScreen excludes forbidden sections', (WidgetTester tester) async {
    // Set screen size to mobile (width 400, height 800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify NavigationRail is NOT present on mobile
    expect(find.byType(NavigationRail), findsNothing);

    // Verify NavigationBar is present
    expect(find.byType(NavigationBar), findsOneWidget);

    // Open the drawer
    final ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    // Verify allowed mobile sections are in Drawer
    expect(find.text('Presenze'), findsAtLeastNWidgets(1));
    expect(find.text('Lezioni'), findsAtLeastNWidgets(1));
    expect(find.text('Anagrafica Allievi'), findsOneWidget);
    expect(find.text('Corsi'), findsOneWidget);
    expect(find.text('Argomenti'), findsOneWidget);
    expect(find.text('Pagamenti'), findsAtLeastNWidgets(1));
    expect(find.text('Ricevute'), findsOneWidget);

    // Verify forbidden sections are NOT present anywhere on mobile
    expect(find.text('Impostazioni'), findsNothing);
    expect(find.text('ASD'), findsNothing);
    expect(find.text('Bilancio'), findsNothing);
    expect(find.text('Scuole'), findsNothing);
    expect(find.text('Messaggistica'), findsNothing);
    expect(find.text('Messaggi'), findsNothing);
  });

  testWidgets('Desktop HomeScreen includes all sections', (WidgetTester tester) async {
    // Set screen size to desktop (width 1200, height 800)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify NavigationRail is present on desktop
    expect(find.byType(NavigationRail), findsOneWidget);

    // Verify all 12 sections exist in NavigationRail
    expect(find.text('Presenze'), findsOneWidget);
    expect(find.text('Messaggistica'), findsOneWidget);
    expect(find.text('Lezioni'), findsOneWidget);
    expect(find.text('Anagrafica'), findsOneWidget);
    expect(find.text('Scuole'), findsOneWidget);
    expect(find.text('Corsi'), findsOneWidget);
    expect(find.text('Argomenti'), findsOneWidget);
    expect(find.text('Pagamenti'), findsOneWidget);
    expect(find.text('Ricevute'), findsOneWidget);
    expect(find.text('Bilancio'), findsOneWidget);
    expect(find.text('ASD'), findsOneWidget);
    expect(find.text('Impostazioni'), findsOneWidget);
  });
}

