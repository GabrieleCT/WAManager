import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AllieviScreen extends StatefulWidget {
  const AllieviScreen({super.key});

  @override
  State<AllieviScreen> createState() => _AllieviScreenState();
}

class _AllieviScreenState extends State<AllieviScreen> {
  final ApiService _api = ApiService();
  List<Allievo> _allievi = [];
  List<Corso> _corsi = [];
  List<Scuola> _scuole = [];
  bool _loading = true;
  String _groupBy = 'nessuno'; // 'nessuno', 'corso', 'scuola'
  String _searchQuery = '';
  String? _selectedScuolaId;
  String? _selectedCorsoId;
  bool _syncingWhatsapp = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _sortAllievi(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    final allievi = await _api.getAllievi(
      isProspect: false,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      scuolaId: _selectedScuolaId,
      corsoId: _selectedCorsoId,
    );
    _sortAllievi(allievi);
    if (mounted) {
      setState(() {
        _corsi = corsi;
        _scuole = scuole;
        _allievi = allievi;
        _loading = false;
      });
    }
  }

  Future<void> _loadAllievi() async {
    setState(() => _loading = true);
    final allievi = await _api.getAllievi(
      isProspect: false,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      scuolaId: _selectedScuolaId,
      corsoId: _selectedCorsoId,
    );
    _sortAllievi(allievi);
    if (mounted) {
      setState(() {
        _allievi = allievi;
        _loading = false;
      });
    }
  }

  Future<void> _syncWhatsappScuola() async {
    setState(() => _syncingWhatsapp = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Verifica presenza allievi nei gruppi WhatsApp Scuola in corso...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final res = await _api.syncWhatsappScuola();
    if (mounted) {
      setState(() => _syncingWhatsapp = false);
      if (res['success'] == true) {
        final total = res['total_allievi'] ?? 0;
        final inGroup = res['in_gruppo_scuola'] ?? 0;
        final notInGroup = res['non_in_gruppo'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              'Verifica completata su $total allievi: $inGroup presenti nel gruppo WhatsApp Scuola, $notInGroup assenti.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        _loadAllievi();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(res['error'] ?? 'Errore durante la verifica WhatsApp Scuola'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndAddToWhatsapp(Allievo a) async {
    if (a.telefono.isEmpty || a.telefono.toUpperCase() == 'TBD') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("L'allievo ${a.nomeCompleto} non ha un numero di telefono valido registrato."),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final scuolaNome = a.scuolaNome ?? 'della scuola';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group_add, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Aggiungi a WhatsApp Scuola'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vuoi aggiungere questo allievo al gruppo WhatsApp di $scuolaNome?'),
            const SizedBox(height: 12),
            Text('Allievo: ${a.nomeCompleto}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Telefono: ${a.telefono}'),
            if (a.corsoDescrizione != null) Text('Corso: ${a.corsoDescrizione!}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Aggiungi al Gruppo'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Aggiunta di ${a.nomeCompleto} al gruppo in corso...'),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final res = await _api.addStudentToSchoolGroup(a.id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '${a.nomeCompleto} aggiunto con successo al gruppo WhatsApp!'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
      _loadAllievi();
    } else {
      final err = res['error'] ?? 'Impossibile aggiungere l\'allievo al gruppo.';
      final inviteLink = res['invite_link'];

      if (inviteLink != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restrizioni Privacy WhatsApp'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(err),
                const SizedBox(height: 12),
                const Text('Puoi inviare manualmente il link d\'invito all\'allievo:'),
                const SizedBox(height: 8),
                SelectableText(
                  inviteLink,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showAddEditDialog([Allievo? allievo]) {
    final nomeController = TextEditingController(text: allievo?.nome ?? '');
    final cognomeController = TextEditingController(text: allievo?.cognome ?? '');
    final telefonoController = TextEditingController(text: allievo?.telefono ?? '');
    String ruolo = allievo?.ruolo ?? 'leader';
    String livello = allievo?.livello ?? 'principiante';
    String recensione = allievo?.recensione ?? 'no';
    String? selectedCorsoId = allievo?.corsoId;
    String? selectedScuolaId = allievo?.scuolaId;
    
    // Fallback se ci sono scuole e non è selezionata
    if (selectedScuolaId == null && _scuole.isNotEmpty) {
      selectedScuolaId = _scuole.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final corsiFiltrati = _corsi.where((c) => 
            c.scuolaId == selectedScuolaId && c.livello == livello
          ).toList();

          if (selectedCorsoId != null && !corsiFiltrati.any((c) => c.id == selectedCorsoId)) {
            selectedCorsoId = corsiFiltrati.isNotEmpty ? corsiFiltrati.first.id : null;
          }

          return AlertDialog(
            title: Text(allievo == null ? 'Nuovo Allievo' : 'Modifica Allievo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                  ),
                  TextField(
                    controller: cognomeController,
                    decoration: const InputDecoration(labelText: 'Cognome *'),
                  ),
                  TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(labelText: 'Telefono * (es. +39333...)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: ruolo,
                    decoration: const InputDecoration(labelText: 'Ruolo'),
                    items: const [
                      DropdownMenuItem(value: 'leader', child: Text('Leader')),
                      DropdownMenuItem(value: 'follower', child: Text('Follower')),
                      DropdownMenuItem(value: 'both', child: Text('Entrambi (Both)')),
                    ],
                    onChanged: (v) => setDlgState(() => ruolo = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: livello,
                    decoration: const InputDecoration(labelText: 'Livello'),
                    items: const [
                      DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                      DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                    ],
                    onChanged: (v) => setDlgState(() {
                      livello = v!;
                      final matching = _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello).toList();
                      selectedCorsoId = matching.isNotEmpty ? matching.first.id : null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: recensione,
                    decoration: const InputDecoration(labelText: 'Recensione rilasciata'),
                    items: const [
                      DropdownMenuItem(value: 'si', child: Text('Sì')),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                    ],
                    onChanged: (v) => setDlgState(() => recensione = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedScuolaId,
                    decoration: const InputDecoration(labelText: 'Scuola'),
                    items: _scuole.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.nome),
                    )).toList(),
                    onChanged: (v) => setDlgState(() {
                      selectedScuolaId = v;
                      final matching = _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello).toList();
                      selectedCorsoId = matching.isNotEmpty ? matching.first.id : null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedCorsoId,
                    decoration: const InputDecoration(labelText: 'Corso (associato al livello)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Nessun corso --')),
                      ...corsiFiltrati.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})'),
                          )),
                    ],
                    onChanged: (v) => setDlgState(() => selectedCorsoId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.trim().isEmpty || cognomeController.text.trim().isEmpty) return;
                  final data = {
                    'nome': nomeController.text.trim(),
                    'cognome': cognomeController.text.trim(),
                    'telefono': telefonoController.text.trim(),
                    'ruolo': ruolo,
                    'livello': livello,
                    'recensione': recensione,
                    'corso': selectedCorsoId,
                    'is_prospect': false,
                  };
                  if (allievo == null) {
                    await _api.createAllievo(data);
                  } else {
                    await _api.updateAllievo(allievo.id, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAllievi();
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildWhatsappScuolaBadge(Allievo a) {
    final bool inGruppo = a.inGruppoScuolaWhatsapp;
    if (inGruppo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade600, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'WhatsApp Scuola: Sì',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'WhatsApp Scuola: No',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => _confirmAndAddToWhatsapp(a),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_add, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Aggiungi al gruppo',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllievoTile(Allievo a) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: a.ruolo == 'leader' ? Colors.blue.shade100 : Colors.purple.shade100,
          child: Text(a.cognome.isNotEmpty ? a.cognome[0] : 'A'),
        ),
        title: Row(children: [Text(a.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)), if (a.partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 16, color: Colors.pink)]]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📞 ${a.telefono}'),
            if (a.corsoDescrizione != null)
              Text('🎓 ${a.corsoDescrizione!}', style: const TextStyle(fontSize: 12, color: Colors.grey)), if (a.partnerId != null) Text('Partner: ${a.partnerNomeCompleto}', style: const TextStyle(fontSize: 12, color: Colors.pink)),
          ],
        ),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildRuoloBadge(a.ruolo),
            Chip(
              label: Text(a.livelloDisplay, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
            _buildWhatsappScuolaBadge(a),
            if (a.recensione == 'si')
              const Tooltip(message: 'Recensione rilasciata', child: Icon(Icons.star, color: Colors.amber, size: 18)),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _showAddEditDialog(a),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Conferma'),
                    content: const Text('Sei sicuro di voler eliminare questo allievo?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _api.deleteAllievo(a.id);
                  _loadAllievi();
                }
              },
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int leadersCount = _allievi.where((a) => a.ruolo == 'leader').length;
    final int followersCount = _allievi.where((a) => a.ruolo == 'follower').length;
    final int bothCount = _allievi.where((a) => a.ruolo == 'both').length;

    final corsiFiltratiPerScuola = _selectedScuolaId == null
        ? _corsi
        : _corsi.where((c) => c.scuolaId == _selectedScuolaId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elenco Allievi'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _syncingWhatsapp
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text(
              'Verifica WhatsApp Scuola',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _syncingWhatsapp ? null : _syncWhatsappScuola,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Raggruppa per',
            icon: const Icon(Icons.group_work),
            onSelected: (val) => setState(() => _groupBy = val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'nessuno', child: Text('Nessun raggruppamento')),
              PopupMenuItem(value: 'corso', child: Text('Raggruppa per Corso')),
              PopupMenuItem(value: 'scuola', child: Text('Raggruppa per Scuola')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica dati',
            onPressed: _loadInitialData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuovo Allievo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca allievo per nome, cognome o telefono...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _loadAllievi();
              },
            ),
          ),
          // Sezione Filtri Scuola & Corso
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 600;

                        final scuolaDropdown = DropdownButtonFormField<String?>(
                          value: _selectedScuolaId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Filtra per Scuola',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.school, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tutte le scuole')),
                            ..._scuole.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.nome, overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedScuolaId = v;
                              if (_selectedCorsoId != null) {
                                final corsoStillValid = corsiFiltratiPerScuola.any((c) => c.id == _selectedCorsoId && (v == null || c.scuolaId == v));
                                if (!corsoStillValid) {
                                  _selectedCorsoId = null;
                                }
                              }
                            });
                            _loadAllievi();
                          },
                        );

                        final corsoDropdown = DropdownButtonFormField<String?>(
                          value: _selectedCorsoId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Filtra per Corso',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.class_, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tutti i corsi')),
                            ...corsiFiltratiPerScuola.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                _selectedScuolaId == null
                                    ? '${c.scuolaNome} - ${c.livelloDisplay} (${c.orario})'
                                    : '${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedCorsoId = v);
                            _loadAllievi();
                          },
                        );

                        if (isCompact) {
                          return Column(
                            children: [
                              scuolaDropdown,
                              const SizedBox(height: 8),
                              corsoDropdown,
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: scuolaDropdown),
                              const SizedBox(width: 12),
                              Expanded(child: corsoDropdown),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    // Summary Chips & Reset
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.people, size: 16),
                          label: Text('Totale: ${_allievi.length}'),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.blue.shade50,
                          avatar: Icon(Icons.man, size: 16, color: Colors.blue.shade800),
                          label: Text('Leader: $leadersCount', style: TextStyle(color: Colors.blue.shade900)),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.purple.shade50,
                          avatar: Icon(Icons.woman, size: 16, color: Colors.purple.shade800),
                          label: Text('Follower: $followersCount', style: TextStyle(color: Colors.purple.shade900)),
                        ),
                        if (bothCount > 0)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.teal.shade50,
                            avatar: Icon(Icons.people_outline, size: 16, color: Colors.teal.shade800),
                            label: Text('Both: $bothCount', style: TextStyle(color: Colors.teal.shade900)),
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green.shade50,
                          avatar: Icon(Icons.check_circle, size: 16, color: Colors.green.shade800),
                          label: Text(
                            'WhatsApp Scuola: ${_allievi.where((a) => a.inGruppoScuolaWhatsapp).length}',
                            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_selectedScuolaId != null || _selectedCorsoId != null)
                          TextButton.icon(
                            icon: const Icon(Icons.filter_alt_off, size: 18),
                            label: const Text('Azzera filtri'),
                            onPressed: () {
                              setState(() {
                                _selectedScuolaId = null;
                                _selectedCorsoId = null;
                              });
                              _loadAllievi();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_allievi.isEmpty)
            const Expanded(child: Center(child: Text('Nessun allievo trovato per i filtri selezionati.')))
          else
            Expanded(
              child: _groupBy == 'nessuno'
                  ? ListView.builder(
                      itemCount: _allievi.length,
                      itemBuilder: (_, i) => _buildAllievoTile(_allievi[i]),
                    )
                  : _buildGroupedList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<Allievo>> groups = {};
    for (final a in _allievi) {
      String key = 'Non assegnato';
      if (_groupBy == 'corso') {
        key = a.corsoDescrizione ?? 'Nessun corso';
      } else if (_groupBy == 'scuola') {
        key = a.scuolaNome ?? 'Nessuna scuola';
      }
      groups.putIfAbsent(key, () => []).add(a);
    }

    return ListView(
      children: groups.entries.map((entry) {
        return ExpansionTile(
          initiallyExpanded: true,
          title: Text('${entry.key} (${entry.value.length} allievi)', style: const TextStyle(fontWeight: FontWeight.bold)),
          children: entry.value.map(_buildAllievoTile).toList(),
        );
      }).toList(),
    );
  }
}
