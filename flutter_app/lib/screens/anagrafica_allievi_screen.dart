import 'package:flutter/material.dart';
import 'allievi_screen.dart';
import 'prospects_screen.dart';
import 'coppie_screen.dart';
import 'jolly_panel_screen.dart';

class AnagraficaAllieviScreen extends StatefulWidget {
  final int initialTab;
  const AnagraficaAllieviScreen({super.key, this.initialTab = 0});

  @override
  State<AnagraficaAllieviScreen> createState() => _AnagraficaAllieviScreenState();
}

class _AnagraficaAllieviScreenState extends State<AnagraficaAllieviScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anagrafica Allievi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.people),
              text: 'Allievi',
            ),
            Tab(
              icon: Icon(Icons.contact_mail),
              text: 'Prospect',
            ),
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Coppie',
            ),
            Tab(
              icon: Icon(Icons.star),
              text: 'Jolly',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AllieviScreen(embedded: true),
          ProspectsScreen(embedded: true),
          CoppieScreen(embedded: true),
          JollyPanelScreen(embedded: true),
        ],
      ),
    );
  }
}

