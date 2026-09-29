import os

path = r"C:\Users\gabriele.cataldo\OneDrive - Banca Mediolanum SPA\Desktop\private\tango\gestionale\WAManager\flutter_app\lib\screens\home_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace imports
imports = """import 'package:flutter/material.dart';
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
"""

content = content.split("class HomeScreen")[1]
content = imports + "\\nclass HomeScreen" + content

# Replace _pages list
pages_list = """  final List<Widget> _pages = const [
    PresenzeScreen(),
    SondaggioMattutinoScreen(),
    JollyPanelScreen(),
    LezioniScreen(),
    AllieviScreen(),
    ProspectsScreen(),
    ScuoleScreen(),
    CorsiScreen(),
    ArgomentiScreen(),
    PagamentiScreen(),
    ImportExportScreen(),
    WhatsAppScreen(),
  ];"""

import re
content = re.sub(r'  final List<Widget> _pages = const \[\s*(?:.*\s*)*?  \];', pages_list, content)

# Replace NavigationRail destinations
destinations = """              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.how_to_reg), label: Text('Presenze')),
                NavigationRailDestination(icon: Icon(Icons.poll), label: Text('Sondaggio')),
                NavigationRailDestination(icon: Icon(Icons.star), label: Text('Jolly')),
                NavigationRailDestination(icon: Icon(Icons.event), label: Text('Lezioni')),
                NavigationRailDestination(icon: Icon(Icons.people), label: Text('Allievi')),
                NavigationRailDestination(icon: Icon(Icons.contact_mail), label: Text('Prospect')),
                NavigationRailDestination(icon: Icon(Icons.business), label: Text('Scuole')),
                NavigationRailDestination(icon: Icon(Icons.class_), label: Text('Corsi')),
                NavigationRailDestination(icon: Icon(Icons.menu_book), label: Text('Argomenti')),
                NavigationRailDestination(icon: Icon(Icons.euro), label: Text('Pagamenti')),
                NavigationRailDestination(icon: Icon(Icons.import_export), label: Text('Imp/Exp')),
                NavigationRailDestination(icon: Icon(Icons.qr_code_scanner), label: Text('WhatsApp')),
              ],"""

content = re.sub(r'              destinations: const \[\s*(?:.*\s*)*?              \],', destinations, content)

# Replace ListTile elements in Drawer
list_tiles = """            ListTile(
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
              leading: const Icon(Icons.business),
              title: const Text('Scuole'),
              selected: _currentIndex == 6,
              onTap: () {
                setState(() => _currentIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_),
              title: const Text('Corsi'),
              selected: _currentIndex == 7,
              onTap: () {
                setState(() => _currentIndex = 7);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Argomenti'),
              selected: _currentIndex == 8,
              onTap: () {
                setState(() => _currentIndex = 8);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.euro),
              title: const Text('Pagamenti'),
              selected: _currentIndex == 9,
              onTap: () {
                setState(() => _currentIndex = 9);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.import_export),
              title: const Text('Import / Export'),
              selected: _currentIndex == 10,
              onTap: () {
                setState(() => _currentIndex = 10);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('WhatsApp'),
              selected: _currentIndex == 11,
              onTap: () {
                setState(() => _currentIndex = 11);
                Navigator.pop(context);
              },
            ),"""

# Using regex to replace all ListTiles in Drawer before Divider
content = re.sub(r'(?s)            ListTile\(\s*leading: const Icon\(Icons.people\).*?            const Divider\(\),', list_tiles + '\\n            const Divider(),', content)

# Replace BottomNavigationBar items
bottom_nav = """        items: const [
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
        ],"""

content = re.sub(r'(?s)        items: const \[\s*BottomNavigationBarItem.*?        \],', bottom_nav, content)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Modified home_screen.dart")
