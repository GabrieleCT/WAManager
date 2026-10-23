import 'package:flutter/material.dart';
import 'allievi_screen.dart';
import 'prospects_screen.dart';
import 'coppie_screen.dart';
import 'jolly_panel_screen.dart';
import 'sincronizzazione_contatti_screen.dart';

class AnagraficaAllieviScreen extends StatelessWidget {
  final int initialTab;
  const AnagraficaAllieviScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final int tabCount = isDesktop ? 5 : 4;
    final int clampedInitialTab = initialTab.clamp(0, tabCount - 1);

    return DefaultTabController(
      key: ValueKey(isDesktop),
      length: tabCount,
      initialIndex: clampedInitialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anagrafica'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(
                icon: Icon(Icons.people),
                text: 'Allievi',
              ),
              const Tab(
                icon: Icon(Icons.contact_mail),
                text: 'Prospect',
              ),
              const Tab(
                icon: Icon(Icons.favorite),
                text: 'Coppie',
              ),
              const Tab(
                icon: Icon(Icons.star),
                text: 'Jolly',
              ),
              if (isDesktop)
                const Tab(
                  icon: Icon(Icons.sync_alt),
                  text: 'Sincronizzazione',
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const AllieviScreen(embedded: true),
            const ProspectsScreen(embedded: true),
            const CoppieScreen(embedded: true),
            const JollyPanelScreen(embedded: true),
            if (isDesktop) const SincronizzazioneContattiScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
