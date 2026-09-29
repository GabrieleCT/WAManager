import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL del backend Django (modificabile se si testa da emulatore Android o IP LAN)
  String baseUrl = 'http://localhost:8082';
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      baseUrl = savedUrl;
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
    final url = Uri.parse('$baseUrl/api/auth/login/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      return true;
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

  // ─── Scuole ───────────────────────────────────────────────
  Future<List<Scuola>> getScuole() async {
    final res = await http.get(Uri.parse('$baseUrl/api/scuole/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Scuola.fromJson(e)).toList();
    }
    return [];
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
    return res.statusCode == 204;
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

  // ─── Allievi & Prospects ──────────────────────────────────
  Future<List<Allievo>> getAllievi({String? corsoId, String? scuolaId, bool? isProspect, String? search}) async {
    var queryParams = <String>[];
    if (corsoId != null) queryParams.add('corso=$corsoId');
    if (scuolaId != null) queryParams.add('corso__scuola=$scuolaId');
    if (isProspect != null) queryParams.add('is_prospect=$isProspect');
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');

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

  Future<bool> convertProspectToStudent(String allievoId, String corsoId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/allievi/$allievoId/convert_to_student/'),
      headers: _headers,
      body: jsonEncode({'corso_id': corsoId}),
    );
    return res.statusCode == 200;
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

  Future<Jolly?> createJolly(String allievoId, int priorita) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/jolly/'),
      headers: _headers,
      body: jsonEncode({'allievo': allievoId, 'priorita': priorita}),
    );
    if (res.statusCode == 201) {
      return Jolly.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    return null;
  }

    Future<Jolly?> updateJolly(String id, String allievoId, int priorita) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/jolly/$id/'),
      headers: _headers,
      body: jsonEncode({'allievo': allievoId, 'priorita': priorita}),
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

  Future<void> initPresenzeLezione(String lezioneId) async {
    await http.post(Uri.parse('$baseUrl/api/lezioni/$lezioneId/init_presenze/'), headers: _headers);
  }

  // ─── Presenze ─────────────────────────────────────────────
  Future<List<Presenza>> getPresenzeForLezione(String lezioneId) async {
    final res = await http.get(Uri.parse('$baseUrl/api/lezioni/$lezioneId/presenze/'), headers: _headers);
    if (res.statusCode == 200) {
      final List list = jsonDecode(utf8.decode(res.bodyBytes));
      return list.map((e) => Presenza.fromJson(e)).toList();
    }
    return [];
  }

  Future<bool> batchUpdatePresenze(String lezioneId, List<Map<String, dynamic>> presenze) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/presenze/batch_update/'),
      headers: _headers,
      body: jsonEncode({'lezione_id': lezioneId, 'presenze': presenze}),
    );
    return res.statusCode == 200;
  }

  // ─── Pagamenti ────────────────────────────────────────────
  Future<List<Pagamento>> getPagamenti({String? corsoId, String? scuolaId, String? trimestre}) async {
    var params = <String>[];
    if (corsoId != null) params.add('corso=$corsoId');
    if (scuolaId != null) params.add('corso__scuola=$scuolaId');
    if (trimestre != null) params.add('trimestre=$trimestre');

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
}


