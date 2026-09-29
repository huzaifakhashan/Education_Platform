import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RemoteProgress {
  final Set<String> done;
  final String? lastLessonId;
  const RemoteProgress(this.done, this.lastLessonId);
}

/// Cloud storage for a user's progress, so it follows them across devices.
abstract class ProgressSync {
  /// Returns null when nothing is stored yet for the signed-in user.
  Future<RemoteProgress?> fetch();
  Future<void> push(Set<String> done, String? lastLessonId);
}

/// Stores progress in Firestore at `users/{uid}`.
class FirestoreProgressSync implements ProgressSync {
  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : FirebaseFirestore.instance.collection('users').doc(uid);
  }

  @override
  Future<RemoteProgress?> fetch() async {
    final doc = _doc;
    if (doc == null) return null;
    final snap = await doc.get();
    final data = snap.data();
    if (data == null) return null;
    return RemoteProgress(
      List<String>.from(data['done'] ?? const []).toSet(),
      data['last'] as String?,
    );
  }

  @override
  Future<void> push(Set<String> done, String? lastLessonId) async {
    await _doc?.set({'done': done.toList(), 'last': lastLessonId});
  }
}
