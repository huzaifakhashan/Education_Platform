import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import 'auth_service.dart';
import 'course_repository.dart';
import 'progress_sync.dart';

/// Tracks completed lessons and the last visited lesson per user.
/// Always cached locally; optionally mirrored to the cloud via [ProgressSync].
class ProgressService extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  ProgressService(this._prefs, this._auth, this._courses, {ProgressSync? sync}) : _sync = sync {
    _auth.addListener(_load);
    _courses.addListener(notifyListeners);
    _load();
  }

  final SharedPreferences _prefs;
  final AuthService _auth;
  final CourseRepository _courses;
  final ProgressSync? _sync;
  Set<String> _done = {};
  String? _lastLessonId;
  String? _loadedFor;

  String get _doneKey => 'done_${_auth.email}';
  String get _lastKey => 'last_${_auth.email}';

  void _load() {
    final email = _auth.email;
    // Auth notifies for name changes too; only reload when the user changes.
    if (email == _loadedFor) return;
    _loadedFor = email;
    if (email == null) {
      _done = {};
      _lastLessonId = null;
    } else {
      _done = (_prefs.getStringList(_doneKey) ?? []).toSet();
      _lastLessonId = _prefs.getString(_lastKey);
      _pull(email);
    }
    notifyListeners();
  }

  /// Cloud data wins when present; otherwise local progress is uploaded.
  Future<void> _pull(String email) async {
    if (_sync == null) return;
    try {
      final remote = await _sync.fetch();
      if (_auth.email != email) return; // user changed while fetching
      if (remote == null) {
        await _sync.push(_done, _lastLessonId);
        return;
      }
      _done = {...remote.done};
      _lastLessonId = remote.lastLessonId;
      await _persistLocal();
      notifyListeners();
    } catch (e) {
      debugPrint('Progress sync failed: $e');
    }
  }

  Future<void> _persistLocal() async {
    await _prefs.setStringList(_doneKey, _done.toList());
    final last = _lastLessonId;
    if (last != null) await _prefs.setString(_lastKey, last);
  }

  Future<void> _save() async {
    await _persistLocal();
    try {
      await _sync?.push(_done, _lastLessonId);
    } catch (e) {
      debugPrint('Progress sync failed: $e');
    }
  }

  bool isDone(String lessonId) => _done.contains(lessonId);

  int completedIn(Course c) => c.lessons.where((l) => isDone(l.id)).length;

  double courseProgress(Course c) =>
      c.lessons.isEmpty ? 0 : completedIn(c) / c.lessons.length;

  /// Only counts lessons that still exist in published courses.
  int get totalCompleted => _courses.published
      .expand((c) => c.lessons)
      .where((l) => _done.contains(l.id))
      .length;
  int get totalLessons => _courses.published.fold(0, (s, c) => s + c.lessons.length);
  double get overallProgress => totalLessons == 0 ? 0 : totalCompleted / totalLessons;
  int get completedCourses =>
      _courses.published.where((c) => c.lessons.isNotEmpty && courseProgress(c) == 1).length;
  int get minutesLearned => _courses.published
      .expand((c) => c.lessons)
      .where((l) => isDone(l.id))
      .fold(0, (s, l) => s + l.minutes);

  /// The unfinished course the user last worked on, if any.
  Course? get continueCourse {
    final id = _lastLessonId;
    if (id == null) return null;
    for (final c in _courses.published) {
      if (c.lessons.any((l) => l.id == id) && courseProgress(c) < 1) return c;
    }
    return null;
  }

  Future<void> markVisited(String lessonId) async {
    if (_lastLessonId == lessonId) return;
    _lastLessonId = lessonId;
    notifyListeners();
    await _save();
  }

  Future<void> setDone(String lessonId, bool done) async {
    done ? _done.add(lessonId) : _done.remove(lessonId);
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _auth.removeListener(_load);
    _courses.removeListener(notifyListeners);
    super.dispose();
  }
}
