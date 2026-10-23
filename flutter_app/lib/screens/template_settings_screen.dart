import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class TemplateSettingsScreen extends StatefulWidget {
  final bool embedded;
  const TemplateSettingsScreen({super.key, this.embedded = false});

  @override
  State<TemplateSettingsScreen> createState() => _TemplateSettingsScreenState();
}

class _TemplateSettingsScreenState extends State<TemplateSettingsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _uploadingChiave;
  String? _removingChiave;
  List<DocumentTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getDocumentTemplates();
      if (mounted) {
        setState(() {
          _templates = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento dei template: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUpload(DocumentTemplate tmpl) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc'],
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossibile leggere i dati del file selezionato.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _uploadingChiave = tmpl.chiave);

      final res = await _api.uploadDocumentTemplate(tmpl.chiave, bytes, file.name);

      if (mounted) {
        setState(() => _uploadingChiave = null);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${file.name}" caricato con successo per "${tmpl.nome}"!'),
              backgroundColor: Colors.green.shade700,
            ),
          );
          _loadTemplates();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore durante il caricamento del file.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingChiave = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore selezione file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _downloadOrView(DocumentTemplate tmpl) async {
    final urlStr = _api.getDocumentTemplateDownloadUrl(tmpl.chiave);
    final uri = Uri.parse(urlStr);
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndRemove(DocumentTemplate tmpl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Conferma eliminazione'),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare il file PDF del template "${tmpl.nome}" (${tmpl.filename})?\n\nQuesta azione rimuoverà il file attualmente caricato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _removingChiave = tmpl.chiave);
    final res = await _api.removeDocumentTemplate(tmpl.chiave);

    if (mounted) {
      setState(() => _removingChiave = null);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File del template "${tmpl.nome}" eliminato con successo.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _loadTemplates();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Errore durante la rimozione del file.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Identifica i tre template specifici
    final ricevutaTmpl = _templates.firstWhere(
      (t) => t.chiave == 'ricevuta',
      orElse: () => DocumentTemplate(
        id: '',
        chiave: 'ricevuta',
        nome: 'Template Ricevuta Pagamento',
        descrizione: 'Template PDF utilizzato per la generazione delle ricevute di pagamento quote e corsi per gli allievi.',
      ),
    );

    final moduloTmpl = _templates.firstWhere(
      (t) => t.chiave == 'modulo_tesseramento',
      orElse: () => DocumentTemplate(
        id: '',
        chiave: 'modulo_tesseramento',
        nome: 'Modulo di Tesseramento',
        descrizione: 'Modulo PDF ufficiale per la richiesta o il rinnovo del tesseramento annuale degli allievi.',
      ),
    );

    final verbaleTmpl = _templates.firstWhere(
      (t) => t.chiave == 'verbale_rendiconto',
      orElse: () => DocumentTemplate(
        id: '',
        chiave: 'verbale_rendiconto',
        nome: 'Verbale Approvazione Rendiconto',
        descrizione: 'Modello PDF/DOCX ufficiale per il verbale dell\'assemblea ordinaria dei soci di approvazione del rendiconto economico-finanziario.',
      ),
    );

    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade800, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestione Template e Moduli Ufficiali',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Carica qui i file PDF o modelli ufficiali dei documenti. Il template della ricevuta viene utilizzato per le ricevute di pagamento quote, il modulo di tesseramento per nuove iscrizioni e rinnovi, e il modello di verbale per l\'approvazione del rendiconto economico-finanziario annuale.',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Ricarica',
                        color: Colors.blue.shade800,
                        onPressed: _loadTemplates,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Card 1: Template Ricevuta
                _buildTemplateCard(
                  tmpl: ricevutaTmpl,
                  icon: Icons.receipt_long,
                  accentColor: const Color(0xFF880E4F), // Bordeaux
                  badgeLabel: 'Ricevuta Pagamenti',
                ),
                const SizedBox(height: 20),

                // Card 2: Modulo di Tesseramento
                _buildTemplateCard(
                  tmpl: moduloTmpl,
                  icon: Icons.badge_outlined,
                  accentColor: Colors.indigo.shade800,
                  badgeLabel: 'Tesseramento & Iscrizioni',
                ),
                const SizedBox(height: 20),

                // Card 3: Verbale Approvazione Rendiconto
                _buildTemplateCard(
                  tmpl: verbaleTmpl,
                  icon: Icons.gavel_rounded,
                  accentColor: Colors.teal.shade800,
                  badgeLabel: 'Verbale & Bilancio',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard({
    required DocumentTemplate tmpl,
    required IconData icon,
    required Color accentColor,
    required String badgeLabel,
  }) {
    final isUploading = _uploadingChiave == tmpl.chiave;
    final isRemoving = _removingChiave == tmpl.chiave;
    final hasFile = tmpl.hasFile;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasFile ? accentColor.withValues(alpha: 0.3) : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione Card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tmpl.nome,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tmpl.descrizione,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Stato File Caricato
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasFile ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFile ? Colors.green.shade300 : Colors.amber.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFile
                        ? (tmpl.filename.toLowerCase().endsWith('.doc') || tmpl.filename.toLowerCase().endsWith('.docx')
                            ? Icons.description
                            : Icons.picture_as_pdf)
                        : Icons.upload_file,
                    color: hasFile
                        ? (tmpl.filename.toLowerCase().endsWith('.doc') || tmpl.filename.toLowerCase().endsWith('.docx')
                            ? Colors.blue.shade700
                            : Colors.red.shade700)
                        : Colors.amber.shade800,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: hasFile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tmpl.filename,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dimensione: ${tmpl.fileSizeFormatted} • Ultimo aggiornamento: ${_formatDate(tmpl.updatedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Nessun file caricato al momento. Clicca su "Carica Template" per inserire il modello (PDF o Word).',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  if (hasFile)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Text(
                        'CARICATO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Pulsanti Azioni
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (isUploading || isRemoving) ? null : () => _pickAndUpload(tmpl),
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(hasFile ? Icons.replay : Icons.upload_file, size: 18),
                  label: Text(
                    isUploading
                        ? 'Caricamento in corso...'
                        : (hasFile ? 'Sostituisci File' : 'Carica Template'),
                  ),
                ),
                if (hasFile) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: (isUploading || isRemoving) ? null : () => _downloadOrView(tmpl),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Visualizza / Scarica'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: (isUploading || isRemoving) ? null : () => _confirmAndRemove(tmpl),
                    icon: isRemoving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: Text(isRemoving ? 'Rimozione...' : 'Rimuovi'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
