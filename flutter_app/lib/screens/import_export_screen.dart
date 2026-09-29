import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  // Stato Import
  String _importModel = 'allievi';
  final _importTextController = TextEditingController();
  bool _importing = false;
  Map<String, dynamic>? _importResult;

  // Stato Export
  String _exportModel = 'allievi';
  String _exportFormat = 'xlsx';
  String? _exportScuolaId;
  String? _exportCorsoId;
  String? _exportTrimestre;
  List<Scuola> _scuole = [];
  List<Corso> _corsi = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFilters();
  }

  Future<void> _downloadFile(String url, String description) async {
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadFilters() async {
    final scuole = await _api.getScuole();
    final corsi = await _api.getCorsi();
    setState(() {
      _scuole = scuole;
      _corsi = corsi;
    });
  }

  Future<void> _executeImport() async {
    if (_importModel == 'global') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il ripristino globale da file .xlsx richiede l\'integrazione di un file picker (es. pacchetto file_picker) non ancora presente nell\'app. Usa le API via Postman per ora.')),
      );
      return;
    }

    final text = _importTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incolla il contenuto CSV del file da importare.')),
      );
      return;
    }

    setState(() {
      _importing = true;
      _importResult = null;
    });

    final bytes = utf8.encode(text);
    final res = await _api.uploadImportFile(_importModel, bytes, 'import_$_importModel.csv');

    setState(() {
      _importing = false;
      _importResult = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import & Export Dati'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.file_upload), text: 'Importa Dati'),
            Tab(icon: Icon(Icons.file_download), text: 'Esporta Dati'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: IMPORT DATI ─────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Seleziona il tipo di dati da importare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _importModel,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'global', child: Text('Ripristino Globale DB (File .xlsx)')),
                    DropdownMenuItem(value: 'allievi', child: Text('Allievi & Prospect')),
                    DropdownMenuItem(value: 'presenze', child: Text('Presenze Lezioni')),
                    DropdownMenuItem(value: 'pagamenti', child: Text('Pagamenti Trimestrali')),
                  ],
                  onChanged: (val) => setState(() {
                    _importModel = val!;
                    _importResult = null;
                  }),
                ),
                const SizedBox(height: 16),
                const Text('2. Template di esempio con intestazioni corrette', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.table_view, color: Colors.green),
                      label: const Text('Scarica Template Excel (.xlsx)'),
                      onPressed: () {
                        final url = _api.getTemplateUrl(_importModel, format: 'xlsx');
                        _downloadFile(url, 'Template Excel $_importModel');
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.description, color: Colors.blueGrey),
                      label: const Text('Scarica Template CSV (.csv)'),
                      onPressed: () {
                        final url = _api.getTemplateUrl(_importModel, format: 'csv');
                        _downloadFile(url, 'Template CSV $_importModel');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('3. Incolla o carica il contenuto CSV / Dati', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _importTextController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Incolla qui le righe CSV con intestazione (separatore ; o ,)\nEs:\nnome;cognome;ruolo;telefono;livello;recensione\nMario;Rossi;leader;+39333112233;principiante;si',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                    icon: _importing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.upload),
                    label: Text(_importing ? 'Importazione in corso...' : 'Avvia Importazione Dati',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _importing ? null : _executeImport,
                  ),
                ),
                if (_importResult != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _importResult!['success'] == true ? Colors.green.shade50 : Colors.red.shade50,
                      border: Border.all(color: _importResult!['success'] == true ? Colors.green.shade300 : Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Esito Importazione: ${_importResult!['success'] == true ? "Completata" : "Errore"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (_importResult!['creati'] != null) Text('• Nuovi record creati: ${_importResult!['creati']}'),
                        if (_importResult!['aggiornati'] != null) Text('• Record aggiornati: ${_importResult!['aggiornati']}'),
                        if (_importResult!['presenze_salvate'] != null) Text('• Presenze registrate: ${_importResult!['presenze_salvate']}'),
                        if (_importResult!['pagamenti_salvati'] != null) Text('• Pagamenti registrati: ${_importResult!['pagamenti_salvati']}'),
                        if (_importResult!['errori'] != null && (_importResult!['errori'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Segnalazioni ed errori per riga:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          ...(_importResult!['errori'] as List).map((err) => Text('⚠️ $err', style: const TextStyle(color: Colors.red, fontSize: 12))),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── TAB 2: EXPORT DATI ─────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1. Seleziona tipo di dati da esportare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _exportModel,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'global', child: Text('Backup Globale (Tutto il DB in Excel)')),
                    DropdownMenuItem(value: 'allievi', child: Text('Allievi & Prospect')),
                    DropdownMenuItem(value: 'presenze', child: Text('Presenze Lezioni')),
                    DropdownMenuItem(value: 'pagamenti', child: Text('Pagamenti Trimestrali')),
                    DropdownMenuItem(value: 'lezioni', child: Text('Calendario Lezioni')),
                  ],
                  onChanged: (val) => setState(() {
                    _exportModel = val!;
                    if (val == 'global') _exportFormat = 'xlsx'; // Forza excel per il globale
                  }),
                ),
                const SizedBox(height: 16),
                const Text('2. Formato del file', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    Radio<String>(
                      value: 'xlsx',
                      groupValue: _exportFormat,
                      onChanged: (v) => setState(() => _exportFormat = v!),
                    ),
                    const Text('Excel (.xlsx) - Consigliato'),
                    const SizedBox(width: 24),
                    Radio<String>(
                      value: 'csv',
                      groupValue: _exportFormat,
                      onChanged: (v) => setState(() => _exportFormat = v!),
                    ),
                    const Text('CSV (.csv)'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('3. Filtri opzionali', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _exportScuolaId,
                  decoration: const InputDecoration(labelText: 'Filtra per Scuola', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutte le Scuole')),
                    ..._scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))),
                  ],
                  onChanged: (v) => setState(() => _exportScuolaId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _exportCorsoId,
                  decoration: const InputDecoration(labelText: 'Filtra per Corso', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutti i Corsi')),
                    ..._corsi.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.scuolaNome} - ${c.livelloDisplay}'))),
                  ],
                  onChanged: (v) => setState(() => _exportCorsoId = v),
                ),
                if (_exportModel == 'pagamenti') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _exportTrimestre,
                    decoration: const InputDecoration(labelText: 'Filtra per Trimestre', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tutti i Trimestri')),
                      DropdownMenuItem(value: 'T1', child: Text('Primo Trimestre (T1)')),
                      DropdownMenuItem(value: 'T2', child: Text('Secondo Trimestre (T2)')),
                      DropdownMenuItem(value: 'T3', child: Text('Terzo Trimestre (T3)')),
                    ],
                    onChanged: (v) => setState(() => _exportTrimestre = v),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.download),
                    label: const Text('Genera ed Esporta File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final url = _api.getExportUrl(
                        _exportModel,
                        format: _exportFormat,
                        scuolaId: _exportScuolaId,
                        corsoId: _exportCorsoId,
                        trimestre: _exportTrimestre,
                      );
                      _downloadFile(url, 'Esportazione $_exportModel ($_exportFormat)');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
