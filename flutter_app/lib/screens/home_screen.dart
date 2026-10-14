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
import 'login_screen.dart';
import 'impostazioni_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    PresenzeScreen(),
    MessaggisticaScreen(),
    LezioniScreen(),
    AnagraficaAllieviScreen(),
    ScuoleScreen(),
    CorsiScreen(),
    ArgomentiScreen(),
    PagamentiScreen(),
    ImpostazioniScreen(),
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

    if (isDesktop) {
      // Layout Desktop / Tablet con NavigationRail laterale
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
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
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
                        destinations: const [
                          NavigationRailDestination(icon: Icon(Icons.how_to_reg), label: Text('Presenze')),
                          NavigationRailDestination(icon: Icon(Icons.chat), label: Text('Messaggistica')),
                          NavigationRailDestination(icon: Icon(Icons.event), label: Text('Lezioni')),
                          NavigationRailDestination(icon: Icon(Icons.people_alt), label: Text('Anagrafica')),
                          NavigationRailDestination(icon: Icon(Icons.business), label: Text('Scuole')),
                          NavigationRailDestination(icon: Icon(Icons.class_), label: Text('Corsi')),
                          NavigationRailDestination(icon: Icon(Icons.menu_book), label: Text('Argomenti')),
                          NavigationRailDestination(icon: Icon(Icons.euro), label: Text('Pagamenti')),
                          NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Impostazioni')),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _pages[_currentIndex]),
          ],
        ),
      );
    }

    // Layout Mobile con BottomNavigationBar
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 60,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('TantoTango Manager', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('Gestionale scuola di ballo', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.how_to_reg),
              title: const Text('Presenze'),
              selected: _currentIndex == 0,
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Messaggistica'),
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Lezioni'),
              selected: _currentIndex == 2,
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt),
              title: const Text('Anagrafica Allievi'),
              selected: _currentIndex == 3,
              onTap: () {
                setState(() => _currentIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Scuole'),
              selected: _currentIndex == 4,
              onTap: () {
                setState(() => _currentIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('Corsi'),
              selected: _currentIndex == 5,
              onTap: () {
                setState(() => _currentIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Argomenti'),
              selected: _currentIndex == 6,
              onTap: () {
                setState(() => _currentIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.euro),
              title: const Text('Pagamenti'),
              selected: _currentIndex == 7,
              onTap: () {
                setState(() => _currentIndex = 7);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Impostazioni'),
              selected: _currentIndex == 8,
              onTap: () {
                setState(() => _currentIndex = 8);
                Navigator.pop(context);
              },
            ),
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
              }
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.how_to_reg), label: 'Presenze'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messaggistica'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Lezioni'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Anagrafica'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Scuole'),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Corsi'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Argomenti'),
          BottomNavigationBarItem(icon: Icon(Icons.euro), label: 'Pagamenti'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Impostazioni'),
        ],
      ),
    );
  }
}
