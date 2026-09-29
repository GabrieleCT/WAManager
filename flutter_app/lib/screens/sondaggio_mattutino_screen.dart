import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SondaggioMattutinoScreen extends StatefulWidget {
  const SondaggioMattutinoScreen({super.key});

  @override
  State<SondaggioMattutinoScreen> createState() => _SondaggioMattutinoScreenState();
}

class _SondaggioMattutinoScreenState extends State<SondaggioMattutinoScreen> {
  final ApiService _api = ApiService();
  List<SondaggioMattutinoConfig> _sondaggi = [];
  List<Scuola> _scuole = [];
  List<Corso> _corsi = [];
  bool _loading = true;
  String? _sendingId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final sondaggi = await _api.getSondaggiMattutini();
    final scuole = await _api.getScuole();
    final corsi = await _api.getCorsi();
    setState(() {
      _sondaggi = sondaggi;
      _scuole = scuole;
      _corsi = corsi;
      _loading = false;
    });
  }

  void _showAddEditDialog([SondaggioMattutinoConfig? config]) {
    String? selectedScuolaId;
    String? selectedCorsoId;

    if (config != null) {
      selectedCorsoId = config.corsoId;
      final foundCorso = _corsi.where((c) => c.id == config.corsoId).firstOrNull;
      selectedScuolaId = foundCorso?.scuolaId;
    } else {
      if (_scuole.isNotEmpty) {
        selectedScuolaId = _scuole.first.id;
        final matching = _corsi.where((c) => c.scuolaId == selectedScuolaId).toList();
        if (matching.isNotEmpty) {
          selectedCorsoId = matching.first.id;
        }
      }
    }

    final testoCtl = TextEditingController(
      text: config?.testo ??
          'Buongiorno ragazzi! 🕺💃 Vi ricordiamo che oggi c\'è lezione per il corso {corso} alle {orario}.\nChi di voi sarà presente stasera? Rispondete a questo messaggio per confermare la vostra presenza!',
    );
    bool isActive = config?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final corsiFiltrati = selectedScuolaId == null
              ? _corsi
              : _corsi.where((c) => c.scuolaId == selectedScuolaId).toList();

          return AlertDialog(
            title: Text(config == null ? 'Nuova Automazione Sondaggio' : 'Modifica Automazione Sondaggio'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 550,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleziona il corso a cui associare questo messaggio. Tutte le mattine alle 08:00, se c\'è lezione in data odierna, il messaggio verrà inviato sul gruppo WhatsApp del corso.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedScuolaId,
                      decoration: const InputDecoration(
                        labelText: 'Scuola *',
                        prefixIcon: Icon(Icons.school),
                        border: OutlineInputBorder(),
                      ),
                      items: _scuole
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome)))
                          .toList(),
                      onChanged: (v) {
                        setDState(() {
                          selectedScuolaId = v;
                          final match = _corsi.where((c) => c.scuolaId == v).toList();
                          selectedCorsoId = match.isNotEmpty ? match.first.id : null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCorsoId,
                      decoration: const InputDecoration(
                        labelText: 'Corso *',
                        prefixIcon: Icon(Icons.class_),
                        border: OutlineInputBorder(),
                      ),
                      items: corsiFiltrati
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})'),
                              ))
                          .toList(),
                      onChanged: (v) => setDState(() => selectedCorsoId = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: testoCtl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Testo messaggio da inviare *',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        helperText: 'Tag dinamici disponibili: {corso}, {scuola}, {orario}, {data}',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automazione Attiva'),
                      subtitle: const Text('Se disattivata, il demone delle 8:00 salterà questo corso.'),
                      value: isActive,
                      onChanged: (v) => setDState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salva Automazione'),
                onPressed: () async {
                  if (selectedCorsoId == null || testoCtl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Compilare sia il corso che il testo del messaggio.')),
                    );
                    return;
                  }

                  final data = {
                    'corso': selectedCorsoId,
                    'testo': testoCtl.text.trim(),
                    'is_active': isActive,
                  };

                  if (config == null) {
                    await _api.createSondaggioMattutino(data);
                  } else {
                    await _api.updateSondaggioMattutino(config.id, data);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _inviaSubito(SondaggioMattutinoConfig config) async {
    setState(() => _sendingId = config.id);
    final res = await _api.inviaSondaggioOra(config.id);
    setState(() => _sendingId = null);

    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Messaggio inviato con successo al gruppo ${res['target'] ?? ""}!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore invio: ${res['error'] ?? "Impossibile inviare messaggio"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleAttivo(SondaggioMattutinoConfig config) async {
    await _api.updateSondaggioMattutino(config.id, {'is_active': !config.isActive});
    _loadData();
  }

  Future<void> _eliminaConfig(SondaggioMattutinoConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Sei sicuro di voler eliminare l\'automazione per il corso "${config.corsoDescrizione}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _api.deleteSondaggioMattutino(config.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sondaggio Mattutino'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuova Automazione'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue, size: 36),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automazione Sondaggio Mattutino (Ore 08:00)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tutte le mattine alle 08:00, il demone controlla il calendario delle lezioni odierne. '
                                  'Per ogni corso che ha lezione oggi, recupera il gruppo WhatsApp associato e invia automaticamente il messaggio configurato qui sotto.',
                                  style: TextStyle(fontSize: 13, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_sondaggi.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.mark_chat_unread_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'Nessuna automazione creata.',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Clicca su "Nuova Automazione" in basso a destra per associare un messaggio al gruppo WhatsApp di un corso.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._sondaggi.map((s) {
                      final isSendingThis = _sendingId == s.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: s.isActive ? Colors.green.shade200 : Colors.grey.shade300,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: s.isActive ? Colors.green.shade100 : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.campaign,
                                      color: s.isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${s.scuolaNome.isNotEmpty ? "${s.scuolaNome} - " : ""}${s.corsoDescrizione}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Gruppo WhatsApp: ${s.gruppoWhatsapp.isNotEmpty ? s.gruppoWhatsapp : "Non impostato sul corso (verrà cercato sulla scuola)"}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: s.isActive,
                                    activeThumbColor: Colors.green,
                                    onChanged: (_) => _toggleAttivo(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Modifica',
                                    onPressed: () => _showAddEditDialog(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Elimina',
                                    onPressed: () => _eliminaConfig(s),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  s.testo,
                                  style: const TextStyle(fontSize: 14, height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    icon: isSendingThis
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.send, size: 16),
                                    label: Text(isSendingThis ? 'Invio in corso...' : 'Invia ora per prova'),
                                    onPressed: isSendingThis ? null : () => _inviaSubito(s),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
