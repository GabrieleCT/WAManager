import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL del backend Django (modificabile se si testa da emulatore Android o IP LAN)
  String baseUrl = 'http://localhost:50082';
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.host.isNotEmpty && uri.host != 'localhost' && uri.host != '127.0.0.1') {
        baseUrl = '${uri.scheme}://${uri.host}:50082';
      } else {
        baseUrl = 'http://localhost:50082';
      }
    } else {
      final savedUrl = prefs.getString('api_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        baseUrl = savedUrl;
      } else {
        baseUrl = 'http://localhost:50082';
      }
    }
  }

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Token $_token';
    }
    return headers;
  }
  Map<String, String> getHeaders() => _headers;

  Future<bool> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/login/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        return true;
      }
    } catch (e) {
      debugPrint('Errore durante login: $e');
    }
    return false;
  }

  Future<void> logout() async {
    try {
      final url = Uri.parse('$baseUrl/api/auth/logout/');
      await http.post(url, headers: _headers);
    } catch (_) {}
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> setBaseUrl(String newUrl) async {
    baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', newUrl);
  }

  // Helper generici
  Future<dynamic> get(String endpoint) async {
    final res = await http.get(Uri.parse('$baseUrl/api/$endpoint'), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Failed to load: ${res.statusCode} ${res.body}');
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/$endpoint'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Failed to post: ${res.statusCode} ${res.body}');
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/$endpoint'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Failed to update: ${res.statusCode} ${res.body}');
  }

  // ─── Scuole ───────────────────────────────────────────────
  Future<List<Scuola>> getScuole() async {
    final res = await http.get(Uri.parse('$baseUrl/api/scuole/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Scuola.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> checkScuolaWhatsapp(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/scuole/$id/check-whatsapp/'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('Errore check whatsapp: ${res.body}');
  }

  Future<Scuola?> createScuola(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/scuole/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 201) {
      return Scuola.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Scuola?> updateScuola(String id, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/scuole/$id/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 200) {
      return Scuola.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deleteScuola(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/scuole/$id/'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }

  // ─── Corsi ────────────────────────────────────────────────
  Future<List<Corso>> getCorsi({String? scuolaId}) async {
    var urlStr = '$baseUrl/api/corsi/';
    if (scuolaId != null) urlStr += '?scuola=$scuolaId';
    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Corso.fromJson(e)).toList();
    }
    return [];
  }

  Future<Corso?> createCorso(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/corsi/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 201) {
      return Corso.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Corso?> updateCorso(String id, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/corsi/$id/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 200) {
      return Corso.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deleteCorso(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/corsi/$id/'), headers: _headers);
    return res.statusCode == 204;
  }

  // ─── Argomenti ────────────────────────────────────────────
  Future<List<Argomento>> getArgomenti() async {
    final res = await http.get(Uri.parse('$baseUrl/api/argomenti/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Argomento.fromJson(e)).toList();
    }
    return [];
  }

  Future<Argomento?> createArgomento(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/argomenti/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 201) {
      return Argomento.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Argomento?> updateArgomento(String id, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/argomenti/$id/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 200) {
      return Argomento.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deleteArgomento(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/argomenti/$id/'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }

  Future<List<Argomento>?> reorderArgomenti(List<String> ids) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/argomenti/reorder/'),
        headers: _headers,
        body: jsonEncode({'ids': ids}),
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((e) => Argomento.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Errore reorderArgomenti: $e');
    }
    return null;
  }

  // ─── Allievi & Prospects ──────────────────────────────────
  Future<List<Allievo>> getAllievi({
    String? corsoId,
    String? scuolaId,
    bool? isProspect,
    String? search,
    bool? corsoIsNull,
    String? statoTessera,
  }) async {
    var queryParams = <String>[];
    if (corsoId != null) queryParams.add('corso=$corsoId');
    if (corsoIsNull != null && corsoIsNull) queryParams.add('corso__isnull=True');
    if (scuolaId != null) queryParams.add('corso__scuola=$scuolaId');
    if (isProspect != null) queryParams.add('is_prospect=$isProspect');
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');
    if (statoTessera != null && statoTessera.isNotEmpty && statoTessera != 'tutti') {
      queryParams.add('stato_tessera=${Uri.encodeComponent(statoTessera)}');
    }

    var urlStr = '$baseUrl/api/allievi/';
    if (queryParams.isNotEmpty) urlStr += '?${queryParams.join('&')}';

    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Allievo.fromJson(e)).toList();
    }
    return [];
  }

  Future<Allievo?> createAllievo(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/allievi/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 201) {
      return Allievo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Allievo?> updateAllievo(String id, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/allievi/$id/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 200) {
      return Allievo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deleteAllievo(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/allievi/$id/'), headers: _headers);
    return res.statusCode == 204;
  }

  Future<Allievo?> convertProspectToStudent(String allievoId, String corsoId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/allievi/$allievoId/convert_to_student/'),
      headers: _headers,
      body: jsonEncode({'corso_id': corsoId}),
    );
    if (res.statusCode == 200) {
      return Allievo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> setPartner(String allievoId, String? partnerId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/allievi/$allievoId/set_partner/'),
      headers: _headers,
      body: jsonEncode({'partner_id': partnerId}),
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> syncWhatsappScuola() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/allievi/sync-whatsapp-scuola/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } else {
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return {
            'success': false,
            'error': data['error'] ?? 'Errore sincronizzazione (HTTP ${res.statusCode})',
          };
        } catch (_) {
          return {
            'success': false,
            'error': 'Errore HTTP ${res.statusCode}: ${res.body}',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addStudentToSchoolGroup(String allievoId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/allievi/$allievoId/add-to-whatsapp-scuola/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } else {
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return {
            'success': false,
            'error': data['error'] ?? 'Errore aggiunta gruppo (HTTP ${res.statusCode})',
            'invite_link': data['invite_link'],
          };
        } catch (_) {
          return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addStudentToCourseGroup(String allievoId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/allievi/$allievoId/add-to-whatsapp-corso/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } else {
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return {
            'success': false,
            'error': data['error'] ?? 'Errore aggiunta gruppo corso (HTTP ${res.statusCode})',
            'invite_link': data['invite_link'],
          };
        } catch (_) {
          return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resolveWhatsappGroup(String link) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/whatsapp/resolve-group/'),
        headers: _headers,
        body: jsonEncode({'link': link.trim()}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } else {
        try {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          return {
            'success': false,
            'error': data['error'] ?? 'Errore risoluzione gruppo (HTTP ${res.statusCode})',
          };
        } catch (_) {
          return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Jolly ────────────────────────────────────────────────
  Future<List<Jolly>> getJolly() async {
    final res = await http.get(Uri.parse('$baseUrl/api/jolly/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Jolly.fromJson(e)).toList();
    }
    return [];
  }

  Future<Jolly?> createJolly(String allievoId, int priorita, {String? nickname}) async {
    final Map<String, dynamic> data = {'allievo': allievoId, 'priorita': priorita};
    if (nickname != null) {
      data['nickname'] = nickname.trim();
    }
    final res = await http.post(
      Uri.parse('$baseUrl/api/jolly/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Jolly.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Jolly?> updateJolly(String id, String allievoId, int priorita, {String? nickname}) async {
    final Map<String, dynamic> data = {'allievo': allievoId, 'priorita': priorita};
    if (nickname != null) {
      data['nickname'] = nickname.trim();
    }
    final res = await http.put(
      Uri.parse('$baseUrl/api/jolly/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Jolly.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deleteJolly(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/jolly/$id/'),
      headers: _headers,
    );
    return res.statusCode == 204 || res.statusCode == 200;
  }
  Future<Map<String, dynamic>> sendJollyMessage({
    required String testo,
    List<String>? lezioneIds,
    List<String>? jollyIds,
    int? numJolly,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/jolly/send-message/'),
      headers: _headers,
      body: jsonEncode({
        'testo': testo,
        'lezione_ids': lezioneIds ?? [],
        'jolly_ids': jollyIds ?? [],
        'num_jolly': numJolly ?? 0,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  // ─── Lezioni ──────────────────────────────────────────────
  Future<List<Lezione>> getLezioni({String? corsoId}) async {
    var urlStr = '$baseUrl/api/lezioni/';
    if (corsoId != null) urlStr += '?corso=$corsoId';
    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Lezione.fromJson(e)).toList();
    }
    return [];
  }

  Future<Lezione?> createLezione(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/lezioni/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 201) {
      return Lezione.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Lezione?> updateLezione(String id, Map<String, dynamic> data) async {
    final res = await http.patch(Uri.parse('$baseUrl/api/lezioni/$id/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 200) {
      return Lezione.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<List<Lezione>> creaTrimestre(String corsoId, List<Map<String, dynamic>> lezioni) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/lezioni/crea-trimestre/'),
      headers: _headers,
      body: jsonEncode({
        'corso': corsoId,
        'lezioni': lezioni,
      }),
    );
    if (res.statusCode == 201) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Lezione.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> deleteLezione(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/lezioni/$id/'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }

  Future<void> initPresenzeLezione(String lezioneId) async {
    await http.post(Uri.parse('$baseUrl/api/lezioni/$lezioneId/init_presenze/'), headers: _headers);
  }

  // ─── Presenze ─────────────────────────────────────────────
  Future<void> initPresenze(String lezioneId) async {
    await http.post(Uri.parse('$baseUrl/api/lezioni/$lezioneId/init_presenze/'), headers: _headers);
  }

  Future<List<Presenza>> getPresenzeForLezione(String lezioneId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/lezioni/$lezioneId/presenze/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Presenza.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> updatePresenza(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/presenze/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  Future<bool> batchUpdatePresenze(String lezioneId, List<Map<String, dynamic>> presenze) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/presenze/batch_update/'),
      headers: _headers,
      body: jsonEncode({'lezione_id': lezioneId, 'presenze': presenze}),
    );
    return res.statusCode == 200;
  }

  Future<bool> aggiungiJollyLezione(String lezioneId, String allievoId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/lezioni/$lezioneId/aggiungi-jolly/'),
      headers: _headers,
      body: jsonEncode({'allievo_id': allievoId}),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<bool> deletePresenza(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/presenze/$id/'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }


  // ─── Pagamenti ────────────────────────────────────────────
  Future<List<Pagamento>> getPagamenti({
    String? corsoId,
    String? scuolaId,
    String? trimestre,
    bool? hasRicevuta,
    String? dataDa,
    String? dataA,
    String? data,
  }) async {
    var params = <String>[];
    if (corsoId != null) params.add('corso=$corsoId');
    if (scuolaId != null) params.add('corso__scuola=$scuolaId');
    if (trimestre != null) params.add('trimestre=$trimestre');
    if (hasRicevuta != null) params.add('has_ricevuta=$hasRicevuta');
    if (data != null) params.add('data=$data');
    if (dataDa != null) params.add('data_da=$dataDa');
    if (dataA != null) params.add('data_a=$dataA');

    var urlStr = '$baseUrl/api/pagamenti/';
    if (params.isNotEmpty) urlStr += '?${params.join('&')}';

    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Pagamento.fromJson(e)).toList();
    }
    return [];
  }

  Future<Pagamento?> createPagamento(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/pagamenti/'), headers: _headers, body: jsonEncode(data));
    if (res.statusCode == 201) {
      return Pagamento.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Pagamento?> updatePagamento(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/pagamenti/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Pagamento.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deletePagamento(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/pagamenti/$id/'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }

  // ─── Ricevute ─────────────────────────────────────────────
  Future<List<Ricevuta>> getRicevute({
    int? anno,
    String? search,
    String? dataDa,
    String? dataA,
    String? data,
  }) async {
    var params = <String>[];
    if (anno != null) params.add('anno=$anno');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (data != null) params.add('data=$data');
    if (dataDa != null) params.add('data_da=$dataDa');
    if (dataA != null) params.add('data_a=$dataA');

    var urlStr = '$baseUrl/api/ricevute/';
    if (params.isNotEmpty) urlStr += '?${params.join('&')}';

    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Ricevuta.fromJson(e)).toList();
    }
    return [];
  }

  Future<Ricevuta?> getRicevuta(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/ricevute/$id/'), headers: _headers);
    if (res.statusCode == 200) {
      return Ricevuta.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Ricevuta?> createRicevuta(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/ricevute/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return Ricevuta.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore createRicevuta: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<Ricevuta?> updateRicevuta(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/ricevute/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return Ricevuta.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore updateRicevuta: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<bool> deleteRicevuta(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/ricevute/$id/'), headers: _headers);
    return res.statusCode == 204 || res.statusCode == 200;
  }

  Future<List<int>> getAnniRicevute() async {
    final res = await http.get(Uri.parse('$baseUrl/api/ricevute/anni/'), headers: _headers);
    if (res.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      final List list = data['anni'] ?? [];
      return list.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 2026).toList();
    }
    return [DateTime.now().year];
  }

  Future<ContatoreRicevuteInfo?> getContatoreRicevute({int? anno}) async {
    var urlStr = '$baseUrl/api/ricevute/contatore/';
    if (anno != null) urlStr += '?anno=$anno';
    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      return ContatoreRicevuteInfo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<ContatoreRicevuteInfo?> aggiornaContatoreRicevute(int anno, int ultimoNumero) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/ricevute/aggiorna-contatore/'),
      headers: _headers,
      body: jsonEncode({'anno': anno, 'ultimo_numero': ultimoNumero}),
    );
    if (res.statusCode == 200) {
      return ContatoreRicevuteInfo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Map<String, dynamic>> inserisciRicevutaInCassa(String id, {String? categoria, String? descrizione, String? note}) async {
    try {
      final body = <String, dynamic>{};
      if (categoria != null) body['categoria'] = categoria;
      if (descrizione != null) body['descrizione'] = descrizione;
      if (note != null) body['note'] = note;

      final res = await http.post(
        Uri.parse('$baseUrl/api/ricevute/$id/inserisci-in-cassa/'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        return {
          'success': true,
          'message': decoded['message'],
          'ricevuta': decoded['ricevuta'] != null ? Ricevuta.fromJson(decoded['ricevuta']) : null,
          'movimento_id': decoded['movimento_id'],
        };
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        return {
          'success': false,
          'error': err['error'] ?? 'Errore durante l\'inserimento in cassa.',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Uint8List?> getRicevutaPdf(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/ricevute/$id/pdf/'), headers: _headers);
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    debugPrint('Errore getRicevutaPdf: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<Uint8List?> getPagamentoRicevutaPdf(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/pagamenti/$id/pdf/'), headers: _headers);
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    debugPrint('Errore getPagamentoRicevutaPdf: ${res.statusCode} -> ${res.body}');
    return null;
  }


  // ─── Matches ──────────────────────────────────────────────
  Future<Map<String, dynamic>> generateMatches(String lezioneId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/matches/generate/'),
      headers: _headers,
      body: jsonEncode({'lezione_id': lezioneId}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {};
  }

  // ─── 5.1 & 5.2 Import / Export ─────────────────────────────
  String getExportUrl(String model, {String format = 'xlsx', String? scuolaId, String? corsoId, String? trimestre}) {
    var params = <String>['format=$format'];
    if (scuolaId != null) params.add('scuola=$scuolaId');
    if (corsoId != null) params.add('corso=$corsoId');
    if (trimestre != null) params.add('trimestre=$trimestre');
    if (_token != null && _token!.isNotEmpty) params.add('token=$_token');
    return '$baseUrl/api/export/$model/?${params.join('&')}';
  }

  String getTemplateUrl(String model, {String format = 'xlsx'}) {
    var url = '$baseUrl/api/import/template/$model/?format=$format';
    if (_token != null && _token!.isNotEmpty) {
      url += '&token=$_token';
    }
    return url;
  }

  Future<Map<String, dynamic>> uploadImportFile(String model, List<int> bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/api/import/$model/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);

    final multipartFile = http.MultipartFile.fromBytes('file', bytes, filename: filename);
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'error': 'Errore HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Sondaggi Mattutini ────────────────────────────────────
  Future<List<SondaggioMattutinoConfig>> getSondaggiMattutini() async {
    final res = await http.get(Uri.parse('$baseUrl/api/sondaggio-mattutino/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => SondaggioMattutinoConfig.fromJson(e)).toList();
    }
    return [];
  }

  Future<SondaggioMattutinoConfig?> createSondaggioMattutino(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return SondaggioMattutinoConfig.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<SondaggioMattutinoConfig?> updateSondaggioMattutino(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return SondaggioMattutinoConfig.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<bool> deleteSondaggioMattutino(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/api/sondaggio-mattutino/$id/'), headers: _headers);
    return res.statusCode == 204;
  }

  Future<Map<String, dynamic>> inviaSondaggioOra(String id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/$id/invia_ora/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<SondaggioMattutinoConfig?> getDaemonConfig() async {
    final res = await http.get(Uri.parse('$baseUrl/api/sondaggio-mattutino/daemon-config/'), headers: _headers);
    if (res.statusCode == 200) {
      return SondaggioMattutinoConfig.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<SondaggioMattutinoConfig?> saveDaemonConfig(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/daemon-config/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return SondaggioMattutinoConfig.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Map<String, dynamic>> inviaSondaggioManuale(
    List<String> corsoIds, {
    String? testo,
    bool isPoll = true,
    List<String>? pollOpzioni,
  }) async {
    final body = {
      'corso_ids': corsoIds,
      if (testo != null && testo.trim().isNotEmpty) 'testo': testo,
      'is_poll': isPoll,
      if (pollOpzioni != null) 'poll_opzioni': pollOpzioni,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/invia-manuale/'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> eseguiDemoneOra() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/esegui-demone-ora/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> inviaSollecitoOra({List<String>? corsoIds}) async {
    final body = {
      if (corsoIds != null && corsoIds.isNotEmpty) 'corso_ids': corsoIds,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/api/sondaggio-mattutino/invia-sollecito-ora/'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
    }
  }

  Future<Map<String, dynamic>> inviaSollecitoAllievo(String allievoId, {String? testo}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/allievi/$allievoId/invia-sollecito/'),
      headers: _headers,
      body: jsonEncode({
        if (testo != null && testo.isNotEmpty) 'testo': testo,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
    }
  }

  // ─── Template Documenti (PDF Ricevuta, Modulo Tesseramento) ─────────────
  Future<List<DocumentTemplate>> getDocumentTemplates() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/document-templates/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => DocumentTemplate.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> uploadDocumentTemplate(String chiave, List<int> bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/api/document-templates/$chiave/upload/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);

    final multipartFile = http.MultipartFile.fromBytes('file', bytes, filename: filename);
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'error': 'Errore HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeDocumentTemplate(String chiave) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/document-templates/$chiave/remove/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  String getDocumentTemplateDownloadUrl(String chiave) {
    return '$baseUrl/api/document-templates/$chiave/file/';
  }

  // ─── Google Drive Configuration ──────────────────────────────
  Future<GoogleDriveConfig?> getGoogleDriveConfig() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/google-drive/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return GoogleDriveConfig.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Map<String, dynamic>> uploadGoogleDriveKey(List<int> bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/api/google-drive/upload/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);

    final multipartFile = http.MultipartFile.fromBytes('file', bytes, filename: filename);
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'error': 'Errore HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> testGoogleDriveConnection() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/test/'),
      headers: _headers,
    );
    if (res.statusCode == 200 || res.statusCode == 400) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> removeGoogleDriveKey() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/remove/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> switchGoogleDriveAuthType(String authType) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/switch-auth-type/'),
      headers: _headers,
      body: jsonEncode({'auth_type': authType}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> saveGoogleDriveOAuthCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/oauth-save-credentials/'),
      headers: _headers,
      body: jsonEncode({
        'client_id': clientId,
        'client_secret': clientSecret,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 400) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> initGoogleDriveOAuth({
    String? clientId,
    String? clientSecret,
    String? redirectUri,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/oauth-init/'),
      headers: _headers,
      body: jsonEncode({
        if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
        if (clientSecret != null && clientSecret.isNotEmpty) 'client_secret': clientSecret,
        if (redirectUri != null && redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 400) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> disconnectGoogleDriveOAuth() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/oauth-disconnect/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> updateGoogleDriveConfig(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/update-settings/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> getGoogleDriveFolders({String? parentId}) async {
    final uri = Uri.parse('$baseUrl/api/google-drive/folders/').replace(
      queryParameters: parentId != null && parentId.isNotEmpty
          ? {'parent_id': parentId}
          : null,
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {'success': false, 'error': data['error'] ?? 'Errore HTTP ${res.statusCode}'};
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
    }
  }

  Future<Map<String, dynamic>> createGoogleDriveFolder({
    required String name,
    String? parentId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-drive/create-folder/'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {'success': false, 'error': data['error'] ?? 'Errore HTTP ${res.statusCode}'};
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
    }
  }

  // ─── Google Contacts (OAuth 2.0) ─────────────────────────
  Future<GoogleContactsConfig?> getGoogleContactsConfig() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/google-contacts/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return GoogleContactsConfig.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<Map<String, dynamic>> saveGoogleContactsCredentials({
    required String clientId,
    required String clientSecret,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/api/google-contacts/save-credentials/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields['client_id'] = clientId;
    request.fields['client_secret'] = clientSecret;

    if (fileBytes != null && fileName != null) {
      final multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: fileName);
      request.files.add(multipartFile);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'error': 'Errore HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> initGoogleContactsOAuth({String? redirectUri}) async {
    var bodyData = <String, dynamic>{};
    if (redirectUri != null && redirectUri.isNotEmpty) {
      bodyData['redirect_uri'] = redirectUri;
    }
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/oauth-init/'),
      headers: _headers,
      body: jsonEncode(bodyData),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': res.body};
  }

  Future<Map<String, dynamic>> disconnectGoogleContacts() async {
    final res = await http.post(Uri.parse('$baseUrl/api/google-contacts/oauth-disconnect/'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': res.body};
  }

  Future<Map<String, dynamic>> testGoogleContactsConnection() async {
    final res = await http.post(Uri.parse('$baseUrl/api/google-contacts/test-connection/'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'message': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> saveGoogleContactsSettings({
    String? syncGroupName,
    bool? isActive,
  }) async {
    var bodyData = <String, dynamic>{};
    if (syncGroupName != null) bodyData['sync_group_name'] = syncGroupName;
    if (isActive != null) bodyData['is_active'] = isActive;

    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/save-settings/'),
      headers: _headers,
      body: jsonEncode(bodyData),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': res.body};
  }

  Future<Map<String, dynamic>> syncAllievoToGoogleContacts(String allievoId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/allievi/$allievoId/sync-google-contacts/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'message': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> syncAllGoogleContacts() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/sync-all-contacts/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'message': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<GoogleContactComparisonReport?> getGoogleContactsComparison() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/google-contacts/comparison/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return GoogleContactComparisonReport.fromJson(json);
    }
    return null;
  }

  Future<Map<String, dynamic>> runGoogleContactsFullSync() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/run-full-sync/'),
      headers: _headers,
    );
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> pushToGoogle(String allievoId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/push-to-google/'),
      headers: _headers,
      body: jsonEncode({'allievo_id': allievoId}),
    );
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> pullFromGoogle(String allievoId, String googleId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/pull-from-google/'),
      headers: _headers,
      body: jsonEncode({'allievo_id': allievoId, 'google_id': googleId}),
    );
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> importFromGoogle(String googleId, {bool? asProspect, String? corsoId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/import-from-google/'),
      headers: _headers,
      body: jsonEncode({
        'google_id': googleId,
        'as_prospect': asProspect,
        'corso_id': corsoId,
      }),
    );
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<Map<String, dynamic>> deleteGoogleContactAction(String googleId, {String? allievoId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/google-contacts/delete-google-contact/'),
      headers: _headers,
      body: jsonEncode({
        'google_id': googleId,
        'allievo_id': allievoId,
      }),
    );
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}: ${res.body}'};
    }
  }

  Future<List<GoogleContactsSyncLog>> getGoogleContactsSyncLogs() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/google-contacts/sync-logs/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((item) => GoogleContactsSyncLog.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> uploadRicevutaToDrive(String ricevutaId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/ricevute/$ricevutaId/upload-to-drive/'),
      headers: _headers,
    );
    if (res.statusCode == 200 || res.statusCode == 400 || res.statusCode == 500) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Map<String, dynamic>> sendRicevutaWhatsApp({
    required String ricevutaId,
    required String telefono,
    String? messaggio,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/ricevute/$ricevutaId/send-whatsapp/'),
      headers: _headers,
      body: jsonEncode({
        'telefono': telefono,
        if (messaggio != null && messaggio.isNotEmpty) 'messaggio': messaggio,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 400 || res.statusCode == 500) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  Future<Uint8List?> getModuloTesseramentoPdf(String allievoId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/allievi/$allievoId/modulo-tesseramento-pdf/'), headers: _headers);
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    debugPrint('Errore getModuloTesseramentoPdf: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<Map<String, dynamic>> sendModuloTesseramentoWhatsApp({
    required String allievoId,
    required String telefono,
    String? messaggio,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/allievi/$allievoId/send-modulo-tesseramento/'),
      headers: _headers,
      body: jsonEncode({
        'telefono': telefono,
        if (messaggio != null && messaggio.isNotEmpty) 'messaggio': messaggio,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 400 || res.statusCode == 500) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
  }

  // ─── Bilancio: Prima Nota Cassa ────────────────────────────
  Future<List<MovimentoPrimaNota>> getMovimentiPrimaNota({
    String? tipo,
    String? categoria,
    int? anno,
    int? mese,
    String? dataDa,
    String? dataA,
    String? search,
  }) async {
    var params = <String>[];
    if (tipo != null && tipo.isNotEmpty) params.add('tipo=$tipo');
    if (categoria != null && categoria.isNotEmpty) params.add('categoria=${Uri.encodeComponent(categoria)}');
    if (anno != null) params.add('anno=$anno');
    if (mese != null) params.add('mese=$mese');
    if (dataDa != null && dataDa.isNotEmpty) params.add('data_da=$dataDa');
    if (dataA != null && dataA.isNotEmpty) params.add('data_a=$dataA');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');

    var urlStr = '$baseUrl/api/prima-nota/';
    if (params.isNotEmpty) urlStr += '?${params.join('&')}';

    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => MovimentoPrimaNota.fromJson(e)).toList();
    }
    return [];
  }

  Future<RiepilogoPrimaNota?> getRiepilogoPrimaNota({
    String? tipo,
    String? categoria,
    int? anno,
    int? mese,
    String? dataDa,
    String? dataA,
    String? search,
  }) async {
    var params = <String>[];
    if (tipo != null && tipo.isNotEmpty) params.add('tipo=$tipo');
    if (categoria != null && categoria.isNotEmpty) params.add('categoria=${Uri.encodeComponent(categoria)}');
    if (anno != null) params.add('anno=$anno');
    if (mese != null) params.add('mese=$mese');
    if (dataDa != null && dataDa.isNotEmpty) params.add('data_da=$dataDa');
    if (dataA != null && dataA.isNotEmpty) params.add('data_a=$dataA');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');

    var urlStr = '$baseUrl/api/prima-nota/riepilogo/';
    if (params.isNotEmpty) urlStr += '?${params.join('&')}';

    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      return RiepilogoPrimaNota.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

  Future<MovimentoPrimaNota?> createMovimentoPrimaNota(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/prima-nota/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return MovimentoPrimaNota.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore createMovimentoPrimaNota: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<MovimentoPrimaNota?> updateMovimentoPrimaNota(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/prima-nota/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return MovimentoPrimaNota.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore updateMovimentoPrimaNota: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<bool> deleteMovimentoPrimaNota(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/prima-nota/$id/'),
      headers: _headers,
    );
    return res.statusCode == 204 || res.statusCode == 200;
  }

  Future<BilancioMensileAnno?> getBilancioMensile({int? anno}) async {
    final year = anno ?? DateTime.now().year;
    final res = await http.get(
      Uri.parse('$baseUrl/api/prima-nota/bilancio-mensile/?anno=$year'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return BilancioMensileAnno.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore getBilancioMensile: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<BilancioAnnualeData?> getBilancioAnnuale({int? anno}) async {
    final year = anno ?? DateTime.now().year;
    final res = await http.get(
      Uri.parse('$baseUrl/api/prima-nota/bilancio-annuale/?anno=$year'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return BilancioAnnualeData.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore getBilancioAnnuale: ${res.statusCode} -> ${res.body}');
    return null;
  }



  // ─── Categorie Bilancio ──────────────────────────────────────────

  Future<List<CategoriaBilancio>> getCategorieBilancio({String? tipo, String? search}) async {
    final params = <String>[];
    if (tipo != null && tipo.isNotEmpty) params.add('tipo=$tipo');
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');

    var urlStr = '$baseUrl/api/categorie-bilancio/';
    if (params.isNotEmpty) urlStr += '?${params.join('&')}';

    final res = await http.get(Uri.parse(urlStr), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => CategoriaBilancio.fromJson(json)).toList();
    }
    return [];
  }

  Future<CategoriaBilancio?> createCategoriaBilancio(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/categorie-bilancio/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) {
      return CategoriaBilancio.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore createCategoriaBilancio: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<CategoriaBilancio?> updateCategoriaBilancio(String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/categorie-bilancio/$id/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return CategoriaBilancio.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    debugPrint('Errore updateCategoriaBilancio: ${res.statusCode} -> ${res.body}');
    return null;
  }

  Future<bool> deleteCategoriaBilancio(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/categorie-bilancio/$id/'),
      headers: _headers,
    );
    return res.statusCode == 204 || res.statusCode == 200;
  }

  Future<bool> resetDefaultCategorieBilancio() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/categorie-bilancio/reset-defaults/'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  // ─── Configurazione ASD & Direttivo ─────────────────────────
  Future<ConfigurazioneASD?> getConfigurazioneASD() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/asd/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return ConfigurazioneASD.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Errore getConfigurazioneASD: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> saveConfigurazioneASD(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/asd/salva/'),
        headers: _headers,
        body: jsonEncode(data),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } else {
        return {
          'success': false,
          'error': 'Errore HTTP ${res.statusCode}: ${res.body}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<MembroDirettivo>> getDirettivo() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/direttivo/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((json) => MembroDirettivo.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Errore getDirettivo: $e');
    }
    return [];
  }

  Future<MembroDirettivo?> updateMembroDirettivo(String id, Map<String, dynamic> data) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/api/direttivo/$id/'),
        headers: _headers,
        body: jsonEncode(data),
      );
      if (res.statusCode == 200) {
        return MembroDirettivo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
      } else {
        debugPrint('Errore updateMembroDirettivo: ${res.statusCode} -> ${res.body}');
      }
    } catch (e) {
      debugPrint('Errore updateMembroDirettivo: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> uploadFirmaMembro(String id, List<int> bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/api/direttivo/$id/upload-firma/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);

    final multipartFile = http.MultipartFile.fromBytes('firma', bytes, filename: filename);
    request.files.add(multipartFile);

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {'success': false, 'error': 'Errore HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeFirmaMembro(String id) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/direttivo/$id/remove-firma/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String getFirmaFullUrl(String? firmaUrl) {
    if (firmaUrl == null || firmaUrl.isEmpty) return '';
    if (firmaUrl.startsWith('http://') || firmaUrl.startsWith('https://')) {
      return firmaUrl;
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = firmaUrl.startsWith('/') ? firmaUrl : '/$firmaUrl';
    return '$cleanBase$cleanPath';
  }

  Future<Map<String, dynamic>?> getApkInfo() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/app/apk-info/'));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  String getApkDownloadUrl() {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase/api/app/download-apk/';
  }

  // --- Generazione Verbale Rendiconto ---
  Future<Map<String, dynamic>> getDatiVerbaleDefault() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/asd/dati-verbale-default/'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'Errore HTTP ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Uint8List?> generaVerbalePdf({
    required String dataAssemblea,
    required String orarioAssemblea,
    required String dataAffissione,
    int? annoEsercizio,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/asd/genera-verbale/'),
        headers: _headers,
        body: jsonEncode({
          'data_assemblea': dataAssemblea,
          'orario_assemblea': orarioAssemblea,
          'data_affissione_convocazione': dataAffissione,
          if (annoEsercizio != null) 'anno_esercizio': annoEsercizio,
        }),
      );
      if (res.statusCode == 200) {
        return res.bodyBytes;
      } else {
        try {
          final errJson = jsonDecode(utf8.decode(res.bodyBytes));
          throw Exception(errJson['error'] ?? 'Errore generazione verbale (${res.statusCode})');
        } catch (e) {
          if (e is Exception && !e.toString().contains('FormatException')) rethrow;
          throw Exception('Errore HTTP ${res.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Errore generaVerbalePdf: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadVerbaleDrive({
    required String dataAssemblea,
    required String orarioAssemblea,
    required String dataAffissione,
    int? annoEsercizio,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/asd/upload-verbale-drive/'),
        headers: _headers,
        body: jsonEncode({
          'data_assemblea': dataAssemblea,
          'orario_assemblea': orarioAssemblea,
          'data_affissione_convocazione': dataAffissione,
          if (annoEsercizio != null) 'anno_esercizio': annoEsercizio,
        }),
      );
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
