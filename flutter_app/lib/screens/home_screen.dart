import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'presenze_screen.dart';
import 'sondaggio_mattutino_screen.dart';
import 'jolly_panel_screen.dart';
import 'lezioni_screen.dart';
import 'allievi_screen.dart';
import 'prospects_screen.dart';
import 'scuole_screen.dart';
import 'corsi_screen.dart';
import 'argomenti_screen.dart';
import 'pagamenti_screen.dart';
import 'import_export_screen.dart';
import 'login_screen.dart';
import 'wa_screen.dart';
import 'coppie_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    PresenzeScreen(),
    SondaggioMattutinoScreen(),
    JollyPanelScreen(),
    LezioniScreen(),
    AllieviScreen(),
    ProspectsScreen(),
    CoppieScreen(),
    ScuoleScreen(),
    CorsiScreen(),
    ArgomentiScreen(),
    PagamentiScreen(),
    ImportExportScreen(),
    WhatsAppScreen(),
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
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Icon(Icons.music_note, color: Colors.deepPurple, size: 32),
                        ),
                        trailing: Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: IconButton(
                                icon: const Icon(Icons.logout, color: Colors.red),
                                tooltip: 'Logout',
                                onPressed: _logout,
                              ),
                            ),
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(icon: Icon(Icons.how_to_reg), label: Text('Presenze')),
                          NavigationRailDestination(icon: Icon(Icons.poll), label: Text('Sondaggio')),
                          NavigationRailDestination(icon: Icon(Icons.star), label: Text('Jolly')),
                          NavigationRailDestination(icon: Icon(Icons.event), label: Text('Lezioni')),
                          NavigationRailDestination(icon: Icon(Icons.people), label: Text('Allievi')),
                          NavigationRailDestination(icon: Icon(Icons.contact_mail), label: Text('Prospect')),
                          NavigationRailDestination(icon: Icon(Icons.favorite), label: Text('Coppie')),
                          NavigationRailDestination(icon: Icon(Icons.business), label: Text('Scuole')),
                          NavigationRailDestination(icon: Icon(Icons.class_), label: Text('Corsi')),
                          NavigationRailDestination(icon: Icon(Icons.menu_book), label: Text('Argomenti')),
                          NavigationRailDestination(icon: Icon(Icons.euro), label: Text('Pagamenti')),
                          NavigationRailDestination(icon: Icon(Icons.import_export), label: Text('Imp/Exp')),
                          NavigationRailDestination(icon: Icon(Icons.qr_code_scanner), label: Text('WhatsApp')),
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
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.music_note, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text('WAManager Tango', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Gestionale Scuola Tango', style: TextStyle(color: Colors.white70)),
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
              leading: const Icon(Icons.poll),
              title: const Text('Sondaggio Mattutino'),
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Jolly WA'),
              selected: _currentIndex == 2,
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Lezioni'),
              selected: _currentIndex == 3,
              onTap: () {
                setState(() => _currentIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Allievi'),
              selected: _currentIndex == 4,
              onTap: () {
                setState(() => _currentIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Prospects'),
              selected: _currentIndex == 5,
              onTap: () {
                setState(() => _currentIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Coppie'),
              selected: _currentIndex == 6,
              onTap: () {
                setState(() => _currentIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Scuole'),
              selected: _currentIndex == 7,
              onTap: () {
                setState(() => _currentIndex = 7);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('Corsi'),
              selected: _currentIndex == 8,
              onTap: () {
                setState(() => _currentIndex = 8);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Argomenti'),
              selected: _currentIndex == 9,
              onTap: () {
                setState(() => _currentIndex = 9);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.euro),
              title: const Text('Pagamenti'),
              selected: _currentIndex == 10,
              onTap: () {
                setState(() => _currentIndex = 10);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.import_export),
              title: const Text('Import / Export'),
              selected: _currentIndex == 11,
              onTap: () {
                setState(() => _currentIndex = 11);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('WhatsApp'),
              selected: _currentIndex == 12,
              onTap: () {
                setState(() => _currentIndex = 12);
                Navigator.pop(context);
              },
            ),
            const Divider(),
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
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.how_to_reg), label: 'Presenze'),
          BottomNavigationBarItem(icon: Icon(Icons.poll), label: 'Sondaggio'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Jolly'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Lezioni'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Allievi'),
          BottomNavigationBarItem(icon: Icon(Icons.contact_mail), label: 'Prospect'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Scuole'),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Corsi'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Argomenti'),
          BottomNavigationBarItem(icon: Icon(Icons.euro), label: 'Pagamenti'),
          BottomNavigationBarItem(icon: Icon(Icons.import_export), label: 'Imp/Exp'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'WhatsApp'),
        ],
      ),
    );
  }
}
