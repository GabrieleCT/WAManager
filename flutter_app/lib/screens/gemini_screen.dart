import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class GeminiScreen extends StatefulWidget {
  final bool embedded;
  const GeminiScreen({super.key, this.embedded = false});

  @override
  State<GeminiScreen> createState() => _GeminiScreenState();
}

class _GeminiScreenState extends State<GeminiScreen> {
  bool _isLoading = false;
  bool _isSavingApiKey = false;
  bool _isObscureKey = true;
  late final TextEditingController _apiKeyController;

  List<dynamic> _logs = [];
  List<Corso> _corsi = [];

  String? _selectedCorsoId;
  String? _selectedEsito;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final logsFuture = ApiService().get('gemini-logs/');
      final scheduleFuture = ApiService().get('schedules/');
      final corsiFuture = ApiService().getCorsi();

      final results = await Future.wait([logsFuture, scheduleFuture, corsiFuture]);
      final logsRes = results[0];
      final scheduleRes = results[1];
      final corsiRes = results[2] as List<Corso>;

      setState(() {
        _logs = logsRes is List ? logsRes : [];
        _corsi = corsiRes;
        if (scheduleRes is List && scheduleRes.isNotEmpty) {
          _apiKeyController.text = scheduleRes[0]['gemini_api_key'] ?? '';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSavingApiKey = true);
    try {
      final key = _apiKeyController.text.trim();
      final scheduleRes = await ApiService().get('schedules/');
      if (scheduleRes is List && scheduleRes.isNotEmpty) {
        final id = scheduleRes[0]['id'];
        await ApiService().put('schedules/$id/', {
          'gemini_api_key': key,
        });
      } else {
        await ApiService().post('schedules/', {
          'time': '20:00:00',
          'gemini_api_key': key,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API Key di Gemini salvata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingApiKey = false);
    }
  }

  Future<void> _svuotaTuttiILog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Text('Svuotare tutti i log Gemini?'),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler eliminare tutti i log storici di Gemini AI? '
          'L\'operazione è irreversibile e rimuoverà messaggi ricevuti, chiamate e risposte salvate finora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina Tutto'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService().post('gemini-logs/clear-all/', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tutti i log Gemini sono stati cancellati.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la cancellazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getFilteredLogs() {
    return _logs.where((log) {
      // Filtro per Corso
      if (_selectedCorsoId != null) {
        final logCorsoId = log['corso']?.toString();
        if (logCorsoId != _selectedCorsoId) {
          return false;
        }
      }

      // Filtro per Esito
      if (_selectedEsito != null) {
        final esito = (log['esito_interpretato'] ?? '').toString().toUpperCase();
        if (_selectedEsito == 'PRESENTE') {
          if (!esito.contains('PRESENTE')) return false;
        } else if (_selectedEsito == 'ASSENTE') {
          if (!esito.contains('ASSENTE')) return false;
        } else if (_selectedEsito == 'IGNOTA') {
          if (esito != 'IGNOTA' && esito != '') return false;
        } else if (_selectedEsito == 'ERRORE') {
          if (esito != 'ERRORE') return false;
        } else if (esito != _selectedEsito) {
          return false;
        }
      }

      // Filtro per Ricerca Testo
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final text = (log['testo_originale'] ?? '').toString().toLowerCase();
        final mitt = (log['mittente'] ?? log['allievo_nome'] ?? '').toString().toLowerCase();
        final corso = (log['corso_nome'] ?? '').toString().toLowerCase();
        final resp = (log['risposta_ai'] ?? '').toString().toLowerCase();
        final call = (log['chiamata_ai'] ?? '').toString().toLowerCase();

        if (!text.contains(q) &&
            !mitt.contains(q) &&
            !corso.contains(q) &&
            !resp.contains(q) &&
            !call.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Map<String, dynamic> _getEsitoStyle(String? esito) {
    final e = (esito ?? '').toUpperCase();
    if (e.contains('PRESENTE_SINGOLO')) {
      return {
        'label': 'Presente (Singolo)',
        'color': Colors.green.shade700,
        'bg': Colors.green.shade50,
        'border': Colors.green.shade300,
        'icon': Icons.check_circle_outline,
      };
    } else if (e.contains('PRESENTE_COPPIA')) {
      return {
        'label': 'Presente (Coppia)',
        'color': Colors.teal.shade800,
        'bg': Colors.teal.shade50,
        'border': Colors.teal.shade300,
        'icon': Icons.group,
      };
    } else if (e.contains('ASSENTE_SINGOLO')) {
      return {
        'label': 'Assente (Singolo)',
        'color': Colors.orange.shade900,
        'bg': Colors.orange.shade50,
        'border': Colors.orange.shade300,
        'icon': Icons.cancel_outlined,
      };
    } else if (e.contains('ASSENTE_COPPIA')) {
      return {
        'label': 'Assente (Coppia)',
        'color': Colors.red.shade800,
        'bg': Colors.red.shade50,
        'border': Colors.red.shade300,
        'icon': Icons.group_off,
      };
    } else if (e.contains('ERRORE')) {
      return {
        'label': 'Errore Chiamata',
        'color': Colors.deepOrange.shade800,
        'bg': Colors.deepOrange.shade50,
        'border': Colors.deepOrange.shade300,
        'icon': Icons.warning_amber_rounded,
      };
    } else {
      return {
        'label': 'Altro / Non Specificato',
        'color': Colors.blueGrey.shade700,
        'bg': Colors.blueGrey.shade50,
        'border': Colors.blueGrey.shade200,
        'icon': Icons.help_outline,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 1. PANNELLO CONFIGURAZIONE & MONITORAGGIO 7 CORSI
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titolo e Azioni
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.psychology, color: Colors.blue.shade700, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gemini AI • Monitoraggio Gruppi WhatsApp Corsi',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Registrazione automatica di messaggio ricevuto, chiamata prompt a Gemini e risposta per i 7 gruppi corso.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Ricarica log e stato',
                              onPressed: _loadData,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.red),
                              tooltip: 'Svuota tutti i log Gemini',
                              onPressed: _logs.isEmpty ? null : _svuotaTuttiILog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Campo API Key
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _apiKeyController,
                                obscureText: _isObscureKey,
                                decoration: InputDecoration(
                                  labelText: 'Gemini API Key',
                                  hintText: 'Incolla la chiave API di Google Gemini (es. AIzaSy...)',
                                  prefixIcon: const Icon(Icons.vpn_key),
                                  suffixIcon: IconButton(
                                    icon: Icon(_isObscureKey ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _isObscureKey = !_isObscureKey),
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSavingApiKey ? null : _saveApiKey,
                              icon: _isSavingApiKey
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save),
                              label: Text(_isSavingApiKey ? 'Salvataggio...' : 'Salva Chiave'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Chips 7 Gruppi Corso Monitorati
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hub_outlined, size: 16, color: Colors.indigo.shade600),
                              const SizedBox(width: 8),
                              Text(
                                '7 Corsi Monitorati in Tempo Reale:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildCourseBadge('Ripamonti - Avanzato'),
                                      _buildCourseBadge('Ripamonti - Intermedio'),
                                      _buildCourseBadge('Ripamonti - Principiante'),
                                      _buildCourseBadge('San Donato - Int 20:30'),
                                      _buildCourseBadge('San Donato - Int 21:30'),
                                      _buildCourseBadge('San Donato - Princ 19:30'),
                                      _buildCourseBadge('San Donato - Princ 20:30'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. FILTRI & RICERCA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    // Campo Ricerca
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cerca per mittente, testo, prompt o risposta...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filtro per Corso
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedCorsoId,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          labelText: 'Filtra Corso',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tutti i corsi', overflow: TextOverflow.ellipsis),
                          ),
                          ..._corsi.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.scuolaNome} - ${c.livello}', overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedCorsoId = val),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filtro per Esito
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedEsito,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          labelText: 'Filtra Esito',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tutti gli esiti')),
                          DropdownMenuItem(value: 'PRESENTE', child: Text('Presente (Singolo o Coppia)')),
                          DropdownMenuItem(value: 'ASSENTE', child: Text('Assente (Singolo o Coppia)')),
                          DropdownMenuItem(value: 'IGNOTA', child: Text('Non classificato')),
                          DropdownMenuItem(value: 'ERRORE', child: Text('Errore API')),
                        ],
                        onChanged: (val) => setState(() => _selectedEsito = val),
                      ),
                    ),
                  ],
                ),
              ),

              // Contatore log
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log totali registrati: ${_logs.length} (mostrati: ${filteredLogs.length})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    if (_selectedCorsoId != null || _selectedEsito != null || _searchQuery.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCorsoId = null;
                            _selectedEsito = null;
                            _searchQuery = '';
                          });
                        },
                        child: Text(
                          'Resetta filtri',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 12),

              // 3. LISTA DEI LOG CON LE 3 SEZIONI RICHIESTE
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_chat_read_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _logs.isEmpty
                                  ? 'Nessun messaggio WhatsApp ancora ricevuto sui gruppi dei corsi.'
                                  : 'Nessun log corrisponde ai filtri selezionati.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          return _buildLogCard(log);
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
        title: const Text('Gemini AI • Monitoraggio Gruppi WhatsApp'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: content,
    );
  }

  Widget _buildCourseBadge(String title) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _buildLogCard(dynamic log) {
    final esito = log['esito_interpretato']?.toString() ?? 'IGNOTA';
    final esitoStyle = _getEsitoStyle(esito);

    final mittente = (log['mittente']?.toString().isNotEmpty == true)
        ? log['mittente']
        : (log['allievo_nome'] ?? 'Mittente WhatsApp');

    final corsoNome = (log['corso_nome']?.toString().isNotEmpty == true)
        ? log['corso_nome']
        : (log['gruppo_whatsapp'] ?? 'Gruppo WhatsApp');

    final dataOraStr = _formatDateTime(log['timestamp']);
    final testo = log['testo_originale']?.toString() ?? '';
    final chiamataPrompt = log['chiamata_ai']?.toString() ?? '';
    final rispostaAi = log['risposta_ai']?.toString() ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: esitoStyle['border'] as Color, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione Card: Mittente, Corso, Esito e Data
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: esitoStyle['bg'] as Color,
                  child: Icon(esitoStyle['icon'] as IconData, size: 18, color: esitoStyle['color'] as Color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              mittente,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school, size: 12, color: Colors.blue.shade800),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    corsoNome,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (log['lezione_descrizione'] != null && log['lezione_descrizione'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Lezione: ${log['lezione_descrizione']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ),

                // Esito Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: esitoStyle['bg'] as Color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: esitoStyle['border'] as Color),
                  ),
                  child: Text(
                    esitoStyle['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: esitoStyle['color'] as Color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dataOraStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // SEZIONE 1: 💬 MESSAGGIO RICEVUTO DAL GRUPPO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE7FBD3), // Tonalità fumetto WhatsApp
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB4E7A1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat, size: 14, color: Colors.green.shade900),
                      const SizedBox(width: 6),
                      Text(
                        '1. MESSAGGIO RICEVUTO SUL GRUPPO WHATSAPP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    testo.isNotEmpty ? testo : '(Nessun testo)',
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // SEZIONE 2: 🤖 CHIAMATA A GEMINI AI (PROMPT INVIATO)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Dark slate moderno stile console/prompt
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 14, color: Colors.cyanAccent),
                      const SizedBox(width: 6),
                      const Text(
                        '2. CHIAMATA A GEMINI AI (PROMPT INVIATO)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (chiamataPrompt.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: chiamataPrompt));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Prompt copiato negli appunti!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 12, color: Colors.white70),
                              SizedBox(width: 4),
                              Text('Copia', style: TextStyle(fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    chiamataPrompt.isNotEmpty ? chiamataPrompt : '(Prompt non registrato per log precedenti)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFE2E8F0),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // SEZIONE 3: 💡 RISPOSTA DI GEMINI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF), // Viola chiaro AI
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD8B4FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade900),
                      const SizedBox(width: 6),
                      Text(
                        '3. RISPOSTA DI GEMINI AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    rispostaAi.isNotEmpty ? rispostaAi : '(Nessuna risposta registrata)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B0764),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
