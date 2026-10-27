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

  bool _monitoringActive = true;
  TimeOfDay _timeStart = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _timeEnd = const TimeOfDay(hour: 13, minute: 0);
  bool _onlyCourseDays = true;
  List<String> _customDays = ['LUNEDI', 'MERCOLEDI', 'GIOVEDI'];
  bool _isSavingConfig = false;

  bool _isApiConfigExpanded = false;
  bool _isRulesConfigExpanded = false;

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
          final sched = scheduleRes[0];
          _apiKeyController.text = sched['gemini_api_key'] ?? '';
          _monitoringActive = sched['gemini_monitoring_active'] ?? true;
          _onlyCourseDays = sched['gemini_only_course_days'] ?? true;

          final startStr = sched['gemini_time_start']?.toString() ?? '07:00:00';
          final startParts = startStr.split(':');
          if (startParts.length >= 2) {
            _timeStart = TimeOfDay(hour: int.tryParse(startParts[0]) ?? 7, minute: int.tryParse(startParts[1]) ?? 0);
          }

          final endStr = sched['gemini_time_end']?.toString() ?? '13:00:00';
          final endParts = endStr.split(':');
          if (endParts.length >= 2) {
            _timeEnd = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 13, minute: int.tryParse(endParts[1]) ?? 0);
          }

          final customDaysStr = sched['gemini_custom_days']?.toString() ?? 'LUNEDI,MERCOLEDI,GIOVEDI';
          _customDays = customDaysStr.split(',').map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList();
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
        final mitt = (log['allievo_nome'] ?? log['mittente'] ?? '').toString().toLowerCase();
        final corso = (log['corso_nome'] ?? '').toString().toLowerCase();
        final resp = (log['risposta_ai'] ?? '').toString().toLowerCase();
        final pres = (log['presenze_segnate'] ?? log['azione_presenze'] ?? '').toString().toLowerCase();

        if (!text.contains(q) &&
            !mitt.contains(q) &&
            !corso.contains(q) &&
            !resp.contains(q) &&
            !pres.contains(q)) {
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
    final e = (esito ?? '').toUpperCase().trim();
    if (e == 'PRESENTE_SINGOLO') {
      return {
        'label': 'PRESENTE_SINGOLO',
        'color': Colors.green.shade800,
        'bg': Colors.green.shade50,
        'border': Colors.green.shade400,
        'icon': Icons.check_circle_outline,
      };
    } else if (e == 'PRESENTE_COPPIA') {
      return {
        'label': 'PRESENTE_COPPIA',
        'color': Colors.teal.shade900,
        'bg': Colors.teal.shade50,
        'border': Colors.teal.shade400,
        'icon': Icons.group,
      };
    } else if (e == 'ASSENTE_SINGOLO') {
      return {
        'label': 'ASSENTE_SINGOLO',
        'color': Colors.orange.shade900,
        'bg': Colors.orange.shade50,
        'border': Colors.orange.shade400,
        'icon': Icons.person_off,
      };
    } else if (e == 'ASSENTE_COPPIA') {
      return {
        'label': 'ASSENTE_COPPIA',
        'color': Colors.red.shade900,
        'bg': Colors.red.shade50,
        'border': Colors.red.shade400,
        'icon': Icons.group_off,
      };
    } else if (e == 'IGNOTA') {
      return {
        'label': 'IGNOTA',
        'color': Colors.blueGrey.shade800,
        'bg': Colors.blueGrey.shade50,
        'border': Colors.blueGrey.shade300,
        'icon': Icons.help_outline,
      };
    } else {
      return {
        'label': e.isNotEmpty ? e : 'IGNOTA',
        'color': Colors.deepOrange.shade800,
        'bg': Colors.deepOrange.shade50,
        'border': Colors.deepOrange.shade300,
        'icon': Icons.warning_amber_rounded,
      };
    }
  }

  String _getPresenzeSegnate(dynamic log) {
    if (log['presenze_segnate'] != null && log['presenze_segnate'].toString().isNotEmpty) {
      return log['presenze_segnate'].toString();
    }
    final esito = (log['esito_interpretato'] ?? '').toString().toUpperCase();
    final allievo = log['allievo_nome']?.toString() ?? log['mittente']?.toString() ?? '';
    final partner = log['partner_nome']?.toString() ?? '';

    if (allievo.isEmpty || allievo.contains('@s.whatsapp.net')) {
      return 'Nessuna (allievo non censito)';
    }

    if (esito == 'PRESENTE_COPPIA') {
      return partner.isNotEmpty ? '$allievo & $partner' : allievo;
    } else if (esito == 'PRESENTE_SINGOLO') {
      return allievo;
    } else if (esito == 'ASSENTE_COPPIA') {
      return partner.isNotEmpty ? 'Assenti: $allievo & $partner' : 'Assente: $allievo';
    } else if (esito == 'ASSENTE_SINGOLO') {
      return 'Assente: $allievo';
    } else {
      return 'Nessuna';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. PANNELLO CONFIGURAZIONE & STATO MONITORAGGIO (COMPRIMIBILE)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _isApiConfigExpanded = !_isApiConfigExpanded),
                          child: Row(
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Gemini AI • Configurazione Base & Gruppi',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _apiKeyController.text.trim().isNotEmpty
                                                ? Colors.green.shade50
                                                : Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _apiKeyController.text.trim().isNotEmpty
                                                  ? Colors.green.shade300
                                                  : Colors.amber.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            _apiKeyController.text.trim().isNotEmpty ? 'API Key OK' : 'Nessuna Chiave',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _apiKeyController.text.trim().isNotEmpty
                                                  ? Colors.green.shade800
                                                  : Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isApiConfigExpanded
                                          ? 'Intercetta solo i 7 gruppi dei corsi (esclusi gruppi generali scuola o chat esterne).'
                                          : '7 corsi monitorati • Clicca per espandere/modificare API Key',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                tooltip: 'Ricarica log e stato',
                                onPressed: _loadData,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                                tooltip: 'Svuota tutti i log Gemini',
                                onPressed: _logs.isEmpty ? null : _svuotaTuttiILog,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(_isApiConfigExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                                tooltip: _isApiConfigExpanded ? 'Comprimi pannello' : 'Espandi pannello',
                                onPressed: () => setState(() => _isApiConfigExpanded = !_isApiConfigExpanded),
                              ),
                            ],
                          ),
                        ),

                        if (_isApiConfigExpanded) ...[
                          const Divider(height: 20),
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
                                  '7 Corsi Monitorati:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildCourseBadge('Ripamonti Avanzato 21:30'),
                                        _buildCourseBadge('Ripamonti Intermedio 20:30'),
                                        _buildCourseBadge('Ripamonti Principiante 19:30'),
                                        _buildCourseBadge('San Donato Intermedio 20:30'),
                                        _buildCourseBadge('San Donato Intermedio 21:30'),
                                        _buildCourseBadge('San Donato Principiante 19:30'),
                                        _buildCourseBadge('San Donato Principiante 20:30'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 1.2 PANNELLO CONFIGURAZIONE INTERVALLI E REGOLE DI MONITORAGGIO
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: _buildMonitoringConfigCard(),
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
                          hintText: 'Cerca per allievo, messaggio, corso o risposta...',
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
                                child: Text('${c.scuolaNome} ${c.livello}', overflow: TextOverflow.ellipsis),
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
                          labelText: 'Filtra Risposta AI',
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tutte le risposte')),
                          DropdownMenuItem(value: 'PRESENTE_SINGOLO', child: Text('PRESENTE_SINGOLO')),
                          DropdownMenuItem(value: 'PRESENTE_COPPIA', child: Text('PRESENTE_COPPIA')),
                          DropdownMenuItem(value: 'ASSENTE_SINGOLO', child: Text('ASSENTE_SINGOLO')),
                          DropdownMenuItem(value: 'ASSENTE_COPPIA', child: Text('ASSENTE_COPPIA')),
                          DropdownMenuItem(value: 'IGNOTA', child: Text('IGNOTA')),
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
              const SizedBox(height: 6),

              // 3. TABELLA DEI LOG (7 COLONNE COME RICHIESTO)
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_rows_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _logs.isEmpty
                                  ? 'Nessun messaggio WhatsApp ancora ricevuto sui 7 gruppi dei corsi.'
                                  : 'Nessun log corrisponde ai filtri selezionati.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                                        dataRowMinHeight: 48,
                                        dataRowMaxHeight: 64,
                                        horizontalMargin: 16,
                                        columnSpacing: 18,
                                        columns: const [
                                          // 1. Data e orario del messaggio intercettato
                                          DataColumn(
                                            label: Text('1. Data e Orario'),
                                            tooltip: 'Data e orario del messaggio intercettato',
                                          ),
                                          // 2. Nome e cognome dell\'allievo che ha scritto
                                          DataColumn(
                                            label: Text('2. Allievo'),
                                            tooltip: 'Nome e cognome dell\'allievo che ha scritto',
                                          ),
                                          // 3. Messaggio intercettato
                                          DataColumn(
                                            label: Text('3. Messaggio Intercettato'),
                                            tooltip: 'Testo del messaggio ricevuto nel gruppo WhatsApp',
                                          ),
                                          // 4. Risposta di GEMINI (PRESENTE_SINGOLO, ASSENTE_SINGOLO, PRESENTE_COPPIA, ASSENTE_COPPIA, IGNOTA)
                                          DataColumn(
                                            label: Text('4. Risposta di GEMINI'),
                                            tooltip: 'Valore restituito da Gemini (PRESENTE_SINGOLO, ASSENTE_SINGOLO, PRESENTE_COPPIA, ASSENTE_COPPIA, IGNOTA)',
                                          ),
                                          // 5. Gruppo di provenienza messaggio (es: Ripamonti Principiante 19:30)
                                          DataColumn(
                                            label: Text('5. Gruppo di Provenienza'),
                                            tooltip: 'Gruppo corso WhatsApp di provenienza (es: Ripamonti Principiante 19:30)',
                                          ),
                                          // 6. Presenza o presenze che verranno segnate
                                          DataColumn(
                                            label: Text('6. Presenze Segnate'),
                                            tooltip: 'Presenza o presenze che verranno segnate nel gestionale',
                                          ),
                                          // 7. Dettaglio (icona lente di ingrandimento)
                                          DataColumn(
                                            label: Center(child: Text('7. Dettaglio')),
                                            tooltip: 'Clicca sulla lente per vedere tutti i dettagli completi',
                                          ),
                                        ],
                                        rows: filteredLogs.map((log) {
                                          final esito = (log['esito_interpretato'] ?? 'IGNOTA').toString().trim();
                                          final esitoStyle = _getEsitoStyle(esito);

                                          final allievo = (log['allievo_nome']?.toString().isNotEmpty == true)
                                              ? log['allievo_nome'].toString()
                                              : (log['mittente']?.toString() ?? 'Sconosciuto');

                                          final testo = log['testo_originale']?.toString() ?? '';
                                          final corso = (log['corso_nome']?.toString().isNotEmpty == true)
                                              ? log['corso_nome'].toString()
                                              : (log['gruppo_whatsapp']?.toString() ?? '-');

                                          final presenze = _getPresenzeSegnate(log);
                                          final dataOra = _formatDateTime(log['timestamp']);

                                          return DataRow(
                                            cells: [
                                              // 1. Data e orario
                                              DataCell(
                                                Text(
                                                  dataOra,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                              ),

                                              // 2. Nome e cognome allievo
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 12,
                                                      backgroundColor: Colors.blue.shade100,
                                                      child: Text(
                                                        allievo.isNotEmpty ? allievo[0].toUpperCase() : '?',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 160),
                                                      child: Text(
                                                        allievo,
                                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // 3. Messaggio intercettato
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 240),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE7FBD3), // Tonalita WhatsApp
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFB4E7A1)),
                                                    ),
                                                    child: Text(
                                                      testo.isNotEmpty ? testo : '(Vuoto)',
                                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // 4. Risposta di GEMINI (Badged)
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: esitoStyle['bg'] as Color,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: esitoStyle['border'] as Color),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(esitoStyle['icon'] as IconData, size: 14, color: esitoStyle['color'] as Color),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        esitoStyle['label'] as String,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: esitoStyle['color'] as Color,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // 5. Gruppo di provenienza (es: Ripamonti Principiante 19:30)
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.indigo.shade50,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Colors.indigo.shade200),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.school, size: 13, color: Colors.indigo.shade800),
                                                      const SizedBox(width: 5),
                                                      ConstrainedBox(
                                                        constraints: const BoxConstraints(maxWidth: 180),
                                                        child: Text(
                                                          corso,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.indigo.shade900,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // 6. Presenza o presenze che verranno segnate
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 220),
                                                  child: Text(
                                                    presenze,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: (esito.contains('PRESENTE') || esito.contains('ASSENTE'))
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: esito.contains('PRESENTE')
                                                          ? Colors.green.shade900
                                                          : (esito.contains('ASSENTE') ? Colors.red.shade900 : Colors.black87),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),

                                              // 7. Dettaglio (Icona lente di ingrandimento)
                                              DataCell(
                                                Center(
                                                  child: IconButton(
                                                    icon: const Icon(Icons.search, color: Colors.blue),
                                                    tooltip: 'Visualizza dettaglio completo',
                                                    onPressed: () => _mostraDettaglioModal(context, log),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI • Tabella Log Corsi WhatsApp'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: content,
    );
  }


  bool _isCurrentlyInWindow() {
    if (!_monitoringActive) return false;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeStart.hour * 60 + _timeStart.minute;
    final endMinutes = _timeEnd.hour * 60 + _timeEnd.minute;

    bool inTime = false;
    if (startMinutes <= endMinutes) {
      inTime = currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      inTime = currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
    if (!inTime) return false;

    const weekdayNames = ['LUNEDI', 'MARTEDI', 'MERCOLEDI', 'GIOVEDI', 'VENERDI', 'SABATO', 'DOMENICA'];
    final todayName = weekdayNames[now.weekday - 1];

    if (_onlyCourseDays) {
      return todayName == 'LUNEDI' || todayName == 'MERCOLEDI' || todayName == 'GIOVEDI';
    } else {
      return _customDays.contains(todayName);
    }
  }

  Future<void> _saveMonitoringConfig() async {
    setState(() => _isSavingConfig = true);
    try {
      final scheduleRes = await ApiService().get('schedules/');
      String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

      final payload = {
        'gemini_monitoring_active': _monitoringActive,
        'gemini_time_start': formatTime(_timeStart),
        'gemini_time_end': formatTime(_timeEnd),
        'gemini_only_course_days': _onlyCourseDays,
        'gemini_custom_days': _customDays.join(','),
      };

      if (scheduleRes is List && scheduleRes.isNotEmpty) {
        final id = scheduleRes[0]['id'];
        await ApiService().put('schedules/$id/', payload);
      } else {
        await ApiService().post('schedules/', {
          ...payload,
          'time': '20:00:00',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione intervalli di monitoraggio salvata con successo!'),
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
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Widget _buildMonitoringConfigCard() {
    final isInWindow = _isCurrentlyInWindow();
    String formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    const allWeekdays = [
      {'key': 'LUNEDI', 'label': 'Lunedì'},
      {'key': 'MARTEDI', 'label': 'Martedì'},
      {'key': 'MERCOLEDI', 'label': 'Mercoledì'},
      {'key': 'GIOVEDI', 'label': 'Giovedì'},
      {'key': 'VENERDI', 'label': 'Venerdì'},
      {'key': 'SABATO', 'label': 'Sabato'},
      {'key': 'DOMENICA', 'label': 'Domenica'},
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione con Titolo, Badge di Stato Attuale e Freccia Espandi/Comprimi
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _isRulesConfigExpanded = !_isRulesConfigExpanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.timer_outlined, color: Colors.indigo.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Intervalli Temporali e Regole di Monitoraggio',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isRulesConfigExpanded
                              ? 'Fascia oraria e giorni in cui i messaggi WhatsApp vengono elaborati per registrare le presenze.'
                              : '${!_monitoringActive ? "Spento" : "Attivo: ${formatTimeOfDay(_timeStart)} - ${formatTimeOfDay(_timeEnd)} (${_onlyCourseDays ? "Solo Giorni Corsi" : "Giorni Custom"})"} • Clicca per modificare',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_monitoringActive
                          ? Colors.grey.shade200
                          : (isInWindow ? Colors.green.shade50 : Colors.amber.shade50),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: !_monitoringActive
                            ? Colors.grey.shade400
                            : (isInWindow ? Colors.green.shade400 : Colors.amber.shade400),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: !_monitoringActive
                                ? Colors.grey.shade600
                                : (isInWindow ? Colors.green.shade700 : Colors.amber.shade700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          !_monitoringActive
                              ? 'Monitoraggio Spento'
                              : (isInWindow ? 'In Finestra Attiva' : 'In Attesa'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_monitoringActive
                                ? Colors.grey.shade800
                                : (isInWindow ? Colors.green.shade800 : Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(_isRulesConfigExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    tooltip: _isRulesConfigExpanded ? 'Comprimi pannello' : 'Espandi pannello',
                    onPressed: () => setState(() => _isRulesConfigExpanded = !_isRulesConfigExpanded),
                  ),
                ],
              ),
            ),

            if (_isRulesConfigExpanded) ...[
              const Divider(height: 24),

            // Switch Abilitazione Generale
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Attiva Monitoraggio Automatico Messaggi WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Se disattivato, i messaggi ricevuti nei gruppi non verranno elaborati e non modificheranno le presenze.',
                style: TextStyle(fontSize: 12),
              ),
              value: _monitoringActive,
              activeColor: Colors.indigo,
              onChanged: (val) => setState(() => _monitoringActive = val),
            ),
            const SizedBox(height: 12),

            // Sezione Orario (Dalle 07:00 alle 13:00)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Fascia Oraria di Monitoraggio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.restore, size: 14),
                        label: const Text('Predefinito (07:00 - 13:00)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            _timeStart = const TimeOfDay(hour: 7, minute: 0);
                            _timeEnd = const TimeOfDay(hour: 13, minute: 0);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Ora Inizio
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Dalle ore: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.access_time, size: 16, color: Colors.indigo),
                            label: Text(
                              formatTimeOfDay(_timeStart),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _timeStart,
                              );
                              if (picked != null) {
                                setState(() => _timeStart = picked);
                              }
                            },
                          ),
                        ],
                      ),

                      // Ora Fine
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Alle ore: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.access_time, size: 16, color: Colors.indigo),
                            label: Text(
                              formatTimeOfDay(_timeEnd),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _timeEnd,
                              );
                              if (picked != null) {
                                setState(() => _timeEnd = picked);
                              }
                            },
                          ),
                        ],
                      ),

                      Text(
                        'Intervallo impostato: ${formatTimeOfDay(_timeStart)} - ${formatTimeOfDay(_timeEnd)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Sezione Giorni di Monitoraggio
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Regola Giorni della Settimana',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Opzione 1: Solo nei giorni dei corsi
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Solo nei giorni dei corsi (Consigliato)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'I messaggi del gruppo WhatsApp vengono intercettati solo nel giorno in cui si tiene ciascun rispettivo corso: Lunedì per i corsi di Ripamonti, Mercoledì e Giovedì per i corsi di San Donato (o se c\'è una lezione programmata oggi).',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: true,
                    groupValue: _onlyCourseDays,
                    activeColor: Colors.indigo,
                    onChanged: (val) => setState(() => _onlyCourseDays = true),
                  ),

                  // Opzione 2: Giorni personalizzati
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Giorni personalizzati specifici',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Seleziona manualmente i giorni della settimana in cui il monitoraggio deve essere attivo.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: false,
                    groupValue: _onlyCourseDays,
                    activeColor: Colors.indigo,
                    onChanged: (val) => setState(() => _onlyCourseDays = false),
                  ),

                  if (!_onlyCourseDays) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: allWeekdays.map((d) {
                          final key = d['key']!;
                          final label = d['label']!;
                          final isSelected = _customDays.contains(key);

                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: Colors.indigo.shade100,
                            checkmarkColor: Colors.indigo.shade900,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.indigo.shade900 : Colors.black87,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  if (!_customDays.contains(key)) _customDays.add(key);
                                } else {
                                  _customDays.remove(key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Pulsante Salva Regole
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSavingConfig ? null : _saveMonitoringConfig,
                icon: _isSavingConfig
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSavingConfig ? 'Salvataggio...' : 'Salva Regole di Monitoraggio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            ],
          ],
        ),
      ),
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

  // ─── MODALE DETTAGLIO LOG (Lente di ingrandimento) ───────────────
  void _mostraDettaglioModal(BuildContext context, dynamic log) {
    final esito = (log['esito_interpretato'] ?? 'IGNOTA').toString().trim();
    final esitoStyle = _getEsitoStyle(esito);

    final allievo = (log['allievo_nome']?.toString().isNotEmpty == true)
        ? log['allievo_nome'].toString()
        : (log['mittente']?.toString() ?? 'Sconosciuto');

    final corso = (log['corso_nome']?.toString().isNotEmpty == true)
        ? log['corso_nome'].toString()
        : (log['gruppo_whatsapp']?.toString() ?? '-');

    final dataOra = _formatDateTime(log['timestamp']);
    final testo = log['testo_originale']?.toString() ?? '';
    final prompt = log['chiamata_ai']?.toString() ?? '';
    final risposta = log['risposta_ai']?.toString() ?? '';
    final azionePresenze = log['azione_presenze']?.toString() ?? _getPresenzeSegnate(log);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 850),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header modale
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.zoom_in, color: Colors.blue.shade800, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dettaglio Intercettazione & Risposta Gemini',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dataOra • $corso',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Chiudi',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Contenuto scrollabile con le sezioni dettagliate
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge riassuntivo Mittente & Esito
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      allievo.isNotEmpty ? allievo[0].toUpperCase() : '?',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          allievo,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        if (log['mittente'] != null && log['mittente'] != allievo)
                                          Text(
                                            'Numero/ID: ${log['mittente']}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: esitoStyle['bg'] as Color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: esitoStyle['border'] as Color),
                            ),
                            child: Row(
                              children: [
                                Icon(esitoStyle['icon'] as IconData, size: 20, color: esitoStyle['color'] as Color),
                                const SizedBox(width: 8),
                                Text(
                                  esitoStyle['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: esitoStyle['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 1. Messaggio WhatsApp
                      _buildModalSectionBox(
                        title: '1. MESSAGGIO WHATSAPP INTERCETTATO',
                        icon: Icons.chat,
                        titleColor: Colors.green.shade900,
                        bgColor: const Color(0xFFE7FBD3),
                        borderColor: const Color(0xFFB4E7A1),
                        content: SelectableText(
                          testo.isNotEmpty ? testo : '(Nessun testo)',
                          style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Chiamata inviata a Gemini AI (Prompt)
                      _buildModalSectionBox(
                        title: '2. CHIAMATA A GEMINI AI (PROMPT INVIATO)',
                        icon: Icons.terminal,
                        titleColor: Colors.cyanAccent,
                        bgColor: const Color(0xFF1E293B),
                        borderColor: const Color(0xFF334155),
                        trailing: prompt.isNotEmpty
                            ? InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: prompt));
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
                                    Icon(Icons.copy, size: 13, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text('Copia', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                  ],
                                ),
                              )
                            : null,
                        content: SelectableText(
                          prompt.isNotEmpty ? prompt : '(Prompt non registrato per questo log)',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFFE2E8F0),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Risposta di Gemini AI
                      _buildModalSectionBox(
                        title: '3. RISPOSTA DI GEMINI AI',
                        icon: Icons.auto_awesome,
                        titleColor: Colors.purple.shade900,
                        bgColor: const Color(0xFFF3E8FF),
                        borderColor: const Color(0xFFD8B4FE),
                        content: SelectableText(
                          risposta.isNotEmpty ? risposta : '(Nessuna risposta registrata)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B0764),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Aggiornamento Presenze
                      _buildModalSectionBox(
                        title: '4. PRESENZA O PRESENZE CHE VERRANNO SEGNATE',
                        icon: Icons.how_to_reg,
                        titleColor: esito.contains('PRESENTE')
                            ? Colors.green.shade900
                            : (esito.contains('ASSENTE') ? Colors.red.shade900 : Colors.blueGrey.shade900),
                        bgColor: esito.contains('PRESENTE')
                            ? const Color(0xFFE8F5E9)
                            : (esito.contains('ASSENTE') ? const Color(0xFFFFEBEE) : const Color(0xFFF1F5F9)),
                        borderColor: esito.contains('PRESENTE')
                            ? const Color(0xFF81C784)
                            : (esito.contains('ASSENTE') ? const Color(0xFFE57373) : const Color(0xFFCBD5E1)),
                        content: SelectableText(
                          azionePresenze,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: (esito.contains('PRESENTE') || esito.contains('ASSENTE')) ? FontWeight.bold : FontWeight.w500,
                            color: esito.contains('PRESENTE')
                                ? Colors.green.shade900
                                : (esito.contains('ASSENTE') ? Colors.red.shade900 : Colors.blueGrey.shade900),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer modale
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Chiudi'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSectionBox({
    required String title,
    required IconData icon,
    required Color titleColor,
    required Color bgColor,
    required Color borderColor,
    required Widget content,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: titleColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}
