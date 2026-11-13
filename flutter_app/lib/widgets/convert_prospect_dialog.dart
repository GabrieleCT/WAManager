import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum StepStateStatus {
  pending,
  inProgress,
  success,
  warning,
  error,
}

class _ConversionStep {
  final String title;
  final String defaultDescription;
  StepStateStatus status = StepStateStatus.pending;
  String? detail;

  _ConversionStep({
    required this.title,
    required this.defaultDescription,
  });
}

Future<void> mostraConversioneAllievoDialog(
  BuildContext context, {
  required Allievo prospect,
  required String corsoId,
  String? corsoNome,
  bool inviaModuloTesseramento = true,
  VoidCallback? onCompleted,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConvertProspectDialog(
      prospect: prospect,
      corsoId: corsoId,
      corsoNome: corsoNome,
      inviaModuloTesseramento: inviaModuloTesseramento,
      onCompleted: onCompleted,
    ),
  );
}

class _ConvertProspectDialog extends StatefulWidget {
  final Allievo prospect;
  final String corsoId;
  final String? corsoNome;
  final bool inviaModuloTesseramento;
  final VoidCallback? onCompleted;

  const _ConvertProspectDialog({
    required this.prospect,
    required this.corsoId,
    this.corsoNome,
    this.inviaModuloTesseramento = true,
    this.onCompleted,
  });

  @override
  State<_ConvertProspectDialog> createState() => _ConvertProspectDialogState();
}

class _ConvertProspectDialogState extends State<_ConvertProspectDialog> {
  final ApiService _api = ApiService();
  bool _isProcessing = true;

  late final List<_ConversionStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      _ConversionStep(
        title: '1. Aggiornamento status su sistema',
        defaultDescription: 'Conversione da prospect ad allievo effettivo nel gestionale',
      ),
      _ConversionStep(
        title: '2. Inserimento nei gruppi WhatsApp',
        defaultDescription: 'Aggiunta ai gruppi WhatsApp della scuola e del corso',
      ),
      _ConversionStep(
        title: '3. Modifica informazioni su Google Contacts',
        defaultDescription: 'Rimozione della dicitura "potenziale" dalle note del contatto',
      ),
      _ConversionStep(
        title: '4. Invio del modulo di tesseramento',
        defaultDescription: widget.inviaModuloTesseramento
            ? 'Generazione PDF e invio modulo tesseramento via WhatsApp'
            : 'Invio modulo di tesseramento escluso su richiesta',
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eseguiConversione();
    });
  }

  Future<void> _eseguiConversione() async {
    // ─── STEP 1: Aggiornamento status su sistema ─────────────────────
    setState(() {
      _steps[0].status = StepStateStatus.inProgress;
      _steps[0].detail = 'Salvataggio nuovo status in corso...';
    });

    Map<String, dynamic> step1Res;
    try {
      step1Res = await _api.convertProspectStatus(widget.prospect.id, widget.corsoId);
    } catch (e) {
      step1Res = {'success': false, 'error': e.toString()};
    }

    if (!mounted) return;

    if (step1Res['success'] == true) {
      setState(() {
        _steps[0].status = StepStateStatus.success;
        _steps[0].detail = step1Res['message'] ?? 'Status aggiornato ad Allievo Effettivo.';
      });
    } else {
      setState(() {
        _steps[0].status = StepStateStatus.error;
        _steps[0].detail = step1Res['error'] ?? 'Errore durante l\'aggiornamento dello status.';
        _isProcessing = false;
      });
      return; // Se il salvataggio principale fallisce, arresta la sequenza
    }

    // ─── STEP 2: Inserimento nei gruppi WhatsApp ────────────────────
    setState(() {
      _steps[1].status = StepStateStatus.inProgress;
      _steps[1].detail = 'Aggiunta ai gruppi WhatsApp del corso e della scuola in corso...';
    });

    Map<String, dynamic> step2Res;
    try {
      step2Res = await _api.addAllievoToWhatsAppGroups(widget.prospect.id);
    } catch (e) {
      step2Res = {'success': false, 'error': e.toString()};
    }

    if (!mounted) return;

    if (step2Res['success'] == true) {
      final isWarning = step2Res['warning'] == true;
      setState(() {
        _steps[1].status = isWarning ? StepStateStatus.warning : StepStateStatus.success;
        _steps[1].detail = step2Res['message'] ?? (isWarning ? 'Inserimento saltato.' : 'Allievo aggiunto ai gruppi.');
      });
    } else {
      setState(() {
        _steps[1].status = StepStateStatus.warning;
        _steps[1].detail = step2Res['error'] ?? 'Impossibile completare l\'inserimento nei gruppi.';
      });
    }

    // ─── STEP 3: Modifica informazioni su Google Contacts ───────────
    setState(() {
      _steps[2].status = StepStateStatus.inProgress;
      _steps[2].detail = 'Aggiornamento contatto Google e note in corso...';
    });

    Map<String, dynamic> step3Res;
    try {
      step3Res = await _api.syncAllievoToGoogleContacts(widget.prospect.id, cleanPotenziale: true);
    } catch (e) {
      step3Res = {'success': false, 'error': e.toString()};
    }

    if (!mounted) return;

    if (step3Res['success'] == true) {
      final noteAggiornata = step3Res['note'] ?? '';
      setState(() {
        _steps[2].status = StepStateStatus.success;
        _steps[2].detail = noteAggiornata.isNotEmpty
            ? 'Contatto Google aggiornato: nota impostata su "$noteAggiornata".'
            : (step3Res['message'] ?? 'Contatto Google sincronizzato senza termine "potenziale".');
      });
    } else {
      final skipped = step3Res['skipped'] == true;
      setState(() {
        _steps[2].status = skipped ? StepStateStatus.warning : StepStateStatus.error;
        _steps[2].detail = step3Res['message'] ?? step3Res['error'] ?? 'Errore sincronizzazione Google Contacts.';
      });
    }

    // ─── STEP 4: Invio modulo di tesseramento via WhatsApp ──────────
    if (!widget.inviaModuloTesseramento) {
      setState(() {
        _steps[3].status = StepStateStatus.warning;
        _steps[3].detail = 'Invio modulo di tesseramento escluso su richiesta dell\'utente.';
      });
    } else {
      setState(() {
        _steps[3].status = StepStateStatus.inProgress;
        _steps[3].detail = 'Generazione PDF e invio modulo tesseramento in corso...';
      });

      Map<String, dynamic> step4Res;
      try {
        final tel = widget.prospect.telefono.trim();
        if (tel.isEmpty || tel.toUpperCase() == 'TBD') {
          step4Res = {
            'success': false,
            'skipped': true,
            'error': 'Nessun numero di telefono associato: modulo non inviato via WhatsApp.',
          };
        } else {
          step4Res = await _api.sendModuloTesseramentoWhatsApp(
            allievoId: widget.prospect.id,
            telefono: tel,
          );
        }
      } catch (e) {
        step4Res = {'success': false, 'error': e.toString()};
      }

      if (!mounted) return;

      if (step4Res['success'] == true) {
        setState(() {
          _steps[3].status = StepStateStatus.success;
          _steps[3].detail = step4Res['message'] ?? 'Modulo di tesseramento inviato con successo via WhatsApp!';
        });
      } else {
        final isSkipped = step4Res['skipped'] == true;
        setState(() {
          _steps[3].status = isSkipped ? StepStateStatus.warning : StepStateStatus.error;
          _steps[3].detail = step4Res['error'] ?? step4Res['message'] ?? 'Invio modulo tesseramento non riuscito.';
        });
      }
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Widget _buildStepIndicator(StepStateStatus status, int index) {
    switch (status) {
      case StepStateStatus.pending:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 2),
            color: Colors.grey.shade100,
          ),
          alignment: Alignment.center,
          child: Text(
            '${index + 1}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
        );
      case StepStateStatus.inProgress:
        return const SizedBox(
          width: 28,
          height: 28,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      case StepStateStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green, size: 28);
      case StepStateStatus.warning:
        return Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28);
      case StepStateStatus.error:
        return const Icon(Icons.cancel, color: Colors.red, size: 28);
    }
  }

  Color _getStepCardColor(StepStateStatus status) {
    switch (status) {
      case StepStateStatus.pending:
        return Colors.grey.shade50;
      case StepStateStatus.inProgress:
        return Colors.blue.shade50.withValues(alpha: 0.5);
      case StepStateStatus.success:
        return Colors.green.shade50.withValues(alpha: 0.5);
      case StepStateStatus.warning:
        return Colors.orange.shade50.withValues(alpha: 0.5);
      case StepStateStatus.error:
        return Colors.red.shade50.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school, color: Colors.green.shade800, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversione Prospect in Allievo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.prospect.nomeCompleto +
                      (widget.corsoNome != null && widget.corsoNome!.isNotEmpty ? ' • ${widget.corsoNome}' : ''),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...List.generate(_steps.length, (index) {
              final s = _steps[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStepCardColor(s.status),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: s.status == StepStateStatus.inProgress
                        ? Colors.blue.shade300
                        : s.status == StepStateStatus.success
                            ? Colors.green.shade200
                            : s.status == StepStateStatus.warning
                                ? Colors.orange.shade200
                                : s.status == StepStateStatus.error
                                    ? Colors.red.shade200
                                    : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(s.status, index),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: s.status == StepStateStatus.error
                                  ? Colors.red.shade900
                                  : s.status == StepStateStatus.warning
                                      ? Colors.orange.shade900
                                      : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.detail ?? s.defaultDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: s.detail != null ? Colors.grey.shade800 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        if (_isProcessing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green.shade700),
              ),
              const SizedBox(width: 10),
              Text(
                'Elaborazione in corso...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ],
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Chiudi', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              widget.onCompleted?.call();
            },
          ),
      ],
    );
  }
}
