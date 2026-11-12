import 'package:flutter/material.dart';
import 'presenze_screen.dart';

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
    return PresenzeScreen(
      embedded: false,
      initialLezioneId: initialLezioneId,
    );
  }
}

