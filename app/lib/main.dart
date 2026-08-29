import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/providers/app_provider.dart';
import 'src/services/notification_service.dart';
import 'src/theme/app_theme.dart';
import 'src/screens/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final provider = AppProvider();
  await provider.bootstrap();
  runApp(LoveOrbitApp(provider: provider));
}

class LoveOrbitApp extends StatefulWidget {
  final AppProvider provider;
  const LoveOrbitApp({super.key, required this.provider});

  @override
  State<LoveOrbitApp> createState() => _LoveOrbitAppState();
}

class _LoveOrbitAppState extends State<LoveOrbitApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    widget.provider.setPhoneActive(active);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.provider,
      child: Consumer<AppProvider>(
        builder: (context, p, _) {
          return MaterialApp(
            title: 'LoveOrbit',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}
