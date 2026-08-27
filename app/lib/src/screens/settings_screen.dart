import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _nameController = TextEditingController(text: p.user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Display name',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'Your name'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await p.updateProfile(name: _nameController.text.trim());
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profile updated')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Theme',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Theme.of(context).brightness == Brightness.dark
                  ? Icons.dark_mode
                  : Icons.light_mode),
              title: const Text('Follow system'),
              subtitle: Text(Theme.of(context).brightness == Brightness.dark
                  ? 'Currently dark'
                  : 'Currently light'),
            ),
            const SizedBox(height: 24),
            Text('Connection',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Couple code'),
              subtitle: Text(p.couple?.code ?? 'Not connected'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Partner'),
              subtitle: Text(p.partner?.displayName ?? 'No partner'),
            ),
            const SizedBox(height: 24),
            Text('About',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('LoveOrbit'),
              subtitle:
                  Text('Version 1.0.0\n"Always connected, wherever we are."'),
            ),
          ],
        ),
      ),
    );
  }
}
