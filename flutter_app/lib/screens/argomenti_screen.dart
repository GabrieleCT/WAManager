import 'dart:async';
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
  bool _savingOrder = false;
  Timer? _reorderDebounce;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _reorderDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final argomenti = await _api.getArgomenti();
    if (!mounted) return;
    setState(() {
      _argomenti = argomenti;
      _loading = false;
    });
  }

  String _searchQuery = '';
  String _filterLivello = 'tutti';

  List<Argomento> get _filteredArgomenti {
    return _argomenti.where((a) {
      if (_filterLivello != 'tutti' && a.livello != _filterLivello) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitolo = a.titolo.toLowerCase().contains(q);
        final matchesDesc = a.descrizione.toLowerCase().contains(q);
        if (!matchesTitolo && !matchesDesc) return false;
      }
      return true;
    }).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final filtered = _filteredArgomenti;
    final movedItem = filtered[oldIndex];
    final targetItem = filtered[newIndex];

    setState(() {
      _argomenti.removeWhere((a) => a.id == movedItem.id);
      final targetIdxInAll = _argomenti.indexWhere((a) => a.id == targetItem.id);
      if (targetIdxInAll != -1) {
        if (oldIndex < newIndex) {
          _argomenti.insert(targetIdxInAll + 1, movedItem);
        } else {
          _argomenti.insert(targetIdxInAll, movedItem);
        }
      } else {
        _argomenti.add(movedItem);
      }
    });

    _reorderDebounce?.cancel();
    _reorderDebounce = Timer(const Duration(milliseconds: 350), () {
      _saveNewOrder();
    });
  }

  Future<void> _saveNewOrder() async {
    setState(() => _savingOrder = true);
    final ids = _argomenti.map((a) => a.id).toList();
    final updated = await _api.reorderArgomenti(ids);
    if (!mounted) return;
    setState(() => _savingOrder = false);
    if (updated != null) {
      setState(() {
        _argomenti = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Nuova disposizione salvata con successo!'),
            ],
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante il salvataggio dell\'ordinamento.'),
          backgroundColor: Colors.red,
        ),
      );
      _loadAll();
    }
  }

  void _showAddEditArgomentoDialog([Argomento? a]) {
    final titoloCtl = TextEditingController(text: a?.titolo ?? '');
    final descCtl = TextEditingController(text: a?.descrizione ?? '');
    String livello = a?.livello ?? 'principiante';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(a == null ? 'Nuovo Argomento' : 'Modifica Argomento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titoloCtl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Titolo Argomento *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrizione / Dettagli', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: livello,
                  decoration: const InputDecoration(labelText: 'Livello', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                    DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                    DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                  ],
                  onChanged: (v) => setDState(() => livello = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: a == null ? Colors.teal : Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final titolo = titoloCtl.text.trim();
                if (titolo.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Il titolo dell\'argomento è obbligatorio.')),
                  );
                  return;
                }
                final data = {
                  'titolo': titolo,
                  'descrizione': descCtl.text.trim(),
                  'livello': livello,
                };
                final res = a == null
                    ? await _api.createArgomento(data)
                    : await _api.updateArgomento(a.id, data);

                if (res == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Errore durante il salvataggio dell\'argomento.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(a == null ? 'Argomento creato con successo!' : 'Argomento aggiornato con successo!'),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                }
                _loadAll();
              },
              child: Text(a == null ? 'Crea Argomento' : 'Salva Modifiche'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteArgomento(Argomento a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Sei sicuro di voler eliminare l\'argomento "${a.titolo}"?\nLe lezioni associate non avranno più questo argomento collegato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _api.deleteArgomento(a.id);
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Argomento "${a.titolo}" eliminato.'), backgroundColor: Colors.green.shade800),
                  );
                  _loadAll();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Errore durante l\'eliminazione dell\'argomento.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Widget _buildLivelloBadge(String livello, String display) {
    Color bg;
    Color fg;
    if (livello == 'avanzato') {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade800;
    } else if (livello == 'intermedio') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade900;
    } else {
      bg = Colors.green.shade50;
      fg = Colors.green.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        display.isNotEmpty ? display : livello,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredArgomenti;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Argomenti Lezioni'),
        actions: [
          if (_savingOrder)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditArgomentoDialog(),
        label: const Text('Nuovo Argomento'),
        icon: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barra Ricerca e Filtri
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade50,
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cerca per titolo o descrizione...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Livello: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: Text('Tutti (${_argomenti.length})'),
                                    selected: _filterLivello == 'tutti',
                                    onSelected: (s) {
                                      if (s) setState(() => _filterLivello = 'tutti');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: Text('Principiante (${_argomenti.where((a) => a.livello == 'principiante').length})'),
                                    selected: _filterLivello == 'principiante',
                                    onSelected: (s) {
                                      if (s) setState(() => _filterLivello = 'principiante');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: Text('Intermedio (${_argomenti.where((a) => a.livello == 'intermedio').length})'),
                                    selected: _filterLivello == 'intermedio',
                                    onSelected: (s) {
                                      if (s) setState(() => _filterLivello = 'intermedio');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: Text('Avanzato (${_argomenti.where((a) => a.livello == 'avanzato').length})'),
                                    selected: _filterLivello == 'avanzato',
                                    onSelected: (s) {
                                      if (s) setState(() => _filterLivello = 'avanzato');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Barra informativa per Drag & Drop
                if (filtered.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.amber.shade50.withValues(alpha: 0.6),
                    child: Row(
                      children: [
                        Icon(Icons.swap_vert, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Trascina le voci tenendo premuta l\'icona con i puntini (⠿) per riordinarle. L\'ordine verrà salvato automaticamente.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                        if (_savingOrder)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber.shade900),
                              ),
                              const SizedBox(width: 6),
                              Text('Salvataggio...', style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontStyle: FontStyle.italic)),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (filtered.isNotEmpty) const Divider(height: 1),

                // Lista Argomenti con Drag & Drop
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _argomenti.isEmpty
                                    ? 'Nessun argomento presente nel database.'
                                    : 'Nessun argomento corrisponde ai filtri impostati.',
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                              ),
                              if (_argomenti.isEmpty) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddEditArgomentoDialog(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crea Primo Argomento'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: filtered.length,
                          onReorder: _onReorder,
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Material(
                                  elevation: 6,
                                  color: Colors.transparent,
                                  shadowColor: Colors.black38,
                                  borderRadius: BorderRadius.circular(8),
                                  child: child,
                                );
                              },
                              child: child,
                            );
                          },
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          itemBuilder: (context, i) {
                            final a = filtered[i];
                            return Container(
                              key: ValueKey(a.id),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: Tooltip(
                                        message: 'Trascina per riordinare',
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                            child: Icon(
                                              Icons.drag_indicator,
                                              color: Colors.grey.shade500,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    CircleAvatar(
                                      backgroundColor: Colors.teal.shade50,
                                      foregroundColor: Colors.teal.shade800,
                                      child: const Icon(Icons.menu_book, size: 20),
                                    ),
                                  ],
                                ),
                                title: Text(a.titolo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    a.descrizione.isNotEmpty ? a.descrizione : 'Nessuna descrizione specificata',
                                    style: TextStyle(
                                      color: a.descrizione.isNotEmpty ? Colors.grey.shade800 : Colors.grey.shade500,
                                      fontStyle: a.descrizione.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _buildLivelloBadge(a.livello, a.livelloDisplay),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      tooltip: 'Modifica Argomento',
                                      onPressed: () => _showAddEditArgomentoDialog(a),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      tooltip: 'Elimina Argomento',
                                      onPressed: () => _confirmDeleteArgomento(a),
                                    ),
                                  ],
                                ),
                                onTap: () => _showAddEditArgomentoDialog(a),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
