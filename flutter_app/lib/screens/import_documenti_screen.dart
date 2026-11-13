import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ImportDocumentiScreen extends StatefulWidget {
  final bool embedded;
  const ImportDocumentiScreen({super.key, this.embedded = false});

  @override
  State<ImportDocumentiScreen> createState() => _ImportDocumentiScreenState();
}

class _ImportDocumentiScreenState extends State<ImportDocumentiScreen> {
  final ApiService _api = ApiService();

  // Wizard step (0 to 6)
  int _currentStep = 0;

  // Step 1: Allievo Selection
  List<Allievo> _allievi = [];
  bool _loadingAllievi = false;
  String _searchQuery = '';
  Allievo? _selectedAllievo;

  // Step 2 & 3: WhatsApp / Manual Media Files
  bool _loadingMedia = false;
  List<Map<String, dynamic>> _whatsappMedia = [];
  final Set<String> _selectedWhatsappFiles = {};
  final List<Map<String, dynamic>> _manualFiles = []; // [{'name': String, 'bytes': Uint8List, 'size': int, 'isImage': bool, 'isPdf': bool}]

  // Step 4: Convert to Single PDF
  bool _convertToPdf = true;

  // Step 5: Document Type ('tesseramento' vs 'certificati')
  String _tipoDocumento = 'tesseramento'; // 'tesseramento' | 'certificati'
  final TextEditingController _scadenzaCertificatoController = TextEditingController();

  // Step 6: Filename
  final TextEditingController _filenameController = TextEditingController();

  // Step 7: Upload Execution
  bool _uploading = false;
  Map<String, dynamic>? _uploadResult;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _loadAllievi();
  }

  @override
  void dispose() {
    _scadenzaCertificatoController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllievi() async {
    setState(() => _loadingAllievi = true);
    try {
      final list = await _api.getAllievi();
      if (mounted) {
        setState(() {
          _allievi = list;
          _loadingAllievi = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAllievi = false);
    }
  }

  Future<void> _loadWhatsappMediaForSelected() async {
    if (_selectedAllievo == null) return;
    setState(() {
      _loadingMedia = true;
      _whatsappMedia = [];
      _selectedWhatsappFiles.clear();
    });

    try {
      final res = await _api.getAllievoWhatsappMedia(_selectedAllievo!.id);
      if (mounted) {
        final rawFiles = (res['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _whatsappMedia = rawFiles;
          _loadingMedia = false;
          // Seleziona di default tutti i file trovati
          for (final f in _whatsappMedia) {
            final id = f['id'] as String?;
            if (id != null) _selectedWhatsappFiles.add(id);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  void _onAllievoSelected(Allievo allievo) {
    setState(() {
      _selectedAllievo = allievo;
      _updateDefaultFilename();
    });
    _loadWhatsappMediaForSelected();
  }

  void _updateDefaultFilename() {
    if (_selectedAllievo == null) return;
    final cleanNome = _selectedAllievo!.nome.trim().replaceAll(RegExp(r'\s+'), '_');
    final cleanCognome = _selectedAllievo!.cognome.trim().replaceAll(RegExp(r'\s+'), '_');
    final base = '${cleanNome}_$cleanCognome'.replaceAll(RegExp(r'^_+|_+$'), '');

    if (_convertToPdf) {
      _filenameController.text = '$base.pdf';
    } else {
      _filenameController.text = base;
    }
  }

  Future<void> _pickManualFiles() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last.toLowerCase();
        final isImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext);
        final isPdf = ext == 'pdf';
        setState(() {
          _manualFiles.add({
            'name': file.name,
            'bytes': bytes,
            'size': bytes.length,
            'isImage': isImage,
            'isPdf': isPdf,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore selezione file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int get _totalSelectedFilesCount => _selectedWhatsappFiles.length + _manualFiles.length;

  Future<void> _executeUpload() async {
    if (_selectedAllievo == null) return;
    if (_totalSelectedFilesCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un documento o immagine da caricare.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadResult = null;
    });

    try {
      final res = await _api.importDocumentoDrive(
        allievoId: _selectedAllievo!.id,
        tipoDocumento: _tipoDocumento,
        convertToPdf: _convertToPdf,
        filename: _filenameController.text.trim(),
        whatsappFiles: _selectedWhatsappFiles.toList(),
        manualFiles: _manualFiles,
        scadenzaCertificatoMedico: _tipoDocumento == 'certificati' ? _scadenzaCertificatoController.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _uploading = false;
          if (res['success'] == true) {
            _uploadResult = res;
          } else {
            _uploadError = res['error']?.toString() ?? 'Errore durante il caricamento su Google Drive.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadError = e.toString();
        });
      }
    }
  }

  void _resetWizard() {
    setState(() {
      _currentStep = 0;
      _selectedAllievo = null;
      _searchQuery = '';
      _whatsappMedia.clear();
      _selectedWhatsappFiles.clear();
      _manualFiles.clear();
      _convertToPdf = true;
      _tipoDocumento = 'tesseramento';
      _scadenzaCertificatoController.clear();
      _filenameController.clear();
      _uploading = false;
      _uploadResult = null;
      _uploadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderBanner(),
              const SizedBox(height: 16),
              _buildStepperCard(),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Documenti > Google Drive'),
      ),
      body: body,
    );
  }

  Widget _buildHeaderBanner() {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade700,
              radius: 24,
              child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wizard Importazione Documenti su Google Drive',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seleziona l\'allievo, visualizza le foto e i file ricevuti nella chat WhatsApp (o aggiungili dal computer), uniscili in un unico PDF e caricali automaticamente nella cartella Google Drive dedicata.',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Indicator Bar
            _buildStepIndicator(),
            const Divider(height: 32),

            // Active Step Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentStepContent(),
            ),

            const SizedBox(height: 24),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      '1. Allievo',
      '2. Media WhatsApp',
      '3. Selezione',
      '4. PDF Unico',
      '5. Tipologia',
      '6. Nome File',
      '7. Drive',
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        return InkWell(
          onTap: () {
            // Permetti il salto all'indietro o avanti se consentito
            if (index < _currentStep || (index == 1 && _selectedAllievo != null)) {
              setState(() => _currentStep = index);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.blue.shade700
                  : (isCompleted ? Colors.blue.shade100 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted)
                  const Icon(Icons.check, size: 14, color: Colors.blue)
                else
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  steps[index].substring(3),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.white : (isCompleted ? Colors.blue.shade900 : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1SelectAllievo();
      case 1:
      case 2:
        return _buildStep2And3MediaGallery();
      case 3:
        return _buildStep4PdfChoice();
      case 4:
        return _buildStep5DocType();
      case 5:
        return _buildStep6Filename();
      case 6:
        return _buildStep7Upload();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Selezione Allievo ─────────────────────────────
  Widget _buildStep1SelectAllievo() {
    final filtered = _allievi.where((a) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      final full = '${a.nome} ${a.cognome}'.toLowerCase();
      final phone = a.telefono.toLowerCase();
      return full.contains(q) || phone.contains(q);
    }).toList();

    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 1: Scegli l\'allievo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Cerca per nome, cognome o numero di telefono.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Cerca allievo (es. Mario Rossi)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 12),
        if (_loadingAllievi)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text('Nessun allievo trovato per "$_searchQuery"', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final allievo = filtered[index];
                final isSelected = _selectedAllievo?.id == allievo.id;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: Colors.blue.shade50,
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
                    foregroundColor: isSelected ? Colors.white : Colors.black87,
                    child: Text(allievo.nome.isNotEmpty ? allievo.nome[0].toUpperCase() : '?'),
                  ),
                  title: Text(
                    '${allievo.nome} ${allievo.cognome}',
                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Tel: ${allievo.telefono.isNotEmpty ? allievo.telefono : "N/D"} • Corso: ${allievo.corsoDescrizione ?? "Nessuno"}${allievo.isProspect ? " (Prospect)" : ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                  onTap: () => _onAllievoSelected(allievo),
                );
              },
            ),
          ),
        if (_selectedAllievo != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selezionato: ${_selectedAllievo!.nome} ${_selectedAllievo!.cognome} (${_selectedAllievo!.telefono.isNotEmpty ? _selectedAllievo!.telefono : "senza telefono"})',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── Step 2 & 3: File WhatsApp e selezione ─────────────────
  Widget _buildStep2And3MediaGallery() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Passo 2 e 3: File e Immagini ricevuti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'File dalla chat WhatsApp di ${_selectedAllievo?.nome ?? "allievo"} e upload manuale.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: const Text('Carica da PC'),
              onPressed: _pickManualFiles,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sezione file WhatsApp
        Text(
          'Media rilevati da WhatsApp (${_whatsappMedia.length}):',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        if (_loadingMedia)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_whatsappMedia.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nessun file multimediale memorizzato per questo contatto via WhatsApp. Puoi caricare le immagini/documenti direttamente dal tuo computer cliccando "Carica da PC".',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _whatsappMedia.map((f) {
              final id = f['id'] as String;
              final fileName = f['fileName'] as String? ?? id;
              final isImage = f['isImage'] == true;
              final isPdf = f['isPdf'] == true;
              final isSelected = _selectedWhatsappFiles.contains(id);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedWhatsappFiles.remove(id);
                    } else {
                      _selectedWhatsappFiles.add(id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            isPdf ? Icons.picture_as_pdf : (isImage ? Icons.image : Icons.insert_drive_file),
                            color: isPdf ? Colors.red : (isImage ? Colors.blue : Colors.grey.shade700),
                            size: 20,
                          ),
                          Icon(
                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isSelected ? Colors.blue : Colors.grey.shade500,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        // Sezione file manuali aggiunti da PC
        if (_manualFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'File aggiunti dal computer (${_manualFiles.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _manualFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final f = entry.value;
              final name = f['name'] as String;
              final isPdf = f['isPdf'] == true;

              return Container(
                width: 160,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: isPdf ? Colors.red : Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _manualFiles.removeAt(idx)),
                      child: const Icon(Icons.close, size: 18, color: Colors.red),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.library_books, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Totale elementi selezionati: $_totalSelectedFilesCount',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 4: Converti in PDF unico ────────────────────────
  Widget _buildStep4PdfChoice() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 4: Formato di destinazione',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Scegli se desideri unire le immagini e i documenti selezionati in un unico file PDF.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        RadioListTile<bool>(
          title: const Text('Unisci e converti tutti i file in un UNICO PDF (Consigliato)'),
          subtitle: const Text('Crea un solo file PDF multi-pagina pronto da allegare o archiviare.'),
          value: true,
          groupValue: _convertToPdf,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _convertToPdf = val;
                _updateDefaultFilename();
              });
            }
          },
        ),
        RadioListTile<bool>(
          title: const Text('Mantieni i file separati nel loro formato originale'),
          subtitle: const Text('Carica ogni singola immagine o file su Google Drive così com\'è.'),
          value: false,
          groupValue: _convertToPdf,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _convertToPdf = val;
                _updateDefaultFilename();
              });
            }
          },
        ),
      ],
    );
  }

  // ─── Step 5: Tipologia Documento ──────────────────────────
  Widget _buildStep5DocType() {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 5: Tipologia Documento',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Seleziona il tipo di documento per destinarlo alla cartella corretta su Google Drive.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tipoDocumento = 'tesseramento'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _tipoDocumento == 'tesseramento' ? Colors.blue.shade50 : Colors.white,
                    border: Border.all(
                      color: _tipoDocumento == 'tesseramento' ? Colors.blue.shade700 : Colors.grey.shade300,
                      width: _tipoDocumento == 'tesseramento' ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.badge_outlined, size: 36, color: _tipoDocumento == 'tesseramento' ? Colors.blue.shade700 : Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Modulo di Tesseramento', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Cartella Tessere su Google Drive', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tipoDocumento = 'certificati'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _tipoDocumento == 'certificati' ? Colors.deepOrange.shade50 : Colors.white,
                    border: Border.all(
                      color: _tipoDocumento == 'certificati' ? Colors.deepOrange.shade700 : Colors.grey.shade300,
                      width: _tipoDocumento == 'certificati' ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.medical_information_outlined, size: 36, color: _tipoDocumento == 'certificati' ? Colors.deepOrange.shade700 : Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Certificato Medico', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Cartella Certificati Medici', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_tipoDocumento == 'certificati') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _scadenzaCertificatoController,
            decoration: InputDecoration(
              labelText: 'Scadenza Certificato Medico (Opzionale, formato YYYY-MM-DD)',
              hintText: 'es. 2027-10-31',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              prefixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Step 6: Nome del File ────────────────────────────────
  Widget _buildStep6Filename() {
    return Column(
      key: const ValueKey(5),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 6: Nome del file',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Il nome predefinito è basato su Nome e Cognome dell\'allievo.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _filenameController,
          decoration: InputDecoration(
            labelText: 'Nome file su Google Drive',
            hintText: 'es. Mario_Rossi.pdf',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            prefixIcon: const Icon(Icons.description, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Riepilogo caricamento:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13)),
              const SizedBox(height: 6),
              Text('• Allievo: ${_selectedAllievo?.nome} ${_selectedAllievo?.cognome}'),
              Text('• Tipo: ${_tipoDocumento == "certificati" ? "Certificato Medico" : "Modulo di Tesseramento"}'),
              Text('• File selezionati: $_totalSelectedFilesCount'),
              Text('• Unisci in unico PDF: ${_convertToPdf ? "Sì" : "No"}'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 7: Upload e Risultato ───────────────────────────
  Widget _buildStep7Upload() {
    if (_uploading) {
      return Container(
        key: const ValueKey('uploading'),
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento in corso su Google Drive...', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Elaborazione e unione file in corso, attendere...', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    if (_uploadResult != null) {
      final folderNome = _uploadResult!['folder_nome'] ?? 'Google Drive';
      final files = (_uploadResult!['uploaded_files'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      return Container(
        key: const ValueKey('success'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Caricamento completato con successo!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'I file sono stati caricati nella cartella "$folderNome" su Google Drive:',
              style: TextStyle(fontSize: 13, color: Colors.green.shade800),
            ),
            const SizedBox(height: 8),
            ...files.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.attachment, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(f['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            )),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh),
              label: const Text('Carica un altro documento'),
              onPressed: _resetWizard,
            ),
          ],
        ),
      );
    }

    if (_uploadError != null) {
      return Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Errore durante il caricamento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_uploadError!, style: TextStyle(fontSize: 13, color: Colors.red.shade800)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              icon: const Icon(Icons.replay),
              label: const Text('Riprova caricamento'),
              onPressed: _executeUpload,
            ),
          ],
        ),
      );
    }

    // Default pre-upload view in Step 7
    return Column(
      key: const ValueKey(6),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passo 7: Conferma e Caricamento su Google Drive',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Verifica le impostazioni finali e avvia il caricamento.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Riepilogo finale:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 14)),
              const SizedBox(height: 8),
              Text('• Allievo: ${_selectedAllievo?.nome} ${_selectedAllievo?.cognome}'),
              Text('• Tipologia: ${_tipoDocumento == "certificati" ? "Certificato Medico" : "Modulo di Tesseramento"}'),
              Text('• Nome del file: ${_filenameController.text}'),
              Text('• Elementi selezionati: $_totalSelectedFilesCount'),
              Text('• Conversione PDF unico: ${_convertToPdf ? "Sì" : "No"}'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Carica su Google Drive', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            onPressed: _executeUpload,
          ),
        ),
      ],
    );
  }

  // ─── Pulsanti di Navigazione ──────────────────────────────
  Widget _buildNavigationButtons() {
    if (_uploading || _uploadResult != null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Indietro'),
            onPressed: () => setState(() => _currentStep--),
          )
        else
          const SizedBox.shrink(),
        if (_currentStep < 6)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Avanti'),
            onPressed: () {
              if (_currentStep == 0 && _selectedAllievo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seleziona un allievo per proseguire.'), backgroundColor: Colors.orange),
                );
                return;
              }
              if (_currentStep == 2 && _totalSelectedFilesCount == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seleziona almeno un file o caricalo dal computer.'), backgroundColor: Colors.orange),
                );
                return;
              }
              setState(() => _currentStep++);
            },
          ),
      ],
    );
  }
}
