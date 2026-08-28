import 'package:flutter/material.dart';

/// Large logo used on auth screens (login / register).
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(Icons.favorite, color: Colors.white, size: size * 0.48),
        ),
        const SizedBox(height: 12),
        Text(
          'LoveOrbit',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: size * 0.38,
            color: scheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// Shared AppBar used across all screens.
/// Shows the LoveOrbit heart logo + app name on the left,
/// and optional [actions] on the right.
class LoveOrbitAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final bool showBack;

  const LoveOrbitAppBar({
    super.key,
    this.actions,
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      automaticallyImplyLeading: showBack,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            'LoveOrbit',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: scheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}
