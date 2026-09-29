import 'package:flutter/material.dart';

/// Icons a course author can pick from (stored by key in the database).
const courseIcons = <String, IconData>{
  'phone': Icons.phone_android_rounded,
  'code': Icons.code_rounded,
  'palette': Icons.palette_rounded,
  'science': Icons.science_rounded,
  'calculate': Icons.calculate_rounded,
  'language': Icons.language_rounded,
  'music': Icons.music_note_rounded,
  'business': Icons.business_center_rounded,
  'camera': Icons.photo_camera_rounded,
  'book': Icons.menu_book_rounded,
};

/// Color themes a course author can pick from (stored by index).
const courseGradients = <List<Color>>[
  [Color(0xFF6366F1), Color(0xFFA855F7)],
  [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
  [Color(0xFFF97316), Color(0xFFEC4899)],
  [Color(0xFF10B981), Color(0xFF34D399)],
  [Color(0xFFEF4444), Color(0xFFF59E0B)],
  [Color(0xFF334155), Color(0xFF64748B)],
];

class Lesson {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final int minutes;

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.minutes,
  });

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        videoUrl: (m['videoUrl'] as String?) ?? '',
        minutes: (m['minutes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'videoUrl': videoUrl,
        'minutes': minutes,
      };
}

class Course {
  final String id;
  final String title;
  final String description;
  final String instructor;
  final String instructorId;
  final String iconKey;
  final int gradientIndex;
  final bool published;
  final int createdAt;
  final List<Lesson> lessons;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    this.instructorId = '',
    this.iconKey = 'book',
    this.gradientIndex = 0,
    this.published = true,
    this.createdAt = 0,
    required this.lessons,
  });

  IconData get icon => courseIcons[iconKey] ?? Icons.menu_book_rounded;
  List<Color> get gradient => courseGradients[gradientIndex.clamp(0, courseGradients.length - 1)];
  int get totalMinutes => lessons.fold(0, (sum, l) => sum + l.minutes);

  Course copyWith({
    String? title,
    String? description,
    String? instructor,
    String? instructorId,
    String? iconKey,
    int? gradientIndex,
    bool? published,
    int? createdAt,
    List<Lesson>? lessons,
  }) =>
      Course(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        instructor: instructor ?? this.instructor,
        instructorId: instructorId ?? this.instructorId,
        iconKey: iconKey ?? this.iconKey,
        gradientIndex: gradientIndex ?? this.gradientIndex,
        published: published ?? this.published,
        createdAt: createdAt ?? this.createdAt,
        lessons: lessons ?? this.lessons,
      );

  factory Course.fromMap(String id, Map<String, dynamic> m) => Course(
        id: id,
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        instructor: (m['instructor'] as String?) ?? '',
        instructorId: (m['instructorId'] as String?) ?? '',
        iconKey: (m['iconKey'] as String?) ?? 'book',
        gradientIndex: (m['gradientIndex'] as num?)?.toInt() ?? 0,
        published: (m['published'] as bool?) ?? true,
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        lessons: [
          for (final l in (m['lessons'] as List? ?? const []))
            Lesson.fromMap(Map<String, dynamic>.from(l as Map)),
        ],
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'instructor': instructor,
        'instructorId': instructorId,
        'iconKey': iconKey,
        'gradientIndex': gradientIndex,
        'published': published,
        'createdAt': createdAt,
        'lessons': [for (final l in lessons) l.toMap()],
      };
}
