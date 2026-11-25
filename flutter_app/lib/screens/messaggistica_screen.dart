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
  bool _savingSollecito = false;
  bool _savingJolly = false;
  bool _savingModuloTesseramento = false;
  bool _savingRicevuta = false;
  bool _savingIstruzioniPagamento = false;
  final TextEditingController _testoIstruzioniPagamentoCtl = TextEditingController(
    text: "Ciao {nickname}, per effettuare il pagamento della quota a favore di {nome_asd}, puoi effettuare un bonifico alle seguenti coordinate bancarie:\n\nIBAN: {iban}\nIntestato a: {nome_asd}\nCausale: Quota corso {nickname}\n\nGrazie e a presto! 💃🕺",
  );
  ConfigurazioneASD? _asdConfig;
  final TextEditingController _testoJollyCtl = TextEditingController(
    text: 'Ciao! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺',
  );
  final TextEditingController _testoModuloTesseramentoCtl = TextEditingController(
    text: "Gentile {nickname}, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all'ASD TantoTango da compilare e firmare. A presto!",
  );
  final TextEditingController _testoRicevutaCtl = TextEditingController(
    text: 'Gentile {nickname}, in allegato la ricevuta {numero} del {data} di € {importo} per "{causale}".',
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

  // Configurazione Sollecito
  bool _sollecitoAttivo = false;
  TimeOfDay _sollecitoTime = const TimeOfDay(hour: 16, minute: 0);
  final TextEditingController _testoSollecitoCtl = TextEditingController();
  bool _invioSollecitoManualeInCorso = false;

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
    _testoSollecitoCtl.dispose();
    _testoJollyCtl.dispose();
    _testoModuloTesseramentoCtl.dispose();
    _testoRicevutaCtl.dispose();
    _testoIstruzioniPagamentoCtl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      try {
        _asdConfig = await _api.getConfigurazioneASD();
      } catch (_) {}
      final config = await _api.getDaemonConfig();

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
            : "Ciao {nickname}, ci sei stasera al corso?";
        if (config.jollyTesto.isNotEmpty) {
          _testoJollyCtl.text = config.jollyTesto;
        }
        if (config.moduloTesseramentoTesto.isNotEmpty) {
          _testoModuloTesseramentoCtl.text = config.moduloTesseramentoTesto;
        }
        if (config.ricevutaTesto.isNotEmpty) {
          _testoRicevutaCtl.text = config.ricevutaTesto;
        }
        if (config.istruzioniPagamentoTesto.isNotEmpty) {
          _testoIstruzioniPagamentoCtl.text = config.istruzioniPagamentoTesto;
        }
      } else {
        _testoDaemonCtl.text =
            "Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c'è lezione per il corso {corso} alle {orario}.\n"
            "Chi di voi sarà presente stasera? Rispondete al sondaggio per confermare la vostra presenza!";
        _testoSollecitoCtl.text = "Ciao {nickname}, ci sei stasera al corso?";
        _testoJollyCtl.text = 'Ciao {nickname}! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺';
        _testoModuloTesseramentoCtl.text = "Gentile {nickname}, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all'ASD TantoTango da compilare e firmare. A presto!";
        _testoRicevutaCtl.text = 'Gentile {nickname}, in allegato la ricevuta {numero} del {data} di € {importo} per "{causale}".';
        _testoIstruzioniPagamentoCtl.text = "Ciao {nickname}, per effettuare il pagamento della quota a favore di {nome_asd}, puoi effettuare un bonifico alle seguenti coordinate bancarie:\n\nIBAN: {iban}\nIntestato a: {nome_asd}\nCausale: Quota corso {nickname}\n\nGrazie e a presto! 💃🕺";
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
      'sollecito_attivo': _sollecitoAttivo,
      'sollecito_orario': _formatTimeOfDay(_sollecitoTime),
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

  Future<void> _eseguiSollecitiMancataRispostaOra() async {
    final confermato = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notification_important, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conferma Invio Solleciti'),
          ],
        ),
        content: const Text(
          'Vuoi controllare le lezioni di oggi e inviare il messaggio di sollecito '
          'individuale su WhatsApp a tutti gli allievi di cui non è stata registrata '
          'una risposta (sia ASSENTE che PRESENTE)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade900,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Invia Ora'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confermato != true) return;

    setState(() => _invioSollecitoManualeInCorso = true);
    try {
      final res = await _api.inviaSollecitiMancataRispostaOra(force: true);
      if (mounted) {
        if (res['success'] == true) {
          final count = res['solleciti_inviati_totali'] ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Operazione completata: $count messaggi di sollecito inviati con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante l\'invio: ${res['error'] ?? res['message'] ?? 'Errore'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore di connessione: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _invioSollecitoManualeInCorso = false);
      }
    }
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
      initialIndex: widget.initialTab.clamp(0, 6),
      length: 7,
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
                icon: Icon(Icons.notification_important_outlined),
                text: 'Configurazione Messaggio di Sollecito',
              ),
              Tab(
                icon: Icon(Icons.star),
                text: 'Configurazione Messaggio Jolly',
              ),
              Tab(
                icon: Icon(Icons.assignment_outlined),
                text: 'Messaggio Modulo Tesseramento',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Messaggio Invio Ricevuta',
              ),
              Tab(
                icon: Icon(Icons.account_balance_outlined),
                text: 'Messaggio Istruzioni di Pagamento',
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
            _buildTabSollecito(),
            _buildTabJolly(),
            _buildTabModuloTesseramento(),
            _buildTabRicevuta(),
            _buildTabIstruzioniPagamento(),
            const WhatsAppScreen(embedded: true),
          ],
        ),
      ),
    );
  }

  Future<void> _salvaConfigurazioneIstruzioniPagamento() async {
    setState(() => _savingIstruzioniPagamento = true);
    try {
      final res = await _api.saveDaemonConfig({
        'istruzioni_pagamento_testo': _testoIstruzioniPagamentoCtl.text.trim(),
      });
      if (!mounted) return;
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione messaggio Istruzioni di Pagamento salvata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel salvataggio della configurazione.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore di connessione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingIstruzioniPagamento = false);
      }
    }
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
  // TAB 2: CONFIGURAZIONE MESSAGGIO DI SOLLECITO
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
                              'Se dopo l\'intervallo configurato dall\'invio del sondaggio ci sono allievi di cui non è stata '
                              'registrata una risposta (né ASSENTE né PRESENTE), il sistema invia loro automaticamente questo sollecito individuale.',
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

              // CARD 1: AUTOMAZIONE INVIO SOLLECITO PER MANCATA RISPOSTA
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
                          Icon(Icons.alarm, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          const Text(
                            'Automazione Sollecito Mancata Risposta',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // Switch Attivazione Sollecito Automatico
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Invio automatico sollecito per mancata risposta',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'Invia automaticamente un messaggio individuale su WhatsApp a tutti gli allievi del corso '
                          'che non hanno risposto al sondaggio all\'orario stabilito.',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: _sollecitoAttivo,
                        activeColor: Colors.amber.shade900,
                        onChanged: (val) => setState(() => _sollecitoAttivo = val),
                      ),
                      const SizedBox(height: 16),

                      // Configurazione Orario Invio Sollecito Mancata Risposta
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_outlined, color: Colors.blueGrey.shade700, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Orario di invio sollecito:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: BorderSide(color: Colors.grey.shade400),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: Icon(Icons.schedule, size: 18, color: Colors.amber.shade900),
                                  label: Text(
                                    _formatTimeOfDay(_sollecitoTime),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                  ),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _sollecitoTime,
                                    );
                                    if (picked != null) {
                                      setState(() => _sollecitoTime = picked);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All\'orario stabilito (${_formatTimeOfDay(_sollecitoTime)}), il sistema individuerà gli allievi della lezione odierna che non hanno ancora risposto (né presenza né assenza) e invierà loro il messaggio individuale.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                            ),
                          ],
                        ),
                      ),

                      // Bottone esegui ora
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber.shade900,
                            side: BorderSide(color: Colors.amber.shade800),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: _invioSollecitoManualeInCorso
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.outgoing_mail, size: 18),
                          label: Text(
                            _invioSollecitoManualeInCorso ? 'Invio in corso...' : 'Verifica e Invia Solleciti Ora (Oggi)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: _invioSollecitoManualeInCorso ? null : _eseguiSollecitiMancataRispostaOra,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 2: TESTO E TEMPLATE SOLLECITO INDIVIDUALE
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
                        'Inserisci il messaggio predefinito. Come placeholder è disponibile il nickname o nome dell\'allievo ({nickname}):',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testoSollecitoCtl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Es. Ciao {nickname}, ci sei stasera al corso?",
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
                          const Text('Tag rapidi:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nickname}'),
                            tooltip: 'Inserisce il nickname dell\'allievo (o il nome se non specificato)',
                            onPressed: () => _inserisciTagNelController(_testoSollecitoCtl, '{nickname}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('<nickname>'),
                            tooltip: 'Inserisce il nickname dell\'allievo (o il nome se non specificato)',
                            onPressed: () => _inserisciTagNelController(_testoSollecitoCtl, '<nickname>'),
                          ),
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
                                  .replaceAll('{nickname}', 'Marco')
                                  .replaceAll('<nickname>', 'Marco')
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
                              'Imposta il messaggio predefinito proposto quando si contatta un allievo Jolly dalla sezione Presenze -> Jolly.',
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
                          hintText: 'Es. Ciao {nickname}! Abbiamo bisogno di un jolly stasera alle {orario}...',
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
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{orario}'),
                            tooltip: "Inserisce l'orario del corso della lezione (es. 20:30)",
                            onPressed: () => _inserisciTagNelController(_testoJollyCtl, '{orario}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('<orario>'),
                            tooltip: "Inserisce l'orario del corso della lezione (es. 20:30)",
                            onPressed: () => _inserisciTagNelController(_testoJollyCtl, '<orario>'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Anteprima
                      const Text(
                        'Anteprima Messaggio WhatsApp (con esempio nickname "Alex" e orario "20:30")',
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
                          _testoJollyCtl.text
                              .trim()
                              .replaceAll('{nickname}', 'Alex')
                              .replaceAll('<nickname>', 'Alex')
                              .replaceAll('{orario}', '20:30')
                              .replaceAll('<orario>', '20:30'),
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

  // ─────────────────────────────────────────────────────────────
  // SALVATAGGIO MODULO TESSERAMENTO & RICEVUTA
  // ─────────────────────────────────────────────────────────────

  Future<void> _salvaConfigurazioneModuloTesseramento() async {
    setState(() => _savingModuloTesseramento = true);
    try {
      final res = await _api.saveDaemonConfig({
        'modulo_tesseramento_testo': _testoModuloTesseramentoCtl.text.trim(),
      });
      if (!mounted) return;
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione messaggio Modulo Tesseramento salvata con successo!'),
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
            content: Text('Errore salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingModuloTesseramento = false);
    }
  }

  Future<void> _salvaConfigurazioneRicevuta() async {
    setState(() => _savingRicevuta = true);
    try {
      final res = await _api.saveDaemonConfig({
        'ricevuta_testo': _testoRicevutaCtl.text.trim(),
      });
      if (!mounted) return;
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione messaggio Invio Ricevuta salvata con successo!'),
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
            content: Text('Errore salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRicevuta = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 5: MESSAGGIO MODULO TESSERAMENTO
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabModuloTesseramento() {
    final previewText = _testoModuloTesseramentoCtl.text
        .replaceAll('{nickname}', 'Marco')
        .replaceAll('<nickname>', 'Marco')
        .replaceAll('{nome}', 'Marco')
        .replaceAll('{cognome}', 'Marchesi')
        .replaceAll('{nome_completo}', 'Marco Marchesi');

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
                color: Colors.teal.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.teal.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, color: Colors.teal.shade800, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Template Messaggio Modulo Tesseramento',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Imposta il messaggio WhatsApp predefinito inviato all\'allievo come testo di accompagnamento quando si invia il modulo di tesseramento in PDF.',
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
                        'Personalizza il messaggio. I placeholder inseriti verranno automaticamente sostituiti con i dati dell\'allievo prima dell\'invio:',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testoModuloTesseramentoCtl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Es. Gentile {nickname}, in allegato ti inviamo il modulo...',
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
                          const Text('Tag disponibili:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nickname}'),
                            tooltip: 'Inserisce il nickname dell\'allievo (o il nome se non presente)',
                            onPressed: () => _inserisciTagNelController(_testoModuloTesseramentoCtl, '{nickname}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nome}'),
                            tooltip: 'Inserisce il nome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoModuloTesseramentoCtl, '{nome}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{cognome}'),
                            tooltip: 'Inserisce il cognome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoModuloTesseramentoCtl, '{cognome}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nome_completo}'),
                            tooltip: 'Inserisce nome e cognome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoModuloTesseramentoCtl, '{nome_completo}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Anteprima
                      const Text(
                        'Anteprima Messaggio WhatsApp (esempio con Marco Marchesi):',
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
                          previewText,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Ripristina Predefinito'),
                            onPressed: () {
                              setState(() {
                                _testoModuloTesseramentoCtl.text =
                                    "Gentile {nickname}, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all'ASD TantoTango da compilare e firmare. A presto!";
                              });
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            icon: _savingModuloTesseramento
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_savingModuloTesseramento ? 'Salvataggio...' : 'Salva Configurazione Modulo'),
                            onPressed: _savingModuloTesseramento ? null : _salvaConfigurazioneModuloTesseramento,
                          ),
                        ],
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

  // ─────────────────────────────────────────────────────────────
  // TAB 6: MESSAGGIO INVIO RICEVUTA
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabRicevuta() {
    final previewText = _testoRicevutaCtl.text
        .replaceAll('{nickname}', 'Marco')
        .replaceAll('<nickname>', 'Marco')
        .replaceAll('{nome}', 'Marco')
        .replaceAll('{cognome}', 'Marchesi')
        .replaceAll('{nome_completo}', 'Marco Marchesi')
        .replaceAll('{numero}', 'N. 12/2026')
        .replaceAll('{data}', '29/10/2026')
        .replaceAll('{importo}', '150.00')
        .replaceAll('{causale}', 'Quota Corso Autunno')
        .replaceAll('{intestatario}', 'Marco Marchesi');

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
                color: Colors.indigo.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.indigo.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, color: Colors.indigo.shade800, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Template Messaggio Invio Ricevuta',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Imposta il messaggio WhatsApp predefinito inviato come accompagnamento quando si inoltra una ricevuta di pagamento in PDF.',
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
                        'Personalizza il messaggio. I placeholder inseriti verranno automaticamente sostituiti con i dati dell\'allievo e della ricevuta prima dell\'invio:',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _testoRicevutaCtl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Es. Gentile {nickname}, in allegato la ricevuta {numero}...',
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
                          const Text('Tag disponibili:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nickname}'),
                            tooltip: 'Inserisce il nickname dell\'allievo (o intestatario)',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{nickname}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{numero}'),
                            tooltip: 'Inserisce il numero ricevuta (es. N. 12/2026)',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{numero}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{data}'),
                            tooltip: 'Inserisce la data della ricevuta',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{data}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{importo}'),
                            tooltip: 'Inserisce l\'importo (es. 150.00)',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{importo}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{causale}'),
                            tooltip: 'Inserisce la causale della ricevuta',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{causale}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nome}'),
                            tooltip: 'Inserisce il nome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{nome}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{cognome}'),
                            tooltip: 'Inserisce il cognome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{cognome}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nome_completo}'),
                            tooltip: 'Inserisce nome e cognome / intestatario',
                            onPressed: () => _inserisciTagNelController(_testoRicevutaCtl, '{nome_completo}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Anteprima
                      const Text(
                        'Anteprima Messaggio WhatsApp (esempio con ricevuta N. 12/2026):',
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
                          previewText,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Ripristina Predefinito'),
                            onPressed: () {
                              setState(() {
                                _testoRicevutaCtl.text =
                                    'Gentile {nickname}, in allegato la ricevuta {numero} del {data} di € {importo} per "{causale}".';
                              });
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            icon: _savingRicevuta
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_savingRicevuta ? 'Salvataggio...' : 'Salva Configurazione Ricevuta'),
                            onPressed: _savingRicevuta ? null : _salvaConfigurazioneRicevuta,
                          ),
                        ],
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

  // ─────────────────────────────────────────────────────────────
  // TAB 7: MESSAGGIO ISTRUZIONI DI PAGAMENTO
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabIstruzioniPagamento() {
    final asdIban = (_asdConfig?.iban != null && _asdConfig!.iban.trim().isNotEmpty)
        ? _asdConfig!.iban.trim()
        : '';
    final asdNome = (_asdConfig?.nome != null && _asdConfig!.nome.trim().isNotEmpty)
        ? _asdConfig!.nome.trim()
        : 'ASD TantoTango';

    final previewIban = asdIban.isNotEmpty ? asdIban : 'IT00X0000000000000000000000';

    final previewText = _testoIstruzioniPagamentoCtl.text
        .replaceAll('{iban}', previewIban)
        .replaceAll('<iban>', previewIban)
        .replaceAll('{nome_asd}', asdNome)
        .replaceAll('<nome_asd>', asdNome)
        .replaceAll('{nickname}', 'Marco')
        .replaceAll('<nickname>', 'Marco')
        .replaceAll('{nome}', 'Marco')
        .replaceAll('{cognome}', 'Marchesi')
        .replaceAll('{nome_completo}', 'Marco Marchesi');

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.account_balance_outlined, color: Colors.teal.shade700, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configurazione Messaggio Istruzioni di Pagamento',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Personalizza il messaggio WhatsApp inviato agli allievi con le coordinate bancarie (IBAN) e il nome dell\'ASD per il bonifico.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (asdIban.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Nota: L\'IBAN dell\'ASD non è ancora stato configurato. Vai nella sezione Anagrafica -> ASD per inserirlo: verrà sostituito automaticamente al tag {iban}.',
                                  style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Testo del messaggio WhatsApp:',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _testoIstruzioniPagamentoCtl,
                        maxLines: 8,
                        minLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Inserisci il testo per le istruzioni di pagamento...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tag chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Tag disponibili:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ActionChip(
                            avatar: const Icon(Icons.account_balance, size: 14),
                            label: const Text('{iban}'),
                            tooltip: 'Inserisce l\'IBAN del conto corrente dell\'ASD',
                            backgroundColor: Colors.teal.shade50,
                            labelStyle: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                            onPressed: () => _inserisciTagNelController(_testoIstruzioniPagamentoCtl, '{iban}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.business, size: 14),
                            label: const Text('{nome_asd}'),
                            tooltip: 'Inserisce il nome ufficiale dell\'ASD',
                            backgroundColor: Colors.teal.shade50,
                            labelStyle: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                            onPressed: () => _inserisciTagNelController(_testoIstruzioniPagamentoCtl, '{nome_asd}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nickname}'),
                            tooltip: 'Inserisce il nickname dell\'allievo (o Nome se assente)',
                            onPressed: () => _inserisciTagNelController(_testoIstruzioniPagamentoCtl, '{nickname}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nome}'),
                            tooltip: 'Inserisce il nome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoIstruzioniPagamentoCtl, '{nome}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{cognome}'),
                            tooltip: 'Inserisce il cognome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoIstruzioniPagamentoCtl, '{cognome}'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('{nome_completo}'),
                            tooltip: 'Inserisce nome e cognome dell\'allievo',
                            onPressed: () => _inserisciTagNelController(_testoIstruzioniPagamentoCtl, '{nome_completo}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Anteprima
                      const Text(
                        'Anteprima Messaggio WhatsApp (esempio pratico):',
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
                          previewText,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Ripristina Predefinito'),
                            onPressed: () {
                              setState(() {
                                _testoIstruzioniPagamentoCtl.text =
                                    "Ciao {nickname}, per effettuare il pagamento della quota a favore di {nome_asd}, puoi effettuare un bonifico alle seguenti coordinate bancarie:\n\nIBAN: {iban}\nIntestato a: {nome_asd}\nCausale: Quota corso {nickname}\n\nGrazie e a presto! 💃🕺";
                              });
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            icon: _savingIstruzioniPagamento
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_savingIstruzioniPagamento ? 'Salvataggio...' : 'Salva Configurazione Istruzioni Pagamento'),
                            onPressed: _savingIstruzioniPagamento ? null : _salvaConfigurazioneIstruzioniPagamento,
                          ),
                        ],
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