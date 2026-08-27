import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ConnectPartnerScreen extends StatefulWidget {
  const ConnectPartnerScreen({super.key});

  @override
  State<ConnectPartnerScreen> createState() => _ConnectPartnerScreenState();
}

class _ConnectPartnerScreenState extends State<ConnectPartnerScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  Future<void> _create() async {
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      final c = await context.read<AppProvider>().createCouple();
      setState(() { _info = 'Your couple code is ${c.code}. Share it with your partner.'; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _join() async {
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await context.read<AppProvider>().joinCouple(_code.text.trim().toUpperCase());
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final pendingCode = p.couple?.code;
    return Scaffold(
      appBar: AppBar(title: const Text('Connect partner')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.link, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Connect with your partner',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Generate a private code and share it, or enter your partner\'s code. Both of you must agree to share locations.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 24),
              if (pendingCode != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Your couple code', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        SelectableText(pendingCode, style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Waiting for your partner to join…', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy code'),
                      onPressed: () => Clipboard.setData(ClipboardData(text: pendingCode)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      onPressed: () => p.refreshCouple(),
                    )),
                  ],
                ),
              ] else ...[
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Generate couple code'),
                  onPressed: _loading ? null : _create,
                ),
              ],
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text('Have a code from your partner?', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                textAlign: TextAlign.center,
                style: const TextStyle(letterSpacing: 4, fontSize: 20, fontWeight: FontWeight.w600),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'ENTER CODE'),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loading ? null : _join, child: const Text('Join couple')),
              if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
              if (_info != null) ...[const SizedBox(height: 12), Text(_info!, style: const TextStyle(color: Colors.green))],
              const SizedBox(height: 24),
              TextButton(onPressed: () => p.logout(), child: const Text('Log out')),
            ],
          ),
        ),
      ),
    );
  }
}
