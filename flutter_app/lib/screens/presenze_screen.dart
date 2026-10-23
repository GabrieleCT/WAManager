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
  List<Corso> _corsi = [];
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
    final corsi = await _api.getCorsi();
    final daemonConfig = await _api.getDaemonConfig();
    if (daemonConfig != null && daemonConfig.sollecitoTesto.trim().isNotEmpty) {
      _sollecitoTemplate = daemonConfig.sollecitoTesto.trim();
    }
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Ordine cronologico decrescente per facile reperibilità
    final allSorted = List<Lezione>.from(lezioni)
      ..sort((a, b) => b.data.compareTo(a.data));

    // Seleziona la data futura più vicina (incluso oggi se presente)
    final futureSorted = allSorted.where((l) => l.data.compareTo(todayStr) >= 0).toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    String? closestDate;
    List<Lezione> menuLezioni = [];

    if (futureSorted.isNotEmpty) {
      closestDate = futureSorted.first.data;
      menuLezioni = allSorted.where((l) => l.data == closestDate).toList();
    } else if (allSorted.isNotEmpty) {
      // Se non ci sono lezioni future, prendi la data più recente passata
      closestDate = allSorted.first.data;
      menuLezioni = allSorted.where((l) => l.data == closestDate).toList();
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
        _corsi = corsi;
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

  void _showSelectAnyLezioneDialog() {
    String? selectedScuolaId;
    String? selectedCorsoId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          List<Corso> availableCorsi = selectedScuolaId == null 
              ? [] 
              : _corsi.where((c) => c.scuolaId == selectedScuolaId).toList();
              
          List<Lezione> filteredLezioni = _allLezioni;
          if (selectedCorsoId != null) {
            filteredLezioni = _allLezioni.where((l) => l.corsoId == selectedCorsoId).toList();
          } else if (selectedScuolaId != null) {
            filteredLezioni = _allLezioni.where((l) => l.scuolaId == selectedScuolaId || availableCorsi.any((c) => c.id == l.corsoId)).toList();
          }
          
          filteredLezioni.sort((a, b) => a.data.compareTo(b.data));

          return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.deepPurple),
              SizedBox(width: 10),
              Text('Scegli una Lezione'),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 480,
            child: Column(
              children: [
                DropdownButtonFormField<String?>(
                  value: selectedScuolaId,
                  decoration: InputDecoration(
                    labelText: 'Filtra per Scuola',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutte le Scuole')),
                    ..._scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))),
                  ],
                  onChanged: (val) {
                    setDlgState(() {
                      selectedScuolaId = val;
                      selectedCorsoId = null; // reset corso when scuola changes
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: selectedCorsoId,
                  decoration: InputDecoration(
                    labelText: 'Filtra per Corso',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutti i Corsi')),
                    ...availableCorsi.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})'))),
                  ],
                  onChanged: selectedScuolaId == null ? null : (val) {
                    setDlgState(() {
                      selectedCorsoId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredLezioni.isEmpty
                      ? const Center(child: Text('Nessuna lezione corrispondente ai filtri.'))
                      : ListView.separated(
                          itemCount: filteredLezioni.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final l = filteredLezioni[i];
                            final isCurrent = _selectedLezione?.id == l.id;

                            return ListTile(
                              selected: isCurrent,
                              selectedTileColor: Colors.deepPurple.shade50,
                              leading: CircleAvatar(
                                backgroundColor: isCurrent ? Colors.deepPurple : Colors.grey.shade200,
                                foregroundColor: isCurrent ? Colors.white : Colors.black87,
                                child: const Icon(Icons.event, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(_formatData(l.data), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (l.titolo.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        l.titolo,
                                        style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade900, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${l.scuolaNome != null ? "${l.scuolaNome} • " : ""}${l.corsoDescrizione}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              trailing: isCurrent ? const Icon(Icons.check, color: Colors.deepPurple) : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                final isMenu = _lezioniMenu.any((o) => o.id == l.id);
                                setState(() {
                                  _selectedLezione = l;
                                  _isCustomSelection = !isMenu;
                                });
                                _loadPresenze(l.id);
                              },
                            );
                          },
                        ),
                ),
              ],
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
    final manualePresentiCount = presentiList.where((p) => p.fonte == 'manuale').length;
    final jollyPresentiCount = presentiList.where((p) => p.isJolly).length;

    final leaderCount = _presenze.where((p) => p.presente == true && p.allievoRuolo == 'leader').length;
    final followerCount = _presenze.where((p) => p.presente == true && p.allievoRuolo == 'follower').length;
    final jollyNecessari = (leaderCount - followerCount).abs();
    final isMobile = MediaQuery.of(context).size.width < 800;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List<Lezione> dropdownItems = List<Lezione>.from(_lezioniMenu);
    if (_selectedLezione != null && !dropdownItems.any((l) => l.id == _selectedLezione!.id)) {
      dropdownItems.insert(0, _selectedLezione!);
    }

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

    final Widget scegliAltraLezioneBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isCustomSelection ? Colors.deepPurple : Colors.grey.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.event_note, size: 18),
      label: const Text('Scegli Altra Lezione'),
      onPressed: _showSelectAnyLezioneDialog,
    );

    return Scaffold(
      floatingActionButton: (isMobile && _selectedLezione != null)
          ? FloatingActionButton.extended(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.star),
              label: const Text('Aggiungi Jolly'),
              onPressed: _showAddJollyDialog,
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
                    child: scegliAltraLezioneBtn,
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
                      scegliAltraLezioneBtn,
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
                            if (manualePresentiCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '✍️ $manualePresentiCount Manuali',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                                ),
                              ),
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
                  // RIEPILOGO RUOLI (LEADER, FOLLOWER, JOLLY)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.blue.shade50,
                    child: isMobile
                        ? Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Text('Totali Leader: $leaderCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Totali Follower: $followerCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Text(
                                    'Jolly necessari: $jollyNecessari',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
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
                                          fontSize: 12,
                                          color: Colors.purple.shade900,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      'Jolly presenti: 0',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text('Totali Leader: $leaderCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Totali Follower: $followerCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                'Jolly necessari: $jollyNecessari',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
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
                                      color: Colors.purple.shade900,
                                    ),
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
                        final isWa = p.fonte == 'whatsapp';

                        return Container(
                          decoration: BoxDecoration(
                            color: isWa ? Colors.green.shade50.withValues(alpha: 0.6) : Colors.indigo.shade50.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isWa ? Colors.green.shade400 : Colors.indigo.shade200,
                              width: isWa ? 1.5 : 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: p.presente == true
                                          ? (isWa ? Colors.green.shade600 : (p.isJolly ? Colors.purple.shade600 : Colors.indigo.shade600))
                                          : (p.presente == false ? Colors.red.shade100 : Colors.grey.shade300),
                                      child: Icon(
                                        p.presente == true
                                            ? (isWa ? Icons.smart_toy : (p.isJolly ? Icons.star : Icons.check))
                                            : (p.presente == false ? Icons.close : Icons.help_outline),
                                        color: p.presente == true ? Colors.white : (p.presente == false ? Colors.red.shade800 : Colors.grey.shade700),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (p.allievoIsProspect)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 8),
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
                                              Expanded(
                                                child: Text(
                                                  p.allievoNome,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    decoration: p.presente == false ? TextDecoration.lineThrough : null,
                                                    color: p.presente == false ? Colors.grey : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              if (p.isJolly) ...[
                                                if (!isMobile)
                                                  Container(
                                                    margin: const EdgeInsets.only(right: 8),
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
                                                InkWell(
                                                  onTap: () => _removeJollyPresenza(p),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade50,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.red.shade200),
                                                    ),
                                                    child: Icon(Icons.close, size: 14, color: Colors.red.shade700),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.chat,
                                                  size: 19,
                                                  color: p.allievoTelefono.trim().isNotEmpty
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade400,
                                                ),
                                                tooltip: p.allievoTelefono.trim().isNotEmpty
                                                    ? 'Invia sollecito risposta WhatsApp a '
                                                    : 'Nessun numero di telefono per ',
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _inviaSollecitoRisposta(p),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Ruolo: ${p.allievoRuolo.toUpperCase()}${p.allievoPartnerId != null && p.cleanPartnerNome.isNotEmpty ? " - Coppia: ${p.cleanPartnerNome}" : ""}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                                                      const SizedBox(width: 4),
                                                      Text('WA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                                    ],
                                                  ),
                                                )
                                              else if (p.fonte == 'manuale' && !isMobile)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.indigo.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.indigo.shade300),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.edit_note, size: 10, color: Colors.indigo.shade900),
                                                      const SizedBox(width: 3),
                                                      Text('Man', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<String>(
                                  showSelectedIcon: !isMobile,
                                  segments: [
                                    ButtonSegment<String>(
                                      value: 'presente',
                                      label: isMobile ? null : const Text('Presente'),
                                      icon: const Icon(Icons.check),
                                      tooltip: 'Presente',
                                    ),
                                    ButtonSegment<String>(
                                      value: 'assente',
                                      label: isMobile ? null : const Text('Assente'),
                                      icon: const Icon(Icons.close),
                                      tooltip: 'Assente',
                                    ),
                                    ButtonSegment<String>(
                                      value: 'non_risposto',
                                      label: isMobile ? null : const Text('Nessuna risp.'),
                                      icon: const Icon(Icons.help_outline),
                                      tooltip: 'Nessuna risposta',
                                    ),
                                  ],
                                  selected: {
                                    p.presente == true
                                        ? 'presente'
                                        : (p.presente == false ? 'assente' : 'non_risposto')
                                  },
                                  onSelectionChanged: (Set<String> newSelection) async {
                                    bool? val;
                                    if (newSelection.first == 'presente') val = true;
                                    if (newSelection.first == 'assente') val = false;
                                    
                                    setState(() {
                                      p.presente = val;
                                      p.fonte = 'manuale';
                                      _sortPresenze(_presenze);
                                    });
                                    await _api.updatePresenza(p.id, {
                                      'presente': val,
                                      'fonte': 'manuale',
                                    });
                                  },
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return const Color(0xFFFFD1D6);
                                      }
                                      return null;
                                    }),
                                  ),
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
}
