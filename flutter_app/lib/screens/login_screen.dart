import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin');
  final _urlController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiService().baseUrl;
  }

  void _doLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ApiService();
    if (_urlController.text.trim().isNotEmpty) {
      await api.setBaseUrl(_urlController.text.trim());
    }

    final success = await api.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _loading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => _error = 'Credenziali non valide o server non raggiungibile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEBE5DA), Color(0xFFDCD4C6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                elevation: 12,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TantoTango Manager',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Text(
                        'Gestionale scuola di ballo',
                        style: TextStyle(color: Colors.grey, fontSize: 14, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 32),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13))),
                            ],
                          ),
                        ),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onSubmitted: (_) => _doLogin(),
                      ),
                      const SizedBox(height: 20),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Impostazioni Server', style: TextStyle(fontSize: 14)),
                        children: [
                          const SizedBox(height: 8),
                          TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'URL Backend Django',
                              hintText: 'http://localhost:8000',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _doLogin,
                          child: _loading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('ACCEDI', style: TextStyle(fontSize: 16, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text('v${snapshot.data!.version}', style: const TextStyle(color: Colors.grey, fontSize: 13));
                    }
                    return const SizedBox();
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
