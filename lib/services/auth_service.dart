import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../models/profile.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Authentication + current-user contract. Implemented by [LocalAuthService]
/// (on-device) and [FirebaseAuthService] (cloud, roles, synced across devices).
abstract class AuthService extends ChangeNotifier {
  bool get isLoggedIn;

  /// False while the signed-in user's profile/role is still loading.
  bool get isReady;

  String? get uid;
  String? get email;
  String get name;
  UserRole get role;

  Future<void> register(String name, String email, String password);
  Future<void> login(String email, String password);
  Future<void> logout();

  bool get isAdmin => role == UserRole.admin;
  bool get isStaff => role.isStaff;

  /// Admins edit everything; teachers only their own courses.
  bool canEditCourse(Course c) =>
      isAdmin || (role == UserRole.teacher && c.instructorId == uid);
}
