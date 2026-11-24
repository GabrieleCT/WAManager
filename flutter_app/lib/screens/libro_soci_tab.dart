import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class LibroSociTab extends StatefulWidget {
  const LibroSociTab({super.key});

  @override
  State<LibroSociTab> createState() => _LibroSociTabState();
}

class _LibroSociTabState extends State<LibroSociTab> {
  final ApiService _api = ApiService();

  bool _loading = false;
  bool _exportingDrive = false;
  List<Socio> _soci = [];

  final _searchController = TextEditingController();
  String _filtroStato = 'tutti'; // Default 'tutti' in modo che i soci cessati rimangano visibili nel registro con stato 'Cessato'
  String _filtroCategoria = 'tutti';
  String _filtroOrigine = 'tutti';

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  @override
  void initState() {
    super.initState();
    _loadSoci();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSoci() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getSoci(
        search: _searchController.text,
        stato: _filtroStato,
        categoria: _filtroCategoria,
        origine: _filtroOrigine,
      );
      if (mounted) {
        setState(() {
          _soci = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento del Libro Soci: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _esportaXls() async {
    try {
      final url = _api.getSociExportUrl(
        search: _searchController.text,
        stato: _filtroStato,
        categoria: _filtroCategoria,
        origine: _filtroOrigine,
      );

      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Download del Libro Soci (XLSX) avviato.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'esportazione: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _esportaGoogleDrive() async {
    setState(() => _exportingDrive = true);
    try {
      final res = await _api.exportSociToGoogleDrive(
        search: _searchController.text,
        stato: _filtroStato,
        categoria: _filtroCategoria,
        origine: _filtroOrigine,
      );

      if (mounted) {
        setState(() => _exportingDrive = false);
        if (res['success'] == true) {
          final webViewLink = res['webViewLink'] as String?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Libro Soci esportato correttamente su Google Drive.'),
              backgroundColor: Colors.teal.shade800,
              duration: const Duration(seconds: 6),
              action: (webViewLink != null && webViewLink.isNotEmpty)
                  ? SnackBarAction(
                      label: 'APRI SU DRIVE',
                      textColor: Colors.yellowAccent,
                      onPressed: () => launchUrl(Uri.parse(webViewLink), mode: LaunchMode.externalApplication),
                    )
                  : null,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore caricamento su Google Drive'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exportingDrive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore upload Google Drive: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showDettaglio(Socio socio) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  socio.numeroProgressivo != null ? '#${socio.numeroProgressivo}' : '#?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      socio.nomeCompleto,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tessera: ${socio.numeroTessera}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  socio.attivo ? 'Attivo' : 'Cessato',
                  style: TextStyle(
                    fontSize: 11,
                    color: socio.attivo ? Colors.green.shade900 : Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: socio.attivo ? Colors.green.shade100 : Colors.red.shade100,
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Origine
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: socio.isStudente ? Colors.blue.shade50 : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: socio.isStudente ? Colors.blue.shade200 : Colors.purple.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          socio.isStudente ? Icons.school : Icons.person_add_alt,
                          size: 20,
                          color: socio.isStudente ? Colors.blue.shade800 : Colors.purple.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            socio.isStudente
                                ? 'Origine: Anagrafica Allievo (sincronizzato automaticamente)'
                                : 'Origine: Inserimento Manuale',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: socio.isStudente ? Colors.blue.shade900 : Colors.purple.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInfoGrid([
                    _buildInfoTile('Codice Fiscale', socio.codiceFiscale ?? '-'),
                    _buildInfoTile('Categoria', socio.categoriaDisplay),
                    _buildInfoTile('Data Iscrizione', _formatDateStr(socio.dataIscrizione)),
                    _buildInfoTile('Quota Associativa', _currencyFormat.format(socio.quotaAssociativa)),
                    _buildInfoTile('Data di Nascita', _formatDateStr(socio.dataNascita)),
                    _buildInfoTile('Luogo di Nascita', socio.luogoNascita?.isNotEmpty == true ? socio.luogoNascita! : '-'),
                    _buildInfoTile('Telefono', socio.telefono?.isNotEmpty == true ? socio.telefono! : '-'),
                    _buildInfoTile('Email', socio.email?.isNotEmpty == true ? socio.email! : '-'),
                    _buildInfoTile('Indirizzo Residenza', socio.indirizzoResidenza?.isNotEmpty == true ? socio.indirizzoResidenza! : '-', fullWidth: true),
                  ]),

                  if (!socio.attivo) ...[
                    const Divider(height: 28),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informazioni Cessazione',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Data Cessazione: ${_formatDateStr(socio.dataCessazione)}'),
                              ),
                              Expanded(
                                child: Text('Motivo: ${socio.motivoCessazioneDisplay ?? '-'}'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: children,
    );
  }

  Widget _buildInfoTile(String label, String value, {bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? 540 : 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDateStr(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(d);
      return _dateFormat.format(parsed);
    } catch (_) {
      return d;
    }
  }

  Future<void> _showNuovoSocioDialog() async {
    final formKey = GlobalKey<FormState>();
    final tesseraCtrl = TextEditingController();
    final cognomeCtrl = TextEditingController();
    final nomeCtrl = TextEditingController();
    final cfCtrl = TextEditingController();
    final nascitaCtrl = TextEditingController();
    final luogoCtrl = TextEditingController();
    final indirizzoCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final iscrizioneCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final quotaCtrl = TextEditingController(text: '20.00');
    String categoria = 'ORDINARIO';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Nuovo Socio (Manuale)'),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: tesseraCtrl,
                                decoration: const InputDecoration(labelText: 'N. Tessera *', border: OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: categoria,
                                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'ORDINARIO', child: Text('Ordinario')),
                                  DropdownMenuItem(value: 'SOSTENITORE', child: Text('Sostenitore')),
                                  DropdownMenuItem(value: 'PRESIDENTE', child: Text('Presidente')),
                                  DropdownMenuItem(value: 'VICE_PRESIDENTE', child: Text('Vice Presidente')),
                                  DropdownMenuItem(value: 'SEGRETARIO', child: Text('Segretario')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => categoria = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cognomeCtrl,
                                decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: nomeCtrl,
                                decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cfCtrl,
                                decoration: const InputDecoration(labelText: 'Codice Fiscale', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: nascitaCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Data di Nascita (YYYY-MM-DD)',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(1990),
                                    firstDate: DateTime(1920),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    nascitaCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: luogoCtrl,
                                decoration: const InputDecoration(labelText: 'Luogo di Nascita', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: indirizzoCtrl,
                                decoration: const InputDecoration(labelText: 'Indirizzo di Residenza', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: telCtrl,
                                decoration: const InputDecoration(labelText: 'Telefono', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: iscrizioneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Data Iscrizione *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    iscrizioneCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                                  }
                                },
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: quotaCtrl,
                                decoration: const InputDecoration(labelText: 'Quota Associativa (€)', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() != true) return;
                    try {
                      final payload = {
                        'numero_tessera': tesseraCtrl.text.trim(),
                        'cognome': cognomeCtrl.text.trim(),
                        'nome': nomeCtrl.text.trim(),
                        'codice_fiscale': cfCtrl.text.trim().toUpperCase(),
                        if (nascitaCtrl.text.isNotEmpty) 'data_nascita': nascitaCtrl.text.trim(),
                        'luogo_nascita': luogoCtrl.text.trim(),
                        'indirizzo_residenza': indirizzoCtrl.text.trim(),
                        'telefono': telCtrl.text.trim(),
                        'email': emailCtrl.text.trim().toLowerCase(),
                        'data_iscrizione': iscrizioneCtrl.text.trim(),
                        'categoria': categoria,
                        'quota_associativa': double.tryParse(quotaCtrl.text.replaceAll(',', '.')) ?? 20.0,
                        'attivo': true,
                        'origine': 'MANUALE',
                      };
                      await _api.createSocio(payload);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Socio ${cognomeCtrl.text} inserito con successo!'),
                            backgroundColor: Colors.green.shade800,
                          ),
                        );
                        _loadSoci();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Errore: $e'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salva Socio'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showModificaSocioDialog(Socio socio) async {
    final formKey = GlobalKey<FormState>();
    final tesseraCtrl = TextEditingController(text: socio.numeroTessera);
    final cognomeCtrl = TextEditingController(text: socio.cognome);
    final nomeCtrl = TextEditingController(text: socio.nome);
    final cfCtrl = TextEditingController(text: socio.codiceFiscale ?? '');
    final nascitaCtrl = TextEditingController(text: socio.dataNascita ?? '');
    final luogoCtrl = TextEditingController(text: socio.luogoNascita ?? '');
    final indirizzoCtrl = TextEditingController(text: socio.indirizzoResidenza ?? '');
    final telCtrl = TextEditingController(text: socio.telefono ?? '');
    final emailCtrl = TextEditingController(text: socio.email ?? '');
    final iscrizioneCtrl = TextEditingController(text: socio.dataIscrizione ?? '');
    final quotaCtrl = TextEditingController(text: socio.quotaAssociativa.toStringAsFixed(2));
    String categoria = socio.categoria;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Modifica Socio #${socio.numeroProgressivo ?? socio.id}'),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (socio.isStudente)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Socio derivante da allievo. I dati anagrafici sono sincronizzati con la scheda allievo.',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: tesseraCtrl,
                                decoration: const InputDecoration(labelText: 'N. Tessera *', border: OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: categoria,
                                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'ORDINARIO', child: Text('Ordinario')),
                                  DropdownMenuItem(value: 'SOSTENITORE', child: Text('Sostenitore')),
                                  DropdownMenuItem(value: 'PRESIDENTE', child: Text('Presidente')),
                                  DropdownMenuItem(value: 'VICE_PRESIDENTE', child: Text('Vice Presidente')),
                                  DropdownMenuItem(value: 'SEGRETARIO', child: Text('Segretario')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => categoria = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cognomeCtrl,
                                decoration: const InputDecoration(labelText: 'Cognome *', border: OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: nomeCtrl,
                                decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cfCtrl,
                                decoration: const InputDecoration(labelText: 'Codice Fiscale', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: nascitaCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Data Nascita (YYYY-MM-DD)',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: telCtrl,
                                decoration: const InputDecoration(labelText: 'Telefono', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: iscrizioneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Data Iscrizione *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: quotaCtrl,
                                decoration: const InputDecoration(labelText: 'Quota Associativa (€)', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() != true) return;
                    try {
                      final payload = {
                        'numero_tessera': tesseraCtrl.text.trim(),
                        'cognome': cognomeCtrl.text.trim(),
                        'nome': nomeCtrl.text.trim(),
                        'codice_fiscale': cfCtrl.text.trim().toUpperCase(),
                        if (nascitaCtrl.text.isNotEmpty) 'data_nascita': nascitaCtrl.text.trim(),
                        'luogo_nascita': luogoCtrl.text.trim(),
                        'indirizzo_residenza': indirizzoCtrl.text.trim(),
                        'telefono': telCtrl.text.trim(),
                        'email': emailCtrl.text.trim().toLowerCase(),
                        'data_iscrizione': iscrizioneCtrl.text.trim(),
                        'categoria': categoria,
                        'quota_associativa': double.tryParse(quotaCtrl.text.replaceAll(',', '.')) ?? 20.0,
                        'attivo': socio.attivo,
                        'origine': socio.origine,
                      };
                      await _api.updateSocio(socio.id, payload);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dati socio aggiornati con successo!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadSoci();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Errore: $e'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salva Modifiche'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCessaSocioDialog(Socio socio) async {
    final dataCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    String motivo = 'RECESSO';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.person_off, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Cessazione Socio: ${socio.nomeCompleto}'),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'La cessazione imposterà lo stato del socio come "Cessato" mantenendo lo storico per il Libro Soci e per l\'esportazione.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: dataCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Data Cessazione *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          dataCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: motivo,
                      decoration: const InputDecoration(
                        labelText: 'Motivo Cessazione *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'RECESSO', child: Text('Recesso')),
                        DropdownMenuItem(value: 'ESCLUSIONE', child: Text('Esclusione')),
                        DropdownMenuItem(value: 'DECESSO', child: Text('Decesso')),
                        DropdownMenuItem(value: 'MANCATO_RINNOVO', child: Text('Mancato Rinnovo')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => motivo = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                  onPressed: () async {
                    try {
                      await _api.cessaSocio(
                        socio.id,
                        motivoCessazione: motivo,
                        dataCessazione: dataCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Socio ${socio.nomeCompleto} cessato con successo.'),
                            backgroundColor: Colors.orange.shade900,
                          ),
                        );
                        _loadSoci();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Errore: $e'),
                            backgroundColor: Colors.red.shade800,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Conferma Cessazione'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confermaEliminazione(Socio socio) async {
    if (socio.isStudente) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('I soci derivati da allievi non possono essere eliminati.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confermato = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Socio'),
        content: Text('Sei sicuro di voler eliminare definitivamente il socio ${socio.nomeCompleto} (Tessera ${socio.numeroTessera})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confermato == true) {
      try {
        await _api.deleteSocio(socio.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Socio eliminato con successo')),
          );
          _loadSoci();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ─── Main Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Row(
                children: [
                  // Barra di ricerca
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cerca per Nome, Cognome, CF, N. Tessera...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadSoci();
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _loadSoci(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Filtro Stato
                  DropdownButton<String>(
                    value: _filtroStato,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'tutti', child: Text('Stato: Tutti')),
                      DropdownMenuItem(value: 'attivi', child: Text('Stato: Attivi')),
                      DropdownMenuItem(value: 'cessati', child: Text('Stato: Cessati')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filtroStato = val);
                        _loadSoci();
                      }
                    },
                  ),
                  const SizedBox(width: 12),

                  // Filtro Categoria
                  DropdownButton<String>(
                    value: _filtroCategoria,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'tutti', child: Text('Tutte le Categorie')),
                      DropdownMenuItem(value: 'ORDINARIO', child: Text('Ordinario')),
                      DropdownMenuItem(value: 'SOSTENITORE', child: Text('Sostenitore')),
                      DropdownMenuItem(value: 'PRESIDENTE', child: Text('Presidente')),
                      DropdownMenuItem(value: 'VICE_PRESIDENTE', child: Text('Vice Presidente')),
                      DropdownMenuItem(value: 'SEGRETARIO', child: Text('Segretario')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filtroCategoria = val);
                        _loadSoci();
                      }
                    },
                  ),
                  const SizedBox(width: 12),

                  // Filtro Origine
                  DropdownButton<String>(
                    value: _filtroOrigine,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'tutti', child: Text('Tutte le Origini')),
                      DropdownMenuItem(value: 'STUDENTE', child: Text('Studente')),
                      DropdownMenuItem(value: 'MANUALE', child: Text('Manuale')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _filtroOrigine = val);
                        _loadSoci();
                      }
                    },
                  ),
                  const Spacer(),

                  // Pulsanti Azioni
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuovo Socio'),
                    onPressed: _showNuovoSocioDialog,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Esporta XLS'),
                    onPressed: _esportaXls,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: _exportingDrive
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Carica su Drive'),
                    onPressed: _exportingDrive ? null : _esportaGoogleDrive,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Totale record: ${_soci.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Attivi: ${_soci.where((s) => s.attivo).length}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cessati: ${_soci.where((s) => !s.attivo).length}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Aggiorna elenco',
                    onPressed: _loadSoci,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabella dei Soci
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _soci.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Nessun socio trovato con i criteri selezionati',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: const [
                            DataColumn(label: Text('N. Prog.', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('N. Tessera', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Cognome', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Codice Fiscale', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Data Iscrizione', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Quota', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Stato', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Origine', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _soci.map((socio) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    socio.numeroProgressivo != null ? '#${socio.numeroProgressivo}' : '-',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataCell(Text(socio.numeroTessera)),
                                DataCell(Text(socio.cognome)),
                                DataCell(Text(socio.nome)),
                                DataCell(Text(socio.codiceFiscale ?? '-')),
                                DataCell(Text(socio.categoriaDisplay)),
                                DataCell(Text(_formatDateStr(socio.dataIscrizione))),
                                DataCell(Text(_currencyFormat.format(socio.quotaAssociativa))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: socio.attivo ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: socio.attivo ? Colors.green.shade300 : Colors.red.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      socio.attivo ? 'Attivo' : 'Cessato',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: socio.attivo ? Colors.green.shade900 : Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: socio.isStudente ? Colors.blue.shade50 : Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: socio.isStudente ? Colors.blue.shade300 : Colors.purple.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      socio.origineDisplay,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: socio.isStudente ? Colors.blue.shade900 : Colors.purple.shade900,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, size: 18),
                                        tooltip: 'Dettaglio',
                                        onPressed: () => _showDettaglio(socio),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        tooltip: 'Modifica',
                                        onPressed: () => _showModificaSocioDialog(socio),
                                      ),
                                      if (socio.attivo)
                                        IconButton(
                                          icon: const Icon(Icons.person_off, size: 18, color: Colors.orange),
                                          tooltip: 'Cessa Socio',
                                          onPressed: () => _showCessaSocioDialog(socio),
                                        ),
                                      if (socio.isManuale)
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                          tooltip: 'Elimina',
                                          onPressed: () => _confermaEliminazione(socio),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
