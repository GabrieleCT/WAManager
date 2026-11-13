import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wamanager_flutter/models/models.dart';
import 'package:wamanager_flutter/screens/google_drive_screen.dart';

void main() {
  test('GoogleDriveConfig parses folder_certificati_id and folder_certificati_nome', () {
    final json = {
      'id': 'cfg-1',
      'auth_type': 'oauth',
      'is_configured': true,
      'is_sa_configured': false,
      'is_oauth_connected': true,
      'filename': '',
      'file_size': 0,
      'client_email': '',
      'project_id': '',
      'private_key_id': '',
      'folder_id': '',
      'folder_ricevute_id': 'f_ric',
      'folder_ricevute_nome': 'Ricevute',
      'folder_tessere_id': 'f_tess',
      'folder_tessere_nome': 'Tessere',
      'folder_verbali_id': 'f_verb',
      'folder_verbali_nome': 'Verbali',
      'folder_libro_soci_id': 'f_ls',
      'folder_libro_soci_nome': 'Libro Soci',
      'folder_certificati_id': 'f_cert',
      'folder_certificati_nome': 'Certificati Medici 2026',
      'is_active': true,
      'last_test_status': 'success',
      'last_test_message': 'Connesso',
      'created_at': '2026-01-01',
      'updated_at': '2026-01-02',
    };

    final config = GoogleDriveConfig.fromJson(json);
    expect(config.folderCertificatiId, 'f_cert');
    expect(config.folderCertificatiNome, 'Certificati Medici 2026');
  });

  testWidgets('GoogleDriveScreen displays Cartella Certificati Medici section', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GoogleDriveScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify presence of Cartella Certificati Medici
    expect(find.text('Cartella Certificati Medici'), findsOneWidget);
    expect(find.byIcon(Icons.medical_information_outlined), findsOneWidget);
  });
}
