import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Estrae (comune, provincia) da `socio.luogoNascita` (es. "MILANO (MI)" -> ("MILANO", "MI")).
(String, String) parseLuogoNascitaSocio(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return ('', '');
  final match = RegExp(r'^(.+?)\s*\(([A-Za-z]{2})\)$').firstMatch(trimmed);
  if (match != null) {
    return (match.group(1)!.trim().toUpperCase(), match.group(2)!.trim().toUpperCase());
  }
  return (trimmed.toUpperCase(), '');
}

/// Estrae (indirizzo, comune, provincia) da `socio.indirizzoResidenza`
/// (es. "Via Roma 10, MILANO, MI" -> ("Via Roma 10", "MILANO", "MI")).
(String, String, String) parseResidenzaSocio(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return ('', '', '');
  final parts = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.length >= 3 && RegExp(r'^[A-Za-z]{2}$').hasMatch(parts.last)) {
    final prov = parts.last.toUpperCase();
    final comune = parts[parts.length - 2].toUpperCase();
    final indirizzo = parts.sublist(0, parts.length - 2).join(', ');
    return (indirizzo, comune, prov);
  }
  return (trimmed, '', '');
}

/// Converte una data ISO (`yyyy-MM-dd`) nel formato italiano (`dd/MM/yyyy`).
String formatSocioIsoDateToItalian(String? iso) {
  final trimmed = (iso ?? '').trim();
  if (trimmed.isEmpty) return '';
  final parts = trimmed.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  return trimmed;
}

/// Costruisce il payload anagrafico completo a partire da un [Socio] selezionato
/// (usato quando si crea un Prospect collegato a un ex-Socio).
Map<String, dynamic> buildSocioAnagraficaPayload(Socio socio) {
  final (comuneNasc, provNasc) = parseLuogoNascitaSocio(socio.luogoNascita);
  final (indirizzoRes, comuneRes, provRes) = parseResidenzaSocio(socio.indirizzoResidenza);
  return {
    'tessera_associativa': socio.numeroTessera,
    if (socio.email != null && socio.email!.trim().isNotEmpty) 'email': socio.email!.trim(),
    if (socio.codiceFiscale != null && socio.codiceFiscale!.trim().isNotEmpty)
      'codice_fiscale': socio.codiceFiscale!.trim().toUpperCase(),
    if (socio.dataNascita != null && socio.dataNascita!.trim().isNotEmpty)
      'data_nascita': socio.dataNascita!.trim(),
    if (comuneNasc.isNotEmpty) 'comune_nascita': comuneNasc,
    if (provNasc.isNotEmpty) 'provincia_nascita': provNasc,
    if (indirizzoRes.isNotEmpty) 'indirizzo_residenza': indirizzoRes,
    if (comuneRes.isNotEmpty) 'comune_residenza': comuneRes,
    if (provRes.isNotEmpty) 'provincia_residenza': provRes,
  };
}

/// Apre un dialog per cercare e selezionare un [Socio] non attualmente collegato ad alcun Allievo.
Future<Socio?> showCercaSocioDialog(BuildContext context, ApiService api) {
  return showDialog<Socio>(
    context: context,
    builder: (ctx) => _CercaSocioDialog(api: api),
  );
}

class _CercaSocioDialog extends StatefulWidget {
  final ApiService api;

  const _CercaSocioDialog({required this.api});

  @override
  State<_CercaSocioDialog> createState() => _CercaSocioDialogState();
}

class _CercaSocioDialogState extends State<_CercaSocioDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Socio> _allSoci = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSoci();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSoci() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.getSoci(senzaAllievo: true);
      if (mounted) {
        setState(() {
          _allSoci = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allSoci.where((s) {
      if (q.isEmpty) return true;
      return s.nomeCompleto.toLowerCase().contains(q) ||
          '${s.nome} ${s.cognome}'.toLowerCase().contains(q) ||
          s.numeroTessera.toLowerCase().contains(q) ||
          (s.codiceFiscale ?? '').toLowerCase().contains(q) ||
          (s.telefono ?? '').toLowerCase().contains(q) ||
          (s.email ?? '').toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_search, color: Colors.indigo),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cerca tra i Soci (non allievi)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seleziona un socio già registrato nel Libro Soci per recuperarne i dati anagrafici e il numero di tessera.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cerca per cognome, nome, tessera o codice fiscale...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _loadSoci, child: const Text('Riprova')),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _allSoci.isEmpty
                                    ? 'Nessun socio senza allievo collegato trovato.'
                                    : 'Nessun risultato per "${_searchCtrl.text.trim()}".',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final details = <String>[
                                  if ((s.telefono ?? '').isNotEmpty) s.telefono!,
                                  if ((s.email ?? '').isNotEmpty) s.email!,
                                  if ((s.codiceFiscale ?? '').isNotEmpty) 'CF: ${s.codiceFiscale}',
                                ];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: s.attivo ? Colors.indigo.shade50 : Colors.grey.shade200,
                                    foregroundColor: s.attivo ? Colors.indigo : Colors.grey.shade700,
                                    child: Text(
                                      '#${s.numeroTessera}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          s.nomeCompleto,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: s.attivo ? Colors.green.shade50 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s.attivo ? 'Attivo' : 'Cessato',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: s.attivo ? Colors.green.shade800 : Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: details.isNotEmpty
                                      ? Text(
                                          details.join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Text('Tessera n. ${s.numeroTessera}'),
                                  onTap: () => Navigator.pop(context, s),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}
