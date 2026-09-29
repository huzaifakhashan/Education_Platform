import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import 'auth_service.dart';

/// On-device authentication (accounts live in local storage only).
class LocalAuthService extends AuthService {
  LocalAuthService(this._prefs) {
    _email = _prefs.getString(_kCurrent);
  }

  static const _kUsers = 'users';
  static const _kCurrent = 'current_user';

  final SharedPreferences _prefs;
  String? _email;

  @override
  bool get isLoggedIn => _email != null;
  @override
  bool get isReady => true;
  @override
  String? get uid => _email;
  @override
  UserRole get role => UserRole.student;
  @override
  String? get email => _email;
  @override
  String get name => _users[_email]?['name'] ?? '';

  Map<String, dynamic> get _users {
    final raw = _prefs.getString(_kUsers);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw));
  }

  String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

  @override
  Future<void> register(String name, String email, String password) async {
    final key = email.trim().toLowerCase();
    final users = _users;
    if (users.containsKey(key)) throw AuthException('هذا البريد مسجّل مسبقاً');
    users[key] = {'name': name.trim(), 'hash': _hash(password)};
    await _prefs.setString(_kUsers, jsonEncode(users));
    await _setCurrent(key);
  }

  @override
  Future<void> login(String email, String password) async {
    final key = email.trim().toLowerCase();
    final user = _users[key];
    if (user == null || user['hash'] != _hash(password)) {
      throw AuthException('البريد أو كلمة المرور غير صحيحة');
    }
    await _setCurrent(key);
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(_kCurrent);
    _email = null;
    notifyListeners();
  }

  Future<void> _setCurrent(String key) async {
    await _prefs.setString(_kCurrent, key);
    _email = key;
    notifyListeners();
  }
}
