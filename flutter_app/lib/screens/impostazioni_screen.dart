import 'package:flutter/material.dart';
import 'gemini_screen.dart';
import 'import_export_screen.dart';
import 'template_settings_screen.dart';

class ImpostazioniScreen extends StatefulWidget {
  final int initialTab;
  const ImpostazioniScreen({super.key, this.initialTab = 0});

  @override
  State<ImpostazioniScreen> createState() => _ImpostazioniScreenState();
}

class _ImpostazioniScreenState extends State<ImpostazioniScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
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
        title: const Text('Impostazioni'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_awesome),
              text: 'Gemini AI',
            ),
            Tab(
              icon: Icon(Icons.import_export),
              text: 'Import / Export',
            ),
            Tab(
              icon: Icon(Icons.picture_as_pdf),
              text: 'Template',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GeminiScreen(embedded: true),
          ImportExportScreen(embedded: true),
          TemplateSettingsScreen(embedded: true),
        ],
      ),
    );
  }
}
