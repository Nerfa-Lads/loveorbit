import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'main_shell.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    if (p.user == null) {
      return const _AuthGate();
    }
    return const MainShell();
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    return _showLogin
        ? LoginScreen(onSwitch: () => setState(() => _showLogin = false))
        : RegisterScreen(onSwitch: () => setState(() => _showLogin = true));
  }
}
