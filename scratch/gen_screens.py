import os
import re

base_dir = r"C:\Users\gabriele.cataldo\OneDrive - Banca Mediolanum SPA\Desktop\private\tango\gestionale\WAManager\flutter_app\lib\screens"

# 1. ScuoleScreen
scuole_screen = """import 'package:flutter/material.dart';
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
                  subtitle: Text('${s.sede}\\nWhatsApp: ${s.gruppoWhatsapp.isNotEmpty ? s.gruppoWhatsapp : "Non impostato"}'),
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
"""

with open(os.path.join(base_dir, "scuole_screen.dart"), "w") as f:
    f.write(scuole_screen)

# 2. CorsiScreen
corsi_screen = """import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CorsiScreen extends StatefulWidget {
  const CorsiScreen({super.key});
  @override
  State<CorsiScreen> createState() => _CorsiScreenState();
}

class _CorsiScreenState extends State<CorsiScreen> {
  final ApiService _api = ApiService();
  List<Corso> _corsi = [];
  List<Scuola> _scuole = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    setState(() {
      _corsi = corsi;
      _scuole = scuole;
      _loading = false;
    });
  }

  void _showAddCorsoDialog([Corso? corso]) {
    String? scuolaId = corso?.scuolaId ?? (_scuole.isNotEmpty ? _scuole.first.id : null);
    String livello = corso?.livello ?? 'principiante';
    final orarioCtl = TextEditingController(text: corso?.orario ?? '20:30');
    final annoCtl = TextEditingController(text: corso?.annoAccademico ?? '2025/2026');
    final waCtl = TextEditingController(text: corso?.gruppoWhatsapp ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(corso == null ? 'Nuovo Corso' : 'Modifica Corso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: scuolaId,
                  decoration: const InputDecoration(labelText: 'Scuola *'),
                  items: _scuole.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome))).toList(),
                  onChanged: (v) => setDState(() => scuolaId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: livello,
                  decoration: const InputDecoration(labelText: 'Livello *'),
                  items: const [
                    DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                    DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                    DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                  ],
                  onChanged: (v) => setDState(() => livello = v!),
                ),
                TextField(controller: orarioCtl, decoration: const InputDecoration(labelText: 'Orario (HH:MM) *')),
                TextField(controller: annoCtl, decoration: const InputDecoration(labelText: 'Anno Accademico *')),
                TextField(controller: waCtl, decoration: const InputDecoration(labelText: 'Gruppo WhatsApp Corso')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                if (scuolaId == null || orarioCtl.text.isEmpty) return;
                final data = {
                  'scuola': scuolaId,
                  'livello': livello,
                  'orario': orarioCtl.text.trim(),
                  'anno_accademico': annoCtl.text.trim(),
                  'gruppo_whatsapp': waCtl.text.trim(),
                };
                if (corso == null) {
                  await _api.createCorso(data);
                } else {
                  await _api.updateCorso(corso.id, data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAll();
              },
              child: const Text('Salva Corso'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corsi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCorsoDialog,
        label: const Text('Nuovo Corso'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _corsi.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = _corsi[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.class_)),
                  title: Text('${c.scuolaNome} - ${c.livelloDisplay}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Orario: ${c.orario} | Anno: ${c.annoAccademico}\\nWA: ${c.gruppoWhatsapp.isNotEmpty ? c.gruppoWhatsapp : "Non impostato"}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(label: Text('${c.allieviCount} iscritti')),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddCorsoDialog(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Conferma'), content: const Text('Eliminare corso?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Colors.red)))]));
                          if (confirm == true) { await _api.deleteCorso(c.id); _loadAll(); }
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
"""
with open(os.path.join(base_dir, "corsi_screen.dart"), "w") as f:
    f.write(corsi_screen)

# 3. ArgomentiScreen
argomenti_screen = """import 'package:flutter/material.dart';
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
"""
with open(os.path.join(base_dir, "argomenti_screen.dart"), "w") as f:
    f.write(argomenti_screen)

print("Created screens.")
