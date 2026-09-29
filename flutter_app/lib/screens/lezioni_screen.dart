import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'presenze_screen.dart';

class LezioniScreen extends StatefulWidget {
  const LezioniScreen({super.key});

  @override
  State<LezioniScreen> createState() => _LezioniScreenState();
}

class _LezioniScreenState extends State<LezioniScreen> {
  final ApiService _api = ApiService();
  List<Lezione> _lezioni = [];
  List<Corso> _corsi = [];
  List<Scuola> _scuole = [];
  List<Argomento> _argomenti = [];
  bool _loading = true;
  String? _filterScuolaId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final lezioni = await _api.getLezioni();
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    final argomenti = await _api.getArgomenti();
    if (mounted) {
      setState(() {
        _lezioni = lezioni;
        _corsi = corsi;
        _scuole = scuole;
        _argomenti = argomenti;
        _loading = false;
      });
    }
  }

  String _giornoItaliano(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunedì';
      case DateTime.tuesday:
        return 'Martedì';
      case DateTime.wednesday:
        return 'Mercoledì';
      case DateTime.thursday:
        return 'Giovedì';
      case DateTime.friday:
        return 'Venerdì';
      case DateTime.saturday:
        return 'Sabato';
      case DateTime.sunday:
        return 'Domenica';
      default:
        return '';
    }
  }

  int _giornoStringToInt(String g) {
    final u = g.toUpperCase();
    if (u.contains('LUN')) return DateTime.monday;
    if (u.contains('MAR')) return DateTime.tuesday;
    if (u.contains('MER')) return DateTime.wednesday;
    if (u.contains('GIO')) return DateTime.thursday;
    if (u.contains('VEN')) return DateTime.friday;
    if (u.contains('SAB')) return DateTime.saturday;
    if (u.contains('DOM')) return DateTime.sunday;
    return DateTime.monday;
  }

  DateTime _prossimoGiorno(int targetWeekday) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int diff = targetWeekday - today.weekday;
    if (diff < 0) diff += 7;
    return today.add(Duration(days: diff));
  }

  // ─── DIALOG NUOVA LEZIONE SINGOLA ─────────────────────────────
  void _showAddLezioneDialog() {
    String? selectedCorsoId = _corsi.isNotEmpty ? _corsi.first.id : null;
    String? selectedArgomentoId;
    DateTime selectedDate = DateTime.now();
    final titoloCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Nuova Lezione'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCorsoId,
                  decoration: const InputDecoration(labelText: 'Corso *'),
                  items: _corsi.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.orario})'));
                  }).toList(),
                  onChanged: (v) => setDlgState(() => selectedCorsoId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titoloCtl,
                  decoration: const InputDecoration(
                    labelText: 'Titolo / Nomenclatura (opzionale)',
                    hintText: 'Es. 1/12 - 1° Trimestre o Lezione di Recupero',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data: ${DateFormat('dd/MM/yyyy').format(selectedDate)} (${_giornoItaliano(selectedDate.weekday)})'),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedArgomentoId,
                  decoration: const InputDecoration(labelText: 'Argomento trattato (opzionale)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-- Nessun argomento --')),
                    ..._argomenti.map((a) => DropdownMenuItem(value: a.id, child: Text(a.titolo))),
                  ],
                  onChanged: (v) => setDlgState(() => selectedArgomentoId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCorsoId == null) return;
                final data = {
                  'corso': selectedCorsoId,
                  'data': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'titolo': titoloCtl.text.trim(),
                  'argomento': selectedArgomentoId,
                };
                await _api.createLezione(data);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              child: const Text('Salva Lezione'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── WIZARD AGGIUNGI TRIMESTRE ────────────────────────────────
  void _showAddTrimestreWizard() {
    if (_corsi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attenzione: devi prima creare almeno un Corso.')),
      );
      return;
    }

    int currentStep = 0;
    String selectedCorsoId = _corsi.first.id;
    Corso selectedCorso = _corsi.first;

    String selectedGiorno = selectedCorso.giornoSettimana;
    final orarioCtl = TextEditingController(text: selectedCorso.orario);
    DateTime selectedDataInizio = _prossimoGiorno(_giornoStringToInt(selectedGiorno));
    String selectedTrimestre = '1° Trimestre';
    int numeroLezioni = 12;

    List<DateTime> dateProposte = [];
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setWizState) {
          final dialogWidth = MediaQuery.of(ctx).size.width > 750 ? 700.0 : MediaQuery.of(ctx).size.width * 0.95;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: dialogWidth,
              constraints: const BoxConstraints(maxHeight: 680),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // INTESTAZIONE WIZARD
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.date_range, color: Colors.deepPurple, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aggiungi Trimestre Lezioni',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              currentStep == 0
                                  ? 'Step 1/2: Parametri del corso e orari'
                                  : 'Step 2/2: Revisione calendario e date lezioni',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // CONTENUTO STEP
                  Expanded(
                    child: currentStep == 0
                        ? _buildWizardStep1(
                            setWizState: setWizState,
                            selectedCorsoId: selectedCorsoId,
                            selectedCorso: selectedCorso,
                            selectedGiorno: selectedGiorno,
                            orarioCtl: orarioCtl,
                            selectedDataInizio: selectedDataInizio,
                            selectedTrimestre: selectedTrimestre,
                            numeroLezioni: numeroLezioni,
                            onCorsoChanged: (newId) {
                              final found = _corsi.firstWhere((c) => c.id == newId);
                              setWizState(() {
                                selectedCorsoId = newId;
                                selectedCorso = found;
                                selectedGiorno = found.giornoSettimana;
                                orarioCtl.text = found.orario;
                                selectedDataInizio = _prossimoGiorno(_giornoStringToInt(selectedGiorno));
                              });
                            },
                            onGiornoChanged: (newGiorno) {
                              setWizState(() {
                                selectedGiorno = newGiorno;
                                selectedDataInizio = _prossimoGiorno(_giornoStringToInt(newGiorno));
                              });
                            },
                            onDataInizioChanged: (picked) {
                              setWizState(() => selectedDataInizio = picked);
                            },
                            onTrimestreChanged: (t) {
                              setWizState(() => selectedTrimestre = t);
                            },
                            onNumeroLezioniChanged: (n) {
                              setWizState(() => numeroLezioni = n);
                            },
                          )
                        : _buildWizardStep2(
                            setWizState: setWizState,
                            context: ctx,
                            selectedCorso: selectedCorso,
                            selectedTrimestre: selectedTrimestre,
                            selectedGiorno: selectedGiorno,
                            orario: orarioCtl.text,
                            dateProposte: dateProposte,
                          ),
                  ),

                  const Divider(height: 20),

                  // AZIONI FOOTER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (currentStep == 1)
                        OutlinedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () {
                                  setWizState(() => currentStep = 0);
                                },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Indietro'),
                        )
                      else
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          child: const Text('Annulla'),
                        ),
                      if (currentStep == 0)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Avanti: Genera Calendario'),
                          onPressed: () {
                            dateProposte.clear();
                            DateTime d = DateTime(selectedDataInizio.year, selectedDataInizio.month, selectedDataInizio.day);
                            for (int i = 0; i < numeroLezioni; i++) {
                              dateProposte.add(d);
                              d = d.add(const Duration(days: 7));
                            }
                            setWizState(() => currentStep = 1);
                          },
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle),
                          label: Text(isSaving ? 'Salvataggio in corso...' : 'Conferma e Salva (${dateProposte.length} Lezioni)'),
                          onPressed: isSaving || dateProposte.isEmpty
                              ? null
                              : () async {
                                  setWizState(() => isSaving = true);
                                  try {
                                    dateProposte.sort((a, b) => a.compareTo(b));
                                    final totalCount = dateProposte.length;
                                    final lezioniPayload = [
                                      for (int i = 0; i < totalCount; i++)
                                        {
                                          'data': DateFormat('yyyy-MM-dd').format(dateProposte[i]),
                                          'titolo': '${i + 1}/$totalCount - $selectedTrimestre',
                                        }
                                    ];

                                    final res = await _api.creaTrimestre(selectedCorsoId, lezioniPayload);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.green.shade800,
                                          content: Text(
                                            '${res.length} lezioni create con successo per il $selectedTrimestre!',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    }
                                    _loadAll();
                                  } catch (err) {
                                    if (ctx.mounted) {
                                      setWizState(() => isSaving = false);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.red.shade800,
                                          content: Text('Errore durante il salvataggio: $err'),
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // WIZARD STEP 1: PARAMETRI
  Widget _buildWizardStep1({
    required void Function(void Function()) setWizState,
    required String selectedCorsoId,
    required Corso selectedCorso,
    required String selectedGiorno,
    required TextEditingController orarioCtl,
    required DateTime selectedDataInizio,
    required String selectedTrimestre,
    required int numeroLezioni,
    required ValueChanged<String> onCorsoChanged,
    required ValueChanged<String> onGiornoChanged,
    required ValueChanged<DateTime> onDataInizioChanged,
    required ValueChanged<String> onTrimestreChanged,
    required ValueChanged<int> onNumeroLezioniChanged,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SELEZIONE CORSO
          DropdownButtonFormField<String>(
            initialValue: selectedCorsoId,
            decoration: const InputDecoration(
              labelText: 'Corso di riferimento *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.school),
            ),
            items: _corsi.map((c) {
              return DropdownMenuItem(
                value: c.id,
                child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.giornoSettimanaDisplay} ore ${c.orario})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) onCorsoChanged(val);
            },
          ),
          const SizedBox(height: 16),

          // TRIMESTRE & NUMERO LEZIONI
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedTrimestre,
                  decoration: const InputDecoration(
                    labelText: 'Trimestre *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bookmark_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: '1° Trimestre', child: Text('1° Trimestre')),
                    DropdownMenuItem(value: '2° Trimestre', child: Text('2° Trimestre')),
                    DropdownMenuItem(value: '3° Trimestre', child: Text('3° Trimestre')),
                    DropdownMenuItem(value: '4° Trimestre', child: Text('4° Trimestre')),
                  ],
                  onChanged: (val) {
                    if (val != null) onTrimestreChanged(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: numeroLezioni.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'N° Lezioni *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  onChanged: (val) {
                    final n = int.tryParse(val.trim());
                    if (n != null && n > 0) {
                      onNumeroLezioniChanged(n);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GIORNO DELLA SETTIMANA & ORARIO
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedGiorno,
                  decoration: const InputDecoration(
                    labelText: 'Giorno della settimana *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_view_day),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'LUNEDI', child: Text('Lunedì')),
                    DropdownMenuItem(value: 'MARTEDI', child: Text('Martedì')),
                    DropdownMenuItem(value: 'MERCOLEDI', child: Text('Mercoledì')),
                    DropdownMenuItem(value: 'GIOVEDI', child: Text('Giovedì')),
                    DropdownMenuItem(value: 'VENERDI', child: Text('Venerdì')),
                    DropdownMenuItem(value: 'SABATO', child: Text('Sabato')),
                    DropdownMenuItem(value: 'DOMENICA', child: Text('Domenica')),
                  ],
                  onChanged: (val) {
                    if (val != null) onGiornoChanged(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: orarioCtl,
                  decoration: const InputDecoration(
                    labelText: 'Orario (HH:MM) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // DATA DI INIZIO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Data di inizio lezioni *', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(selectedDataInizio)} (${_giornoItaliano(selectedDataInizio.weekday)})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Modifica'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDataInizio,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      onDataInizioChanged(picked);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // INFORMAZIONE PREVENTIVA
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nel prossimo step verrà generato il calendario provvisorio di $numeroLezioni date settimanali. Potrai rimuovere festività o aggiungere date extra prima di confermare.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIZARD STEP 2: CALENDARIO E REVISIONE DATE
  Widget _buildWizardStep2({
    required void Function(void Function()) setWizState,
    required BuildContext context,
    required Corso selectedCorso,
    required String selectedTrimestre,
    required String selectedGiorno,
    required String orario,
    required List<DateTime> dateProposte,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RIEPILOGO PARAMETRI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${selectedCorso.scuolaNome} • ${selectedCorso.livelloDisplay} • $selectedTrimestre • $selectedGiorno ore $orario',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Aggiungi Data'),
                onPressed: () async {
                  final initial = dateProposte.isNotEmpty ? dateProposte.last.add(const Duration(days: 7)) : DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    final normalized = DateTime(picked.year, picked.month, picked.day);
                    if (!dateProposte.any((d) => d.year == normalized.year && d.month == normalized.month && d.day == normalized.day)) {
                      setWizState(() {
                        dateProposte.add(normalized);
                        dateProposte.sort((a, b) => a.compareTo(b));
                      });
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Questa data è già presente nella lista.')),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Date previste (${dateProposte.length} totali):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              'Naming: 1/${dateProposte.length} - $selectedTrimestre',
              style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // LISTA DATE
        Expanded(
          child: dateProposte.isEmpty
              ? const Center(
                  child: Text('Nessuna data configurata. Clicca "+ Aggiungi Data" per inserirne una.'),
                )
              : ListView.separated(
                  itemCount: dateProposte.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final d = dateProposte[i];
                    final numLez = i + 1;
                    final total = dateProposte.length;
                    final titoloCalcolato = '$numLez/$total - $selectedTrimestre';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.deepPurple.shade200),
                            ),
                            child: Text(
                              '$numLez/$total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.deepPurple.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titoloCalcolato,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '${_giornoItaliano(d.weekday)} ${DateFormat('dd/MM/yyyy').format(d)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_calendar, size: 20, color: Colors.indigo),
                            tooltip: 'Modifica questa data',
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: d,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                final normalized = DateTime(picked.year, picked.month, picked.day);
                                setWizState(() {
                                  dateProposte[i] = normalized;
                                  dateProposte.sort((a, b) => a.compareTo(b));
                                });
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            tooltip: 'Rimuovi data (es. festività)',
                            onPressed: () {
                              setWizState(() {
                                dateProposte.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLezioni = _filterScuolaId == null ? _lezioni : _lezioni.where((l) => l.scuolaId == _filterScuolaId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultazione Lezioni'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              elevation: 1,
            ),
            icon: const Icon(Icons.date_range, size: 18),
            label: const Text('Aggiungi Trimestre'),
            onPressed: _showAddTrimestreWizard,
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Ricarica', onPressed: _loadAll),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fabTrimestre',
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Aggiungi Trimestre'),
            onPressed: _showAddTrimestreWizard,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fabLezione',
            icon: const Icon(Icons.add),
            label: const Text('Singola Lezione'),
            onPressed: _showAddLezioneDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String?>(
              initialValue: _filterScuolaId,
              decoration: InputDecoration(
                labelText: 'Filtra per Scuola',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tutte le Scuole')),
                ..._scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))),
              ],
              onChanged: (val) {
                setState(() => _filterScuolaId = val);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredLezioni.isEmpty
                    ? const Center(child: Text('Nessuna lezione trovata.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        itemCount: filteredLezioni.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final l = filteredLezioni[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                child: const Icon(Icons.event, color: Colors.deepPurple),
                              ),
                              title: Row(
                                children: [
                                  if (l.titolo.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        border: Border.all(color: Colors.deepPurple.shade200),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        l.titolo,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.deepPurple.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      '${l.data} | ${l.corsoDescrizione}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (l.argomentoTitolo != null)
                                    Text('📖 Argomento: ${l.argomentoTitolo}', style: const TextStyle(color: Colors.deepPurple)),
                                  Text('👥 Presenze: ${l.presentiCount} presenti su ${l.presenzeTotali} allievi registrati'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.how_to_reg, color: Colors.deepPurple),
                                tooltip: 'Gestisci Presenze',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const PresenzeScreen()),
                                  );
                                },
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
