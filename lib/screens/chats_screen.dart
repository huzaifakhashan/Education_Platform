import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/profile.dart';
import '../widgets/app_scope.dart';
import '../widgets/brand.dart';
import 'chat_screen.dart';

/// Inbox: my conversations, plus a button to start a new one.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final me = scope.auth.uid!;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newChat(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('محادثة جديدة'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: StreamBuilder<List<ChatSummary>>(
            stream: scope.chat!.watchChats(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('تعذّر تحميل المحادثات'));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final chats = snap.data!.where((c) => c.lastMessage.isNotEmpty).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Text('الرسائل',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  if (chats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'لا توجد محادثات بعد.\nابدأ محادثة جديدة مع مدرّسك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final c in chats) _ChatTile(chat: c, me: me),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _newChat(BuildContext context) async {
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final picked = await navigator.push<Profile>(
      MaterialPageRoute(builder: (_) => const _ContactPicker()),
    );
    if (picked == null) return;
    final chatId = await scope.chat!.openChat(picked);
    navigator.push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, other: picked)));
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.me});
  final ChatSummary chat;
  final String me;

  @override
  Widget build(BuildContext context) {
    final name = chat.otherName(me);
    final unread = chat.isUnread(me);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: cardColor(context),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(name.characters.first),
        ),
        title: Text(name, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
        subtitle: Text(
          '${chat.lastSenderId == me ? 'أنت: ' : ''}${chat.lastMessage}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.normal),
        ),
        trailing: unread
            ? CircleAvatar(radius: 6, backgroundColor: theme.colorScheme.primary)
            : null,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            other: Profile(uid: chat.otherId(me), name: name, role: UserRole.student),
          ),
        )),
      ),
    );
  }
}

/// Choose who to message. Students can only reach staff; staff can reach anyone.
class _ContactPicker extends StatelessWidget {
  const _ContactPicker();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = scope.auth;
    return Scaffold(
      appBar: AppBar(title: const Text('اختر جهة الاتصال')),
      body: StreamBuilder<List<Profile>>(
        stream: scope.directory!.watchProfiles(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('تعذّر تحميل القائمة'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final people = snap.data!
              .where((p) => p.uid != auth.uid && (auth.isStaff || p.role.isStaff))
              .toList();
          if (people.isEmpty) {
            return const Center(child: Text('لا يوجد أحد لمراسلته حالياً'));
          }
          return ListView(
            children: [
              for (final p in people)
                ListTile(
                  leading: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name.characters.first)),
                  title: Text(p.name),
                  trailing: _RoleBadge(role: p.role),
                  onTap: () => Navigator.of(context).pop(p),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) => Text(role.label,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12));
}
