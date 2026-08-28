import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../services/local_store.dart';
import '../services/sync_service.dart';
import '../widgets/loveorbit_app_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await context.read<AppProvider>().sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source, imageQuality: 70);
    if (x == null) return;
    final tempDir = await getTemporaryDirectory();
    final target = '${tempDir.path}/${_uuid.v4()}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      x.path,
      target,
      quality: 70,
      minWidth: 1024,
    );
    if (compressed == null) return;
    final clientUid = _uuid.v4();
    await LocalStore.queueMedia(clientUid, compressed.path);
    // The SyncService will upload it automatically when online.
    // Trigger a manual sync attempt in case we are already online.
    if (SyncService.instance.online) {
      await SyncService.instance.syncNow();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Photo queued. It will send when online.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final myId = p.user?.id;
    final msgs = p.messages;
    _scrollToBottom();
    return Scaffold(
      appBar: LoveOrbitAppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                p.partner?.displayName ?? 'Chat',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: msgs.isEmpty
                  ? const Center(child: Text('Say hi to your partner'))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final mine = m.senderId == myId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.15)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (m.isPhoto && m.mediaUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(m.mediaUrl!,
                                          width: 180,
                                          height: 180,
                                          fit: BoxFit.cover),
                                    ),
                                  )
                                else if (m.body != null)
                                  Text(m.body!),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_fmtTime(m.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 10)),
                                    if (mine) ...[
                                      const SizedBox(width: 4),
                                      Icon(_statusIcon(m.status),
                                          size: 12, color: Colors.grey),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.photo_outlined),
                        onPressed: () => _pickPhoto(ImageSource.gallery)),
                    IconButton(
                        icon: const Icon(Icons.camera_alt_outlined),
                        onPressed: () => _pickPhoto(ImageSource.camera)),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Message…'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send), onPressed: _send),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  IconData _statusIcon(String s) => s == 'read'
      ? Icons.done_all
      : (s == 'delivered' ? Icons.done_all : Icons.check);
}
