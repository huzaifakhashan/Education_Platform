import 'package:flutter/material.dart';

import '../models/course.dart';
import '../widgets/app_scope.dart';
import '../widgets/brand.dart';
import 'course_editor_screen.dart';
import 'users_screen.dart';

/// Teachers manage their own courses; admins manage all courses and users.
class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final showUsers = scope.auth.isAdmin && scope.directory != null;
    if (!showUsers) return const _CoursesManager();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(icon: Icon(Icons.library_books_outlined), text: 'الدورات'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'المستخدمون'),
          ]),
          const Expanded(child: TabBarView(children: [_CoursesManager(), UsersView()])),
        ],
      ),
    );
  }
}

class _CoursesManager extends StatelessWidget {
  const _CoursesManager();

  void _add(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CourseEditorScreen()));

  Future<void> _seed(BuildContext context) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await scope.courses.seedSamples(
        instructorId: scope.auth.uid!,
        instructorName: scope.auth.name,
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر استيراد الدورات')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = scope.auth;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('دورة جديدة'),
      ),
      body: ListenableBuilder(
        listenable: scope.courses,
        builder: (context, _) {
          final list = scope.courses.editableBy(auth);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Text(auth.isAdmin ? 'كل الدورات' : 'دوراتي',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  if (!scope.courses.loaded)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'لا توجد دورات بعد. أنشئ دورتك الأولى!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          if (auth.isAdmin && scope.courses.all.isEmpty) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _seed(context),
                              icon: const Icon(Icons.download),
                              label: const Text('استيراد دورات تجريبية'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  for (final c in list) _ManagedCourseTile(course: c),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ManagedCourseTile extends StatelessWidget {
  const _ManagedCourseTile({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: cardColor(context),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: course.gradient),
          ),
          child: Icon(course.icon, color: Colors.white),
        ),
        title: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${course.lessons.length} دروس'
          '${auth.isAdmin ? ' • ${course.instructor}' : ''}',
        ),
        trailing: course.published
            ? Pill(text: 'منشورة', color: Colors.green.shade600)
            : Pill(text: 'مسودة', color: theme.colorScheme.onSurfaceVariant),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CourseEditorScreen(course: course)),
        ),
      ),
    );
  }
}
