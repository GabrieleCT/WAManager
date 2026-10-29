import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'verbale_rendiconto_tab.dart';

class AsdScreen extends StatefulWidget {
  const AsdScreen({super.key});

  @override
  State<AsdScreen> createState() => _AsdScreenState();
}

class _AsdScreenState extends State<AsdScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  bool _savingAsd = false;
  String? _uploadingMembroId;

  List<MembroDirettivo> _direttivo = [];

  // Controllers per form ASD
  final _nomeController = TextEditingController();
  final _codiceFiscaleController = TextEditingController();
  final _partitaIvaController = TextEditingController();
  final _sedeLegaleController = TextEditingController();
  final _sedeOperativaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _pecController = TextEditingController();
  final _sitoWebController = TextEditingController();
  final _codiceAffiliazioneController = TextEditingController();
  final _ibanController = TextEditingController();

  // Cache buster per le immagini delle firme aggiornate
  int _imageKeyTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeController.dispose();
    _codiceFiscaleController.dispose();
    _partitaIvaController.dispose();
    _sedeLegaleController.dispose();
    _sedeOperativaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _pecController.dispose();
    _sitoWebController.dispose();
    _codiceAffiliazioneController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final asdFuture = _api.getConfigurazioneASD();
      final direttivoFuture = _api.getDirettivo();

      final results = await Future.wait([asdFuture, direttivoFuture]);
      final asd = results[0] as ConfigurazioneASD?;
      final direttivo = results[1] as List<MembroDirettivo>;

      if (mounted) {
        setState(() {
          _direttivo = direttivo;
          if (asd != null) {
            _nomeController.text = asd.nome;
            _codiceFiscaleController.text = asd.codiceFiscale;
            _partitaIvaController.text = asd.partitaIva;
            _sedeLegaleController.text = asd.sedeLegale;
            _sedeOperativaController.text = asd.sedeOperativa;
            _telefonoController.text = asd.telefono;
            _emailController.text = asd.email;
            _pecController.text = asd.pec;
            _sitoWebController.text = asd.sitoWeb;
            _codiceAffiliazioneController.text = asd.codiceAffiliazione;
            _ibanController.text = asd.iban;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento dati ASD: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _salvaDatiAsd() async {
    setState(() => _savingAsd = true);
    final payload = {
      'nome': _nomeController.text.trim(),
      'codice_fiscale': _codiceFiscaleController.text.trim().toUpperCase(),
      'partita_iva': _partitaIvaController.text.trim(),
      'sede_legale': _sedeLegaleController.text.trim(),
      'sede_operativa': _sedeOperativaController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'email': _emailController.text.trim(),
      'pec': _pecController.text.trim(),
      'sito_web': _sitoWebController.text.trim(),
      'codice_affiliazione': _codiceAffiliazioneController.text.trim(),
      'iban': _ibanController.text.trim().toUpperCase(),
    };

    final res = await _api.saveConfigurazioneASD(payload);
    if (!mounted) return;

    setState(() => _savingAsd = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dati ASD salvati con successo!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel salvataggio: ${res['error'] ?? 'Dati non validi'}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _modificaMembro(MembroDirettivo membro) async {
    final nomeCtrl = TextEditingController(text: membro.nome);
    final cognomeCtrl = TextEditingController(text: membro.cognome);
    final cfCtrl = TextEditingController(text: membro.codiceFiscale);
    final luogoCtrl = TextEditingController(text: membro.luogoNascita);
    final telCtrl = TextEditingController(text: membro.telefono);
    final emailCtrl = TextEditingController(text: membro.email);
    DateTime? selectedDate = membro.dataNascita != null && membro.dataNascita!.isNotEmpty
        ? DateTime.tryParse(membro.dataNascita!)
        : null;

    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRuoloColor(membro.ruolo).withOpacity(0.15),
                    child: Icon(_getRuoloIcon(membro.ruolo), color: _getRuoloColor(membro.ruolo)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Modifica ${membro.ruoloDisplay}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Anagrafica carica sociale', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nomeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nome *',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci il nome' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: cognomeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cognome *',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci il cognome' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: cfCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Codice Fiscale',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                            hintText: 'Es. RSSMRA80A01H501Z',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogCtx,
                                    initialDate: selectedDate ?? DateTime(1980, 1, 1),
                                    firstDate: DateTime(1920),
                                    lastDate: DateTime.now(),
                                    helpText: 'Seleziona data di nascita',
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Data di Nascita',
                                    prefixIcon: Icon(Icons.cake_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    selectedDate != null
                                        ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                                        : 'Seleziona data',
                                    style: TextStyle(
                                      color: selectedDate != null ? Colors.black87 : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: luogoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Luogo di Nascita',
                                  prefixIcon: Icon(Icons.location_city_outlined),
                                  border: OutlineInputBorder(),
                                  hintText: 'Es. Roma (RM)',
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
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Telefono',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
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
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annulla'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final data = {
                        'nome': nomeCtrl.text.trim(),
                        'cognome': cognomeCtrl.text.trim(),
                        'codice_fiscale': cfCtrl.text.trim().toUpperCase(),
                        'data_nascita': selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : null,
                        'luogo_nascita': luogoCtrl.text.trim(),
                        'telefono': telCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                      };
                      final res = await _api.updateMembroDirettivo(membro.id, data);
                      if (!dialogCtx.mounted) return;
                      if (res != null) {
                        Navigator.pop(ctx, true);
                      } else {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          const SnackBar(
                            content: Text('Errore durante l\'aggiornamento del membro'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anagrafica ${membro.ruoloDisplay} aggiornata con successo!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    }
  }

  Future<void> _pickAndUploadFirma(MembroDirettivo membro) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File immagine vuoto o illeggibile.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _uploadingMembroId = membro.id);

      final res = await _api.uploadFirmaMembro(membro.id, bytes, file.name);

      if (mounted) {
        setState(() {
          _uploadingMembroId = null;
          _imageKeyTimestamp = DateTime.now().millisecondsSinceEpoch;
        });

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Firma caricata con successo per ${membro.ruoloDisplay}!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          _loadAllData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nel caricamento della firma: ${res['error'] ?? 'Errore sconosciuto'}'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingMembroId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la selezione del file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _rimuoviFirma(MembroDirettivo membro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            const Text('Conferma Rimozione Firma'),
          ],
        ),
        content: Text(
          'Sei sicuro di voler rimuovere l\'immagine della firma di ${membro.ruoloDisplay} (${membro.nomeCompleto})?\n\nNon comparirà più automaticamente nei documenti generati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi Firma', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _uploadingMembroId = membro.id);
    final res = await _api.removeFirmaMembro(membro.id);

    if (mounted) {
      setState(() {
        _uploadingMembroId = null;
        _imageKeyTimestamp = DateTime.now().millisecondsSinceEpoch;
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firma rimossa con successo per ${membro.ruoloDisplay}!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore rimozione firma: ${res['error'] ?? 'Impossibile rimuovere la firma'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getRuoloColor(String ruolo) {
    switch (ruolo.toLowerCase()) {
      case 'presidente':
        return Colors.indigo.shade700;
      case 'vicepresidente':
        return Colors.teal.shade700;
      case 'segretario':
        return Colors.amber.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getRuoloIcon(String ruolo) {
    switch (ruolo.toLowerCase()) {
      case 'presidente':
        return Icons.workspace_premium;
      case 'vicepresidente':
        return Icons.military_tech;
      case 'segretario':
        return Icons.assignment_ind;
      default:
        return Icons.badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.corporate_fare, size: 26),
            SizedBox(width: 10),
            Text('Gestione ASD & Direttivo', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ricarica dati',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey.shade700,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.account_balance), text: 'Dati Associazione (ASD)'),
            Tab(icon: Icon(Icons.groups_rounded), text: 'Direttivo & Firme'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Genera Verbale Rendiconto'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Caricamento configurazione ASD e Direttivo in corso...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabDatiAsd(),
                _buildTabDirettivo(),
                const VerbaleRendicontoTab(),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: DATI ASD
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabDatiAsd() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner info
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade800, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'In questa sezione puoi configurare i dati legali e fiscali dell\'Associazione Sportiva Dilettantistica. '
                          'Questi parametri vengono utilizzati automaticamente nelle intestazioni delle ricevute di pagamento, nei tesseramenti e nella modulistica istituzionale.',
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form principale
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.domain, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Anagrafica Fiscale & Legale ASD',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const SizedBox(height: 8),

                      // Nome ASD
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo Associazione (ASD) *',
                          hintText: 'Es. TantoTango Associazione Sportiva Dilettantistica',
                          prefixIcon: Icon(Icons.corporate_fare),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Codice Fiscale & Partita IVA
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codiceFiscaleController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Codice Fiscale *',
                                hintText: 'Es. 97865430582',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _partitaIvaController,
                              decoration: const InputDecoration(
                                labelText: 'Partita IVA (se presente)',
                                hintText: 'Es. 12345678901',
                                prefixIcon: Icon(Icons.receipt_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sede Legale & Sede Operativa
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sedeLegaleController,
                              decoration: const InputDecoration(
                                labelText: 'Sede Legale *',
                                hintText: 'Via, Civico, CAP, Città (Provincia)',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sedeOperativaController,
                              decoration: const InputDecoration(
                                labelText: 'Sede Operativa *',
                                hintText: 'Via, Civico, CAP, Città (Provincia)',
                                prefixIcon: Icon(Icons.storefront),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Recapiti: Telefono, Email, PEC
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _telefonoController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefono Contatto',
                                hintText: 'Es. +39 347 1234567',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Istituzionale',
                                hintText: 'info@tantotango.it',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _pecController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Posta Elettronica Certificata (PEC)',
                                hintText: 'tantotango@pec.it',
                                prefixIcon: Icon(Icons.mark_email_read_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sito Web & Codice Affiliazione
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sitoWebController,
                              decoration: const InputDecoration(
                                labelText: 'Sito Web',
                                hintText: 'https://www.tantotango.it',
                                prefixIcon: Icon(Icons.language),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _codiceAffiliazioneController,
                              decoration: const InputDecoration(
                                labelText: 'Codice Affiliazione EPS / CONI',
                                hintText: 'Es. ACSI / CSEN n. 123456 - CONI 78910',
                                prefixIcon: Icon(Icons.card_membership),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // IBAN Conto Corrente
                      TextFormField(
                        controller: _ibanController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'IBAN Conto Corrente ASD',
                          hintText: 'Es. IT60X0542811101000000123456',
                          prefixIcon: Icon(Icons.account_balance),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottone Salva
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _savingAsd ? null : _salvaDatiAsd,
                          icon: _savingAsd
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _savingAsd ? 'Salvataggio in corso...' : 'Salva Dati ASD',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Anteprima intestazione documenti
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Anteprima Intestazione Documentale Ricevute & Modulistica',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nomeController.text.isNotEmpty ? _nomeController.text : 'TantoTango Associazione Sportiva Dilettantistica',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cod. Fiscale: ${_codiceFiscaleController.text.isNotEmpty ? _codiceFiscaleController.text : '[Da Configurare]'} '
                              '${_partitaIvaController.text.isNotEmpty ? '• P.IVA: ${_partitaIvaController.text}' : ''}',
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sede Legale: ${_sedeLegaleController.text.isNotEmpty ? _sedeLegaleController.text : '[Da Configurare]'}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            Text(
                              'Sede Operativa: ${_sedeOperativaController.text.isNotEmpty ? _sedeOperativaController.text : '[Da Configurare]'}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            if (_codiceAffiliazioneController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Affiliazione: ${_codiceAffiliazioneController.text}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: DIRETTIVO & FIRME
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabDirettivo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner info
              Card(
                elevation: 0,
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.indigo.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.draw, color: Colors.indigo.shade800, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Gestione del Consiglio Direttivo: configura le anagrafiche del Presidente, Vicepresidente e Segretario. '
                          'Carica per ciascun membro l\'immagine della firma autografa (preferibilmente su sfondo bianco o trasparente PNG/JPG): '
                          'verrà automaticamente apposta nelle ricevute e nei documenti ufficiali dell\'associazione.',
                          style: TextStyle(color: Colors.indigo.shade900, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Lista Membri Direttivo
              if (_direttivo.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('Nessun membro del direttivo presente.'),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadAllData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Ricarica e inizializza cariche'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._direttivo.map((membro) => _buildMembroCard(membro)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembroCard(MembroDirettivo membro) {
    final bool isUploading = _uploadingMembroId == membro.id;
    final roleColor = _getRuoloColor(membro.ruolo);
    final roleIcon = _getRuoloIcon(membro.ruolo);

    final String firmaUrl = membro.hasFirma && membro.firmaUrl != null
        ? '${_api.getFirmaFullUrl(membro.firmaUrl)}?t=$_imageKeyTimestamp'
        : '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione Card: Badge Ruolo + Tasto Modifica
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, color: roleColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        membro.ruoloDisplay.toUpperCase(),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: isUploading ? null : () => _modificaMembro(membro),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Modifica Anagrafica'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenuto: Dati Anagrafici a Sinistra, Riquadro Firma a Destra
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final anagraficaWidget = _buildAnagraficaInfo(membro);
                final firmaWidget = _buildFirmaBox(membro, firmaUrl, isUploading);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: anagraficaWidget),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: firmaWidget),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      anagraficaWidget,
                      const SizedBox(height: 20),
                      firmaWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnagraficaInfo(MembroDirettivo membro) {
    final bool hasName = membro.nome.isNotEmpty || membro.cognome.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.grey.shade700, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasName ? '${membro.nome} ${membro.cognome}' : 'Nominativo non ancora inserito',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasName ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow(
            Icons.badge_outlined,
            'Codice Fiscale',
            membro.codiceFiscale.isNotEmpty ? membro.codiceFiscale : 'Non specificato',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.cake_outlined,
            'Nascita',
            _formatNascita(membro.dataNascita, membro.luogoNascita),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.phone_outlined,
            'Telefono',
            membro.telefono.isNotEmpty ? membro.telefono : 'Non specificato',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.email_outlined,
            'Email',
            membro.email.isNotEmpty ? membro.email : 'Non specificata',
          ),
        ],
      ),
    );
  }

  String _formatNascita(String? data, String luogo) {
    String res = '';
    if (data != null && data.isNotEmpty) {
      try {
        final dt = DateTime.parse(data);
        res = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {
        res = data;
      }
    }
    if (luogo.isNotEmpty) {
      res = res.isNotEmpty ? '$res a $luogo' : 'a $luogo';
    }
    return res.isNotEmpty ? res : 'Non specificata';
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildFirmaBox(MembroDirettivo membro, String firmaUrl, bool isUploading) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: membro.hasFirma ? Colors.green.shade300 : Colors.grey.shade300,
          width: membro.hasFirma ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                membro.hasFirma ? Icons.check_circle : Icons.draw_outlined,
                size: 18,
                color: membro.hasFirma ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Firma Autografa Digitale',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: membro.hasFirma ? Colors.green.shade800 : Colors.black87,
                ),
              ),
              const Spacer(),
              if (membro.hasFirma)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'Caricata',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Area anteprima firma
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            alignment: Alignment.center,
            child: isUploading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 8),
                      Text('Caricamento firma in corso...', style: TextStyle(fontSize: 12)),
                    ],
                  )
                : membro.hasFirma && firmaUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          firmaUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey.shade400, size: 30),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Impossibile caricare l\'anteprima',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gesture, color: Colors.grey.shade400, size: 36),
                          const SizedBox(height: 6),
                          Text(
                            'Nessuna immagine firma presente',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: 12),

          // Azioni Firma: Carica/Sostituisci & Elimina
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isUploading ? null : () => _pickAndUploadFirma(membro),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: membro.hasFirma ? Colors.blueGrey.shade800 : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(membro.hasFirma ? Icons.file_upload_outlined : Icons.upload, size: 18),
                  label: Text(
                    membro.hasFirma ? 'Sostituisci Firma' : 'Carica Firma',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (membro.hasFirma) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Rimuovi firma',
                  onPressed: isUploading ? null : () => _rimuoviFirma(membro),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
