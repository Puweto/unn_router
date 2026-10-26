import 'package:flutter/material.dart';
import '../api.dart';

class DirectorLoginScreen extends StatefulWidget {
  const DirectorLoginScreen({super.key});
  @override
  State<DirectorLoginScreen> createState() => _DirectorLoginScreenState();
}

class _DirectorLoginScreenState extends State<DirectorLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.directorLogin(_user.text.trim(), _pass.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst); // root now shows the director panel
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Director of Transport')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Administrator sign in', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(controller: _user, decoration: const InputDecoration(labelText: 'Username'), autofillHints: const [AutofillHints.username]),
                  const SizedBox(height: 12),
                  TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true, autofillHints: const [AutofillHints.password]),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _busy ? null : _login, child: const Text('Sign in')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
