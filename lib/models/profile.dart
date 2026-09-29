enum UserRole {
  admin,
  teacher,
  student;

  String get label => switch (this) {
        UserRole.admin => 'مدير',
        UserRole.teacher => 'مدرّس',
        UserRole.student => 'طالب',
      };

  /// Admins and teachers.
  bool get isStaff => this != UserRole.student;

  static UserRole parse(String? value) =>
      values.firstWhere((r) => r.name == value, orElse: () => UserRole.student);
}

class Profile {
  final String uid;
  final String name;
  final UserRole role;
  final String email;

  const Profile({
    required this.uid,
    required this.name,
    required this.role,
    this.email = '',
  });

  factory Profile.fromMap(String uid, Map<String, dynamic> m) => Profile(
        uid: uid,
        name: (m['name'] as String?) ?? '',
        role: UserRole.parse(m['role'] as String?),
        email: (m['email'] as String?) ?? '',
      );
}
