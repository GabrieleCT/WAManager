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
  bool _loading = false;
  
  List<Scuola> _scuole = [];
  List<Corso> _corsi = [];
  
  String? _selectedScuolaId;
  String? _selectedCorsoId;
  
  List<Allievo> _allievi = [];

  @override
  void initState() {
    super.initState();
    _loadScuoleCorsi();
  }

  Future<void> _loadScuoleCorsi() async {
    setState(() => _loading = true);
    _scuole = await _api.getScuole();
    _corsi = await _api.getCorsi();
    setState(() => _loading = false);
  }


  void _sortAllievi(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  Future<void> _loadAllievi() async {
    if (_selectedCorsoId == null) {
      setState(() => _allievi = []);
      return;
    }
    setState(() => _loading = true);
    _allievi = await _api.getAllievi(corsoId: _selectedCorsoId);
    _sortAllievi(_allievi);
    setState(() => _loading = false);
  }

  void _showSetPartnerDialog(Allievo a) {
    String? chosenPartnerId = a.partnerId;
    final possibiliPartner = _allievi.where((alt) => alt.id != a.id).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Imposta Partner per ${a.nomeCompleto}'),
              content: DropdownButtonFormField<String?>(
                value: chosenPartnerId,
                decoration: const InputDecoration(labelText: 'Seleziona Partner'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- Nessun partner --')),
                  ...possibiliPartner.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.nomeCompleto} (${p.ruoloDisplay})'),
                      )),
                ],
                onChanged: (v) => setDlgState(() => chosenPartnerId = v),
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
                      await _loadAllievi();
                    } else {
                      setState(() => _loading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Errore durante l\'impostazione del partner')),
                      );
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
    final corsiScuola = _selectedScuolaId == null 
        ? <Corso>[] 
        : _corsi.where((c) => c.scuolaId == _selectedScuolaId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Coppie'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedScuolaId,
                    decoration: const InputDecoration(labelText: 'Scuola', border: OutlineInputBorder()),
                    items: _scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedScuolaId = v;
                        _selectedCorsoId = null;
                        _allievi = [];
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedCorsoId,
                    decoration: const InputDecoration(labelText: 'Corso', border: OutlineInputBorder()),
                    items: corsiScuola.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.livelloDisplay} - ${c.giornoSettimanaDisplay} - ${c.orario}'),
                        )).toList(),
                    onChanged: (v) {
                      setState(() => _selectedCorsoId = v);
                      if (v != null) _loadAllievi();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCorsoId == null
                      ? const Center(child: Text('Seleziona una scuola e un corso per gestire le coppie.'))
                      : _allievi.isEmpty
                          ? const Center(child: Text('Nessun allievo trovato per questo corso.'))
                          : ListView.builder(
                              itemCount: _allievi.length,
                              itemBuilder: (context, index) {
                                final a = _allievi[index];
                                final hasPartner = a.partnerId != null;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: a.ruolo == 'leader' ? Colors.blue.shade100 : Colors.pink.shade100,
                                      child: Icon(a.ruolo == 'leader' ? Icons.male : Icons.female, 
                                          color: a.ruolo == 'leader' ? Colors.blue : Colors.pink),
                                    ),
                                    title: Text(a.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(hasPartner ? 'Partner: ${a.partnerNomeCompleto}' : 'Singolo/a'),
                                    trailing: ElevatedButton.icon(
                                      icon: const Icon(Icons.favorite),
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
