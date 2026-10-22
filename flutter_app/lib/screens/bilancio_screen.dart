import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class BilancioScreen extends StatefulWidget {
  const BilancioScreen({super.key});

  @override
  State<BilancioScreen> createState() => _BilancioScreenState();
}

class _BilancioScreenState extends State<BilancioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedAnno = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;
  final Set<int> _anniDisponibili = {2026};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAnniLoaded(List<int> anni) {
    if (anni.isNotEmpty) {
      bool changed = false;
      for (final a in anni) {
        if (a >= 2026 && _anniDisponibili.add(a)) {
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {});
      }
    }
  }

  List<int> _getSortedAnni() {
    final currentYear = DateTime.now().year;
    final maxBase = currentYear > 2026 ? currentYear : 2026;
    final set = <int>{
      ..._anniDisponibili.where((y) => y >= 2026),
      2026,
      if (_selectedAnno >= 2026) _selectedAnno,
    };
    for (int y = 2026; y <= maxBase + 4; y++) {
      set.add(y);
    }
    final list = set.toList()..sort();
    return list;
  }

  Widget _buildYearSelector() {
    final sortedAnni = _getSortedAnni();
    final bool canDecrement = _selectedAnno > 2026;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade300, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: canDecrement
                ? () {
                    setState(() => _selectedAnno--);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: canDecrement ? Colors.teal : Colors.grey.shade400,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedAnno < 2026 ? 2026 : _selectedAnno,
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.teal, size: 18),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade900,
              ),
              items: sortedAnni.map((a) {
                return DropdownMenuItem<int>(
                  value: a,
                  child: Text('$a'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val >= 2026) {
                  setState(() => _selectedAnno = val);
                }
              },
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _selectedAnno++);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.chevron_right, size: 20, color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance, color: Colors.teal),
            const SizedBox(width: 8),
            const Text(
              'Bilancio',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 14),
            _buildYearSelector(),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.teal,
          labelColor: Colors.teal.shade900,
          unselectedLabelColor: Colors.grey.shade700,
          tabs: const [
            Tab(
              icon: Icon(Icons.point_of_sale),
              text: 'Prima Nota Cassa',
            ),
            Tab(
              icon: Icon(Icons.calendar_month),
              text: 'Bilancio Mensile',
            ),
            Tab(
              icon: Icon(Icons.assessment),
              text: 'Bilancio Annuale',
            ),
            Tab(
              icon: Icon(Icons.category),
              text: 'Categorie',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const PrimaNotaCassaView(),
          BilancioMensileView(
            selectedAnno: _selectedAnno,
            onAnniLoaded: _onAnniLoaded,
          ),
          BilancioAnnualeView(
            selectedAnno: _selectedAnno,
            onAnniLoaded: _onAnniLoaded,
          ),
          const CategorieBilancioView(),
        ],
      ),
    );
  }
}




class PrimaNotaCassaView extends StatefulWidget {
  const PrimaNotaCassaView({super.key});

  @override
  State<PrimaNotaCassaView> createState() => _PrimaNotaCassaViewState();
}

class _PrimaNotaCassaViewState extends State<PrimaNotaCassaView> {
  final ApiService _api = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  List<MovimentoPrimaNota> _movimenti = [];
  RiepilogoPrimaNota? _riepilogo;
  bool _loading = true;

  // Filtri
  String? _filterTipo; // null (tutti), 'entrata', 'uscita'
  String? _filterCategoria;
  int? _filterAnno = DateTime.now().year < 2026 ? 2026 : DateTime.now().year;
  int? _filterMese;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categoriePredefinite = [
    'Quote corsi',
    'Tesseramenti',
    'Milonghe / Serate',
    'Stage / Workshop',
    'Lezioni private',
    'Donazioni / Contributi',
    'Affitto sale',
    'Compensi maestri',
    'SIAE / SCF',
    'Attrezzatura',
    'Grafica / Web',
    'Spese bancarie',
    'Generale',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final String search = _searchController.text.trim();

    final movimenti = await _api.getMovimentiPrimaNota(
      tipo: _filterTipo,
      categoria: _filterCategoria,
      anno: _filterAnno,
      mese: _filterMese,
      search: search.isNotEmpty ? search : null,
    );

    final riepilogo = await _api.getRiepilogoPrimaNota(
      tipo: _filterTipo,
      categoria: _filterCategoria,
      anno: _filterAnno,
      mese: _filterMese,
      search: search.isNotEmpty ? search : null,
    );

    if (mounted) {
      setState(() {
        _movimenti = movimenti;
        _riepilogo = riepilogo;
        _loading = false;
      });
    }
  }

  void _resetFiltri() {
    setState(() {
      _filterTipo = null;
      _filterCategoria = null;
      _filterAnno = DateTime.now().year;
      _filterMese = null;
      _searchController.clear();
    });
    _loadData();
  }

  Future<void> _mostraDialogMovimento({MovimentoPrimaNota? movimento}) async {
    final bool isModifica = movimento != null;
    DateTime selectedDate = isModifica ? DateTime.tryParse(movimento.data) ?? DateTime.now() : DateTime.now();
    String tipo = isModifica ? movimento.tipo : 'entrata';
    final descrController = TextEditingController(text: isModifica ? movimento.descrizione : '');
    final importoController = TextEditingController(text: isModifica ? movimento.importo.toStringAsFixed(2) : '');
    final catController = TextEditingController(text: isModifica ? movimento.categoria : 'Quote corsi');
    final noteController = TextEditingController(text: isModifica ? movimento.note : '');

    // Unisci categorie dinamiche del riepilogo con le predefinite
    final Set<String> catSet = {..._categoriePredefinite};
    if (_riepilogo != null) {
      catSet.addAll(_riepilogo!.categorie);
    }
    List<String> getCategorieSuggerite(String t) {
      if (t == 'entrata') {
        if (_riepilogo != null && _riepilogo!.categorieEntrate.isNotEmpty) {
          return _riepilogo!.categorieEntrate;
        }
        return [
          'Quote corsi', 'Tesseramenti', 'Milonghe / Serate', 'Stage / Workshop',
          'Lezioni private', 'Quote associative', 'Donazioni / Contributi', 'Varie entrate'
        ];
      } else {
        if (_riepilogo != null && _riepilogo!.categorieUscite.isNotEmpty) {
          return _riepilogo!.categorieUscite;
        }
        return [
          'Affitto sale', 'Compensi maestri', 'SIAE / SCF', 'Attrezzatura / Service',
          'Grafica / Pubblicità / Web', 'Rinfreschi / Bar', 'Spese bancarie / Gestionali',
          'Assicurazioni', 'Varie uscite'
        ];
      }
    }

    if (!isModifica) {
      catController.text = getCategorieSuggerite(tipo).first;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final List<String> categorieSuggerite = getCategorieSuggerite(tipo);

          return AlertDialog(
          title: Row(
            children: [
              Icon(
                isModifica ? Icons.edit_note : Icons.add_circle,
                color: tipo == 'entrata' ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Text(isModifica ? 'Modifica Movimento' : 'Nuovo Movimento di Cassa'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selettore Tipo: Entrata / Uscita
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDlgState(() {
                              tipo = 'entrata';
                              final sug = getCategorieSuggerite('entrata');
                              if (catController.text.isEmpty || getCategorieSuggerite('uscita').contains(catController.text)) {
                                catController.text = sug.isNotEmpty ? sug.first : 'Quote corsi';
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tipo == 'entrata' ? Colors.green.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward, color: tipo == 'entrata' ? Colors.white : Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ENTRATA (+)',
                                    style: TextStyle(
                                      color: tipo == 'entrata' ? Colors.white : Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setDlgState(() {
                              tipo = 'uscita';
                              final sug = getCategorieSuggerite('uscita');
                              if (catController.text.isEmpty || getCategorieSuggerite('entrata').contains(catController.text)) {
                                catController.text = sug.isNotEmpty ? sug.first : 'Affitto sale';
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tipo == 'uscita' ? Colors.red.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),

                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward, color: tipo == 'uscita' ? Colors.white : Colors.red, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'USCITA (-)',
                                    style: TextStyle(
                                      color: tipo == 'uscita' ? Colors.white : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data movimento
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.teal),
                    title: Text(
                      'Data: ${_dateFormat.format(selectedDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: TextButton(
                      child: const Text('Cambia'),
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
                  const Divider(),

                  // Importo
                  TextField(
                    controller: importoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Importo (€) *',
                      prefixText: '€ ',
                      prefixStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tipo == 'entrata' ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                      hintText: '0.00',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descrizione
                  TextField(
                    controller: descrController,
                    decoration: const InputDecoration(
                      labelText: 'Descrizione Movimento *',
                      hintText: 'es. Affitto sala teatro, Quota corso Tango',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Categoria con Autocomplete
                  Autocomplete<String>(
                    key: ValueKey('auto_${tipo}_${catController.text}'),
                    initialValue: TextEditingValue(text: catController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return categorieSuggerite;
                      }
                      return categorieSuggerite.where((cat) =>
                          cat.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      catController.text = selection;
                    },
                    fieldViewBuilder: (context, fieldTextEditingController, focusNode, onFieldSubmitted) {
                      fieldTextEditingController.addListener(() {
                        catController.text = fieldTextEditingController.text;
                      });
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Categoria *',
                          hintText: 'Seleziona o digita una nuova categoria',
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            onSelected: (String val) {
                              fieldTextEditingController.text = val;
                              catController.text = val;
                            },
                            itemBuilder: (BuildContext context) {
                              return categorieSuggerite.map((String c) {
                                return PopupMenuItem<String>(value: c, child: Text(c));
                              }).toList();
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Note
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note aggiuntive (opzionale)',
                      hintText: 'es. Pagato con bonifico, scontrino n. 45',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tipo == 'entrata' ? Colors.green.shade700 : Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: Icon(isModifica ? Icons.save : Icons.check),
              label: Text(isModifica ? 'Salva Modifiche' : 'Registra Movimento'),
              onPressed: () async {
                final double? importoVal = double.tryParse(importoController.text.trim().replaceAll(',', '.'));
                if (importoVal == null || importoVal <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci un importo valido maggiore di zero.')),
                  );
                  return;
                }

                final descr = descrController.text.trim();
                if (descr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inserisci la descrizione del movimento.')),
                  );
                  return;
                }

                final cat = catController.text.trim();
                final payload = {
                  'data': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'descrizione': descr,
                  'categoria': cat.isNotEmpty ? cat : 'Generale',
                  'tipo': tipo,
                  'importo': importoVal,
                  'note': noteController.text.trim(),
                };

                bool successo = false;
                if (isModifica) {
                  final res = await _api.updateMovimentoPrimaNota(movimento.id, payload);
                  successo = res != null;
                } else {
                  final res = await _api.createMovimentoPrimaNota(payload);
                  successo = res != null;
                }

                if (ctx.mounted) Navigator.pop(ctx);

                if (mounted) {
                  if (successo) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isModifica ? 'Movimento aggiornato!' : 'Movimento registrato con successo!'),
                        backgroundColor: Colors.teal.shade800,
                      ),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Errore durante il salvataggio del movimento.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    ),
  );
}



  Future<void> _eliminaMovimento(MovimentoPrimaNota m) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Movimento'),
        content: Text(
          'Vuoi davvero eliminare il movimento del ${_dateFormat.format(DateTime.tryParse(m.data) ?? DateTime.now())}:\n\n"${m.descrizione}" (${_currencyFormat.format(m.importo)})?',
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

    if (conf == true) {
      final ok = await _api.deleteMovimentoPrimaNota(m.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movimento eliminato.')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore durante l\'eliminazione del movimento.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 750;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _mostraDialogMovimento(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Movimento'),
      ),
      body: Column(
        children: [
          // KPI / Header Riepilogo
          _buildKpiBanner(),

          // Barra Filtri
          _buildFilterBar(),

          // Vista Tabellare Movimenti
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _movimenti.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Nessun movimento di cassa registrato con i filtri correnti.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Aggiungi Primo Movimento'),
                              onPressed: () => _mostraDialogMovimento(),
                            ),
                          ],
                        ),
                      )
                    : isDesktop
                        ? _buildDesktopTable()
                        : _buildMobileCards(),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBanner() {
    final double entrate = _riepilogo?.totaleEntrate ?? 0.0;
    final double uscite = _riepilogo?.totaleUscite ?? 0.0;
    final double saldo = _riepilogo?.saldo ?? (entrate - uscite);
    final int conteggio = _riepilogo?.conteggio ?? _movimenti.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildKpiCard(
                title: 'TOTALE ENTRATE',
                value: _currencyFormat.format(entrate),
                icon: Icons.arrow_downward,
                color: Colors.green.shade700,
                bgColor: Colors.green.shade50,
                isNarrow: isNarrow,
              ),
              _buildKpiCard(
                title: 'TOTALE USCITE',
                value: _currencyFormat.format(uscite),
                icon: Icons.arrow_upward,
                color: Colors.red.shade700,
                bgColor: Colors.red.shade50,
                isNarrow: isNarrow,
              ),
              _buildKpiCard(
                title: 'SALDO CASSA',
                value: _currencyFormat.format(saldo),
                icon: Icons.account_balance_wallet,
                color: saldo >= 0 ? Colors.teal.shade800 : Colors.red.shade800,
                bgColor: saldo >= 0 ? Colors.teal.shade50 : Colors.red.shade50,
                isNarrow: isNarrow,
              ),
              _buildKpiCard(
                title: 'MOVIMENTI',
                value: '$conteggio',
                icon: Icons.format_list_numbered,
                color: Colors.indigo.shade700,
                bgColor: Colors.indigo.shade50,
                isNarrow: isNarrow,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isNarrow,
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: isNarrow ? 140 : 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 18,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final Set<int> anniDisponibili = {2026};
    if (DateTime.now().year >= 2026) {
      anniDisponibili.add(DateTime.now().year);
    }
    if (_riepilogo != null) {
      anniDisponibili.addAll(_riepilogo!.anni.where((y) => y >= 2026));
    }
    final List<int> sortedAnni = anniDisponibili.toList()..sort((a, b) => b.compareTo(a));

    final Set<String> catSet = {..._categoriePredefinite};
    if (_riepilogo != null) {
      catSet.addAll(_riepilogo!.categorie);
    }
    final List<String> sortedCat = catSet.toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.grey.shade100,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Filtro Anno
          DropdownButton<int?>(
            value: _filterAnno,
            hint: const Text('Tutti gli anni'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tutti gli anni')),
              ...sortedAnni.map((a) => DropdownMenuItem(value: a, child: Text('Anno $a'))),
            ],
            onChanged: (val) {
              setState(() => _filterAnno = val);
              _loadData();
            },
          ),

          // Filtro Mese
          DropdownButton<int?>(
            value: _filterMese,
            hint: const Text('Tutti i mesi'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Tutti i mesi')),
              DropdownMenuItem(value: 1, child: Text('Gennaio')),
              DropdownMenuItem(value: 2, child: Text('Febbraio')),
              DropdownMenuItem(value: 3, child: Text('Marzo')),
              DropdownMenuItem(value: 4, child: Text('Aprile')),
              DropdownMenuItem(value: 5, child: Text('Maggio')),
              DropdownMenuItem(value: 6, child: Text('Giugno')),
              DropdownMenuItem(value: 7, child: Text('Luglio')),
              DropdownMenuItem(value: 8, child: Text('Agosto')),
              DropdownMenuItem(value: 9, child: Text('Settembre')),
              DropdownMenuItem(value: 10, child: Text('Ottobre')),
              DropdownMenuItem(value: 11, child: Text('Novembre')),
              DropdownMenuItem(value: 12, child: Text('Dicembre')),
            ],
            onChanged: (val) {
              setState(() => _filterMese = val);
              _loadData();
            },
          ),

          // Filtro Tipo
          DropdownButton<String?>(
            value: _filterTipo,
            hint: const Text('Tutti i tipi'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Tutti i tipi (Entrate e Uscite)')),
              DropdownMenuItem(value: 'entrata', child: Text('Solo Entrate (+)')),
              DropdownMenuItem(value: 'uscita', child: Text('Solo Uscite (-)')),
            ],
            onChanged: (val) {
              setState(() => _filterTipo = val);
              _loadData();
            },
          ),

          // Filtro Categoria
          DropdownButton<String?>(
            value: _filterCategoria,
            hint: const Text('Tutte le categorie'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tutte le categorie')),
              ...sortedCat.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (val) {
              setState(() => _filterCategoria = val);
              _loadData();
            },
          ),

          // Ricerca
          SizedBox(
            width: 180,
            height: 36,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),

          // Tasto Reset
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.teal),
            tooltip: 'Ripristina filtri',
            onPressed: _resetFiltri,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.teal.shade50),
            columns: const [
              DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Descrizione', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Entrata (€)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Uscita (€)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Note', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _movimenti.map((m) {
              final dateStr = _dateFormat.format(DateTime.tryParse(m.data) ?? DateTime.now());
              return DataRow(
                cells: [
                  DataCell(Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: m.isEntrata ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: m.isEntrata ? Colors.green.shade300 : Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            m.isEntrata ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 13,
                            color: m.isEntrata ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m.tipoDisplay.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: m.isEntrata ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Text(m.descrizione, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Text(
                        m.categoria,
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      m.isEntrata ? _currencyFormat.format(m.importo) : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: m.isEntrata ? Colors.green.shade800 : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      m.isUscita ? _currencyFormat.format(m.importo) : '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: m.isUscita ? Colors.red.shade800 : Colors.grey,
                      ),
                    ),
                  ),

                  DataCell(
                    Text(
                      m.note.isNotEmpty ? m.note : '-',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          tooltip: 'Modifica',
                          onPressed: () => _mostraDialogMovimento(movimento: m),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          tooltip: 'Elimina',
                          onPressed: () => _eliminaMovimento(m),
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
    );
  }

  Widget _buildMobileCards() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _movimenti.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final m = _movimenti[i];
        final dateStr = _dateFormat.format(DateTime.tryParse(m.data) ?? DateTime.now());

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: m.isEntrata ? Colors.green.shade200 : Colors.red.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: m.isEntrata ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: m.isEntrata ? Colors.green.shade300 : Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            m.isEntrata ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 13,
                            color: m.isEntrata ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m.tipoDisplay.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: m.isEntrata ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${m.isEntrata ? "+" : "-"} ${_currencyFormat.format(m.importo)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: m.isEntrata ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(m.descrizione, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        m.categoria,
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Data: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                if (m.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Note: ${m.note}', style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Modifica'),
                      onPressed: () => _mostraDialogMovimento(movimento: m),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Elimina', style: TextStyle(color: Colors.red)),
                      onPressed: () => _eliminaMovimento(m),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOTTOSEZIONE: BILANCIO MENSILE
// ─────────────────────────────────────────────────────────────────────────────

class BilancioMensileView extends StatefulWidget {
  final int selectedAnno;
  final ValueChanged<List<int>>? onAnniLoaded;

  const BilancioMensileView({
    super.key,
    required this.selectedAnno,
    this.onAnniLoaded,
  });

  @override
  State<BilancioMensileView> createState() => _BilancioMensileViewState();
}

class _BilancioMensileViewState extends State<BilancioMensileView> {
  final ApiService _api = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  BilancioMensileAnno? _bilancio;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant BilancioMensileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAnno != widget.selectedAnno) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await _api.getBilancioMensile(anno: widget.selectedAnno);
    if (mounted) {
      setState(() {
        _bilancio = data;
        _loading = false;
      });
      if (data != null && data.anniDisponibili.isNotEmpty) {
        widget.onAnniLoaded?.call(data.anniDisponibili);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Barra info sottosezione e refresh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.teal.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Prospetto Mensile - Esercizio ${widget.selectedAnno}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.teal.shade900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.teal),
                  tooltip: 'Ricarica dati',
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // Banner KPI
          if (_bilancio != null) _buildKpiBanner(_bilancio!),

          // Tabella / Card Mensile Scrollabile (Responsive Desktop / Mobile)
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _bilancio == null
                    ? const Center(child: Text('Impossibile caricare il bilancio mensile.'))
                    : LayoutBuilder(
                        builder: (ctx, constraints) {
                          final bool isMobile = constraints.maxWidth < 650;
                          if (isMobile) {
                            return _buildMobileMensileCards(_bilancio!);
                          }
                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 40),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1000),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: _buildTable(_bilancio!),
                                    ),
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

  Widget _buildKpiBanner(BilancioMensileAnno b) {
    return Container(
      width: double.infinity,
      color: Colors.teal.shade50.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildKpiCard(
            label: 'Entrate Annuali (${widget.selectedAnno})',
            value: _currencyFormat.format(b.totaleEntrate),
            icon: Icons.arrow_downward,
            color: Colors.green.shade700,
            bgColor: Colors.green.shade50,
          ),
          _buildKpiCard(
            label: 'Uscite Annuali (${widget.selectedAnno})',
            value: _currencyFormat.format(b.totaleUscite),
            icon: Icons.arrow_upward,
            color: Colors.red.shade700,
            bgColor: Colors.red.shade50,
          ),
          _buildKpiCard(
            label: 'Saldo Netto Annuale',
            value: '${b.saldoTotale >= 0 ? "+" : ""}${_currencyFormat.format(b.saldoTotale)}',
            icon: Icons.account_balance_wallet,
            color: b.isAvanzo ? Colors.green.shade700 : (b.isPerdita ? Colors.red.shade700 : Colors.teal.shade700),
            bgColor: b.isAvanzo ? Colors.green.shade50 : (b.isPerdita ? Colors.red.shade50 : Colors.teal.shade50),
          ),
          _buildKpiCard(
            label: 'Stato Annuale',
            value: b.statoTotaleDisplay.toUpperCase(),
            icon: b.isAvanzo ? Icons.trending_up : (b.isPerdita ? Icons.trending_down : Icons.trending_flat),
            color: b.isAvanzo ? Colors.green.shade700 : (b.isPerdita ? Colors.red.shade700 : Colors.blueGrey.shade700),
            bgColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      elevation: 1,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMensileCards(BilancioMensileAnno b) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: b.mesi.length + 1,
      itemBuilder: (ctx, i) {
        if (i == b.mesi.length) {
          // Card finale dei Totali
          return Card(
            elevation: 3,
            color: Colors.teal.shade50,
            margin: const EdgeInsets.only(top: 8, bottom: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.shade300, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.functions, color: Colors.teal.shade900, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'TOTALI (${widget.selectedAnno})',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.teal.shade900),
                          ),
                        ],
                      ),
                      _buildStatoBadge(b.statoTotale, b.statoTotaleDisplay, true, isTotale: true),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entrate', style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(_currencyFormat.format(b.totaleEntrate), style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uscite', style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(_currencyFormat.format(b.totaleUscite), style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Saldo Netto', style: TextStyle(color: Colors.teal.shade900, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(
                            '${b.saldoTotale >= 0 ? "+" : ""}${_currencyFormat.format(b.saldoTotale)}',
                            style: TextStyle(
                              color: b.isAvanzo ? Colors.green.shade900 : (b.isPerdita ? Colors.red.shade900 : Colors.teal.shade900),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final m = b.mesi[i];
        final bool hasActivity = m.entrate > 0 || m.uscite > 0;

        return Card(
          elevation: hasActivity ? 1.5 : 0.5,
          color: hasActivity ? Colors.white : Colors.grey.shade50,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: hasActivity
                  ? (m.isAvanzo ? Colors.green.shade200 : (m.isPerdita ? Colors.red.shade200 : Colors.grey.shade300))
                  : Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: hasActivity ? Colors.teal.shade50 : Colors.grey.shade100,
                  child: Text(
                    m.nomeMese.length >= 3 ? m.nomeMese.substring(0, 3) : m.nomeMese,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasActivity ? Colors.teal.shade800 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m.nomeMese,
                            style: TextStyle(
                              fontWeight: hasActivity ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                              color: hasActivity ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                          _buildStatoBadge(m.stato, m.statoDisplay, hasActivity),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Entrate: ${m.entrate > 0 ? _currencyFormat.format(m.entrate) : "-"}',
                            style: TextStyle(fontSize: 12, color: m.entrate > 0 ? Colors.green.shade800 : Colors.grey),
                          ),
                          Text(
                            'Uscite: ${m.uscite > 0 ? _currencyFormat.format(m.uscite) : "-"}',
                            style: TextStyle(fontSize: 12, color: m.uscite > 0 ? Colors.red.shade800 : Colors.grey),
                          ),
                          Text(
                            hasActivity ? '${m.saldo >= 0 ? "+" : ""}${_currencyFormat.format(m.saldo)}' : '0,00 €',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: m.isAvanzo
                                  ? Colors.green.shade800
                                  : (m.isPerdita ? Colors.red.shade800 : Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable(BilancioMensileAnno b) {
    return DataTable(
      headingRowColor: MaterialStateProperty.all(Colors.teal.shade50),
      columns: const [
        DataColumn(label: Text('Mese', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Entrate (€)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Uscite (€)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Saldo (€)', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('Stato', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: [
        // Righe dei 12 mesi
        ...b.mesi.map((m) {
          final bool hasActivity = m.entrate > 0 || m.uscite > 0;
          return DataRow(
            color: MaterialStateProperty.resolveWith<Color?>((states) {
              if (m.isAvanzo && m.entrate > 0) return Colors.green.shade50.withOpacity(0.2);
              if (m.isPerdita) return Colors.red.shade50.withOpacity(0.2);
              return null;
            }),
            cells: [
              // Mese
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: hasActivity ? Colors.teal : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      m.nomeMese,
                      style: TextStyle(
                        fontWeight: hasActivity ? FontWeight.bold : FontWeight.normal,
                        color: hasActivity ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Entrate (senza segno +)
              DataCell(
                Text(
                  m.entrate > 0 ? _currencyFormat.format(m.entrate) : '-',
                  style: TextStyle(
                    fontWeight: m.entrate > 0 ? FontWeight.bold : FontWeight.normal,
                    color: m.entrate > 0 ? Colors.green.shade800 : Colors.grey,
                  ),
                ),
              ),

              // Uscite (senza segno -)
              DataCell(
                Text(
                  m.uscite > 0 ? _currencyFormat.format(m.uscite) : '-',
                  style: TextStyle(
                    fontWeight: m.uscite > 0 ? FontWeight.bold : FontWeight.normal,
                    color: m.uscite > 0 ? Colors.red.shade800 : Colors.grey,
                  ),
                ),
              ),

              // Saldo
              DataCell(
                Text(
                  hasActivity ? '${m.saldo >= 0 ? "+" : ""}${_currencyFormat.format(m.saldo)}' : '0,00 €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.isAvanzo
                        ? Colors.green.shade800
                        : (m.isPerdita ? Colors.red.shade800 : Colors.grey.shade700),
                  ),
                ),
              ),

              // Stato (Pareggio, Perdita, Avanzo)
              DataCell(
                _buildStatoBadge(m.stato, m.statoDisplay, hasActivity),
              ),
            ],
          );
        }),

        // Riga dei TOTALI (sotto)
        DataRow(
          color: MaterialStateProperty.all(Colors.teal.shade100.withOpacity(0.6)),
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.functions, color: Colors.teal.shade900, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'TOTALI (${widget.selectedAnno})',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ),
            ),
            DataCell(
              Text(
                _currencyFormat.format(b.totaleEntrate),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.green.shade900,
                ),
              ),
            ),
            DataCell(
              Text(
                _currencyFormat.format(b.totaleUscite),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.red.shade900,
                ),
              ),
            ),
            DataCell(
              Text(
                '${b.saldoTotale >= 0 ? "+" : ""}${_currencyFormat.format(b.saldoTotale)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: b.isAvanzo
                      ? Colors.green.shade900
                      : (b.isPerdita ? Colors.red.shade900 : Colors.teal.shade900),
                ),
              ),
            ),
            DataCell(
              _buildStatoBadge(b.statoTotale, b.statoTotaleDisplay, true, isTotale: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatoBadge(String stato, String display, bool hasActivity, {bool isTotale = false}) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    if (stato == 'avanzo') {
      bg = Colors.green.shade50;
      border = Colors.green.shade300;
      text = Colors.green.shade900;
      icon = Icons.arrow_upward;
    } else if (stato == 'perdita') {
      bg = Colors.red.shade50;
      border = Colors.red.shade300;
      text = Colors.red.shade900;
      icon = Icons.arrow_downward;
    } else {
      bg = Colors.grey.shade100;
      border = Colors.grey.shade300;
      text = Colors.grey.shade700;
      icon = Icons.remove;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTotale ? 10 : 8, vertical: isTotale ? 5 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: isTotale ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            display.toUpperCase(),
            style: TextStyle(
              fontSize: isTotale ? 12 : 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOTTOSEZIONE: BILANCIO ANNUALE (Prospetto Entrate e Uscite per Categoria)
// ─────────────────────────────────────────────────────────────────────────────

class BilancioAnnualeView extends StatefulWidget {
  final int selectedAnno;
  final ValueChanged<List<int>>? onAnniLoaded;

  const BilancioAnnualeView({
    super.key,
    required this.selectedAnno,
    this.onAnniLoaded,
  });

  @override
  State<BilancioAnnualeView> createState() => _BilancioAnnualeViewState();
}

class _BilancioAnnualeViewState extends State<BilancioAnnualeView> {
  final ApiService _api = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  BilancioAnnualeData? _data;
  bool _loading = true;
  String _vistaSelezionata = 'tutte'; // 'tutte', 'entrate', 'uscite'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant BilancioAnnualeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAnno != widget.selectedAnno) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final res = await _api.getBilancioAnnuale(anno: widget.selectedAnno);
    if (mounted) {
      setState(() {
        _data = res;
        _loading = false;
      });
      if (res != null && res.anniDisponibili.isNotEmpty) {
        widget.onAnniLoaded?.call(res.anniDisponibili);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Toolbar Filtro Vista e Refresh (Selettore Anno spostato nell'intestazione principale)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assessment, color: Colors.teal.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Prospetto Annuale ${widget.selectedAnno}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),

                // Filtro visualizzazione tabelle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      label: const Text('Tutte e due'),
                      selected: _vistaSelezionata == 'tutte',
                      selectedColor: Colors.teal.shade100,
                      onSelected: (val) => setState(() => _vistaSelezionata = 'tutte'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.arrow_downward, size: 14, color: Colors.green),
                      label: const Text('Solo Entrate'),
                      selected: _vistaSelezionata == 'entrate',
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) => setState(() => _vistaSelezionata = 'entrate'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.arrow_upward, size: 14, color: Colors.red),
                      label: const Text('Solo Uscite'),
                      selected: _vistaSelezionata == 'uscite',
                      selectedColor: Colors.red.shade100,
                      onSelected: (val) => setState(() => _vistaSelezionata = 'uscite'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.teal),
                      tooltip: 'Ricarica dati',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Banner KPI
          if (_data != null) _buildKpiBanner(_data!),

          // Contenuto Tabelle
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data == null
                    ? const Center(child: Text('Impossibile caricare il bilancio annuale.'))
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Tabella Entrate
                              if (_vistaSelezionata == 'tutte' || _vistaSelezionata == 'entrate') ...[
                                _buildSectionCard(
                                  titolo: 'TABELLA ENTRATE PER CATEGORIA (${widget.selectedAnno})',
                                  icon: Icons.arrow_downward,
                                  color: Colors.green,
                                  totaleComplessivo: _data!.entrate.totaleComplessivo,
                                  child: _buildProspettoTable(
                                    tabella: _data!.entrate,
                                    color: Colors.green,
                                    labelTotale: 'TOTALE ENTRATE',
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Tabella Uscite
                              if (_vistaSelezionata == 'tutte' || _vistaSelezionata == 'uscite') ...[
                                _buildSectionCard(
                                  titolo: 'TABELLA USCITE PER CATEGORIA (${widget.selectedAnno})',
                                  icon: Icons.arrow_upward,
                                  color: Colors.red,
                                  totaleComplessivo: _data!.uscite.totaleComplessivo,
                                  child: _buildProspettoTable(
                                    tabella: _data!.uscite,
                                    color: Colors.red,
                                    labelTotale: 'TOTALE USCITE',
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Tabella Riepilogativa del Saldo Mensile (se entrambe visibili)
                              if (_vistaSelezionata == 'tutte') ...[
                                _buildSaldoTableCard(_data!),
                              ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBanner(BilancioAnnualeData d) {
    final saldo = d.saldoComplessivo;
    final bool isAvanzo = saldo > 0.001;
    final bool isPerdita = saldo < -0.001;

    return Container(
      width: double.infinity,
      color: Colors.teal.shade50.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildKpiCard(
            label: 'Totale Entrate Annuali',
            value: _currencyFormat.format(d.entrate.totaleComplessivo),
            icon: Icons.arrow_downward,
            color: Colors.green.shade700,
            bgColor: Colors.green.shade50,
          ),
          _buildKpiCard(
            label: 'Totale Uscite Annuali',
            value: _currencyFormat.format(d.uscite.totaleComplessivo),
            icon: Icons.arrow_upward,
            color: Colors.red.shade700,
            bgColor: Colors.red.shade50,
          ),
          _buildKpiCard(
            label: 'Saldo Netto Complessivo',
            value: '${saldo >= 0 ? "+" : ""}${_currencyFormat.format(saldo)}',
            icon: Icons.account_balance_wallet,
            color: isAvanzo ? Colors.green.shade700 : (isPerdita ? Colors.red.shade700 : Colors.teal.shade700),
            bgColor: isAvanzo ? Colors.green.shade50 : (isPerdita ? Colors.red.shade50 : Colors.teal.shade50),
          ),
          _buildKpiCard(
            label: 'Stato Complessivo',
            value: isAvanzo ? 'AVANZO' : (isPerdita ? 'PERDITA' : 'PAREGGIO'),
            icon: isAvanzo ? Icons.trending_up : (isPerdita ? Icons.trending_down : Icons.trending_flat),
            color: isAvanzo ? Colors.green.shade700 : (isPerdita ? Colors.red.shade700 : Colors.blueGrey.shade700),
            bgColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      elevation: 1,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String titolo,
    required IconData icon,
    required MaterialColor color,
    required double totaleComplessivo,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header della card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.shade700,
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      titolo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color.shade900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.shade300),
                  ),
                  child: Text(
                    'Totale: ${_currencyFormat.format(totaleComplessivo)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabella con scroll orizzontale
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProspettoTable({
    required TabellaBilancioAnnuale tabella,
    required MaterialColor color,
    required String labelTotale,
  }) {
    final mesiLabels = _data?.mesiLabels ?? [
      'GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU', 'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC'
    ];

    return DataTable(
      headingRowColor: MaterialStateProperty.all(color.shade50.withOpacity(0.8)),
      columnSpacing: 18,
      horizontalMargin: 12,
      columns: [
        const DataColumn(
          label: Text('VOCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        ...mesiLabels.map((m) => DataColumn(
              numeric: true,
              label: Text(m, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )),
        const DataColumn(
          numeric: true,
          label: Text('TOTALE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
      rows: [
        // Righe per ogni categoria
        ...tabella.righe.map((r) {
          final bool hasActivity = r.totale > 0;
          return DataRow(
            color: MaterialStateProperty.resolveWith<Color?>((states) {
              if (hasActivity) return color.shade50.withOpacity(0.12);
              return null;
            }),
            cells: [
              // VOCE (Categoria)
              DataCell(
                Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    r.categoria,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: hasActivity ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.5,
                      color: hasActivity ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),

              // 12 Mesi
              ...List.generate(12, (idx) {
                final double val = idx < r.mesi.length ? r.mesi[idx] : 0.0;
                return DataCell(
                  Text(
                    val > 0 ? _currencyFormat.format(val) : '-',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: val > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: val > 0 ? color.shade800 : Colors.grey.shade400,
                    ),
                  ),
                );
              }),

              // TOTALE riga
              DataCell(
                Text(
                  r.totale > 0 ? _currencyFormat.format(r.totale) : '-',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: r.totale > 0 ? color.shade900 : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          );
        }),

        // Riga di RIEPILOGO TOTALE (sotto)
        DataRow(
          color: MaterialStateProperty.all(color.shade100.withOpacity(0.7)),
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.functions, color: color.shade900, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    labelTotale,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: color.shade900,
                    ),
                  ),
                ],
              ),
            ),

            // Totali per mese
            ...List.generate(12, (idx) {
              final double val = idx < tabella.totaliMesi.length ? tabella.totaliMesi[idx] : 0.0;
              return DataCell(
                Text(
                  val > 0 ? _currencyFormat.format(val) : '-',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: val > 0 ? color.shade900 : Colors.grey.shade600,
                  ),
                ),
              );
            }),

            // Totale Complessivo
            DataCell(
              Text(
                _currencyFormat.format(tabella.totaleComplessivo),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color.shade900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaldoTableCard(BilancioAnnualeData d) {
    final mesiLabels = d.mesiLabels;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.teal.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.teal.shade700,
                      child: const Icon(Icons.compare_arrows, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'SALDO NETTO MENSILE (ENTRATE - USCITE)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Saldo Annuale: ${d.saldoComplessivo >= 0 ? "+" : ""}${_currencyFormat.format(d.saldoComplessivo)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: d.saldoComplessivo >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.teal.shade50.withOpacity(0.5)),
                columnSpacing: 18,
                horizontalMargin: 12,
                columns: [
                  const DataColumn(
                    label: Text('RIASSUNTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  ...mesiLabels.map((m) => DataColumn(
                        numeric: true,
                        label: Text(m, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )),
                  const DataColumn(
                    numeric: true,
                    label: Text('TOTALE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
                rows: [
                  DataRow(
                    color: MaterialStateProperty.all(Colors.teal.shade50.withOpacity(0.4)),
                    cells: [
                      const DataCell(
                        Text('SALDO NETTO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                      ...List.generate(12, (idx) {
                        final double val = idx < d.saldoMesi.length ? d.saldoMesi[idx] : 0.0;
                        final bool pos = val > 0.001;
                        final bool neg = val < -0.001;
                        return DataCell(
                          Text(
                            val != 0.0 ? '${pos ? "+" : ""}${_currencyFormat.format(val)}' : '0,00 €',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: pos ? Colors.green.shade800 : (neg ? Colors.red.shade800 : Colors.grey.shade700),
                            ),
                          ),
                        );
                      }),
                      DataCell(
                        Text(
                          '${d.saldoComplessivo >= 0 ? "+" : ""}${_currencyFormat.format(d.saldoComplessivo)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: d.saldoComplessivo >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOTTOSEZIONE: CATEGORIE BILANCIO (Entrate / Uscite)
// ─────────────────────────────────────────────────────────────────────────────



class CategorieBilancioView extends StatefulWidget {
  const CategorieBilancioView({super.key});

  @override
  State<CategorieBilancioView> createState() => _CategorieBilancioViewState();
}

class _CategorieBilancioViewState extends State<CategorieBilancioView> {
  final ApiService _api = ApiService();
  List<CategoriaBilancio> _categorie = [];
  bool _loading = true;

  // Filtro tipo: null (tutte), 'entrata', 'uscita'
  String? _filtroTipo;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _loadData() async {
    setState(() => _loading = true);
    final search = _searchController.text.trim();
    final list = await _api.getCategorieBilancio(
      tipo: _filtroTipo,
      search: search.isNotEmpty ? search : null,
    );
    if (mounted) {
      setState(() {
        _categorie = list;
        _loading = false;
      });
    }
  }

  List<CategoriaBilancio> get _categorieEntrate =>
      _categorie.where((c) => c.isEntrata).toList();

  List<CategoriaBilancio> get _categorieUscite =>
      _categorie.where((c) => c.isUscita).toList();

  Future<void> _mostraDialogCategoria({
    CategoriaBilancio? categoria,
    String? tipoPredefinito,
  }) async {
    final bool isModifica = categoria != null;
    String tipo = isModifica
        ? categoria.tipo
        : (tipoPredefinito ?? (_filtroTipo ?? 'entrata'));
    final nomeController = TextEditingController(text: isModifica ? categoria.nome : '');
    final descrController = TextEditingController(text: isModifica ? categoria.descrizione : '');
    final ordineController = TextEditingController(text: isModifica ? categoria.ordine.toString() : '0');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isModifica ? Icons.edit : Icons.add_circle,
                color: tipo == 'entrata' ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Text(isModifica ? 'Modifica Categoria' : 'Nuova Categoria'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selettore Tipo (Entrata o Uscita)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: isModifica ? null : () => setDlgState(() => tipo = 'entrata'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tipo == 'entrata' ? Colors.green.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward, color: tipo == 'entrata' ? Colors.white : Colors.green, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ENTRATA',
                                    style: TextStyle(
                                      color: tipo == 'entrata' ? Colors.white : Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: isModifica ? null : () => setDlgState(() => tipo = 'uscita'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tipo == 'uscita' ? Colors.red.shade600 : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_upward, color: tipo == 'uscita' ? Colors.white : Colors.red, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'USCITA',
                                    style: TextStyle(
                                      color: tipo == 'uscita' ? Colors.white : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nome Categoria
                  TextField(
                    controller: nomeController,
                    decoration: InputDecoration(
                      labelText: 'Nome Categoria *',
                      hintText: tipo == 'entrata' ? 'es. Stage & Seminari' : 'es. Noleggio impianto audio',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descrizione
                  TextField(
                    controller: descrController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descrizione / Note (opzionale)',
                      hintText: 'Breve descrizione o scopo di questa voce di bilancio',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ordine
                  TextField(
                    controller: ordineController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Posizione Ordinamento',
                      hintText: '0, 1, 2...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tipo == 'entrata' ? Colors.green.shade700 : Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              icon: Icon(isModifica ? Icons.save : Icons.check),
              label: Text(isModifica ? 'Salva Modifiche' : 'Crea Categoria'),
              onPressed: () async {
                final nome = nomeController.text.trim();
                if (nome.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Il nome della categoria è obbligatorio.'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                final ordine = int.tryParse(ordineController.text.trim()) ?? 0;
                final payload = {
                  'nome': nome,
                  'tipo': tipo,
                  'descrizione': descrController.text.trim(),
                  'ordine': ordine,
                };

                bool successo = false;
                if (isModifica) {
                  final res = await _api.updateCategoriaBilancio(categoria.id, payload);
                  successo = res != null;
                } else {
                  final res = await _api.createCategoriaBilancio(payload);
                  successo = res != null;
                }

                if (ctx.mounted) Navigator.pop(ctx);

                if (mounted) {
                  if (successo) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isModifica ? 'Categoria aggiornata!' : 'Categoria creata con successo!'),
                        backgroundColor: Colors.teal.shade800,
                      ),
                    );
                    _loadData();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Errore: impossibile salvare la categoria (potrebbe già esistere per questo tipo).'),
                        backgroundColor: Colors.red,
                      ),
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

  Future<void> _eliminaCategoria(CategoriaBilancio c) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Elimina Categoria'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sei sicuro di voler eliminare la categoria "${c.nome}"?'),
            if (c.movimentiCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ci sono ${c.movimentiCount} movimenti registrati in Prima Nota con questa categoria.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Annulla'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Elimina'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (conf == true) {
      final ok = await _api.deleteCategoriaBilancio(c.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categoria eliminata.'), backgroundColor: Colors.teal),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore durante l\'eliminazione della categoria.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _ripristinaPredefinite() async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina Categorie Predefinite'),
        content: const Text(
          'Questa operazione verificherà ed eventualmente integrerà tutte le categorie standard (Quote corsi, Affitto sale, Compensi maestri, SIAE, ecc.) senza cancellare quelle già presenti.\n\nVuoi procedere?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );

    if (conf == true) {
      final ok = await _api.resetDefaultCategorieBilancio();
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categorie predefinite verificate e integrate!'), backgroundColor: Colors.teal),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore durante il ripristino delle categorie.'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Banner KPI Riepilogo Categorie
          _buildKpiBanner(),

          // Barra Ricerca e Filtri
          _buildFilterBar(),

          // Contenuto principale
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _categorie.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Nessuna categoria trovata.',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Crea Nuova Categoria'),
                              onPressed: () => _mostraDialogCategoria(),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 40),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;

                              if (_filtroTipo == 'entrata') {
                                return _buildSingleListPanel(
                                  titolo: 'Categorie di Entrata',
                                  tipo: 'entrata',
                                  categorie: _categorieEntrate,
                                  color: Colors.green,
                                  icon: Icons.arrow_downward,
                                );
                              } else if (_filtroTipo == 'uscita') {
                                return _buildSingleListPanel(
                                  titolo: 'Categorie di Uscita',
                                  tipo: 'uscita',
                                  categorie: _categorieUscite,
                                  color: Colors.red,
                                  icon: Icons.arrow_upward,
                                );
                              }

                              // Vista divisa (Tutte le categorie)
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildCategoryGroupCard(
                                        titolo: 'Categorie di Entrata',
                                        tipo: 'entrata',
                                        categorie: _categorieEntrate,
                                        color: Colors.green,
                                        icon: Icons.arrow_downward,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildCategoryGroupCard(
                                        titolo: 'Categorie di Uscita',
                                        tipo: 'uscita',
                                        categorie: _categorieUscite,
                                        color: Colors.red,
                                        icon: Icons.arrow_upward,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // Layout verticale a schede su schermi stretti
                                return Column(
                                  children: [
                                    _buildCategoryGroupCard(
                                      titolo: 'Categorie di Entrata',
                                      tipo: 'entrata',
                                      categorie: _categorieEntrate,
                                      color: Colors.green,
                                      icon: Icons.arrow_downward,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildCategoryGroupCard(
                                      titolo: 'Categorie di Uscita',
                                      tipo: 'uscita',
                                      categorie: _categorieUscite,
                                      color: Colors.red,
                                      icon: Icons.arrow_upward,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),
          ),

        ],
      ),
    );
  }

  Widget _buildKpiBanner() {
    final int totEntrate = _categorieEntrate.length;
    final int totUscite = _categorieUscite.length;
    final int totale = _categorie.length;

    return Container(
      width: double.infinity,
      color: Colors.teal.shade50.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildKpiCard(
            label: 'Totale Categorie',
            value: '$totale',
            icon: Icons.folder_special,
            color: Colors.teal.shade700,
            bgColor: Colors.white,
          ),
          _buildKpiCard(
            label: 'Categorie Entrata',
            value: '$totEntrate',
            icon: Icons.arrow_downward,
            color: Colors.green.shade700,
            bgColor: Colors.green.shade50,
          ),
          _buildKpiCard(
            label: 'Categorie Uscita',
            value: '$totUscite',
            icon: Icons.arrow_upward,
            color: Colors.red.shade700,
            bgColor: Colors.red.shade50,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      elevation: 1,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Chip Filtro Tipo
          ChoiceChip(
            label: Text('Tutte (${_categorie.length})'),
            selected: _filtroTipo == null,
            selectedColor: Colors.teal.shade100,
            onSelected: (val) {
              setState(() => _filtroTipo = null);
              _loadData();
            },
          ),
          ChoiceChip(
            avatar: const Icon(Icons.arrow_downward, size: 16, color: Colors.green),
            label: Text('Entrate (${_categorieEntrate.length})'),
            selected: _filtroTipo == 'entrata',
            selectedColor: Colors.green.shade100,
            onSelected: (val) {
              setState(() => _filtroTipo = val ? 'entrata' : null);
              _loadData();
            },
          ),
          ChoiceChip(
            avatar: const Icon(Icons.arrow_upward, size: 16, color: Colors.red),
            label: Text('Uscite (${_categorieUscite.length})'),
            selected: _filtroTipo == 'uscita',
            selectedColor: Colors.red.shade100,
            onSelected: (val) {
              setState(() => _filtroTipo = val ? 'uscita' : null);
              _loadData();
            },
          ),

          // Campo Ricerca
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca categoria...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),

          // Pulsante Nuova Categoria
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuova Categoria'),
            onPressed: () => _mostraDialogCategoria(),
          ),

          // Menu Altre Azioni
          PopupMenuButton<String>(
            tooltip: 'Altre opzioni',
            icon: const Icon(Icons.more_vert, color: Colors.teal),
            onSelected: (val) {
              if (val == 'reset') {
                _ripristinaPredefinite();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Ripristina predefinite'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGroupCard({
    required String titolo,
    required String tipo,
    required List<CategoriaBilancio> categorie,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del gruppo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: color.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.shade600,
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      titolo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color.shade900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${categorie.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.shade900),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: color.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Aggiungi'),
                  onPressed: () => _mostraDialogCategoria(tipoPredefinito: tipo),
                ),
              ],
            ),
          ),

          // Lista delle categorie del gruppo
          if (categorie.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Nessuna categoria di $tipo presente.',
                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categorie.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (ctx, idx) {
                final c = categorie[idx];
                return _buildCategoryTile(c, color);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSingleListPanel({
    required String titolo,
    required String tipo,
    required List<CategoriaBilancio> categorie,
    required MaterialColor color,
    required IconData icon,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: _buildCategoryGroupCard(
          titolo: titolo,
          tipo: tipo,
          categorie: categorie,
          color: color,
          icon: icon,
        ),
      ),
    );
  }


  Widget _buildCategoryTile(CategoriaBilancio c, MaterialColor color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.shade50,
        child: Icon(
          c.isEntrata ? Icons.arrow_downward : Icons.arrow_upward,
          size: 16,
          color: color.shade700,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              c.nome,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (c.movimentiCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Text(
                '${c.movimentiCount} ${c.movimentiCount == 1 ? "movimento" : "movimenti"}',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
      subtitle: c.descrizione.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c.descrizione,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
            tooltip: 'Modifica',
            onPressed: () => _mostraDialogCategoria(categoria: c),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            tooltip: 'Elimina',
            onPressed: () => _eliminaCategoria(c),
          ),
        ],
      ),
    );
  }
}


