import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

typedef AggiungiJollySubmitCallback = Future<Map<String, dynamic>> Function(
  Allievo allievo,
  String testo,
  bool inviaWhatsapp,
);

typedef AggiungiJollyMultiSubmitCallback = Future<Map<String, dynamic>> Function(
  List<Allievo> allievi,
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
  final AggiungiJollyMultiSubmitCallback? onMultiSubmit;

  const AggiungiJollyDialog({
    super.key,
    required this.lezione,
    required this.presenze,
    required this.scuole,
    required this.infoBilanciamento,
    this.initialAllievi,
    this.initialJollyTemplate,
    this.onSubmit,
    this.onMultiSubmit,
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
  bool _inviaWhatsapp = true;
  String? _errorMsg;

  List<Allievo> _allievi = [];
  String _jollyTemplate = _fallbackTemplate;
  String _searchQuery = '';
  String _selectedRuolo = 'tutti';
  String? _selectedScuolaId;

  final Set<String> _selectedAllievoIds = <String>{};
  final Map<String, Allievo> _selectedAllievi = <String, Allievo>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialAllievi != null) {
      _allievi = List<Allievo>.from(widget.initialAllievi!)
        ..sort((a, b) => a.sortName.compareTo(b.sortName));
      _jollyTemplate = (widget.initialJollyTemplate?.trim().isNotEmpty ?? false)
          ? widget.initialJollyTemplate!.trim()
          : _fallbackTemplate;
      _messageController.text = _jollyTemplate;
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
        _messageController.text = tmpl;
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

  int get _selectedWithPhoneCount =>
      _selectedAllievi.values.where(_hasValidPhone).length;

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

  void _toggleAllievo(Allievo allievo) {
    setState(() {
      if (_selectedAllievoIds.contains(allievo.id)) {
        _selectedAllievoIds.remove(allievo.id);
        _selectedAllievi.remove(allievo.id);
      } else {
        _selectedAllievoIds.add(allievo.id);
        _selectedAllievi[allievo.id] = allievo;
        // Se è il primo o l'unico selezionato, sincronizza l'anteprima
        if (_selectedAllievi.length == 1) {
          _messageController.text = _buildPreviewFor(allievo);
        }
      }
    });
  }

  void _selectAllFiltered(List<Allievo> filtered) {
    setState(() {
      for (final a in filtered) {
        _selectedAllievoIds.add(a.id);
        _selectedAllievi[a.id] = a;
      }
      if (_selectedAllievi.length == 1) {
        _messageController.text = _buildPreviewFor(_selectedAllievi.values.first);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedAllievoIds.clear();
      _selectedAllievi.clear();
    });
  }

  Future<void> _submit() async {
    if (_selectedAllievi.isEmpty) return;

    final hasAnyPhone = _selectedWithPhoneCount > 0;
    final shouldSendWa = _inviaWhatsapp && hasAnyPhone;
    final msg = _messageController.text.trim();

    if (shouldSendWa && msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci il testo del messaggio WhatsApp.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final res = widget.onMultiSubmit != null
        ? await widget.onMultiSubmit!(
            _selectedAllievi.values.toList(),
            msg,
            shouldSendWa,
          )
        : (widget.onSubmit != null
            ? await widget.onSubmit!(
                _selectedAllievi.values.first,
                msg,
                shouldSendWa,
              )
            : await _api.aggiungiJollyLezione(
                widget.lezione.id,
                allievoIds: _selectedAllievoIds.toList(),
                testo: msg,
                inviaWhatsapp: shouldSendWa,
              ));

    if (!mounted) return;
    Navigator.pop(context, res);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAllievi;
    final selectedCount = _selectedAllievi.length;
    final withPhoneCount = _selectedWithPhoneCount;
    final withoutPhoneCount = selectedCount - withPhoneCount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              selectedCount > 1
                  ? 'Aggiungi Jolly alla Lezione ($selectedCount selezionati)'
                  : 'Aggiungi Jolly alla Lezione',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Seleziona allievi (${filtered.length} filtrati, $selectedCount selezionati):',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                if (filtered.isNotEmpty &&
                                    selectedCount < filtered.length)
                                  InkWell(
                                    onTap: () => _selectAllFiltered(filtered),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      child: Text(
                                        'Seleziona tutti',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (selectedCount > 0)
                                  InkWell(
                                    onTap: _clearSelection,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      child: Text(
                                        'Deseleziona',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
                                        _selectedAllievoIds.contains(a.id);
                                    final existing = widget.presenze
                                        .where((p) => p.allievoId == a.id)
                                        .firstOrNull;
                                    final giaPresente =
                                        existing?.presente == true;
                                    final giaInLista = existing != null;
                                    final hasPhone = _hasValidPhone(a);

                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: Colors.amber.shade50,
                                      leading: Icon(
                                        isSelected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: isSelected
                                            ? Colors.amber.shade800
                                            : Colors.grey,
                                        size: 22,
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
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
                                          ),
                                          if (!hasPhone)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'No tel',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange.shade900,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        [
                                          a.ruoloDisplay.isNotEmpty
                                              ? a.ruoloDisplay
                                              : a.ruolo.toUpperCase(),
                                          if (a.scuolaNome != null &&
                                              a.scuolaNome!.isNotEmpty)
                                            a.scuolaNome!,
                                          if (hasPhone) a.telefono,
                                          if (giaPresente)
                                            'Già presente'
                                          else if (giaInLista)
                                            'Già in elenco',
                                        ].join(' • '),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onTap: () => _toggleAllievo(a),
                                    );
                                  },
                                ),
                        ),
                        if (selectedCount > 0) ...[
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 6),

                          // Opzione: inviare o non inviare WhatsApp
                          Material(
                            color: _inviaWhatsapp
                                ? Colors.green.shade50
                                : Colors.blueGrey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _inviaWhatsapp
                                    ? Colors.green.shade300
                                    : Colors.blueGrey.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              child: CheckboxListTile(
                                value: _inviaWhatsapp,
                                onChanged: (val) =>
                                    setState(() => _inviaWhatsapp = val ?? true),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Row(
                                  children: [
                                    Icon(
                                      _inviaWhatsapp
                                          ? Icons.chat
                                          : Icons.chat_bubble_outline,
                                      size: 18,
                                      color: _inviaWhatsapp
                                          ? const Color(0xFF25D366)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Invia messaggio di richiesta disponibilità via WhatsApp',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  _inviaWhatsapp
                                      ? 'I Jolly verranno inseriti tra le presenze in attesa e riceveranno il messaggio WhatsApp.'
                                      : 'I Jolly verranno inseriti tra le presenze in attesa di risposta SENZA inviare messaggi WhatsApp.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _inviaWhatsapp
                                        ? Colors.green.shade900
                                        : Colors.blueGrey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          if (_inviaWhatsapp) ...[
                            if (withPhoneCount == 0)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.orange.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 18,
                                        color: Colors.orange.shade800),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Nessun allievo selezionato ha un numero di telefono registrato: verranno aggiunti senza invio WhatsApp.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              Row(
                                children: [
                                  const Icon(Icons.edit_note,
                                      size: 18, color: Color(0xFF25D366)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      selectedCount == 1
                                          ? 'Testo messaggio per ${_selectedAllievi.values.first.nomeCompleto}:'
                                          : 'Testo messaggio WhatsApp ($withPhoneCount destinatari con numero valido):',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _messageController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Testo messaggio (modificabile)',
                                  hintText: 'Usa {nickname} per personalizzare il nome...',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  helperText:
                                      'Il segnaposto {nickname} verrà sostituito automaticamente per ogni allievo.',
                                  helperStyle: const TextStyle(fontSize: 10),
                                ),
                              ),
                              if (withoutPhoneCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Nota: $withoutPhoneCount allievi senza telefono verranno aggiunti senza messaggio WhatsApp.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade800),
                                  ),
                                ),
                            ],
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 20, color: Colors.blue.shade800),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedCount == 1
                                          ? '${_selectedAllievi.values.first.nomeCompleto} verrà inserito tra le presenze come Jolly "In attesa di risposta".'
                                          : '$selectedCount allievi selezionati verranno inseriti tra le presenze come Jolly "In attesa di risposta".',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
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
            backgroundColor: (_inviaWhatsapp && withPhoneCount > 0)
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
              : Icon(
                  (_inviaWhatsapp && withPhoneCount > 0)
                      ? Icons.send
                      : Icons.person_add,
                  size: 18,
                ),
          label: Text(
            _submitting
                ? 'Operazione in corso...'
                : (_inviaWhatsapp && withPhoneCount > 0
                    ? (selectedCount > 1
                        ? 'Aggiungi ($selectedCount) e Invia WhatsApp'
                        : 'Aggiungi e Invia WhatsApp')
                    : (selectedCount > 1
                        ? 'Aggiungi ($selectedCount) in Attesa'
                        : 'Aggiungi come Jolly in Attesa')),
          ),
          onPressed: (_submitting || _loading || selectedCount == 0)
              ? null
              : _submit,
        ),
      ],
    );
  }
}
