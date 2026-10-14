import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GeminiScreen extends StatefulWidget {
  final bool embedded;
  const GeminiScreen({super.key, this.embedded = false});

  @override
  State<GeminiScreen> createState() => _GeminiScreenState();
}

class _GeminiScreenState extends State<GeminiScreen> {
  bool _isLoading = false;
  String _apiKey = '';
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final logsRes = await ApiService().get('gemini-logs/');
      final scheduleRes = await ApiService().get('schedules/');
      
      setState(() {
        _logs = logsRes is List ? logsRes : [];
        if (scheduleRes is List && scheduleRes.isNotEmpty) {
          _apiKey = scheduleRes[0]['gemini_api_key'] ?? '';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveApiKey() async {
    setState(() => _isLoading = true);
    try {
      final scheduleRes = await ApiService().get('schedules/');
      if (scheduleRes is List && scheduleRes.isNotEmpty) {
        final id = scheduleRes[0]['id'];
        await ApiService().put('schedules/$id/', {
          'gemini_api_key': _apiKey,
        });
      } else {
        await ApiService().post('schedules/', {
          'time': '20:00:00',
          'gemini_api_key': _apiKey,
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Key salvata!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Configurazione Gemini AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Ricarica dati e log',
                              onPressed: _loadData,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _apiKey,
                                decoration: const InputDecoration(
                                  labelText: 'Gemini API Key',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _apiKey = val,
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _saveApiKey,
                              icon: const Icon(Icons.save),
                              label: const Text('Salva API Key'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _logs.isEmpty
                    ? const Center(child: Text('Nessun log AI disponibile.'))
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final esito = log['esito_interpretato'] ?? 'IGNOTA';
                          Color bgColor = Colors.grey.shade100;
                          IconData icon = Icons.help;
                          
                          if (esito == 'PRESENTE') {
                            bgColor = Colors.green.shade50;
                            icon = Icons.check_circle;
                          } else if (esito == 'ASSENTE') {
                            bgColor = Colors.red.shade50;
                            icon = Icons.cancel;
                          }

                          return Card(
                            color: bgColor,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(icon, color: esito == 'PRESENTE' ? Colors.green : (esito == 'ASSENTE' ? Colors.red : Colors.grey)),
                              title: Text(log['allievo_nome'] ?? 'Sconosciuto'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Lezione: ${log['lezione_descrizione'] ?? '-'}'),
                                  const SizedBox(height: 4),
                                  Text('Testo: "${log['testo_originale'] ?? ''}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  Text('Risposta AI: ${log['risposta_ai'] ?? ''}'),
                                ],
                              ),
                              trailing: Text(
                                log['timestamp'] != null ? DateTime.parse(log['timestamp']).toLocal().toString().substring(0, 16) : '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI & Log'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: content,
    );
  }
}
