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
  bool _saving = false;

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

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await p.updateProfile(name: _nameController.text.trim());
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save. Try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Account ──────────────────────────────────────
            _SectionHeader('Account'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: p.user?.avatarUrl != null
                          ? NetworkImage(p.user!.avatarUrl!)
                          : null,
                      child: p.user?.avatarUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.user?.displayName ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text('@${p.user?.username ?? ''}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text('Display name',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            hintText: 'Your display name'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save'),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Theme ─────────────────────────────────────────
            _SectionHeader('Appearance'),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: scheme.primary,
                ),
                title: const Text('Theme'),
                subtitle: Text(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'Dark mode'
                      : 'Light mode',
                ),
                trailing: Text('System',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ),
            ),

            const SizedBox(height: 24),

            // ── Partner ───────────────────────────────────────
            _SectionHeader('Partner & Connection'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.link, color: scheme.primary),
                    title: const Text('Couple code'),
                    subtitle: Text(p.couple?.code ?? 'Not connected yet'),
                    trailing: p.couple?.code != null
                        ? IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              // copy to clipboard handled separately
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied!')),
                              );
                            },
                          )
                        : null,
                  ),
                  ListTile(
                    leading: Icon(Icons.favorite, color: scheme.primary),
                    title: const Text('Partner'),
                    subtitle:
                        Text(p.partner?.displayName ?? 'No partner connected'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── About ─────────────────────────────────────────
            _SectionHeader('About'),
            const SizedBox(height: 8),
            Card(
              child: const ListTile(
                leading: Icon(Icons.favorite, color: Color(0xFFE26D8C)),
                title: Text('LoveOrbit'),
                subtitle:
                    Text('Version 1.0.0\n"Always connected, wherever we are."'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
