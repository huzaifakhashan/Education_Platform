import '../models/course.dart';

const _base = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample';

/// Demo content. Admins can import it into the database from the manage screen.
const sampleCourses = <Course>[
  Course(
    id: 'flutter',
    title: 'تطوير التطبيقات مع Flutter',
    description:
        'تعلّم بناء تطبيقات أندرويد وويب من كود واحد: الواجهات، إدارة الحالة، والتنقل بين الشاشات.',
    instructor: 'م. أحمد الخطيب',
    iconKey: 'phone',
    gradientIndex: 0,
    createdAt: 1,
    lessons: [
      Lesson(
        id: 'flutter-1',
        title: 'مقدمة وتثبيت البيئة',
        description: 'نظرة عامة على Flutter وكيفية تجهيز بيئة العمل.',
        videoUrl: '$_base/BigBuckBunny.mp4',
        minutes: 10,
      ),
      Lesson(
        id: 'flutter-2',
        title: 'الـ Widgets الأساسية',
        description: 'Container, Row, Column, Stack وأهم عناصر الواجهة.',
        videoUrl: '$_base/ElephantsDream.mp4',
        minutes: 15,
      ),
      Lesson(
        id: 'flutter-3',
        title: 'إدارة الحالة',
        description: 'الفرق بين StatelessWidget وStatefulWidget وأدوات إدارة الحالة.',
        videoUrl: '$_base/ForBiggerBlazes.mp4',
        minutes: 12,
      ),
    ],
  ),
  Course(
    id: 'python',
    title: 'أساسيات بايثون',
    description: 'ابدأ البرمجة من الصفر: المتغيرات، الشروط، الحلقات والدوال.',
    instructor: 'م. سارة النابلسي',
    iconKey: 'code',
    gradientIndex: 1,
    createdAt: 2,
    lessons: [
      Lesson(
        id: 'python-1',
        title: 'أول برنامج بلغة بايثون',
        description: 'كتابة وتشغيل أول سكربت.',
        videoUrl: '$_base/ForBiggerEscapes.mp4',
        minutes: 8,
      ),
      Lesson(
        id: 'python-2',
        title: 'المتغيرات وأنواع البيانات',
        description: 'الأرقام والنصوص والقوائم.',
        videoUrl: '$_base/ForBiggerFun.mp4',
        minutes: 14,
      ),
      Lesson(
        id: 'python-3',
        title: 'الحلقات والدوال',
        description: 'for و while وتعريف الدوال.',
        videoUrl: '$_base/ForBiggerJoyrides.mp4',
        minutes: 18,
      ),
    ],
  ),
  Course(
    id: 'design',
    title: 'تصميم واجهات UI/UX',
    description: 'مبادئ التصميم، الألوان، الخطوط، وبناء تجربة مستخدم ممتازة.',
    instructor: 'م. ليان حداد',
    iconKey: 'palette',
    gradientIndex: 2,
    createdAt: 3,
    lessons: [
      Lesson(
        id: 'design-1',
        title: 'مبادئ التصميم',
        description: 'التباين، المحاذاة، والتسلسل البصري.',
        videoUrl: '$_base/ForBiggerMeltdowns.mp4',
        minutes: 9,
      ),
      Lesson(
        id: 'design-2',
        title: 'الألوان والخطوط',
        description: 'اختيار لوحة ألوان وخطوط متناسقة.',
        videoUrl: '$_base/Sintel.mp4',
        minutes: 11,
      ),
    ],
  ),
];
