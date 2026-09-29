import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/course_repository.dart';
import '../services/directory_service.dart';
import '../services/progress_service.dart';
import '../services/theme_controller.dart';

/// Exposes the app services to the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.progress,
    required this.courses,
    required this.theme,
    this.chat,
    this.directory,
    required super.child,
  });

  final AuthService auth;
  final ProgressService progress;
  final CourseRepository courses;
  final ThemeController theme;

  /// Cloud-only features; null when running without Firebase.
  final ChatService? chat;
  final DirectoryService? directory;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => false;
}
