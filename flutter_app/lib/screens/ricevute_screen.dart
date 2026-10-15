import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pdf_report_service.dart';

class RicevuteScreen extends StatefulWidget {
  const RicevuteScreen({super.key});

  @override
  State<RicevuteScreen> createState() => _RicevuteScreenState();
}

class _RicevuteScreenState extends State<RicevuteScreen> {
  final ApiService _api = ApiService();

  List<Ricevuta> _ricevute = [];
  List<Allievo> _allievi = [];
  List<int> _anniDisponibili = [DateTime.now().year];
  int? _selectedAnno;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  ContatoreRicevuteInfo? _contatoreAnnoCorrente;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedAnno = DateTime.now().year;
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      final anni = await _api.getAnniRicevute();
      final annoTarget = _selectedAnno ?? DateTime.now().year;
      final contatore = await _api.getContatoreRicevute(anno: annoTarget);
      final ricevute = await _api.getRicevute(anno: _selectedAnno, search: _searchQuery);
      final allievi = await _api.getAllievi(isProspect: false);

      setState(() {
        _anniDisponibili = anni;
        _contatoreAnnoCorrente = contatore;
        _ricevute = ricevute;
        _allievi = allievi;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento ricevute: $e')),
        );
      }
    }
  }

  Future<void> _loadRicevuteOnly() async {
    final annoTarget = _selectedAnno ?? DateTime.now().year;
    final contatore = await _api.getContatoreRicevute(anno: annoTarget);
    final ricevute = await _api.getRicevute(anno: _selectedAnno, search: _searchQuery);

    if (mounted) {
      setState(() {
        _contatoreAnnoCorrente = contatore;
        _ricevute = ricevute;
      });
    }
  }

  // ─── 1. Modifica Contatore Anno Corrente ─────────────────────────────
  void _showModificaContatoreDialog() {
    final anno = _selectedAnno ?? DateTime.now().year;
    final ultimoNum = _contatoreAnnoCorrente?.ultimoNumero ?? 0;
    final controller = TextEditingController(text: ultimoNum.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: Colors.indigo),
            const SizedBox(width: 8),
            Text('Contatore Ricevute $anno'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imposta il numero dell\'ultima ricevuta emessa per l\'anno $anno.\n'
              'La prossima ricevuta creata prenderà automaticamente il numero successivo.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Ultimo numero ricevuta *',
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                helperText: 'Es. Se hai emesso fino alla ricevuta 25, inserisci 25.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val == null || val < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserisci un numero valido maggiore o uguale a 0.')),
                );
                return;
              }
              final res = await _api.aggiornaContatoreRicevute(anno, val);
              if (ctx.mounted) Navigator.pop(ctx);
              if (res != null) {
                if (mounted) {
                  setState(() {
                    _contatoreAnnoCorrente = res;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contatore per l\'anno $anno aggiornato a N. ${res.ultimoNumero}.')),
                  );
                }
                _loadRicevuteOnly();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Errore durante l\'aggiornamento del contatore.')),
                  );
                }
              }
            },
            child: const Text('Salva Contatore'),
          ),
        ],
      ),
    );
  }

  // ─── 3. Inserimento Nuova Ricevuta ──────────────────────────────────
  void _showAddRicevutaDialog() {
    final currYear = DateTime.now().year;
    final int prossimoNum = (_contatoreAnnoCorrente?.ultimoNumero ?? 0) + 1;

    final intestatarioController = TextEditingController();
    final causaleController = TextEditingController(text: 'Quota corso di Tango Argentino');
    final importoController = TextEditingController(text: '150.00');
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedAllievoId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_circle, color: Colors.teal),
              const SizedBox(width: 8),
              const Text('Emetti Nuova Ricevuta'),
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
                      // Sincronizza i controller
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

                  // Data (Default: Data di sistema)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.indigo),
                    title: Text(
                      'Data Emissione: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text('Default data odierna di sistema', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                          setDlgState(() => selectedDate = picked);
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
                  if (selectedAllievoId != null) 'allievo': selectedAllievoId,
                };

                final nuovaRicevuta = await _api.createRicevuta(payload);
                if (ctx.mounted) Navigator.pop(ctx);

                if (nuovaRicevuta != null) {
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
                            _stampaRicevuta(nuovaRicevuta);
                          },
                        ),
                      ),
                    );
                  }
                  _loadRicevuteOnly();
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

  // ─── Modifica Ricevuta Esistente ───────────────────────────────────
  void _showEditRicevutaDialog(Ricevuta r) {
    final intestatarioController = TextEditingController(text: r.intestatario);
    final causaleController = TextEditingController(text: r.causale);
    final importoController = TextEditingController(text: r.importo.toStringAsFixed(2));
    final numeroController = TextEditingController(text: r.numero.toString());
    final noteController = TextEditingController(text: r.note);
    DateTime selectedDate = DateTime.tryParse(r.data) ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Modifica Ricevuta ${r.numeroDisplay}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: numeroController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Numero Progressivo *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Anno'),
                          child: Text('${r.anno}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: intestatarioController,
                    decoration: const InputDecoration(labelText: 'Intestatario *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: causaleController,
                    decoration: const InputDecoration(labelText: 'Causale *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: importoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Importo (€) *', prefixText: '€ '),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Data: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
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
                    decoration: const InputDecoration(labelText: 'Note aggiuntive'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                final numVal = int.tryParse(numeroController.text.trim()) ?? r.numero;
                final impVal = double.tryParse(importoController.text.trim()) ?? r.importo;

                final payload = {
                  'numero': numVal,
                  'intestatario': intestatarioController.text.trim(),
                  'causale': causaleController.text.trim(),
                  'importo': impVal,
                  'data': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'note': noteController.text.trim(),
                };

                final updated = await _api.updateRicevuta(r.id, payload);
                if (ctx.mounted) Navigator.pop(ctx);
                if (updated != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ricevuta aggiornata con successo.')),
                    );
                  }
                  _loadRicevuteOnly();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore durante l\'aggiornamento.')),
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

  // ─── Eliminazione Ricevuta ─────────────────────────────────────────
  Future<void> _deleteRicevuta(Ricevuta r) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Elimina Ricevuta'),
        content: Text('Vuoi davvero eliminare la ricevuta ${r.numeroDisplay} intestata a "${r.intestatario}"?'),
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
      final ok = await _api.deleteRicevuta(r.id);
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ricevuta ${r.numeroDisplay} eliminata.')),
          );
        }
        _loadRicevuteOnly();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore durante l\'eliminazione.')),
          );
        }
      }
    }
  }

  Future<void> _stampaRicevuta(Ricevuta r) async {
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

  void _esportaElenco() {
    PdfReportService.generaReportRicevute(
      context: context,
      ricevute: _ricevute,
      anno: _selectedAnno,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currYear = DateTime.now().year;
    final ultimoNumero = _contatoreAnnoCorrente?.ultimoNumero ?? 0;
    final totaleIncassato = _ricevute.fold<double>(0.0, (sum, r) => sum + r.importo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Ricevute'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
            tooltip: 'Esporta lista ricevute PDF',
            onPressed: _esportaElenco,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRicevutaDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuova Ricevuta'),
      ),
      body: Column(
        children: [
          // ─── 1. Card Contatore Anno Corrente ──────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Ricevute Anno Corrente ($currYear)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Anno ${_contatoreAnnoCorrente?.anno ?? currYear}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Arrivati alla ricevuta: N. $ultimoNumero',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prossimo numero: N. ${ultimoNumero + 1}  •  Emesse nel database: ${_contatoreAnnoCorrente?.conteggioEmesse ?? _ricevute.length}',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifica Contatore'),
                  onPressed: _showModificaContatoreDialog,
                ),
              ],
            ),
          ),

          // ─── 2. Filtri & Ricerca ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Filtro Anno
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Filtra per Anno: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    DropdownButton<int?>(
                      value: _selectedAnno,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tutti gli anni')),
                        ...({
                          if (_selectedAnno != null) _selectedAnno!,
                          ..._anniDisponibili,
                          DateTime.now().year,
                        }.toList()..sort((a, b) => b.compareTo(a)))
                            .map((a) => DropdownMenuItem(value: a, child: Text('Anno $a'))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedAnno = val);
                        _loadRicevuteOnly();
                      },
                    ),
                  ],
                ),

                // Barra Ricerca
                SizedBox(
                  width: 280,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cerca per intestatario, causale...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadRicevuteOnly();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val.trim());
                      _loadRicevuteOnly();
                    },
                  ),
                ),
              ],
            ),
          ),

          // ─── Riepilogo Totali ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ricevute visualizzate: ${_ricevute.length}',
                  style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Totale Importo: € ${totaleIncassato.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.teal.shade900, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // ─── Elenco Ricevute ────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_ricevute.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      _selectedAnno != null
                          ? 'Nessuna ricevuta emessa per l\'anno $_selectedAnno.'
                          : 'Nessuna ricevuta presente nel sistema.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Emetti la prima ricevuta'),
                      onPressed: _showAddRicevutaDialog,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _ricevute.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _ricevute[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        '${r.numero}',
                        style: TextStyle(
                          color: Colors.indigo.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          r.intestatario,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r.numeroDisplay,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          'Causale: ${r.causale}',
                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 13),
                        ),
                        Text(
                          'Data: ${r.data}${r.note.isNotEmpty ? " • Note: ${r.note}" : ""}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '€ ${r.importo.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                          tooltip: 'Stampa Ricevuta PDF',
                          onPressed: () => _stampaRicevuta(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Modifica Ricevuta',
                          onPressed: () => _showEditRicevutaDialog(r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Elimina Ricevuta',
                          onPressed: () => _deleteRicevuta(r),
                        ),
                      ],
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
