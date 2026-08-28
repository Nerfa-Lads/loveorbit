import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/avatar_image.dart';
import '../widgets/loveorbit_app_bar.dart';
import 'connect_partner_screen.dart';
import 'settings_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await picker.pickImage(source: source);
    if (picked == null) return;
    if (!mounted) return;

    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _uploadingAvatar = true);
    try {
      // ── Step 1: crop (1:1 square) ─────────────────────────
      final scheme = Theme.of(context).colorScheme;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: scheme.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: scheme.primary,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      // User cancelled the cropper
      if (cropped == null) {
        setState(() => _uploadingAvatar = false);
        return;
      }

      // ── Step 2: compress to ≤ 400 KB ────────────────────────
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        cropped.path,
        targetPath,
        minWidth: 512,
        minHeight: 512,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      final uploadPath = compressed?.path ?? cropped.path;

      if (!File(uploadPath).existsSync()) {
        throw Exception('Compressed file not found. Please try again.');
      }

      // ── Step 3: upload ───────────────────────────────────────
      await provider.uploadAvatar(uploadPath);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile picture updated! ✓')),
      );

      // Clean up temp files
      try {
        File(uploadPath).deleteSync();
        File(cropped.path).deleteSync();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final user = p.user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const LoveOrbitAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Avatar ───────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: _uploadingAvatar
                        ? const CircleAvatar(
                            radius: 56,
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          )
                        : AvatarImage(url: user?.avatarUrl, radius: 56),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.primary,
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user?.displayName ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Center(
              child: Text(
                '@${user?.username ?? ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // ── Partner card ──────────────────────────────────
            if (!p.isConnected)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.favorite_border, color: scheme.primary),
                  ),
                  title: const Text('Connect with your partner'),
                  subtitle: const Text('Generate a code or enter theirs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConnectPartnerScreen()),
                  ),
                ),
              ),
            if (p.isConnected)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.favorite, color: scheme.primary),
                  ),
                  title: Text(p.partner?.displayName ?? 'Partner'),
                  subtitle: const Text('Connected ❤️'),
                ),
              ),

            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log out', style: TextStyle(color: Colors.red)),
              onTap: () => p.logout(),
            ),
          ],
        ),
      ),
    );
  }
}
