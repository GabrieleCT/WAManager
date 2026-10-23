import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ImportExportScreen extends StatefulWidget {
  final bool embedded;
  const ImportExportScreen({super.key, this.embedded = false});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Stato Import Globale
  Uint8List? _fileBytes;
  String? _fileName;
  int? _fileSize;
  bool _importing = false;
  Map<String, dynamic>? _importResult;

  // Stato Export Globale
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadFile(String url, String description) async {
    setState(() => _exporting = true);
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download avviato: $description'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore download: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'xlsx'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final size = file.lengthSync() ?? bytes.length;
        setState(() {
          _fileBytes = bytes;
          _fileName = file.name;
          _fileSize = size;
          _importResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore selezione file: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _executeGlobalImport() async {
    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima un file di backup (.json o .xlsx).')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conferma Ripristino Globale'),
          ],
        ),
        content: Text(
          'Stai per importare tutti i dati dal file "${_fileName ?? 'backup.xlsx'}".\n'
          'I dati esistenti verranno aggiornati o integrati.\n\nVuoi procedere?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conferma e Importa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _importing = true;
      _importResult = null;
    });

    final res = await _api.uploadImportFile('global', _fileBytes!, _fileName ?? 'backup.xlsx');

    if (mounted) {
      setState(() {
        _importing = false;
        _importResult = res;
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Importazione globale completata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Errore durante l\'importazione.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Theme.of(context).primaryColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.download), text: 'Esporta Dati (Backup Globale)'),
                Tab(icon: Icon(Icons.upload), text: 'Importa Dati (Ripristino Globale)'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExportTab(),
                _buildImportTab(),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Ripristino Globale'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: 'Esporta Dati (Backup Globale)'),
            Tab(icon: Icon(Icons.upload), text: 'Importa Dati (Ripristino Globale)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: EXPORT GLOBALE ──────────────────────────────
          _buildExportTab(),

          // ─── TAB 2: IMPORT GLOBALE ──────────────────────────────
          _buildImportTab(),
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cloud_download_outlined, size: 32, color: Colors.teal.shade800),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dump Completo del Database',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Scarica un dump completo del database (.json) conforme a Django. Include il 100% delle tabelle e dei record (Allievi, Corsi, Scuole, Presenze, Pagamenti, Ricevute, Movimenti Cassa, ASD, WhatsApp, ecc.) e includerà automaticamente qualsiasi nuova entità futura.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Il dump include l\'intero database senza esclusioni (anche per entità future):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(Icons.storage, 'Tutto il Database'),
                          _buildChip(Icons.people, 'Allievi & Prospect'),
                          _buildChip(Icons.school, 'Corsi & Scuole'),
                          _buildChip(Icons.how_to_reg, 'Presenze & Lezioni'),
                          _buildChip(Icons.euro, 'Pagamenti'),
                          _buildChip(Icons.receipt_long, 'Ricevute Fiscali'),
                          _buildChip(Icons.account_balance, 'Bilancio & Cassa'),
                          _buildChip(Icons.card_membership, 'Socio ASD & Certificati'),
                          _buildChip(Icons.chat, 'Messaggistica & WhatsApp'),
                          _buildChip(Icons.auto_awesome, 'Tutte le future entità'),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Pulsante Principale: Dump Completo JSON
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _exporting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.download, size: 22),
                          label: Text(
                            _exporting ? 'Generazione dump in corso...' : 'Scarica Dump Completo Database (.json)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _exporting
                              ? null
                              : () {
                                  final url = _api.getExportUrl('global', format: 'json');
                                  _downloadFile(url, 'Dump Completo Database (.json)');
                                },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Pulsante Secondario: Backup Excel
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade800,
                            side: BorderSide(color: Colors.teal.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.table_view_outlined, size: 20),
                          label: const Text(
                            'Scarica in formato Excel (.xlsx) per consultazione',
                            style: TextStyle(fontSize: 14),
                          ),
                          onPressed: _exporting
                              ? null
                              : () {
                                  final url = _api.getExportUrl('global', format: 'xlsx');
                                  _downloadFile(url, 'Backup Excel (.xlsx)');
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportTab() {
    final stats = _importResult != null && _importResult!['statistiche'] != null
        ? _importResult!['statistiche'] as Map<String, dynamic>
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.deepPurple.shade800),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ripristino Completo del Gestionale',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Carica un file di dump (.json o .xlsx) per ripristinare o sincronizzare l\'intero database. I file .json contengono il dump completo e ripristinano qualsiasi entità presente o futura.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      // Selezione File
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _fileName != null ? Icons.insert_drive_file : Icons.folder_open,
                              color: _fileName != null ? Colors.deepPurple : Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fileName ?? 'Nessun file selezionato',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _fileName != null ? Colors.black87 : Colors.grey.shade700,
                                    ),
                                  ),
                                  if (_fileSize != null)
                                    Text(
                                      '${(_fileSize! / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.attach_file),
                              label: Text(_fileName != null ? 'Cambia File' : 'Scegli File (.json / .xlsx)'),
                              onPressed: _importing ? null : _pickFile,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _importing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.upload, size: 22),
                          label: Text(
                            _importing ? 'Importazione e sincronizzazione in corso...' : 'Avvia Ripristino Globale',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: (_importing || _fileBytes == null) ? null : _executeGlobalImport,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Risultato dell'importazione
              if (_importResult != null) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: _importResult!['success'] == true ? Colors.green.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _importResult!['success'] == true ? Icons.check_circle : Icons.error,
                              color: _importResult!['success'] == true ? Colors.green.shade800 : Colors.red.shade800,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _importResult!['messaggio'] ?? (_importResult!['success'] == true ? 'Importazione completata con successo!' : 'Errore durante l\'importazione'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _importResult!['success'] == true ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_importResult!['error'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _importResult!['error'],
                            style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                          ),
                        ],
                        if (stats != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Riepilogo Dati Importati/Aggiornati:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: stats.entries.map((entry) {
                              final label = entry.key
                                  .replaceAll('core.', '')
                                  .replaceAll('auth.', '')
                                  .replaceAll('_', ' ')
                                  .toUpperCase();
                              return _buildStatBadge(label, entry.value, Colors.indigo);
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, dynamic count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          Text(
            '$count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
