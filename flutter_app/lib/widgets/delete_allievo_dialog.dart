import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum StepStatus { pending, inProgress, success, warning, error }

class CleanupStepItem {
  final String key;
  final String title;
  final IconData icon;
  StepStatus status;
  String? detail;

  CleanupStepItem({
    required this.key,
    required this.title,
    required this.icon,
    this.status = StepStatus.pending,
    this.detail,
  });
}

class DeleteAllievoDialog extends StatefulWidget {
  final Allievo allievo;

  const DeleteAllievoDialog({
    super.key,
    required this.allievo,
  });

  @override
  State<DeleteAllievoDialog> createState() => _DeleteAllievoDialogState();
}

class _DeleteAllievoDialogState extends State<DeleteAllievoDialog> {
  final ApiService _api = ApiService();

  bool _isExecuting = false;
  bool _isFinished = false;
  bool _dbDeleted = false;
  late final List<CleanupStepItem> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      CleanupStepItem(
        key: 'google_contacts',
        title: 'Rubrica Google Contacts',
        icon: Icons.contacts_outlined,
        detail: 'Eliminazione contatto Google',
      ),
      if (!widget.allievo.isProspect)
        CleanupStepItem(
          key: 'whatsapp_groups',
          title: 'Gruppi WhatsApp (Corso & Scuola)',
          icon: Icons.groups_outlined,
          detail: 'Rimozione partecipante dai gruppi',
        ),
      CleanupStepItem(
        key: 'whatsapp_chat',
        title: 'Chat WhatsApp individuale',
        icon: Icons.chat_bubble_outline,
        detail: 'Eliminazione chat su WhatsApp',
      ),
      CleanupStepItem(
        key: 'delete_database',
        title: 'Database Gestionale',
        icon: Icons.storage_outlined,
        detail: 'Eliminazione definitiva dal sistema',
      ),
    ];
  }

  Future<void> _startExecution() async {
    setState(() {
      _isExecuting = true;
    });

    for (final step in _steps) {
      if (!mounted) break;
      setState(() {
        step.status = StepStatus.inProgress;
        step.detail = 'Operazione in corso...';
      });

      await Future.delayed(const Duration(milliseconds: 150));

      try {
        final res = await _api.cleanupAllievoStep(widget.allievo.id, step.key);
        if (!mounted) break;

        setState(() {
          if (res['success'] == true) {
            if (res['skipped'] == true) {
              step.status = StepStatus.warning;
              step.detail = res['message'] ?? 'Nessun elemento da rimuovere o operazione saltata';
            } else {
              step.status = StepStatus.success;
              step.detail = res['message'] ?? 'Operazione completata con successo';
            }
            if (step.key == 'delete_database') {
              _dbDeleted = true;
            }
          } else {
            step.status = StepStatus.error;
            step.detail = res['error'] ?? res['message'] ?? "Errore durante l'operazione";
          }
        });
      } catch (e) {
        if (!mounted) break;
        setState(() {
          step.status = StepStatus.error;
          step.detail = 'Eccezione: $e';
        });
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  Widget _buildStepItem(CleanupStepItem item) {
    Color iconColor;
    Widget leadingWidget;

    switch (item.status) {
      case StepStatus.pending:
        iconColor = Colors.grey.shade400;
        leadingWidget = Icon(item.icon, color: iconColor, size: 24);
        break;
      case StepStatus.inProgress:
        iconColor = Theme.of(context).primaryColor;
        leadingWidget = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
        break;
      case StepStatus.success:
        iconColor = Colors.green.shade600;
        leadingWidget = Icon(Icons.check_circle, color: iconColor, size: 24);
        break;
      case StepStatus.warning:
        iconColor = Colors.orange.shade700;
        leadingWidget = Icon(Icons.info_outline, color: iconColor, size: 24);
        break;
      case StepStatus.error:
        iconColor = Colors.red.shade600;
        leadingWidget = Icon(Icons.error_outline, color: iconColor, size: 24);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: item.status == StepStatus.inProgress
            ? Theme.of(context).primaryColor.withValues(alpha: 0.06)
            : item.status == StepStatus.error
                ? Colors.red.shade50
                : item.status == StepStatus.success
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.status == StepStatus.inProgress
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : item.status == StepStatus.error
                  ? Colors.red.shade200
                  : item.status == StepStatus.success
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leadingWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: item.status == StepStatus.pending ? Colors.grey.shade700 : Colors.black87,
                  ),
                ),
                if (item.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.detail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.status == StepStatus.error
                          ? Colors.red.shade700
                          : item.status == StepStatus.warning
                              ? Colors.orange.shade800
                              : item.status == StepStatus.success
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProspect = widget.allievo.isProspect;
    final entityName = isProspect ? 'Prospect' : 'Corsista';

    return PopScope(
      canPop: !_isExecuting || _isFinished,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isExecuting ? Colors.orange.shade50 : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isExecuting ? Icons.sync : Icons.delete_forever,
                color: _isExecuting ? Colors.orange.shade800 : Colors.red.shade700,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isFinished
                        ? 'Esito eliminazione $entityName'
                        : _isExecuting
                            ? 'Eliminazione in corso...'
                            : 'Elimina $entityName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.allievo.nomeCompleto,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey.shade700,
                    ),
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
                if (!_isExecuting) ...[
                  Text(
                    'Sei sicuro di voler eliminare definitivamente ${widget.allievo.nomeCompleto}?',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              'Azioni che verranno eseguite passo-passo:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('• 1. Rimozione da Google Contacts', style: TextStyle(fontSize: 12)),
                        if (!isProspect)
                          const Text('• 2. Rimozione dai gruppi WhatsApp (corso e scuola)', style: TextStyle(fontSize: 12)),
                        Text('• ${!isProspect ? "3" : "2"}. Eliminazione chat WhatsApp individuale (se presente)', style: const TextStyle(fontSize: 12)),
                        Text('• ${!isProspect ? "4" : "3"}. Cancellazione definitiva dal database di sistema', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 6),
                ],
                ..._steps.map(_buildStepItem),
                if (_isFinished) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _dbDeleted ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _dbDeleted ? Colors.green.shade200 : Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _dbDeleted ? Icons.check_circle : Icons.error_outline,
                          color: _dbDeleted ? Colors.green.shade700 : Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dbDeleted
                                ? 'Processo completato: $entityName eliminato dal sistema.'
                                : "Si è verificato un problema durante l'eliminazione dal database.",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _dbDeleted ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (!_isExecuting) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Elimina definitivamente'),
              onPressed: _startExecution,
            ),
          ] else if (_isFinished) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, _dbDeleted),
              child: const Text('Chiudi'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool?> showDeleteAllievoDialog(BuildContext context, {required Allievo allievo}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DeleteAllievoDialog(allievo: allievo),
  );
}
