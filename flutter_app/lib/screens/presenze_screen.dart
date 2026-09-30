import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class PresenzeScreen extends StatefulWidget {
  final String? initialLezioneId;
  const PresenzeScreen({super.key, this.initialLezioneId});

  @override
  State<PresenzeScreen> createState() => _PresenzeScreenState();
}

class _PresenzeScreenState extends State<PresenzeScreen> {
  final ApiService _api = ApiService();
  List<Lezione> _allLezioni = [];
  List<Lezione> _lezioniOggi = [];
  Lezione? _selectedLezione;
  bool _isCustomSelection = false;
  List<Presenza> _presenze = [];
  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _matchStats;

  List<Scuola> _scuole = [];
  List<Corso> _corsi = [];

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

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final lezioni = await _api.getLezioni();
    final scuole = await _api.getScuole();
    final corsi = await _api.getCorsi();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Ordine cronologico decrescente per facile reperibilità
    final allSorted = List<Lezione>.from(lezioni)
      ..sort((a, b) => b.data.compareTo(a.data));
    final oggi = allSorted.where((l) => l.data == todayStr).toList();

    Lezione? target;
    bool custom = false;

    if (widget.initialLezioneId != null) {
      final found = allSorted.where((l) => l.id == widget.initialLezioneId);
      if (found.isNotEmpty) {
        target = found.first;
        custom = !oggi.any((l) => l.id == target?.id);
      }
    }

    if (target == null) {
      if (oggi.isNotEmpty) {
        target = oggi.first;
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
        _lezioniOggi = oggi;
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
      if (a.presente != b.presente) return a.presente ? -1 : 1; // Presenti in cima
      int cmp = a.allievoSortName.compareTo(b.allievoSortName);
      if (cmp != 0) return cmp;
      return b.allievoRuolo.compareTo(a.allievoRuolo); // Leader prima
    });
  }

  Future<void> _loadPresenze(String lezioneId) async {
    setState(() => _loading = true);
    // Assicura che i nuovi allievi vengano aggiunti alle presenze
    await _api.initPresenze(lezioneId);
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

  Future<void> _savePresenze() async {
    if (_selectedLezione == null) return;
    setState(() => _saving = true);
    final payload = _presenze.map((p) => {
      'allievo_id': p.allievoId,
      'presente': p.presente,
      'fonte': p.fonte,
    }).toList();
    final ok = await _api.batchUpdatePresenze(_selectedLezione!.id, payload);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Presenze salvate con successo!' : 'Errore nel salvataggio presenze.'),
          backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
        ),
      );
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
                                final isOggi = _lezioniOggi.any((o) => o.id == l.id);
                                setState(() {
                                  _selectedLezione = l;
                                  _isCustomSelection = !isOggi;
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

    final presentiLeader = _presenze.where((p) => p.presente && p.allievoRuolo == 'leader').length;
    final presentiFollower = _presenze.where((p) => p.presente && p.allievoRuolo == 'follower').length;
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
                      (j) => !_presenze.any((p) => p.allievoId == j.allievoId && p.presente)
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
                final giaPresente = _presenze.any((p) => p.allievoId == j.allievoId && p.presente);
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
              final giaPresente = _presenze.any((p) => p.allievoId == a.id && p.presente);
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
        content: Text('Vuoi rimuovere ${p.allievoNome} dalle presenze di questa lezione?'),
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
              content: Text('${p.allievoNome} rimosso dalla lezione.'),
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

    final presentiList = _presenze.where((p) => p.presente).toList();
    final presentiCount = presentiList.length;
    final whatsappPresentiCount = presentiList.where((p) => p.fonte == 'whatsapp').length;
    final manualePresentiCount = presentiList.where((p) => p.fonte == 'manuale').length;
    final jollyPresentiCount = presentiList.where((p) => p.isJolly).length;

    final leaderCount = _presenze.where((p) => p.presente && p.allievoRuolo == 'leader').length;
    final followerCount = _presenze.where((p) => p.presente && p.allievoRuolo == 'follower').length;
    final jollyNecessari = (leaderCount - followerCount).abs();

    return Scaffold(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // MENU A TENDINA: LEZIONI DEL GIORNO
                    Expanded(
                      flex: 6,
                      child: _lezioniOggi.isEmpty
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
                                      'Nessuna lezione programmata per oggi',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _isCustomSelection ? null : _selectedLezione?.id,
                              hint: const Text('Seleziona lezione di oggi...'),
                              decoration: InputDecoration(
                                labelText: '📅 Lezioni di Oggi (${_lezioniOggi.length})',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: _lezioniOggi.map((l) {
                                return DropdownMenuItem(
                                  value: l.id,
                                  child: Text(
                                    '${l.corsoDescrizione} ${l.titolo.isNotEmpty ? "(${l.titolo})" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (id) {
                                if (id != null) {
                                  final found = _lezioniOggi.firstWhere((l) => l.id == id);
                                  setState(() {
                                    _selectedLezione = found;
                                    _isCustomSelection = false;
                                  });
                                  _loadPresenze(id);
                                }
                              },
                            ),
                    ),
                    const SizedBox(width: 12),

                    // PULSANTINO PER SCEGLIERE UNA LEZIONE QUALSIASI
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCustomSelection ? Colors.deepPurple : Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.event_note, size: 18),
                      label: const Text('Scegli Altra Lezione'),
                      onPressed: _showSelectAnyLezioneDialog,
                    ),
                  ],
                ),

                // BADGE NOTIFICA SE È SELEZIONATA UNA LEZIONE NON DI OGGI
                if (_isCustomSelection && _selectedLezione != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Lezione selezionata dall\'archivio: ${_formatData(_selectedLezione!.data)} • ${_selectedLezione!.corsoDescrizione} ${_selectedLezione!.titolo.isNotEmpty ? "(${_selectedLezione!.titolo})" : ""}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                        if (_lezioniOggi.isNotEmpty)
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () {
                              setState(() {
                                _selectedLezione = _lezioniOggi.first;
                                _isCustomSelection = false;
                              });
                              _loadPresenze(_lezioniOggi.first.id);
                            },
                            child: const Text('Torna a Oggi', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
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
                          if (whatsappPresentiCount > 0)
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedLezione!.scuolaNome != null ? "${_selectedLezione!.scuolaNome} • " : ""}${_selectedLezione!.corsoDescrizione}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.star, size: 18),
                        label: const Text('Aggiungi Jolly'),
                        onPressed: _showAddJollyDialog,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_alt, size: 18),
                        label: const Text('Re-inizializza'),
                        onPressed: () async {
                          await _api.initPresenzeLezione(_selectedLezione!.id);
                          _loadPresenze(_selectedLezione!.id);
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.save, size: 18),
                        label: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Salva Presenze'),
                        onPressed: _saving ? null : _savePresenze,
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Nessun partecipante registrato per questa lezione.', style: TextStyle(fontSize: 15)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sync),
                      onPressed: () async {
                        await _api.initPresenzeLezione(_selectedLezione!.id);
                        _loadPresenze(_selectedLezione!.id);
                      },
                      label: const Text('Carica tutti gli allievi del corso'),
                    ),
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
                    child: Row(
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            value: p.presente,
                            activeColor: isWa ? Colors.green.shade700 : Colors.deepPurple,
                            secondary: CircleAvatar(
                              backgroundColor: p.presente
                                  ? (isWa ? Colors.green.shade600 : (p.isJolly ? Colors.purple.shade600 : Colors.indigo.shade600))
                                  : Colors.red.shade100,
                              child: Icon(
                                p.presente
                                    ? (isWa ? Icons.smart_toy : (p.isJolly ? Icons.star : Icons.check))
                                    : Icons.close,
                                color: p.presente ? Colors.white : Colors.red.shade800,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                if (p.allievoIsProspect) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      border: Border.all(color: Colors.amber.shade600),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'PROVA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                                if (p.isJolly) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      border: Border.all(color: Colors.purple.shade600),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, size: 10, color: Colors.purple.shade900),
                                        const SizedBox(width: 2),
                                        Text(
                                          'JOLLY',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Text(
                                    p.allievoNome,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                // BADGE VISIVO DIFFERENZIATO FONTE
                                if (isWa)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade600),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.smart_toy, size: 14, color: Colors.green.shade900),
                                        const SizedBox(width: 4),
                                        Text(
                                          'WhatsApp (AI Gemini)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.indigo.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_note, size: 15, color: Colors.indigo.shade900),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Manuale',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (p.isJolly) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _removeJollyPresenza(p),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Icon(Icons.close, size: 14, color: Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Ruolo: ${p.allievoRuolo.toUpperCase()} • Tel: ${p.allievoTelefono.isNotEmpty ? p.allievoTelefono : "N/D"}${p.allievoPartnerId != null ? ' | Partner: ' + p.allievoPartnerNome! : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                p.presente = val ?? false;
                                p.fonte = 'manuale'; // Modifica esplicita dall'utente
                                _sortPresenze(_presenze);
                              });
                            },
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
