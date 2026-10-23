import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'google_contacts_screen.dart';

class SincronizzazioneContattiScreen extends StatefulWidget {
  final bool embedded;
  const SincronizzazioneContattiScreen({super.key, this.embedded = false});

  @override
  State<SincronizzazioneContattiScreen> createState() => _SincronizzazioneContattiScreenState();
}

class _SincronizzazioneContattiScreenState extends State<SincronizzazioneContattiScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _syncingAll = false;
  String? _processingItemId;

  GoogleContactComparisonReport? _report;
  List<Corso> _corsi = [];

  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'diffs_only', 'synced', 'modified_system', 'modified_google', 'only_system', 'only_google'

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReport();
    _loadCorsi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCorsi() async {
    try {
      final corsi = await _api.getCorsi();
      if (mounted) setState(() => _corsi = corsi);
    } catch (_) {}
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final rep = await _api.getGoogleContactsComparison();
      if (mounted) {
        setState(() {
          _report = rep;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento confronto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runFullSync() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sync, color: Colors.indigo, size: 28),
            SizedBox(width: 10),
            Text('Avvia Sincronizzazione Completa'),
          ],
        ),
        content: const Text(
          'Verranno eseguite le seguenti operazioni automatiche:\n\n'
          '• I contatti presenti solo nel gestionale verranno creati in Google Contacts.\n'
          '• I contatti modificati nel gestionale aggiorneranno Google Contacts.\n'
          '• I contatti modificati su Google Contacts aggiorneranno il gestionale.\n\n'
          'Vuoi procedere?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Avvia Sincronizzazione'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _syncingAll = true);
    try {
      final res = await _api.runGoogleContactsFullSync();
      if (mounted) {
        final summary = res['summary'] ?? (res['success'] == true ? 'Sincronizzazione completata con successo.' : 'Operazione completata.');
        final errorsCount = res['errors_count'] ?? 0;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(errorsCount == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: errorsCount == 0 ? Colors.green : Colors.orange, size: 28),
                const SizedBox(width: 10),
                const Text('Esito Sincronizzazione'),
              ],
            ),
            content: Text(summary),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadReport();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la sincronizzazione: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingAll = false);
    }
  }

  Future<void> _pushItem(GoogleContactComparisonRecord record) async {
    if (record.systemId == null) return;
    setState(() => _processingItemId = record.systemId);
    try {
      final res = await _api.pushToGoogle(record.systemId!);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Contatto aggiornato su Google.'), backgroundColor: Colors.green),
          );
          _loadReport();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Errore sincronizzazione con Google.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  Future<void> _pullItem(GoogleContactComparisonRecord record) async {
    if (record.systemId == null || record.googleId == null) return;
    setState(() => _processingItemId = record.systemId);
    try {
      final res = await _api.pullFromGoogle(record.systemId!, record.googleId!);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Record aggiornato nel gestionale.'), backgroundColor: Colors.green),
          );
          _loadReport();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Errore aggiornamento nel gestionale.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  Future<void> _importItem(GoogleContactComparisonRecord record) async {
    if (record.googleId == null) return;

    bool isProspect = record.isProspect;
    String? selectedCorsoId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.indigo, size: 26),
              SizedBox(width: 10),
              Text('Importa nel Gestionale'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stai per importare "${record.nomeCompleto}" da Google Contacts nel database locale.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text('Tipo di record da creare:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                RadioListTile<bool>(
                  title: const Text('Prospect (Potenziale allievo)'),
                  value: true,
                  groupValue: isProspect,
                  onChanged: (val) => setDialogState(() => isProspect = val ?? true),
                ),
                RadioListTile<bool>(
                  title: const Text('Allievo Effettivo'),
                  value: false,
                  groupValue: isProspect,
                  onChanged: (val) => setDialogState(() => isProspect = val ?? false),
                ),
                if (!isProspect && _corsi.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Assegna Corso (opzionale):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCorsoId,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    hint: const Text('Seleziona corso...'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Nessun corso')),
                      ..._corsi.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nomeDisplay))),
                    ],
                    onChanged: (val) => setDialogState(() => selectedCorsoId = val),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importa'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _processingItemId = record.googleId);
    try {
      final res = await _api.importFromGoogle(
        record.googleId!,
        asProspect: isProspect,
        corsoId: selectedCorsoId,
      );
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Importazione completata con successo.'), backgroundColor: Colors.green),
          );
          _loadReport();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Errore durante l\'importazione.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  Future<void> _deleteGoogleItem(GoogleContactComparisonRecord record) async {
    if (record.googleId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Elimina da Google Contacts'),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare "${record.nomeCompleto}" dalla rubrica di Google Contacts?\n\n'
          'Questa operazione rimuoverà il contatto da Google People API. Il record interno al gestionale (se presente) rimarrà intatto.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingItemId = record.googleId);
    try {
      final res = await _api.deleteGoogleContactAction(record.googleId!, allievoId: record.systemId);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contatto eliminato da Google Contacts.'), backgroundColor: Colors.green),
          );
          _loadReport();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Errore eliminazione Google.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processingItemId = null);
    }
  }

  void _showDiffDialog(GoogleContactComparisonRecord record) {
    final sys = record.systemData;
    final ggl = record.googleData;
    final diffs = record.differences;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.compare_arrows, color: Colors.indigo, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text('Confronto: ${record.nomeCompleto}', style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusChip(record.status),
                    const SizedBox(width: 10),
                    Text(
                      record.differences.isEmpty ? 'Tutti i dati coincidono' : 'Differenze nei campi: ${diffs.join(", ")}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(2.4),
                    2: FlexColumnWidth(2.4),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(padding: EdgeInsets.all(10), child: Text('Campo', style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Gestionale (Sistema)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                        Padding(padding: EdgeInsets.all(10), child: Text('Google Contacts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                      ],
                    ),
                    _buildDiffRow('Nome', sys?['nome'], ggl?['nome'], diffs.contains('nome')),
                    _buildDiffRow('Cognome', sys?['cognome'], ggl?['cognome'], diffs.contains('cognome')),
                    _buildDiffRow('Telefono', sys?['telefono'], ggl?['telefono'], diffs.contains('telefono')),
                    _buildDiffRow('Email', sys?['email'], ggl?['email'], diffs.contains('email')),
                    _buildDiffRow('Note', sys?['note'], ggl?['note'], diffs.contains('note')),
                    _buildDiffRow('Data Modifica', _formatDateTimeStr(sys?['updated_at']), _formatDateTimeStr(ggl?['update_time']), false),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
        ],
      ),
    );
  }

  TableRow _buildDiffRow(String field, String? sysVal, String? gglVal, bool isDiff) {
    final bgColor = isDiff ? Colors.amber.shade50 : Colors.white;
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(field, style: TextStyle(fontWeight: isDiff ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(sysVal ?? '-', style: TextStyle(color: isDiff ? Colors.indigo.shade900 : Colors.black87, fontWeight: isDiff ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(gglVal ?? '-', style: TextStyle(color: isDiff ? Colors.teal.shade900 : Colors.black87, fontWeight: isDiff ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ),
      ],
    );
  }

  void _showLogsDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<GoogleContactsSyncLog>>(
        future: _api.getGoogleContactsSyncLogs(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
          }
          final logs = snapshot.data ?? [];
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.history, color: Colors.blueGrey, size: 26),
                SizedBox(width: 10),
                Text('Registro Log Sincronizzazione'),
              ],
            ),
            content: SizedBox(
              width: 650,
              height: 400,
              child: logs.isEmpty
                  ? const Center(child: Text('Nessun log registrato finora.'))
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final log = logs[i];
                        final isOk = log.status == 'success';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isOk ? Colors.green.shade100 : (log.status == 'partial' ? Colors.orange.shade100 : Colors.red.shade100),
                            child: Icon(isOk ? Icons.check : Icons.warning, color: isOk ? Colors.green.shade800 : Colors.red.shade800, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(log.timestampDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                child: Text(log.action, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              ),
                            ],
                          ),
                          subtitle: Text(log.details, style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
            ],
          );
        },
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiato negli appunti!'), duration: const Duration(seconds: 2)),
    );
  }

  String _formatDateTimeStr(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoStr;
    }
  }

  List<GoogleContactComparisonRecord> get _filteredRecords {
    if (_report == null) return [];
    var list = _report!.records;

    // Filtro stato
    if (_selectedStatusFilter != 'all') {
      if (_selectedStatusFilter == 'diffs_only') {
        list = list.where((r) => r.status != 'synced').toList();
      } else {
        list = list.where((r) => r.status == _selectedStatusFilter).toList();
      }
    }

    // Ricerca testuale
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        return r.nome.toLowerCase().contains(q) ||
            r.cognome.toLowerCase().contains(q) ||
            r.telefono.contains(q) ||
            r.email.toLowerCase().contains(q) ||
            (r.systemId?.toLowerCase().contains(q) ?? false) ||
            (r.googleId?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_report != null && !_report!.connected) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_disabled, size: 64, color: Colors.orange.shade800),
              const SizedBox(height: 16),
              const Text(
                'Google Contacts Non Collegato',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _report?.message ?? 'Per visualizzare la sincronizzazione e la tabella di confronto, collega il tuo account Google da Impostazioni > Google Contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                icon: const Icon(Icons.settings),
                label: const Text('Vai a Impostazioni Google Contacts'),
                onPressed: () {
                  // Apri schermata Google Contacts
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GoogleContactsScreen(embedded: false),
                    ),
                  ).then((_) => _loadReport());
                },
              ),
            ],
          ),
        ),
      );
    }

    final content = RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildKpiCards(),
            const SizedBox(height: 16),
            _buildSearchAndFilters(),
            const SizedBox(height: 16),
            _buildTableCard(),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anagrafica > Sincronizzazione Google Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica confronto',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: content,
    );
  }

  // ─── 1. Header Card ────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    final rep = _report;
    final lastSyncDateStr = rep?.lastSyncAt != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(rep!.lastSyncAt!.toLocal())
        : 'Mai eseguita';

    final isOk = rep?.lastSyncStatus == 'success';
    final isError = rep?.lastSyncStatus == 'error';
    final isPartial = rep?.lastSyncStatus == 'partial';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync, color: Colors.indigo, size: 28),
                    const SizedBox(width: 10),
                    const Text(
                      'Sincronizzazione Google Contacts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOk ? Colors.green.shade100 : (isPartial ? Colors.orange.shade100 : (isError ? Colors.red.shade100 : Colors.grey.shade200)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOk ? Icons.check_circle : (isPartial ? Icons.warning : (isError ? Icons.error : Icons.info_outline)),
                            size: 13,
                            color: isOk ? Colors.green.shade800 : (isPartial ? Colors.orange.shade800 : (isError ? Colors.red.shade800 : Colors.grey.shade700)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOk ? 'Ultima sinc: Riuscita' : (isPartial ? 'Ultima sinc: Parziale' : (isError ? 'Ultima sinc: Errore' : 'In attesa')),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOk ? Colors.green.shade900 : (isPartial ? Colors.orange.shade900 : (isError ? Colors.red.shade900 : Colors.grey.shade800)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ultima sincronizzazione: $lastSyncDateStr${rep?.userEmail != null ? " (${rep!.userEmail})" : ""}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (rep?.lastSyncSummary != null && rep!.lastSyncSummary!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    rep.lastSyncSummary!,
                    style: TextStyle(fontSize: 12, color: isError ? Colors.red.shade800 : Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Registro Log'),
                  onPressed: _showLogsDialog,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Ricarica Confronto'),
                  onPressed: _loadReport,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _syncingAll
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  label: Text(_syncingAll ? 'Sincronizzazione in corso...' : 'Avvia Sincronizzazione'),
                  onPressed: _syncingAll ? null : _runFullSync,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. KPI Cards ──────────────────────────────────────────────────
  Widget _buildKpiCards() {
    final stats = _report?.stats ?? {};
    final total = stats['total'] ?? 0;
    final synced = stats['synced'] ?? 0;
    final modSys = stats['modified_system'] ?? 0;
    final modGgl = stats['modified_google'] ?? 0;
    final onlySys = stats['only_system'] ?? 0;
    final onlyGgl = stats['only_google'] ?? 0;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('Totale Record', '$total', Icons.groups, Colors.blueGrey, 'all'),
            _buildStatCard('Sincronizzati', '$synced', Icons.check_circle, Colors.green, 'synced'),
            _buildStatCard('Modificati nel Sistema', '$modSys', Icons.arrow_upward, Colors.indigo, 'modified_system'),
            _buildStatCard('Modificati su Google', '$modGgl', Icons.arrow_downward, Colors.orange, 'modified_google'),
            _buildStatCard('Solo nel Sistema', '$onlySys', Icons.phone_android, Colors.purple, 'only_system'),
            _buildStatCard('Solo su Google', '$onlyGgl', Icons.cloud, Colors.teal, 'only_google'),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String filterKey) {
    final isSelected = _selectedStatusFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = filterKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Search & Filters ───────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              height: 42,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cerca per nome, telefono, email...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildFilterChip('Tutti', 'all'),
                _buildFilterChip('Da allineare', 'diffs_only'),
                _buildFilterChip('Sincronizzati', 'synced'),
                _buildFilterChip('Mod. Sistema', 'modified_system'),
                _buildFilterChip('Mod. Google', 'modified_google'),
                _buildFilterChip('Solo Sistema', 'only_system'),
                _buildFilterChip('Solo Google', 'only_google'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedStatusFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: Colors.indigo.shade100,
      onSelected: (_) => setState(() => _selectedStatusFilter = filterKey),
    );
  }

  // ─── 4. Table Card ─────────────────────────────────────────────────
  Widget _buildTableCard() {
    final records = _filteredRecords;

    if (records.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('Nessun contatto trovato con i filtri selezionati.', style: TextStyle(fontSize: 15, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columnSpacing: 20,
              horizontalMargin: 16,
              columns: const [
                DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Nome e Cognome', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Telefono', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ID Sistema', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ID Google Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Stato Sincronizzazione', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Azione Disponibile', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: records.map((record) => _buildDataRow(record)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(GoogleContactComparisonRecord record) {
    final isProcessing = _processingItemId != null &&
        (_processingItemId == record.systemId || _processingItemId == record.googleId);

    // Tipo badge (Allievo, Prospect, Solo Google)
    Widget tipoWidget;
    if (record.status == 'only_google') {
      tipoWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.teal.shade300)),
        child: Text(record.isProspect ? 'PROSPECT G' : 'ALLIEVO G', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
      );
    } else {
      tipoWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: record.isProspect ? Colors.orange.shade50 : Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: record.isProspect ? Colors.orange.shade300 : Colors.indigo.shade300),
        ),
        child: Text(
          record.isProspect ? 'PROSPECT' : 'ALLIEVO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: record.isProspect ? Colors.orange.shade900 : Colors.indigo.shade900),
        ),
      );
    }

    // ID Sistema e ID Google
    final sysIdShort = record.systemId != null ? (record.systemId!.length > 8 ? record.systemId!.substring(0, 8) : record.systemId!) : '-';
    final gglIdShort = record.googleId != null && record.googleId!.isNotEmpty
        ? (record.googleId!.contains('/') ? record.googleId!.split('/').last : record.googleId!)
        : '-';

    return DataRow(
      cells: [
        DataCell(tipoWidget),
        DataCell(
          InkWell(
            onTap: () => _showDiffDialog(record),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(record.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (record.differences.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Clicca per vedere le differenze: ${record.differences.join(", ")}',
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.info_outline, size: 14, color: Colors.brown),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        DataCell(Text(record.telefono.isNotEmpty ? record.telefono : '-')),
        DataCell(Text(record.email.isNotEmpty ? record.email : '-')),
        DataCell(
          record.systemId != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sysIdShort, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      tooltip: 'Copia ID Sistema',
                      onPressed: () => _copyToClipboard(record.systemId!, 'ID Sistema'),
                    ),
                  ],
                )
              : const Text('-'),
        ),
        DataCell(
          record.googleId != null && record.googleId!.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(gglIdShort, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      tooltip: 'Copia ID Google',
                      onPressed: () => _copyToClipboard(record.googleId!, 'ID Google'),
                    ),
                  ],
                )
              : const Text('-'),
        ),
        DataCell(
          InkWell(
            onTap: () => _showDiffDialog(record),
            child: _buildStatusChip(record.status),
          ),
        ),
        DataCell(
          isProcessing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : _buildActionButton(record),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'synced':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        icon = Icons.check_circle;
        label = 'Sincronizzato';
        break;
      case 'modified_system':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade800;
        icon = Icons.arrow_upward;
        label = 'Modificato nel sistema';
        break;
      case 'modified_google':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        icon = Icons.arrow_downward;
        label = 'Modificato su Google';
        break;
      case 'only_system':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        icon = Icons.phone_android;
        label = 'Presente solo nel sistema';
        break;
      case 'only_google':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        icon = Icons.cloud;
        label = 'Presente solo su Google';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        icon = Icons.info;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }

  Widget _buildActionButton(GoogleContactComparisonRecord record) {
    switch (record.status) {
      case 'synced':
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            side: BorderSide(color: Colors.green.shade300),
          ),
          icon: const Icon(Icons.check, size: 14, color: Colors.green),
          label: const Text('Allineato', style: TextStyle(fontSize: 11, color: Colors.green)),
          onPressed: () => _pushItem(record),
        );

      case 'modified_system':
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          icon: const Icon(Icons.cloud_upload, size: 14),
          label: const Text('Aggiorna Google', style: TextStyle(fontSize: 11)),
          onPressed: () => _pushItem(record),
        );

      case 'modified_google':
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          icon: const Icon(Icons.cloud_download, size: 14),
          label: const Text('Aggiorna Sistema', style: TextStyle(fontSize: 11)),
          onPressed: () => _pullItem(record),
        );

      case 'only_system':
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          icon: const Icon(Icons.person_add, size: 14),
          label: const Text('Crea su Google', style: TextStyle(fontSize: 11)),
          onPressed: () => _pushItem(record),
        );

      case 'only_google':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.input, size: 14),
              label: const Text('Importa nel Sistema', style: TextStyle(fontSize: 11)),
              onPressed: () => _importItem(record),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: 'Elimina da Google',
              onPressed: () => _deleteGoogleItem(record),
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }
}
