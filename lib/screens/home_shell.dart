import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/course.dart';
import '../widgets/app_scope.dart';
import '../widgets/brand.dart';
import 'chats_screen.dart';
import 'course_detail_screen.dart';
import 'manage_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  final bool isChat;
  const _Tab(this.label, this.icon, this.selectedIcon, this.page, {this.isChat = false});
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Tab> _tabs(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = scope.auth;
    return [
      const _Tab('الدورات', Icons.school_outlined, Icons.school, _CoursesTab()),
      const _Tab('تقدّمي', Icons.insights_outlined, Icons.insights, _ProgressTab()),
      if (auth.isStaff)
        _Tab(auth.isAdmin ? 'الإدارة' : 'دوراتي', Icons.dashboard_customize_outlined,
            Icons.dashboard_customize, const ManageScreen()),
      if (scope.chat != null)
        const _Tab('الرسائل', Icons.chat_bubble_outline, Icons.chat_bubble, ChatsScreen(), isChat: true),
      const _Tab('حسابي', Icons.person_outline, Icons.person, _ProfileTab()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    // Rebuild when the role changes (e.g. an admin promotes this user).
    return ListenableBuilder(
      listenable: scope.auth,
      builder: (context, _) {
        final tabs = _tabs(context);
        final index = _index.clamp(0, tabs.length - 1);
        return Scaffold(
          body: SafeArea(child: tabs[index].page),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: t.isChat ? _ChatBadge(icon: t.icon) : Icon(t.icon),
                  selectedIcon: t.isChat ? _ChatBadge(icon: t.selectedIcon) : Icon(t.selectedIcon),
                  label: t.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Chat icon with a dot when there are unread conversations.
class _ChatBadge extends StatelessWidget {
  const _ChatBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final me = scope.auth.uid!;
    return StreamBuilder<List<ChatSummary>>(
      stream: scope.chat!.watchChats(),
      builder: (context, snap) {
        final unread = (snap.data ?? const []).where((c) => c.isUnread(me)).length;
        return Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: Icon(icon),
        );
      },
    );
  }
}

void _openCourse(BuildContext context, Course c) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: c.id)));

class _CoursesTab extends StatelessWidget {
  const _CoursesTab();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.progress, scope.courses]),
      builder: (context, _) {
        final resume = scope.progress.continueCourse;
        final list = scope.courses.published;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const AppLogo(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أهلاً ${scope.auth.name} 👋',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          Text('ماذا ستتعلّم اليوم؟',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (resume != null) ...[
                  const SizedBox(height: 20),
                  _ContinueCard(course: resume),
                ],
                const SizedBox(height: 24),
                Text('كل الدورات',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (!scope.courses.loaded)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      scope.auth.isStaff
                          ? 'لا توجد دورات منشورة بعد. أضف دورة من تبويب الإدارة.'
                          : 'لا توجد دورات منشورة حالياً. عُد قريباً!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                for (final c in list) ...[
                  _CourseCard(course: c),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openCourse(context, course),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: course.gradient),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تابع من حيث توقفت',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(course.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 12),
                  ProgressBar(value: progress.courseProgress(course), color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.play_arrow_rounded, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final progress = AppScope.of(context).progress;
    final theme = Theme.of(context);
    final value = progress.courseProgress(course);
    return Material(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCourse(context, course),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: course.gradient),
                ),
                child: Icon(course.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${course.lessons.length} دروس • ${course.totalMinutes} دقيقة',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: ProgressBar(value: value, color: course.gradient.first, height: 6)),
                        const SizedBox(width: 8),
                        Text('${(value * 100).round()}%', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final progress = scope.progress;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([progress, scope.courses]),
      builder: (context, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('تقدّمي', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress.overallProgress,
                            strokeWidth: 14,
                            strokeCap: StrokeCap.round,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        Text('${(progress.overallProgress * 100).round()}%',
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _Stat(icon: Icons.check_circle, label: 'دروس مكتملة', value: '${progress.totalCompleted}/${progress.totalLessons}', color: Colors.green),
                    const SizedBox(width: 12),
                    _Stat(icon: Icons.emoji_events, label: 'دورات منتهية', value: '${progress.completedCourses}', color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    _Stat(icon: Icons.timer, label: 'دقائق تعلّم', value: '${progress.minutesLearned}', color: Colors.indigo),
                  ],
                ),
                const SizedBox(height: 24),
                Text('تقدّم الدورات', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final c in scope.courses.published)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      onTap: () => _openCourse(context, c),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(c.title, style: theme.textTheme.bodyMedium)),
                              Text('${progress.completedIn(c)}/${c.lessons.length}',
                                  style: theme.textTheme.labelMedium),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ProgressBar(value: progress.courseProgress(c), color: c.gradient.first),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = scope.auth;
    final themeController = scope.theme;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  auth.name.isEmpty ? '?' : auth.name.characters.first,
                  style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(auth.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(auth.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              RoleChip(role: auth.role),
              const SizedBox(height: 28),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('المظهر', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: themeController,
                builder: (_, _) => SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('تلقائي')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('فاتح')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('داكن')),
                  ],
                  selected: {themeController.mode},
                  onSelectionChanged: (s) => themeController.setMode(s.first),
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
