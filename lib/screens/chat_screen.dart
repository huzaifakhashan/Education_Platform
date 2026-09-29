import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/profile.dart';
import '../widgets/app_scope.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, required this.other});

  final String chatId;
  final Profile other;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _markRead();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _markRead() {
    AppScope.of(context).chat!.markRead(widget.chatId).catchError((_) {});
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await AppScope.of(context).chat!.send(widget.chatId, widget.other.uid, text);
    } catch (_) {
      if (mounted) {
        _input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر إرسال الرسالة')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final me = scope.auth.uid!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.other.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: scope.chat!.watchMessages(widget.chatId),
                  builder: (context, snap) {
                    if (snap.hasError) return const Center(child: Text('تعذّر تحميل الرسائل'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snap.data!;
                    // Anything that arrives while the chat is open counts as read.
                    if (messages.isNotEmpty && messages.last.senderId != me) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _markRead();
                      });
                    }
                    if (messages.isEmpty) {
                      return Center(
                        child: Text('ابدأ المحادثة مع ${widget.other.name}',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[messages.length - 1 - i];
                        return _Bubble(message: m, mine: m.senderId == me);
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالتك...',
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = message.createdAt;
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text,
                style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(
                    fontSize: 10,
                    color: (mine ? scheme.onPrimary : scheme.onSurface).withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}
