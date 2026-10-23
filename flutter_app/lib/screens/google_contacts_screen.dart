import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class GoogleContactsScreen extends StatefulWidget {
  final bool embedded;
  const GoogleContactsScreen({super.key, this.embedded = false});

  @override
  State<GoogleContactsScreen> createState() => _GoogleContactsScreenState();
}

class _GoogleContactsScreenState extends State<GoogleContactsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _testingConnection = false;
  bool _savingCreds = false;
  bool _savingSettings = false;
  bool _syncingAll = false;
  bool _obscureSecret = true;

  GoogleContactsConfig? _config;

  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  static const String _uriLocalhost = 'http://localhost:50082/api/google-contacts/oauth-callback/';
  static const String _uri127 = 'http://127.0.0.1:50082/api/google-contacts/oauth-callback/';
  String _selectedRedirectUri = _uri127;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final config = await _api.getGoogleContactsConfig();
      if (mounted) {
        setState(() {
          _config = config;
          if (config != null) {
            if (config.clientId.isNotEmpty) {
              _clientIdController.text = config.clientId;
            }
            if (config.syncGroupName.isNotEmpty) {
              _groupNameController.text = config.syncGroupName;
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento configurazione: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _saveCredentials({Uint8List? fileBytes, String? fileName}) async {
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();

    if (fileBytes == null && (clientId.isEmpty || clientSecret.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci sia il Client ID che il Client Secret (oppure carica il file JSON).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _savingCreds = true);
    try {
      final res = await _api.saveGoogleContactsCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credenziali OAuth 2.0 salvate con successo!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore durante il salvataggio credenziali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCreds = false);
    }
  }

  Future<void> _pickJsonFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        await _saveCredentials(fileBytes: bytes, fileName: file.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore selezione file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startOAuthFlow() async {
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();

    if (clientId.isEmpty || (clientSecret.isEmpty && !(_config?.hasClientSecret ?? false))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salva prima il Client ID e il Client Secret.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final res = await _api.initGoogleContactsOAuth(redirectUri: _selectedRedirectUri);
      if (res['success'] == true && res['auth_url'] != null) {
        final uri = Uri.parse(res['auth_url']);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(uri);
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.open_in_browser, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Autorizzazione in corso'),
                ],
              ),
              content: const Text(
                'Si è aperta la finestra di autorizzazione Google nel tuo browser.\n\n'
                '1. Seleziona il tuo account Google e consenti l\'accesso a Google Contacts.\n'
                '2. Una volta completato, torna in questa schermata e clicca "Aggiorna Stato".',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Chiudi'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadConfig();
                  },
                  child: const Text('Aggiorna Stato'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Impossibile avviare il flusso OAuth 2.0.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore avvio autorizzazione: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    try {
      final res = await _api.testGoogleContactsConnection();
      if (mounted) {
        final isSuccess = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (isSuccess ? 'Connessione verificata con successo!' : 'Verifica fallita.')),
            backgroundColor: isSuccess ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        _loadConfig();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore test connessione: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Disconnetti Google Contacts'),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler disconnettere l\'account Google Contacts?\n'
          'I token salvati verranno rimossi e la sincronizzazione della rubrica verrà interrotta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnetti'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.disconnectGoogleContacts();
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account disconnesso con successo.'), backgroundColor: Colors.green),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Errore durante la disconnessione.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      final res = await _api.saveGoogleContactsSettings(
        syncGroupName: _groupNameController.text.trim(),
      );
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impostazioni salvate con successo!'), backgroundColor: Colors.green),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] ?? 'Errore salvataggio impostazioni.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _syncAllContacts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Sincronizza Rubrica Google'),
          ],
        ),
        content: const Text(
          'Vuoi sincronizzare tutti gli allievi e i prospect del gestionale con la rubrica di Google Contacts?\n\n'
          'Per ogni contatto verranno impostati:\n'
          '• Nome e Cognome\n'
          '• Numero di Telefono\n'
          '• Nota: "Allievo <Scuola>" (se uomo) o "Allieva <Scuola>" (se donna) per gli allievi, oppure "Potenziale Allievo / Potenziale Allieva <Scuola>" per i prospect.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Avvia Sincronizzazione'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _syncingAll = true);
    try {
      final res = await _api.syncAllGoogleContacts();
      if (mounted) {
        final total = res['total'] ?? 0;
        final created = res['created'] ?? 0;
        final updated = res['updated'] ?? 0;
        final errorsCount = res['errors_count'] ?? 0;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Sincronizzazione Completata'),
              ],
            ),
            content: Text(
              'Riepilogo sincronizzazione con Google Contacts:\n\n'
              '• Totale contatti elaborati: $total\n'
              '• Nuovi contatti aggiunti: $created\n'
              '• Contatti aggiornati: $updated\n'
              '• Errori: $errorsCount',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadConfig();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la sincronizzazione: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingAll = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiato negli appunti!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusBanner(),
                    const SizedBox(height: 20),
                    if (_config?.isConnected ?? false) ...[
                      _buildSyncCard(),
                      const SizedBox(height: 20),
                    ],
                    _buildCredentialsCard(),
                    const SizedBox(height: 20),
                    _buildOAuthActionCard(),
                    const SizedBox(height: 20),
                    _buildInstructionsCard(),
                    const SizedBox(height: 20),
                    _buildSettingsCard(),
                  ],
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Contacts - Impostazioni'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: content,
    );
  }

  // ─── 1. Status Banner ──────────────────────────────────────────────
  Widget _buildStatusBanner() {
    final isConnected = _config?.isConnected ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.shade100 : Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isConnected ? Icons.check_circle_rounded : Icons.info_outline,
                color: isConnected ? Colors.green.shade800 : Colors.orange.shade800,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isConnected ? 'Google Contacts Collegato' : 'Google Contacts Non Collegato',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green.shade700 : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isConnected ? 'ATTIVO' : 'DISCONNESSO',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isConnected) ...[
                    Text(
                      'Account: ${_config?.userEmail ?? ''} (${_config?.userName ?? ''})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (_config?.lastTestMessage.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        _config!.lastTestMessage,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'Configura le credenziali OAuth 2.0 di seguito per sincronizzare la rubrica con Google Contacts.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ],
              ),
            ),
            if (isConnected) ...[
              const SizedBox(width: 12),
              Column(
                children: [
                  OutlinedButton.icon(
                    icon: _testingConnection
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt, size: 16),
                    label: const Text('Verifica'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade800,
                      side: BorderSide(color: Colors.green.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _testingConnection ? null : _testConnection,
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.link_off, size: 16, color: Colors.red),
                    label: const Text('Disconnetti', style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: _disconnect,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 1.1 Sync Card ─────────────────────────────────────────────────
  Widget _buildSyncCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.import_contacts, color: Colors.indigo, size: 24),
                SizedBox(width: 10),
                Text(
                  'Sincronizzazione Rubrica Google Contacts',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gli allievi e i prospect inseriti o modificati nel gestionale vengono sincronizzati automaticamente in Google Contacts con la nota "Allievo <Scuola>" se uomo o "Allieva <Scuola>" se donna (oppure "Potenziale Allievo / Potenziale Allieva").\n'
              'Puoi anche eseguire una sincronizzazione completa di tutti i contatti presenti nel database.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _syncingAll
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  label: Text(_syncingAll ? 'Sincronizzazione in corso...' : 'Sincronizza Tutti i Contatti'),
                  onPressed: _syncingAll ? null : _syncAllContacts,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Credentials Form ───────────────────────────────────────────
  Widget _buildCredentialsCard() {
    final hasSecret = _config?.hasClientSecret ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key, color: Colors.indigo, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Credenziali OAuth 2.0',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Carica client_secret.json'),
                  onPressed: _savingCreds ? null : _pickJsonFile,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Inserisci il Client ID e il Client Secret generati su Google Cloud Console (tipo Applicazione Web), oppure carica direttamente il file JSON scaricato.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _clientIdController,
              decoration: InputDecoration(
                labelText: 'Client ID OAuth 2.0 *',
                hintText: 'Es. 1234567890-abcdefgh.apps.googleusercontent.com',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientSecretController,
              obscureText: _obscureSecret,
              decoration: InputDecoration(
                labelText: hasSecret
                    ? 'Client Secret OAuth 2.0 * (Già configurato nel sistema)'
                    : 'Client Secret OAuth 2.0 *',
                hintText: hasSecret ? '••••••••••••••••••••••••' : 'Inserisci il Client Secret',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureSecret ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _savingCreds
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, size: 18),
                label: const Text('Salva Credenziali'),
                onPressed: _savingCreds ? null : () => _saveCredentials(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. OAuth Action Card ──────────────────────────────────────────
  Widget _buildOAuthActionCard() {
    final hasCreds = (_clientIdController.text.trim().isNotEmpty) || (_config?.clientId.isNotEmpty ?? false);
    final isConnected = _config?.isConnected ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sync_lock, color: Colors.teal, size: 24),
                SizedBox(width: 10),
                Text(
                  'Autorizzazione e Collegamento Account',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seleziona l\'URI di reindirizzamento corrispondente a quello registrato nella Google Cloud Console e avvia il collegamento.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            // Selezione Redirect URI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'URI di reindirizzamento attivo:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedRedirectUri,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: _uri127, child: Text(_uri127, style: TextStyle(fontSize: 13, fontFamily: 'monospace'))),
                            DropdownMenuItem(value: _uriLocalhost, child: Text(_uriLocalhost, style: TextStyle(fontSize: 13, fontFamily: 'monospace'))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedRedirectUri = val);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copia URI negli appunti',
                        onPressed: () => _copyToClipboard(_selectedRedirectUri, 'URI di reindirizzamento'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.teal.shade700 : Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.login, size: 22),
                label: Text(
                  isConnected ? 'Ricollega o Cambia Account Google' : 'Collega con Google',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: hasCreds ? _startOAuthFlow : null,
              ),
            ),
            if (!hasCreds)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '* Inserisci e salva prima il Client ID e il Client Secret per abilitare il pulsante.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── 4. Instructions Card ──────────────────────────────────────────
  Widget _buildInstructionsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50.withValues(alpha: 0.5),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.help_outline, color: Colors.blue),
        title: const Text(
          'Come ottenere Client ID e Client Secret su Google Cloud Console',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo),
        ),
        subtitle: const Text(
          'Guida passo-passo per configurare le credenziali in 5 minuti',
          style: TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _buildInstructionStep(
            '1',
            'Crea o seleziona un Progetto',
            'Accedi a Google Cloud Console (console.cloud.google.com) e seleziona il tuo progetto o creane uno nuovo (es. "TantoTango Gestionale").',
          ),
          _buildInstructionStep(
            '2',
            'Abilita la Google People API',
            'Nel menu a sinistra vai su "API e Servizi" > "Libreria". Cerca "People API" (o Google People API) e clicca su "Abilita".',
          ),
          _buildInstructionStep(
            '3',
            'Configura la Schermata Consenso OAuth',
            'Vai su "Schermata consenso OAuth" (OAuth consent screen).\n'
            '• Seleziona tipo utente "Esterno" (External) e compila Nome app ed Email di supporto.\n'
            '• Nella sezione "Ambiti" (Scopes) aggiungi:\n'
            '   - ".../auth/contacts" (Visualizzazione e gestione dei contatti)\n'
            '• Nella sezione "Utenti di test" (Test users) aggiungi il tuo indirizzo Gmail personale o della scuola.',
          ),
          _buildInstructionStep(
            '4',
            'Crea le Credenziali ID Client OAuth',
            'Vai su "Credenziali" > "+ Crea credenziali" > "ID client OAuth".\n'
            '• Tipo di applicazione: seleziona "Applicazione Web".\n'
            '• Nome: es. "Gestionale Tango".\n'
            '• In "URI di reindirizzamento autorizzati" aggiungi entrambi gli indirizzi:\n'
            '   $_uri127\n'
            '   $_uriLocalhost',
            showCopy: true,
          ),
          _buildInstructionStep(
            '5',
            'Copia o Scarica le Credenziali',
            'Una volta creato, copia il Client ID e il Client Secret e incollali nel form in alto, oppure clicca "Scarica JSON" e caricalo con il pulsante "Carica client_secret.json".',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String step, String title, String description, {bool showCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.indigo,
            child: Text(step, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                if (showCopy) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.copy, size: 14),
                        label: const Text('Copia 127.0.0.1 callback', style: TextStyle(fontSize: 11)),
                        onPressed: () => _copyToClipboard(_uri127, 'URI 127.0.0.1'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.copy, size: 14),
                        label: const Text('Copia localhost callback', style: TextStyle(fontSize: 11)),
                        onPressed: () => _copyToClipboard(_uriLocalhost, 'URI localhost'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 5. Settings Card ──────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: Colors.blueGrey, size: 24),
                SizedBox(width: 10),
                Text(
                  'Opzioni di Sincronizzazione',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Imposta le preferenze per l\'organizzazione dei contatti nella rubrica Google.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Nome Etichetta / Gruppo Google Contacts',
                hintText: 'Es. Allievi Tango',
                helperText: 'I contatti sincronizzati dal gestionale verranno catalogati sotto questa etichetta.',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _savingSettings
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Salva Impostazioni'),
                onPressed: _savingSettings ? null : _saveSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

