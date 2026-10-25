import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pdf_report_service.dart';

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
  bool? _filterHasRicevuta;
  DateTime? _filterDataDa;
  DateTime? _filterDataA;

  int? _sortColumnIndex = 3;
  bool _sortAscending = false;

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
      hasRicevuta: _filterHasRicevuta,
      dataDa: _filterDataDa != null ? DateFormat('yyyy-MM-dd').format(_filterDataDa!) : null,
      dataA: _filterDataA != null ? DateFormat('yyyy-MM-dd').format(_filterDataA!) : null,
    );
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    final allievi = await _api.getAllievi(isProspect: false);

    setState(() {
      _pagamenti = pagamenti;
      if (_sortColumnIndex != null) {
        _applySort(_sortColumnIndex!, _sortAscending);
      }
      _corsi = corsi;
      _scuole = scuole;
      _allievi = allievi;
      _loading = false;
    });
  }

  Future<void> _deletePagamento(Pagamento p) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Elimina Pagamento'),
        content: Text('Vuoi davvero eliminare il pagamento di ${p.allievoNome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (conf == true) {
      final ok = await _api.deletePagamento(p.id);
      if (ok) {
        _loadAll();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore eliminazione.')));
        }
      }
    }
  }

  void _showAddPaymentDialog() {
    String? selectedAllievoId = _allievi.isNotEmpty ? _allievi.first.id : null;
    String? selectedCorsoId = _corsi.isNotEmpty ? _corsi.first.id : null;
    if (_allievi.isNotEmpty && _allievi.first.corsoId != null) {
      selectedCorsoId = _allievi.first.corsoId;
    }
    final importoController = TextEditingController(text: '150.00');
    final causaleController = TextEditingController(text: 'Quota Primo Trimestre (T1)');
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
                    return DropdownMenuItem(value: c.id, child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.orario})'));
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
                  onChanged: (v) => setDlgState(() {
                    trimestre = v!;
                    if (causaleController.text.startsWith('Quota ') || causaleController.text.isEmpty) {
                      if (v == 'T1') causaleController.text = 'Quota Primo Trimestre (T1)';
                      if (v == 'T2') causaleController.text = 'Quota Secondo Trimestre (T2)';
                      if (v == 'T3') causaleController.text = 'Quota Terzo Trimestre (T3)';
                    }
                  }),
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
                TextField(
                  controller: causaleController,
                  decoration: const InputDecoration(
                    labelText: 'Causale Pagamento *',
                    hintText: 'es. Quota Primo Trimestre, Mensilità Ottobre',
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
                  'causale': causaleController.text.trim(),
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

  void _showEditPaymentDialog(Pagamento p) {
    final importoController = TextEditingController(text: p.importo.toStringAsFixed(2));
    final causaleController = TextEditingController(text: p.causale.isNotEmpty ? p.causale : p.causaleDisplay);
    final noteController = TextEditingController(text: p.note);
    String trimestre = p.trimestre;
    DateTime selectedDate = DateTime.tryParse(p.dataPagamento) ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Modifica Pagamento - ${p.allievoNome}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.scuolaNome} - ${p.corsoDescrizione}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: trimestre,
                  decoration: const InputDecoration(labelText: 'Trimestre *'),
                  items: const [
                    DropdownMenuItem(value: 'T1', child: Text('Primo Trimestre (T1)')),
                    DropdownMenuItem(value: 'T2', child: Text('Secondo Trimestre (T2)')),
                    DropdownMenuItem(value: 'T3', child: Text('Terzo Trimestre (T3)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDlgState(() {
                        trimestre = v;
                        if (causaleController.text.startsWith('Quota ') || causaleController.text.isEmpty) {
                          if (v == 'T1') causaleController.text = 'Quota Primo Trimestre (T1)';
                          if (v == 'T2') causaleController.text = 'Quota Secondo Trimestre (T2)';
                          if (v == 'T3') causaleController.text = 'Quota Terzo Trimestre (T3)';
                        }
                      });
                    }
                  },
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
                TextField(
                  controller: causaleController,
                  decoration: const InputDecoration(
                    labelText: 'Causale Pagamento *',
                    hintText: 'es. Quota Primo Trimestre, Mensilità Ottobre',
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
                final double? importoVal = double.tryParse(importoController.text.trim());
                if (importoVal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci un importo valido.')),
                  );
                  return;
                }
                final data = {
                  'importo': importoVal,
                  'causale': causaleController.text.trim(),
                  'trimestre': trimestre,
                  'data_pagamento': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'note': noteController.text.trim(),
                };
                final res = await _api.updatePagamento(p.id, data);
                if (ctx.mounted) Navigator.pop(ctx);
                if (res != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pagamento aggiornato con successo.')),
                    );
                  }
                  _loadAll();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore durante l\'aggiornamento del pagamento.')),
                    );
                  }
                }
              },
              child: const Text('Salva Modifiche'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stampaRicevutaEmessa(Ricevuta r) async {
    try {
      final templateBytes = await _api.getRicevutaPdf(r.id);
      if (templateBytes != null && templateBytes.isNotEmpty) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => templateBytes,
          name: 'Ricevuta_${r.numero}_${r.anno}.pdf',
        );
        return;
      }
    } catch (e) {
      debugPrint('Fallback stampa ricevuta: $e');
    }

    if (mounted) {
      PdfReportService.generaRicevutaFiscale(context: context, ricevuta: r);
    }
  }

  Future<void> _mostraEmettiRicevutaDialog(Pagamento p) async {
    final dataPagamentoParsed = DateTime.tryParse(p.dataPagamento);
    DateTime selectedDate = dataPagamentoParsed ?? DateTime.now();
    int currYear = selectedDate.year;

    // Recupera contatore per l'anno di riferimento
    final contatoreInfo = await _api.getContatoreRicevute(anno: currYear);
    int prossimoNum = contatoreInfo?.prossimoNumero ?? ((contatoreInfo?.ultimoNumero ?? 0) + 1);

    if (!mounted) return;

    final intestatarioController = TextEditingController(text: p.allievoNome);

    String causaleIniziale = p.causale.trim();
    if (causaleIniziale.isEmpty) {
      causaleIniziale = p.causaleDisplay.trim();
    }
    if (causaleIniziale.isEmpty) {
      causaleIniziale = 'Quota corso di Tango Argentino';
    }
    final causaleController = TextEditingController(text: causaleIniziale);
    final importoController = TextEditingController(text: p.importo.toStringAsFixed(2));
    final noteController = TextEditingController(text: p.note);
    String? selectedAllievoId = p.allievoId.isNotEmpty ? p.allievoId : null;
    bool apriStampaSubito = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.teal),
              SizedBox(width: 8),
              Text('Emetti Ricevuta'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info prossimo numero
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verrà assegnata la Ricevuta N. $prossimoNum/$currYear',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Intestatario con Autocomplete / suggerimenti da Allievi
                  Autocomplete<Allievo>(
                    initialValue: TextEditingValue(text: p.allievoNome),
                    displayStringForOption: (a) => a.nomeCompleto,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Allievo>.empty();
                      }
                      return _allievi.where((a) =>
                          a.nomeCompleto.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (Allievo selection) {
                      setDlgState(() {
                        intestatarioController.text = selection.nomeCompleto;
                        selectedAllievoId = selection.id;
                      });
                    },
                    fieldViewBuilder: (context, fieldTextEditingController, focusNode, onFieldSubmitted) {
                      fieldTextEditingController.addListener(() {
                        intestatarioController.text = fieldTextEditingController.text;
                      });
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Intestatario (Nome e Cognome) *',
                          hintText: 'es. Mario Rossi',
                          prefixIcon: const Icon(Icons.person),
                          suffixIcon: fieldTextEditingController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    fieldTextEditingController.clear();
                                    selectedAllievoId = null;
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Causale
                  TextField(
                    controller: causaleController,
                    decoration: const InputDecoration(
                      labelText: 'Causale Pagamento *',
                      hintText: 'es. Quota corso di Tango Argentino, Quota sociale',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Importo
                  TextField(
                    controller: importoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Importo (€) *',
                      prefixText: '€ ',
                      prefixIcon: Icon(Icons.euro),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Data di emissione
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                    title: Text(
                      'Data Emissione: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text('Default data del pagamento registrato', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Cambia'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          if (picked.year != selectedDate.year) {
                            final c = await _api.getContatoreRicevute(anno: picked.year);
                            setDlgState(() {
                              selectedDate = picked;
                              currYear = picked.year;
                              prossimoNum = c?.prossimoNumero ?? ((c?.ultimoNumero ?? 0) + 1);
                            });
                          } else {
                            setDlgState(() => selectedDate = picked);
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Note aggiuntive
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (opzionale, es. bonifico, contanti)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Opzione stampa immediata
                  CheckboxListTile(
                    value: apriStampaSubito,
                    onChanged: (val) => setDlgState(() => apriStampaSubito = val ?? true),
                    title: const Text('Apri anteprima di stampa subito dopo l\'emissione', style: TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton.icon(
              icon: const Icon(Icons.receipt),
              label: const Text('Emetti Ricevuta'),
              onPressed: () async {
                final intestatario = intestatarioController.text.trim();
                final causale = causaleController.text.trim();
                final importo = double.tryParse(importoController.text.trim());

                if (intestatario.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci l\'intestatario della ricevuta.')),
                  );
                  return;
                }
                if (causale.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci la causale della ricevuta.')),
                  );
                  return;
                }
                if (importo == null || importo <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci un importo valido.')),
                  );
                  return;
                }

                final payload = {
                  'intestatario': intestatario,
                  'causale': causale,
                  'importo': importo,
                  'data': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'anno': selectedDate.year,
                  'note': noteController.text.trim(),
                  if (selectedAllievoId != null && selectedAllievoId!.isNotEmpty) 'allievo': selectedAllievoId,
                  'pagamento': p.id,
                };

                final nuovaRicevuta = await _api.createRicevuta(payload);
                if (ctx.mounted) Navigator.pop(ctx);

                if (nuovaRicevuta != null) {
                  _loadAll();
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Ricevuta ${nuovaRicevuta.numeroDisplay} emessa con successo!'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                        showCloseIcon: true,
                        action: SnackBarAction(
                          label: 'Stampa PDF',
                          onPressed: () {
                            messenger.hideCurrentSnackBar();
                            _stampaRicevutaEmessa(nuovaRicevuta);
                          },
                        ),
                      ),
                    );

                    if (apriStampaSubito) {
                      _stampaRicevutaEmessa(nuovaRicevuta);
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore durante l\'emissione della ricevuta.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostraOpzioniRicevutaEmessa(Pagamento p) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt, color: Colors.teal),
            const SizedBox(width: 8),
            Text('Ricevuta ${p.ricevutaNumero ?? "Emessa"}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ricevuta ${p.ricevutaNumero ?? ""} già emessa per questo pagamento.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Intestatario: ${p.allievoNome}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Importo: € ${p.importo.toStringAsFixed(2)} | Data: ${p.dataPagamento}'),
            const SizedBox(height: 4),
            Text('Causale: ${p.causaleDisplay}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Emetti Altra Ricevuta'),
            onPressed: () {
              Navigator.pop(ctx);
              _mostraEmettiRicevutaDialog(p);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Stampa / Scarica PDF'),
            onPressed: () async {
              Navigator.pop(ctx);
              if (p.ricevutaId != null) {
                final r = await _api.getRicevuta(p.ricevutaId!);
                if (r != null) {
                  _stampaRicevutaEmessa(r);
                  return;
                }
              }
              final bytes = await _api.getPagamentoRicevutaPdf(p.id);
              if (bytes != null && mounted) {
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name: 'Ricevuta_${p.ricevutaNumero ?? p.id}.pdf',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selezionaFiltroData() async {
    final scelta = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Filtra Pagamenti per Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.today, color: Colors.teal),
              title: const Text('Oggi'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
              onTap: () => Navigator.pop(ctx, 'oggi'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.indigo),
              title: const Text('Giorno specifico...'),
              subtitle: const Text('Seleziona una singola data da calendario'),
              onTap: () => Navigator.pop(ctx, 'giorno'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.deepPurple),
              title: const Text('Intervallo di date...'),
              subtitle: const Text('Seleziona periodo da data a data'),
              onTap: () => Navigator.pop(ctx, 'intervallo'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.amber),
              title: const Text('Questo mese'),
              subtitle: Text(DateFormat('MMMM yyyy').format(DateTime.now())),
              onTap: () => Navigator.pop(ctx, 'mese'),
            ),
            if (_filterDataDa != null)
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.red),
                title: const Text('Rimuovi filtro data', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
          ],
        ),
      ),
    );

    if (scelta == 'clear') {
      setState(() {
        _filterDataDa = null;
        _filterDataA = null;
      });
      _loadAll();
      return;
    }

    if (scelta == 'oggi') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      setState(() {
        _filterDataDa = today;
        _filterDataA = today;
      });
      _loadAll();
      return;
    }

    if (scelta == 'mese') {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      setState(() {
        _filterDataDa = firstDay;
        _filterDataA = lastDay;
      });
      _loadAll();
      return;
    }

    if (scelta == 'giorno') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _filterDataDa ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        helpText: 'SELEZIONA DATA PAGAMENTO',
      );
      if (picked != null) {
        final d = DateTime(picked.year, picked.month, picked.day);
        setState(() {
          _filterDataDa = d;
          _filterDataA = d;
        });
        _loadAll();
      }
      return;
    }

    if (scelta == 'intervallo') {
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        initialDateRange: (_filterDataDa != null && _filterDataA != null)
            ? DateTimeRange(start: _filterDataDa!, end: _filterDataA!)
            : null,
        helpText: 'SELEZIONA INTERVALLO DATE',
      );
      if (pickedRange != null) {
        setState(() {
          _filterDataDa = DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day);
          _filterDataA = DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day);
        });
        _loadAll();
      }
      return;
    }
  }

  void _esportaReportPagamenti() {
    String filtri = '';
    if (_filterScuolaId != null) filtri += 'Scuola, ';
    if (_filterCorsoId != null) filtri += 'Corso, ';
    if (_filterTrimestre != null) filtri += 'Trimestre $_filterTrimestre, ';
    if (_filterDataDa != null) {
      if (_filterDataDa == _filterDataA) {
        filtri += 'Data: ${DateFormat('dd/MM/yyyy').format(_filterDataDa!)}, ';
      } else {
        filtri += 'Periodo: ${DateFormat('dd/MM/yyyy').format(_filterDataDa!)} - ${DateFormat('dd/MM/yyyy').format(_filterDataA!)}, ';
      }
    }
    if (filtri.isNotEmpty) filtri = filtri.substring(0, filtri.length - 2);

    PdfReportService.generaReportPagamenti(
      context: context,
      pagamenti: _pagamenti,
      filtriAttivi: filtri,
    );
  }

  String _formatData(String dataIso) {
    if (dataIso.isEmpty) return '-';
    try {
      final d = DateTime.parse(dataIso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return dataIso;
    }
  }

  void _applySort(int columnIndex, bool ascending) {
    _pagamenti.sort((a, b) {
      int cmp = 0;
      switch (columnIndex) {
        case 0: // Cognome
          cmp = a.cognome.toLowerCase().compareTo(b.cognome.toLowerCase());
          if (cmp == 0) cmp = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          break;
        case 1: // Nome
          cmp = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          if (cmp == 0) cmp = a.cognome.toLowerCase().compareTo(b.cognome.toLowerCase());
          break;
        case 2: // Causale
          cmp = a.causaleDisplay.toLowerCase().compareTo(b.causaleDisplay.toLowerCase());
          break;
        case 3: // Data registrazione pagamento
          cmp = a.dataPagamento.compareTo(b.dataPagamento);
          break;
        case 4: // Importo
          cmp = a.importo.compareTo(b.importo);
          break;
      }
      return ascending ? cmp : -cmp;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySort(columnIndex, ascending);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totaleIncassato = _pagamenti.fold<double>(0.0, (sum, p) => sum + p.importo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Pagamenti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
            tooltip: 'Esporta lista pagamenti',
            onPressed: _esportaReportPagamenti,
          ),
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
                    ..._corsi.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.orario})'))),
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
                DropdownButton<bool?>(
                  value: _filterHasRicevuta,
                  hint: const Text('Stato Ricevuta: Tutte'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Stato Ricevuta: Tutte')),
                    DropdownMenuItem(value: true, child: Text('Solo con ricevuta emessa')),
                    DropdownMenuItem(value: false, child: Text('Solo senza ricevuta (da emettere)')),
                  ],
                  onChanged: (val) {
                    setState(() => _filterHasRicevuta = val);
                    _loadAll();
                  },
                ),
                // Filtro Data
                if (_filterDataDa == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Filtra per Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _selezionaFiltroData,
                  )
                else
                  InputChip(
                    avatar: const Icon(Icons.calendar_month, size: 16, color: Colors.teal),
                    label: Text(
                      _filterDataDa == _filterDataA
                          ? DateFormat('dd/MM/yyyy').format(_filterDataDa!)
                          : '${DateFormat('dd/MM/yy').format(_filterDataDa!)} - ${DateFormat('dd/MM/yy').format(_filterDataA!)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    backgroundColor: Colors.teal.shade50,
                    deleteIcon: const Icon(Icons.close, size: 16, color: Colors.teal),
                    onDeleted: () {
                      setState(() {
                        _filterDataDa = null;
                        _filterDataA = null;
                      });
                      _loadAll();
                    },
                    onPressed: _selezionaFiltroData,
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
                Row(
                  children: [
                    Text('Totale pagamenti: ${_pagamenti.length}', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Text(
                      '(${_pagamenti.where((p) => p.hasRicevuta).length} con ricevuta, ${_pagamenti.where((p) => !p.hasRicevuta).length} da emettere)',
                      style: TextStyle(color: Colors.teal.shade800, fontSize: 13),
                    ),
                  ],
                ),
                Text('Incassato: € ${totaleIncassato.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.teal.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Lista pagamenti tabellare
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_pagamenti.isEmpty)
            const Expanded(child: Center(child: Text('Nessun pagamento registrato con i filtri selezionati.')))
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            headingRowColor: WidgetStateProperty.all(Colors.teal.shade50.withValues(alpha: 0.5)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 64,
                            horizontalMargin: 16,
                            columnSpacing: 24,
                            showBottomBorder: true,
                            columns: [
                              DataColumn(
                                label: const Text('Cognome'),
                                onSort: _onSort,
                              ),
                              DataColumn(
                                label: const Text('Nome'),
                                onSort: _onSort,
                              ),
                              DataColumn(
                                label: const Text('Causale'),
                                onSort: _onSort,
                              ),
                              DataColumn(
                                label: const Text('Data registrazione pagamento'),
                                onSort: _onSort,
                              ),
                              DataColumn(
                                label: const Text('Importo'),
                                numeric: true,
                                onSort: _onSort,
                              ),
                              const DataColumn(
                                label: Text('Azioni'),
                              ),
                            ],
                            rows: _pagamenti.map((p) {
                              return DataRow(
                                cells: [
                                  // 1. Cognome
                                  DataCell(
                                    Text(
                                      p.cognome.isNotEmpty ? p.cognome : '-',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // 2. Nome
                                  DataCell(
                                    Text(p.nome.isNotEmpty ? p.nome : p.allievoNome),
                                  ),
                                  // 3. Causale
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.causaleDisplay,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        if (p.corsoDescrizione.isNotEmpty)
                                          Text(
                                            '${p.scuolaNome.isNotEmpty ? "${p.scuolaNome} • " : ""}${p.corsoDescrizione}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // 4. Data registrazione pagamento
                                  DataCell(
                                    Text(
                                      _formatData(p.dataPagamento),
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  // 5. Importo
                                  DataCell(
                                    Text(
                                      '€ ${p.importo.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  // 6. Azioni: Modifica, Eliminazione, Emissione Ricevuta
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Tasto di modifica
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Modifica pagamento',
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showEditPaymentDialog(p),
                                        ),
                                        const SizedBox(width: 8),
                                        // Tasto di eliminazione
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          tooltip: 'Elimina pagamento',
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deletePagamento(p),
                                        ),
                                        const SizedBox(width: 8),
                                        // Tasto di emissione ricevuta
                                        IconButton(
                                          icon: Icon(
                                            p.hasRicevuta ? Icons.receipt : Icons.receipt_long_outlined,
                                            color: p.hasRicevuta ? Colors.teal.shade700 : Colors.indigo,
                                            size: 20,
                                          ),
                                          tooltip: p.hasRicevuta
                                              ? 'Ricevuta ${p.ricevutaNumero ?? "emessa"} (gestisci / stampa)'
                                              : 'Emetti ricevuta',
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            if (p.hasRicevuta) {
                                              _mostraOpzioniRicevutaEmessa(p);
                                            } else {
                                              _mostraEmettiRicevutaDialog(p);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
