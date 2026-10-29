import 'package:flutter/material.dart';
import 'presenze_screen.dart';
import 'jolly_panel_screen.dart';

class GestionePresenzeScreen extends StatelessWidget {
  final String? initialLezioneId;
  final int initialTab;

  const GestionePresenzeScreen({
    super.key,
    this.initialLezioneId,
    this.initialTab = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Presenze'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.how_to_reg),
                text: 'Presenze',
              ),
              Tab(
                icon: Icon(Icons.star),
                text: 'Jolly',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PresenzeScreen(
              embedded: true,
              initialLezioneId: initialLezioneId,
            ),
            const JollyPanelScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}

