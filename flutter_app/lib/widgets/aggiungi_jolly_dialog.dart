import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

typedef AggiungiJollySubmitCallback = Future<Map<String, dynamic>> Function(
  Allievo allievo,
  String testo,
  bool inviaWhatsapp,
);

class AggiungiJollyDialog extends StatefulWidget {
  final Lezione lezione;
  final List<Presenza> presenze;
  final List<Scuola> scuole;
  final String infoBilanciamento;
  final List<Allievo>? initialAllievi;
  final String? initialJollyTemplate;
  final AggiungiJollySubmitCallback? onSubmit;

  const AggiungiJollyDialog({
    super.key,
    required this.lezione,
    required this.presenze,
    required this.scuole,
    required this.infoBilanciamento,
    this.initialAllievi,
    this.initialJollyTemplate,
    this.onSubmit,
  });

  @override
  State<AggiungiJollyDialog> createState() => _AggiungiJollyDialogState();
}

class _AggiungiJollyDialogState extends State<AggiungiJollyDialog> {
  static const String _fallbackTemplate =
      'Ciao {nickname}! Abbiamo bisogno del tuo aiuto come Jolly per la lezione. Fammi sapere se sei disponibile! 💃🕺';

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _errorMsg;

  List<Allievo> _allievi = [];
  String _jollyTemplate = _fallbackTemplate;
  String _searchQuery = '';
  String _selectedRuolo = 'tutti';
  String? _selectedScuolaId;
  Allievo? _selectedAllievo;

  @override
  void initState() {
    super.initState();
    if (widget.initialAllievi != null) {
      _allievi = List<Allievo>.from(widget.initialAllievi!)
        ..sort((a, b) => a.sortName.compareTo(b.sortName));
      _jollyTemplate = (widget.initialJollyTemplate?.trim().isNotEmpty ?? false)
          ? widget.initialJollyTemplate!.trim()
          : _fallbackTemplate;
      _loading = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getAllievi(isProspect: false),
        _api.getDaemonConfig(),
      ]);
      if (!mounted) return;
      final allievi = (results[0] as List<Allievo>)
        ..sort((a, b) => a.sortName.compareTo(b.sortName));
      final cfg = results[1] as SondaggioMattutinoConfig?;
      final tmpl = (cfg != null && cfg.jollyTesto.trim().isNotEmpty)
          ? cfg.jollyTesto.trim()
          : _fallbackTemplate;

      setState(() {
        _allievi = allievi;
        _jollyTemplate = tmpl;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = 'Errore nel caricamento: $err';
      });
    }
  }

  String _buildPreviewFor(Allievo allievo) {
    final nick = allievo.nickname.trim().isNotEmpty
        ? allievo.nickname.trim()
        : allievo.nome.trim();
    return _jollyTemplate
        .replaceAll('{nickname}', nick)
        .replaceAll('<nickname>', nick)
        .replaceAll('<nome_allievo>', nick)
        .replaceAll('{nome_allievo}', nick)
        .replaceAll('{allievo}', nick)
        .replaceAll('{nome}', nick)
        .replaceAll('<nome>', nick);
  }

  bool _hasValidPhone(Allievo a) {
    final tel = a.telefono.trim();
    return tel.isNotEmpty && tel.toUpperCase() != 'TBD';
  }

  List<Allievo> get _filteredAllievi {
    final q = _searchQuery.trim().toLowerCase();
    return _allievi.where((a) {
      if (_selectedRuolo != 'tutti' &&
          a.ruolo.toLowerCase() != _selectedRuolo) {
        return false;
      }
      if (_selectedScuolaId != null && a.scuolaId != _selectedScuolaId) {
        return false;
      }
      if (q.isNotEmpty) {
        final full1 = '${a.nome} ${a.cognome}'.toLowerCase();
        final full2 = '${a.cognome} ${a.nome}'.toLowerCase();
        final nick = a.nickname.toLowerCase();
        if (!full1.contains(q) && !full2.contains(q) && !nick.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _selectAllievo(Allievo allievo) {
    setState(() {
      _selectedAllievo = allievo;
      _messageController.text = _buildPreviewFor(allievo);
    });
  }

  Future<void> _submit() async {
    final allievo = _selectedAllievo;
    if (allievo == null) return;

    final hasPhone = _hasValidPhone(allievo);
    final msg = _messageController.text.trim();
    if (hasPhone && msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci il testo del messaggio WhatsApp.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final res = widget.onSubmit != null
        ? await widget.onSubmit!(allievo, msg, hasPhone)
        : await _api.aggiungiJollyLezione(
            widget.lezione.id,
            allievo.id,
            testo: msg,
            inviaWhatsapp: hasPhone,
          );

    if (!mounted) return;
    Navigator.pop(context, res);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAllievi;
    final hasPhone =
        _selectedAllievo != null && _hasValidPhone(_selectedAllievo!);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.star, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(child: Text('Aggiungi Jolly alla Lezione')),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator()),
              )
            : _errorMsg != null
                ? Text(_errorMsg!, style: const TextStyle(color: Colors.red))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline,
                                  size: 20, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.infoBilanciamento,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Cerca allievo per nome o cognome',
                            hintText: 'Es. Mario Rossi...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedRuolo,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Ruolo',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'tutti',
                                      child: Text('Tutti i ruoli')),
                                  DropdownMenuItem(
                                      value: 'leader', child: Text('Leader')),
                                  DropdownMenuItem(
                                      value: 'follower',
                                      child: Text('Follower')),
                                  DropdownMenuItem(
                                      value: 'both',
                                      child: Text('Entrambi (Both)')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedRuolo = v ?? 'tutti'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _selectedScuolaId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Scuola',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Tutte le scuole')),
                                  ...widget.scuole.map(
                                    (s) => DropdownMenuItem<String?>(
                                      value: s.id,
                                      child: Text(s.nome,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedScuolaId = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Seleziona allievo (${filtered.length}):',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 190,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nessun allievo trovato con i filtri selezionati.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, idx) {
                                    final a = filtered[idx];
                                    final isSelected =
                                        _selectedAllievo?.id == a.id;
                                    final existing = widget.presenze
                                        .where((p) => p.allievoId == a.id)
                                        .firstOrNull;
                                    final giaPresente =
                                        existing?.presente == true;
                                    final giaInLista = existing != null;

                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: Colors.amber.shade50,
                                      leading: Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: isSelected
                                            ? Colors.amber.shade800
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      title: Text(
                                        a.nomeCompleto,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: giaPresente
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          a.ruoloDisplay.isNotEmpty
                                              ? a.ruoloDisplay
                                              : a.ruolo.toUpperCase(),
                                          if (a.scuolaNome != null &&
                                              a.scuolaNome!.isNotEmpty)
                                            a.scuolaNome!,
                                          if (giaPresente)
                                            'Già presente'
                                          else if (giaInLista)
                                            'Già in elenco',
                                        ].join(' • '),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onTap: () => _selectAllievo(a),
                                    );
                                  },
                                ),
                        ),
                        if (_selectedAllievo != null) ...[
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.chat,
                                  size: 18, color: Color(0xFF25D366)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  hasPhone
                                      ? 'Anteprima messaggio WhatsApp per ${_selectedAllievo!.nomeCompleto} (${_selectedAllievo!.telefono}):'
                                      : 'Messaggio WhatsApp non inviabile (nessun numero valido per ${_selectedAllievo!.nomeCompleto})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: hasPhone
                                        ? Colors.black87
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasPhone) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _messageController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Testo messaggio (modificabile)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: hasPhone
                ? Colors.green.shade700
                : Colors.amber.shade800,
            foregroundColor: Colors.white,
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Icon(hasPhone ? Icons.send : Icons.person_add, size: 18),
          label: Text(
            _submitting
                ? 'Invio in corso...'
                : (hasPhone
                    ? 'Aggiungi e Invia WhatsApp'
                    : 'Aggiungi come Jolly'),
          ),
          onPressed: (_submitting || _loading || _selectedAllievo == null)
              ? null
              : _submit,
        ),
      ],
    );
  }
}
