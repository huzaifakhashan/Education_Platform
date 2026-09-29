import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profile.dart';

/// Lists users and lets admins change their roles (`profiles` collection).
class DirectoryService {
  final _col = FirebaseFirestore.instance.collection('profiles');

  Stream<List<Profile>> watchProfiles() => _col.snapshots().map((snap) {
        final list = [for (final d in snap.docs) Profile.fromMap(d.id, d.data())];
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  /// Only succeeds for admins (enforced by the security rules).
  Future<void> setRole(String uid, UserRole role) => _col.doc(uid).update({'role': role.name});
}
