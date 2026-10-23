import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class VerbaleRendicontoTab extends StatefulWidget {
  const VerbaleRendicontoTab({super.key});

  @override
  State<VerbaleRendicontoTab> createState() => _VerbaleRendicontoTabState();
}

class _VerbaleRendicontoTabState extends State<VerbaleRendicontoTab> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _generatingPdf = false;
  bool _uploadingDrive = false;

  Map<String, dynamic>? _info;
  int? _selectedAnno;
  List<int> _anniDisponibili = [];

  final _dataAssembleaController = TextEditingController();
  final _orarioAssembleaController = TextEditingController(text: '20:00');
  final _dataAffissioneController = TextEditingController();

  DateTime? _dataAssemblea;
  DateTime? _dataAffissione;

  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _caricaDatiDefault();
  }

  @override
  void dispose() {
    _dataAssembleaController.dispose();
    _orarioAssembleaController.dispose();
    _dataAffissioneController.dispose();
    super.dispose();
  }

  Future<void> _caricaDatiDefault() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getDatiVerbaleDefault();
      if (mounted) {
        setState(() {
          _info = res;
          if (res['success'] == true) {
            if (res['anni_disponibili'] != null) {
              _anniDisponibili = List<int>.from(res['anni_disponibili']);
            }
            _selectedAnno = res['anno_esercizio_default'] as int?;
            if (_anniDisponibili.isEmpty) {
              final fallback = _selectedAnno ?? DateTime.now().year;
              _anniDisponibili = [fallback];
              _selectedAnno = fallback;
            } else if (_selectedAnno == null || !_anniDisponibili.contains(_selectedAnno)) {
              _selectedAnno = _anniDisponibili.first;
            }

            if (res['data_assemblea_default'] != null) {
              _dataAssemblea = DateTime.tryParse(res['data_assemblea_default']);
              if (_dataAssemblea != null) {
                _dataAssembleaController.text = DateFormat('dd/MM/yyyy').format(_dataAssemblea!);
              }
            }

            if (res['data_affissione_default'] != null) {
              _dataAffissione = DateTime.tryParse(res['data_affissione_default']);
              if (_dataAffissione != null) {
                _dataAffissioneController.text = DateFormat('dd/MM/yyyy').format(_dataAffissione!);
              }
            }

            if (res['orario_assemblea_default'] != null && _orarioAssembleaController.text.isEmpty) {
              _orarioAssembleaController.text = res['orario_assemblea_default'];
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento delle impostazioni: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento parametri e firme ASD in corso...'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1050;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 480,
                          child: _buildFormCard(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildPreviewCard(height: 780),
                        ),
                      ],
                    )
                  else ...[
                    _buildFormCard(),
                    const SizedBox(height: 24),
                    _buildPreviewCard(height: 600),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    final hasTmpl = _info?['has_template_verbale'] == true;
    final hasPres = _info?['has_firma_presidente'] == true;
    final hasVice = _info?['has_firma_vicepresidente'] == true;
    final driveConfigured = _info?['google_drive_configured'] == true;
    final folderNome = _info?['google_drive_folder_nome'] ?? 'Cartella Verbali';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.description, color: Theme.of(context).primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generazione Verbale di Approvazione Rendiconto',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compila i dati dell\'assemblea e genera automaticamente il documento ufficiale sostituendo i placeholder e apponendo le firme digitali del Presidente e del Segretario.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ricarica impostazioni e firme',
                icon: const Icon(Icons.refresh),
                onPressed: _caricaDatiDefault,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: hasTmpl ? 'Template Verbale Caricato' : 'Template Verbale Mancante',
                icon: hasTmpl ? Icons.check_circle : Icons.warning_amber_rounded,
                isOk: hasTmpl,
              ),
              _buildStatusPill(
                label: hasPres ? 'Firma Presidente Presente' : 'Firma Presidente Mancante',
                icon: hasPres ? Icons.check_circle : Icons.error_outline,
                isOk: hasPres,
              ),
              _buildStatusPill(
                label: hasVice ? 'Firma Segretario Presente' : 'Firma Segretario Mancante',
                icon: hasVice ? Icons.check_circle : Icons.error_outline,
                isOk: hasVice,
              ),
              _buildStatusPill(
                label: driveConfigured ? 'Google Drive: $folderNome' : 'Google Drive Non Connesso',
                icon: driveConfigured ? Icons.cloud_done : Icons.cloud_off,
                isOk: driveConfigured,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({required String label, required IconData icon, required bool isOk}) {
    final color = isOk ? Colors.green.shade700 : Colors.amber.shade900;
    final bg = isOk ? Colors.green.shade50 : Colors.amber.shade50;
    final border = isOk ? Colors.green.shade200 : Colors.amber.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, size: 20, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text(
                'Parametri Assemblea',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tutti i campi contrassegnati con (*) sono obbligatori per la redazione del verbale.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Anno esercizio
          DropdownButtonFormField<int>(
            initialValue: _selectedAnno,
            decoration: const InputDecoration(
              labelText: 'Anno di Esercizio *',
              prefixIcon: Icon(Icons.calendar_month),
              border: OutlineInputBorder(),
              helperText: 'Anno del rendiconto economico da approvare',
            ),
            items: _anniDisponibili.map((anno) {
              return DropdownMenuItem<int>(
                value: anno,
                child: Text('Esercizio $anno', style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedAnno = val);
              }
            },
          ),
          const SizedBox(height: 16),

          // Data assemblea
          TextFormField(
            controller: _dataAssembleaController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Data assemblea *',
              prefixIcon: Icon(Icons.event),
              suffixIcon: Icon(Icons.calendar_today, size: 20),
              border: OutlineInputBorder(),
              helperText: 'Data in cui si tiene l\'assemblea dei soci',
            ),
            onTap: _selezionaDataAssemblea,
          ),
          const SizedBox(height: 16),

          // Orario assemblea
          TextFormField(
            controller: _orarioAssembleaController,
            decoration: const InputDecoration(
              labelText: 'Orario assemblea (inizio) *',
              prefixIcon: Icon(Icons.access_time),
              suffixIcon: Icon(Icons.schedule, size: 20),
              border: OutlineInputBorder(),
              helperText: 'Es: 20:00 (l\'orario di chiusura sarà calcolato a 1h 30m)',
            ),
            onTap: _selezionaOrarioAssemblea,
          ),
          const SizedBox(height: 16),

          // Data affissione convocazione
          TextFormField(
            controller: _dataAffissioneController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Data affissione convocazione *',
              prefixIcon: Icon(Icons.campaign_outlined),
              suffixIcon: Icon(Icons.calendar_today, size: 20),
              border: OutlineInputBorder(),
              helperText: 'Data di esposizione dell\'avviso di convocazione',
            ),
            onTap: _selezionaDataAffissione,
          ),
          const SizedBox(height: 24),

          // Box riepilogo dati sistema
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dati recuperati automaticamente:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 6),
                _buildInfoLine('Presidente:', _info?['presidente'] ?? '-'),
                _buildInfoLine('Segretario:', '${_info?['vicepresidente'] ?? '-'} (Vicepresidente)'),
                _buildInfoLine('Sede legale:', _info?['sede_legale'] ?? '-'),
                _buildInfoLine('Utili/Risultato:', 'Calcolato da Prima Nota per l\'anno selezionato'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Pulsante Anteprima PDF
          ElevatedButton.icon(
            onPressed: (_generatingPdf || _uploadingDrive) ? null : _generaAnteprima,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            icon: _generatingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf, size: 20),
            label: Text(
              _generatingPdf ? 'Generazione in corso...' : 'Anteprima PDF',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Pulsante Carica su Google Drive
          OutlinedButton.icon(
            onPressed: (_generatingPdf || _uploadingDrive) ? null : _caricaSuDrive,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade800,
              side: BorderSide(color: Colors.blue.shade700, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _uploadingDrive
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.blue.shade800, strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined, size: 20),
            label: Text(
              _uploadingDrive ? 'Caricamento su Drive in corso...' : 'Carica su Google Drive',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _generatingPdf
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generazione verbale con firme e rendiconto in corso...'),
                ],
              ),
            )
          : _pdfBytes != null
              ? PdfPreview(
                  build: (format) => _pdfBytes!,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName: 'Verbale_Approvazione_Rendiconto_${_selectedAnno ?? ''}.pdf',
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'Nessuna anteprima disponibile',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verifica i parametri assemblea a sinistra e clicca su "Anteprima PDF" per compilare e visualizzare il documento in tempo reale.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Future<void> _selezionaDataAssemblea() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataAssemblea ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dataAssemblea = picked;
        _dataAssembleaController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selezionaDataAffissione() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataAffissione ?? (_dataAssemblea != null ? _dataAssemblea!.subtract(const Duration(days: 15)) : now),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dataAffissione = picked;
        _dataAffissioneController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selezionaOrarioAssemblea() async {
    TimeOfDay initial = const TimeOfDay(hour: 20, minute: 0);
    final parts = _orarioAssembleaController.text.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initial = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _orarioAssembleaController.text = formatted;
      });
    }
  }

  Future<void> _generaAnteprima() async {
    if (_dataAssemblea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il campo "Data assemblea" è obbligatorio.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_orarioAssembleaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il campo "Orario assemblea" è obbligatorio.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_dataAffissione == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il campo "Data affissione convocazione" è obbligatorio.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _generatingPdf = true);
    try {
      final bytes = await _api.generaVerbalePdf(
        dataAssemblea: DateFormat('yyyy-MM-dd').format(_dataAssemblea!),
        orarioAssemblea: _orarioAssembleaController.text.trim(),
        dataAffissione: DateFormat('yyyy-MM-dd').format(_dataAffissione!),
        annoEsercizio: _selectedAnno,
      );

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _generatingPdf = false;
        });
        if (bytes != null && bytes.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verbale generato con successo! Visualizzalo nell\'anteprima.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la generazione del verbale: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _caricaSuDrive() async {
    if (_dataAssemblea == null || _orarioAssembleaController.text.trim().isEmpty || _dataAffissione == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila tutti i campi obbligatori prima del caricamento.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final folderNome = _info?['google_drive_folder_nome'] ?? 'Cartella Verbali';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: Colors.blue),
            SizedBox(width: 10),
            Text('Carica su Google Drive'),
          ],
        ),
        content: Text(
          'Confermi il caricamento del verbale dell\'assemblea per l\'anno ${_selectedAnno ?? ''} nella cartella Google Drive "$folderNome"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cloud_upload, color: Colors.white, size: 18),
            label: const Text('Carica Documento', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _uploadingDrive = true);
    try {
      final res = await _api.uploadVerbaleDrive(
        dataAssemblea: DateFormat('yyyy-MM-dd').format(_dataAssemblea!),
        orarioAssemblea: _orarioAssembleaController.text.trim(),
        dataAffissione: DateFormat('yyyy-MM-dd').format(_dataAffissione!),
        annoEsercizio: _selectedAnno,
      );

      if (!mounted) return;
      setState(() => _uploadingDrive = false);

      if (res['success'] == true) {
        final webViewLink = res['webViewLink'] as String?;
        final filename = res['filename'] ?? 'Verbale.pdf';

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Caricamento Completato!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(res['message'] ?? 'Documento salvato con successo.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(filename, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (webViewLink != null && webViewLink.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                  icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                  label: const Text('Apri su Google Drive', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    final uri = Uri.parse(webViewLink);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Errore caricamento su Google Drive'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingDrive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore imprevisto durante il caricamento: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}
