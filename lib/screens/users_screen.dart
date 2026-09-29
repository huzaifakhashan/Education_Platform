import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/app_scope.dart';
import '../widgets/brand.dart';

/// Admin-only: list users and change their roles.
class UsersView extends StatelessWidget {
  const UsersView({super.key});

  Future<void> _changeRole(BuildContext context, Profile p, UserRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).directory!.setRole(p.uid, role);
      messenger.showSnackBar(SnackBar(content: Text('أصبح ${p.name} ${role.label}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر تغيير الدور')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: StreamBuilder<List<Profile>>(
          stream: scope.directory!.watchProfiles(),
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('تعذّر تحميل المستخدمين'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final users = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('المستخدمون (${users.length})',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('غيّر دور المستخدم لمنحه صلاحية إنشاء الدورات (مدرّس) أو الإدارة الكاملة (مدير).',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                for (final p in users)
                  Card(
                    elevation: 0,
                    color: cardColor(context),
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(p.name.isEmpty ? '?' : p.name.characters.first),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(p.email, textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                      trailing: p.uid == scope.auth.uid
                          ? RoleChip(role: p.role, label: '${p.role.label} (أنت)')
                          : PopupMenuButton<UserRole>(
                              tooltip: 'تغيير الدور',
                              initialValue: p.role,
                              onSelected: (r) => _changeRole(context, p, r),
                              itemBuilder: (_) => [
                                for (final r in UserRole.values)
                                  PopupMenuItem(value: r, child: Text(r.label)),
                              ],
                              child: RoleChip(role: p.role, dropdown: true),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
