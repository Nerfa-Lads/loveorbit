import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onSwitch;
  const RegisterScreen({super.key, required this.onSwitch});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  String _friendlyError(Object e) {
    if (e is ApiException) {
      switch (e.message) {
        case 'username already taken':
          return 'That username is already taken. Please choose another one.';
        case 'username too short':
          return 'Username must be at least 3 characters.';
        case 'username invalid characters':
          return 'Username can only contain letters, numbers, dots and underscores.';
        case 'username, password and display_name are required':
          return 'Please fill in all fields.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup')) {
      return 'Can\'t reach the server. Check your internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _submit() async {
    final name = _displayName.text.trim();
    final username = _username.text.trim();
    final pass = _pass.text;

    if (name.isEmpty || username.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(username)) {
      setState(() => _error =
          'Username can only contain letters, numbers, dots and underscores.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().register(username, pass, name);
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.favorite, size: 64, color: scheme.primary),
              const SizedBox(height: 12),
              Text('Create your account',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Join LoveOrbit and connect with your partner',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _displayName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'How your partner sees you',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Letters, numbers, . and _',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 6 characters',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create account'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: widget.onSwitch,
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
