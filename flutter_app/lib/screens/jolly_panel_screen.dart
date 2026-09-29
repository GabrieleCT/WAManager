import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class JollyPanelScreen extends StatefulWidget {
  const JollyPanelScreen({super.key});

  @override
  State<JollyPanelScreen> createState() => _JollyPanelScreenState();
}

class _JollyPanelScreenState extends State<JollyPanelScreen> {
  final ApiService _api = ApiService();

  List<Jolly> _jollyList = [];
  List<Allievo> _allievi = [];
  List<Lezione> _lezioni = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final jolly = await _api.getJolly();
    jolly.sort((a, b) => a.priorita.compareTo(b.priorita));
    final lezioni = await _api.getLezioni();
    final allievi = await _api.getAllievi(isProspect: false);
    setState(() {
      _jollyList = jolly;
      _lezioni = lezioni;
      _allievi = allievi;
      _loading = false;
    });
  }

  void _showAddJollyDialog([Jolly? jolly]) {
    String? allievoId = jolly?.allievoId ?? (_allievi.isNotEmpty ? _allievi.first.id : null);
    int priorita = jolly?.priorita ?? 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(jolly == null ? 'Designa Nuovo Jolly' : 'Modifica Jolly'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: allievoId,
                decoration: const InputDecoration(labelText: 'Seleziona Allievo *'),
                items: _allievi.map((a) => DropdownMenuItem(value: a.id, child: Text(a.nomeCompleto))).toList(),
                onChanged: (v) => setDState(() => allievoId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: priorita,
                decoration: const InputDecoration(labelText: 'Priorità (1 = più alta)'),
                items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => DropdownMenuItem(value: n, child: Text('Priorità $n'))).toList(),
                onChanged: (v) => setDState(() => priorita = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                if (allievoId == null) return;
                if (jolly == null) {
                  await _api.createJolly(allievoId!, priorita);
                } else {
                  // Assuming you have an updateJolly method, though might just delete and recreate
                  // Wait, createJolly actually might just update if it exists or you need an update endpoint.
                  // For simplicity, we can do createJolly and backend handles or we add update.
                  // Let's assume API has updateJolly or we can delete and create.
                  // The prompt only says Add/Edit/Delete. Let's delete and create.
                  await _api.deleteJolly(jolly.id);
                  await _api.createJolly(allievoId!, priorita);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Salva Jolly'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendMessageDialog() {
    String? selectedJollyId = _jollyList.isNotEmpty ? _jollyList.first.id : null;
    String? selectedLezioneId = _lezioni.isNotEmpty ? _lezioni.first.id : null;
    final textController = TextEditingController(text: 'Ciao! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺');
    bool sending = false;
    Map<String, dynamic>? lastResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Invia Messaggio Jolly'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedJollyId,
                  decoration: const InputDecoration(labelText: 'Jolly'),
                  items: _jollyList.map((j) => DropdownMenuItem(value: j.id, child: Text(j.allievoNome))).toList(),
                  onChanged: (v) => setDState(() => selectedJollyId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLezioneId,
                  decoration: const InputDecoration(labelText: 'Lezione (Sede - Lezione - Orario)'),
                  items: _lezioni.map((l) => DropdownMenuItem(value: l.id, child: Text('${l.scuolaNome ?? ""} - ${l.corsoDescrizione} - ${l.data}'))).toList(),
                  onChanged: (v) => setDState(() => selectedLezioneId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Messaggio', border: OutlineInputBorder()),
                ),
                if (lastResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('Inviato: ${lastResult!['totale_contattati']} contatti'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
            ElevatedButton(
              onPressed: sending ? null : () async {
                if (selectedJollyId == null || selectedLezioneId == null || textController.text.trim().isEmpty) return;
                setDState(() => sending = true);
                final res = await _api.sendJollyMessage(
                  testo: textController.text.trim(),
                  lezioneIds: [selectedLezioneId!],
                  jollyIds: [selectedJollyId!],
                  numJolly: null,
                );
                setDState(() {
                  sending = false;
                  lastResult = res;
                });
              },
              child: sending ? const CircularProgressIndicator() : const Text('Invia Messaggio'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pannello Jolly WhatsApp'),
        actions: [
          IconButton(icon: const Icon(Icons.send), onPressed: _showSendMessageDialog, tooltip: 'Invia Messaggio'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddJollyDialog,
        label: const Text('Nuovo Jolly'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _jollyList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final j = _jollyList[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.shade100,
                    child: Text('${j.priorita}', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(j.allievoNome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Ruolo: ${j.allievoRuoloDisplay} | Livello: ${j.allievoLivello} | Tel: ${j.allievoTelefono}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddJollyDialog(j),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Conferma'), content: const Text('Eliminare jolly?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Colors.red)))]));
                          if (confirm == true) { await _api.deleteJolly(j.id); _loadData(); }
                        }
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
