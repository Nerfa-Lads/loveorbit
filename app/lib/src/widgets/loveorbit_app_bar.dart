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
        Image.asset(
          'assets/applogo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
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
///
/// - Main tabs (Home, History, Chat, Profile): shows the heart icon centered,
///   no text title.
/// - Sub-screens (Settings, etc.): shows back arrow + [screenTitle] as text.
class LoveOrbitAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;
  final bool showBack;

  /// If provided, shows this as the AppBar title text instead of the logo icon.
  /// Use for sub-screens like "Settings", "Privacy", etc.
  final String? screenTitle;

  const LoveOrbitAppBar({
    super.key,
    this.actions,
    this.showBack = false,
    this.screenTitle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Sub-screen: show back arrow + screen name
    if (screenTitle != null) {
      return AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          screenTitle!,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: actions,
      );
    }

    // Main screen: centered logo icon only
    return AppBar(
      automaticallyImplyLeading: showBack,
      centerTitle: true,
      title: Image.asset(
        'assets/applogo.png',
        width: 34,
        height: 34,
        fit: BoxFit.contain,
      ),
      actions: actions,
    );
  }
}
