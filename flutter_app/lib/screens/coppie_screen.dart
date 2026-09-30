import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CoppieScreen extends StatefulWidget {
  const CoppieScreen({super.key});

  @override
  State<CoppieScreen> createState() => _CoppieScreenState();
}

class _CoppieScreenState extends State<CoppieScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  String _searchQuery = '';

  List<Scuola> _scuole = [];
  List<Corso> _corsi = [];
  List<Allievo> _allievi = [];

  String? _selectedScuolaId;
  String? _selectedCorsoId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getScuole(),
        _api.getCorsi(),
        _api.getAllievi(), // Restituisce sia allievi che prospect
      ]);
      if (!mounted) return;
      _scuole = results[0] as List<Scuola>;
      _corsi = results[1] as List<Corso>;
      _allievi = results[2] as List<Allievo>;
      _sortAllievi(_allievi);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il caricamento dei dati: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _sortAllievi(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  List<Allievo> _getFilteredAllievi() {
    return _allievi.where((a) {
      // Filtro Scuola
      if (_selectedScuolaId != null && a.scuolaId != _selectedScuolaId) {
        return false;
      }
      // Filtro Corso
      if (_selectedCorsoId != null && a.corsoId != _selectedCorsoId) {
        return false;
      }
      // Filtro Casella di Testo per Nome e/o Cognome
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final myName = '${a.nome} ${a.cognome} ${a.cognome} ${a.nome}'.toLowerCase();
        final partnerName = a.partnerNomeCompleto.toLowerCase();
        final combined = '$myName $partnerName';
        for (final w in words) {
          if (!combined.contains(w)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  void _showSetPartnerDialog(Allievo a) {
    String? chosenPartnerId = a.partnerId;
    String dlgSearch = '';
    final dlgSearchController = TextEditingController();

    // Tutti i possibili partner: tutti gli allievi/prospect tranne se stesso
    final tuttiCandidati = _allievi.where((alt) => alt.id != a.id).toList();
    tuttiCandidati.sort((c1, c2) => c1.cognome.toLowerCase().compareTo(c2.cognome.toLowerCase()));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final filteredCandidates = tuttiCandidati.where((c) {
              if (dlgSearch.isEmpty) return true;
              final q = dlgSearch.toLowerCase().trim();
              final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
              final target = '${c.nome} ${c.cognome} ${c.cognome} ${c.nome}'.toLowerCase();
              return words.every((w) => target.contains(w));
            }).toList();

            return AlertDialog(
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: a.ruolo == 'leader' ? Colors.blue.shade100 : Colors.pink.shade100,
                    child: Icon(
                      a.ruolo == 'leader' ? Icons.male : Icons.female,
                      color: a.ruolo == 'leader' ? Colors.blue.shade800 : Colors.pink.shade800,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Imposta Partner per',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${a.nomeCompleto} (${a.ruoloDisplay})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: dlgSearchController,
                      decoration: InputDecoration(
                        hintText: 'Cerca per nome e/o cognome...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: dlgSearch.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  dlgSearchController.clear();
                                  setDlgState(() => dlgSearch = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setDlgState(() => dlgSearch = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          children: [
                            RadioListTile<String?>(
                              value: null,
                              groupValue: chosenPartnerId,
                              activeColor: Colors.deepPurple,
                              title: const Text(
                                '-- Nessun partner (Singolo/a) --',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
                              ),
                              subtitle: const Text('Rimuove l\'associazione della coppia'),
                              onChanged: (v) => setDlgState(() => chosenPartnerId = v),
                            ),
                            const Divider(height: 1),
                            if (filteredCandidates.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'Nessun candidato trovato con questo nome.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ...filteredCandidates.map((c) {
                                final isSelected = c.id == chosenPartnerId;
                                final alreadyHasOtherPartner = c.partnerId != null && c.partnerId != a.id;
                                return RadioListTile<String?>(
                                  value: c.id,
                                  groupValue: chosenPartnerId,
                                  activeColor: Colors.deepPurple,
                                  title: Row(
                                    children: [
                                      Icon(
                                        c.ruolo == 'leader' ? Icons.male : Icons.female,
                                        size: 16,
                                        color: c.ruolo == 'leader' ? Colors.blue : Colors.pink,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${c.nomeCompleto} (${c.ruoloDisplay})',
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (c.isProspect)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.purple.shade300),
                                          ),
                                          child: Text(
                                            'PROSPECT',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.purple.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    alreadyHasOtherPartner
                                        ? 'Attualmente in coppia con: ${c.partnerNomeCompleto}'
                                        : (c.corsoDescrizione ?? (c.isProspect ? 'Prospect (nessun corso)' : 'Nessun corso')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: alreadyHasOtherPartner ? Colors.orange.shade800 : Colors.grey.shade600,
                                      fontStyle: alreadyHasOtherPartner ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                  onChanged: (v) => setDlgState(() => chosenPartnerId = v),
                                );
                              }),
                          ],
                        ),
                      ),
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
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    final ok = await _api.setPartner(a.id, chosenPartnerId);
                    if (ok) {
                      await _loadData(showLoading: false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(chosenPartnerId == null
                                ? 'Partner rimosso per ${a.nomeCompleto}'
                                : 'Coppia aggiornata con successo!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        setState(() => _loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Errore durante l\'impostazione del partner'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAllievi = _getFilteredAllievi();
    final isCompact = MediaQuery.of(context).size.width < 750;

    final corsiDisponibili = _selectedScuolaId == null
        ? _corsi
        : _corsi.where((c) => c.scuolaId == _selectedScuolaId).toList();

    final coppieCount = filteredAllievi.where((a) => a.partnerId != null).length;
    final singoliCount = filteredAllievi.where((a) => a.partnerId == null).length;
    final prospectCount = filteredAllievi.where((a) => a.isProspect).length;

    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Cerca allievo o prospect',
        hintText: 'Cerca per nome e/o cognome...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (v) => setState(() => _searchQuery = v),
    );

    final scuolaDropdown = DropdownButtonFormField<String?>(
      value: _selectedScuolaId,
      decoration: InputDecoration(
        labelText: 'Scuola',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.business, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Tutte le scuole --')),
        ..._scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))),
      ],
      onChanged: (v) {
        setState(() {
          _selectedScuolaId = v;
          if (_selectedCorsoId != null) {
            final valid = _corsi.any((c) => c.id == _selectedCorsoId && (v == null || c.scuolaId == v));
            if (!valid) _selectedCorsoId = null;
          }
        });
      },
    );

    final corsoDropdown = DropdownButtonFormField<String?>(
      value: _selectedCorsoId,
      decoration: InputDecoration(
        labelText: 'Corso',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.class_, size: 20),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('-- Tutti i corsi --')),
        ...corsiDisponibili.map((c) => DropdownMenuItem(
              value: c.id,
              child: Text(
                '${c.scuolaNome.isNotEmpty && _selectedScuolaId == null ? "${c.scuolaNome} - " : ""}${c.livelloDisplay} - ${c.giornoSettimanaDisplay} ${c.orario}',
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged: (v) => setState(() => _selectedCorsoId = v),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Coppie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica dati',
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filtri Ricerca e Selezione
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    if (isCompact) ...[
                      searchField,
                      const SizedBox(height: 10),
                      scuolaDropdown,
                      const SizedBox(height: 10),
                      corsoDropdown,
                    ] else ...[
                      Row(
                        children: [
                          Expanded(flex: 3, child: searchField),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: scuolaDropdown),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: corsoDropdown),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Summary Chips & Reset
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.people, size: 16),
                                label: Text('Totale: ${filteredAllievi.length} / ${_allievi.length}'),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.green.shade50,
                                avatar: Icon(Icons.favorite, size: 16, color: Colors.green.shade700),
                                label: Text(
                                  'In Coppia: $coppieCount',
                                  style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.blueGrey.shade50,
                                avatar: Icon(Icons.person, size: 16, color: Colors.blueGrey.shade700),
                                label: Text(
                                  'Singoli: $singoliCount',
                                  style: TextStyle(color: Colors.blueGrey.shade900),
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.purple.shade50,
                                avatar: Icon(Icons.contact_mail, size: 16, color: Colors.purple.shade700),
                                label: Text(
                                  'Prospect: $prospectCount',
                                  style: TextStyle(color: Colors.purple.shade900),
                                ),
                              ),
                              if (_selectedScuolaId != null || _selectedCorsoId != null || _searchQuery.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.filter_alt_off, size: 16),
                                  label: const Text('Azzera filtri'),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _selectedScuolaId = null;
                                      _selectedCorsoId = null;
                                      _searchQuery = '';
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Elenco Allievi e Prospect
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _allievi.isEmpty
                      ? const Center(
                          child: Text(
                            'Nessun allievo o prospect registrato a sistema.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        )
                      : filteredAllievi.isEmpty
                          ? const Center(
                              child: Text(
                                'Nessun allievo o prospect trovato per i filtri selezionati.',
                                style: TextStyle(fontSize: 15, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredAllievi.length,
                              itemBuilder: (context, index) {
                                final a = filteredAllievi[index];
                                final hasPartner = a.partnerId != null;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: hasPartner ? 1.5 : 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: hasPartner ? Colors.green.shade200 : Colors.grey.shade300,
                                      width: hasPartner ? 1.2 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          a.ruolo == 'leader' ? Colors.blue.shade100 : Colors.pink.shade100,
                                      child: Icon(
                                        a.ruolo == 'leader' ? Icons.male : Icons.female,
                                        color: a.ruolo == 'leader' ? Colors.blue.shade800 : Colors.pink.shade800,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            a.nomeCompleto,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (a.isProspect)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.purple.shade300),
                                            ),
                                            child: Text(
                                              'PROSPECT',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              hasPartner ? Icons.favorite : Icons.person_outline,
                                              size: 15,
                                              color: hasPartner ? Colors.pink : Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                hasPartner
                                                    ? 'Partner: ${a.partnerNomeCompleto}'
                                                    : 'Singolo/a (nessun partner)',
                                                style: TextStyle(
                                                  fontWeight: hasPartner ? FontWeight.w600 : FontWeight.normal,
                                                  color: hasPartner ? Colors.green.shade800 : Colors.grey.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          a.scuolaNome != null && a.corsoDescrizione != null
                                              ? '${a.scuolaNome!} • ${a.corsoDescrizione!}'
                                              : (a.corsoDescrizione ??
                                                  (a.isProspect
                                                      ? 'Non ancora iscritto a un corso'
                                                      : 'Nessun corso assegnato')),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    trailing: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            hasPartner ? Colors.orange.shade50 : Colors.deepPurple.shade50,
                                        foregroundColor:
                                            hasPartner ? Colors.orange.shade900 : Colors.deepPurple.shade900,
                                        elevation: 0,
                                        side: BorderSide(
                                          color:
                                              hasPartner ? Colors.orange.shade300 : Colors.deepPurple.shade300,
                                        ),
                                      ),
                                      icon: Icon(hasPartner ? Icons.edit : Icons.favorite, size: 16),
                                      label: Text(hasPartner ? 'Cambia/Rimuovi' : 'Associa'),
                                      onPressed: () => _showSetPartnerDialog(a),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
