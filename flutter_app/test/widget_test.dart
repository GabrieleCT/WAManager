import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WAManagerApp(isLoggedIn: false));
    expect(find.byType(WAManagerApp), findsOneWidget);
  });
}

