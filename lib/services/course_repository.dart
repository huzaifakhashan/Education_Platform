import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/courses_data.dart';
import '../models/course.dart';
import 'auth_service.dart';

/// Source of truth for courses. Screens read [all]/[published] and listen for changes.
abstract class CourseRepository extends ChangeNotifier {
  /// Every course (including drafts), oldest first.
  List<Course> get all;

  /// False until the first load finishes.
  bool get loaded;

  List<Course> get published => all.where((c) => c.published).toList();

  Course? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Courses the given user is allowed to edit.
  List<Course> editableBy(AuthService auth) => all.where(auth.canEditCourse).toList();

  Future<void> save(Course course);
  Future<void> delete(String id);

  /// Imports the demo courses, owned by the given instructor.
  Future<void> seedSamples({required String instructorId, required String instructorName});

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';
}

/// Keeps courses in memory (used when Firebase is off, and in tests).
class InMemoryCourseRepository extends CourseRepository {
  InMemoryCourseRepository({List<Course> initial = sampleCourses}) : _all = [...initial];

  final List<Course> _all;

  @override
  List<Course> get all => List.unmodifiable(_all);
  @override
  bool get loaded => true;

  @override
  Future<void> save(Course course) async {
    final i = _all.indexWhere((c) => c.id == course.id);
    i >= 0 ? _all[i] = course : _all.add(course);
    _all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    _all.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  @override
  Future<void> seedSamples({required String instructorId, required String instructorName}) async {
    for (final c in sampleCourses) {
      await save(c.copyWith(instructorId: instructorId, instructor: instructorName));
    }
  }
}

/// Courses stored in Firestore (`courses/{id}`), streamed live while signed in.
class FirestoreCourseRepository extends CourseRepository {
  FirestoreCourseRepository(this._auth) {
    _auth.addListener(_sync);
    _sync();
  }

  final AuthService _auth;
  final _col = FirebaseFirestore.instance.collection('courses');
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<Course> _all = [];
  bool _loaded = false;

  @override
  List<Course> get all => _all;
  @override
  bool get loaded => _loaded;

  void _sync() {
    final shouldListen = _auth.isLoggedIn && _auth.isReady;
    if (shouldListen && _sub == null) {
      _sub = _col.snapshots().listen((snap) {
        _all = [for (final d in snap.docs) Course.fromMap(d.id, d.data())]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _loaded = true;
        notifyListeners();
      }, onError: (Object e) {
        debugPrint('Courses stream failed: $e');
        _loaded = true;
        notifyListeners();
      });
    } else if (!shouldListen && _sub != null) {
      _sub!.cancel();
      _sub = null;
      _all = [];
      _loaded = false;
      notifyListeners();
    }
  }

  @override
  Future<void> save(Course course) => _col.doc(course.id).set(course.toMap());

  @override
  Future<void> delete(String id) => _col.doc(id).delete();

  @override
  Future<void> seedSamples({required String instructorId, required String instructorName}) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final c in sampleCourses) {
      final course = c.copyWith(instructorId: instructorId, instructor: instructorName);
      batch.set(_col.doc(course.id), course.toMap());
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _auth.removeListener(_sync);
    _sub?.cancel();
    super.dispose();
  }
}
