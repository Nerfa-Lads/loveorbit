import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/loveorbit_app_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final active = p.sharing && !p.paused;
    return Scaffold(
      appBar: const LoveOrbitAppBar(screenTitle: 'Privacy'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sharing status banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: active
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(active ? Icons.location_on : Icons.location_off,
                      color: active ? Colors.green : Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? 'Location sharing is ON'
                              : 'Location sharing is OFF',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          active
                              ? 'Your partner can see your current location.'
                              : 'Your partner cannot see your location right now.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sharing toggle
            SwitchListTile(
              secondary: const Icon(Icons.share_location),
              title: const Text('Location sharing'),
              subtitle: const Text('Allow your partner to see your location'),
              value: p.sharing,
              onChanged: (v) => p.setSharing(on: v),
            ),
            // Pause toggle
            if (p.sharing)
              SwitchListTile(
                secondary: const Icon(Icons.pause_circle_outline),
                title: const Text('Pause sharing'),
                subtitle:
                    const Text('Temporarily stop sharing without turning off'),
                value: p.paused,
                onChanged: (v) => p.setSharing(on: true, pause: v),
              ),
            const Divider(),
            // Delete location history
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: const Text('Delete location history'),
              subtitle: const Text('Remove all your saved locations'),
              onTap: () => _confirmDeleteHistory(context),
            ),
            // Disconnect partner
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.deepOrange),
              title: const Text('Disconnect partner'),
              subtitle: const Text('End the couple connection'),
              onTap: () => _confirmDisconnect(context, p),
            ),
            const Divider(),
            // Delete account
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete account',
                  style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently remove your account and data'),
              onTap: () => _confirmDeleteAccount(context, p),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'LoveOrbit never tracks you secretly. Both partners must agree before '
                'sharing locations, and you can stop at any time.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all history?'),
        content: const Text(
            'This will permanently delete all your recorded locations. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<AppProvider>().deleteMyHistory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location history deleted')),
                  );
                }
              } catch (_) {}
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, AppProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect partner?'),
        content: const Text(
            'You will stop sharing locations and chat with your partner. '
            'You can reconnect later with a new couple code.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await p.disconnect();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AppProvider p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This permanently deletes your account, locations, messages, '
            'and photos. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await p.deleteAccount();
            },
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
  }
}
