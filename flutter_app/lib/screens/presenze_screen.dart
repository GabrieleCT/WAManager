import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class PresenzeScreen extends StatefulWidget {
  const PresenzeScreen({super.key});

  @override
  State<PresenzeScreen> createState() => _PresenzeScreenState();
}

class _PresenzeScreenState extends State<PresenzeScreen> {
  final ApiService _api = ApiService();
  List<Lezione> _lezioni = [];
  Lezione? _selectedLezione;
  List<Presenza> _presenze = [];
  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _matchStats;

  @override
  void initState() {
    super.initState();
    _loadLezioni();
  }

  Future<void> _loadLezioni() async {
    setState(() => _loading = true);
    final lezioni = await _api.getLezioni();
    setState(() {
      _lezioni = lezioni;
      if (lezioni.isNotEmpty) {
        _selectedLezione = lezioni.first;
      }
      _loading = false;
    });
    if (_selectedLezione != null) {
      _loadPresenze(_selectedLezione!.id);
    }
  }

  Future<void> _loadPresenze(String lezioneId) async {
    setState(() => _loading = true);
    final presenze = await _api.getPresenzeForLezione(lezioneId);
    setState(() {
      _presenze = presenze;
      _matchStats = null;
      _loading = false;
    });
  }

  Future<void> _savePresenze() async {
    if (_selectedLezione == null) return;
    setState(() => _saving = true);
    final payload = _presenze.map((p) => {'allievo_id': p.allievoId, 'presente': p.presente, 'fonte': p.fonte}).toList();
    final ok = await _api.batchUpdatePresenze(_selectedLezione!.id, payload);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Presenze salvate con successo!' : 'Errore nel salvataggio presenze.')),
      );
    }
  }

  Future<void> _generateMatches() async {
    if (_selectedLezione == null) return;
    setState(() => _loading = true);
    final res = await _api.generateMatches(_selectedLezione!.id);
    setState(() {
      _matchStats = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final presentiCount = _presenze.where((p) => p.presente).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenze Lezione'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedLezione != null) _loadPresenze(_selectedLezione!.id);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Icon(Icons.event, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLezione?.id,
                    decoration: const InputDecoration(
                      labelText: 'Seleziona Lezione',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _lezioni.map((l) {
                      return DropdownMenuItem(
                        value: l.id,
                        child: Text('${l.data} | ${l.corsoDescrizione}'),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final found = _lezioni.firstWhere((l) => l.id == id);
                        setState(() => _selectedLezione = found);
                        _loadPresenze(id);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_selectedLezione != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.deepPurple.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Presenti: $presentiCount su ${_presenze.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_alt, size: 18),
                        label: const Text('Inizializza'),
                        onPressed: () async {
                          await _api.initPresenzeLezione(_selectedLezione!.id);
                          _loadPresenze(_selectedLezione!.id);
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                        icon: const Icon(Icons.save, size: 18),
                        label: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Salva'),
                        onPressed: _saving ? null : _savePresenze,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_matchStats != null && _matchStats!['stats'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coppie generate: ${_matchStats!['stats']['pairs_count']} | Rotazioni: ${_matchStats!['stats']['rotating_leaders'] + _matchStats!['stats']['rotating_followers']}',
                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_presenze.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nessuna presenza registrata per questa lezione.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (_selectedLezione != null) {
                          await _api.initPresenzeLezione(_selectedLezione!.id);
                          _loadPresenze(_selectedLezione!.id);
                        }
                      },
                      child: const Text('Carica allievi del corso'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.blue.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Totali Leader: ${_presenze.where((p) => p.presente && p.allievoRuolo == 'leader').length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Totali Follower: ${_presenze.where((p) => p.presente && p.allievoRuolo == 'follower').length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Jolly necessari: ${(
                          _presenze.where((p) => p.presente && p.allievoRuolo == 'leader').length -
                          _presenze.where((p) => p.presente && p.allievoRuolo == 'follower').length
                        ).abs()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _presenze.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final p = _presenze[i];
                        return CheckboxListTile(
                          value: p.presente,
                          title: Row(
                            children: [
                              if (p.allievoIsProspect) ...[
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    border: Border.all(color: Colors.amber.shade400),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PROVA',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                              Expanded(child: Text(p.allievoNome, style: const TextStyle(fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: p.fonte == 'whatsapp' ? Colors.green.shade100 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.fonte.toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: p.fonte == 'whatsapp' ? Colors.green.shade800 : Colors.grey.shade800),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Ruolo: ${p.allievoRuolo} | Tel: ${p.allievoTelefono}'),
                          secondary: CircleAvatar(
                            backgroundColor: p.presente ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              p.presente ? Icons.check : Icons.close,
                              color: p.presente ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              p.presente = val ?? false;
                              p.fonte = 'manuale'; // User manual override
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                icon: const Icon(Icons.shuffle),
                label: const Text('Genera Coppie (Matching) per questa lezione'),
                onPressed: _presenze.isEmpty ? null : _generateMatches,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
