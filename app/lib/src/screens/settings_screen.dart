import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _nameController = TextEditingController(text: p.user?.displayName ?? '');
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
      setState(() => _editingName = false);
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

    if (p.user == null) {
      return const Scaffold(
        appBar: LoveOrbitAppBar(screenTitle: 'Settings'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = p.user!;
    if (_nameController.text.isEmpty && user.displayName.isNotEmpty) {
      _nameController.text = user.displayName;
    }

    return Scaffold(
      appBar: const LoveOrbitAppBar(screenTitle: 'Settings'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // ═══════════════════════════════════════════════
            // PROFILE HERO CARD
            // ═══════════════════════════════════════════════
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      p.pinBorderColor.withValues(alpha: 0.18),
                      scheme.primaryContainer.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Avatar ───────────────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring — pin color
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.pinBorderColor,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: p.pinBorderColor.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: AvatarImage(url: user.avatarUrl, radius: 44),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Name ─────────────────────────────────
                    _editingName
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  autofocus: true,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onSubmitted: (_) => _save(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.check_circle,
                                          color: Colors.green, size: 28),
                                      onPressed: _save,
                                    ),
                              IconButton(
                                icon: Icon(Icons.cancel_outlined,
                                    color: Colors.grey.shade400, size: 26),
                                onPressed: () {
                                  setState(() {
                                    _editingName = false;
                                    _nameController.text = user.displayName;
                                  });
                                },
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 22),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _editingName = true),
                                child: Icon(Icons.edit_outlined,
                                    size: 18, color: Colors.grey.shade500),
                              ),
                            ],
                          ),

                    const SizedBox(height: 4),

                    Text(
                      '@${user.username}',
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 16),

                    // ── Info chips row ────────────────────────
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Pin color chip
                        _InfoChip(
                          icon: Icons.circle,
                          iconColor: p.pinBorderColor,
                          label: 'Pin color',
                        ),
                        // Couple code chip
                        if (p.couple?.code != null)
                          _InfoChip(
                            icon: Icons.link,
                            iconColor: scheme.primary,
                            label: p.couple!.code,
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: p.couple!.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Couple code copied!')),
                              );
                            },
                            trailing: const Icon(Icons.copy,
                                size: 12, color: Colors.grey),
                          ),
                        // Partner chip
                        if (p.partner != null)
                          _InfoChip(
                            icon: Icons.favorite,
                            iconColor: scheme.primary,
                            label: p.partner!.displayName,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ═══════════════════════════════════════════════
            // MAP PIN COLOR
            // ═══════════════════════════════════════════════
            const _SectionHeader('Map pin color'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live pin preview + description
                    Row(
                      children: [
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
                                'Your map pin',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This ring appears around your avatar on the map. Your partner sees it too.',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Color grid — larger swatches
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: kPinBorderColors.map((color) {
                        final selected =
                            p.pinBorderColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => p.setPinBorderColor(color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: selected ? 46 : 40,
                            height: selected ? 46 : 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                // white ring inside when selected
                                color: selected
                                    ? Colors.white
                                    : color.withValues(alpha: 0.0),
                                width: selected ? 3 : 0,
                                strokeAlign: BorderSide.strokeAlignInside,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                      alpha: selected ? 0.65 : 0.25),
                                  blurRadius: selected ? 14 : 4,
                                  spreadRadius: selected ? 2 : 0,
                                ),
                              ],
                            ),
                            child: selected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ═══════════════════════════════════════════════
            // PARTNER & CONNECTION
            // ═══════════════════════════════════════════════
            const _SectionHeader('Partner & Connection'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.link, color: scheme.primary, size: 18),
                    ),
                    title: const Text('Couple code',
                        style: TextStyle(fontWeight: FontWeight.w600)),
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
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      child:
                          Icon(Icons.favorite, color: scheme.primary, size: 18),
                    ),
                    title: const Text('Partner',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle:
                        Text(p.partner?.displayName ?? 'No partner connected'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ═══════════════════════════════════════════════
            // MAP STYLE
            // ═══════════════════════════════════════════════
            const _SectionHeader('Map style'),
            const SizedBox(height: 10),
            _MapStylePicker(current: p.mapStyle, onChanged: p.setMapStyle),

            const SizedBox(height: 28),

            // ═══════════════════════════════════════════════
            // APPEARANCE
            // ═══════════════════════════════════════════════
            const _SectionHeader('Appearance'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: const ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0x1A888888),
                  child:
                      Icon(Icons.brightness_auto, size: 18, color: Colors.grey),
                ),
                title: Text('Theme',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Follows your system setting'),
                trailing: Text('System',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),

            const SizedBox(height: 28),

            // ═══════════════════════════════════════════════
            // ABOUT
            // ═══════════════════════════════════════════════
            const _SectionHeader('About'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/applogo.png',
                      width: 36, height: 36, fit: BoxFit.cover),
                ),
                title: const Text('LoveOrbit',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Version 1.0.0\n"Always connected, wherever we are."'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 4),
            color: borderColor.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(child: AvatarImage(url: avatarUrl, radius: 24)),
        ),
        CustomPaint(
          size: const Size(14, 7),
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
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ── Section header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ── Map style picker ──────────────────────────────────────────
class _MapStylePicker extends StatelessWidget {
  final String current;
  final Future<void> Function(String) onChanged;

  const _MapStylePicker({required this.current, required this.onChanged});

  static const _styles = [
    (
      id: 'satellite',
      label: 'Satellite',
      icon: Icons.satellite_alt,
      tileUrl:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      labelUrl:
          'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    ),
    (
      id: 'classic',
      label: 'Classic',
      icon: Icons.map_outlined,
      tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      labelUrl: '',
    ),
  ];

  // Manila as neutral preview center
  static const _previewCenter = LatLng(14.5995, 120.9842);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: _styles.map((style) {
        final selected = current == style.id;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: style.id == 'satellite' ? 8 : 0,
              left: style.id == 'classic' ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(style.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    children: [
                      // ── Mini map preview ───────────────
                      SizedBox(
                        height: 110,
                        child: IgnorePointer(
                          child: FlutterMap(
                            options: const MapOptions(
                              initialCenter: _previewCenter,
                              initialZoom: 13,
                              interactionOptions: InteractionOptions(
                                  flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: style.tileUrl,
                                tileProvider: NetworkTileProvider(
                                  headers: {
                                    'User-Agent':
                                        'LoveOrbit/1.0 (contact: loveorbit.app)',
                                  },
                                ),
                              ),
                              if (style.labelUrl.isNotEmpty)
                                TileLayer(
                                  urlTemplate: style.labelUrl,
                                  tileProvider: NetworkTileProvider(
                                    headers: {
                                      'User-Agent':
                                          'LoveOrbit/1.0 (contact: loveorbit.app)',
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // ── Label bar at bottom ────────────
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary
                                : Colors.black.withValues(alpha: 0.55),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(style.icon, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                style.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 5),
                                const Icon(Icons.check_circle,
                                    size: 13, color: Colors.white),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
