import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/file_download_helper.dart';

class LibroSociTab extends StatefulWidget {
  const LibroSociTab({super.key});

  @override
  State<LibroSociTab> createState() => _LibroSociTabState();
}

class _LibroSociTabState extends State<LibroSociTab> {
  final ApiService _api = ApiService();

  bool _loading = false;
  bool _exportingDrive = false;
  bool _loadingDriveStatus = false;
  Map<String, dynamic>? _driveStatus;
  List<Socio> _soci = [];

  final _searchController = TextEditingController();
  String _filtroStato = 'tutti'; // Default 'tutti' in modo che i soci cessati rimangano visibili nel registro con stato 'Cessato'
  String _filtroCategoria = 'tutti';
  String _filtroOrigine = 'tutti';

  // Ordinamento: default per numero tessera crescente
  int _sortColumnIndex = 0; // Colonna 'N. Tessera'
  bool _sortAscending = true;
  String _sortField = 'numero_tessera';

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  @override
  void initState() {
    super.initState();
    _loadSoci();
    _checkDriveStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(int columnIndex, String field, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortField = field;
    });
    _loadSoci();
  }

  Future<void> _checkDriveStatus() async {
    setState(() => _loadingDriveStatus = true);
    try {
      final status = await _api.getSociDriveStatus();
      if (mounted) {
        setState(() {
          _driveStatus = status;
          _loadingDriveStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDriveStatus = false);
    }
  }

  Future<void> _loadSoci() async {
    setState(() => _loading = true);
    try {
      final orderingParam = _sortAscending ? _sortField : '-$_sortField';
      final list = await _api.getSoci(
        search: _searchController.text,
        stato: _filtroStato,
        categoria: _filtroCategoria,
        origine: _filtroOrigine,
        ordering: orderingParam,
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

  String _formatDateTimeStr(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(d).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
    } catch (_) {
      return d;
    }
  }

  void _showDifferenzeDialog() {
    if (_driveStatus == null) return;
    final differenze = (_driveStatus!['differenze'] as List<dynamic>?) ?? [];
    final lastDrive = _formatDateTimeStr(_driveStatus!['last_drive_update'] as String?);
    final lastSystem = _formatDateTimeStr(_driveStatus!['last_system_update'] as String?);
    final filename = _driveStatus!['filename'] as String? ?? 'Libro_Soci.xlsx';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.sync_problem_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              const Text('Evidenza Differenze con Google Drive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_done_outlined, size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            const Text('Ultimo file su Drive:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const Spacer(),
                            Flexible(child: Text('$lastDrive ($filename)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.storage_outlined, size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            const Text('Ultima modifica gestionale:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const Spacer(),
                            Text(lastSystem, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_outlined, size: 18, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            const Text('Soci modificati o inseriti:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const Spacer(),
                            Text(
                              '${differenze.length} soci disallineati',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (differenze.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nessun dettaglio aggiuntivo disponibile sulle differenze.'),
                    )
                  else ...[
                    const Text('Elenco soci aggiornati o inseriti dopo l\'ultimo caricamento:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: differenze.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final diff = differenze[index] as Map<String, dynamic>;
                          final isNuovo = diff['is_nuovo'] == true;
                          final attivo = diff['attivo'] == true;
                          final dataMod = _formatDateTimeStr(diff['updated_at'] as String?);
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isNuovo ? Colors.blue.shade100 : Colors.orange.shade100,
                              child: Icon(
                                isNuovo ? Icons.person_add : Icons.edit,
                                size: 16,
                                color: isNuovo ? Colors.blue.shade900 : Colors.orange.shade900,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'Tessera ${diff['numero_tessera'] ?? '-'} - ${diff['nome_completo'] ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isNuovo ? Colors.blue.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isNuovo ? Colors.blue.shade200 : Colors.amber.shade300),
                                  ),
                                  child: Text(
                                    isNuovo ? 'Nuovo' : 'Modificato',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isNuovo ? Colors.blue.shade900 : Colors.brown.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: attivo ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: attivo ? Colors.green.shade200 : Colors.red.shade200),
                                  ),
                                  child: Text(
                                    attivo ? 'Attivo' : 'Cessato',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: attivo ? Colors.green.shade900 : Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text('Data modifica: $dataMod', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          );
                        },
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
            FilledButton.icon(
              icon: const Icon(Icons.cloud_upload, size: 16),
              label: const Text('Aggiorna su Drive Ora'),
              onPressed: () {
                Navigator.pop(ctx);
                _esportaGoogleDrive();
              },
            ),
          ],
        );
      },
    );
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
          _checkDriveStatus();
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
                child: Icon(Icons.person, color: Theme.of(context).primaryColor),
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
                      final rawQuota = quotaCtrl.text.trim().replaceAll(',', '.');
                      final quotaVal = rawQuota.isEmpty ? 0.0 : (double.tryParse(rawQuota) ?? 0.0);
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
                        'quota_associativa': quotaVal,
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
                  Text('Modifica Socio (${socio.numeroTessera})'),
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
                      final rawQuota = quotaCtrl.text.trim().replaceAll(',', '.');
                      final quotaVal = rawQuota.isEmpty ? 0.0 : (double.tryParse(rawQuota) ?? 0.0);
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
                        'quota_associativa': quotaVal,
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

  Widget _buildDriveAlertBanner() {
    if (_driveStatus == null || _driveStatus!['configured'] != true) {
      return const SizedBox.shrink();
    }

    final status = _driveStatus!['status'] as String? ?? '';
    if (status == 'AGGIORNATO') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Libro Soci sincronizzato su Google Drive.',
                style: TextStyle(color: Colors.green.shade900, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (_driveStatus!['webViewLink'] != null && (_driveStatus!['webViewLink'] as String).isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Apri su Drive', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.green.shade800),
                onPressed: () => launchUrl(
                  Uri.parse(_driveStatus!['webViewLink']),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      );
    }

    final isNonPresente = status == 'NON_PRESENTE';
    final bgColor = isNonPresente ? Colors.orange.shade50 : Colors.amber.shade50;
    final borderColor = isNonPresente ? Colors.orange.shade300 : Colors.amber.shade400;
    final iconColor = isNonPresente ? Colors.orange.shade800 : Colors.amber.shade900;
    final textColor = isNonPresente ? Colors.orange.shade900 : Colors.brown.shade900;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isNonPresente ? Icons.warning_amber_rounded : Icons.sync_problem_rounded,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isNonPresente
                      ? 'Attenzione: Il file del Libro Soci non è presente su Google Drive.'
                      : 'Attenzione: Il file del Libro Soci su Google Drive non è aggiornato rispetto alle modifiche nel sistema.',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (!isNonPresente && _driveStatus!['drive_modified_time'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Ultima versione su Drive: ${_formatDateStr(_driveStatus!['drive_modified_time'])}',
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!isNonPresente) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Info Differenze', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: _showDifferenzeDialog,
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isNonPresente ? Colors.orange.shade700 : Colors.amber.shade800,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: _exportingDrive
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload, size: 16),
            label: Text(
              isNonPresente ? 'Carica su Drive' : 'Aggiorna su Drive',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: _exportingDrive ? null : _esportaGoogleDrive,
          ),
        ],
      ),
    );
  }

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
                    onPressed: () {
                      _loadSoci();
                      _checkDriveStatus();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Drive Alert Banner
        _buildDriveAlertBanner(),

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
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: [
                            DataColumn(
                              label: const Text('N. Tessera', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (idx, asc) => _onSort(idx, 'numero_tessera', asc),
                            ),
                            DataColumn(
                              label: const Text('Cognome', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (idx, asc) => _onSort(idx, 'cognome', asc),
                            ),
                            DataColumn(
                              label: const Text('Nome', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (idx, asc) => _onSort(idx, 'nome', asc),
                            ),
                            const DataColumn(label: Text('Codice Fiscale', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Residenza', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(
                              label: const Text('Data Iscrizione', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (idx, asc) => _onSort(idx, 'data_iscrizione', asc),
                            ),
                            const DataColumn(label: Text('Quota', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(
                              label: const Text('Stato', style: TextStyle(fontWeight: FontWeight.bold)),
                              onSort: (idx, asc) => _onSort(idx, 'attivo', asc),
                            ),
                            const DataColumn(label: Text('Origine', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _soci.map((socio) {
                            return DataRow(
                              cells: [
                                DataCell(Text(socio.numeroTessera)),
                                DataCell(Text(socio.cognome)),
                                DataCell(Text(socio.nome)),
                                DataCell(Text(socio.codiceFiscale ?? '-')),
                                DataCell(
                                  Text(
                                    socio.indirizzoResidenza?.isNotEmpty == true
                                        ? socio.indirizzoResidenza!
                                        : '-',
                                  ),
                                ),
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
