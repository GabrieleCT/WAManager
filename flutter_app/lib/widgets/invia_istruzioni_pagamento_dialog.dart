import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

Future<void> mostraInviaIstruzioniPagamentoDialog(BuildContext context, Allievo a, {ApiService? api}) async {
  final apiService = api ?? ApiService();
  final phoneController = TextEditingController(text: a.telefono);
  final nick = a.nickname.trim().isNotEmpty ? a.nickname.trim() : a.nome.trim();
  String defaultMsg = 'Ciao $nick, per effettuare il pagamento della quota a favore di TantoTango, puoi effettuare un bonifico.';
  try {
    final cfg = await apiService.getDaemonConfig();
    final asd = await apiService.getConfigurazioneASD();
    final iban = asd?.iban.trim() ?? '';
    final nomeAsd = (asd?.nome != null && asd!.nome.trim().isNotEmpty) ? asd.nome.trim() : 'TantoTango';
    if (cfg != null && cfg.istruzioniPagamentoTesto.isNotEmpty) {
      defaultMsg = cfg.istruzioniPagamentoTesto
          .replaceAll('{iban}', iban)
          .replaceAll('<iban>', iban)
          .replaceAll('{nome_asd}', nomeAsd)
          .replaceAll('<nome_asd>', nomeAsd)
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
                color: Colors.teal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance, color: Colors.teal, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invia Istruzioni di Pagamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(a.nomeCompleto, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
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
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: !sending,
                decoration: InputDecoration(
                  labelText: 'Numero di Telefono WhatsApp *',
                  hintText: 'es. 393401234567 o 3401234567',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  helperText: a.telefono.isNotEmpty
                      ? (a.isProspect ? 'Numero registrato per il prospect' : 'Numero registrato per l\'allievo')
                      : 'Inserisci il numero con prefisso internazionale (es. 39...)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: messageController,
                maxLines: 7,
                minLines: 4,
                enabled: !sending,
                decoration: InputDecoration(
                  labelText: 'Messaggio WhatsApp con IBAN',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: sending ? null : () => Navigator.pop(ctx),
            child: const Text('Annulla'),
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
            label: Text(sending ? 'Invio in corso...' : 'Invia via WhatsApp'),
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

                    final res = await apiService.sendIstruzioniPagamentoWhatsApp(
                      allievoId: a.id,
                      telefono: phone,
                      messaggio: messageController.text.trim(),
                    );

                    if (!ctx.mounted) return;
                    if (!context.mounted) return;

                    if (res['success'] == true) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res['message'] ?? 'Istruzioni inviate con successo!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      setDlgState(() {
                        sending = false;
                        localError = res['error'] ?? 'Errore durante l\'invio delle istruzioni.';
                      });
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
