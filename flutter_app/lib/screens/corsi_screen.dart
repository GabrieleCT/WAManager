import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

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

  // Cache degli iscritti e delle lezioni per il drill-down
  final Map<String, List<Allievo>> _iscrittiMap = {};
  final Map<String, List<Lezione>> _lezioniMap = {};
  final Set<String> _loadingIscritti = {};

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
      final list = await _api.getAllievi(corsoId: corsoId);
        _sortIscritti(list);
      final lezioni = await _api.getLezioni(corsoId: corsoId);
      if (mounted) {
        setState(() {
          _iscrittiMap[corsoId] = list;
          _lezioniMap[corsoId] = lezioni;
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

  void _showAddCorsoDialog([Corso? corso]) {
    String? scuolaId = corso?.scuolaId ?? (_scuole.isNotEmpty ? _scuole.first.id : null);
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
                      decoration: const InputDecoration(labelText: 'Telefono * (es. +39...)', border: OutlineInputBorder()),
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
                  await _api.createAllievo(data);
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

  Widget _buildStatCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color.shade700),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color.shade700, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 15, color: color.shade900, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuoloBadge(String ruolo) {
    Color bg;
    Color fg;
    String label;
    if (ruolo == 'leader') {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade900;
      label = 'Leader';
    } else if (ruolo == 'follower') {
      bg = Colors.purple.shade100;
      fg = Colors.purple.shade900;
      label = 'Follower';
    } else {
      bg = Colors.teal.shade100;
      fg = Colors.teal.shade900;
      label = 'Both';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
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

    final iscritti = _iscrittiMap[c.id] ?? [];
    final effettivi = iscritti.where((a) => !a.isProspect).toList();
    final prospects = iscritti.where((a) => a.isProspect).toList();

    final lezioni = _lezioniMap[c.id] ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int lezioniFatte = 0;
    int lezioniRimanenti = 0;
    int lezioniTotaliTrimestre = 0;
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

      final lezioniTrimestre = byTrimestre[activeKey] ?? sortedLezioni;
      lezioniTotaliTrimestre = lezioniTrimestre.length;

      for (final l in lezioniTrimestre) {
        final d = DateTime.tryParse(l.data);
        if (d != null) {
          if (d.isBefore(today)) {
            lezioniFatte++;
          } else {
            lezioniRimanenti++;
          }
        }
      }
    }

    final effLeaders = effettivi.where((a) => a.ruolo == 'leader').length;
    final effFollowers = effettivi.where((a) => a.ruolo == 'follower').length;
    final effBoth = effettivi.where((a) => a.ruolo == 'both').length;

    final prLeaders = prospects.where((a) => a.ruolo == 'leader').length;
    final prFollowers = prospects.where((a) => a.ruolo == 'follower').length;

    Widget balanceBadge;
    if (effettivi.isEmpty) {
      balanceBadge = const SizedBox.shrink();
    } else if (effLeaders == effFollowers) {
      balanceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text(
              'Coppie bilanciate ($effLeaders Leader / $effFollowers Follower)',
              style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    } else if (effLeaders > effFollowers) {
      final diff = effLeaders - effFollowers;
      balanceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 18, color: Colors.amber.shade800),
            const SizedBox(width: 6),
            Text(
              '+$diff Leader di scarto (necessari $diff Follower o Jolly)',
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      final diff = effFollowers - effLeaders;
      balanceBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 18, color: Colors.amber.shade800),
            const SizedBox(width: 6),
            Text(
              '+$diff Follower di scarto (necessari $diff Leader o Jolly)',
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RIASSUNTO HEADER CON PULSANTI
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStatCard('Allievi Effettivi', '${effettivi.length}', Icons.groups, Colors.blueGrey),
              _buildStatCard('Prospect in Prova', '${prospects.length}', Icons.contact_mail, Colors.amber),
              _buildStatCard(
                'Leader',
                '$effLeaders${prLeaders > 0 ? " (+$prLeaders prova)" : ""}',
                Icons.man,
                Colors.blue,
              ),
              _buildStatCard(
                'Follower',
                '$effFollowers${prFollowers > 0 ? " (+$prFollowers prova)" : ""}',
                Icons.woman,
                Colors.purple,
              ),
              if (effBoth > 0)
                _buildStatCard('Both', '$effBoth', Icons.people, Colors.teal),
              if (lezioniTotaliTrimestre > 0) ...[
                _buildStatCard(
                  'Lezioni Fatte ($activeTrimestreName)',
                  '$lezioniFatte / $lezioniTotaliTrimestre',
                  Icons.task_alt,
                  Colors.teal,
                ),
                _buildStatCard(
                  'Lezioni Rimanenti',
                  '$lezioniRimanenti',
                  Icons.hourglass_bottom,
                  Colors.indigo,
                ),
              ],
              if (balanceBadge != const SizedBox.shrink())
                balanceBadge,
            ],
          ),
          const Divider(height: 24),

          // SEZIONE 1: ALLIEVI EFFETTIVI
          Row(
            children: [
              const Icon(Icons.school, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                'Allievi Iscritti Effettivi (${effettivi.length}):',
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
                  if (idx > 0) const Divider(height: 1),
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: effettivi[idx].ruolo == 'leader' ? Colors.blue.shade100 : Colors.purple.shade100,
                      child: Text(
                        effettivi[idx].cognome.isNotEmpty
                            ? effettivi[idx].cognome[0]
                            : (effettivi[idx].nome.isNotEmpty ? effettivi[idx].nome[0] : 'A'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: effettivi[idx].ruolo == 'leader' ? Colors.blue.shade900 : Colors.purple.shade900,
                        ),
                      ),
                    ),
                    title: Row(children: [Text(effettivi[idx].nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), if (effettivi[idx].partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 14, color: Colors.pink)]]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('📞 ${effettivi[idx].telefono}', style: const TextStyle(fontSize: 12)), if (effettivi[idx].partnerId != null) Text('Partner: ${effettivi[idx].partnerNomeCompleto}', style: const TextStyle(fontSize: 11, color: Colors.pink))]),
                    trailing: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildRuoloBadge(effettivi[idx].ruolo),
                        Chip(
                          label: Text(effettivi[idx].livelloDisplay, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        if (effettivi[idx].recensione == 'si')
                          const Tooltip(
                            message: 'Recensione rilasciata',
                            child: Icon(Icons.star, color: Colors.amber, size: 16),
                          ),
                      ],
                    ),
                  ),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade400, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.amber.shade200,
                          child: Icon(Icons.assignment_ind, color: Colors.amber.shade900, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(p.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (p.partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 14, color: Colors.pink)],
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'IN PROVA',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('📞 ${p.telefono}', style: const TextStyle(fontSize: 12)), const SizedBox(width: 8), _buildRuoloBadge(p.ruolo), if (p.partnerId != null) ...[const SizedBox(width: 8), Text('Partner: ${p.partnerNomeCompleto}', style: const TextStyle(fontSize: 11, color: Colors.pink))],
                                ],
                              ),
                              if (p.note.isNotEmpty) ...[
                                const SizedBox(height: 4),
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
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Tooltip(
                              message: 'Iscrive definitivamente il prospect come allievo effettivo',
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
                                  final ok = await _api.convertProspectToStudent(p.id, c.id);
                                  if (ok && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${p.nomeCompleto} iscritto al corso come allievo effettivo!')),
                                    );
                                    _fetchIscritti(c.id);
                                    _loadAll();
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              tooltip: 'Rimuovi dalla prova del corso',
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                await _api.updateAllievo(p.id, {'corso': null});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${p.nomeCompleto} rimosso dalla prova del corso.')),
                                  );
                                  _fetchIscritti(c.id);
                                  _loadAll();
                                }
                              },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corsi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica corsi',
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCorsoDialog(),
        tooltip: 'Aggiungi Corso',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scuole.isEmpty
              ? const Center(child: Text('Nessuna scuola configurata.'))
              : ListView.builder(
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
                          title: Text(
                            scuola.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Text('${corsiScuola.length} corsi'),
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
                                            child: Text(
                                              '${c.livelloDisplay}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                                            onPressed: () async {
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
                                              if (confirm == true) {
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
                                            },
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
                                            if (c.gruppoWhatsapp.isNotEmpty)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.chat, size: 14, color: Colors.green),
                                                  const SizedBox(width: 4),
                                                  Text(c.gruppoWhatsapp, style: const TextStyle(fontSize: 13, color: Colors.green)),
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
                ),
    );
  }
}
