import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/profile.dart';
import '../widgets/app_scope.dart';
import '../widgets/brand.dart';
import 'chat_screen.dart';
import 'course_editor_screen.dart';
import 'lesson_player_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  Future<void> _messageInstructor(BuildContext context, Course course) async {
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final other = Profile(uid: course.instructorId, name: course.instructor, role: UserRole.teacher);
      final chatId = await scope.chat!.openChat(other);
      navigator.push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, other: other)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر فتح المحادثة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final progress = scope.progress;
    final theme = Theme.of(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([progress, scope.courses]),
        builder: (context, _) {
          final course = scope.courses.byId(courseId);
          if (course == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('هذه الدورة لم تعد متاحة')),
            );
          }
          final value = progress.courseProgress(course);
          final canMessage = scope.chat != null &&
              course.instructorId.isNotEmpty &&
              course.instructorId != scope.auth.uid;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                foregroundColor: Colors.white,
                actions: [
                  if (scope.auth.canEditCourse(course))
                    IconButton(
                      tooltip: 'تعديل الدورة',
                      icon: const Icon(Icons.edit),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CourseEditorScreen(course: course)),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(course.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  background: DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: course.gradient)),
                    child: Align(
                      alignment: Alignment.center,
                      child: Icon(course.icon, size: 72, color: Colors.white24),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.description, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 10),
                          Row(children: [
                            Icon(Icons.person, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(child: Text(course.instructor, style: theme.textTheme.bodyMedium)),
                            if (canMessage)
                              OutlinedButton.icon(
                                onPressed: () => _messageInstructor(context, course),
                                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                label: const Text('راسل المدرّس'),
                              ),
                          ]),
                          const SizedBox(height: 16),
                          ProgressBar(value: value, color: course.gradient.first),
                          const SizedBox(height: 6),
                          Text('${progress.completedIn(course)} من ${course.lessons.length} دروس مكتملة',
                              style: theme.textTheme.labelMedium),
                          const SizedBox(height: 20),
                          Text('محتوى الدورة',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (course.lessons.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('لم تُضف دروس لهذه الدورة بعد.'),
                            ),
                          for (var i = 0; i < course.lessons.length; i++)
                            _LessonTile(course: course, index: i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.course, required this.index});

  final Course course;
  final int index;

  @override
  Widget build(BuildContext context) {
    final lesson = course.lessons[index];
    final done = AppScope.of(context).progress.isDone(lesson.id);
    return Card(
      elevation: 0,
      color: cardColor(context),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          backgroundColor: done ? Colors.green.shade50 : course.gradient.first.withValues(alpha: 0.12),
          child: done
              ? const Icon(Icons.check, color: Colors.green)
              : Text('${index + 1}', style: TextStyle(color: course.gradient.first, fontWeight: FontWeight.w700)),
        ),
        title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${lesson.minutes} دقيقة'),
        trailing: Icon(Icons.play_circle_fill_rounded, color: course.gradient.first, size: 30),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LessonPlayerScreen(course: course, index: index)),
        ),
      ),
    );
  }
}
