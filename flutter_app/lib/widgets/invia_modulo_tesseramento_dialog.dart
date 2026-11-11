import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/api_service.dart';

Future<void> mostraInviaModuloTesseramentoDialog(
  BuildContext context,
  Allievo a, {
  ApiService? api,
}) async {
  final apiService = api ?? ApiService();
  final phoneController = TextEditingController(
    text: a.telefono.trim().toUpperCase() == 'TBD' ? '' : a.telefono,
  );
  final nick = a.nickname.trim().isNotEmpty ? a.nickname.trim() : a.nome.trim();
  String defaultMsg =
      'Gentile $nick, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all\'ASD TantoTango da compilare e firmare. A presto!';
  try {
    final cfg = await apiService.getDaemonConfig();
    if (cfg != null && cfg.moduloTesseramentoTesto.isNotEmpty) {
      defaultMsg = cfg.moduloTesseramentoTesto
          .replaceAll('{nickname}', nick)
          .replaceAll('<nickname>', nick)
          .replaceAll('{nome}', a.nome)
          .replaceAll('{cognome}', a.cognome)
          .replaceAll('{nome_completo}', a.nomeCompleto);
    }
  } catch (_) {}
  if (!context.mounted) return;
  final messageController = TextEditingController(text: defaultMsg);
  bool sending = false;
  bool loadingPreview = false;
  String? localError;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invia Modulo Tesseramento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    a.nomeCompleto,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (localError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localError!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.indigo, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allegato: Modulo_Tesseramento.pdf',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            a.isProspect
                                ? 'Prospect: ${a.nomeCompleto} • Stato tessera: ${a.statoTessera}'
                                : 'Allievo: ${a.nomeCompleto} • Stato tessera: ${a.statoTessera}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: !sending,
                decoration: InputDecoration(
                  labelText: 'Numero di Telefono WhatsApp *',
                  hintText: 'es. 393401234567 o 3401234567',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  helperText: (a.telefono.isNotEmpty && a.telefono.trim().toUpperCase() != 'TBD')
                      ? (a.isProspect
                          ? 'Numero registrato per il prospect'
                          : 'Numero registrato per l\'allievo')
                      : 'Inserisci il numero con prefisso internazionale (es. 39...)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: messageController,
                maxLines: 3,
                enabled: !sending,
                decoration: InputDecoration(
                  labelText: 'Messaggio di accompagnamento',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: sending ? null : () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          OutlinedButton.icon(
            icon: loadingPreview
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.visibility, size: 16),
            label: const Text('Anteprima PDF'),
            onPressed: (sending || loadingPreview)
                ? null
                : () async {
                    setDlgState(() => loadingPreview = true);
                    try {
                      final bytes = await apiService.getModuloTesseramentoPdf(a.id);
                      if (bytes != null && bytes.isNotEmpty) {
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => bytes,
                          name: 'Modulo_Tesseramento_${a.cognome}_${a.nome}.pdf',
                        );
                      } else if (ctx.mounted) {
                        setDlgState(() => localError = 'Impossibile caricare il PDF del modulo.');
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDlgState(() => localError = 'Errore anteprima PDF: $e');
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDlgState(() => loadingPreview = false);
                      }
                    }
                  },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(sending ? 'Invio in corso...' : 'Invia PDF via WhatsApp'),
            onPressed: sending
                ? null
                : () async {
                    final phone = phoneController.text.trim();
                    if (phone.isEmpty) {
                      setDlgState(() => localError = 'Inserisci un numero di telefono valido.');
                      return;
                    }

                    setDlgState(() {
                      sending = true;
                      localError = null;
                    });

                    final res = await apiService.sendModuloTesseramentoWhatsApp(
                      allievoId: a.id,
                      telefono: phone,
                      messaggio: messageController.text.trim(),
                    );

                    if (!ctx.mounted) return;

                    if (res['success'] == true) {
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    res['message'] ??
                                        'Modulo di tesseramento inviato con successo a ${a.nomeCompleto} ($phone)!',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green.shade700,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } else {
                      setDlgState(() {
                        sending = false;
                        localError = res['error'] ?? 'Errore durante l\'invio del messaggio.';
                      });
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
