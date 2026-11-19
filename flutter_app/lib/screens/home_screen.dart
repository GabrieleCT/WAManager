import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api_service.dart';
import 'presenze_screen.dart';
import 'gestione_presenze_screen.dart';
import 'messaggistica_screen.dart';
import 'lezioni_screen.dart';
import 'anagrafica_allievi_screen.dart';
import 'scuole_screen.dart';
import 'corsi_screen.dart';
import 'argomenti_screen.dart';
import 'pagamenti_screen.dart';
import 'ricevute_screen.dart';
import 'bilancio_screen.dart';
import 'asd_screen.dart';
import 'login_screen.dart';
import 'impostazioni_screen.dart';

enum NavSection {
  menu,
  presenze,
  messaggistica,
  lezioni,
  anagrafica,
  scuole,
  corsi,
  argomenti,
  pagamenti,
  ricevute,
  bilancio,
  asd,
  impostazioni,
}

class _NavItem {
  final NavSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget widget;
  final bool availableOnMobile;

  const _NavItem({
    required this.section,
    required this.label,
    required this.icon,
    IconData? selectedIcon,
    required this.widget,
    this.availableOnMobile = true,
  }) : selectedIcon = selectedIcon ?? icon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavSection _currentSection = NavSection.menu;

  static const List<_NavItem> _items = [
    _NavItem(
      section: NavSection.presenze,
      label: 'Presenze',
      icon: Icons.how_to_reg_outlined,
      selectedIcon: Icons.how_to_reg,
      widget: const GestionePresenzeScreen(),
      availableOnMobile: true,
    ),
    _NavItem(
      section: NavSection.messaggistica,
      label: 'Messaggistica',
      icon: Icons.chat_outlined,
      selectedIcon: Icons.chat,
      widget: MessaggisticaScreen(),
      availableOnMobile: false, // Esclusa da Mobile
    ),
    _NavItem(
      section: NavSection.lezioni,
      label: 'Lezioni',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event,
      widget: LezioniScreen(),
      availableOnMobile: false, // Esclusa da Mobile
    ),
    _NavItem(
      section: NavSection.anagrafica,
      label: 'Anagrafica',
      icon: Icons.people_alt_outlined,
      selectedIcon: Icons.people_alt,
      widget: AnagraficaAllieviScreen(),
      availableOnMobile: true,
    ),
    _NavItem(
      section: NavSection.scuole,
      label: 'Scuole',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      widget: ScuoleScreen(),
      availableOnMobile: false, // Esclusa da Mobile
    ),
    _NavItem(
      section: NavSection.corsi,
      label: 'Corsi',
      icon: Icons.class_outlined,
      selectedIcon: Icons.class_,
      widget: CorsiScreen(),
      availableOnMobile: true,
    ),
    _NavItem(
      section: NavSection.argomenti,
      label: 'Argomenti',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      widget: ArgomentiScreen(),
      availableOnMobile: true,
    ),
    _NavItem(
      section: NavSection.pagamenti,
      label: 'Pagamenti',
      icon: Icons.euro_outlined,
      selectedIcon: Icons.euro,
      widget: PagamentiScreen(),
      availableOnMobile: true,
    ),
    _NavItem(
      section: NavSection.ricevute,
      label: 'Ricevute',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      widget: RicevuteScreen(),
      availableOnMobile: true,
    ),
    _NavItem(
      section: NavSection.bilancio,
      label: 'Bilancio',
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance,
      widget: BilancioScreen(),
      availableOnMobile: false, // Esclusa da Mobile
    ),
    _NavItem(
      section: NavSection.asd,
      label: 'ASD',
      icon: Icons.corporate_fare_outlined,
      selectedIcon: Icons.corporate_fare,
      widget: AsdScreen(),
      availableOnMobile: false, // Esclusa da Mobile
    ),
    _NavItem(
      section: NavSection.impostazioni,
      label: 'Impostazioni',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      widget: ImpostazioniScreen(),
      availableOnMobile: false, // Esclusa da Mobile
    ),
  ];

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma Logout'),
        content: const Text("Sei sicuro di voler uscire dall'applicazione?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Esci')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ApiService().logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    // Se siamo su desktop e la sezione è 'menu', fallback alla sezione principale 'presenze'
    if (isDesktop && _currentSection == NavSection.menu) {
      _currentSection = NavSection.presenze;
    }

    // Se siamo su mobile e la sezione corrente non è disponibile su mobile, fallback a Menù
    if (!isDesktop && _currentSection != NavSection.menu) {
      final currentItem = _items.firstWhere(
        (i) => i.section == _currentSection,
        orElse: () => _items[0],
      );
      if (!currentItem.availableOnMobile) {
        _currentSection = NavSection.menu;
      }
    }

    if (isDesktop) {
      // Layout Desktop / Tablet con NavigationRail laterale (tutte le 12 sezioni)
      final desktopSelectedIndex = _items.indexWhere((i) => i.section == _currentSection);
      final activeItem = _items[desktopSelectedIndex >= 0 ? desktopSelectedIndex : 0];
      return Scaffold(
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: desktopSelectedIndex >= 0 ? desktopSelectedIndex : 0,
                        onDestinationSelected: (idx) => setState(() => _currentSection = _items[idx].section),
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        trailing: Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FutureBuilder<PackageInfo>(
                                    future: PackageInfo.fromPlatform(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Text('v${snapshot.data!.version}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.logout, color: Colors.red),
                                    tooltip: 'Logout',
                                    onPressed: _logout,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        destinations: _items.map((item) {
                          return NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: activeItem.widget),
          ],
        ),
      );
    }

    // ─── Layout Mobile con Schermata Menù a Icone Grandi o Schermata Attiva ───
    final mobileItems = _items.where((i) => i.availableOnMobile).toList();
    final isMenuSection = _currentSection == NavSection.menu;
    final activeItem = isMenuSection
        ? null
        : _items.firstWhere((i) => i.section == _currentSection, orElse: () => _items[0]);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: isMenuSection
          ? AppBar(
              backgroundColor: const Color(0xFF8B2529),
              foregroundColor: Colors.white,
              elevation: 2,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 28,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TantoTango Manager',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Menù Principale',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: _logout,
                ),
              ],
            )
          : null,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 36,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'TantoTango Manager',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Gestionale scuola di ballo',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: Color(0xFF8B2529)),
              title: const Text('Menù Principale', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: isMenuSection,
              selectedColor: const Color(0xFF8B2529),
              onTap: () {
                setState(() => _currentSection = NavSection.menu);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...mobileItems.map((item) {
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.label == 'Anagrafica' ? 'Anagrafica Allievi' : item.label),
                selected: _currentSection == item.section,
                selectedColor: const Color(0xFF8B2529),
                onTap: () {
                  setState(() => _currentSection = item.section);
                  Navigator.pop(context);
                },
              );
            }),
            const Divider(),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('v${snapshot.data!.version}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  );
                }
                return const SizedBox();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: isMenuSection ? _buildMobileMenuBody(context) : activeItem!.widget,
      bottomNavigationBar: Builder(
        builder: (ctx) {
          int navIndex;
          if (_currentSection == NavSection.menu) {
            navIndex = 0;
          } else if (_currentSection == NavSection.presenze) {
            navIndex = 1;
          } else if (_currentSection == NavSection.anagrafica) {
            navIndex = 2;
          } else if (_currentSection == NavSection.pagamenti) {
            navIndex = 3;
          } else {
            navIndex = 4;
          }

          return NavigationBar(
            selectedIndex: navIndex,
            backgroundColor: Colors.white,
            elevation: 8,
            indicatorColor: const Color(0xFF8B2529).withValues(alpha: 0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (idx) {
              if (idx == 0) {
                setState(() => _currentSection = NavSection.menu);
              } else if (idx == 1) {
                setState(() => _currentSection = NavSection.presenze);
              } else if (idx == 2) {
                setState(() => _currentSection = NavSection.anagrafica);
              } else if (idx == 3) {
                setState(() => _currentSection = NavSection.pagamenti);
              } else {
                Scaffold.of(ctx).openDrawer();
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: Color(0xFF8B2529)),
                label: 'Menù',
              ),
              NavigationDestination(
                icon: Icon(Icons.how_to_reg_outlined),
                selectedIcon: Icon(Icons.how_to_reg, color: Color(0xFF8B2529)),
                label: 'Presenze',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt, color: Color(0xFF8B2529)),
                label: 'Allievi',
              ),
              NavigationDestination(
                icon: Icon(Icons.euro_outlined),
                selectedIcon: Icon(Icons.euro, color: Color(0xFF8B2529)),
                label: 'Pagamenti',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_rounded),
                selectedIcon: Icon(Icons.menu_open_rounded, color: Color(0xFF8B2529)),
                label: 'Altro...',
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Schermata Menù Mobile con Grandi Icone ─────────────────────────────
  Widget _buildMobileMenuBody(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Banner di benvenuto
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B2529), Color(0xFFA63439)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B2529).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Benvenuto!',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tocca un modulo per iniziare:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 1. PRESENZE (Icona grande in evidenza)
          _buildBigMenuCard(
            title: '1. Presenze',
            subtitle: 'Appello giornaliero, statistiche e gestione presenze lezioni',
            icon: Icons.how_to_reg_rounded,
            primaryColor: const Color(0xFF8B2529),
            badgeText: 'PRIMARIO',
            isHero: true,
            onTap: () => setState(() => _currentSection = NavSection.presenze),
          ),
          const SizedBox(height: 18),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'ALTRE FUNZIONI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Card Allievi
          _buildBigMenuCard(
            title: 'Anagrafica',
            subtitle: 'Soci, quote, tesseramento e import documenti',
            icon: Icons.people_alt_rounded,
            primaryColor: Colors.blue.shade700,
            onTap: () => setState(() => _currentSection = NavSection.anagrafica),
          ),
          const SizedBox(height: 10),

          // Card Pagamenti
          _buildBigMenuCard(
            title: 'Pagamenti',
            subtitle: 'Registrazione quote, saldi e scadenze allievi',
            icon: Icons.euro_rounded,
            primaryColor: Colors.teal.shade700,
            onTap: () => setState(() => _currentSection = NavSection.pagamenti),
          ),
          const SizedBox(height: 10),

          // Card Ricevute
          _buildBigMenuCard(
            title: 'Ricevute',
            subtitle: 'Emissione ricevute, archivio e download PDF',
            icon: Icons.receipt_long_rounded,
            primaryColor: Colors.deepOrange.shade700,
            onTap: () => setState(() => _currentSection = NavSection.ricevute),
          ),
          const SizedBox(height: 10),

          // Card Corsi
          _buildBigMenuCard(
            title: 'Gestione Corsi',
            subtitle: 'Orari, sedi, livelli e allievi iscritti',
            icon: Icons.class_rounded,
            primaryColor: Colors.indigo.shade700,
            onTap: () => setState(() => _currentSection = NavSection.corsi),
          ),
          const SizedBox(height: 10),

          // Card Argomenti
          _buildBigMenuCard(
            title: 'Registro Argomenti',
            subtitle: 'Registro didattico e programmi delle lezioni',
            icon: Icons.menu_book_rounded,
            primaryColor: Colors.purple.shade700,
            onTap: () => setState(() => _currentSection = NavSection.argomenti),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─── Componente Card a Icona Grande per Menù Mobile ─────────────────────
  Widget _buildBigMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    String? badgeText,
    bool isHero = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isHero ? 18 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHero ? primaryColor : Colors.grey.shade200,
              width: isHero ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isHero
                    ? primaryColor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isHero ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isHero ? 60 : 50,
                height: isHero ? 60 : 50,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(isHero ? 14 : 12),
                ),
                child: Icon(
                  icon,
                  size: isHero ? 34 : 26,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: isHero ? 18 : 16,
                              fontWeight: FontWeight.bold,
                              color: isHero ? primaryColor : Colors.black87,
                            ),
                          ),
                        ),
                        if (badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isHero ? 13 : 12,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isHero ? primaryColor : Colors.grey.shade400,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
