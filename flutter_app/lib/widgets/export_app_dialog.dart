import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ExportAppDialog extends StatefulWidget {
  const ExportAppDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ExportAppDialog(),
    );
  }

  @override
  State<ExportAppDialog> createState() => _ExportAppDialogState();
}

class _ExportAppDialogState extends State<ExportAppDialog> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  int _deviceSubTab = 0; // 0: iPhone, 1: Android, 2: PC / QR Code

  Map<String, dynamic>? _apkInfo;
    bool _downloadingApk = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _detectInitialDeviceSubTab();
    _loadApkInfo();
  }

  void _detectInitialDeviceSubTab() {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        _deviceSubTab = 0;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        _deviceSubTab = 1;
      } else {
        _deviceSubTab = 2;
      }
      return;
    }

    // Su Web, analizziamo se siamo su mobile o desktop
    // defaultTargetPlatform su web rispecchia l'OS sottostante
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _deviceSubTab = 0;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      _deviceSubTab = 1;
    } else {
      _deviceSubTab = 2;
    }
  }

  Future<void> _loadApkInfo() async {
    try {
      final info = await _api.getApkInfo();
      if (mounted) {
        setState(() {
          _apkInfo = info;
          
        });
      }
    } catch (_) {
      if (mounted) {
        
      }
    }
  }

  String _getMobileAppUrl() {
    if (kIsWeb) {
      final base = Uri.base;
      // Costruiamo l'URL pulito
      return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}${base.path}';
    }
    return _api.baseUrl;
  }

  Future<void> _downloadApk() async {
    setState(() => _downloadingApk = true);
    try {
      final downloadUrl = _api.getApkDownloadUrl();
      final uri = Uri.parse(downloadUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download del pacchetto APK avviato! Controlla i download del browser.'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il download: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingApk = false);
    }
  }

  void _copyMobileUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Indirizzo dell\'app mobile copiato negli appunti!'),
        backgroundColor: Color(0xFF8B2529),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isMobileScreen = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobileScreen ? 16 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              color: const Color(0xFFFBF8F5),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.install_mobile_rounded, color: primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esporta come APP Mobile',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Utilizza TantoTango Manager sul tuo smartphone come una vera app',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Chiudi',
                  ),
                ],
              ),
            ),

            // Tab Bar Principale
            Container(
              color: const Color(0xFFFBF8F5),
              child: TabBar(
                controller: _tabController,
                labelColor: primary,
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.touch_app_outlined, size: 18),
                    text: 'Web App PWA (Consigliato)',
                  ),
                  Tab(
                    icon: Icon(Icons.android, size: 18),
                    text: 'Pacchetto APK Android',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Contenuto Tab
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPwaTab(primary, isMobileScreen),
                  _buildApkTab(primary, isMobileScreen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: Web App / PWA (Aggiungi alla Schermata Home)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPwaTab(Color primary, bool isMobileScreen) {
    final mobileUrl = _getMobileAppUrl();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner di presentazione
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La versione Web per smartphone è una Progressive Web App: si apre a schermo intero come una vera applicazione, è leggerissima e si aggiorna da sola senza passare dallo Store.',
                    style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Selettore del dispositivo / browser
          Text(
            'SELEZIONA IL TUO DISPOSITIVO O PROCEDURA:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.blueGrey.shade600,
            ),
          ),
          const SizedBox(height: 8),

          // Segmented buttons per dispositivo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apple, size: 16),
                      SizedBox(width: 6),
                      Text('iPhone / iPad (iOS)'),
                    ],
                  ),
                  selected: _deviceSubTab == 0,
                  onSelected: (val) {
                    if (val) setState(() => _deviceSubTab = 0);
                  },
                  selectedColor: primary.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: _deviceSubTab == 0 ? primary : const Color(0xFF475569),
                    fontWeight: _deviceSubTab == 0 ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.android, size: 16),
                      SizedBox(width: 6),
                      Text('Android (Chrome / Samsung)'),
                    ],
                  ),
                  selected: _deviceSubTab == 1,
                  onSelected: (val) {
                    if (val) setState(() => _deviceSubTab = 1);
                  },
                  selectedColor: primary.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: _deviceSubTab == 1 ? primary : const Color(0xFF475569),
                    fontWeight: _deviceSubTab == 1 ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2, size: 16),
                      SizedBox(width: 6),
                      Text('Da PC a Smartphone (QR)'),
                    ],
                  ),
                  selected: _deviceSubTab == 2,
                  onSelected: (val) {
                    if (val) setState(() => _deviceSubTab = 2);
                  },
                  selectedColor: primary.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: _deviceSubTab == 2 ? primary : const Color(0xFF475569),
                    fontWeight: _deviceSubTab == 2 ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Guida per dispositivo selezionato
          if (_deviceSubTab == 0)
            _buildIosGuide(primary)
          else if (_deviceSubTab == 1)
            _buildAndroidGuide(primary)
          else
            _buildPcQrGuide(primary, mobileUrl),
        ],
      ),
    );
  }

  // Guida iOS
  Widget _buildIosGuide(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apple, color: Colors.black87, size: 22),
              SizedBox(width: 8),
              Text(
                'Come esportare l\'APP su iPhone / iPad:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStepRow(
            number: '1',
            icon: Icons.ios_share,
            title: 'Tocca il pulsante "Condividi"',
            description: 'Nella barra inferiore di Safari (o in alto su iPad), tocca l\'icona del quadrato con la freccia verso l\'alto.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            number: '2',
            icon: Icons.add_box_outlined,
            title: 'Seleziona "Aggiungi alla schermata Home"',
            description: 'Scorri il menu delle azioni verso il basso e tocca l\'opzione con il simbolo del più "+".',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            number: '3',
            icon: Icons.check_circle_outline,
            title: 'Conferma toccando "Aggiungi"',
            description: 'L\'icona di TantoTango Manager verrà aggiunta alla Home del tuo iPhone. Si avvierà a schermo intero come una vera app nativa!',
          ),
        ],
      ),
    );
  }

  // Guida Android PWA
  Widget _buildAndroidGuide(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.android, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 8),
              Text(
                'Come esportare l\'APP su Android:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStepRow(
            number: '1',
            icon: Icons.more_vert,
            title: 'Apri il menu del browser',
            description: 'In Chrome, Samsung Internet o Edge, tocca i tre puntini verticali ⋮ in alto a destra.',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            number: '2',
            icon: Icons.install_mobile,
            title: 'Tocca "Installa app" o "Aggiungi a Home"',
            description: 'Nel menu a tendina, tocca la voce "Installa applicazione" oppure "Aggiungi a schermata Home".',
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            number: '3',
            icon: Icons.check_circle_outline,
            title: 'Conferma l\'installazione',
            description: 'L\'app TantoTango sarà salvata tra le applicazioni del tuo telefono e si aprirà senza barre di navigazione.',
          ),
        ],
      ),
    );
  }

  // Guida QR Code da PC
  Widget _buildPcQrGuide(Color primary, String mobileUrl) {
    final qrApiUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(mobileUrl)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Sei al computer? Apri subito l\'app sul tuo smartphone:',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          // Box QR Code con fallback
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Image.network(
              qrApiUrl,
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 150,
                  height: 150,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (ctx, err, stack) {
                return Container(
                  width: 150,
                  height: 150,
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Icon(Icons.qr_code, size: 64, color: Color(0xFF94A3B8)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Inquadra il QR Code con la fotocamera del tuo cellulare',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // URL box + pulsante copia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mobileUrl,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: primary,
                  ),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copia'),
                  onPressed: () => _copyMobileUrl(mobileUrl),
                ),
              ],
            ),
          ),

          if (mobileUrl.contains('localhost') || mobileUrl.contains('127.0.0.1')) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggerimento: Per accedere da cellulare in locale, assicurati che lo smartphone sia connesso al medesimo Wi-Fi usando l\'indirizzo IP locale del PC (es. 192.168.x.x).',
                      style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: Pacchetto Nativo Android (File APK)
  // ─────────────────────────────────────────────────────────────
  Widget _buildApkTab(Color primary, bool isMobileScreen) {
    final hasApk = _apkInfo?['available'] == true;
    final sizeMb = _apkInfo?['size_mb'];
    final dateStr = _apkInfo?['modified_at'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card principale pacchetto Android
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.android, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TantoTango Manager per Android',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            hasApk
                                ? 'File APK Release compilato ($sizeMb MB${dateStr != null ? ' • $dateStr' : ''})'
                                : 'Pacchetto applicativo autonomo per smartphone Android',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF33691E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Pulsante Scarica APK
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _downloadingApk
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 22),
                    label: Text(
                      _downloadingApk ? 'Avvio download...' : 'SCARICA APK ANDROID (.apk)',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    onPressed: _downloadingApk ? null : _downloadApk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Istruzioni di installazione APK
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Come installare il file APK su Android:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                _buildStepRow(
                  number: '1',
                  icon: Icons.file_download_done,
                  title: 'Scarica il file .apk',
                  description: 'Premi il pulsante verde qui sopra e attendi il completamento del download nel tuo browser.',
                ),
                const SizedBox(height: 10),
                _buildStepRow(
                  number: '2',
                  icon: Icons.security,
                  title: 'Autorizza sorgenti sconosciute',
                  description: 'Se Android mostra un avviso di sicurezza, tocca "Impostazioni" e attiva "Consenti da questa sorgente".',
                ),
                const SizedBox(height: 10),
                _buildStepRow(
                  number: '3',
                  icon: Icons.open_in_new,
                  title: 'Installa e avvia l\'app',
                  description: 'Premi "Installa" e apri TantoTango Manager per accedere.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper riga passo-passo
  Widget _buildStepRow({
    required String number,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF8B2529).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF8B2529),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
