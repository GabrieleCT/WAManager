import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pdf_report_service.dart';

class PresenzeScreen extends StatefulWidget {
  final String? initialLezioneId;
  const PresenzeScreen({super.key, this.initialLezioneId});

  @override
  State<PresenzeScreen> createState() => _PresenzeScreenState();
}

class _PresenzeScreenState extends State<PresenzeScreen> {
  final ApiService _api = ApiService();
  List<Lezione> _allLezioni = [];
  List<Lezione> _lezioniMenu = [];
  String? _menuDate;
  Lezione? _selectedLezione;
  bool _isCustomSelection = false;
  List<Presenza> _presenze = [];
  bool _loading = false;
    Map<String, dynamic>? _matchStats;

  List<Scuola> _scuole = [];
  String _sollecitoTemplate = 'Ciao <nome_allievo>, ci sei stasera al corso?';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _formatData(String dataStr) {
    final d = DateTime.tryParse(dataStr);
    if (d == null) return dataStr;
    const giorni = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    final giorno = giorni[d.weekday - 1];
    return '$giorno ${DateFormat('dd/MM/yyyy').format(d)}';
  }

  String? get _currentScuolaNome {
    if (_selectedLezione == null) return null;
    if (_selectedLezione!.scuolaNome != null && _selectedLezione!.scuolaNome!.isNotEmpty) {
      return _selectedLezione!.scuolaNome;
    }
    final found = _scuole.where((s) => s.id == _selectedLezione!.scuolaId);
    return found.isNotEmpty ? found.first.nome : null;
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final lezioni = await _api.getLezioni();
    final scuole = await _api.getScuole();
    final daemonConfig = await _api.getDaemonConfig();
    if (daemonConfig != null && daemonConfig.sollecitoTesto.trim().isNotEmpty) {
      _sollecitoTemplate = daemonConfig.sollecitoTesto.trim();
    }
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Ordine cronologico decrescente per facile reperibilità (a parità di data, crescente per orario)
    final allSorted = List<Lezione>.from(lezioni)
      ..sort((a, b) {
        final cmpData = b.data.compareTo(a.data);
        if (cmpData != 0) return cmpData;
        return a.orarioEffettivo.compareTo(b.orarioEffettivo);
      });

    // Seleziona la data futura più vicina (incluso oggi se presente)
    final futureSorted = allSorted.where((l) => l.data.compareTo(todayStr) >= 0).toList()
      ..sort((a, b) {
        final cmpData = a.data.compareTo(b.data);
        if (cmpData != 0) return cmpData;
        return a.orarioEffettivo.compareTo(b.orarioEffettivo);
      });

    String? closestDate;
    List<Lezione> menuLezioni = [];

    if (futureSorted.isNotEmpty) {
      closestDate = futureSorted.first.data;
      menuLezioni = allSorted.where((l) => l.data == closestDate).toList()
        ..sort((a, b) => a.orarioEffettivo.compareTo(b.orarioEffettivo));
    } else if (allSorted.isNotEmpty) {
      // Se non ci sono lezioni future, prendi la data più recente passata
      closestDate = allSorted.first.data;
      menuLezioni = allSorted.where((l) => l.data == closestDate).toList()
        ..sort((a, b) => a.orarioEffettivo.compareTo(b.orarioEffettivo));
    }

    Lezione? target;
    bool custom = false;

    if (widget.initialLezioneId != null) {
      final found = allSorted.where((l) => l.id == widget.initialLezioneId);
      if (found.isNotEmpty) {
        target = found.first;
        custom = !menuLezioni.any((l) => l.id == target?.id);
      }
    }

    if (target == null) {
      if (menuLezioni.isNotEmpty) {
        target = menuLezioni.first;
        custom = false;
      } else if (allSorted.isNotEmpty) {
        target = allSorted.first;
        custom = true;
      }
    }

    if (mounted) {
      setState(() {
        _scuole = scuole;
        _allLezioni = allSorted;
        _lezioniMenu = menuLezioni;
        _menuDate = closestDate;
        _selectedLezione = target;
        _isCustomSelection = custom;
        _loading = false;
      });

      if (_selectedLezione != null) {
        _loadPresenze(_selectedLezione!.id);
      }
    }
  }

  void _sortPresenze(List<Presenza> list) {
    list.sort((a, b) {
      if (a.presente == true && b.presente != true) return -1;
      if (a.presente != true && b.presente == true) return 1;
      if (a.presente == null && b.presente == false) return -1;
      if (a.presente == false && b.presente == null) return 1;
      int cmp = a.allievoSortName.compareTo(b.allievoSortName);
      if (cmp != 0) return cmp;
      return b.allievoRuolo.compareTo(a.allievoRuolo); // Leader prima
    });
  }

  Future<void> _loadPresenze(String lezioneId) async {
    setState(() => _loading = true);
    var presenze = await _api.getPresenzeForLezione(lezioneId);
    
    if (mounted) {
      setState(() {
        _sortPresenze(presenze);
        _presenze = presenze;
        _matchStats = null;
        _loading = false;
      });
    }
  }


  // ignore: unused_element
  Future<void> _generateMatches() async {
    if (_selectedLezione == null) return;
    setState(() => _loading = true);
    final res = await _api.generateMatches(_selectedLezione!.id);
    setState(() {
      _matchStats = res;
      _loading = false;
    });
  }

  Future<void> _inviaSollecitoRisposta(Presenza p) async {
    if (p.allievoTelefono.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nessun numero di telefono registrato per ${p.cleanNome}.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    // Aggiorna template con eventuale ultima modifica da backend
    try {
      final cfg = await _api.getDaemonConfig();
      if (cfg != null && cfg.sollecitoTesto.trim().isNotEmpty) {
        _sollecitoTemplate = cfg.sollecitoTesto.trim();
      }
    } catch (_) {}

    final nome = p.nomeSolo;
    String baseText = _sollecitoTemplate.trim().isNotEmpty
        ? _sollecitoTemplate
        : 'Ciao <nome_allievo>, ci sei stasera al corso?';

    final textReplaced = baseText
        .replaceAll('<nome_allievo>', nome)
        .replaceAll('{nome_allievo}', nome)
        .replaceAll('{allievo}', nome)
        .replaceAll('{nome}', nome)
        .replaceAll('<nome>', nome);

    final textCtrl = TextEditingController(text: textReplaced);
    bool sending = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat, color: Colors.green.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sollecito Risposta WhatsApp',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'A: ${p.cleanNome} (${p.allievoTelefono})',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messaggio da inviare:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    hintText: 'Scrivi qui il messaggio di sollecito...',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Il messaggio verrà inviato direttamente via WhatsApp Gateway al contatto.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final msg = textCtrl.text.trim();
                      if (msg.isEmpty) return;
                      setDlgState(() => sending = true);
                      final res = await _api.inviaSollecitoAllievo(p.allievoId, testo: msg);
                      final bool ok = res['success'] == true;
                      if (!mounted) return;
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Sollecito inviato con successo a ${p.cleanNome}!'
                                : (res['error'] ?? 'Errore durante l\'invio del messaggio.')),
                            backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        );
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(sending ? 'Invio in corso...' : 'Invia su WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectDateCalendarDialog() {
    DateTime initialDate;
    if (_menuDate != null && DateTime.tryParse(_menuDate!) != null) {
      initialDate = DateTime.parse(_menuDate!);
    } else {
      initialDate = DateTime.now();
    }

    DateTime viewMonth = DateTime(initialDate.year, initialDate.month, 1);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Raggruppa le lezioni per data
    final Map<String, List<Lezione>> lezioniPerData = {};
    for (final l in _allLezioni) {
      lezioniPerData.putIfAbsent(l.data, () => []).add(l);
    }

    const mesi = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    const giorniSettimana = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final daysInMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0).day;
          final firstWeekday = DateTime(viewMonth.year, viewMonth.month, 1).weekday; // 1=Lun, 7=Dom
          final prefixEmptyDays = firstWeekday - 1;
          final isMobile = MediaQuery.of(context).size.width < 500;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.calendar_month, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scegli Data Lezione',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Seleziona un giorno dal calendario mensile',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra navigazione mese
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Mese precedente',
                            onPressed: () {
                              setDlgState(() {
                                viewMonth = DateTime(viewMonth.year, viewMonth.month - 1, 1);
                              });
                            },
                          ),
                          Text(
                            '${mesi[viewMonth.month - 1]} ${viewMonth.year}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Mese successivo',
                            onPressed: () {
                              setDlgState(() {
                                viewMonth = DateTime(viewMonth.year, viewMonth.month + 1, 1);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Giorni della settimana
                    Row(
                      children: giorniSettimana.map((g) {
                        final isWeekend = g == 'Sab' || g == 'Dom';
                        return Expanded(
                          child: Center(
                            child: Text(
                              g,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isWeekend ? Colors.red.shade400 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 16),

                    // Giorni del mese
                    Builder(
                      builder: (context) {
                        final totalSlots = prefixEmptyDays + daysInMonth;
                        final totalRows = (totalSlots / 7).ceil();

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(totalRows, (rowIndex) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: List.generate(7, (colIndex) {
                                  final slotIndex = rowIndex * 7 + colIndex;
                                  final dayNumber = slotIndex - prefixEmptyDays + 1;

                                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                                    return const Expanded(child: SizedBox(height: 44));
                                  }

                                  final dayDate = DateTime(viewMonth.year, viewMonth.month, dayNumber);
                                  final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
                                  final lezioniGiorno = lezioniPerData[dateStr] ?? [];
                                  final hasLessons = lezioniGiorno.isNotEmpty;
                                  final isSelected = _menuDate == dateStr;
                                  final isToday = todayStr == dateStr;

                                  return Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        if (!hasLessons) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Nessuna lezione programmata per ${_formatData(dateStr)}'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                          return;
                                        }

                                        final sortedLezioni = List<Lezione>.from(lezioniGiorno)
                                          ..sort((a, b) => a.orarioEffettivo.compareTo(b.orarioEffettivo));

                                        Navigator.pop(ctx);
                                        setState(() {
                                          _menuDate = dateStr;
                                          _lezioniMenu = sortedLezioni;
                                          _selectedLezione = sortedLezioni.first;
                                          _isCustomSelection = false;
                                        });
                                        _loadPresenze(_selectedLezione!.id);
                                      },
                                      child: Container(
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.deepPurple.shade100
                                              : (isToday ? Colors.grey.shade200 : Colors.transparent),
                                          borderRadius: BorderRadius.circular(8),
                                          border: isToday
                                              ? Border.all(color: Colors.deepPurple.shade300, width: 1.5)
                                              : (isSelected ? Border.all(color: Colors.deepPurple, width: 1.5) : null),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$dayNumber',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: (isSelected || isToday || hasLessons)
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? Colors.deepPurple.shade900
                                                    : (hasLessons ? Colors.black87 : Colors.grey.shade400),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            if (hasLessons)
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade600,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                            else
                                              const SizedBox(height: 6),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    // Legenda puntino blu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Puntino blu = lezione presente',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }


  void _showAddJollyDialog() {
    if (_selectedLezione == null) return;

    final presentiLeader = _presenze.where((p) => p.presente == true && p.allievoRuolo == 'leader').length;
    final presentiFollower = _presenze.where((p) => p.presente == true && p.allievoRuolo == 'follower').length;
    String infoBilanciamento;
    if (presentiLeader > presentiFollower) {
      infoBilanciamento = 'Attualmente servono ${presentiLeader - presentiFollower} Follower per pareggiare i ruoli.';
    } else if (presentiFollower > presentiLeader) {
      infoBilanciamento = 'Attualmente servono ${presentiFollower - presentiLeader} Leader per pareggiare i ruoli.';
    } else {
      infoBilanciamento = 'I ruoli sono attualmente in parità ($presentiLeader Leader e $presentiFollower Follower).';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        bool loading = true;
        List<Jolly> jollyList = [];
        List<Allievo> allieviList = [];
        String? selectedAllievoId;
        bool adding = false;
        String? errorMsg;

        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            if (loading) {
              Future.wait([
                _api.getJolly(),
                _api.getAllievi(isProspect: false),
              ]).then((results) {
                if (ctx.mounted) {
                  final jList = results[0] as List<Jolly>;
                  jList.sort((a, b) => a.priorita.compareTo(b.priorita));
                  final aList = results[1] as List<Allievo>;
                  setDlgState(() {
                    jollyList = jList;
                    allieviList = aList;
                    loading = false;
                    final candidateJolly = jList.where(
                      (j) => !_presenze.any((p) => p.allievoId == j.allievoId && p.presente == true)
                    ).toList();
                    if (candidateJolly.isNotEmpty) {
                      selectedAllievoId = candidateJolly.first.allievoId;
                    } else if (jList.isNotEmpty) {
                      selectedAllievoId = jList.first.allievoId;
                    } else if (aList.isNotEmpty) {
                      selectedAllievoId = aList.first.id;
                    }
                  });
                }
              }).catchError((err) {
                if (ctx.mounted) {
                  setDlgState(() {
                    loading = false;
                    errorMsg = 'Errore nel caricamento: $err';
                  });
                }
              });
            }

            final items = <DropdownMenuItem<String>>[];
            if (jollyList.isNotEmpty) {
              for (final j in jollyList) {
                final giaPresente = _presenze.any((p) => p.allievoId == j.allievoId && p.presente == true);
                items.add(DropdownMenuItem(
                  value: j.allievoId,
                  child: Text(
                    '⭐ [P${j.priorita}] ${j.allievoNome} (${j.allievoRuolo.toUpperCase()})${giaPresente ? " - Già Presente" : ""}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: giaPresente ? Colors.grey : Colors.purple.shade900,
                    ),
                  ),
                ));
              }
            }

            final altriAllievi = allieviList.where((a) => !jollyList.any((j) => j.allievoId == a.id)).toList();
            for (final a in altriAllievi) {
              final giaPresente = _presenze.any((p) => p.allievoId == a.id && p.presente == true);
              items.add(DropdownMenuItem(
                value: a.id,
                child: Text(
                  '👤 ${a.nomeCompleto} (${a.ruolo.toUpperCase()})${giaPresente ? " - Già Presente" : ""}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: giaPresente ? Colors.grey : Colors.black87,
                  ),
                ),
              ));
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Aggiungi Jolly alla Lezione'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : errorMsg != null
                        ? Text(errorMsg!, style: const TextStyle(color: Colors.red))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber.shade900),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        infoBilanciamento,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: selectedAllievoId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Seleziona Allievo / Jolly da aggiungere *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  helperText: 'I Jolly registrati hanno la precedenza (⭐)',
                                ),
                                items: items,
                                onChanged: (val) {
                                  setDlgState(() => selectedAllievoId = val);
                                },
                              ),
                            ],
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                  ),
                  icon: adding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_task, size: 18),
                  label: const Text('Aggiungi e Segna Presente'),
                  onPressed: (adding || loading || selectedAllievoId == null)
                      ? null
                      : () async {
                          setDlgState(() => adding = true);
                          final ok = await _api.aggiungiJollyLezione(_selectedLezione!.id, selectedAllievoId!);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (ok) {
                            await _loadPresenze(_selectedLezione!.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Jolly aggiunto alla lezione e conteggiato tra i presenti!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Errore durante l\'aggiunta del Jolly.'),
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
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _removeJollyPresenza(Presenza p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovi Jolly'),
        content: Text('Vuoi rimuovere ${p.cleanNome} dalle presenze di questa lezione?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _api.deletePresenza(p.id);
      if (ok) {
        if (_selectedLezione != null) {
          _loadPresenze(_selectedLezione!.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${p.cleanNome} rimosso dalla lezione.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _sortPresenze(_presenze);

    final presentiList = _presenze.where((p) => p.presente == true).toList();
    final presentiCount = presentiList.length;
    final whatsappPresentiCount = presentiList.where((p) => p.fonte == 'whatsapp').length;
    final jollyPresentiCount = presentiList.where((p) => p.isJolly).length;

    // Jolly potenziali: differenza assoluta tra leader e follower registrati al corso (compresi prospect)
    final leaderRegistrati = _presenze.where((p) => !p.isJolly && p.allievoRuolo.toLowerCase() == 'leader').length;
    final followerRegistrati = _presenze.where((p) => !p.isJolly && p.allievoRuolo.toLowerCase() == 'follower').length;
    final jollyPotenziali = (followerRegistrati - leaderRegistrati).abs();

    // Jolly necessari: calcolati sulla base delle presenze segnate
    final leaderPresenti = _presenze.where((p) => p.presente == true && p.allievoRuolo.toLowerCase() == 'leader').length;
    final followerPresenti = _presenze.where((p) => p.presente == true && p.allievoRuolo.toLowerCase() == 'follower').length;
    final jollyNecessari = (followerPresenti - leaderPresenti).abs();
    final isMobile = MediaQuery.of(context).size.width < 800;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List<Lezione> dropdownItems = List<Lezione>.from(_lezioniMenu);
    if (_selectedLezione != null && !dropdownItems.any((l) => l.id == _selectedLezione!.id)) {
      dropdownItems.insert(0, _selectedLezione!);
    }
    dropdownItems.sort((a, b) {
      final cmpData = a.data.compareTo(b.data);
      if (cmpData != 0) return cmpData;
      return a.orarioEffettivo.compareTo(b.orarioEffettivo);
    });

    String dropdownLabel = '📅 Lezioni';
    if (_selectedLezione != null && _isCustomSelection) {
      dropdownLabel = '📅 Lezione del ${_formatData(_selectedLezione!.data)}';
    } else if (_menuDate != null) {
      if (_menuDate == todayStr) {
        dropdownLabel = '📅 Lezioni di Oggi (${_lezioniMenu.length})';
      } else {
        dropdownLabel = '📅 Prossime Lezioni - ${_formatData(_menuDate!)} (${_lezioniMenu.length})';
      }
    }

    final Widget lezioneSelectorWidget = dropdownItems.isEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nessuna lezione programmata nel sistema',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          )
        : DropdownButtonFormField<String>(
            value: _selectedLezione?.id,
            hint: const Text('Seleziona lezione...'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: dropdownLabel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: dropdownItems.map((l) {
              final isFromMenuDate = l.data == _menuDate;
              final prefix = isFromMenuDate ? '' : '${_formatData(l.data)} • ';
              return DropdownMenuItem(
                value: l.id,
                child: Text(
                  '$prefix${l.corsoDescrizione} ${l.titolo.isNotEmpty ? "(${l.titolo})" : ""}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (id) {
              if (id != null) {
                final found = dropdownItems.firstWhere((l) => l.id == id);
                final isMenu = _lezioniMenu.any((l) => l.id == id);
                setState(() {
                  _selectedLezione = found;
                  _isCustomSelection = !isMenu;
                });
                _loadPresenze(id);
              }
            },
          );

    final Widget scegliAltraDataBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isCustomSelection ? Colors.deepPurple : Colors.grey.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.calendar_month, size: 18),
      label: const Text('Scegli Altra Data'),
      onPressed: _showSelectDateCalendarDialog,
    );

    return Scaffold(
      floatingActionButton: (isMobile && _selectedLezione != null)
          ? FloatingActionButton(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              tooltip: 'Aggiungi Jolly',
              onPressed: _showAddJollyDialog,
              child: const Icon(Icons.star),
            )
          : null,
      appBar: AppBar(
        title: const Text('Gestione Presenze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica Presenze',
            onPressed: () {
              if (_selectedLezione != null) _loadPresenze(_selectedLezione!.id);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── BARRA DI SELEZIONE LEZIONE (LEZIONI DEL GIORNO + PULSANTE LEZIONE QUALSIASI) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  lezioneSelectorWidget,
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: scegliAltraDataBtn,
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: lezioneSelectorWidget,
                      ),
                      const SizedBox(width: 12),
                      scegliAltraDataBtn,
                    ],
                  ),
                ],


              ],
            ),
          ),

          // ── BARRA AZIONI & SUMMARY PRESENTI ──
          if (_selectedLezione != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.deepPurple.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Presenti: $presentiCount su ${_presenze.length}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.deepPurple.shade900),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade300),
                            ),
                            child: Text(
                              'Jolly potenziali: $jollyPotenziali',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(width: 10),
                            if (jollyPresentiCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.purple.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 12, color: Colors.purple.shade900),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$jollyPresentiCount Jolly',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (whatsappPresentiCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '🤖 $whatsappPresentiCount WhatsApp',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ],
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_selectedLezione!.scuolaNome != null ? "${_selectedLezione!.scuolaNome} • " : ""}${_selectedLezione!.corsoDescrizione}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                  if (!isMobile)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('PDF Appello'),
                          onPressed: _selectedLezione == null
                              ? null
                              : () => PdfReportService.generaFoglioAppello(
                                    context: context,
                                    lezione: _selectedLezione!,
                                    presenze: _presenze,
                                    scuolaNome: _currentScuolaNome,
                                  ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.star, size: 18),
                          label: const Text('Aggiungi Jolly'),
                          onPressed: _showAddJollyDialog,
                        ),
                      ],
                    ),
                ],
              ),
            ),

          if (_matchStats != null && _matchStats!['stats'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coppie generate: ${_matchStats!['stats']['pairs_count']} | Rotazioni: ${_matchStats!['stats']['rotating_leaders'] + _matchStats!['stats']['rotating_followers']}',
                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // ── BODY: LISTA ALLIEVI DEL CORSO E PRESENZE ──
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_selectedLezione == null)
            const Expanded(
              child: Center(
                child: Text('Nessuna lezione selezionata. Usa il menu in alto per scegliere una lezione.'),
              ),
            )
          else if (_presenze.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Nessun partecipante registrato per questa lezione.', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  // RIEPILOGO RUOLI E JOLLY
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.blue.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'Jolly necessari: $jollyNecessari',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 13 : 14,
                            color: jollyNecessari > 0 ? Colors.deepOrange.shade800 : Colors.green.shade800,
                          ),
                        ),
                        if (jollyPresentiCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade300),
                            ),
                            child: Text(
                              '⭐ Jolly presenti: $jollyPresentiCount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.purple.shade900,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Jolly presenti: 0',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 13 : 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // LISTA ALLIEVI CON DIFFERENZIAZIONE VISIVA: MANUALE VS WHATSAPP (GEMINI AI)
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, isMobile ? 80 : 8),
                      itemCount: _presenze.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final p = _presenze[i];
                        final isLeader = p.allievoRuolo.toLowerCase() == 'leader';

                        final Color rowBgColor;
                        final Color rowBorderColor;
                        if (p.presente == true) {
                          rowBgColor = Colors.green.shade100.withValues(alpha: 0.65);
                          rowBorderColor = Colors.green.shade400;
                        } else if (p.presente == false) {
                          rowBgColor = Colors.red.shade100.withValues(alpha: 0.65);
                          rowBorderColor = Colors.red.shade300;
                        } else {
                          // Default: riga grigio chiaro
                          rowBgColor = Colors.grey.shade100;
                          rowBorderColor = Colors.grey.shade300;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: rowBgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: rowBorderColor,
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                // Allievo + Badges
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Avatar Ruolo (Leader o Follower)
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: isLeader ? Colors.blue.shade100 : Colors.pink.shade100,
                                        child: Icon(
                                          isLeader ? Icons.male : Icons.female,
                                          size: 15,
                                          color: isLeader ? Colors.blue.shade800 : Colors.pink.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (p.allievoIsProspect)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            border: Border.all(color: Colors.amber.shade600),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'PROVA',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ),
                                      if (p.isJolly)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            border: Border.all(color: Colors.purple.shade600),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'JOLLY',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple.shade900,
                                            ),
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          p.allievoNome,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            decoration: p.presente == false ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.red.shade900,
                                            decorationThickness: 2,
                                            color: p.presente == false
                                                ? Colors.red.shade900
                                                : (p.presente == true ? Colors.green.shade900 : Colors.black87),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (p.fonte == 'whatsapp')
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.green.shade400),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.message, size: 10, color: Colors.green.shade800),
                                              const SizedBox(width: 3),
                                              Text('WA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Iconcine a destra: Spunta verde, X rossa, Punto interrogativo grigio, WhatsApp
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Spunta verde
                                    _buildPresenzaButton(
                                      isSelected: p.presente == true,
                                      activeBgColor: Colors.green.shade600,
                                      inactiveBgColor: Colors.green.shade50,
                                      iconColor: p.presente == true ? Colors.white : Colors.green.shade700,
                                      borderColor: p.presente == true ? Colors.green.shade700 : Colors.green.shade300,
                                      icon: Icons.check,
                                      tooltip: 'Presente',
                                      onTap: () => _updatePresenzaValore(p, true),
                                    ),
                                    const SizedBox(width: 6),
                                    // 2. X rossa
                                    _buildPresenzaButton(
                                      isSelected: p.presente == false,
                                      activeBgColor: Colors.red.shade600,
                                      inactiveBgColor: Colors.red.shade50,
                                      iconColor: p.presente == false ? Colors.white : Colors.red.shade700,
                                      borderColor: p.presente == false ? Colors.red.shade700 : Colors.red.shade300,
                                      icon: Icons.close,
                                      tooltip: 'Assente',
                                      onTap: () => _updatePresenzaValore(p, false),
                                    ),
                                    const SizedBox(width: 6),
                                    // 3. Punto interrogativo grigio (default)
                                    _buildPresenzaButton(
                                      isSelected: p.presente == null,
                                      activeBgColor: Colors.grey.shade600,
                                      inactiveBgColor: Colors.white,
                                      iconColor: p.presente == null ? Colors.white : Colors.grey.shade700,
                                      borderColor: p.presente == null ? Colors.grey.shade700 : Colors.grey.shade400,
                                      icon: Icons.help_outline,
                                      tooltip: 'Nessuna risposta',
                                      onTap: () => _updatePresenzaValore(p, null),
                                    ),
                                    const SizedBox(width: 6),
                                    // 4. Invia sollecito WhatsApp (dopo il punto interrogativo)
                                    _buildPresenzaButton(
                                      isSelected: false,
                                      activeBgColor: Colors.green.shade600,
                                      inactiveBgColor: p.allievoTelefono.trim().isNotEmpty ? Colors.green.shade50 : Colors.grey.shade100,
                                      iconColor: p.allievoTelefono.trim().isNotEmpty ? Colors.green.shade700 : Colors.grey.shade400,
                                      borderColor: p.allievoTelefono.trim().isNotEmpty ? Colors.green.shade300 : Colors.grey.shade300,
                                      icon: Icons.chat,
                                      tooltip: p.allievoTelefono.trim().isNotEmpty
                                          ? 'Invia sollecito WhatsApp a ${p.allievoNome}'
                                          : 'Nessun numero di telefono per ${p.allievoNome}',
                                      onTap: () => _inviaSollecitoRisposta(p),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
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


  Future<void> _updatePresenzaValore(Presenza p, bool? val) async {
    if (p.isJolly && val == false) {
      // Quando un jolly viene segnato assente deve essere eliminato dalla sezione
      setState(() {
        _presenze.removeWhere((item) => item.id == p.id);
        _sortPresenze(_presenze);
      });
      final ok = await _api.deletePresenza(p.id);
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jolly ${p.cleanNome} segnato assente ed eliminato dalla lezione.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted && _selectedLezione != null) {
          _loadPresenze(_selectedLezione!.id);
        }
      }
      return;
    }

    setState(() {
      p.presente = val;
      p.fonte = 'manuale';
      _sortPresenze(_presenze);
    });
    await _api.updatePresenza(p.id, {
      'presente': val,
      'fonte': 'manuale',
    });
  }

  Widget _buildPresenzaButton({
    required bool isSelected,
    required Color activeBgColor,
    required Color inactiveBgColor,
    required Color iconColor,
    required Color borderColor,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? activeBgColor : inactiveBgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBgColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
