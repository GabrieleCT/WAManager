import 'package:flutter/material.dart';

void checkAndShowGoogleSyncError(
  BuildContext context, {
  required String entityType,
  required String name,
  required String? error,
}) {
  if (error == null || error.trim().isEmpty) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Attenzione Google Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$entityType "$name" salvato correttamente nel gestionale, ma non è stato possibile sincronizzarlo con Google Contacts (People API).',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
            const Text(
              'Dettaglio errore:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: SelectableText(
                error,
                style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Verifica che la People API sia abilitata nel tuo progetto Google Cloud Console e che l\'account sia collegato in Impostazioni > Google Contacts.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Ho Capito'),
        ),
      ],
    ),
  );
}

