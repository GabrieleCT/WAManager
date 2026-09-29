import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ArgomentiScreen extends StatefulWidget {
  const ArgomentiScreen({super.key});
  @override
  State<ArgomentiScreen> createState() => _ArgomentiScreenState();
}

class _ArgomentiScreenState extends State<ArgomentiScreen> {
  final ApiService _api = ApiService();
  List<Argomento> _argomenti = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final argomenti = await _api.getArgomenti();
    setState(() {
      _argomenti = argomenti;
      _loading = false;
    });
  }

  void _showAddArgomentoDialog() {
    final titoloCtl = TextEditingController();
    final descCtl = TextEditingController();
    String livello = 'principiante';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Nuovo Argomento Lezione'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titoloCtl, decoration: const InputDecoration(labelText: 'Titolo Argomento *')),
              TextField(controller: descCtl, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrizione')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: livello,
                decoration: const InputDecoration(labelText: 'Livello'),
                items: const [
                  DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                  DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                  DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                ],
                onChanged: (v) => setDState(() => livello = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                if (titoloCtl.text.isEmpty) return;
                await _api.createArgomento({
                  'titolo': titoloCtl.text.trim(),
                  'descrizione': descCtl.text.trim(),
                  'livello': livello,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              child: const Text('Salva Argomento'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Argomenti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddArgomentoDialog,
        label: const Text('Nuovo Argomento'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _argomenti.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = _argomenti[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                  title: Text(a.titolo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(a.descrizione.isNotEmpty ? a.descrizione : 'Nessuna descrizione'),
                  trailing: Chip(label: Text(a.livelloDisplay)),
                );
              },
            ),
    );
  }
}
