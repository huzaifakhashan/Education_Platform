import 'package:flutter/material.dart';

import '../models/course.dart';
import '../widgets/app_scope.dart';

/// Create or edit a course and its lessons (teachers: own courses; admins: any).
class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({super.key, this.course});

  /// Null when creating a new course.
  final Course? course;

  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _iconKey;
  late int _gradient;
  late bool _published;
  late List<Lesson> _lessons;
  String? _id;
  bool _saving = false;

  bool get _isNew => widget.course == null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _title = TextEditingController(text: c?.title ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    _iconKey = c?.iconKey ?? 'book';
    _gradient = c?.gradientIndex ?? 0;
    _published = c?.published ?? false;
    _lessons = [...?c?.lessons];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final existing = widget.course;
    final id = existing?.id ?? (_id ??= scope.courses.newId());
    final course = Course(
      id: id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      instructor: existing?.instructor ?? scope.auth.name,
      instructorId: existing?.instructorId ?? scope.auth.uid ?? '',
      iconKey: _iconKey,
      gradientIndex: _gradient,
      published: _published,
      createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      lessons: _lessons,
    );
    setState(() => _saving = true);
    try {
      await scope.courses.save(course);
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر حفظ الدورة. تحقق من صلاحياتك والاتصال.')));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الدورة'),
        content: Text('سيتم حذف "${widget.course!.title}" نهائياً. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await scope.courses.delete(widget.course!.id);
      // Leave both the editor and the (now missing) course screen if open.
      navigator.popUntil((r) => r.isFirst);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر حذف الدورة')));
    }
  }

  Future<void> _editLesson([int? index]) async {
    final result = await showDialog<Lesson>(
      context: context,
      builder: (_) => _LessonDialog(
        lesson: index == null ? null : _lessons[index],
        newId: '${_id ??= widget.course?.id ?? AppScope.of(context).courses.newId()}-'
            '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      ),
    );
    if (result == null) return;
    setState(() => index == null ? _lessons.add(result) : _lessons[index] = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'دورة جديدة' : 'تعديل الدورة'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'حذف الدورة',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'عنوان الدورة'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'أدخل عنواناً (3 أحرف على الأقل)' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'وصف الدورة'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل وصفاً' : null,
                ),
                const SizedBox(height: 20),
                Text('الأيقونة', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in courseIcons.entries)
                      ChoiceChip(
                        label: Icon(e.value, size: 22),
                        selected: _iconKey == e.key,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _iconKey = e.key),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('اللون', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < courseGradients.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _gradient = i),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: courseGradients[i]),
                            border: Border.all(
                              color: _gradient == i ? theme.colorScheme.onSurface : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشر الدورة للطلاب'),
                  subtitle: Text(_published ? 'ظاهرة لجميع الطلاب' : 'مسودة: لا تظهر للطلاب'),
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text('الدروس (${_lessons.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => _editLesson(),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة درس'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lessons.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('لا توجد دروس بعد.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lessons.length,
                  onReorderItem: (from, to) =>
                      setState(() => _lessons.insert(to, _lessons.removeAt(from))),
                  itemBuilder: (_, i) {
                    final l = _lessons[i];
                    return Card(
                      key: ValueKey(l.id),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(l.title),
                        subtitle: Text('${l.minutes} دقيقة'),
                        onTap: () => _editLesson(i),
                        trailing: IconButton(
                          tooltip: 'حذف الدرس',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _lessons.removeAt(i)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('حفظ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonDialog extends StatefulWidget {
  const _LessonDialog({this.lesson, required this.newId});

  final Lesson? lesson;
  final String newId;

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.lesson?.title);
  late final _description = TextEditingController(text: widget.lesson?.description);
  late final _url = TextEditingController(text: widget.lesson?.videoUrl);
  late final _minutes = TextEditingController(text: '${widget.lesson?.minutes ?? 10}');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(Lesson(
      id: widget.lesson?.id ?? widget.newId,
      title: _title.text.trim(),
      description: _description.text.trim(),
      videoUrl: _url.text.trim(),
      minutes: int.parse(_minutes.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lesson == null ? 'درس جديد' : 'تعديل الدرس'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'عنوان الدرس'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل عنواناً' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'وصف الدرس'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _url,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'رابط الفيديو',
                    helperText: 'رابط مباشر لملف mp4 (يبدأ بـ https://)',
                  ),
                  validator: (v) {
                    final uri = Uri.tryParse((v ?? '').trim());
                    final ok = uri != null && uri.hasAuthority && (uri.scheme == 'https' || uri.scheme == 'http');
                    return ok ? null : 'أدخل رابطاً صالحاً';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المدة بالدقائق'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n <= 0 || n > 600) ? 'أدخل رقماً بين 1 و 600' : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: _submit,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
