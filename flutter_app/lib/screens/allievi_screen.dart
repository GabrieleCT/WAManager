import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/google_sync_dialog.dart';

class AllieviScreen extends StatefulWidget {
  final bool embedded;
  const AllieviScreen({super.key, this.embedded = false});

  @override
  State<AllieviScreen> createState() => _AllieviScreenState();
}

class _AllieviScreenState extends State<AllieviScreen> {
  final ApiService _api = ApiService();
  List<Allievo> _allievi = [];
  List<Corso> _corsi = [];
  List<Scuola> _scuole = [];
  List<Pagamento> _pagamenti = [];
  bool _loading = true;
  String _groupBy = 'nessuno';
  bool _showMobileFilters = false; // 'nessuno', 'corso', 'scuola'
  String _searchQuery = '';
  String? _selectedScuolaId;
  String? _selectedCorsoId;
  String _filterWaScuola = 'tutti'; // 'tutti', 'si', 'no'
  String _filterWaCorso = 'tutti';  // 'tutti', 'si', 'no'
  String _filterNonPagato = 'tutti'; // 'tutti', 'T1', 'T2', 'T3'
  String _filterStatoTessera = 'tutti'; // 'tutti', 'ok', 'scaduta', 'non_tesserato'
  bool _syncingWhatsapp = false;

  List<Allievo> get _filteredAllievi {
    return _allievi.where((a) {
      if (_filterWaScuola == 'si' && !a.inGruppoScuolaWhatsapp) return false;
      if (_filterWaScuola == 'no' && a.inGruppoScuolaWhatsapp) return false;
      if (_filterWaCorso == 'si' && !a.inGruppoCorsoWhatsapp) return false;
      if (_filterWaCorso == 'no' && a.inGruppoCorsoWhatsapp) return false;
      
      if (_filterNonPagato != 'tutti') {
        final haPagato = _pagamenti.any((p) => p.allievoId == a.id && p.trimestre == _filterNonPagato);
        if (haPagato) return false;
      }

      if (_filterStatoTessera != 'tutti') {
        if (_filterStatoTessera == 'ok' && !a.hasTesseraOk) return false;
        if (_filterStatoTessera == 'scaduta' && !a.hasTesseraScaduta) return false;
        if (_filterStatoTessera == 'non_tesserato' && !a.isNonTesserato) return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _sortAllievi(List<Allievo> list) {
    list.sort((a, b) {
      int cmp = a.sortName.compareTo(b.sortName);
      if (cmp != 0) return cmp;
      return b.ruolo.compareTo(a.ruolo); // leader prima di follower
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    final corsi = await _api.getCorsi();
    final scuole = await _api.getScuole();
    final pagamenti = await _api.getPagamenti();
    final allievi = await _api.getAllievi(
      isProspect: false,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      scuolaId: _selectedScuolaId,
      corsoId: _selectedCorsoId == 'nessuno' ? null : _selectedCorsoId,
      corsoIsNull: _selectedCorsoId == 'nessuno' ? true : null,
    );
    _sortAllievi(allievi);
    if (mounted) {
      setState(() {
        _corsi = corsi;
        _scuole = scuole;
        _pagamenti = pagamenti;
        _allievi = allievi;
        _loading = false;
      });
    }
  }

  Future<void> _loadAllievi() async {
    setState(() => _loading = true);
    final pagamenti = await _api.getPagamenti();
    final allievi = await _api.getAllievi(
      isProspect: false,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      scuolaId: _selectedScuolaId,
      corsoId: _selectedCorsoId == 'nessuno' ? null : _selectedCorsoId,
      corsoIsNull: _selectedCorsoId == 'nessuno' ? true : null,
    );
    _sortAllievi(allievi);
    if (mounted) {
      setState(() {
        _pagamenti = pagamenti;
        _allievi = allievi;
        _loading = false;
      });
    }
  }

  Future<void> _syncWhatsapp() async {
    setState(() => _syncingWhatsapp = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Verifica presenza allievi nei gruppi WhatsApp (Scuola e Corsi) in corso...'),
            ),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    final res = await _api.syncWhatsappScuola();
    if (mounted) {
      setState(() => _syncingWhatsapp = false);
      if (res['success'] == true) {
        final total = res['total_allievi'] ?? 0;
        final inScuola = res['in_gruppo_scuola'] ?? 0;
        final inCorso = res['in_gruppo_corso'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              'Verifica completata su $total allievi: $inScuola presenti nel gruppo Scuola, $inCorso nel gruppo Corso.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        _loadAllievi();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(res['error'] ?? 'Errore durante la verifica WhatsApp'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }


  Future<void> _confirmAndAddToWhatsappScuola(Allievo a) async {
    if (a.telefono.isEmpty || a.telefono.toUpperCase() == 'TBD') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("L'allievo ${a.nomeCompleto} non ha un numero di telefono valido registrato."),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final scuolaNome = a.scuolaNome ?? 'della scuola';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group_add, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Aggiungi a WhatsApp Scuola'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vuoi aggiungere questo allievo al gruppo WhatsApp di $scuolaNome?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Allievo: ${a.nomeCompleto}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Telefono: ${a.telefono}'),
                  if (a.scuolaNome != null) Text('• Scuola: ${a.scuolaNome!}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Aggiungi a Scuola'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Aggiunta di ${a.nomeCompleto} al gruppo scuola in corso...'),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final res = await _api.addStudentToSchoolGroup(a.id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '${a.nomeCompleto} aggiunto con successo al gruppo WhatsApp Scuola!'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
      _loadAllievi();
    } else {
      final err = res['error'] ?? 'Impossibile aggiungere l\'allievo al gruppo.';
      final inviteLink = res['invite_link'];

      if (inviteLink != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restrizioni Privacy WhatsApp'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(err),
                const SizedBox(height: 12),
                const Text('Puoi inviare manualmente il link d\'invito all\'allievo:'),
                const SizedBox(height: 8),
                SelectableText(
                  inviteLink.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndAddToWhatsappCorso(Allievo a) async {
    if (a.telefono.isEmpty || a.telefono.toUpperCase() == 'TBD') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("L'allievo ${a.nomeCompleto} non ha un numero di telefono valido registrato."),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (a.corsoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("L'allievo ${a.nomeCompleto} non è associato ad alcun corso."),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final corsoDesc = a.corsoDescrizione ?? 'del corso';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group_add, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            const Text('Aggiungi a WhatsApp Corso'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vuoi aggiungere questo allievo al gruppo WhatsApp del corso?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Allievo: ${a.nomeCompleto}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Telefono: ${a.telefono}'),
                  Text('• Corso: $corsoDesc'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Aggiungi a Corso'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Aggiunta di ${a.nomeCompleto} al gruppo corso in corso...'),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final res = await _api.addStudentToCourseGroup(a.id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? '${a.nomeCompleto} aggiunto con successo al gruppo WhatsApp del corso!'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
      _loadAllievi();
    } else {
      final err = res['error'] ?? 'Impossibile aggiungere l\'allievo al gruppo del corso.';
      final inviteLink = res['invite_link'];

      if (inviteLink != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restrizioni Privacy WhatsApp'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(err),
                const SizedBox(height: 12),
                const Text('Puoi inviare manualmente il link d\'invito all\'allievo:'),
                const SizedBox(height: 8),
                SelectableText(
                  inviteLink.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }


  void _showAddEditDialog([Allievo? allievo]) {
    final nomeController = TextEditingController(text: allievo?.nome ?? '');
    final cognomeController = TextEditingController(text: allievo?.cognome ?? '');
    final telefonoController = TextEditingController(text: allievo?.telefono ?? '');
    final tesseraController = TextEditingController(text: allievo?.numeroTessera ?? '');
    DateTime? dataEmissione = (allievo?.dataEmissioneTessera != null && allievo!.dataEmissioneTessera!.isNotEmpty)
        ? DateTime.tryParse(allievo.dataEmissioneTessera!)
        : null;

    String ruolo = allievo?.ruolo ?? 'leader';
    String livello = allievo?.livello ?? 'principiante';
    String recensione = allievo?.recensione ?? 'no';
    String? selectedCorsoId = allievo?.corsoId;
    String? selectedScuolaId = allievo?.scuolaId;
    
    // Fallback se ci sono scuole e non è selezionata
    if (selectedScuolaId == null && _scuole.isNotEmpty) {
      selectedScuolaId = _scuole.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isMobile = MediaQuery.of(context).size.width < 800;
          final corsiFiltrati = _corsi.where((c) => 
            c.scuolaId == selectedScuolaId && c.livello == livello
          ).toList();

          if (selectedCorsoId != null && !corsiFiltrati.any((c) => c.id == selectedCorsoId)) {
            selectedCorsoId = corsiFiltrati.isNotEmpty ? corsiFiltrati.first.id : null;
          }

          return AlertDialog(
            title: Text(allievo == null ? 'Nuovo Allievo' : 'Modifica Allievo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                  ),
                  TextField(
                    controller: cognomeController,
                    decoration: const InputDecoration(labelText: 'Cognome *'),
                  ),
                  TextField(
                    controller: telefonoController,
                    decoration: const InputDecoration(labelText: 'Telefono (opzionale, es. +39333...)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: ruolo,
                    decoration: const InputDecoration(labelText: 'Ruolo'),
                    items: const [
                      DropdownMenuItem(value: 'leader', child: Text('Leader')),
                      DropdownMenuItem(value: 'follower', child: Text('Follower')),
                      DropdownMenuItem(value: 'both', child: Text('Entrambi (Both)')),
                    ],
                    onChanged: (v) => setDlgState(() => ruolo = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: livello,
                    decoration: const InputDecoration(labelText: 'Livello'),
                    items: const [
                      DropdownMenuItem(value: 'principiante', child: Text('Principiante')),
                      DropdownMenuItem(value: 'intermedio', child: Text('Intermedio')),
                      DropdownMenuItem(value: 'avanzato', child: Text('Avanzato')),
                    ],
                    onChanged: (v) => setDlgState(() {
                      livello = v!;
                      final matching = _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello).toList();
                      selectedCorsoId = matching.isNotEmpty ? matching.first.id : null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: recensione,
                    decoration: const InputDecoration(labelText: 'Recensione rilasciata'),
                    items: const [
                      DropdownMenuItem(value: 'si', child: Text('Sì')),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                    ],
                    onChanged: (v) => setDlgState(() => recensione = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedScuolaId,
                    decoration: const InputDecoration(labelText: 'Scuola'),
                    items: _scuole.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.nome),
                    )).toList(),
                    onChanged: (v) => setDlgState(() {
                      selectedScuolaId = v;
                      final matching = _corsi.where((c) => c.scuolaId == selectedScuolaId && c.livello == livello).toList();
                      selectedCorsoId = matching.isNotEmpty ? matching.first.id : null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedCorsoId,
                    decoration: const InputDecoration(labelText: 'Corso (associato al livello)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-- Nessun corso --')),
                      ...corsiFiltrati.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.scuolaNome} - ${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})'),
                          )),
                    ],
                    onChanged: (v) => setDlgState(() => selectedCorsoId = v),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Dati Tessera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tesseraController,
                    decoration: const InputDecoration(
                      labelText: 'Numero Tessera',
                      hintText: 'Es. 12345 / 2025-ABC',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                    title: Text(
                      dataEmissione == null
                          ? 'Nessuna data di emissione'
                          : 'Data emissione: ${DateFormat('dd/MM/yyyy').format(dataEmissione!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: dataEmissione == null ? Colors.grey.shade600 : Colors.black87,
                        fontWeight: dataEmissione == null ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        if (dataEmissione != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                            tooltip: 'Rimuovi data emissione',
                            onPressed: () => setDlgState(() => dataEmissione = null),
                          ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('Data', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dataEmissione ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDlgState(() => dataEmissione = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (allievo != null && allievo.partnerId != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Informazioni Coppia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pink)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.pink, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('In coppia con:', style: TextStyle(fontSize: 11, color: Colors.pink, fontWeight: FontWeight.w600)),
                                Text(
                                  allievo.partnerNomeCompleto.isNotEmpty ? allievo.partnerNomeCompleto : 'Partner assegnato',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.link_off, color: Colors.red, size: 18),
                            label: const Text('Scollega', style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              await _api.setPartner(allievo.id, null);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadAllievi();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (allievo != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'WhatsApp & Modulo Tesseramento',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'WhatsApp Scuola: ${allievo.inGruppoScuolaWhatsapp ? "Presente (Sì)" : "Non presente (No)"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: allievo.inGruppoScuolaWhatsapp ? Colors.green.shade900 : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              if (!allievo.inGruppoScuolaWhatsapp)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.group_add, size: 14),
                                  label: const Text('+ Scuola', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _confirmAndAddToWhatsappScuola(allievo),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'WhatsApp Corso: ${allievo.inGruppoCorsoWhatsapp ? "Presente (Sì)" : "Non presente (No)"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: allievo.inGruppoCorsoWhatsapp ? Colors.teal.shade900 : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              if (!allievo.inGruppoCorsoWhatsapp &&
                                  (allievo.corsoId != null && (allievo.corsoHasWhatsapp || (allievo.corsoGruppoWhatsapp != null && allievo.corsoGruppoWhatsapp!.isNotEmpty))))
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.group_add, size: 14),
                                  label: const Text('+ Corso', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _confirmAndAddToWhatsappCorso(allievo),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF128C7E),
                          side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                        label: const Text('Invia Modulo Tesseramento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _mostraInviaModuloTesseramentoDialog(allievo),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (allievo != null && !isMobile)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('Elimina', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeleteAllievo(allievo);
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.trim().isEmpty || cognomeController.text.trim().isEmpty) return;
                  final data = {
                    'nome': nomeController.text.trim(),
                    'cognome': cognomeController.text.trim(),
                    'telefono': telefonoController.text.trim(),
                    'ruolo': ruolo,
                    'livello': livello,
                    'recensione': recensione,
                    'corso': selectedCorsoId,
                    'is_prospect': false,
                    'numero_tessera': tesseraController.text.trim(),
                    'data_emissione_tessera': dataEmissione != null
                        ? DateFormat('yyyy-MM-dd').format(dataEmissione!)
                        : null,
                  };
                  final res = allievo == null
                      ? await _api.createAllievo(data)
                      : await _api.updateAllievo(allievo.id, data);

                  if (res == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Errore durante il salvataggio dell'allievo. Verifica i dati inseriti."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    if (res.googleSyncError != null && res.googleSyncError!.isNotEmpty) {
                      checkAndShowGoogleSyncError(
                        context,
                        entityType: 'Allievo',
                        name: res.nomeCompleto,
                        error: res.googleSyncError,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(allievo == null ? 'Allievo salvato con successo!' : 'Allievo aggiornato con successo!'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    }
                  }
                  _loadAllievi();
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _mostraInviaModuloTesseramentoDialog(Allievo a) async {
    final phoneController = TextEditingController(text: a.telefono);
    final messageController = TextEditingController(
      text: 'Gentile ${a.nomeCompleto}, in allegato ti inviamo il modulo per la richiesta o il rinnovo del tesseramento all\'ASD TantoTango da compilare e firmare. A presto!',
    );
    bool sending = false;
    bool loadingPreview = false;
    String? localError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
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
                    const Text('Invia Modulo Tesseramento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(a.nomeCompleto, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.indigo, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Allegato: Modulo_Tesseramento.pdf',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Allievo: ${a.nomeCompleto} • Stato tessera: ${a.statoTessera}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !sending,
                  decoration: InputDecoration(
                    labelText: 'Numero di Telefono WhatsApp *',
                    hintText: 'es. 393401234567 o 3401234567',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    helperText: a.telefono.isNotEmpty
                        ? 'Numero registrato per l\'allievo'
                        : 'Inserisci il numero con prefisso internazionale (es. 39...)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  enabled: !sending,
                  decoration: InputDecoration(
                    labelText: 'Messaggio di accompagnamento',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            OutlinedButton.icon(
              icon: loadingPreview
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.visibility, size: 16),
              label: const Text('Anteprima PDF'),
              onPressed: (sending || loadingPreview)
                  ? null
                  : () async {
                      setDlgState(() => loadingPreview = true);
                      try {
                        final bytes = await _api.getModuloTesseramentoPdf(a.id);
                        if (bytes != null && bytes.isNotEmpty) {
                          await Printing.layoutPdf(
                            onLayout: (PdfPageFormat format) async => bytes,
                            name: 'Modulo_Tesseramento_${a.cognome}_${a.nome}.pdf',
                          );
                        } else {
                          setDlgState(() => localError = 'Impossibile caricare il PDF del modulo.');
                        }
                      } catch (e) {
                        setDlgState(() => localError = 'Errore anteprima PDF: $e');
                      } finally {
                        setDlgState(() => loadingPreview = false);
                      }
                    },
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
              label: Text(sending ? 'Invio in corso...' : 'Invia PDF via WhatsApp'),
              onPressed: sending
                  ? null
                  : () async {
                      final phone = phoneController.text.trim();
                      if (phone.isEmpty) {
                        setDlgState(() => localError = 'Inserisci un numero di telefono valido.');
                        return;
                      }

                      setDlgState(() {
                        sending = true;
                        localError = null;
                      });

                      final res = await _api.sendModuloTesseramentoWhatsApp(
                        allievoId: a.id,
                        telefono: phone,
                        messaggio: messageController.text.trim(),
                      );

                      if (ctx.mounted) {
                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        res['message'] ?? 'Modulo di tesseramento inviato con successo a ${a.nomeCompleto} ($phone)!',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade700,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } else {
                          setDlgState(() {
                            sending = false;
                            localError = res['error'] ?? 'Errore durante l\'invio del messaggio.';
                          });
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatoTesseraBadge(Allievo a) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String label = a.statoTessera;

    if (a.hasTesseraOk) {
      bg = Colors.green.shade50;
      border = Colors.green.shade600;
      fg = Colors.green.shade900;
      icon = Icons.verified;
    } else if (a.hasTesseraScaduta) {
      bg = Colors.red.shade50;
      border = Colors.red.shade600;
      fg = Colors.red.shade900;
      icon = Icons.error_outline;
    } else {
      bg = Colors.orange.shade50;
      border = Colors.orange.shade600;
      fg = Colors.orange.shade900;
      icon = Icons.credit_card_off;
    }

    String tooltip = label;
    if (a.numeroTessera.isNotEmpty) {
      tooltip += ' (N. ${a.numeroTessera})';
    }
    if (a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty) {
      try {
        final d = DateTime.parse(a.dataEmissioneTessera!);
        tooltip += ' - Emessa il ${DateFormat('dd/MM/yyyy').format(d)}';
      } catch (_) {}
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsappScuolaBadge(Allievo a) {
    final bool inGruppo = a.inGruppoScuolaWhatsapp;
    if (inGruppo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade600, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'WhatsApp Scuola: Sì',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'WhatsApp Scuola: No',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => _confirmAndAddToWhatsappScuola(a),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_add, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  '+ Scuola',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsappCorsoBadge(Allievo a) {
    final bool inGruppo = a.inGruppoCorsoWhatsapp;
    if (inGruppo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.shade600, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.teal.shade700),
            const SizedBox(width: 4),
            Text(
              'WhatsApp Corso: Sì',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade900,
              ),
            ),
          ],
        ),
      );
    }

    final hasCorsoGroup = a.corsoId != null && (a.corsoHasWhatsapp || (a.corsoGruppoWhatsapp != null && a.corsoGruppoWhatsapp!.isNotEmpty));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'WhatsApp Corso: No',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        if (hasCorsoGroup) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _confirmAndAddToWhatsappCorso(a),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_add, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '+ Corso',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeleteAllievo(Allievo a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma eliminazione allievo'),
        content: Text(
          'Sei sicuro di voler eliminare l\'allievo ${a.nome} ${a.cognome}?\n\n'
          'L\'operazione comporterà automaticamente:\n'
          '• Rimozione dai gruppi WhatsApp (corso e scuola)\n'
          '• Eliminazione della chat WhatsApp\n'
          '• Eliminazione del contatto dalla Rubrica Google',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina definitivamente'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _api.deleteAllievo(a.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Allievo ${a.nome} ${a.cognome} eliminato dal sistema, dai gruppi WhatsApp, dalla chat e dalla rubrica Google.'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore durante l\'eliminazione dell\'allievo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      _loadAllievi();
    }
  }

  Widget _buildAllievoTile(Allievo a) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          title: Text(
            a.nomeCompleto,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                tooltip: 'Modifica allievo',
                onPressed: () => _showAddEditDialog(a),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                tooltip: 'Elimina allievo',
                onPressed: () => _confirmDeleteAllievo(a),
              ),
            ],
          ),
          onTap: () => _showAddEditDialog(a),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Row(children: [Text(a.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.bold)), if (a.partnerId != null) ...[const SizedBox(width: 8), const Icon(Icons.favorite, size: 16, color: Colors.pink)]]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📞 ${a.telefono}'),
            if (a.corsoDescrizione != null)
              Text('🎓 ${a.corsoDescrizione!}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (a.partnerId != null)
              Text('Partner: ${a.partnerNomeCompleto}', style: const TextStyle(fontSize: 12, color: Colors.pink)),
            if (a.numeroTessera.isNotEmpty || (a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '💳 Tessera: ${a.numeroTessera.isNotEmpty ? a.numeroTessera : "N/D"}${a.dataEmissioneTessera != null && a.dataEmissioneTessera!.isNotEmpty ? " (Emessa: ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(a.dataEmissioneTessera!) ?? DateTime.now())})" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildStatoTesseraBadge(a),
            Chip(
              label: Text(a.livelloDisplay, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
            _buildWhatsappScuolaBadge(a),
            _buildWhatsappCorsoBadge(a),
            if (a.recensione == 'si')
              const Tooltip(message: 'Recensione rilasciata', child: Icon(Icons.star, color: Colors.amber, size: 18)),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF128C7E),
                side: const BorderSide(color: Color(0xFF25D366)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
              label: const Text('Modulo Tesseramento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _mostraInviaModuloTesseramentoDialog(a),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _showAddEditDialog(a),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Conferma eliminazione allievo'),
                    content: Text(
                      'Sei sicuro di voler eliminare l\'allievo ${a.nome} ${a.cognome}?\n\n'
                      'L\'operazione comporterà automaticamente:\n'
                      '• Rimozione dai gruppi WhatsApp (corso e scuola)\n'
                      '• Eliminazione della chat WhatsApp\n'
                      '• Eliminazione del contatto dalla Rubrica Google',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Elimina definitivamente'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final ok = await _api.deleteAllievo(a.id);
                  if (mounted) {
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Allievo ${a.nome} ${a.cognome} eliminato dal sistema, dai gruppi WhatsApp, dalla chat e dalla rubrica Google.'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Errore durante l\'eliminazione dell\'allievo.'),
                          backgroundColor: Colors.red.shade800,
                        ),
                      );
                    }
                  }
                  _loadAllievi();
                }
              },
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
    final allieviVisualizzati = _filteredAllievi;

    final corsiFiltratiPerScuola = _selectedScuolaId == null
        ? _corsi
        : _corsi.where((c) => c.scuolaId == _selectedScuolaId).toList();

    final bool hasActiveFilters = _selectedScuolaId != null ||
        _selectedCorsoId != null ||
        _filterWaScuola != 'tutti' ||
        _filterWaCorso != 'tutti' ||
        _filterNonPagato != 'tutti' ||
        _filterStatoTessera != 'tutti';

    final actionButtons = isMobile ? <Widget>[] : [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _syncingWhatsapp
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.sync, size: 18),
        label: const Text(
          'Verifica WhatsApp',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: _syncingWhatsapp ? null : _syncWhatsapp,
      ),
      const SizedBox(width: 8),
      PopupMenuButton<String>(
        tooltip: 'Raggruppa per',
        icon: const Icon(Icons.group_work),
        onSelected: (val) => setState(() => _groupBy = val),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'nessuno', child: Text('Nessun raggruppamento')),
          PopupMenuItem(value: 'corso', child: Text('Raggruppa per Corso')),
          PopupMenuItem(value: 'scuola', child: Text('Raggruppa per Scuola')),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Ricarica dati',
        onPressed: _loadInitialData,
      ),
    ];

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Elenco Allievi'),
              actions: isMobile ? [] : actionButtons,
            ),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              tooltip: 'Nuovo Allievo',
              child: const Icon(Icons.person_add),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuovo Allievo'),
            ),
      body: Column(
        children: [
          if (widget.embedded && !isMobile)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  actionButtons[0], // Verifica WhatsApp
                  const Spacer(),
                  actionButtons[2], // PopupMenuButton
                  actionButtons[3], // Refresh
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cerca allievo per nome, cognome o tel...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _searchQuery = v;
                      _loadAllievi();
                    },
                  ),
                ),
                if (isMobile) ...[
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: hasActiveFilters,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: _showMobileFilters ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                      ),
                      icon: Icon(
                        _showMobileFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                        size: 20,
                        color: hasActiveFilters ? Theme.of(context).primaryColor : Colors.grey.shade700,
                      ),
                      label: Text(
                        _showMobileFilters ? 'Chiudi' : 'Filtri',
                        style: TextStyle(
                          color: hasActiveFilters ? Theme.of(context).primaryColor : Colors.grey.shade800,
                          fontWeight: hasActiveFilters ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onPressed: () => setState(() => _showMobileFilters = !_showMobileFilters),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Sezione Filtri Scuola, Corso e WhatsApp (nascosta di default su mobile)
          if (!isMobile || _showMobileFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 650;

                        final scuolaDropdown = DropdownButtonFormField<String?>(
                          value: _selectedScuolaId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Filtra per Scuola',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.school, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tutte le scuole')),
                            ..._scuole.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.nome, overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedScuolaId = v;
                              if (_selectedCorsoId != null) {
                                final corsoStillValid = corsiFiltratiPerScuola.any((c) => c.id == _selectedCorsoId && (v == null || c.scuolaId == v));
                                if (!corsoStillValid) {
                                  _selectedCorsoId = null;
                                }
                              }
                            });
                            _loadAllievi();
                          },
                        );

                        final corsoDropdown = DropdownButtonFormField<String?>(
                          value: _selectedCorsoId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Filtra per Corso',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.class_, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tutti i corsi')),
                            const DropdownMenuItem(value: 'nessuno', child: Text('Nessun corso')),
                            ...corsiFiltratiPerScuola.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                _selectedScuolaId == null
                                    ? '${c.scuolaNome} - ${c.livelloDisplay} (${c.orario})'
                                    : '${c.livelloDisplay} (${c.giornoSettimanaDisplay} ${c.orario})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedCorsoId = v);
                            _loadAllievi();
                          },
                        );

                        final waScuolaDropdown = DropdownButtonFormField<String>(
                          value: _filterWaScuola,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Scuola',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tutti', child: Text('Tutti')),
                            DropdownMenuItem(value: 'si', child: Text('Solo nel gruppo (Sì)')),
                            DropdownMenuItem(value: 'no', child: Text('Solo assenti (No)')),
                          ],
                          onChanged: (v) => setState(() => _filterWaScuola = v!),
                        );

                        final waCorsoDropdown = DropdownButtonFormField<String>(
                          value: _filterWaCorso,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Corso',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.chat_outlined, size: 20, color: Colors.teal),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tutti', child: Text('Tutti')),
                            DropdownMenuItem(value: 'si', child: Text('Solo nel gruppo (Sì)')),
                            DropdownMenuItem(value: 'no', child: Text('Solo assenti (No)')),
                          ],
                          onChanged: (v) => setState(() => _filterWaCorso = v!),
                        );

                        final nonPagatoDropdown = DropdownButtonFormField<String>(
                          value: _filterNonPagato,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Stato Pagamento',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.money_off, size: 20, color: Colors.red),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tutti', child: Text('Tutti (Nessun filtro)')),
                            DropdownMenuItem(value: 'T1', child: Text('Non ha pagato T1')),
                            DropdownMenuItem(value: 'T2', child: Text('Non ha pagato T2')),
                            DropdownMenuItem(value: 'T3', child: Text('Non ha pagato T3')),
                          ],
                          onChanged: (v) => setState(() => _filterNonPagato = v!),
                        );

                        final statoTesseraDropdown = DropdownButtonFormField<String>(
                          value: _filterStatoTessera,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Stato Tessera',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.badge, size: 20, color: Colors.blueGrey),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tutti', child: Text('Tutte le tessere')),
                            DropdownMenuItem(value: 'ok', child: Text('TESSERA OK')),
                            DropdownMenuItem(value: 'scaduta', child: Text('TESSERA SCADUTA')),
                            DropdownMenuItem(value: 'non_tesserato', child: Text('NON TESSERATO')),
                          ],
                          onChanged: (v) => setState(() => _filterStatoTessera = v!),
                        );

                        if (isCompact) {
                          return Column(
                            children: [
                              scuolaDropdown,
                              const SizedBox(height: 8),
                              corsoDropdown,
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: nonPagatoDropdown),
                                  const SizedBox(width: 8),
                                  Expanded(child: statoTesseraDropdown),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: waScuolaDropdown),
                                  const SizedBox(width: 8),
                                  Expanded(child: waCorsoDropdown),
                                ],
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: scuolaDropdown),
                                  const SizedBox(width: 12),
                                  Expanded(child: corsoDropdown),
                                  const SizedBox(width: 12),
                                  Expanded(child: statoTesseraDropdown),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: waScuolaDropdown),
                                  const SizedBox(width: 12),
                                  Expanded(child: waCorsoDropdown),
                                  const SizedBox(width: 12),
                                  Expanded(child: nonPagatoDropdown),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    // Summary Chips & Reset
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.people, size: 16),
                          label: Text('Visualizzati: ${allieviVisualizzati.length} / ${_allievi.length}'),
                        ),

                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green.shade50,
                          avatar: Icon(Icons.verified, size: 16, color: Colors.green.shade800),
                          label: Text(
                            'Tessera OK: ${allieviVisualizzati.where((a) => a.hasTesseraOk).length}',
                            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.red.shade50,
                          avatar: Icon(Icons.error_outline, size: 16, color: Colors.red.shade800),
                          label: Text(
                            'Tessera Scaduta: ${allieviVisualizzati.where((a) => a.hasTesseraScaduta).length}',
                            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.orange.shade50,
                          avatar: Icon(Icons.credit_card_off, size: 16, color: Colors.orange.shade800),
                          label: Text(
                            'Non Tesserati: ${allieviVisualizzati.where((a) => a.isNonTesserato).length}',
                            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green.shade50,
                          avatar: Icon(Icons.check_circle, size: 16, color: Colors.green.shade800),
                          label: Text(
                            'WA Scuola: ${allieviVisualizzati.where((a) => a.inGruppoScuolaWhatsapp).length}',
                            style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.teal.shade50,
                          avatar: Icon(Icons.chat, size: 16, color: Colors.teal.shade800),
                          label: Text(
                            'WA Corso: ${allieviVisualizzati.where((a) => a.inGruppoCorsoWhatsapp).length}',
                            style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_selectedScuolaId != null || _selectedCorsoId != null || _filterWaScuola != 'tutti' || _filterWaCorso != 'tutti' || _filterNonPagato != 'tutti' || _filterStatoTessera != 'tutti')
                          TextButton.icon(
                            icon: const Icon(Icons.filter_alt_off, size: 18),
                            label: const Text('Azzera filtri'),
                            onPressed: () {
                              setState(() {
                                _selectedScuolaId = null;
                                _selectedCorsoId = null;
                                _filterWaScuola = 'tutti';
                                _filterWaCorso = 'tutti';
                                _filterNonPagato = 'tutti';
                                _filterStatoTessera = 'tutti';
                              });
                              _loadAllievi();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (allieviVisualizzati.isEmpty)
            const Expanded(child: Center(child: Text('Nessun allievo trovato per i filtri selezionati.')))
          else
            Expanded(
              child: _groupBy == 'nessuno'
                  ? ListView.builder(
                      itemCount: allieviVisualizzati.length,
                      itemBuilder: (_, i) => _buildAllievoTile(allieviVisualizzati[i]),
                    )
                  : _buildGroupedList(allieviVisualizzati),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Allievo> list) {
    final Map<String, List<Allievo>> groups = {};
    for (final a in list) {
      String key = 'Non assegnato';
      if (_groupBy == 'corso') {
        key = a.corsoDescrizione ?? 'Nessun corso';
      } else if (_groupBy == 'scuola') {
        key = a.scuolaNome ?? 'Nessuna scuola';
      }
      groups.putIfAbsent(key, () => []).add(a);
    }

    return ListView(
      children: groups.entries.map((entry) {
        return ExpansionTile(
          initiallyExpanded: true,
          title: Text('${entry.key} (${entry.value.length} allievi)', style: const TextStyle(fontWeight: FontWeight.bold)),
          children: entry.value.map(_buildAllievoTile).toList(),
        );
      }).toList(),
    );
  }
}

