import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class PagamentiScreen extends StatefulWidget {
  const PagamentiScreen({super.key});

  @override
  State<PagamentiScreen> createState() => _PagamentiScreenState();
}

class _PagamentiScreenState extends State<PagamentiScreen> {
  final ApiService _api = ApiService();
  List<Pagamento> _pagamenti = [];
  List<Corso> _corsi = [];
  List<Scuola> _scuole = [];
  List<Allievo> _allievi = [];
  bool _loading = true;

  String? _filterCorsoId;
  String? _filterScuolaId;
  String? _filterTrimestre;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final pagamenti = await _api.getPagamenti(
      corsoId: _filterCorsoId,
      scuolaId: _filterScuolaId,
      trimestre: _filterTrimestre,
    );
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    final allievi = await _api.getAllievi(isProspect: false);

    setState(() {
      _pagamenti = pagamenti;
      _corsi = corsi;
      _scuole = scuole;
      _allievi = allievi;
      _loading = false;
    });
  }

  void _showAddPaymentDialog() {
    String? selectedAllievoId = _allievi.isNotEmpty ? _allievi.first.id : null;
    String? selectedCorsoId = _corsi.isNotEmpty ? _corsi.first.id : null;
    final importoController = TextEditingController(text: '150.00');
    final noteController = TextEditingController();
    String trimestre = 'T1';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Registra Pagamento Trimestrale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedAllievoId,
                  decoration: const InputDecoration(labelText: 'Allievo *'),
                  items: _allievi.map((a) {
                    return DropdownMenuItem(value: a.id, child: Text(a.nomeCompleto));
                  }).toList(),
                  onChanged: (v) {
                    setDlgState(() {
                      selectedAllievoId = v;
                      // Se l'allievo ha un corso associato, preselezionalo
                      final found = _allievi.firstWhere((a) => a.id == v);
                      if (found.corsoId != null) {
                        selectedCorsoId = found.corsoId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCorsoId,
                  decoration: const InputDecoration(labelText: 'Corso *'),
                  items: _corsi.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text('${c.scuolaNome} - ${c.livelloDisplay}'));
                  }).toList(),
                  onChanged: (v) => setDlgState(() => selectedCorsoId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: trimestre,
                  decoration: const InputDecoration(labelText: 'Trimestre *'),
                  items: const [
                    DropdownMenuItem(value: 'T1', child: Text('Primo Trimestre (T1)')),
                    DropdownMenuItem(value: 'T2', child: Text('Secondo Trimestre (T2)')),
                    DropdownMenuItem(value: 'T3', child: Text('Terzo Trimestre (T3)')),
                  ],
                  onChanged: (v) => setDlgState(() => trimestre = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: importoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo (€) *',
                    prefixText: '€ ',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data Pagamento: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDlgState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note aggiuntive (es. bonifico, contanti)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                if (selectedAllievoId == null || selectedCorsoId == null) return;
                final data = {
                  'allievo': selectedAllievoId,
                  'corso': selectedCorsoId,
                  'importo': double.tryParse(importoController.text.trim()) ?? 150.00,
                  'trimestre': trimestre,
                  'data_pagamento': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'note': noteController.text.trim(),
                };
                await _api.createPagamento(data);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              child: const Text('Registra Pagamento'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totaleIncassato = _pagamenti.fold<double>(0.0, (sum, p) => sum + p.importo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Pagamenti'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPaymentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Pagamento'),
      ),
      body: Column(
        children: [
          // Filtri
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<String?>(
                  value: _filterScuolaId,
                  hint: const Text('Tutte le Scuole'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutte le Scuole')),
                    ..._scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))),
                  ],
                  onChanged: (val) {
                    setState(() => _filterScuolaId = val);
                    _loadAll();
                  },
                ),
                DropdownButton<String?>(
                  value: _filterCorsoId,
                  hint: const Text('Tutti i Corsi'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutti i Corsi')),
                    ..._corsi.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.scuolaNome} - ${c.livelloDisplay}'))),
                  ],
                  onChanged: (val) {
                    setState(() => _filterCorsoId = val);
                    _loadAll();
                  },
                ),
                DropdownButton<String?>(
                  value: _filterTrimestre,
                  hint: const Text('Tutti i Trimestri'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tutti i Trimestri')),
                    DropdownMenuItem(value: 'T1', child: Text('Primo Trimestre (T1)')),
                    DropdownMenuItem(value: 'T2', child: Text('Secondo Trimestre (T2)')),
                    DropdownMenuItem(value: 'T3', child: Text('Terzo Trimestre (T3)')),
                  ],
                  onChanged: (val) {
                    setState(() => _filterTrimestre = val);
                    _loadAll();
                  },
                ),
              ],
            ),
          ),
          // Banner Totali
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Totale pagamenti: ${_pagamenti.length}', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                Text('Incassato: € ${totaleIncassato.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.teal.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Lista pagamenti
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_pagamenti.isEmpty)
            const Expanded(child: Center(child: Text('Nessun pagamento registrato con i filtri selezionati.')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _pagamenti.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = _pagamenti[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text(p.trimestre, style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p.allievoNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.scuolaNome} | ${p.corsoDescrizione}'),
                        Text('Data: ${p.dataPagamento}${p.note.isNotEmpty ? ' | Note: ' + p.note : ''}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    trailing: Text('€ ${p.importo.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
