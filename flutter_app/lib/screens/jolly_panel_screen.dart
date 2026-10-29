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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _defaultJollyMessage = 'Ciao {nickname}! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final jolly = await _api.getJolly();
    jolly.sort((a, b) => a.priorita.compareTo(b.priorita));
    final lezioni = await _api.getLezioni();
    final allievi = await _api.getAllievi(isProspect: false);
    allievi.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    String defaultMsg = _defaultJollyMessage;
    try {
      final config = await _api.getDaemonConfig();
      if (config != null && config.jollyTesto.trim().isNotEmpty) {
        defaultMsg = config.jollyTesto.trim();
      }
    } catch (_) {}

    setState(() {
      _jollyList = jolly;
      _lezioni = lezioni;
      _allievi = allievi;
      _defaultJollyMessage = defaultMsg;
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
                onChanged: (v) {
                  setDState(() {
                    allievoId = v;
                  });
                },
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
                  await _api.updateJolly(jolly.id, allievoId!, priorita);
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

  Future<void> _showSendMessageDialog([Jolly? jolly]) async {
    // Ricarica sempre la configurazione più recente del messaggio jolly
    try {
      final config = await _api.getDaemonConfig();
      if (config != null && config.jollyTesto.trim().isNotEmpty) {
        _defaultJollyMessage = config.jollyTesto.trim();
      }
    } catch (_) {}
    if (!mounted) return;

    String? selectedJollyId = jolly?.id ?? (_jollyList.isNotEmpty ? _jollyList.first.id : null);
    String? selectedLezioneId = _lezioni.isNotEmpty ? _lezioni.first.id : null;

    final initialJolly = jolly ?? (_jollyList.isNotEmpty ? _jollyList.first : null);

    String buildJollyMsg(Jolly? targetJolly) {
      if (targetJolly == null) return _defaultJollyMessage;
      String nick = targetJolly.effectiveNickname;
      if (nick.isEmpty) {
        final a = _allievi.where((al) => al.id == targetJolly.allievoId).firstOrNull;
        if (a != null && a.nickname.trim().isNotEmpty) {
          nick = a.nickname.trim();
        } else if (a != null && a.nome.trim().isNotEmpty) {
          nick = a.nome.trim();
        } else {
          nick = targetJolly.allievoNome.split(' ').first;
        }
      }
      return _defaultJollyMessage
          .replaceAll('{nickname}', nick)
          .replaceAll('<nickname>', nick)
          .replaceAll('{allievo}', nick)
          .replaceAll('{nome}', nick)
          .replaceAll('<nome>', nick);
    }

    final textController = TextEditingController(text: buildJollyMsg(initialJolly));
    bool sending = false;
    String? localError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final currentJolly = _jollyList.where((j) => j.id == selectedJollyId).firstOrNull ?? initialJolly;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentJolly != null ? 'Invia Messaggio a ${currentJolly.allievoNome}' : 'Invia Messaggio Jolly',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (currentJolly != null)
                        Text(
                          'Nickname: ${currentJolly.effectiveNickname} • Ruolo: ${currentJolly.allievoRuoloDisplay}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (localError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localError!,
                                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    DropdownButtonFormField<String>(
                      value: selectedJollyId,
                      decoration: InputDecoration(
                        labelText: 'Seleziona Jolly',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.star, color: Colors.amber),
                      ),
                      items: _jollyList.map((j) => DropdownMenuItem(
                        value: j.id,
                        child: Text('${j.allievoNome} (${j.effectiveNickname})'),
                      )).toList(),
                      onChanged: (v) {
                        setDState(() {
                          selectedJollyId = v;
                          final selectedJolly = _jollyList.where((j) => j.id == v).firstOrNull;
                          if (selectedJolly != null) {
                            textController.text = buildJollyMsg(selectedJolly);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLezioneId,
                      decoration: InputDecoration(
                        labelText: 'Lezione di riferimento',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.event, color: Colors.blue),
                      ),
                      items: _lezioni.map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(
                          '${l.scuolaNome ?? ""} - ${l.corsoDescrizione} (${l.data})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (v) => setDState(() => selectedLezioneId = v),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Messaggio WhatsApp:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        InkWell(
                          onTap: () {
                            setDState(() {
                              textController.text = buildJollyMsg(currentJolly);
                            });
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restore, size: 14, color: Colors.blue),
                              SizedBox(width: 4),
                              Text('Ripristina predefinito', style: TextStyle(fontSize: 12, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Inserisci il messaggio per il jolly...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(sending ? 'Invio in corso...' : 'Invia via WhatsApp'),
                onPressed: sending
                    ? null
                    : () async {
                        if (selectedJollyId == null) {
                          setDState(() => localError = 'Seleziona un Jolly.');
                          return;
                        }
                        if (textController.text.trim().isEmpty) {
                          setDState(() => localError = 'Il testo del messaggio non può essere vuoto.');
                          return;
                        }
                        setDState(() {
                          sending = true;
                          localError = null;
                        });
                        final res = await _api.sendJollyMessage(
                          testo: textController.text.trim(),
                          lezioneIds: selectedLezioneId != null ? [selectedLezioneId!] : [],
                          jollyIds: [selectedJollyId!],
                          numJolly: null,
                        );

                        if (!ctx.mounted) return;
                        if (!mounted) return;

                        if (res['success'] == true && (res['inviati_con_successo'] ?? 0) > 0) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Messaggio WhatsApp inviato con successo a ${currentJolly?.allievoNome ?? "Jolly"}!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          setDState(() {
                            sending = false;
                            localError = res['error'] ?? 'Errore durante l\'invio del messaggio.';
                          });
                        }
                      },
              ),
            ],
          );
        },
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
      final bool isLeader = j.allievoRuolo.toLowerCase() == 'leader';
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: Icon(
            isLeader ? Icons.male : Icons.female,
            color: isLeader ? Colors.blue.shade700 : Colors.pink.shade700,
            size: 26,
          ),
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

    final bool isLeader = j.allievoRuolo.toLowerCase() == 'leader';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLeader ? Colors.blue.shade100 : Colors.pink.shade100,
          child: Icon(
            isLeader ? Icons.male : Icons.female,
            color: isLeader ? Colors.blue.shade800 : Colors.pink.shade800,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              j.allievoNome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
    final filteredJolly = _jollyList.where((j) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return j.displayName.toLowerCase().contains(q) || j.allievoNome.toLowerCase().contains(q) ||
          j.allievoTelefono.toLowerCase().contains(q);
    }).toList();

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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cerca jolly per nome o telefono...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                if (widget.embedded && !isMobile) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Ricarica dati',
                    onPressed: _loadData,
                  ),
                ],
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
                    : filteredJolly.isEmpty
                        ? const Center(
                            child: Text(
                              'Nessun Jolly trovato con i criteri di ricerca.',
                              style: TextStyle(fontSize: 15, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filteredJolly.length,
                            itemBuilder: (context, i) => _buildJollyTile(filteredJolly[i], isMobile),
                          ),
          ),
        ],
      ),
    );
  }
}
