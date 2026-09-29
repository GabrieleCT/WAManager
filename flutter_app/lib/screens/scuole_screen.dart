import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ScuoleScreen extends StatefulWidget {
  const ScuoleScreen({super.key});
  @override
  State<ScuoleScreen> createState() => _ScuoleScreenState();
}

class _ScuoleScreenState extends State<ScuoleScreen> {
  final ApiService _api = ApiService();
  List<Scuola> _scuole = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final scuole = await _api.getScuole();
    setState(() {
      _scuole = scuole;
      _loading = false;
    });
  }

  void _showAddScuolaDialog([Scuola? scuola]) {
    final nomeCtl = TextEditingController(text: scuola?.nome ?? '');
    final sedeCtl = TextEditingController(text: scuola?.sede ?? '');
    final waCtl = TextEditingController(text: scuola?.gruppoWhatsapp ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(scuola == null ? 'Nuova Scuola' : 'Modifica Scuola'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtl, decoration: const InputDecoration(labelText: 'Nome Scuola *')),
            TextField(controller: sedeCtl, decoration: const InputDecoration(labelText: 'Sede *')),
            TextField(controller: waCtl, decoration: const InputDecoration(labelText: 'Gruppo WhatsApp (opzionale)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              if (nomeCtl.text.isEmpty || sedeCtl.text.isEmpty) return;
              final data = {'nome': nomeCtl.text.trim(), 'sede': sedeCtl.text.trim(), 'gruppo_whatsapp': waCtl.text.trim()};
              if (scuola == null) {
                await _api.createScuola(data);
              } else {
                await _api.updateScuola(scuola.id, data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadAll();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scuole')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScuolaDialog,
        label: const Text('Nuova Scuola'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _scuole.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _scuole[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.business)),
                  title: Text(s.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${s.sede}\nWhatsApp: ${s.gruppoWhatsapp.isNotEmpty ? s.gruppoWhatsapp : "Non impostato"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(label: Text('${s.corsiCount} corsi')),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddScuolaDialog(s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Conferma'), content: const Text('Eliminare scuola?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Colors.red)))]));
                          if (confirm == true) { await _api.deleteScuola(s.id); _loadAll(); }
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
