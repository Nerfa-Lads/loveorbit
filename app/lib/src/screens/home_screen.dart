import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'splash_screen.dart' show OrbitMap;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshPartnerLatest();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final partner = p.partner;
    final pt = p.partnerLatest;
    final points =
        pt == null ? <LatLng>[] : [LatLng(pt.latitude, pt.longitude)];

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              p.refreshPartnerLatest();
              p.refreshCouple();
            }),
      ]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (partner == null)
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No partner connected.')))
            else ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: partner.avatarUrl != null
                        ? NetworkImage(partner.avatarUrl!)
                        : null,
                    child: partner.avatarUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(partner.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.circle,
                              size: 10,
                              color: p.online ? Colors.green : Colors.grey),
                          const SizedBox(width: 6),
                          Text(p.online ? 'Online' : 'Offline',
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SharingCard(),
              const SizedBox(height: 16),
              if (pt == null)
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No location shared yet.')))
              else ...[
                OrbitMap(points: points, height: 240),
                const SizedBox(height: 12),
                Text('Last updated ${_timeAgo(pt.recordedAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _SharingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final active = p.sharing && !p.paused;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(active ? Icons.location_on : Icons.location_off,
                  color: active ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text('Location sharing',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value: p.sharing,
                onChanged: (v) => p.setSharing(on: v),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'Sharing is ON — your partner can see your location.'
                  : (p.paused
                      ? 'Paused — sharing is temporarily off.'
                      : 'Sharing is OFF.'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            if (p.sharing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  icon: Icon(p.paused ? Icons.play_arrow : Icons.pause),
                  label: Text(p.paused ? 'Resume' : 'Pause'),
                  onPressed: () => p.setSharing(on: true, pause: !p.paused),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
