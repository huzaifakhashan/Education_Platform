import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/course_repository.dart';
import 'services/directory_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_auth_service.dart';
import 'services/progress_service.dart';
import 'services/progress_sync.dart';
import 'services/theme_controller.dart';
import 'widgets/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final AuthService auth;
  final CourseRepository courses;
  ProgressSync? sync;
  ChatService? chat;
  DirectoryService? directory;
  if (kUseFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuthService.waitForInitialState();
    auth = FirebaseAuthService();
    courses = FirestoreCourseRepository(auth);
    sync = FirestoreProgressSync();
    chat = ChatService(auth);
    directory = DirectoryService();
  } else {
    auth = LocalAuthService(prefs);
    courses = InMemoryCourseRepository();
  }

  runApp(LearningApp(
    auth: auth,
    courses: courses,
    progress: ProgressService(prefs, auth, courses, sync: sync),
    theme: ThemeController(prefs),
    chat: chat,
    directory: directory,
  ));
}

class LearningApp extends StatelessWidget {
  const LearningApp({
    super.key,
    required this.auth,
    required this.progress,
    required this.courses,
    required this.theme,
    this.chat,
    this.directory,
  });

  final AuthService auth;
  final ProgressService progress;
  final CourseRepository courses;
  final ThemeController theme;
  final ChatService? chat;
  final DirectoryService? directory;

  static const seed = Color(0xFF6366F1);

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? scheme.surface : const Color(0xFFF7F7FB),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surfaceContainerHigh : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      auth: auth,
      progress: progress,
      courses: courses,
      theme: theme,
      chat: chat,
      directory: directory,
      child: ListenableBuilder(
        listenable: theme,
        builder: (_, _) => MaterialApp(
          title: 'Learning App',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: theme.mode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: ListenableBuilder(
            listenable: auth,
            builder: (_, _) {
              if (!auth.isLoggedIn) return const AuthScreen();
              if (!auth.isReady) return const _Splash();
              return const HomeShell();
            },
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
