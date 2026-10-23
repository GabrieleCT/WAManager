import 'package:flutter/material.dart';
import 'allievi_screen.dart';
import 'prospects_screen.dart';
import 'coppie_screen.dart';
import 'jolly_panel_screen.dart';
import 'sincronizzazione_contatti_screen.dart';

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
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
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
        title: const Text('Anagrafica'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
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
            Tab(
              icon: Icon(Icons.sync_alt),
              text: 'Sincronizzazione',
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
          SincronizzazioneContattiScreen(embedded: true),
        ],
      ),
    );
  }
}
