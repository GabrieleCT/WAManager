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

    bool isSaving = false;
    bool isVerifyingWa = false;
    String? waResolvedInfo;
    String? waResolvedError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(scuola == null ? 'Nuova Scuola' : 'Modifica Scuola'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nomeCtl,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Nome Scuola *'),
                ),
                TextField(
                  controller: sedeCtl,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Sede *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: waCtl,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Gruppo WhatsApp Scuola',
                    hintText: 'Link invito (es. https://chat.whatsapp.com/...) o ID',
                    helperText: 'Incolla il link d\'invito per risalire automaticamente al gruppo',
                    prefixIcon: const Icon(Icons.chat, color: Colors.green),
                    suffixIcon: isVerifyingWa
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.link_outlined, color: Colors.green),
                            tooltip: 'Verifica link invito',
                            onPressed: () async {
                              final text = waCtl.text.trim();
                              if (text.isEmpty) return;
                              setDState(() {
                                isVerifyingWa = true;
                                waResolvedInfo = null;
                                waResolvedError = null;
                              });
                              final res = await _api.resolveWhatsappGroup(text);
                              setDState(() {
                                isVerifyingWa = false;
                                if (res['success'] == true && res['groupId'] != null) {
                                  waResolvedInfo = '✓ Gruppo: ${res['subject']} (${res['size'] ?? 0} part.)';
                                  waCtl.text = res['groupId'];
                                } else {
                                  waResolvedError = res['error'] ?? 'Impossibile risalire al gruppo dal link';
                                }
                              });
                            },
                          ),
                  ),
                ),
                if (waResolvedInfo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        waResolvedInfo!,
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                if (waResolvedError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        waResolvedError!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nomeCtl.text.trim().isEmpty || sedeCtl.text.trim().isEmpty) return;
                      String waValue = waCtl.text.trim();

                      setDState(() {
                        isSaving = true;
                        waResolvedError = null;
                      });

                      // Se è un link d'invito o codice, risali al gruppo WhatsApp
                      if (waValue.isNotEmpty && (waValue.contains('chat.whatsapp.com') || !waValue.contains('@g.us'))) {
                        final res = await _api.resolveWhatsappGroup(waValue);
                        if (res['success'] == true && res['groupId'] != null) {
                          waValue = res['groupId'];
                        } else {
                          setDState(() {
                            isSaving = false;
                            waResolvedError = res['error'] ?? 'Impossibile risalire al gruppo WhatsApp. Verifica il link.';
                          });
                          return;
                        }
                      }

                      final data = {
                        'nome': nomeCtl.text.trim(),
                        'sede': sedeCtl.text.trim(),
                        'gruppo_whatsapp': waValue
                      };

                      bool ok = false;
                      if (scuola == null) {
                        final created = await _api.createScuola(data);
                        ok = created != null;
                      } else {
                        final updated = await _api.updateScuola(scuola.id, data);
                        ok = updated != null;
                      }

                      setDState(() => isSaving = false);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(waValue.isNotEmpty
                                  ? 'Scuola salvata! Gruppo WhatsApp collegato: $waValue'
                                  : 'Scuola salvata con successo!'),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Errore durante il salvataggio della scuola.'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      }
                      _loadAll();
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salva'),
            ),
          ],
        ),
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
