import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  String _status = 'Inizializzazione...';
  String? _qrData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final api = ApiService();
      final url = Uri.parse('${api.baseUrl}/api/wa-status/');
      final res = await http.get(url, headers: api.getHeaders());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _status = data['status'] ?? 'Sconosciuto';
            _qrData = data['qr'];
          });
        }
      } else {
        if (mounted) setState(() => _status = 'Errore API (Codice ${res.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Gateway offline o irraggiungibile: $e');
    }
  }

  Future<void> _logoutWA() async {
    try {
      final api = ApiService();
      await http.post(Uri.parse('${api.baseUrl}/api/wa-logout/'), headers: api.getHeaders());
      _fetchStatus();
    } catch (e) {
       // ignora
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stato WhatsApp Gateway')),
      body: Center(
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text('Stato: $_status', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                if (_status == 'QR' && _qrData != null && _qrData!.startsWith('data:image'))
                  Image.memory(
                    base64Decode(_qrData!.split(',').last),
                    width: 250,
                    height: 250,
                  ),
                if (_status == 'CONNECTED')
                  const Icon(Icons.check_circle, color: Colors.green, size: 100),
                if (_status == 'CONNECTED') ...[
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    onPressed: _logoutWA,
                    icon: const Icon(Icons.logout),
                    label: const Text('Disconnetti Dispositivo'),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
