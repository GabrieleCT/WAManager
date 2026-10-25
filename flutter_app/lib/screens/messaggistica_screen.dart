import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'wa_screen.dart';

class MessaggisticaScreen extends StatefulWidget {
  final int initialTab;
  const MessaggisticaScreen({super.key, this.initialTab = 0});

  @override
  State<MessaggisticaScreen> createState() => _MessaggisticaScreenState();
}

class _MessaggisticaScreenState extends State<MessaggisticaScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _savingDaemon = false;
  bool _executingDaemon = false;
  bool _sendingManual = false;
  bool _savingSollecito = false;
  bool _savingJolly = false;
  final TextEditingController _testoJollyCtl = TextEditingController(
    text: 'Ciao! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺',
  );

  // 1. Configurazione Demone
  TimeOfDay _daemonTime = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedDays = {0, 1, 2, 3, 4, 5, 6}; // 0=Lun, 6=Dom
  final TextEditingController _testoDaemonCtl = TextEditingController();
  final TextEditingController _pollOpt1Ctl = TextEditingController(text: 'Ci sono! 🕺💃');
  final TextEditingController _pollOpt2Ctl = TextEditingController(text: 'Non ci sono 🚫');
  int _oreAscoltoRisposte = 5;
  bool _isPoll = true;
  bool _daemonActive = true;

  // 2. Invio Manuale
  List<Corso> _corsi = [];
  final Set<String> _selectedCorsoIds = {};
  String _filtroRicerca = '';
  bool _usaTestoPredefinito = true;
  final TextEditingController _testoManualeCtl = TextEditingController();
  bool _manualIsPoll = true;
  final TextEditingController _manualOpt1Ctl = TextEditingController(text: 'Ci sono! 🕺💃');
  final TextEditingController _manualOpt2Ctl = TextEditingController(text: 'Non ci sono 🚫');

  // 3. Configurazione Sollecito
  bool _sollecitoAttivo = false;
  TimeOfDay _sollecitoTime = const TimeOfDay(hour: 16, minute: 0);
  final TextEditingController _testoSollecitoCtl = TextEditingController();

  final List<String> _giorniNomi = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _testoDaemonCtl.dispose();
    _pollOpt1Ctl.dispose();
    _pollOpt2Ctl.dispose();
    _testoManualeCtl.dispose();
    _manualOpt1Ctl.dispose();
    _manualOpt2Ctl.dispose();
    _testoSollecitoCtl.dispose();
    _testoJollyCtl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final config = await _api.getDaemonConfig();
      final corsi = await _api.getCorsi();

      if (config != null) {
        // Parsing orario HH:MM demone
        final parts = config.orario.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 8;
          final m = int.tryParse(parts[1]) ?? 0;
          _daemonTime = TimeOfDay(hour: h, minute: m);
        }

        // Parsing giorni
        _selectedDays.clear();
        final days = config.giorniSettimana
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>();
        _selectedDays.addAll(days);
        if (_selectedDays.isEmpty) {
          _selectedDays.addAll([0, 1, 2, 3, 4, 5, 6]);
        }

        _testoDaemonCtl.text = config.testo;
        _isPoll = config.isPoll;
        _pollOpt1Ctl.text = config.pollOpzione1;
        _pollOpt2Ctl.text = config.pollOpzione2;
        _oreAscoltoRisposte = config.oreAscoltoRisposte;
        _daemonActive = config.isActive;

        // Parsing sollecito
        _sollecitoAttivo = config.sollecitoAttivo;
        final solParts = config.sollecitoOrario.split(':');
        if (solParts.length >= 2) {
          final sh = int.tryParse(solParts[0]) ?? 16;
          final sm = int.tryParse(solParts[1]) ?? 0;
          _sollecitoTime = TimeOfDay(hour: sh, minute: sm);
        }
        _testoSollecitoCtl.text = config.sollecitoTesto.isNotEmpty
            ? config.sollecitoTesto
            : "Ciao <nome_allievo>, ci sei stasera al corso?";
        if (config.jollyTesto.isNotEmpty) {
          _testoJollyCtl.text = config.jollyTesto;
        }

        if (_testoManualeCtl.text.isEmpty) {
          _testoManualeCtl.text = config.testo;
        }
      } else {
        _testoDaemonCtl.text =
            "Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c'è lezione per il corso {corso} alle {orario}.\n"
            "Chi di voi sarà presente stasera? Rispondete al sondaggio per confermare la vostra presenza!";
        _testoManualeCtl.text = _testoDaemonCtl.text;
        _testoSollecitoCtl.text = "Ciao <nome_allievo>, ci sei stasera al corso?";
        _testoJollyCtl.text = 'Ciao {nickname}! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺';
      }

      _corsi = corsi;
      if (_selectedCorsoIds.isEmpty && _corsi.isNotEmpty) {
        _selectedCorsoIds.addAll(_corsi.map((c) => c.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento delle impostazioni: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _inserisciTagNelController(TextEditingController controller, String tag) {
    final text = controller.text;
    final selection = controller.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      controller.text += tag;
    }
    setState(() {});
  }

  Future<void> _salvaConfigurazioneDemone() async {
    if (_testoDaemonCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il testo del messaggio non può essere vuoto.')),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un giorno della settimana.')),
      );
      return;
    }

    setState(() => _savingDaemon = true);

    final sortedDays = _selectedDays.toList()..sort();
    final data = {
      'orario': _formatTimeOfDay(_daemonTime),
      'giorni_settimana': sortedDays.join(','),
      'testo': _testoDaemonCtl.text.trim(),
      'is_poll': _isPoll,
      'poll_opzione_1': _pollOpt1Ctl.text.trim(),
      'poll_opzione_2': _pollOpt2Ctl.text.trim(),
      'ore_ascolto_risposte': _oreAscoltoRisposte,
      'is_active': _daemonActive,
      'sollecito_attivo': _sollecitoAttivo,
      'sollecito_orario': _formatTimeOfDay(_sollecitoTime),
      'sollecito_testo': _testoSollecitoCtl.text.trim(),
    };

    final res = await _api.saveDaemonConfig(data);
    setState(() => _savingDaemon = false);

    if (mounted) {
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione demone salvata e schedulazione aggiornata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante il salvataggio della configurazione.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eseguiDemoneSubito() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esegui Controllo Demone Adesso'),
        content: const Text(
          'Verrà eseguito immediatamente il controllo per la giornata odierna.\n'
          'Il demone individuerà tutti i corsi attivi oggi (in base al giorno della settimana del corso o a lezioni in programma) e invierà il messaggio/sondaggio ai rispettivi gruppi WhatsApp.\n\n'
          'Vuoi procedere?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Esegui Ora'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _executingDaemon = true);
    final res = await _api.eseguiDemoneOra();
    setState(() => _executingDaemon = false);

    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Demone eseguito con successo.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore esecuzione: ${res['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _salvaConfigurazioneSollecito() async {
    if (_testoSollecitoCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il testo del messaggio di sollecito non può essere vuoto.')),
      );
      return;
    }

    setState(() => _savingSollecito = true);

    final data = {
      'sollecito_testo': _testoSollecitoCtl.text.trim(),
      'sollecito_attivo': false,
    };

    final res = await _api.saveDaemonConfig(data);
    setState(() => _savingSollecito = false);

    if (mounted) {
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione messaggio di sollecito salvata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante il salvataggio della configurazione sollecito.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _inviaSondaggioManuale() async {
    if (_selectedCorsoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un corso a cui inviare il sondaggio.')),
      );
      return;
    }

    final testoEffettivo = _usaTestoPredefinito ? _testoDaemonCtl.text.trim() : _testoManualeCtl.text.trim();
    if (testoEffettivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il testo del sondaggio non può essere vuoto.')),
      );
      return;
    }

    final isPoll = _usaTestoPredefinito ? _isPoll : _manualIsPoll;
    List<String>? opzioni;
    if (isPoll) {
      final o1 = (_usaTestoPredefinito ? _pollOpt1Ctl.text : _manualOpt1Ctl.text).trim();
      final o2 = (_usaTestoPredefinito ? _pollOpt2Ctl.text : _manualOpt2Ctl.text).trim();
      if (o1.isEmpty || o2.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le opzioni del sondaggio non possono essere vuote.')),
        );
        return;
      }
      opzioni = [o1, o2];
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Invio Manuale'),
        content: Text(
          'Stai per inviare ${isPoll ? "un sondaggio" : "un messaggio"} WhatsApp a ${_selectedCorsoIds.length} cors'
          '${_selectedCorsoIds.length == 1 ? "o" : "i"}.\n\n'
          'I messaggi verranno inviati direttamente ai rispettivi gruppi WhatsApp configurati.\n'
          'Vuoi procedere?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Conferma e Invia'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _sendingManual = true);

    final res = await _api.inviaSondaggioManuale(
      _selectedCorsoIds.toList(),
      testo: testoEffettivo,
      isPoll: isPoll,
      pollOpzioni: opzioni,
    );

    setState(() => _sendingManual = false);

    if (mounted) {
      if (res['success'] == true) {
        final inviati = res['inviati_con_successo'] ?? 0;
        final totale = res['totale_corsi'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sondaggi inviati con successo a $inviati su $totale corsi!'),
            backgroundColor: Colors.green,
          ),
        );
        _mostraDialogRisultati('Esito Invio Sondaggi', res['dettagli'] ?? []);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'invio: ${res['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostraDialogRisultati(String titolo, List<dynamic> dettagli) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titolo),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: dettagli.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = dettagli[i];
                    final bool success = item['success'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        success ? Icons.check_circle : Icons.error,
                        color: success ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        '${item['scuola_nome'] != null && item['scuola_nome'].toString().isNotEmpty ? "${item['scuola_nome']} - " : ""}${item['corso_nome'] ?? ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        success
                            ? 'Inviato al gruppo: ${item['gruppo_whatsapp']}'
                            : 'Errore: ${item['error']}',
                        style: TextStyle(color: success ? Colors.green.shade700 : Colors.red.shade700),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  String _renderAnteprima(String template) {
    return template
        .replaceAll('{corso}', 'Tango Argentino Intermedio')
        .replaceAll('{scuola}', 'Milano Tango Club')
        .replaceAll('{orario}', '21:00')
        .replaceAll('{data}', 'Oggi')
        .replaceAll('{argomento}', 'Giro con Sacada e Ocho Cortado');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      initialIndex: widget.initialTab.clamp(0, 4),
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messaggistica'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_send),
                text: 'Configurazione Demone Automatico',
              ),
              Tab(
                icon: Icon(Icons.send_rounded),
                text: 'Invio Manuale Sondaggio',
              ),
              Tab(
                icon: Icon(Icons.notification_important_outlined),
                text: 'Configurazione Messaggio di Sollecito',
              ),
              Tab(
                icon: Icon(Icons.star),
                text: 'Configurazione Messaggio Jolly',
              ),
              Tab(
                icon: Icon(Icons.qr_code_scanner),
                text: 'WhatsApp Gateway',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Ricarica dati',
              onPressed: _loadAllData,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildTabDemone(),
            _buildTabInvioManuale(),
            _buildTabSollecito(),
            _buildTabJolly(),
            const WhatsAppScreen(embedded: true),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: CONFIGURAZIONE DEMONE
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabDemone() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner info
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Demone Notturno / Mattutino Automatico',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nei giorni selezionati, all\'orario stabilito (${_formatTimeOfDay(_daemonTime)}), il demone '
                              'individua in automatico tutti i corsi attivi quel giorno (in base al giorno della settimana del corso o lezioni pianificate) '
                              'e invia il sondaggio o messaggio al rispettivo gruppo WhatsApp.',
                              style: const TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 1: ORARIO E GIORNI
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.alarm, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text(
                                'Orario e Giorni di Avvio',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Switch(
                            value: _daemonActive,
                            activeThumbColor: Colors.green,
                            onChanged: (v) => setState(() => _daemonActive = v),
                          ),
                        ],
                      ),
                      Text(
                        _daemonActive
                            ? 'Demone attualmente ATTIVO'
                            : 'Demone attualmente DISATTIVATO (nessun messaggio verrà inviato automaticamente)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _daemonActive ? Colors.green : Colors.red,
                        ),
                      ),
                      const Divider(height: 32),

                      // Selezione Orario
                      Row(
                        children: [
                          const Text('Orario di esecuzione giornaliero:', style: TextStyle(fontSize: 15)),
                          const Spacer(),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _formatTimeOfDay(_daemonTime),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _daemonTime,
                              );
                              if (picked != null) {
                                setState(() => _daemonTime = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Selezione Giorni
                      const Text('Giorni della settimana in cui inviare:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (index) {
                          final isSelected = _selectedDays.contains(index);
                          return FilterChip(
                            label: Text(_giorniNomi[index]),
                            selected: isSelected,
                            selectedColor: Colors.indigo.shade100,
                            checkmarkColor: Colors.indigo,
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDays.add(index);
                                } else {
                                  if (_selectedDays.length > 1) {
                                    _selectedDays.remove(index);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Deve essere selezionato almeno un giorno.')),
                                    );
                                  }
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 2: FORMATO E TESTO
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text('Formato e Testo del Messaggio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 28),

                      // Tipo invio: Sondaggio WhatsApp o Messaggio semplice
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Sondaggio Interattivo WhatsApp'),
                              subtitle: const Text('Invia un vero sondaggio nativo a scelta singola/multipla'),
                              value: true,
                              groupValue: _isPoll,
                              onChanged: (v) => setState(() => _isPoll = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Messaggio di Testo Semplice'),
                              subtitle: const Text('Invia un normale testo di promemoria nel gruppo'),
                              value: false,
                              groupValue: _isPoll,
                              onChanged: (v) => setState(() => _isPoll = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Campo Testo / Domanda
                      Text(
                        _isPoll ? 'Domanda del Sondaggio / Intestazione:' : 'Testo del Messaggio:',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _testoDaemonCtl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Scrivi il testo del messaggio da inviare...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Placeholder Tag cliccabili
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Tag dinamici:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{corso}'),
                            onPressed: () => _inserisciTagNelController(_testoDaemonCtl, '{corso}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{orario}'),
                            onPressed: () => _inserisciTagNelController(_testoDaemonCtl, '{orario}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{data}'),
                            onPressed: () => _inserisciTagNelController(_testoDaemonCtl, '{data}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{scuola}'),
                            onPressed: () => _inserisciTagNelController(_testoDaemonCtl, '{scuola}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{argomento}'),
                            onPressed: () => _inserisciTagNelController(_testoDaemonCtl, '{argomento}'),
                          ),
                        ],
                      ),

                      if (_isPoll) ...[
                        const SizedBox(height: 20),
                        const Text('Opzioni del Sondaggio:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pollOpt1Ctl,
                                decoration: InputDecoration(
                                  labelText: 'Opzione 1 (Presenza)',
                                  prefixIcon: const Icon(Icons.check, color: Colors.green),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _pollOpt2Ctl,
                                decoration: InputDecoration(
                                  labelText: 'Opzione 2 (Assenza)',
                                  prefixIcon: const Icon(Icons.close, color: Colors.red),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                      // Box Anteprima Stile WhatsApp
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF8C6).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.preview, size: 16, color: Colors.green),
                                SizedBox(width: 6),
                                Text(
                                  'Anteprima visualizzazione gruppo WhatsApp:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _renderAnteprima(_testoDaemonCtl.text),
                              style: const TextStyle(fontSize: 14, height: 1.3),
                            ),
                            if (_isPoll) ...[
                              const Divider(height: 16),
                              Center(
                                child: Wrap(
                                  spacing: 12,
                                  children: [
                                    OutlinedButton(
                                      onPressed: null,
                                      child: Text('🔘 ${_pollOpt1Ctl.text}'),
                                    ),
                                    OutlinedButton(
                                      onPressed: null,
                                      child: Text('🔘 ${_pollOpt2Ctl.text}'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // BOTTONI SALVATAGGIO E TEST
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: _executingDaemon
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_circle_outline),
                    label: Text(_executingDaemon ? 'Controllo in corso...' : 'Avvia Demone Adesso per Oggi'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: (_executingDaemon || _savingDaemon) ? null : _eseguiDemoneSubito,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: _savingDaemon
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_savingDaemon ? 'Salvataggio...' : 'Salva Configurazione Demone'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: (_savingDaemon || _executingDaemon) ? null : _salvaConfigurazioneDemone,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: INVIO MANUALE SONDAGGIO
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabInvioManuale() {
    final query = _filtroRicerca.toLowerCase().trim();
    final corsiFiltrati = _corsi.where((c) {
      final sNome = c.scuolaNome.toLowerCase();
      final cNome = '${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})'.toLowerCase();
      return query.isEmpty || sNome.contains(query) || cNome.contains(query);
    }).toList();

    return Row(
      children: [
        // PANNELLO SINISTRO: LISTA CORSI
        SizedBox(
          width: 380,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cerca per scuola o corso...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) => setState(() => _filtroRicerca = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedCorsoIds.length} di ${_corsi.length} selezionati',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => setState(() => _selectedCorsoIds.addAll(_corsi.map((c) => c.id))),
                              child: const Text('Tutti', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () => setState(() => _selectedCorsoIds.clear()),
                              child: const Text('Nessuno', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: corsiFiltrati.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = corsiFiltrati[i];
                    final isChecked = _selectedCorsoIds.contains(c.id);
                    final hasWa = c.gruppoWhatsapp.isNotEmpty;

                    return CheckboxListTile(
                      value: isChecked,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        '${c.scuolaNome.isNotEmpty ? "${c.scuolaNome} - " : ""}${c.livelloDisplay}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.giornoSettimanaDisplay} ${c.orario}', style: const TextStyle(fontSize: 12)),
                          if (!hasWa)
                            const Text(
                              '⚠️ Gruppo WhatsApp non impostato',
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      secondary: hasWa
                          ? const Icon(Icons.chat, color: Colors.green, size: 20)
                          : const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedCorsoIds.add(c.id);
                          } else {
                            _selectedCorsoIds.remove(c.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),

        // PANNELLO DESTRO: CONFIGURAZIONE INVIO MANUALE
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      elevation: 0,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.send_rounded, color: Colors.green, size: 36),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invio Manuale Sondaggio Estemporaneo',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Seleziona i corsi dalla lista a sinistra e invia subito il sondaggio/messaggio ai rispettivi gruppi WhatsApp. '
                                    'Puoi utilizzare il testo predefinito del demone o personalizzarlo per questo singolo invio.',
                                    style: TextStyle(fontSize: 13, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle: Testo predefinito vs Personalizzato
                    SwitchListTile(
                      title: const Text('Usa configurazione predefinita del demone', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Se disattivato, puoi personalizzare il testo e le opzioni solo per questo invio'),
                      value: _usaTestoPredefinito,
                      onChanged: (v) => setState(() => _usaTestoPredefinito = v),
                    ),
                    const Divider(height: 32),

                    if (!_usaTestoPredefinito) ...[
                      // Modalità: Sondaggio vs Testo semplice
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Sondaggio WhatsApp'),
                              value: true,
                              groupValue: _manualIsPoll,
                              onChanged: (v) => setState(() => _manualIsPoll = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Messaggio di Testo'),
                              value: false,
                              groupValue: _manualIsPoll,
                              onChanged: (v) => setState(() => _manualIsPoll = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testoManualeCtl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Testo del messaggio da inviare:',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{corso}'),
                            onPressed: () => _inserisciTagNelController(_testoManualeCtl, '{corso}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{orario}'),
                            onPressed: () => _inserisciTagNelController(_testoManualeCtl, '{orario}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{data}'),
                            onPressed: () => _inserisciTagNelController(_testoManualeCtl, '{data}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{scuola}'),
                            onPressed: () => _inserisciTagNelController(_testoManualeCtl, '{scuola}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{argomento}'),
                            onPressed: () => _inserisciTagNelController(_testoManualeCtl, '{argomento}'),
                          ),
                        ],
                      ),
                      if (_manualIsPoll) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualOpt1Ctl,
                                decoration: const InputDecoration(labelText: 'Opzione 1 (Presenza)'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _manualOpt2Ctl,
                                decoration: const InputDecoration(labelText: 'Opzione 2 (Assenza)'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],

                    // Anteprima Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCF8C6).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.preview, size: 16, color: Colors.green),
                              SizedBox(width: 6),
                              Text('Anteprima:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _renderAnteprima(_usaTestoPredefinito ? _testoDaemonCtl.text : _testoManualeCtl.text),
                            style: const TextStyle(fontSize: 14, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton.icon(
                      icon: _sendingManual
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 22),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _sendingManual
                              ? 'Invio in corso a ${_selectedCorsoIds.length} corsi...'
                              : 'Invia Sondaggio a ${_selectedCorsoIds.length} Corsi',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (_sendingManual || _selectedCorsoIds.isEmpty) ? null : _inviaSondaggioManuale,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: CONFIGURAZIONE MESSAGGIO DI SOLLECITO
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabSollecito() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner info
              Card(
                color: Colors.amber.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.notification_important, color: Colors.amber.shade900, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configurazione Messaggio di Sollecito Risposta',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Questo messaggio viene utilizzato nella sezione Presenze quando clicchi sull\'icona WhatsApp '
                              'accanto a ciascun allievo o prospect per inviargli un sollecito individuale di conferma presenza.',
                              style: TextStyle(fontSize: 13, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD: TESTO E TEMPLATE SOLLECITO INDIVIDUALE
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          const Text('Modello Messaggio di Sollecito Risposta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 28),
                      const Text(
                        'Inserisci il messaggio predefinito. Come placeholder è disponibile il nome dell\'allievo o prospect (<nome_allievo>):',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testoSollecitoCtl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Es. Ciao <nome_allievo>, ci sei stasera al corso?",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Placeholder Tag cliccabile
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Placeholder nome allievo:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('<nome_allievo>'),
                            onPressed: () => _inserisciTagNelController(_testoSollecitoCtl, '<nome_allievo>'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{allievo}'),
                            onPressed: () => _inserisciTagNelController(_testoSollecitoCtl, '{allievo}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Anteprima Live Stile WhatsApp
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF8C6).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.chat, size: 16, color: Colors.green),
                                SizedBox(width: 6),
                                Text(
                                  'Anteprima WhatsApp (Esempio con allievo "Marco"):',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _testoSollecitoCtl.text
                                  .replaceAll('<nome_allievo>', 'Marco')
                                  .replaceAll('{nome_allievo}', 'Marco')
                                  .replaceAll('{allievo}', 'Marco')
                                  .replaceAll('{nome}', 'Marco')
                                  .replaceAll('<nome>', 'Marco'),
                              style: const TextStyle(fontSize: 14, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // BOTTONE SALVATAGGIO
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: _savingSollecito
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_savingSollecito ? 'Salvataggio...' : 'Salva Configurazione Sollecito'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _savingSollecito ? null : _salvaConfigurazioneSollecito,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _salvaConfigurazioneJolly() async {
    setState(() => _savingJolly = true);
    try {
      final res = await _api.saveDaemonConfig({
        'jolly_testo': _testoJollyCtl.text.trim(),
      });
      if (!mounted) return;
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione messaggio Jolly salvata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante il salvataggio della configurazione.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingJolly = false);
    }
  }

  Widget _buildTabJolly() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner info
              Card(
                color: Colors.amber.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade800, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Template Messaggio per i Jolly',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Imposta il messaggio predefinito proposto quando si contatta un allievo Jolly dalla sezione Anagrafica -> Jolly.\nLe informazioni dettagliate sulle lezioni (data, sede, livello) verranno automaticamente accodate al messaggio inviato via WhatsApp.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Card Configurazione
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Testo del Messaggio Predefinito',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inserisci il messaggio base da inviare agli allievi Jolly per chiedere la loro disponibilità:',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testoJollyCtl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Es. Ciao {nickname}! Abbiamo bisogno di un jolly stasera...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      // Placeholder Tag cliccabili
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Tag placeholder disponibili:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nickname}'),
                            tooltip: 'Inserisce il nickname del jolly (o il nome se non presente)',
                            onPressed: () => _inserisciTagNelController(_testoJollyCtl, '{nickname}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('<nickname>'),
                            tooltip: 'Inserisce il nickname del jolly (o il nome se non presente)',
                            onPressed: () => _inserisciTagNelController(_testoJollyCtl, '<nickname>'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Anteprima
                      const Text(
                        'Anteprima Messaggio WhatsApp (con esempio nickname "Alex")',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF8C6), // WhatsApp bubble green
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          '${_testoJollyCtl.text.trim().replaceAll("{nickname}", "Alex").replaceAll("<nickname>", "Alex")}\n\nLezioni in cui servono jolly:\n📅 24/10/2026 21:00 | Sede Centrale - Intermedio',
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          icon: _savingJolly
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(_savingJolly ? 'Salvataggio...' : 'Salva Configurazione Jolly'),
                          onPressed: _savingJolly ? null : _salvaConfigurazioneJolly,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
