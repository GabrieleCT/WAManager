import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class JollyPanelScreen extends StatefulWidget {
  final bool embedded;
  const JollyPanelScreen({super.key, this.embedded = false});

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
    allievi.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
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

  void _showSendMessageDialog([Jolly? jolly]) {
    String? selectedJollyId = jolly?.id ?? (_jollyList.isNotEmpty ? _jollyList.first.id : null);
    String? selectedLezioneId = _lezioni.isNotEmpty ? _lezioni.first.id : null;
    final textController = TextEditingController(text: 'Ciao! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺');
    bool sending = false;
    Map<String, dynamic>? lastResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(jolly != null ? 'Invia Messaggio a ${jolly.allievoNome}' : 'Invia Messaggio Jolly'),
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

  Future<void> _deleteJolly(Jolly j) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Sei sicuro di voler rimuovere ${j.allievoNome} dall\'elenco dei Jolly?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _api.deleteJolly(j.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jolly ${j.allievoNome} eliminato con successo.'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errore durante l\'eliminazione del Jolly.')),
          );
        }
      }
      _loadData();
    }
  }

  Widget _buildJollyTile(Jolly j, bool isMobile) {
    if (isMobile) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          title: Text(
            j.allievoNome,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                tooltip: 'Invia messaggio jolly',
                onPressed: () => _showSendMessageDialog(j),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                tooltip: 'Modifica jolly',
                onPressed: () => _showAddJollyDialog(j),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                tooltip: 'Elimina jolly',
                onPressed: () => _deleteJolly(j),
              ),
            ],
          ),
          onTap: () => _showAddJollyDialog(j),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            Text(j.allievoNome, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Text(
                'Priorità ${j.priorita}',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📞 ${j.allievoTelefono.isNotEmpty ? j.allievoTelefono : "N/D"} | Ruolo: ${j.allievoRuoloDisplay} | Livello: ${j.allievoLivello}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF128C7E),
                side: const BorderSide(color: Color(0xFF25D366)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
              label: const Text('Invia Messaggio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showSendMessageDialog(j),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              tooltip: 'Modifica',
              onPressed: () => _showAddJollyDialog(j),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              tooltip: 'Elimina',
              onPressed: () => _deleteJolly(j),
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
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Pannello Jolly WhatsApp'),
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Ricarica dati'),
              ],
            ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: _showAddJollyDialog,
              tooltip: 'Nuovo Jolly',
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              onPressed: _showAddJollyDialog,
              label: const Text('Nuovo Jolly'),
              icon: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (widget.embedded && !isMobile)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Ricarica dati',
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _jollyList.isEmpty
                    ? const Center(
                        child: Text(
                          'Nessun Jolly designato.',
                          style: TextStyle(fontSize: 15, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _jollyList.length,
                        itemBuilder: (context, i) => _buildJollyTile(_jollyList[i], isMobile),
                      ),
          ),
        ],
      ),
    );
  }
}
