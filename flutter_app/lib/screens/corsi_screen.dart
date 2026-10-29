import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pdf_report_service.dart';
import '../widgets/google_sync_dialog.dart';
import '../widgets/delete_allievo_dialog.dart';

class CorsiScreen extends StatefulWidget {
  const CorsiScreen({super.key});

  @override
  State<CorsiScreen> createState() => _CorsiScreenState();
}

class _CorsiScreenState extends State<CorsiScreen> {
  final ApiService _api = ApiService();
  List<Corso> _corsi = [];
  List<Scuola> _scuole = [];
  bool _loading = true;

  // Cache degli iscritti, lezioni e pagamenti per il drill-down
  final Map<String, List<Allievo>> _iscrittiMap = {};
  final Map<String, List<Lezione>> _lezioniMap = {};
  final Map<String, List<Pagamento>> _pagamentiMap = {};
  final Set<String> _loadingIscritti = {};
  String? _selectedScuolaIdMobile;
  String? _selectedCorsoIdMobile;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    if (mounted) {
      setState(() {
        _corsi = corsi;
        _scuole = scuole;
        _iscrittiMap.clear();
        _lezioniMap.clear();
        _pagamentiMap.clear();
        _loading = false;
      });
    }
  }


  void _sortIscritti(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  Future<void> _fetchIscritti(String corsoId) async {
    if (_loadingIscritti.contains(corsoId)) return;
    setState(() => _loadingIscritti.add(corsoId));
    try {
      final results = await Future.wait([
        _api.getAllievi(corsoId: corsoId),
        _api.getLezioni(corsoId: corsoId),
        _api.getPagamenti(corsoId: corsoId),
      ]);
      final list = results[0] as List<Allievo>;
      _sortIscritti(list);
      final lezioni = results[1] as List<Lezione>;
      final pagamenti = results[2] as List<Pagamento>;
      if (mounted) {
        setState(() {
          _iscrittiMap[corsoId] = list;
          _lezioniMap[corsoId] = lezioni;
          _pagamentiMap[corsoId] = pagamenti;
          _loadingIscritti.remove(corsoId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingIscritti.remove(corsoId));
      }
    }
  }

  String _normalizeGiorno(String? g) {
    if (g == null) return 'LUNEDI';
    final u = g.toUpperCase().trim();
    if (u.contains('LUN')) return 'LUNEDI';
    if (u.contains('MAR')) return 'MARTEDI';
    if (u.contains('MER')) return 'MERCOLEDI';
    if (u.contains('GIO')) return 'GIOVEDI';
    if (u.contains('VEN')) return 'VENERDI';
    if (u.contains('SAB')) return 'SABATO';
    if (u.contains('DOM')) return 'DOMENICA';
    return 'LUNEDI';
  }

  Future<void> _confirmDeleteCorso(Corso c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (cCtx) => AlertDialog(
        title: const Text('Elimina Corso'),
        content: Text('Sei sicuro di voler eliminare il corso ${c.scuolaNome} - ${c.livelloDisplay}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cCtx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(cCtx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await _api.deleteCorso(c.id);
      if (ok) {
        _loadAll();
      } else if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossibile eliminare il corso. Verificare se ci sono allievi o lezioni collegate.')),
        );
      }
    }
  }

  void _showAddCorsoDialog([Corso? corso, String? initialScuolaId]) {
    String? scuolaId = corso?.scuolaId ?? initialScuolaId ?? (_scuole.isNotEmpty ? _scuole.first.id : null);
    String giornoSettimana = _normalizeGiorno(corso?.giornoSettimana);
    String livello = corso?.livello ?? 'principiante';
    final orarioCtl = TextEditingController(text: corso?.orario ?? '20:30');
    final annoCtl = TextEditingController(text: corso?.annoAccademico ?? '2025/2026');
    final waCtl = TextEditingController(text: corso?.gruppoWhatsapp ?? '');

    bool isSaving = false;
    bool isVerifyingWa = false;
    String? waResolvedInfo;
    String? waResolvedError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(corso == null ? 'Nuovo Corso' : 'Modifica Corso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: scuolaId,
                  decoration: const InputDecoration(labelText: 'Scuola *'),
                  items: _scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))).toList(),
                  onChanged: isSaving ? null : (v) => setDState(() => scuolaId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: livello,
                  decoration: const InputDecoration(labelText: 'Livello *'),
                  items: const [
                    DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                    DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                    DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                  ],
                  onChanged: isSaving ? null : (v) => setDState(() => livello = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: giornoSettimana,
                  decoration: const InputDecoration(labelText: 'Giorno della settimana *'),
                  items: const [
                    DropdownMenuItem(value: 'LUNEDI', child: Text('Lunedì')),
                    DropdownMenuItem(value: 'MARTEDI', child: Text('Martedì')),
                    DropdownMenuItem(value: 'MERCOLEDI', child: Text('Mercoledì')),
                    DropdownMenuItem(value: 'GIOVEDI', child: Text('Giovedì')),
                    DropdownMenuItem(value: 'VENERDI', child: Text('Venerdì')),
                    DropdownMenuItem(value: 'SABATO', child: Text('Sabato')),
                    DropdownMenuItem(value: 'DOMENICA', child: Text('Domenica')),
                  ],
                  onChanged: isSaving ? null : (v) => setDState(() => giornoSettimana = v!),
                ),
                TextField(
                  controller: orarioCtl,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Orario (HH:MM) *'),
                ),
                TextField(
                  controller: annoCtl,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Anno Accademico *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: waCtl,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Gruppo WhatsApp Corso',
                    hintText: 'Link invito (es. https://chat.whatsapp.com/...) o ID',
                    helperText: 'Incolla il link d\'invito: verrà convertito automaticamente nel gruppo WhatsApp',
                    prefixIcon: const Icon(Icons.chat, color: Colors.green),
                    suffixIcon: isVerifyingWa
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.link_outlined, color: Colors.green),
                            tooltip: 'Verifica link invito',
                            onPressed: () async {
                              final text = waCtl.text.trim();
                              if (text.isEmpty) return;
                              setDState(() {
                                isVerifyingWa = true;
                                waResolvedInfo = null;
                                waResolvedError = null;
                              });
                              final res = await _api.resolveWhatsappGroup(text);
                              setDState(() {
                                isVerifyingWa = false;
                                if (res['success'] == true && res['groupId'] != null) {
                                  waResolvedInfo = '✓ Gruppo: ${res['subject']} (${res['size'] ?? 0} part.)';
                                  waCtl.text = res['groupId'];
                                } else {
                                  waResolvedError = res['error'] ?? 'Impossibile risalire al gruppo dal link';
                                }
                              });
                            },
                          ),
                  ),
                ),
                if (waResolvedInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        waResolvedInfo!,
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                if (waResolvedError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        waResolvedError!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (scuolaId == null || orarioCtl.text.trim().isEmpty) return;
                      String waValue = waCtl.text.trim();

                      setDState(() {
                        isSaving = true;
                        waResolvedError = null;
                      });

                      // Se l'utente ha inserito un link d'invito o un codice, risali al gruppo WhatsApp
                      if (waValue.isNotEmpty && (waValue.contains('chat.whatsapp.com') || !waValue.contains('@g.us'))) {
                        final res = await _api.resolveWhatsappGroup(waValue);
                        if (res['success'] == true && res['groupId'] != null) {
                          waValue = res['groupId'];
                        } else {
                          setDState(() {
                            isSaving = false;
                            waResolvedError = res['error'] ?? 'Impossibile risalire al gruppo WhatsApp. Verifica il link.';
                          });
                          return;
                        }
                      }

                      final data = {
                        'scuola': scuolaId,
                        'livello': livello,
                        'giorno_settimana': giornoSettimana,
                        'orario': orarioCtl.text.trim(),
                        'anno_accademico': annoCtl.text.trim(),
                        'gruppo_whatsapp': waValue,
                      };

                      bool ok = false;
                      if (corso == null) {
                        final created = await _api.createCorso(data);
                        ok = created != null;
                      } else {
                        final updated = await _api.updateCorso(corso.id, data);
                        ok = updated != null;
                      }

                      setDState(() => isSaving = false);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(waValue.isNotEmpty
                                  ? 'Corso salvato! Gruppo WhatsApp collegato: $waValue'
                                  : 'Corso salvato con successo!'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Errore durante il salvataggio del corso.'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      }
                      _loadAll();
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salva Corso'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAllievoToCorsoDialog(Corso c) async {
    final allAllievi = await _api.getAllievi(isProspect: false);
    final available = allAllievi.where((a) => a.corsoId != c.id).toList();

    if (!mounted) return;

    String? selectedAllievoId = available.isNotEmpty ? available.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.indigo.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Aggiungi Allievo al Corso', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: available.isEmpty
              ? const Text('Nessun allievo disponibile.')
              : SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Seleziona l\'allievo da aggiungere (verrà spostato se già in un altro corso):', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedAllievoId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Allievo *', border: OutlineInputBorder()),
                        items: available.map((a) {
                          final fromStr = (a.corsoDescrizione != null && a.corsoDescrizione!.isNotEmpty) ? ' [Da: ${a.corsoDescrizione}]' : '';
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.nomeCompleto} (${a.ruolo.toUpperCase()})$fromStr'),
                          );
                        }).toList(),
                        onChanged: (v) => setDlgState(() => selectedAllievoId = v),
                      ),
                    ],
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: available.isEmpty
                  ? null
                  : () async {
                      if (selectedAllievoId == null) return;
                      await _api.updateAllievo(selectedAllievoId!, {'corso': c.id, 'livello': c.livello});
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAll();
                    },
              child: const Text('Assegna'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProspectToCorsoDialog(Corso c) async {
    final allProspects = await _api.getAllievi(isProspect: true);
    final available = allProspects.where((p) => p.corsoId != c.id).toList();

    if (!mounted) return;

    int tabIndex = 0; // 0 = seleziona esistente, 1 = crea nuovo
    String? selectedProspectId = available.isNotEmpty ? available.first.id : null;

    final nomeCtl = TextEditingController();
    final cognomeCtl = TextEditingController();
    final telCtl = TextEditingController();
    final noteCtl = TextEditingController();
    String ruolo = 'leader';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Assegna Prospect in Prova', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Corso: ${c.scuolaNome} - ${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Prospect Esistente'), icon: Icon(Icons.people_outline)),
                      ButtonSegment(value: 1, label: Text('Nuovo Prospect'), icon: Icon(Icons.person_add)),
                    ],
                    selected: {tabIndex},
                    onSelectionChanged: (s) => setDlgState(() => tabIndex = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (tabIndex == 0) ...[
                    if (available.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: const Text(
                          'Nessun prospect disponibile da assegnare. Seleziona "Nuovo Prospect" per registrarne uno nuovo.',
                          style: TextStyle(fontSize: 13),
                        ),
                      )
                    else ...[
                      const Text('Seleziona il prospect che parteciperà alla lezione di prova:', style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedProspectId,
                        decoration: const InputDecoration(labelText: 'Prospect *', border: OutlineInputBorder()),
                        items: available.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.nomeCompleto} (${p.ruoloDisplay} • ${p.telefono})'),
                          );
                        }).toList(),
                        onChanged: (v) => setDlgState(() => selectedProspectId = v),
                      ),
                    ],
                  ] else ...[
                    TextField(
                      controller: nomeCtl,
                      decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cognomeCtl,
                      decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: telCtl,
                      decoration: const InputDecoration(labelText: 'Telefono (opzionale, es. +39...)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: ruolo,
                      decoration: const InputDecoration(labelText: 'Ruolo', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'leader', child: Text('Leader')),
                        DropdownMenuItem(value: 'follower', child: Text('Follower')),
                        DropdownMenuItem(value: 'both', child: Text('Both')),
                      ],
                      onChanged: (v) => setDlgState(() => ruolo = v!),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtl,
                      decoration: const InputDecoration(
                        labelText: 'Note (es. Lezione di prova il...)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
              icon: const Icon(Icons.check),
              label: const Text('Assegna al Corso'),
              onPressed: () async {
                if (tabIndex == 0) {
                  if (selectedProspectId == null) return;
                  await _api.updateAllievo(selectedProspectId!, {'corso': c.id, 'livello': c.livello});
                } else {
                  if (nomeCtl.text.trim().isEmpty || cognomeCtl.text.trim().isEmpty) return;
                  final data = {
                    'nome': nomeCtl.text.trim(),
                    'cognome': cognomeCtl.text.trim(),
                    'telefono': telCtl.text.trim(),
                    'ruolo': ruolo,
                    'livello': c.livello,
                    'corso': c.id,
                    'is_prospect': true,
                    'recensione': 'no',
                    'note': noteCtl.text.trim().isNotEmpty ? noteCtl.text.trim() : 'Lezione di prova',
                  };
                  final res = await _api.createAllievo(data);
                  if (res == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Errore durante la creazione del prospect.'), backgroundColor: Colors.red),
                      );
                    }
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted && res.googleSyncError != null && res.googleSyncError!.isNotEmpty) {
                    checkAndShowGoogleSyncError(
                      context,
                      entityType: 'Prospect',
                      name: res.nomeCompleto,
                      error: res.googleSyncError,
                    );
                  }
                  _fetchIscritti(c.id);
                  _loadAll();
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchIscritti(c.id);
                _loadAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickPayDialog(Corso c, Allievo a, String? activeTrimestreCode) {
    final importoCtl = TextEditingController(text: '150.00');
    final noteCtl = TextEditingController();
    String trimestre = activeTrimestreCode ?? 'T1';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payments, color: Colors.green),
              SizedBox(width: 8),
              Text('Registra Pagamento'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Allievo: ${a.nomeCompleto}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Corso: ${c.scuolaNome} - ${c.livelloDisplay}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: trimestre,
                decoration: const InputDecoration(labelText: 'Trimestre', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'T1', child: Text('Primo Trimestre (T1)')),
                  DropdownMenuItem(value: 'T2', child: Text('Secondo Trimestre (T2)')),
                  DropdownMenuItem(value: 'T3', child: Text('Terzo Trimestre (T3)')),
                ],
                onChanged: (v) => setDlgState(() => trimestre = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: importoCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo (€)',
                  prefixText: '€ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                  labelText: 'Note (opzionale)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: () async {
                final data = {
                  'allievo': a.id,
                  'corso': c.id,
                  'importo': double.tryParse(importoCtl.text.trim()) ?? 150.00,
                  'trimestre': trimestre,
                  'data_pagamento': DateFormat('yyyy-MM-dd').format(selectedDate),
                  'note': noteCtl.text.trim(),
                };
                final res = await _api.createPagamento(data);
                if (ctx.mounted) Navigator.pop(ctx);
                if (res != null) {
                  _fetchIscritti(c.id);
                  _loadAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Pagamento registrato per ${a.nomeCompleto}!'), backgroundColor: Colors.green.shade700),
                    );
                  }
                }
              },
              child: const Text('Salva Pagamento'),
            ),
          ],
        ),
      ),
    );
  }


  void _showEditAllievoDialog(Corso c, Allievo a) {
    final nomeController = TextEditingController(text: a.nome);
    final cognomeController = TextEditingController(text: a.cognome);
    final telefonoController = TextEditingController(text: a.telefono);
    final tesseraController = TextEditingController(text: a.numeroTessera);
    final noteController = TextEditingController(text: a.note);
    DateTime? dataEmissione = (a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty)
        ? DateTime.tryParse(a.dataEmissioneTessera!)
        : null;
    String ruolo = a.ruolo;
    String livello = a.livello;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text(a.isProspect ? 'Modifica Prospect' : 'Modifica Allievo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome *')),
                  const SizedBox(height: 16),
                  TextField(controller: cognomeController, decoration: const InputDecoration(labelText: 'Cognome *')),
                  const SizedBox(height: 16),
                  TextField(controller: telefonoController, decoration: const InputDecoration(labelText: 'Telefono (opzionale, es. +39333...)')),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: ruolo,
                    decoration: const InputDecoration(labelText: 'Ruolo *'),
                    items: const [
                      DropdownMenuItem(value: 'leader', child: Text('Leader')),
                      DropdownMenuItem(value: 'follower', child: Text('Follower')),
                    ],
                    onChanged: (v) => setDlgState(() => ruolo = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: livello,
                    decoration: const InputDecoration(labelText: 'Livello *'),
                    items: const [
                      DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                      DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                    ],
                    onChanged: (v) => setDlgState(() => livello = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Disponibilità, richieste, dettagli prova...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Dati Tessera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tesseraController,
                    decoration: const InputDecoration(labelText: 'Numero Tessera', prefixIcon: Icon(Icons.badge_outlined)),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                    title: Text(
                      dataEmissione == null
                          ? 'Nessuna data di emissione'
                          : 'Data emissione: ${DateFormat('dd/MM/yyyy').format(dataEmissione!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: dataEmissione == null ? Colors.grey.shade600 : Colors.black87,
                        fontWeight: dataEmissione == null ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        if (dataEmissione != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                            tooltip: 'Rimuovi data emissione',
                            onPressed: () => setDlgState(() => dataEmissione = null),
                          ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('Data', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dataEmissione ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDlgState(() => dataEmissione = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (a.partnerId != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Informazioni Coppia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pink)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.pink, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('In coppia con:', style: TextStyle(fontSize: 11, color: Colors.pink, fontWeight: FontWeight.w600)),
                                Text(
                                  a.partnerNomeCompleto.isNotEmpty ? a.partnerNomeCompleto : 'Partner assegnato',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.link_off, color: Colors.red, size: 18),
                            label: const Text('Scollega', style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              await _api.setPartner(a.id, null);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _fetchIscritti(c.id);
                              _loadAll();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.trim().isEmpty || cognomeController.text.trim().isEmpty) return;
                  final res = await _api.updateAllievo(a.id, {
                    'nome': nomeController.text.trim(),
                    'cognome': cognomeController.text.trim(),
                    'telefono': telefonoController.text.trim(),
                    'ruolo': ruolo,
                    'livello': livello,
                    'note': noteController.text.trim(),
                    'numero_tessera': tesseraController.text.trim(),
                    'data_emissione_tessera': dataEmissione != null
                        ? DateFormat('yyyy-MM-dd').format(dataEmissione!)
                        : null,
                  });
                  if (res == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Errore durante l'aggiornamento di ${a.isProspect ? 'questo prospect' : 'questo allievo'}."), backgroundColor: Colors.red),
                      );
                    }
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted && res.googleSyncError != null && res.googleSyncError!.isNotEmpty) {
                    checkAndShowGoogleSyncError(
                      context,
                      entityType: a.isProspect ? 'Prospect' : 'Allievo',
                      name: res.nomeCompleto,
                      error: res.googleSyncError,
                    );
                  }
                  _fetchIscritti(c.id);
                  _loadAll();
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteOrRemoveAllievo(Corso c, Allievo a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opzioni Allievo/Prospect'),
        content: Text(
          'Cosa desideri fare con ${a.nomeCompleto}?\n\n'
          'Nota: "Elimina dal DB" rimuoverà l\'allievo anche dai gruppi WhatsApp, dalla chat WhatsApp e dalla Rubrica Google.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Annulla')
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.updateAllievo(a.id, {'corso': null});
              _fetchIscritti(c.id);
              _loadAll();
            },
            child: const Text('Rimuovi dal Corso', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final deleted = await showDeleteAllievoDialog(context, allievo: a);
              if (deleted == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${a.isProspect ? "Prospect" : "Allievo"} ${a.nomeCompleto} eliminato con successo.'),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                }
                _fetchIscritti(c.id);
                _loadAll();
              }
            },
            child: const Text('Elimina dal DB'),
          ),
        ],
      ),
    );
  }

  int _getLeadersCount(Corso c) {
    final iscritti = _iscrittiMap[c.id];
    if (iscritti != null) {
      return iscritti.where((a) => a.ruolo == 'leader').length;
    }
    return c.leadersCount;
  }

  int _getFollowersCount(Corso c) {
    final iscritti = _iscrittiMap[c.id];
    if (iscritti != null) {
      return iscritti.where((a) => a.ruolo == 'follower').length;
    }
    return c.followersCount;
  }

  int _getJollyNecessari(Corso c) {
    final leaders = _getLeadersCount(c);
    final followers = _getFollowersCount(c);
    return (leaders - followers).abs();
  }

  int _getLezioniFatte(Corso c) {
    final lezioni = _lezioniMap[c.id];
    if (lezioni != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return lezioni.where((l) {
        final d = DateTime.tryParse(l.data);
        return d != null && !d.isAfter(today);
      }).length;
    }
    return c.lezioniFatte;
  }

  Widget _buildRecapBadge({
    required IconData icon,
    required String label,
    required int count,
    required MaterialColor color,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Tooltip(
      message: '$label: $count',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color.shade700),
            const SizedBox(width: 3),
            if (!isMobile)
              Text(
                '$label: ',
                style: TextStyle(fontSize: 11, color: color.shade800, fontWeight: FontWeight.w600),
              ),
            Text(
              '$count',
              style: TextStyle(fontSize: 12, color: color.shade900, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllievoAvatar(String ruolo) {
    Color bg;
    Color fg;
    IconData icon;
    final r = ruolo.toLowerCase().trim();
    if (r == 'leader') {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade900;
      icon = Icons.man;
    } else if (r == 'follower') {
      bg = Colors.purple.shade100;
      fg = Colors.purple.shade900;
      icon = Icons.woman;
    } else {
      bg = Colors.teal.shade100;
      fg = Colors.teal.shade900;
      icon = Icons.people;
    }
    return Tooltip(
      message: ruolo.toUpperCase(),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: bg,
        child: Icon(icon, color: fg, size: 16),
      ),
    );
  }


  Widget _buildStatoTesseraBadge(Allievo a) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String label = a.statoTessera;

    if (a.hasTesseraOk) {
      bg = Colors.green.shade50;
      border = Colors.green.shade600;
      fg = Colors.green.shade900;
      icon = Icons.verified;
    } else if (a.hasTesseraScaduta) {
      bg = Colors.red.shade50;
      border = Colors.red.shade600;
      fg = Colors.red.shade900;
      icon = Icons.error_outline;
    } else {
      bg = Colors.orange.shade50;
      border = Colors.orange.shade600;
      fg = Colors.orange.shade900;
      icon = Icons.credit_card_off;
    }

    String tooltip = label;
    if (a.numeroTessera.isNotEmpty) {
      tooltip += ' (N. ${a.numeroTessera})';
    }
    if (a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty) {
      tooltip += ' - Emessa: ${a.dataEmissioneTessera}';
    }

    final isMobile = MediaQuery.of(context).size.width < 800;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isMobile ? 14 : 12, color: fg),
            if (!isMobile) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrillDownContent(Corso c) {
    if (_loadingIscritti.contains(c.id)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(height: 8),
              Text('Caricamento iscritti...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 800;
    final iscritti = _iscrittiMap[c.id] ?? [];
    final effettivi = iscritti.where((a) => !a.isProspect).toList();
    final prospects = iscritti.where((a) => a.isProspect).toList();

    final lezioni = _lezioniMap[c.id] ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String activeTrimestreName = 'Trimestre';

    if (lezioni.isNotEmpty) {
      final sortedLezioni = List<Lezione>.from(lezioni)..sort((a, b) => a.data.compareTo(b.data));
      final Map<String, List<Lezione>> byTrimestre = {};
      for (final l in sortedLezioni) {
        String trim = 'Trimestre in corso';
        if (l.titolo.isNotEmpty) {
          final m = RegExp(r'(\d+°\s*Trimestre)', caseSensitive: false).firstMatch(l.titolo);
          if (m != null) {
            trim = m.group(1)!;
          } else if (l.titolo.toLowerCase().contains('trimestre')) {
            trim = l.titolo;
          }
        }
        byTrimestre.putIfAbsent(trim, () => []).add(l);
      }

      String? activeKey;
      for (final entry in byTrimestre.entries) {
        final hasUpcoming = entry.value.any((l) {
          final d = DateTime.tryParse(l.data);
          return d != null && !d.isBefore(today);
        });
        if (hasUpcoming) {
          activeKey = entry.key;
          break;
        }
      }
      activeKey ??= byTrimestre.keys.last;
      activeTrimestreName = activeKey;


    }

    final pagamentiCorso = _pagamentiMap[c.id] ?? [];

    String? activeTrimestreCode;
    if (activeTrimestreName.contains('1')) {
      activeTrimestreCode = 'T1';
    } else if (activeTrimestreName.contains('2')) {
      activeTrimestreCode = 'T2';
    } else if (activeTrimestreName.contains('3')) {
      activeTrimestreCode = 'T3';
    }

    bool allievoHaPagato(Allievo a) {
      final aPagamenti = pagamentiCorso.where((p) => p.allievoId == a.id).toList();
      if (aPagamenti.isEmpty) return false;
      if (activeTrimestreCode != null) {
        return aPagamenti.any((p) => p.trimestre == activeTrimestreCode);
      }
      return true;
    }

    final numPagati = effettivi.where(allievoHaPagato).length;



    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      decoration: isMobile
          ? null
          : BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RIASSUNTO HEADER CON PULSANTI
          if (isMobile) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18, color: Colors.indigo),
                    SizedBox(width: 6),
                    Text(
                      'Riepilogo Partecipanti al Corso',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Ricarica iscritti',
                  onPressed: () => _fetchIscritti(c.id),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message: 'Esporta Elenco',
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    onPressed: () => PdfReportService.generaElencoCorso(
                      context: context,
                      corso: c,
                      iscritti: effettivi,
                      prospects: prospects,
                    ),
                    child: const Icon(Icons.picture_as_pdf, size: 18),
                  ),
                ),
                Tooltip(
                  message: 'Assegna Prospect in Prova',
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    onPressed: () => _showAddProspectToCorsoDialog(c),
                    child: const Icon(Icons.person_add_alt_1, size: 18),
                  ),
                ),
                Tooltip(
                  message: 'Aggiungi Allievo',
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    onPressed: () => _showAddAllievoToCorsoDialog(c),
                    child: const Icon(Icons.person_add, size: 18),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18, color: Colors.indigo),
                    SizedBox(width: 6),
                    Text(
                      'Riepilogo Partecipanti al Corso',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Esporta Elenco'),
                      onPressed: () => PdfReportService.generaElencoCorso(
                        context: context,
                        corso: c,
                        iscritti: effettivi,
                        prospects: prospects,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Assegna Prospect in Prova'),
                      onPressed: () => _showAddProspectToCorsoDialog(c),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Aggiungi Allievo'),
                      onPressed: () => _showAddAllievoToCorsoDialog(c),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Ricarica iscritti',
                      onPressed: () => _fetchIscritti(c.id),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ],

          const Divider(height: 24),

          // SEZIONE 1: ALLIEVI EFFETTIVI
          Row(
            children: [
              const Icon(Icons.school, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                'Allievi Iscritti Effettivi (${effettivi.length}) - Pagati: $numPagati / ${effettivi.length}:',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (effettivi.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nessun allievo effettivo attualmente iscritto a questo corso.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            )
          else ...[
            Column(
              children: [
                for (int idx = 0; idx < effettivi.length; idx++) ...[
                  () {
                    final a = effettivi[idx];
                    final haPagato = allievoHaPagato(a);


                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: haPagato ? Colors.white : Colors.red.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: haPagato ? Colors.grey.shade300 : Colors.red.shade300,
                          width: haPagato ? 1 : 1.5,
                        ),
                      ),
                      child: isMobile
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.nomeCompleto,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (a.numeroTessera.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Tessera: ${a.numeroTessera}${a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty ? " (${a.dataEmissioneTessera})" : ""}',
                                              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatoTesseraBadge(a),
                                      const SizedBox(width: 4),
                                      if (haPagato)
                                        Tooltip(
                                          message: 'Pagato',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.green.shade400),
                                            ),
                                            child: Icon(Icons.check_circle, size: 15, color: Colors.green.shade700),
                                          ),
                                        )
                                      else
                                        Tooltip(
                                          message: 'Non ha pagato',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.red.shade600, width: 1.2),
                                            ),
                                            child: Icon(Icons.error_outline, size: 15, color: Colors.red.shade900),
                                          ),
                                        ),
                                      const SizedBox(width: 2),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.blueGrey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (value) {
                                          if (value == 'pay') {
                                            _showQuickPayDialog(c, a, activeTrimestreCode);
                                          } else if (value == 'edit') {
                                            _showEditAllievoDialog(c, a);
                                          } else if (value == 'delete') {
                                            _confirmDeleteOrRemoveAllievo(c, a);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (!haPagato)
                                            const PopupMenuItem(
                                              value: 'pay',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.add_card, size: 18, color: Colors.green),
                                                  SizedBox(width: 8),
                                                  Text('Registra Pagamento'),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text('Modifica Allievo'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Elimina / Rimuovi', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              leading: null,
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      a.nomeCompleto,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildAllievoAvatar(a.ruolo),
                                  if (a.partnerId != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.favorite, size: 14, color: Colors.pink),
                                  ],
                                ],
                              ),
                              subtitle: a.numeroTessera.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Tessera: ${a.numeroTessera}${a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty ? " (${a.dataEmissioneTessera})" : ""}',
                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                                      ),
                                    )
                                  : null,
                              trailing: Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildStatoTesseraBadge(a),
                                  if (haPagato)
                                    Tooltip(
                                      message: 'Pagato',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.shade400),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 13, color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'PAGATO',
                                              style: TextStyle(
                                                color: Colors.green.shade900,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else ...[
                                    Tooltip(
                                      message: 'Non ha pagato',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.red.shade600, width: 1.2),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.error_outline, size: 14, color: Colors.red.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              'NON HA PAGATO',
                                              style: TextStyle(
                                                color: Colors.red.shade900,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_card, size: 18, color: Colors.green),
                                      tooltip: 'Registra pagamento per ${a.nomeCompleto}',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showQuickPayDialog(c, a, activeTrimestreCode),
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                    tooltip: 'Modifica ${a.nomeCompleto}',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showEditAllievoDialog(c, a),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    tooltip: 'Elimina/Rimuovi ${a.nomeCompleto}',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDeleteOrRemoveAllievo(c, a),
                                  ),
                                  if (a.recensione == 'si')
                                    const Tooltip(
                                      message: 'Recensione rilasciata',
                                      child: Icon(Icons.star, color: Colors.amber, size: 16),
                                    ),
                                ],
                              ),
                            ),
                    );
                  }(),
                ],
              ],
            ),
          ],

          const Divider(height: 28),

          // SEZIONE 2: PROSPECT - LEZIONI DI PROVA (DISTINTI EVIDENZIATI)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_ind, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Text(
                      'PROSPECT - LEZIONI DI PROVA (${prospects.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (prospects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nessun prospect assegnato per una lezione di prova in questo corso.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13),
              ),
            )
          else ...[
            Column(
              children: [
                for (final p in prospects)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade400, width: 1.5),
                    ),
                    child: isMobile
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.nomeCompleto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade700,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'PROVA',
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p.note.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '📝 ${p.note}',
                                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.brown.shade800),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: Colors.brown),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (value) async {
                                  if (value == 'convert') {
                                    final res = await _api.convertProspectToStudent(p.id, c.id);
                                    if (res != null && mounted) {
                                      if (res.googleSyncError != null && res.googleSyncError!.isNotEmpty) {
                                        checkAndShowGoogleSyncError(
                                          context,
                                          entityType: 'Allievo',
                                          name: res.nomeCompleto,
                                          error: res.googleSyncError,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${p.nomeCompleto} iscritto al corso come allievo effettivo!')),
                                        );
                                      }
                                      _fetchIscritti(c.id);
                                      _loadAll();
                                    }
                                  } else if (value == 'edit') {
                                    _showEditAllievoDialog(c, p);
                                  } else if (value == 'delete') {
                                    _confirmDeleteOrRemoveAllievo(c, p);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'convert',
                                    child: Row(
                                      children: [
                                        Icon(Icons.school, size: 18, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Converti ad Allievo'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Modifica Prospect'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.close, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Rimuovi o Elimina', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.nomeCompleto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _buildAllievoAvatar(p.ruolo),
                                        if (p.partnerId != null) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.favorite, size: 14, color: Colors.pink),
                                        ],
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade700,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'PROVA',
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p.note.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '📝 ${p.note}',
                                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.brown.shade800),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'Converti ad allievo effettivo',
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.school, size: 15),
                                      label: const Text('Converti ad Allievo', style: TextStyle(fontSize: 11)),
                                      onPressed: () async {
                                        final res = await _api.convertProspectToStudent(p.id, c.id);
                                        if (res != null && mounted) {
                                          if (res.googleSyncError != null && res.googleSyncError!.isNotEmpty) {
                                            checkAndShowGoogleSyncError(
                                              context,
                                              entityType: 'Allievo',
                                              name: res.nomeCompleto,
                                              error: res.googleSyncError,
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('${p.nomeCompleto} iscritto al corso come allievo effettivo!')),
                                            );
                                          }
                                          _fetchIscritti(c.id);
                                          _loadAll();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                    tooltip: 'Modifica ${p.nomeCompleto}',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showEditAllievoDialog(c, p),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                    tooltip: 'Rimuovi o Elimina ${p.nomeCompleto}',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDeleteOrRemoveAllievo(c, p),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileScuoleList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _scuole.length,
      itemBuilder: (ctx, i) {
        final scuola = _scuole[i];
        final corsiScuola = _corsi.where((c) => c.scuolaId == scuola.id).toList();

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedScuolaIdMobile = scuola.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scuola.nome,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              scuola.sede.isNotEmpty
                                  ? '${corsiScuola.length} corsi • ${scuola.sede}'
                                  : '${corsiScuola.length} corsi',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.indigo, size: 24),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildRecapBadge(
                        icon: Icons.people_alt,
                        label: 'Totale allievi',
                        count: scuola.allieviCount,
                        color: Colors.blue,
                      ),
                      _buildRecapBadge(
                        icon: Icons.person_search,
                        label: 'Totale Prospect',
                        count: scuola.prospectsCount,
                        color: Colors.orange,
                      ),
                      _buildRecapBadge(
                        icon: Icons.payments,
                        label: 'Totale Paganti',
                        count: scuola.pagantiCount,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCorsiList(Scuola scuola) {
    final corsiScuola = _corsi.where((c) => c.scuolaId == scuola.id).toList();
    corsiScuola.sort((a, b) => a.orario.compareTo(b.orario));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Banner della scuola selezionata con breadcrumb
        Card(
          elevation: 0,
          color: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.school, size: 22, color: Colors.indigo),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scuola.nome,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                      ),
                      if (scuola.sede.isNotEmpty)
                        Text(scuola.sede, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  label: Text(
                    '${corsiScuola.length} corsi',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (corsiScuola.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: Text('Nessun corso configurato per questa scuola.')),
          )
        else
          ...corsiScuola.map((c) => Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _fetchIscritti(c.id);
                    setState(() {
                      _selectedCorsoIdMobile = c.id;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.livelloDisplay,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                              tooltip: 'Modifica Corso',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showAddCorsoDialog(c, scuola.id),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              tooltip: 'Elimina Corso',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDeleteCorso(c),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, color: Colors.indigo, size: 22),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${c.giornoSettimanaDisplay} ore ${c.orario}', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.date_range, size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(c.annoAccademico, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildRecapBadge(
                              icon: Icons.people_alt,
                              label: 'Allievi',
                              count: c.allieviCount,
                              color: Colors.blue,
                            ),
                            if (c.prospectsCount > 0)
                              _buildRecapBadge(
                                icon: Icons.person_search,
                                label: 'Prospect',
                                count: c.prospectsCount,
                                color: Colors.orange,
                              ),
                            _buildRecapBadge(
                              icon: Icons.payments,
                              label: 'Paganti',
                              count: c.pagantiCount,
                              color: Colors.green,
                            ),
                            _buildRecapBadge(
                              icon: Icons.man,
                              label: 'Leader',
                              count: _getLeadersCount(c),
                              color: Colors.indigo,
                            ),
                            _buildRecapBadge(
                              icon: Icons.woman,
                              label: 'Follower',
                              count: _getFollowersCount(c),
                              color: Colors.purple,
                            ),
                            _buildRecapBadge(
                              icon: Icons.star,
                              label: 'Jolly nec.',
                              count: _getJollyNecessari(c),
                              color: Colors.amber,
                            ),
                            _buildRecapBadge(
                              icon: Icons.task_alt,
                              label: 'Lezioni fatte',
                              count: _getLezioniFatte(c),
                              color: Colors.teal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildMobileCorsoDetail(Corso c, Scuola scuola) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scheda riepilogo del corso selezionato
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${c.livelloDisplay} • ${scuola.nome}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                        tooltip: 'Modifica Corso',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showAddCorsoDialog(c, scuola.id),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Elimina Corso',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteCorso(c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${c.giornoSettimanaDisplay} ore ${c.orario}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(c.annoAccademico, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildRecapBadge(
                        icon: Icons.people_alt,
                        label: 'Allievi',
                        count: c.allieviCount,
                        color: Colors.blue,
                      ),
                      if (c.prospectsCount > 0)
                        _buildRecapBadge(
                          icon: Icons.person_search,
                          label: 'Prospect',
                          count: c.prospectsCount,
                          color: Colors.orange,
                        ),
                      _buildRecapBadge(
                        icon: Icons.payments,
                        label: 'Paganti',
                        count: c.pagantiCount,
                        color: Colors.green,
                      ),
                      _buildRecapBadge(
                        icon: Icons.man,
                        label: 'Leader',
                        count: _getLeadersCount(c),
                        color: Colors.indigo,
                      ),
                      _buildRecapBadge(
                        icon: Icons.woman,
                        label: 'Follower',
                        count: _getFollowersCount(c),
                        color: Colors.purple,
                      ),
                      _buildRecapBadge(
                        icon: Icons.star,
                        label: 'Jolly nec.',
                        count: _getJollyNecessari(c),
                        color: Colors.amber,
                      ),
                      _buildRecapBadge(
                        icon: Icons.task_alt,
                        label: 'Lezioni fatte',
                        count: _getLezioniFatte(c),
                        color: Colors.teal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildDrillDownContent(c),
        ],
      ),
    );
  }

  Widget _buildDesktopScuoleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _scuole.length,
      itemBuilder: (ctx, i) {
        final scuola = _scuole[i];
        final corsiScuola = _corsi.where((c) => c.scuolaId == scuola.id).toList();
        corsiScuola.sort((a, b) => a.orario.compareTo(b.orario));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade100,
                child: const Icon(Icons.school, color: Colors.indigo),
              ),
              title: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    scuola.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  _buildRecapBadge(
                    icon: Icons.people_alt,
                    label: 'Totale allievi',
                    count: scuola.allieviCount,
                    color: Colors.blue,
                  ),
                  _buildRecapBadge(
                    icon: Icons.person_search,
                    label: 'Totale Prospect',
                    count: scuola.prospectsCount,
                    color: Colors.orange,
                  ),
                  _buildRecapBadge(
                    icon: Icons.payments,
                    label: 'Totale Paganti',
                    count: scuola.pagantiCount,
                    color: Colors.green,
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  scuola.sede.isNotEmpty
                      ? '${corsiScuola.length} corsi • ${scuola.sede}'
                      : '${corsiScuola.length} corsi',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              children: corsiScuola.isEmpty
                  ? [const Padding(padding: EdgeInsets.all(16.0), child: Text('Nessun corso per questa scuola.'))]
                  : corsiScuola.map((c) => Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 1,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              _fetchIscritti(c.id);
                            }
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      c.livelloDisplay,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    _buildRecapBadge(
                                      icon: Icons.people_alt,
                                      label: 'Allievi',
                                      count: c.allieviCount,
                                      color: Colors.blue,
                                    ),
                                    if (c.prospectsCount > 0)
                                      _buildRecapBadge(
                                        icon: Icons.person_search,
                                        label: 'Prospect',
                                        count: c.prospectsCount,
                                        color: Colors.orange,
                                      ),
                                    _buildRecapBadge(
                                      icon: Icons.payments,
                                      label: 'Paganti',
                                      count: c.pagantiCount,
                                      color: Colors.green,
                                    ),
                                    _buildRecapBadge(
                                      icon: Icons.man,
                                      label: 'Leader',
                                      count: _getLeadersCount(c),
                                      color: Colors.indigo,
                                    ),
                                    _buildRecapBadge(
                                      icon: Icons.woman,
                                      label: 'Follower',
                                      count: _getFollowersCount(c),
                                      color: Colors.purple,
                                    ),
                                    _buildRecapBadge(
                                      icon: Icons.star,
                                      label: 'Jolly nec.',
                                      count: _getJollyNecessari(c),
                                      color: Colors.amber,
                                    ),
                                    _buildRecapBadge(
                                      icon: Icons.task_alt,
                                      label: 'Lezioni fatte',
                                      count: _getLezioniFatte(c),
                                      color: Colors.teal,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                tooltip: 'Modifica Corso',
                                onPressed: () => _showAddCorsoDialog(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Elimina Corso',
                                onPressed: () => _confirmDeleteCorso(c),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('${c.giornoSettimanaDisplay} ore ${c.orario}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.date_range, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(c.annoAccademico, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          children: [
                            _buildDrillDownContent(c),
                          ],
                        ),
                      ),
                    )).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    Scuola? selectedScuola;
    if (_selectedScuolaIdMobile != null) {
      for (final s in _scuole) {
        if (s.id == _selectedScuolaIdMobile) {
          selectedScuola = s;
          break;
        }
      }
      if (selectedScuola == null) {
        _selectedScuolaIdMobile = null;
        _selectedCorsoIdMobile = null;
      }
    }

    Corso? selectedCorso;
    if (_selectedCorsoIdMobile != null) {
      for (final c in _corsi) {
        if (c.id == _selectedCorsoIdMobile) {
          selectedCorso = c;
          break;
        }
      }
      if (selectedCorso == null) {
        _selectedCorsoIdMobile = null;
      }
    }

    return PopScope(
      canPop: !isMobile || (_selectedScuolaIdMobile == null && _selectedCorsoIdMobile == null),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedCorsoIdMobile != null) {
          setState(() {
            _selectedCorsoIdMobile = null;
          });
        } else if (_selectedScuolaIdMobile != null) {
          setState(() {
            _selectedScuolaIdMobile = null;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: isMobile && _selectedScuolaIdMobile != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Torna indietro',
                  onPressed: () {
                    setState(() {
                      if (_selectedCorsoIdMobile != null) {
                        _selectedCorsoIdMobile = null;
                      } else {
                        _selectedScuolaIdMobile = null;
                      }
                    });
                  },
                )
              : null,
          title: Text(
            isMobile
                ? (selectedCorso != null
                    ? selectedCorso.livelloDisplay
                    : (selectedScuola != null ? selectedScuola.nome : 'Corsi'))
                : 'Corsi',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Ricarica',
              onPressed: () {
                if (selectedCorso != null) {
                  _fetchIscritti(selectedCorso.id);
                }
                _loadAll();
              },
            ),
          ],
        ),
        floatingActionButton: (isMobile && selectedCorso != null)
            ? null
            : FloatingActionButton(
                onPressed: () => _showAddCorsoDialog(null, selectedScuola?.id),
                tooltip: 'Aggiungi Corso',
                child: const Icon(Icons.add),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _scuole.isEmpty
                ? const Center(child: Text('Nessuna scuola configurata.'))
                : isMobile
                    ? (selectedCorso != null
                        ? _buildMobileCorsoDetail(selectedCorso, selectedScuola!)
                        : selectedScuola != null
                            ? _buildMobileCorsiList(selectedScuola)
                            : _buildMobileScuoleList())
                    : _buildDesktopScuoleList(),
      ),
    );
  }
}
