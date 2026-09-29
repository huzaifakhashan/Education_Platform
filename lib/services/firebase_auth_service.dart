import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import 'auth_service.dart';

/// Cloud authentication (Firebase Auth) plus the user's role profile
/// stored in Firestore at `profiles/{uid}`.
///
/// The very first account ever created becomes the admin (claimed through a
/// one-time `meta/admin` document, enforced by the security rules). Everyone
/// else starts as a student; only an admin can change roles afterwards.
class FirebaseAuthService extends AuthService {
  FirebaseAuthService() {
    _user = _auth.currentUser;
    _sub = _auth.authStateChanges().listen(_onUser);
  }

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late final StreamSubscription<User?> _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  User? _user;
  Profile? _profile;
  String? _profileUid;
  String? _pendingName;

  /// Call before runApp so a restored session (notably on web) is known.
  static Future<void> waitForInitialState() => FirebaseAuth.instance.authStateChanges().first;

  @override
  bool get isLoggedIn => _user != null;
  @override
  bool get isReady => _user != null && _profile != null;
  @override
  String? get uid => _user?.uid;
  @override
  String? get email => _user?.email?.toLowerCase();
  @override
  String get name => _profile?.name ?? _user?.displayName ?? '';
  @override
  UserRole get role => _profile?.role ?? UserRole.student;

  void _onUser(User? u) {
    _user = u;
    if (u?.uid == _profileUid) {
      notifyListeners();
      return;
    }
    _profileSub?.cancel();
    _profileSub = null;
    _profile = null;
    _profileUid = u?.uid;
    notifyListeners();
    if (u != null) _loadProfile(u);
  }

  Future<void> _loadProfile(User u) async {
    try {
      await _ensureProfile(u);
    } catch (e) {
      debugPrint('Profile setup failed: $e');
      if (_profileUid == u.uid && _profile == null) {
        // Keep the app usable (as a student) if the profile can't be read.
        _profile = Profile(uid: u.uid, name: _fallbackName(u), role: UserRole.student);
        notifyListeners();
      }
    }
    if (_profileUid != u.uid) return;
    _profileSub = _db.collection('profiles').doc(u.uid).snapshots().listen((s) {
      final data = s.data();
      if (data == null) return;
      _profile = Profile.fromMap(u.uid, data);
      notifyListeners();
    });
  }

  String _fallbackName(User u) =>
      (_pendingName ?? u.displayName ?? u.email?.split('@').first ?? 'مستخدم').trim();

  Future<void> _ensureProfile(User u) async {
    final ref = _db.collection('profiles').doc(u.uid);
    if ((await ref.get()).exists) return;

    final data = {
      'name': _fallbackName(u),
      'email': u.email?.toLowerCase() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Try to claim the one-time admin slot if nobody has yet.
    final meta = _db.collection('meta').doc('admin');
    var claimable = false;
    try {
      claimable = !(await meta.get()).exists;
    } catch (_) {}
    if (claimable) {
      try {
        final batch = _db.batch();
        batch.set(meta, {'uid': u.uid});
        batch.set(ref, {...data, 'role': UserRole.admin.name});
        await batch.commit();
        return;
      } catch (_) {
        // Someone else claimed it first; fall through to a normal student.
      }
    }
    await ref.set({...data, 'role': UserRole.student.name});
  }

  @override
  Future<void> register(String name, String email, String password) async {
    try {
      _pendingName = name.trim();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    } finally {
      // The profile is created from the pending name as soon as auth fires.
      Future<void>.delayed(const Duration(seconds: 5), () => _pendingName = null);
    }
  }

  @override
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e.code));
    }
  }

  @override
  Future<void> logout() => _auth.signOut();

  String _message(String code) => switch (code) {
        'email-already-in-use' => 'هذا البريد مسجّل مسبقاً',
        'invalid-email' => 'بريد إلكتروني غير صالح',
        'weak-password' => 'كلمة المرور ضعيفة',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'البريد أو كلمة المرور غير صحيحة',
        'too-many-requests' => 'محاولات كثيرة، حاول لاحقاً',
        'network-request-failed' => 'تحقق من الاتصال بالإنترنت',
        _ => 'حدث خطأ غير متوقع ($code)',
      };

  @override
  void dispose() {
    _sub.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
