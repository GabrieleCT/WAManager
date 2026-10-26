import 'package:flutter/material.dart';

import '../models/models.dart';

import '../services/api_service.dart';

import '../widgets/google_sync_dialog.dart';
import '../widgets/delete_allievo_dialog.dart';



class ProspectsScreen extends StatefulWidget {

  final bool embedded;

  const ProspectsScreen({super.key, this.embedded = false});



  @override

  State<ProspectsScreen> createState() => _ProspectsScreenState();

}



class _ProspectsScreenState extends State<ProspectsScreen> {

  final ApiService _api = ApiService();

  

  List<Allievo> _prospects = [];

  List<Scuola> _scuole = [];

  List<Corso> _corsi = [];

  bool _loading = true;



  String _searchQuery = '';

  String? _selectedScuolaId;

  String? _selectedCorsoId;
  bool _showMobileFilters = false;





  @override

  void initState() {

    super.initState();

    _loadData();

  }



  Future<void> _loadData() async {

    setState(() => _loading = true);

    final prospects = await _api.getAllievi(

      isProspect: true,

      search: _searchQuery.isNotEmpty ? _searchQuery : null,

      scuolaId: _selectedScuolaId,

      corsoId: _selectedCorsoId == 'none' ? null : _selectedCorsoId,

    );

    final scuole = await _api.getScuole();

    final corsi = await _api.getCorsi();

    if (mounted) {

      setState(() {

        if (_selectedCorsoId == 'none') {

          _prospects = prospects.where((p) => p.corsoId == null).toList();

        } else {

          _prospects = prospects;

        }

        _scuole = scuole;

        _corsi = corsi;

        _loading = false;

      });

    }

  }



  void _showAddEditProspectDialog([Allievo? editingProspect]) {

    final nomeController = TextEditingController(text: editingProspect?.nome ?? '');

    final cognomeController = TextEditingController(text: editingProspect?.cognome ?? '');

    final telefonoController = TextEditingController(text: editingProspect?.telefono ?? '');

    final noteController = TextEditingController(text: editingProspect?.note ?? '');

    String ruolo = editingProspect?.ruolo ?? 'leader';

    String livello = editingProspect?.livello ?? 'principiante';

    String recensione = editingProspect?.recensione ?? 'no';



    String? selectedScuolaId = editingProspect?.scuolaId;

    String? selectedCorsoId = editingProspect?.corsoId;



    showDialog(

      context: context,

      builder: (ctx) => StatefulBuilder(

        builder: (ctx, setDlgState) {

          final filteredCorsi = (selectedScuolaId == null

              ? _corsi.where((c) => c.livello == livello)

              : _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello)).toList();



          if (selectedCorsoId != null && !filteredCorsi.any((c) => c.id == selectedCorsoId)) {

            selectedCorsoId = filteredCorsi.isNotEmpty ? filteredCorsi.first.id : null;

          }



          return AlertDialog(

            title: Text(editingProspect == null ? 'Nuovo Prospect' : 'Modifica Prospect'),

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

                    decoration: const InputDecoration(labelText: 'Telefono (opzionale, es. +39333...)'),

                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(

                    value: ruolo,

                    decoration: const InputDecoration(labelText: 'Ruolo preferito'),

                    items: const [

                      DropdownMenuItem(value: 'leader', child: Text('Leader')),

                      DropdownMenuItem(value: 'follower', child: Text('Follower')),

                      DropdownMenuItem(value: 'both', child: Text('Both')),

                    ],

                    onChanged: (v) => setDlgState(() => ruolo = v!),

                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(

                    value: livello,

                    decoration: const InputDecoration(labelText: 'Livello esperienza'),

                    items: const [

                      DropdownMenuItem(value: 'principiante', child: Text('Principiante')),

                      DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),

                      DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),

                    ],

                    onChanged: (v) => setDlgState(() {

                      livello = v!;

                      final matching = (selectedScuolaId == null

                          ? _corsi.where((c) => c.livello == livello)

                          : _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello)).toList();

                      if (selectedCorsoId != null || selectedScuolaId != null) {

                        selectedCorsoId = matching.isNotEmpty ? matching.first.id : null;

                      }

                    }),

                  ),

                  const SizedBox(height: 12),

                  // ASSEGNAZIONE SCUOLA OBBLIGATORIA

                  DropdownButtonFormField<String?>(

                    value: selectedScuolaId,

                    decoration: const InputDecoration(labelText: 'Scuola *'),

                    items: [

                      const DropdownMenuItem(value: null, child: Text('-- Seleziona una scuola --')),

                      ..._scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))),

                    ],

                    onChanged: (v) {

                      setDlgState(() {

                        selectedScuolaId = v;

                        final matching = (selectedScuolaId == null

                            ? _corsi.where((c) => c.livello == livello)

                            : _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello)).toList();

                        selectedCorsoId = matching.isNotEmpty ? matching.first.id : null;

                      });

                    },

                  ),

                  const SizedBox(height: 12),

                  // ASSEGNAZIONE CORSO OBBLIGATORIA

                  DropdownButtonFormField<String?>(

                    value: selectedCorsoId,

                    decoration: const InputDecoration(labelText: 'Corso di Prova assegnato *'),

                    items: [

                      const DropdownMenuItem(value: null, child: Text('-- Seleziona un corso --')),

                      ...filteredCorsi.map((c) => DropdownMenuItem(

                            value: c.id,

                            child: Text('${c.scuolaNome} - ${c.livelloDisplay} - ${c.giornoSettimanaDisplay} - ${c.orario}'),

                          )),

                    ],

                    onChanged: (v) => setDlgState(() => selectedCorsoId = v),

                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(

                    value: recensione,

                    decoration: const InputDecoration(labelText: 'Recensione preliminare'),

                    items: const [

                      DropdownMenuItem(value: 'si', child: Text('Sì')),

                      DropdownMenuItem(value: 'no', child: Text('No')),

                    ],

                    onChanged: (v) => setDlgState(() => recensione = v!),

                  ),

                  const SizedBox(height: 12),

                  if (editingProspect != null && editingProspect.partnerId != null) ...[

                    const SizedBox(height: 16),

                    Row(

                      children: [

                        Expanded(child: Text('Coppia con: ${editingProspect.partnerNomeCompleto}', style: const TextStyle(fontWeight: FontWeight.bold))),

                        TextButton.icon(

                          icon: const Icon(Icons.link_off, color: Colors.red, size: 18),

                          label: const Text('Rimuovi', style: TextStyle(color: Colors.red)),

                          onPressed: () async {

                            await _api.setPartner(editingProspect.id, null);

                            if (ctx.mounted) Navigator.pop(ctx);

                            _loadData();

                          },

                        )

                      ],

                    )

                  ],

                  TextField(

                    controller: noteController,

                    maxLines: 2,

                    decoration: const InputDecoration(

                      labelText: 'Note',

                      hintText: 'Disponibilità, richieste, lezione di prova fissata...',

                    ),

                  ),

                ],

              ),

            ),

            actions: [

              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),

              ElevatedButton(

                onPressed: () async {

                  if (nomeController.text.trim().isEmpty || 

                      cognomeController.text.trim().isEmpty || 

                      selectedScuolaId == null || 

                      selectedCorsoId == null) {

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compila tutti i campi obbligatori (*).')));

                    return;

                  }

                  final data = {

                    'nome': nomeController.text.trim(),

                    'cognome': cognomeController.text.trim(),

                    'telefono': telefonoController.text.trim(),

                    'ruolo': ruolo,

                    'livello': livello,

                    'corso': selectedCorsoId,

                    'recensione': recensione,

                    'is_prospect': true,

                    'note': noteController.text.trim().isNotEmpty ? noteController.text.trim() : 'Prospect',

                  };

                  final res = editingProspect == null

                      ? await _api.createAllievo(data)

                      : await _api.updateAllievo(editingProspect.id, data);



                  if (res == null) {

                    if (mounted) {

                      ScaffoldMessenger.of(context).showSnackBar(

                        const SnackBar(

                          content: Text('Errore durante il salvataggio del prospect. Verifica i dati inseriti.'),

                          backgroundColor: Colors.red,

                        ),

                      );

                    }

                    return;

                  }



                  if (ctx.mounted) Navigator.pop(ctx);

                  if (mounted) {

                    if (res.googleSyncError != null && res.googleSyncError!.isNotEmpty) {

                      checkAndShowGoogleSyncError(

                        context,

                        entityType: 'Prospect',

                        name: res.nomeCompleto,

                        error: res.googleSyncError,

                      );

                    } else {

                      ScaffoldMessenger.of(context).showSnackBar(

                        SnackBar(

                          content: Text(editingProspect == null ? 'Prospect salvato con successo!' : 'Prospect aggiornato con successo!'),

                          backgroundColor: Colors.green.shade800,

                        ),

                      );

                    }

                  }

                  _loadData();

                },

                child: Text(editingProspect == null ? 'Salva Prospect' : 'Aggiorna Prospect'),

              ),

            ],

          );

        },

      ),

    );

  }



  void _showConvertDialog(Allievo prospect) {

    String? selectedCorsoId = prospect.corsoId ?? (_corsi.isNotEmpty ? _corsi.first.id : null);



    showDialog(

      context: context,

      builder: (ctx) => StatefulBuilder(

        builder: (ctx, setDlgState) => AlertDialog(

          title: Text('Iscrivi ${prospect.nomeCompleto} ad un Corso'),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('Seleziona il corso a cui iscrivere l\'allievo per completare la conversione da Prospect ad Allievo Effettivo:'),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(

                initialValue: selectedCorsoId,

                decoration: const InputDecoration(labelText: 'Corso di destinazione *'),

                items: _corsi.map((c) {

                  return DropdownMenuItem(

                    value: c.id,

                    child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})'),

                  );

                }).toList(),

                onChanged: (v) => setDlgState(() => selectedCorsoId = v),

              ),

            ],

          ),

          actions: [

            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),

            ElevatedButton.icon(

              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),

              icon: const Icon(Icons.check),

              label: const Text('Conferma Iscrizione'),

              onPressed: () async {

                if (selectedCorsoId == null) return;

                final res = await _api.convertProspectToStudent(prospect.id, selectedCorsoId!);

                if (ctx.mounted) Navigator.pop(ctx);

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

                      SnackBar(content: Text('${prospect.nomeCompleto} iscritto al corso con successo!')),

                    );

                  }

                }

                _loadData();

              },

            ),

          ],

        ),

      ),

    );

  }



  Future<void> _deleteProspect(Allievo p) async {
    final deleted = await showDeleteAllievoDialog(context, allievo: p);
    if (deleted == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prospect ${p.nomeCompleto} eliminato con successo.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(

      appBar: widget.embedded

          ? null

          : AppBar(

              title: Text('Gestione Prospect (${_prospects.length})'),

              actions: [

                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),

              ],

            ),

      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showAddEditProspectDialog(),
              tooltip: 'Nuovo Prospect',
              child: const Icon(Icons.person_add_alt_1),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showAddEditProspectDialog(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuovo Prospect'),
            ),

      body: Builder(
        builder: (context) {
          final isMobile = MediaQuery.of(context).size.width < 800;
          final bool hasActiveFilters = _selectedScuolaId != null || _selectedCorsoId != null;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca prospect per nome, cognome o tel...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          _searchQuery = v;
                          _loadData();
                        },
                      ),
                    ),
                    if (isMobile) ...[
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: hasActiveFilters,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: _showMobileFilters ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                          ),
                          icon: Icon(
                            _showMobileFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                            size: 20,
                            color: hasActiveFilters ? Theme.of(context).primaryColor : Colors.grey.shade700,
                          ),
                          label: Text(
                            _showMobileFilters ? 'Chiudi' : 'Filtri',
                            style: TextStyle(
                              color: hasActiveFilters ? Theme.of(context).primaryColor : Colors.grey.shade800,
                              fontWeight: hasActiveFilters ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onPressed: () => setState(() => _showMobileFilters = !_showMobileFilters),
                        ),
                      ),
                    ] else if (widget.embedded) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Ricarica dati',
                        onPressed: _loadData,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isMobile || _showMobileFilters)
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

                        final corsiFiltratiPerScuola = _selectedScuolaId == null

                            ? _corsi

                            : _corsi.where((c) => c.scuolaId == _selectedScuolaId).toList();



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

                            _loadData();

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

                            const DropdownMenuItem(value: 'none', child: Text('Nessun corso associato')),

                            ...corsiFiltratiPerScuola.map((c) => DropdownMenuItem(

                              value: c.id,

                              child: Text(

                                _selectedScuolaId == null

                                    ? '${c.scuolaNome} - ${c.livelloDisplay} - ${c.giornoSettimanaDisplay} - ${c.orario}'

                                    : '${c.livelloDisplay} - ${c.giornoSettimanaDisplay} - ${c.orario}',

                                overflow: TextOverflow.ellipsis,

                              ),

                            )),

                          ],

                          onChanged: (v) {

                            setState(() => _selectedCorsoId = v);

                            _loadData();

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

                  ],

                ),

              ),

            ),

          ),

          Expanded(

            child: _loading

          ? const Center(child: CircularProgressIndicator())

          : _prospects.isEmpty

              ? const Center(child: Text('Nessun prospect registrato.'))

              : ListView.separated(

                  padding: const EdgeInsets.all(12),

                  itemCount: _prospects.length,

                  separatorBuilder: (_, __) => const Divider(height: 1),

                  itemBuilder: (ctx, i) {

                    final p = _prospects[i];

                    final hasCorso = p.corsoDescrizione != null && p.corsoDescrizione!.isNotEmpty;



                    if (isMobile) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(
                            p.nomeCompleto,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                tooltip: 'Modifica prospect',
                                onPressed: () => _showAddEditProspectDialog(p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Elimina prospect',
                                onPressed: () => _deleteProspect(p),
                              ),
                              IconButton(
                                icon: Icon(Icons.school, color: Theme.of(context).colorScheme.primary, size: 20),
                                tooltip: 'Iscrivi a Corso (Promuovi)',
                                onPressed: () => _showConvertDialog(p),
                              ),
                            ],
                          ),
                          onTap: () => _showAddEditProspectDialog(p),
                        ),
                      );
                    }

                    return Card(
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(p.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PROSPECT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('📞 ${p.telefono.isNotEmpty ? p.telefono : "N/D"} | Ruolo: ${p.ruoloDisplay} | Livello: ${p.livelloDisplay}'),
                            if (hasCorso) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Text(
                                  '🏷️ In prova nel corso: ${p.corsoDescrizione}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                            if (p.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('📝 Note: ${p.note}', style: const TextStyle(color: Colors.brown, fontStyle: FontStyle.italic)),
                              ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                              tooltip: 'Modifica prospect',
                              onPressed: () => _showAddEditProspectDialog(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              tooltip: 'Elimina prospect',
                              onPressed: () => _deleteProspect(p),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.school, size: 15),
                              label: const Text('Iscrivi a Corso'),
                              onPressed: () => _showConvertDialog(p),
                            ),
                          ],
                        ),
                      ),
                    );

                  },

                ),

          ),

            ],
          );
        },
      ),
    );

  }

}

