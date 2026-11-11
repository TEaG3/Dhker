# ذِكر (Dhker)

تطبيق Flutter باللغة العربية لإدارة مواقيت الصلاة والقرآن والأذكار. المشروع قيد التطوير، ولا يُعد إصدار Android جاهزاً للنشر حتى تنجح اختبارات CI ويُنشر ملف APK ضمن إصدار رسمي.

## التطوير عبر GitHub Codespaces

1. افتح المستودع: https://github.com/TEaG3/Dhker
2. اختر **Code → Codespaces → Create codespace on main**.
3. سيستخدم Codespaces إعداد `.devcontainer/devcontainer.json` لتجهيز بيئة Flutter.
4. بعد اكتمال الإعداد، نفّذ:

```bash
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

لتشغيل التطبيق على محاكي أو جهاز Android متصل:

```bash
flutter run
```

قبل إغلاق Codespaces، احفظ التعديلات في Git ثم ارفعها:

```bash
git status
git add .
git commit -m "Describe your changes"
git push
```

لا تُرفع ملفات `build/` أو `.dart_tool/` إلى Git؛ فهي ملفات مولّدة ويجب أن تبقى مستثناة في `.gitignore`.

## البناء والتحقق

يوجد Workflow واحد مسؤول عن بناء Android:
- يعمل عند الدفع إلى `main`، وعند فتح طلب دمج يستهدف `main`، ويمكن تشغيله يدوياً من تبويب Actions.
- ينفذ `flutter pub get` ثم `flutter analyze` ثم `flutter test` ثم `flutter build apk --release`.
- يرفع APK وملف SHA-256 كـ Artifact لمدة 30 يوماً.
- عند نشر GitHub Release، يرفق APK وملف التحقق بالإصدار.

يمكن تنزيل ملفات البناء المؤقتة من تبويب **Actions → Build Android APK → Artifacts**. أما رابط التنزيل العام فيظهر بعد نشر إصدار رسمي فقط.

## حالة الميزات

قد تختلف حالة بعض الميزات بين الفروع. لا تُعرض أي مكتبة أذكار أو أحاديث أو تسجيلات على أنها مراجعة أو مرخّصة قبل توثيق مصادرها ومراجعتها. بيانات القرآن والنصوص الدينية يجب أن تبقى مطابقة للمصدر المعتمد دون إعادة صياغة.

## المستودع

https://github.com/TEaG3/Dhker
