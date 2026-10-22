import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class GoogleDriveScreen extends StatefulWidget {
  final bool embedded;
  const GoogleDriveScreen({super.key, this.embedded = false});

  @override
  State<GoogleDriveScreen> createState() => _GoogleDriveScreenState();
}

class _GoogleDriveScreenState extends State<GoogleDriveScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _testingConnection = false;
  bool _uploading = false;
  bool _savingSettings = false;
  bool _savingOauthCreds = false;
  bool _obscureSecret = true;

  GoogleDriveConfig? _config;
  String _selectedAuthTab = 'oauth'; // 'oauth' or 'service_account'

  final TextEditingController _oauthClientIdController = TextEditingController();
  final TextEditingController _oauthClientSecretController = TextEditingController();

  final TextEditingController _folderRicevuteIdController = TextEditingController();
  final TextEditingController _folderRicevuteNomeController = TextEditingController();
  final TextEditingController _folderTessereIdController = TextEditingController();
  final TextEditingController _folderTessereNomeController = TextEditingController();

  static const String _uriLocalhost = 'http://localhost:8082/api/google-drive/oauth-callback/';
  static const String _uri127 = 'http://127.0.0.1:8082/api/google-drive/oauth-callback/';
  String _selectedRedirectUri = _uri127;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _oauthClientIdController.dispose();
    _oauthClientSecretController.dispose();
    _folderRicevuteIdController.dispose();
    _folderRicevuteNomeController.dispose();
    _folderTessereIdController.dispose();
    _folderTessereNomeController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final config = await _api.getGoogleDriveConfig();
      if (mounted) {
        setState(() {
          _config = config;
          if (config != null) {
            _selectedAuthTab = config.authType;
            if (config.oauthClientId.isNotEmpty) {
              _oauthClientIdController.text = config.oauthClientId;
            }
            _folderRicevuteIdController.text = config.folderRicevuteId;
            _folderRicevuteNomeController.text = config.folderRicevuteNome;
            _folderTessereIdController.text = config.folderTessereId;
            _folderTessereNomeController.text = config.folderTessereNome;
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

  Future<void> _switchAuthTab(String newType) async {
    if (_selectedAuthTab == newType) return;
    setState(() => _selectedAuthTab = newType);

    try {
      final res = await _api.switchGoogleDriveAuthType(newType);
      if (mounted && res['success'] == true) {
        _loadConfig();
      }
    } catch (_) {}
  }

  Future<void> _saveOAuthCredentials() async {
    final clientId = _oauthClientIdController.text.trim();
    final clientSecret = _oauthClientSecretController.text.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci sia il Client ID sia il Client Secret.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _savingOauthCreds = true);
    try {
      final res = await _api.saveGoogleDriveOAuthCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      if (mounted) {
        setState(() => _savingOauthCreds = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credenziali OAuth salvate con successo! Ora puoi connettere il tuo account.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore nel salvataggio delle credenziali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingOauthCreds = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startOAuthFlow() async {
    final clientId = _oauthClientIdController.text.trim();
    final clientSecret = _oauthClientSecretController.text.trim();

    setState(() => _testingConnection = true);
    try {
      final res = await _api.initGoogleDriveOAuth(
        clientId: clientId.isNotEmpty ? clientId : null,
        clientSecret: clientSecret.isNotEmpty ? clientSecret : null,
        redirectUri: _selectedRedirectUri,
      );

      if (mounted) {
        setState(() => _testingConnection = false);
        if (res['success'] == true && res['auth_url'] != null) {
          final authUrl = res['auth_url'] as String;
          final uri = Uri.parse(authUrl);

          // Apre il browser per il login Google
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(uri);
          }

          if (mounted) {
            _showOAuthPendingDialog();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Impossibile avviare l\'autenticazione OAuth.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _testingConnection = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore avvio autenticazione Google: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showOAuthPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.open_in_new, color: Colors.blue),
            SizedBox(width: 10),
            Text('Accesso Google in corso...'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si è aperta la finestra di autenticazione Google nel tuo browser.\n\n'
              '1. Seleziona il tuo account Google (es. tanto.tango25@gmail.com)\n'
              '2. Concedi l\'accesso a Google Drive\n'
              '3. Una volta visualizzata la pagina di conferma, clicca qui sotto su "Verifica Collegamento".',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'I file caricati saranno associati al tuo account personale e consumeranno la tua quota di 15 GB.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadConfig();
            },
            child: const Text('Chiudi'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check),
            label: const Text('Verifica Collegamento'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _testConnection();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectOAuth() async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Disconnetti Account Google'),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler disconnettere l\'account Google OAuth?\n'
          'Per caricare nuovamente file su Google Drive dovrai rieffettuare l\'accesso.',
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

    if (conf == true) {
      final res = await _api.disconnectGoogleDriveOAuth();
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account Google disconnesso.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore durante la disconnessione.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickAndUploadKey() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'p12', 'pem'],
      );

      if (result == null) return;

      final bytes = await result.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File vuoto o illeggibile.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _uploading = true);

      final res = await _api.uploadGoogleDriveKey(bytes, result.name);

      if (mounted) {
        setState(() => _uploading = false);
        if (res['success'] == true) {
          final detected = res['detected_type'] ?? '';
          final msg = detected == 'oauth'
              ? 'File credenziali OAuth caricato! Ora puoi cliccare su "Connetti con Google".'
              : 'Chiave Service Account "${result.name}" caricata con successo!';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.green.shade700,
            ),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore durante il caricamento della chiave.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    try {
      final res = await _api.testGoogleDriveConnection();
      if (mounted) {
        setState(() => _testingConnection = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(res['message'] ?? 'Connessione a Google Drive riuscita!')),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(res['error'] ?? 'Errore durante il test di connessione.')),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        _loadConfig();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _testingConnection = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _removeKey() async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Rimuovi Chiave Service Account'),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler eliminare la chiave privata Service Account di Google Drive memorizzata sul server?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conf == true) {
      final res = await _api.removeGoogleDriveKey();
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chiave Service Account rimossa.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore durante la rimozione.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openFolderBrowser({required String targetType}) async {
    final isConfigured = _config?.isConfigured ?? false;
    if (!isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa prima l\'accesso a Google Drive per sfogliare le cartelle.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isRicevute = targetType == 'ricevute';
    final currentFolderId = isRicevute
        ? _config?.folderRicevuteId
        : _config?.folderTessereId;
    final currentFolderName = isRicevute
        ? _config?.folderRicevuteNome
        : _config?.folderTessereNome;

    final selected = await showDialog<GoogleDriveFolderItem>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GoogleDriveFolderPickerDialog(
        title: isRicevute
            ? 'Seleziona Cartella per le RICEVUTE'
            : 'Seleziona Cartella per le TESSERE',
        initialFolderId: currentFolderId,
        initialFolderName: currentFolderName,
      ),
    );

    if (selected != null) {
      setState(() => _savingSettings = true);
      final updateData = isRicevute
          ? {
              'folder_ricevute_id': selected.id,
              'folder_ricevute_nome': selected.name,
            }
          : {
              'folder_tessere_id': selected.id,
              'folder_tessere_nome': selected.name,
            };

      final res = await _api.updateGoogleDriveConfig(updateData);
      if (mounted) {
        setState(() => _savingSettings = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cartella ${isRicevute ? "Ricevute" : "Tessere"} impostata su "${selected.name}"!',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
          _loadConfig();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore nel salvataggio della cartella.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearFolder({required String targetType}) async {
    final isRicevute = targetType == 'ricevute';
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rimuovi associazione cartella ${isRicevute ? "Ricevute" : "Tessere"}'),
        content: Text(
          'Sei sicuro di voler scollegare la cartella per ${isRicevute ? "le ricevute" : "le tessere"}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (conf == true) {
      setState(() => _savingSettings = true);
      final updateData = isRicevute
          ? {'folder_ricevute_id': '', 'folder_ricevute_nome': ''}
          : {'folder_tessere_id': '', 'folder_tessere_nome': ''};

      final res = await _api.updateGoogleDriveConfig(updateData);
      if (mounted) {
        setState(() => _savingSettings = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cartella ${isRicevute ? "Ricevute" : "Tessere"} scollegata.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadConfig();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadConfig,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 20),

                      // Auth Mode Switcher (OAuth 2.0 vs Service Account)
                      _buildAuthModeSelector(),
                      const SizedBox(height: 20),

                      // Primary Auth Card
                      if (_selectedAuthTab == 'oauth')
                        _buildOAuthSection()
                      else
                        _buildKeyDetailsCard(),
                      const SizedBox(height: 20),

                      // Folders Section (Ricevute e Tessere)
                      _buildDestinationFoldersSection(),
                      const SizedBox(height: 20),

                      // Setup Instructions Card
                      _buildInstructionsCard(),
                    ],
                  ),
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrazione Google Drive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildHeaderCard() {
    final isConfigured = _config?.isConfigured ?? false;
    final isOAuth = _config?.authType == 'oauth';
    final userEmail = isOAuth
        ? (_config?.oauthUserEmail ?? '')
        : (_config?.clientEmail ?? '');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isConfigured
                ? [Colors.blue.shade900, Colors.blue.shade600]
                : [Colors.grey.shade800, Colors.grey.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_to_drive,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Google Drive',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConfigured ? Colors.green.shade600 : Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isConfigured
                                  ? (isOAuth ? 'OAuth 2.0 Connesso' : 'Service Account Attivo')
                                  : 'Non configurato',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isConfigured
                        ? (userEmail.isNotEmpty
                            ? 'Account collegato: $userEmail. I file caricati usano la quota del tuo account personale.'
                            : 'Google Drive è collegato e pronto per il salvataggio automatico di ricevute e tessere.')
                        : 'Collega Google Drive per salvare e archiviare le ricevute in automatico.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _switchAuthTab('oauth'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedAuthTab == 'oauth' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedAuthTab == 'oauth'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_circle,
                      size: 20,
                      color: _selectedAuthTab == 'oauth' ? Colors.blue.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Account Google Personale (OAuth 2.0)',
                      style: TextStyle(
                        fontWeight: _selectedAuthTab == 'oauth' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedAuthTab == 'oauth' ? Colors.blue.shade900 : Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '15 GB Quota',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => _switchAuthTab('service_account'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedAuthTab == 'service_account' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedAuthTab == 'service_account'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.vpn_key_outlined,
                      size: 20,
                      color: _selectedAuthTab == 'service_account' ? Colors.blue.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service Account (Chiave JSON)',
                      style: TextStyle(
                        fontWeight: _selectedAuthTab == 'service_account' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedAuthTab == 'service_account' ? Colors.blue.shade900 : Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOAuthSection() {
    final isConnected = _config?.isOauthConnected ?? false;
    final userEmail = _config?.oauthUserEmail ?? '';
    final userName = _config?.oauthUserName ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_pin_outlined,
                  color: isConnected ? Colors.green.shade700 : Colors.blue.shade700,
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Accesso OAuth 2.0 (Quota Personale Google)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Questo metodo effettua l\'accesso con il tuo account Google reale (es. tanto.tango25@gmail.com). I file caricati saranno di tua proprietà e consumeranno la tua quota personale di 15 GB.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (isConnected) ...[
              // Stato Connesso
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName.isNotEmpty ? userName : 'Account Google Connesso',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'ATTIVO',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (userEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (_config!.lastTestMessage.isNotEmpty)
                            Text(
                              _config!.lastTestMessage,
                              style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                            ),
                          if (_config!.lastTestedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Verificato il: ${_formatDate(_config!.lastTestedAt!)}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.network_check, size: 18),
                    label: Text(_testingConnection ? 'Test in corso...' : 'Verifica Connessione e Spazio'),
                    onPressed: _testingConnection ? null : _testConnection,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Ricollega Account Google'),
                    onPressed: _startOAuthFlow,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Disconnetti'),
                    onPressed: _disconnectOAuth,
                  ),
                ],
              ),
            ] else ...[
              // Non Connesso - Configurazione Credenziali & Pulsante Accesso
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Credenziali App Google OAuth 2.0 (Client ID & Secret)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Carica client_secret.json'),
                          onPressed: _uploading ? null : _pickAndUploadKey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _oauthClientIdController,
                      decoration: InputDecoration(
                        labelText: 'Client ID OAuth 2.0',
                        hintText: 'es. 123456789-abcdef.apps.googleusercontent.com',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        prefixIcon: const Icon(Icons.vpn_key, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _oauthClientSecretController,
                      obscureText: _obscureSecret,
                      decoration: InputDecoration(
                        labelText: 'Client Secret',
                        hintText: _config?.hasOauthClientSecret == true
                            ? '•••••••••••••••• (già memorizzato)'
                            : 'es. GOCSPX-xxxxxxxxxxxxxxxx',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureSecret ? Icons.visibility : Icons.visibility_off, size: 18),
                          onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: _savingOauthCreds
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save, size: 16),
                          label: const Text('Salva Credenziali'),
                          onPressed: _savingOauthCreds ? null : _saveOAuthCredentials,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link, size: 18, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Text(
                                'URI di reindirizzamento autorizzato (Google Cloud Console)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Google richiede che l\'indirizzo inserito in Google Cloud Console corrisponda esattamente a quello usato. Seleziona quale indirizzo hai registrato:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ChoiceChip(
                                label: const Text('127.0.0.1 (Consigliato)'),
                                selected: _selectedRedirectUri == _uri127,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedRedirectUri = _uri127);
                                },
                              ),
                              ChoiceChip(
                                label: const Text('localhost'),
                                selected: _selectedRedirectUri == _uriLocalhost,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedRedirectUri = _uriLocalhost);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: SelectableText(
                                    _selectedRedirectUri,
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copia URI selezionato',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _selectedRedirectUri));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Copiato negli appunti: $_selectedRedirectUri')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💡 Suggerimento: In Google Cloud Console puoi inserire entrambi gli indirizzi (127.0.0.1 e localhost) per evitare qualsiasi errore!',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Pulsante Connetti con Google
              Center(
                child: SizedBox(
                  width: 320,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login, color: Colors.blue),
                    label: Text(
                      _testingConnection ? 'Apertura in corso...' : 'Connetti con Google',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _testingConnection ? null : _startOAuthFlow,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeyDetailsCard() {
    final isConfigured = _config?.isSaConfigured ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.vpn_key_outlined,
                  color: isConfigured ? Colors.blue.shade700 : Colors.grey.shade700,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Credenziali Account di Servizio (Service Account)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Il file JSON della chiave privata permette al sistema di autenticarsi in modo sicuro con le API di Google Drive.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (!isConfigured) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 52, color: Colors.blue.shade700),
                    const SizedBox(height: 12),
                    const Text(
                      'Nessuna chiave privata Service Account configurata',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Carica il file .json del Service Account scaricato da Google Cloud Console',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Seleziona File Chiave (.json)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _uploading ? null : _pickAndUploadKey,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Dettagli chiave caricata
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.description_outlined,
                      label: 'Nome File',
                      value: _config!.filename,
                      extra: Text(
                        '(${_config!.fileSizeFormatted})',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                    const Divider(height: 20),
                    if (_config!.clientEmail.isNotEmpty) ...[
                      _buildInfoRow(
                        icon: Icons.alternate_email,
                        label: 'Email Account di Servizio',
                        value: _config!.clientEmail,
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copia Email per condivisione Drive',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _config!.clientEmail));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email account di servizio copiata negli appunti!')),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 20),
                    ],
                    if (_config!.projectId.isNotEmpty) ...[
                      _buildInfoRow(
                        icon: Icons.cloud_outlined,
                        label: 'Progetto Google Cloud',
                        value: _config!.projectId,
                      ),
                      const Divider(height: 20),
                    ],
                    _buildInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Ultimo Aggiornamento',
                      value: _formatDate(_config!.updatedAt),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Risultato dell'ultimo test di connessione
              if (_config!.lastTestStatus.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _config!.lastTestStatus == 'success' ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _config!.lastTestStatus == 'success' ? Colors.green.shade300 : Colors.red.shade300,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _config!.lastTestStatus == 'success' ? Icons.check_circle : Icons.error,
                        color: _config!.lastTestStatus == 'success' ? Colors.green.shade700 : Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _config!.lastTestStatus == 'success' ? 'Verifica Connessione: Superata' : 'Verifica Connessione: Errore',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _config!.lastTestStatus == 'success' ? Colors.green.shade900 : Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _config!.lastTestMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: _config!.lastTestStatus == 'success' ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                            if (_config!.lastTestedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Verificato il: ${_formatDate(_config!.lastTestedAt!)}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Pulsanti azioni
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.network_check, size: 18),
                    label: Text(_testingConnection ? 'Test in corso...' : 'Testa Connessione'),
                    onPressed: _testingConnection ? null : _testConnection,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sostituisci Chiave'),
                    onPressed: _uploading ? null : _pickAndUploadKey,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Rimuovi Chiave'),
                    onPressed: _removeKey,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationFoldersSection() {
    final isConfigured = _config?.isConfigured ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.folder_copy_outlined, color: Colors.indigo, size: 24),
                SizedBox(width: 10),
                Text(
                  'Cartelle di Destinazione Google Drive',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sfoglia l\'alberatura delle tue cartelle e seleziona dove archiviare le ricevute e le tessere emesse.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Card Cartella Ricevute
            _buildFolderCard(
              title: 'Cartella Ricevute',
              description: 'Cartella Google Drive per il salvataggio automatico delle ricevute in PDF.',
              icon: Icons.receipt_long,
              color: Colors.teal,
              folderId: _config?.folderRicevuteId ?? '',
              folderName: _config?.folderRicevuteNome ?? '',
              targetType: 'ricevute',
              isConfigured: isConfigured,
            ),

            const SizedBox(height: 20),

            // Card Cartella Tessere
            _buildFolderCard(
              title: 'Cartella Tessere',
              description: 'Cartella Google Drive per l\'archiviazione delle tessere dei soci e allievi.',
              icon: Icons.badge_outlined,
              color: Colors.purple,
              folderId: _config?.folderTessereId ?? '',
              folderName: _config?.folderTessereNome ?? '',
              targetType: 'tessere',
              isConfigured: isConfigured,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard({
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required String folderId,
    required String folderName,
    required String targetType,
    required bool isConfigured,
  }) {
    final hasFolder = folderId.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: hasFolder ? color.shade50.withValues(alpha: 0.4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFolder ? color.shade300 : Colors.grey.shade300,
          width: hasFolder ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color.shade800, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color.shade900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (hasFolder)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Selezionata',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Non impostata',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          if (hasFolder) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.folder, size: 18, color: color.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              folderName.isNotEmpty ? folderName : 'Cartella selezionata',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID Drive: $folderId',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color.shade800,
                    side: BorderSide(color: color.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Cambia'),
                  onPressed: (!isConfigured || _savingSettings)
                      ? null
                      : () => _openFolderBrowser(targetType: targetType),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  tooltip: 'Rimuovi selezione',
                  onPressed: (!isConfigured || _savingSettings)
                      ? null
                      : () => _clearFolder(targetType: targetType),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nessuna cartella di Google Drive attualmente assegnata.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Sfoglia e Seleziona'),
                  onPressed: (!isConfigured || _savingSettings)
                      ? null
                      : () => _openFolderBrowser(targetType: targetType),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 1,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blueGrey.shade800),
                const SizedBox(width: 10),
                Text(
                  _selectedAuthTab == 'oauth'
                      ? 'Guida: Come creare il Client ID OAuth 2.0 su Google Cloud Console'
                      : 'Come condividere le cartelle con il Service Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedAuthTab == 'oauth') ...[
              _buildStepRow('1', 'Vai su Google Cloud Console (console.cloud.google.com) nel tuo progetto (es. wamanager).'),
              _buildStepRow('2', 'Nel menu laterale apri "APIs & Services" > "Credentials" (Credenziali).'),
              _buildStepRow('3', 'Clicca su "+ CREATE CREDENTIALS" in alto e scegli "OAuth client ID".'),
              _buildStepRow('4', 'Scegli come Application type: "Web application" (Applicazione web).'),
              _buildStepRow('5', 'Sotto "Authorized redirect URIs" clicca "+ ADD URI" e inserisci ENTRAMBI i seguenti indirizzi:\n  • http://127.0.0.1:8082/api/google-drive/oauth-callback/\n  • http://localhost:8082/api/google-drive/oauth-callback/'),
              _buildStepRow('6', 'Clicca "CREATE", poi copia il Client ID e il Client Secret generati e incollali qui sopra (oppure scarica il file JSON e caricalo con il pulsante apposito).'),
              _buildStepRow('7', 'Infine clicca su "Connetti con Google" per autorizzare il tuo account personale!'),
            ] else ...[
              _buildStepRow('1', 'Crea una cartella nel tuo Google Drive personale o aziendale (es. "Gestione Tango" con sottocartelle "Ricevute" e "Tessere").'),
              _buildStepRow('2', 'Fai clic destro sulla cartella principale o sottocartella > "Condividi".'),
              _buildStepRow('3', 'Incolla l\'email del Service Account (puoi copiarla dal riquadro sopra con l\'icona Copia).'),
              _buildStepRow('4', 'Imposta il ruolo su "Editor" e togli la spunta su "Invia notifica", poi clicca "Condividi".'),
              _buildStepRow('5', 'Torna qui e clicca "Sfoglia e Seleziona" per scegliere la cartella associata!'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(String stepNum, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.indigo.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? extra,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(width: 8),
                    extra,
                  ],
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// DIALOG PER SFOGLIARE L'ALBERATURA DI GOOGLE DRIVE
// ─────────────────────────────────────────────────────────────

class GoogleDriveFolderPickerDialog extends StatefulWidget {
  final String title;
  final String? initialFolderId;
  final String? initialFolderName;

  const GoogleDriveFolderPickerDialog({
    super.key,
    required this.title,
    this.initialFolderId,
    this.initialFolderName,
  });

  @override
  State<GoogleDriveFolderPickerDialog> createState() => _GoogleDriveFolderPickerDialogState();
}

class _GoogleDriveFolderPickerDialogState extends State<GoogleDriveFolderPickerDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<GoogleDriveFolderItem> _folders = [];
  GoogleDriveFolderItem? _selectedFolder;

  // Breadcrumbs: [{'id': 'root', 'name': 'Radice / Condivisi'}]
  final List<Map<String, String>> _breadcrumbs = [
    {'id': 'root', 'name': 'Radice / Condivisi'}
  ];

  String get _currentParentId => _breadcrumbs.last['id']!;
  String get _currentParentName => _breadcrumbs.last['name']!;

  @override
  void initState() {
    super.initState();
    _loadFolders('root');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFolders(String parentId) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedFolder = null;
    });

    try {
      final res = await _api.getGoogleDriveFolders(
        parentId: parentId == 'root' ? null : parentId,
      );

      if (mounted) {
        if (res['success'] == true) {
          final rawFolders = (res['folders'] as List<dynamic>? ?? []);
          final parsed = rawFolders.map((f) => GoogleDriveFolderItem.fromJson(f)).toList();

          setState(() {
            _folders = parsed;
            _loading = false;
          });
        } else {
          setState(() {
            _error = res['error'] ?? 'Errore nel recupero delle cartelle da Google Drive.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore di comunicazione: $e';
          _loading = false;
        });
      }
    }
  }

  void _navigateToSubfolder(GoogleDriveFolderItem folder) {
    setState(() {
      _breadcrumbs.add({'id': folder.id, 'name': folder.name});
      _searchCtrl.clear();
    });
    _loadFolders(folder.id);
  }

  void _jumpToBreadcrumb(int index) {
    if (index >= 0 && index < _breadcrumbs.length - 1) {
      final target = _breadcrumbs[index];
      setState(() {
        _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
        _searchCtrl.clear();
      });
      _loadFolders(target['id']!);
    }
  }

  void _navigateUp() {
    if (_breadcrumbs.length > 1) {
      _jumpToBreadcrumb(_breadcrumbs.length - 2);
    }
  }

  Future<void> _createNewFolder() async {
    final textCtrl = TextEditingController();
    final createdName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Nuova Cartella Google Drive'),
          ],
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome cartella',
            hintText: 'es. Ricevute 2026',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) Navigator.pop(ctx, val.trim());
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              if (textCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, textCtrl.text.trim());
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );

    if (createdName != null && createdName.isNotEmpty) {
      setState(() => _loading = true);
      final res = await _api.createGoogleDriveFolder(
        name: createdName,
        parentId: _currentParentId == 'root' ? null : _currentParentId,
      );
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cartella "$createdName" creata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadFolders(_currentParentId);
        } else {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Errore creazione cartella.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _confirmSelection() {
    if (_selectedFolder != null) {
      Navigator.pop(context, _selectedFolder);
    } else if (_currentParentId != 'root') {
      // Seleziona la cartella aperta corrente
      Navigator.pop(
        context,
        GoogleDriveFolderItem(
          id: _currentParentId,
          name: _currentParentName,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _searchCtrl.text.trim().toLowerCase();
    final displayedFolders = filter.isEmpty
        ? _folders
        : _folders.where((f) => f.name.toLowerCase().contains(filter)).toList();

    final canConfirm = _selectedFolder != null || _currentParentId != 'root';
    final selectionLabel = _selectedFolder != null
        ? 'Seleziona "${_selectedFolder!.name}"'
        : (_currentParentId != 'root' ? 'Seleziona cartella corrente ("$_currentParentName")' : 'Seleziona una cartella');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          children: [
            // Header del Dialog
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_to_drive, color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Barra Breadcrumbs di navigazione
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    tooltip: 'Livello superiore',
                    onPressed: _breadcrumbs.length > 1 && !_loading ? _navigateUp : null,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_breadcrumbs.length, (idx) {
                          final isLast = idx == _breadcrumbs.length - 1;
                          final b = _breadcrumbs[idx];
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: (!isLast && !_loading) ? () => _jumpToBreadcrumb(idx) : null,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      if (idx == 0) ...[
                                        const Icon(Icons.home, size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        b['name']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                                          color: isLast ? Colors.black87 : Colors.blue.shade700,
                                          decoration: isLast ? TextDecoration.none : TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isLast)
                                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Ricarica elenco',
                    onPressed: _loading ? null : () => _loadFolders(_currentParentId),
                  ),
                ],
              ),
            ),

            // Barra di ricerca e pulsante Nuova Cartella
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filtra cartelle...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.create_new_folder, size: 18),
                    label: const Text('Nuova'),
                    onPressed: _loading ? null : _createNewFolder,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Contenuto principale: Lista cartelle
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 14),
                          Text('Caricamento cartelle da Google Drive...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Riprova'),
                                  onPressed: () => _loadFolders(_currentParentId),
                                ),
                              ],
                            ),
                          ),
                        )
                      : displayedFolders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    filter.isNotEmpty
                                        ? 'Nessuna cartella corrisponde alla ricerca "$filter"'
                                        : 'Nessuna sottocartella trovata qui.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  if (_currentParentId != 'root') ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Puoi comunque selezionare la cartella corrente "$_currentParentName" premendo il tasto in basso.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: displayedFolders.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final folder = displayedFolders[idx];
                                final isSelected = _selectedFolder?.id == folder.id;

                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: folder.isShared
                                          ? Colors.amber.shade100
                                          : (folder.isDrive ? Colors.purple.shade100 : Colors.blue.shade100),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      folder.isShared
                                          ? Icons.folder_shared
                                          : (folder.isDrive ? Icons.dns : Icons.folder),
                                      color: folder.isShared
                                          ? Colors.amber.shade800
                                          : (folder.isDrive ? Colors.purple.shade800 : Colors.blue.shade800),
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    folder.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'ID: ${folder.id}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<String>(
                                        value: folder.id,
                                        groupValue: _selectedFolder?.id,
                                        onChanged: (val) {
                                          setState(() => _selectedFolder = folder);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                        tooltip: 'Apri sottocartelle',
                                        onPressed: () => _navigateToSubfolder(folder),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() => _selectedFolder = folder);
                                  },
                                );
                              },
                            ),
            ),

            const Divider(height: 1),

            // Footer con pulsanti di selezione e annulla
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedFolder != null
                          ? 'Selezionata: ${_selectedFolder!.name}'
                          : (_currentParentId != 'root'
                              ? 'Cartella aperta: $_currentParentName'
                              : 'Tocca una cartella per selezionarla o entra per sfogliare'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedFolder != null ? Colors.blue.shade800 : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(selectionLabel),
                    onPressed: canConfirm ? _confirmSelection : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
