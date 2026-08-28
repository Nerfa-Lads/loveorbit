import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/avatar_image.dart';
import '../widgets/loveorbit_app_bar.dart';

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
    // Refresh user in case it loaded after this screen was built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (p.user == null) p.bootstrap();
    });
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

    // Guard — if user data hasn't loaded yet, show a loader
    if (p.user == null) {
      return const Scaffold(
        appBar: LoveOrbitAppBar(screenTitle: 'Settings'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = p.user!;

    // Sync the name controller if it's still empty after user loaded
    if (_nameController.text.isEmpty && user.displayName.isNotEmpty) {
      _nameController.text = user.displayName;
    }

    return Scaffold(
      appBar: const LoveOrbitAppBar(screenTitle: 'Settings'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── User Info ─────────────────────────────────────
            const _SectionHeader('Your Profile'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + name row
                    Row(
                      children: [
                        // Avatar with pin border color preview
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: p.pinBorderColor,
                                  width: 3,
                                ),
                              ),
                              child:
                                  AvatarImage(url: user.avatarUrl, radius: 30),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: p.pinBorderColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Pin color',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    // User info details
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Display name',
                      value: user.displayName,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.alternate_email,
                      label: 'Username',
                      value: '@${user.username}',
                    ),
                    if (p.couple?.code != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.link,
                        label: 'Couple code',
                        value: p.couple!.code,
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: p.couple!.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Couple code copied!')),
                          );
                        },
                        trailing: const Icon(Icons.copy,
                            size: 16, color: Colors.grey),
                      ),
                    ],
                    if (p.partner != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.favorite,
                        label: 'Partner',
                        value: p.partner!.displayName,
                        iconColor: scheme.primary,
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Edit display name
                    Text('Edit display name',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Map Pin Border Color ───────────────────────────
            const _SectionHeader('Map Pin'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Mini pin preview
                        _PinPreview(
                          avatarUrl: user.avatarUrl,
                          borderColor: p.pinBorderColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Border color',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose the border color of your map pin',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: kPinBorderColors.map((color) {
                        final selected =
                            p.pinBorderColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => p.setPinBorderColor(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: selected ? 38 : 34,
                            height: selected ? 38 : 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.55),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Appearance ────────────────────────────────────
            const _SectionHeader('Appearance'),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.brightness_auto),
                title: Text('Theme'),
                subtitle: Text('Follows your system setting'),
                trailing: Text('System',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),

            const SizedBox(height: 24),

            // ── Partner ───────────────────────────────────────
            const _SectionHeader('Partner & Connection'),
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
                              Clipboard.setData(
                                  ClipboardData(text: p.couple!.code));
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
            const _SectionHeader('About'),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
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

// ── Mini pin preview ──────────────────────────────────────────
class _PinPreview extends StatelessWidget {
  final String? avatarUrl;
  final Color borderColor;

  const _PinPreview({this.avatarUrl, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 3),
            color: borderColor.withValues(alpha: 0.12),
          ),
          child: Center(
            child: AvatarImage(url: avatarUrl, radius: 22),
          ),
        ),
        CustomPaint(
          size: const Size(12, 6),
          painter: _TrianglePainter(color: borderColor),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ── Info row ──────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade600),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
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
