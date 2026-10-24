import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api_service.dart';
import 'presenze_screen.dart';
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
  NavSection _currentSection = NavSection.presenze;

  static const List<_NavItem> _items = [
    _NavItem(
      section: NavSection.presenze,
      label: 'Presenze',
      icon: Icons.how_to_reg_outlined,
      selectedIcon: Icons.how_to_reg,
      widget: PresenzeScreen(),
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

    // Se siamo su mobile e la sezione corrente non è disponibile su mobile, fallback a Presenze
    if (!isDesktop) {
      final currentItem = _items.firstWhere((i) => i.section == _currentSection);
      if (!currentItem.availableOnMobile) {
        _currentSection = NavSection.presenze;
      }
    }

    final activeItem = _items.firstWhere((i) => i.section == _currentSection);

    if (isDesktop) {
      // Layout Desktop / Tablet con NavigationRail laterale (tutte le 12 sezioni)
      final desktopSelectedIndex = _items.indexWhere((i) => i.section == _currentSection);
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

    // Layout Mobile con BottomNavigationBar e Drawer con SOLO le funzionalità consentite
    final mobileItems = _items.where((i) => i.availableOnMobile).toList();

    return Scaffold(
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
      body: activeItem.widget,
      bottomNavigationBar: Builder(
        builder: (ctx) {
          int navIndex;
          if (_currentSection == NavSection.presenze) {
            navIndex = 0;
          } else if (_currentSection == NavSection.anagrafica) {
            navIndex = 1;
          } else if (_currentSection == NavSection.pagamenti) {
            navIndex = 2;
          } else if (_currentSection == NavSection.ricevute) {
            navIndex = 3;
          } else {
            // Corsi o Argomenti
            navIndex = 4;
          }

          return NavigationBar(
            selectedIndex: navIndex,
            backgroundColor: Colors.white,
            elevation: 8,
            indicatorColor: const Color(0xFF8B2529).withValues(alpha: 0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (idx) {
              if (idx == 0) {
                setState(() => _currentSection = NavSection.presenze);
              } else if (idx == 1) {
                setState(() => _currentSection = NavSection.anagrafica);
              } else if (idx == 2) {
                setState(() => _currentSection = NavSection.pagamenti);
              } else if (idx == 3) {
                setState(() => _currentSection = NavSection.ricevute);
              } else {
                Scaffold.of(ctx).openDrawer();
              }
            },
            destinations: const [
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
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF8B2529)),
                label: 'Ricevute',
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
}
