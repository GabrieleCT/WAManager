import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SondaggioMattutinoScreen extends StatefulWidget {
  const SondaggioMattutinoScreen({super.key});

  @override
  State<SondaggioMattutinoScreen> createState() => _SondaggioMattutinoScreenState();
}

class _SondaggioMattutinoScreenState extends State<SondaggioMattutinoScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _savingDaemon = false;
  bool _executingDaemon = false;
  bool _sendingManual = false;

  // Configurazione Demone
  TimeOfDay _daemonTime = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedDays = {0, 1, 2, 3, 4, 5, 6}; // 0=Lun, 6=Dom
  final TextEditingController _testoDaemonCtl = TextEditingController();
  final TextEditingController _pollOpt1Ctl = TextEditingController(text: 'Ci sono! 🕺💃');
  final TextEditingController _pollOpt2Ctl = TextEditingController(text: 'Non ci sono 🚫');
  bool _isPoll = true;
  bool _daemonActive = true;

  // Invio Manuale
  List<Corso> _corsi = [];
  final Set<String> _selectedCorsoIds = {};
  String _filtroRicerca = '';
  bool _usaTestoPredefinito = true;
  final TextEditingController _testoManualeCtl = TextEditingController();
  bool _manualIsPoll = true;
  final TextEditingController _manualOpt1Ctl = TextEditingController(text: 'Ci sono! 🕺💃');
  final TextEditingController _manualOpt2Ctl = TextEditingController(text: 'Non ci sono 🚫');

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
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final config = await _api.getDaemonConfig();
      final corsi = await _api.getCorsi();

      if (config != null) {
        // Parsing orario HH:MM
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
        _daemonActive = config.isActive;

        if (_testoManualeCtl.text.isEmpty) {
          _testoManualeCtl.text = config.testo;
        }
      }

      setState(() {
        _corsi = corsi;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento dati: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _daemonTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _daemonTime = picked);
    }
  }

  void _insertTagIntoController(TextEditingController controller, String tag) {
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
      'is_active': _daemonActive,
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
          'Se per oggi ci sono lezioni previste, il sondaggio verrà inviato ai rispettivi gruppi WhatsApp dei corsi.\n'
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

  Future<void> _inviaSondaggioManuale() async {
    if (_selectedCorsoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un corso a cui inviare il sondaggio.')),
      );
      return;
    }

    final testo = _usaTestoPredefinito ? _testoDaemonCtl.text : _testoManualeCtl.text;
    if (testo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il testo del sondaggio non può essere vuoto.')),
      );
      return;
    }

    final isPoll = _usaTestoPredefinito ? _isPoll : _manualIsPoll;
    final opzioni = isPoll
        ? (_usaTestoPredefinito
            ? [_pollOpt1Ctl.text.trim(), _pollOpt2Ctl.text.trim()]
            : [_manualOpt1Ctl.text.trim(), _manualOpt2Ctl.text.trim()])
        : null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Invio Manuale'),
        content: Text(
          'Stai per inviare ${isPoll ? "un sondaggio" : "un messaggio"} WhatsApp a ${_selectedCorsoIds.length} corso/i selezionato/i.\n'
          'Confermi l\'invio immediato?',
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
      testo: testo,
      isPoll: isPoll,
      pollOpzioni: opzioni,
    );
    setState(() => _sendingManual = false);

    if (!mounted) return;

    if (res['success'] == true) {
      final int inviati = res['inviati_con_successo'] ?? 0;
      final int totale = res['totale_corsi'] ?? 0;
      final List dettagli = res['dettagli'] ?? [];

      _mostraDialogEsitiInvio(inviati, totale, dettagli);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore invio: ${res['error'] ?? "Impossibile completare invio"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostraDialogEsitiInvio(int inviati, int totale, List dettagli) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              inviati == totale ? Icons.check_circle : Icons.warning_amber_rounded,
              color: inviati == totale ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text('Esito Invio: $inviati / $totale riusciti'),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inviati == totale
                    ? 'Tutti i messaggi sono stati inviati con successo ai gruppi WhatsApp!'
                    : 'Alcuni corsi non hanno potuto ricevere il messaggio. Verifica i dettagli qui sotto:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
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
                        '${item['scuola_nome'].isNotEmpty ? "${item['scuola_nome']} - " : ""}${item['corso_nome']}',
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestione Sondaggi WhatsApp'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.schedule_send),
                text: 'Configurazione Demone Automatico',
              ),
              Tab(
                icon: Icon(Icons.send_rounded),
                text: 'Invio Manuale Sondaggio',
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
                              'Nei giorni selezionati, all\'orario stabilito (${_formatTimeOfDay(_daemonTime)}), il sistema '
                              'cerca in automatico i corsi che hanno una lezione in giornata e invia il sondaggio o messaggio '
                              'al rispettivo gruppo WhatsApp.',
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
                      const Divider(height: 28),

                      // Orario
                      Row(
                        children: [
                          const Text(
                            'Orario di esecuzione:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _formatTimeOfDay(_daemonTime),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _selectTime,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '(Clicca per modificare)',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Giorni settimana
                      const Text(
                        'Giorni della settimana abilitati:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
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
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.indigo.shade900 : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDays.add(index);
                                } else {
                                  _selectedDays.remove(index);
                                }
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _selectedDays.addAll([0, 1, 2, 3, 4, 5, 6])),
                            child: const Text('Seleziona tutti'),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedDays.clear();
                              _selectedDays.addAll([0, 1, 2, 3, 4]); // Lun-Ven
                            }),
                            child: const Text('Solo feriali (Lun-Ven)'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedDays.clear()),
                            child: const Text('Deseleziona tutti', style: TextStyle(color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 2: TESTO E FORMATO SONDAGGIO
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
                          Icon(Icons.chat_bubble_outline, color: Colors.teal),
                          SizedBox(width: 8),
                          Text(
                            'Formato e Testo del Sondaggio',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // Tipo: Poll vs Text
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Invia come Sondaggio WhatsApp nativo (interattivo con pulsanti)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Se disattivato, verrà inviato come un normale messaggio testuale.',
                        ),
                        value: _isPoll,
                        activeThumbColor: Colors.teal,
                        onChanged: (v) => setState(() => _isPoll = v),
                      ),
                      if (_isPoll) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _pollOpt1Ctl,
                                decoration: const InputDecoration(
                                  labelText: 'Opzione 1 (Presenza confermata)',
                                  prefixIcon: Icon(Icons.thumb_up, color: Colors.green),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _pollOpt2Ctl,
                                decoration: const InputDecoration(
                                  labelText: 'Opzione 2 (Assenza)',
                                  prefixIcon: Icon(Icons.thumb_down, color: Colors.red),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Testo personalizzabile
                      const Text(
                        'Testo del messaggio personalizzabile:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _testoDaemonCtl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Inserisci il messaggio...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),

                      // Chips per inserimento tag
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Tag dinamici:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          ...['{corso}', '{orario}', '{data}', '{scuola}', '{argomento}'].map((tag) {
                            return ActionChip(
                              avatar: const Icon(Icons.add, size: 14),
                              label: Text(tag, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                _insertTagIntoController(_testoDaemonCtl, tag);
                                setState(() {});
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Anteprima messaggio
                      const Text(
                        'Anteprima Messaggio:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCF8C6), // WhatsApp chat bubble green
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _renderAnteprima(_testoDaemonCtl.text),
                              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                            ),
                            if (_isPoll) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('📊 Sondaggio WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    OutlinedButton(
                                      onPressed: null,
                                      child: Text('🔘 ${_pollOpt1Ctl.text}'),
                                    ),
                                    const SizedBox(height: 4),
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
    // Filtro corsi
    final query = _filtroRicerca.toLowerCase().trim();
    final corsiFiltrati = _corsi.where((c) {
      if (query.isEmpty) return true;
      final nomeScuola = c.scuolaNome.toLowerCase();
      final nomeCorso = '${c.livelloDisplay} ${c.giornoSettimanaDisplay}'.toLowerCase();
      return nomeScuola.contains(query) || nomeCorso.contains(query);
    }).toList();

    final bool isAllFilteredSelected = corsiFiltrati.isNotEmpty &&
        corsiFiltrati.every((c) => _selectedCorsoIds.contains(c.id));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // COLONNA SINISTRA: SELEZIONE CORSI
        Expanded(
          flex: 5,
          child: Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.class_, color: Colors.indigo),
                      const SizedBox(width: 8),
                      const Text(
                        'Seleziona Corsi Target',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          '${_selectedCorsoIds.length} selezionati',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        backgroundColor: _selectedCorsoIds.isNotEmpty ? Colors.indigo : Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Barra ricerca e bottoni selezione rapida
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cerca per nome scuola o corso...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _filtroRicerca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _filtroRicerca = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _filtroRicerca = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: Icon(isAllFilteredSelected ? Icons.deselect : Icons.select_all, size: 18),
                        label: Text(isAllFilteredSelected ? 'Deseleziona visibili' : 'Seleziona visibili'),
                        onPressed: () {
                          setState(() {
                            if (isAllFilteredSelected) {
                              for (final c in corsiFiltrati) {
                                _selectedCorsoIds.remove(c.id);
                              }
                            } else {
                              for (final c in corsiFiltrati) {
                                _selectedCorsoIds.add(c.id);
                              }
                            }
                          });
                        },
                      ),
                      const Spacer(),
                      if (_selectedCorsoIds.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _selectedCorsoIds.clear()),
                          child: const Text('Deseleziona tutti', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                  const Divider(height: 16),

                  // LISTA DEI CORSI
                  Expanded(
                    child: corsiFiltrati.isEmpty
                        ? const Center(
                            child: Text(
                              'Nessun corso corrispondente trovato.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: corsiFiltrati.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final corso = corsiFiltrati[i];
                              final isSelected = _selectedCorsoIds.contains(corso.id);
                              final bool hasGroup = corso.gruppoWhatsapp.isNotEmpty;

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: Colors.indigo,
                                onChanged: (bool? val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedCorsoIds.add(corso.id);
                                    } else {
                                      _selectedCorsoIds.remove(corso.id);
                                    }
                                  });
                                },
                                title: Text(
                                  '${corso.scuolaNome} - ${corso.livelloDisplay}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      '${corso.giornoSettimanaDisplay} ${corso.orario}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(width: 8),
                                    if (hasGroup)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.groups, size: 12, color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Gruppo WA presente',
                                              style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning, size: 12, color: Colors.orange.shade800),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Gruppo corso vuoto (userà gruppo scuola se presente)',
                                              style: TextStyle(fontSize: 10, color: Colors.orange.shade900),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // COLONNA DESTRA: TESTO E PULSANTE INVIO
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text(
                          'Contenuto da Inviare',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Switch usa testo predefinito
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _usaTestoPredefinito,
                      title: const Text('Usa testo e formato predefiniti del Demone'),
                      subtitle: const Text('Utilizza il messaggio configurato nella scheda principale'),
                      onChanged: (v) => setState(() => _usaTestoPredefinito = v ?? true),
                    ),
                    const SizedBox(height: 12),

                    if (!_usaTestoPredefinito) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Invia come Sondaggio WhatsApp'),
                        subtitle: const Text('Crea sondaggio nativo a risposta rapida'),
                        value: _manualIsPoll,
                        activeThumbColor: Colors.teal,
                        onChanged: (v) => setState(() => _manualIsPoll = v),
                      ),
                      if (_manualIsPoll) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _manualOpt1Ctl,
                          decoration: const InputDecoration(
                            labelText: 'Opzione 1 (Presenza)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _manualOpt2Ctl,
                          decoration: const InputDecoration(
                            labelText: 'Opzione 2 (Assenza)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Testo personalizzato per questo invio:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _testoManualeCtl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Inserisci il messaggio personalizzato...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: ['{corso}', '{orario}', '{data}', '{scuola}'].map((tag) {
                          return ActionChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              _insertTagIntoController(_testoManualeCtl, tag);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Anteprima del messaggio:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCF8C6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _renderAnteprima(_usaTestoPredefinito ? _testoDaemonCtl.text : _testoManualeCtl.text),
                        style: const TextStyle(fontSize: 13, height: 1.3),
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
}
