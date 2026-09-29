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
    final today = DateTime(now.year, now.month, now.day, 12, 0);
    int diff = targetWeekday - today.weekday;
    if (diff < 0) diff += 7;
    return DateTime(today.year, today.month, today.day + diff, 12, 0);
  }

  String _calcolaTitoloNuovaLezione(String corsoId, DateTime dataLezione) {
    final lezioniCorso = _lezioni.where((l) => l.corsoId == corsoId).toList();
    
    String trimestre = '';
    if (dataLezione.month >= 10 && dataLezione.month <= 12) trimestre = '1° Trimestre';
    else if (dataLezione.month >= 1 && dataLezione.month <= 3) trimestre = '2° Trimestre';
    else if (dataLezione.month >= 4 && dataLezione.month <= 6) trimestre = '3° Trimestre';
    else trimestre = '4° Trimestre';

    final lezioniTrimestre = lezioniCorso.where((l) => _extractTrimestre(l) == trimestre).toList();
    
    List<DateTime> date = lezioniTrimestre.map((l) => DateTime.tryParse(l.data) ?? DateTime.now()).toList();
    date.add(dataLezione);
    date.sort();

    int index = date.indexOf(dataLezione) + 1;
    int total = date.length;
    
    return '$index/$total - $trimestre';
  }

  // ─── DIALOG NUOVA LEZIONE SINGOLA ─────────────────────────────
  void _showAddLezioneDialog() {
    String? selectedCorsoId = _corsi.isNotEmpty ? _corsi.first.id : null;
    String? selectedArgomentoId;
    DateTime selectedDate = DateTime.now();
    final titoloCtl = TextEditingController();

    void updateTitolo() {
      if (selectedCorsoId != null) {
        titoloCtl.text = _calcolaTitoloNuovaLezione(selectedCorsoId!, selectedDate);
      }
    }
    
    updateTitolo();

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
                  onChanged: (v) {
                    setDlgState(() => selectedCorsoId = v);
                    updateTitolo();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titoloCtl,
                  decoration: const InputDecoration(
                    labelText: 'Titolo / Nomenclatura',
                    hintText: 'Es. 1/12 - 1° Trimestre',
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
                      updateTitolo();
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
                            for (int i = 0; i < numeroLezioni; i++) {
                              dateProposte.add(DateTime(selectedDataInizio.year, selectedDataInizio.month, selectedDataInizio.day + (i * 7), 12, 0));
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
                  final initial = dateProposte.isNotEmpty
                      ? DateTime(dateProposte.last.year, dateProposte.last.month, dateProposte.last.day + 7, 12, 0)
                      : DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    final normalized = DateTime(picked.year, picked.month, picked.day, 12, 0);
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
                                final normalized = DateTime(picked.year, picked.month, picked.day, 12, 0);
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

  String _extractTrimestre(Lezione l) {
    if (l.titolo.isNotEmpty) {
      final match = RegExp(r'(\d+°\s*Trimestre)', caseSensitive: false).firstMatch(l.titolo);
      if (match != null) return match.group(1)!;
      if (l.titolo.toLowerCase().contains('trimestre')) {
        final parts = l.titolo.split('-');
        if (parts.length > 1) return parts.last.trim();
        return l.titolo;
      }
    }
    final date = DateTime.tryParse(l.data);
    if (date != null) {
      if (date.month >= 10 && date.month <= 12) return '1° Trimestre';
      if (date.month >= 1 && date.month <= 3) return '2° Trimestre';
      if (date.month >= 4 && date.month <= 6) return '3° Trimestre';
      return '4° Trimestre';
    }
    return 'Altre Lezioni';
  }

  int _trimestreOrder(String t) {
    if (t.contains('1°')) return 1;
    if (t.contains('2°')) return 2;
    if (t.contains('3°')) return 3;
    if (t.contains('4°')) return 4;
    return 99;
  }

  String _formatDataItaliano(String dataStr) {
    final d = DateTime.tryParse(dataStr);
    if (d == null) return dataStr;
    return '${_giornoItaliano(d.weekday)} ${DateFormat('dd/MM/yyyy').format(d)}';
  }

  Future<void> _deleteLezione(Lezione l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Elimina Lezione'),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare la lezione del ${_formatDataItaliano(l.data)} (${l.titolo.isNotEmpty ? l.titolo : l.corsoDescrizione})?\n\nTutte le presenze registrate per questa lezione andranno perse.',
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

    if (confirm == true) {
      setState(() => _loading = true);
      final ok = await _api.deleteLezione(l.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Lezione eliminata con successo.' : 'Errore durante l\'eliminazione della lezione.'),
            backgroundColor: ok ? Colors.green.shade800 : Colors.red.shade800,
          ),
        );
      }
      _loadAll();
    }
  }

  Future<void> _deleteTrimestre(String corsoDescrizione, String trimestre, List<Lezione> lezioni) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Elimina $trimestre')),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare TUTTE le ${lezioni.length} lezioni del "$trimestre" per il corso "$corsoDescrizione"?\n\nQuesta operazione cancellerà anche tutte le relative presenze e non può essere annullata.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Elimina ${lezioni.length} Lezioni'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      int deleted = 0;
      for (final l in lezioni) {
        final ok = await _api.deleteLezione(l.id);
        if (ok) deleted++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eliminate $deleted lezioni del $trimestre con successo.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedScuole = _filterScuolaId == null
        ? _scuole
        : _scuole.where((s) => s.id == _filterScuolaId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultazione Lezioni'),
        actions: [
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
                : displayedScuole.isEmpty
                    ? const Center(child: Text('Nessuna scuola trovata.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                        itemCount: displayedScuole.length,
                        itemBuilder: (ctx, sIdx) {
                          final scuola = displayedScuole[sIdx];
                          final corsiScuola = _corsi.where((c) => c.scuolaId == scuola.id).toList()
                            ..sort((a, b) => a.orario.compareTo(b.orario));
                          final lezioniScuola = _lezioni.where((l) => l.scuolaId == scuola.id || corsiScuola.any((c) => c.id == l.corsoId)).toList();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.deepPurple.shade100,
                                  child: const Icon(Icons.apartment, color: Colors.deepPurple),
                                ),
                                title: Text(
                                  scuola.nome,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Text(
                                  '${scuola.sede} • ${corsiScuola.length} corsi attivi • ${lezioniScuola.length} lezioni registrate',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                children: [
                                  if (corsiScuola.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Nessun corso configurato per questa scuola.',
                                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                      ),
                                    )
                                  else
                                    ...corsiScuola.map((corso) {
                                      final lezioniCorso = _lezioni.where((l) => l.corsoId == corso.id).toList();

                                      // Raggruppamento per Trimestre
                                      final Map<String, List<Lezione>> trimestriMap = {};
                                      for (final l in lezioniCorso) {
                                        final trim = _extractTrimestre(l);
                                        trimestriMap.putIfAbsent(trim, () => []).add(l);
                                      }

                                      // Ordinamento lezioni per data crescente
                                      for (final list in trimestriMap.values) {
                                        list.sort((a, b) => a.data.compareTo(b.data));
                                      }

                                      // Ordinamento trimestri
                                      final sortedTrimestriKeys = trimestriMap.keys.toList()
                                        ..sort((a, b) => _trimestreOrder(a).compareTo(_trimestreOrder(b)));

                                      return Container(
                                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: ExpansionTile(
                                          initiallyExpanded: true,
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          leading: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.indigo.shade100,
                                            child: const Icon(Icons.class_outlined, size: 18, color: Colors.indigo),
                                          ),
                                          title: Text(
                                            '${corso.livelloDisplay} • ${corso.giornoSettimana} ore ${corso.orario}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          subtitle: Text(
                                            'Anno ${corso.annoAccademico} • ${lezioniCorso.length} lezioni in ${sortedTrimestriKeys.length} trimestri',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          children: [
                                            if (sortedTrimestriKeys.isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                                    const SizedBox(width: 8),
                                                    const Text(
                                                      'Nessuna lezione registrata per questo corso.',
                                                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              ...sortedTrimestriKeys.map((trimestreKey) {
                                                final lezioniTrimestre = trimestriMap[trimestreKey]!;

                                                return Container(
                                                  margin: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.deepPurple.shade100),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: [
                                                      // HEADER TRIMESTRE
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.deepPurple.shade50,
                                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Icon(Icons.calendar_month, size: 18, color: Colors.deepPurple),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  trimestreKey,
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 14,
                                                                    color: Colors.deepPurple.shade900,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.white,
                                                                    borderRadius: BorderRadius.circular(12),
                                                                    border: Border.all(color: Colors.deepPurple.shade200),
                                                                  ),
                                                                  child: Text(
                                                                    '${lezioniTrimestre.length} Lezioni',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: Colors.deepPurple.shade800,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            TextButton.icon(
                                                              style: TextButton.styleFrom(
                                                                foregroundColor: Colors.red.shade700,
                                                                visualDensity: VisualDensity.compact,
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              ),
                                                              icon: const Icon(Icons.delete_sweep, size: 16),
                                                              label: const Text(
                                                                'Elimina Trimestre',
                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                              ),
                                                              onPressed: () => _deleteTrimestre(
                                                                '${scuola.nome} - ${corso.livelloDisplay}',
                                                                trimestreKey,
                                                                lezioniTrimestre,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      // LISTA LEZIONI DEL TRIMESTRE (ORDINATE PER DATA CRESCENTE)
                                                      ListView.separated(
                                                        shrinkWrap: true,
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: lezioniTrimestre.length,
                                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                                        itemBuilder: (ctx, lIdx) {
                                                          final l = lezioniTrimestre[lIdx];
                                                          final dataFormatted = _formatDataItaliano(l.data);

                                                          return ListTile(
                                                            dense: true,
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                                            leading: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: Colors.deepPurple.shade50,
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: Border.all(color: Colors.deepPurple.shade200),
                                                              ),
                                                              child: Text(
                                                                l.titolo.isNotEmpty
                                                                    ? l.titolo.split(' - ').first
                                                                    : '${lIdx + 1}/${lezioniTrimestre.length}',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.deepPurple.shade900,
                                                                ),
                                                              ),
                                                            ),
                                                            title: Row(
                                                              children: [
                                                                Text(
                                                                  dataFormatted,
                                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                                ),
                                                                if (l.titolo.isNotEmpty) ...[
                                                                  const SizedBox(width: 8),
                                                                  Flexible(
                                                                    child: Text(
                                                                      l.titolo,
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: Colors.deepPurple.shade700,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                            subtitle: Row(
                                                              children: [
                                                                if (l.argomentoTitolo != null && l.argomentoTitolo!.isNotEmpty) ...[
                                                                  Text(
                                                                    '📖 ${l.argomentoTitolo!}  •  ',
                                                                    style: const TextStyle(color: Colors.deepPurple, fontSize: 11),
                                                                  ),
                                                                ],
                                                                Text(
                                                                  '👥 ${l.presentiCount} / ${l.presenzeTotali} presenti',
                                                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
                                                                ),
                                                              ],
                                                            ),
                                                            trailing: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                IconButton(
                                                                  icon: const Icon(Icons.how_to_reg, color: Colors.deepPurple, size: 20),
                                                                  tooltip: 'Gestisci Presenze',
                                                                  onPressed: () {
                                                                    Navigator.of(context)
                                                                        .push(
                                                                          MaterialPageRoute(
                                                                            builder: (_) => PresenzeScreen(initialLezioneId: l.id),
                                                                          ),
                                                                        )
                                                                        .then((_) => _loadAll());
                                                                  },
                                                                ),
                                                                IconButton(
                                                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                                  tooltip: 'Elimina Lezione',
                                                                  onPressed: () => _deleteLezione(l),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
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
