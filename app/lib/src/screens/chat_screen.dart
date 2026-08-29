import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
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

  // ── Voice recording ───────────────────────────────────────
  final _recorder = AudioRecorder();
  bool _recording = false;
  Timer? _recTimer;
  int _recSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _recorder.dispose();
    super.dispose();
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
    if (SyncService.instance.online) await SyncService.instance.syncNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Photo queued. It will send when online.')),
      );
    }
  }

  // ── Voice recording ───────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_uuid.v4()}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
    setState(() {
      _recording = true;
      _recSeconds = 0;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recSeconds++);
    });
  }

  Future<void> _stopAndSend() async {
    _recTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path == null || !mounted) return;
    await _sendVoiceFile(path);
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    setState(() {
      _recording = false;
      _recSeconds = 0;
    });
  }

  Future<void> _sendVoiceFile(String path) async {
    try {
      final api = ApiService();
      final media = await api.uploadMedia(path);
      final p = context.read<AppProvider>();
      if (p.partner == null || p.user == null) return;
      final m = ChatMessage(
        senderId: p.user!.id,
        receiverId: p.partner!.id,
        mediaId: media.id,
        mediaUrl: media.url,
        mediaContentType: 'audio/mp4',
        status: 'pending',
        createdAt: DateTime.now(),
        clientUid: _uuid.v4(),
      );
      await p.sendVoiceMessage(m);
      if (SyncService.instance.online) await SyncService.instance.syncNow();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send voice note.')),
        );
      }
    }
  }

  String get _recLabel {
    final m = _recSeconds ~/ 60;
    final s = (_recSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
            // ── Message list ───────────────────────────────
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
                                if (m.isVoice && m.mediaUrl != null)
                                  _VoicePlayer(url: m.mediaUrl!)
                                else if (m.isPhoto && m.mediaUrl != null)
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

            // ── Input bar ──────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _recording
                    ? _RecordingBar(
                        label: _recLabel,
                        onSend: _stopAndSend,
                        onCancel: _cancelRecording,
                      )
                    : Row(
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
                              decoration:
                                  const InputDecoration(hintText: 'Message…'),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          // Mic button — tap to start recording
                          IconButton(
                            icon: const Icon(Icons.mic_none),
                            onPressed: _startRecording,
                          ),
                          IconButton(
                              icon: const Icon(Icons.send), onPressed: _send),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ampm = l.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  IconData _statusIcon(String s) => s == 'read'
      ? Icons.done_all
      : (s == 'delivered' ? Icons.done_all : Icons.check);
}

// ── Recording bar ─────────────────────────────────────────────
class _RecordingBar extends StatelessWidget {
  final String label;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _RecordingBar({
    required this.label,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording… $label',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: onCancel,
            tooltip: 'Cancel',
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.red),
            onPressed: onSend,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

// ── Voice message player ──────────────────────────────────────
class _VoicePlayer extends StatefulWidget {
  final String url;
  const _VoicePlayer({required this.url});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _posSub =
        _player.positionStream.listen((p) => setState(() => _position = p));
    _durSub = _player.durationStream
        .listen((d) => setState(() => _duration = d ?? Duration.zero));
    _stateSub = _player.playerStateStream.listen((s) {
      final playing = s.playing;
      final completed = s.processingState == ProcessingState.completed;
      if (completed) {
        _player.seek(Duration.zero);
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      } else {
        setState(() => _playing = playing);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_player.audioSource == null) {
        await _player.setUrl(widget.url);
      }
      await _player.play();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                color: color, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 3,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _duration > Duration.zero
                  ? '${_fmt(_position)} / ${_fmt(_duration)}'
                  : '🎤 Voice note',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}
