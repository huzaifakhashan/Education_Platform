# 📚 Learning App

تطبيق تعليمي (ويب + أندرويد) من كود Flutter واحد: فيديوهات، دروس، تتبّع تقدّم، تسجيل دخول، أدوار وصلاحيات (مدير / مدرّس / طالب)، وإدارة دورات، ورسائل خاصة بين الطالب والمدرّس.


<table>
<tr>
<td align="center"><img src="docs/screenshots/login.png" width="220"><br><sub>تسجيل الدخول</sub></td>
<td align="center"><img src="docs/screenshots/register.png" width="220"><br><sub>إنشاء حساب</sub></td>
<td align="center"><img src="docs/screenshots/courses-home.png" width="220"><br><sub>الدورات + "تابع من حيث توقفت"</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/course-detail.png" width="220"><br><sub>تفاصيل الدورة</sub></td>
<td align="center"><img src="docs/screenshots/lesson-player.png" width="220"><br><sub>مشغّل الفيديو</sub></td>
<td align="center"><img src="docs/screenshots/progress.png" width="220"><br><sub>تقدّمي</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/manage-courses.png" width="220"><br><sub>إدارة الدورات (مدير/مدرّس)</sub></td>
<td align="center"><img src="docs/screenshots/course-editor.png" width="220"><br><sub>محرّر الدورة</sub></td>
<td align="center"><img src="docs/screenshots/profile-light.png" width="220"><br><sub>الحساب — فاتح</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/profile-dark.png" width="220"><br><sub>الحساب — داكن</sub></td>
<td align="center"><img src="docs/screenshots/courses-dark.png" width="220"><br><sub>الدورات — داكن</sub></td>
<td></td>
</tr>
</table>

---

## المزايا

- **تسجيل دخول وتسجيل حساب** عبر Firebase Authentication (بريد إلكتروني وكلمة مرور).
- **ثلاثة أدوار بصلاحيات حقيقية** مفروضة في قواعد أمان Firestore على السيرفر، وليس فقط بإخفاء أزرار في الواجهة:
  - **مدير:** يدير كل الدورات وأدوار كل المستخدمين.
  - **مدرّس:** ينشئ ويعدّل ويحذف دوراته الخاصة فقط.
  - **طالب:** يتعلّم ويتابع تقدّمه ويراسل.
  - أول حساب يسجّل في التطبيق يصبح **مديراً** تلقائياً (مرة واحدة فقط)؛ كل من بعده طالب حتى يرقّيه المدير.
- **إدارة الدورات:** عنوان، وصف، أيقونة ولون من مجموعة جاهزة، نشر أو حفظ كمسودة، وإضافة/تعديل/حذف/إعادة ترتيب الدروس بالسحب.
- **دروس فيديو:** تشغيل/إيقاف، شريط تقدّم، وتعليم الدرس كمكتمل تلقائياً عند مشاهدة 95% منه (أو يدوياً).
- **تتبّع التقدّم:** لكل مستخدم على حدة، نسبة إنجاز لكل دورة ونسبة عامة، ويُزامَن بين الويب والأندرويد عبر Firestore (تقدّم السحابة يفوز عند تسجيل الدخول، ويُرفع التقدّم المحلي الموجود مسبقاً تلقائياً).
- **رسائل خاصة:** الطالب يراسل المدرّسين والمدير (وزر "راسل المدرّس" داخل كل دورة)، والمدرّس والمدير يراسلان أي شخص، مع عدّاد رسائل غير مقروءة.
- **وضع داكن/فاتح/تلقائي**، يُحفظ الاختيار على الجهاز.
- **واجهة عربية RTL** بالكامل، وأيقونة تطبيق مصمَّمة خصيصاً (كتاب مفتوح + زر تشغيل).

---

## الطبقة التقنية

|---|---|
| الواجهة | Flutter (Material 3) |
| الحالة | `ChangeNotifier` + `InheritedWidget` بسيط (`AppScope`) — بدون حزمة إدارة حالة خارجية |
| المصادقة | Firebase Authentication |
| قاعدة البيانات | Cloud Firestore (`profiles`, `courses`, `users` للتقدّم, `chats`) |
| الاستضافة | Firebase Hosting (ويب) |
| التخزين المحلي | `shared_preferences` (الثيم، وكل بيانات وضع "بدون Firebase") |
| الفيديو | حزمة `video_player` (روابط `mp4` مباشرة) |


## الأدوار والصلاحيات

| الإجراء | طالب | مدرّس | مدير |
|---|:---:|:---:|:---:|
| مشاهدة الدورات المنشورة وتتبّع التقدّم | ✅ | ✅ | ✅ |
| مراسلة المدرّسين/المدير | ✅ | ✅ (أي شخص) | ✅ (أي شخص) |
| إنشاء/تعديل/حذف دوراته هو | ❌ | ✅ | ✅ |
| إدارة دورات الآخرين | ❌ | ❌ | ✅ |
| تغيير أدوار المستخدمين | ❌ | ❌ | ✅ |

الصلاحيات مفروضة في **طبقتين**: الواجهة تُخفي ما لا يخص المستخدم، وقواعد أمان Firestore ([firestore.rules](firestore.rules)) ترفض أي طلب مخالف حتى لو تم تجاوز الواجهة — وهذا ما يُختبر فعلياً (انظر قسم الاختبارات).


## الرخصة

مشروع خاص — لا يوجد ترخيص عام حالياً.


## لتحميل التطبيق: https://github.com/huzaifakhashan/Education_Platform/releases/tag/v1.0.0
