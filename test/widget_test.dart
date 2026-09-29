import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/courses_data.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/models/chat.dart';
import 'package:learning_app/models/course.dart';
import 'package:learning_app/models/profile.dart';
import 'package:learning_app/services/auth_service.dart';
import 'package:learning_app/services/course_repository.dart';
import 'package:learning_app/services/local_auth_service.dart';
import 'package:learning_app/services/progress_service.dart';
import 'package:learning_app/services/progress_sync.dart';
import 'package:learning_app/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSync implements ProgressSync {
  RemoteProgress? stored;
  int pushes = 0;

  @override
  Future<RemoteProgress?> fetch() async => stored;

  @override
  Future<void> push(Set<String> done, String? lastLessonId) async {
    pushes++;
    stored = RemoteProgress({...done}, lastLessonId);
  }
}

/// Auth with a fixed identity and role, for role-based tests.
class _FakeAuth extends AuthService {
  _FakeAuth(this._uid, this._role);
  final String _uid;
  final UserRole _role;

  @override
  bool get isLoggedIn => true;
  @override
  bool get isReady => true;
  @override
  String? get uid => _uid;
  @override
  String? get email => '$_uid@test.com';
  @override
  String get name => 'مستخدم';
  @override
  UserRole get role => _role;
  @override
  Future<void> register(String name, String email, String password) async {}
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<void> logout() async {}
}

Future<({SharedPreferences prefs, LocalAuthService auth})> _setup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return (prefs: prefs, auth: LocalAuthService(prefs));
}

ProgressService _progress(SharedPreferences prefs, AuthService auth, {ProgressSync? sync, CourseRepository? repo}) =>
    ProgressService(prefs, auth, repo ?? InMemoryCourseRepository(), sync: sync);

void main() {
  group('auth', () {
    test('register, logout, login round-trip', () async {
      final s = await _setup();
      await s.auth.register('هدى', 'Huda@Test.com', '123456');
      expect(s.auth.isLoggedIn, isTrue);
      expect(s.auth.email, 'huda@test.com');
      expect(s.auth.name, 'هدى');
      await s.auth.logout();
      expect(s.auth.isLoggedIn, isFalse);
      await s.auth.login('huda@test.com', '123456');
      expect(s.auth.isLoggedIn, isTrue);
    });

    test('wrong password is rejected', () async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      await s.auth.logout();
      expect(() => s.auth.login('a@a.com', 'bad'), throwsA(isA<AuthException>()));
    });

    test('duplicate email is rejected', () async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      expect(() => s.auth.register('b', 'A@a.com', '654321'), throwsA(isA<AuthException>()));
    });

    test('session survives restart', () async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      expect(LocalAuthService(s.prefs).isLoggedIn, isTrue);
    });
  });

  group('progress', () {
    test('computes course and overall progress', () async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      final p = _progress(s.prefs, s.auth);
      final course = sampleCourses.first;
      expect(p.courseProgress(course), 0);
      for (final l in course.lessons) {
        await p.setDone(l.id, true);
      }
      expect(p.courseProgress(course), 1);
      expect(p.completedCourses, 1);
      expect(p.minutesLearned, course.totalMinutes);
      await p.setDone(course.lessons.first.id, false);
      expect(p.completedIn(course), course.lessons.length - 1);
    });

    test('continueCourse is the unfinished course last visited', () async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      final p = _progress(s.prefs, s.auth);
      expect(p.continueCourse, isNull);
      await p.markVisited('python-2');
      expect(p.continueCourse!.id, 'python');
      for (final l in sampleCourses.firstWhere((c) => c.id == 'python').lessons) {
        await p.setDone(l.id, true);
      }
      expect(p.continueCourse, isNull);
    });

    test('progress is separate per user and restored on login', () async {
      final s = await _setup();
      final p = _progress(s.prefs, s.auth);
      await s.auth.register('a', 'a@a.com', '123456');
      await p.setDone('flutter-1', true);
      await s.auth.logout();
      expect(p.totalCompleted, 0);
      await s.auth.register('b', 'b@b.com', '123456');
      expect(p.totalCompleted, 0);
      await s.auth.logout();
      await s.auth.login('a@a.com', '123456');
      expect(p.isDone('flutter-1'), isTrue);
    });

    test('cloud progress wins on login; local changes are pushed', () async {
      final s = await _setup();
      final sync = _FakeSync()..stored = const RemoteProgress({'python-1'}, 'python-1');
      final p = _progress(s.prefs, s.auth, sync: sync);
      await s.auth.register('a', 'a@a.com', '123456');
      await Future<void>.delayed(Duration.zero);
      expect(p.isDone('python-1'), isTrue);
      await p.setDone('flutter-1', true);
      expect(sync.stored!.done, {'python-1', 'flutter-1'});
    });

    test('first login uploads existing local progress', () async {
      final s = await _setup();
      final sync = _FakeSync();
      final p = _progress(s.prefs, s.auth, sync: sync);
      await s.auth.register('a', 'a@a.com', '123456');
      await Future<void>.delayed(Duration.zero);
      expect(sync.pushes, 1);
      expect(sync.stored, isNotNull);
      expect(p.totalCompleted, 0);
    });

    test('lessons removed from a course no longer count', () async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      final p = _progress(s.prefs, s.auth);
      await p.setDone('flutter-1', true);
      await p.setDone('deleted-lesson', true);
      expect(p.totalCompleted, 1);
    });
  });

  group('theme', () {
    test('mode persists', () async {
      final s = await _setup();
      final t = ThemeController(s.prefs);
      expect(t.mode, ThemeMode.system);
      await t.setMode(ThemeMode.dark);
      expect(ThemeController(s.prefs).mode, ThemeMode.dark);
    });
  });

  group('roles & permissions', () {
    const mine = Course(id: 'a', title: 'a', description: '', instructor: 'me', instructorId: 'u1', lessons: []);
    const others = Course(id: 'b', title: 'b', description: '', instructor: 'x', instructorId: 'u2', lessons: []);

    test('role parsing and labels', () {
      expect(UserRole.parse('admin'), UserRole.admin);
      expect(UserRole.parse('teacher'), UserRole.teacher);
      expect(UserRole.parse('whatever'), UserRole.student);
      expect(UserRole.parse(null), UserRole.student);
      expect(UserRole.student.isStaff, isFalse);
      expect(UserRole.teacher.isStaff, isTrue);
      expect(UserRole.admin.isStaff, isTrue);
    });

    test('students edit nothing, teachers only their own, admins everything', () {
      final student = _FakeAuth('u1', UserRole.student);
      final teacher = _FakeAuth('u1', UserRole.teacher);
      final admin = _FakeAuth('u9', UserRole.admin);
      expect(student.canEditCourse(mine), isFalse);
      expect(teacher.canEditCourse(mine), isTrue);
      expect(teacher.canEditCourse(others), isFalse);
      expect(admin.canEditCourse(mine), isTrue);
      expect(admin.canEditCourse(others), isTrue);
    });

    test('repository filters editable and published courses', () async {
      final repo = InMemoryCourseRepository(initial: const []);
      await repo.save(mine);
      await repo.save(others.copyWith(published: false));
      expect(repo.published.map((c) => c.id), ['a']);
      expect(repo.editableBy(_FakeAuth('u1', UserRole.teacher)).map((c) => c.id), ['a']);
      expect(repo.editableBy(_FakeAuth('u9', UserRole.admin)).length, 2);
      expect(repo.editableBy(_FakeAuth('u1', UserRole.student)), isEmpty);
      await repo.delete('a');
      expect(repo.byId('a'), isNull);
    });

    test('seeding imports the demo courses under the given instructor', () async {
      final repo = InMemoryCourseRepository(initial: const []);
      await repo.seedSamples(instructorId: 'u9', instructorName: 'Boss');
      expect(repo.all.length, sampleCourses.length);
      expect(repo.all.every((c) => c.instructorId == 'u9' && c.instructor == 'Boss'), isTrue);
    });
  });

  group('models', () {
    test('course survives a map round-trip', () {
      final original = sampleCourses.first.copyWith(published: false, instructorId: 'u1');
      final copy = Course.fromMap(original.id, original.toMap());
      expect(copy.title, original.title);
      expect(copy.published, isFalse);
      expect(copy.instructorId, 'u1');
      expect(copy.lessons.length, original.lessons.length);
      expect(copy.lessons.first.videoUrl, original.lessons.first.videoUrl);
      expect(copy.gradient, original.gradient);
    });

    test('chat summary unread and counterpart helpers', () {
      final c = ChatSummary.fromMap('a_b', {
        'participants': ['a', 'b'],
        'names': {'a': 'Ann', 'b': 'Bob'},
        'lastMessage': 'hi',
        'lastSenderId': 'a',
        'unread': {'b': true},
      });
      expect(c.otherId('a'), 'b');
      expect(c.otherName('a'), 'Bob');
      expect(c.isUnread('b'), isTrue);
      expect(c.isUnread('a'), isFalse);
    });
  });

  group('screens', () {
    Future<void> pumpApp(WidgetTester tester, AuthService auth, SharedPreferences prefs,
        {CourseRepository? repo}) async {
      final courses = repo ?? InMemoryCourseRepository();
      await tester.pumpWidget(LearningApp(
        auth: auth,
        courses: courses,
        progress: ProgressService(prefs, auth, courses),
        theme: ThemeController(prefs),
      ));
    }

    testWidgets('login form validates input', (tester) async {
      final s = await _setup();
      await pumpApp(tester, s.auth, s.prefs);
      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
      await tester.pump();
      expect(find.text('بريد إلكتروني غير صالح'), findsOneWidget);
      expect(find.text('6 أحرف على الأقل'), findsOneWidget);
    });

    testWidgets('sign up from the UI shows courses, logout returns to login', (tester) async {
      final s = await _setup();
      await pumpApp(tester, s.auth, s.prefs);
      await tester.tap(find.text('ليس لديك حساب؟ سجّل الآن'));
      await tester.pump();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'هدى');
      await tester.enterText(fields.at(1), 'huda@test.com');
      await tester.enterText(fields.at(2), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
      await tester.pumpAndSettle();
      expect(find.text('كل الدورات'), findsOneWidget);
      expect(find.text(sampleCourses.first.title), findsOneWidget);

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('course screen lists lessons and dark mode can be selected', (tester) async {
      final s = await _setup();
      await s.auth.register('a', 'a@a.com', '123456');
      await pumpApp(tester, s.auth, s.prefs);

      await tester.tap(find.text(sampleCourses.first.title));
      await tester.pumpAndSettle();
      expect(find.text(sampleCourses.first.lessons.first.title), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('داكن'));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });
  });

  group('role-based screens', () {
    Future<void> pumpAs(WidgetTester tester, UserRole role, {List<Course> initial = const []}) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuth('u1', role);
      final courses = InMemoryCourseRepository(initial: initial);
      await tester.pumpWidget(LearningApp(
        auth: auth,
        courses: courses,
        progress: ProgressService(prefs, auth, courses),
        theme: ThemeController(prefs),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('students have no management tab', (tester) async {
      await pumpAs(tester, UserRole.student);
      expect(find.text('دوراتي'), findsNothing);
      expect(find.text('الإدارة'), findsNothing);
    });

    testWidgets('teachers see only their own courses in the manage tab', (tester) async {
      await pumpAs(tester, UserRole.teacher, initial: [
        sampleCourses[0].copyWith(instructorId: 'u1'),
        sampleCourses[1].copyWith(instructorId: 'someone-else'),
      ]);
      await tester.tap(find.text('دوراتي'));
      await tester.pumpAndSettle();
      expect(find.text(sampleCourses[0].title), findsOneWidget);
      expect(find.text(sampleCourses[1].title), findsNothing);
      expect(find.text('دورة جديدة'), findsOneWidget);
    });

    testWidgets('teacher can create a course from the editor', (tester) async {
      await pumpAs(tester, UserRole.teacher);
      await tester.tap(find.text('دوراتي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دورة جديدة'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'دورة الرياضيات');
      await tester.enterText(fields.at(1), 'وصف الدورة');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('دورة الرياضيات'), findsOneWidget);
    });

    testWidgets('editor validates required fields', (tester) async {
      await pumpAs(tester, UserRole.teacher);
      await tester.tap(find.text('دوراتي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دورة جديدة'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
      await tester.pump();
      expect(find.text('أدخل عنواناً (3 أحرف على الأقل)'), findsOneWidget);
    });
  });
}
