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

class LoveOrbitApp extends StatelessWidget {
  final AppProvider provider;
  const LoveOrbitApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
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
