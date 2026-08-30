# Marefat Flutter Student Demo

این پروژه یک دموی Flutter برای جریان دانش‌آموز سامانه آزمون V5 است و فقط به پروژه آزمایشی Supabase متصل می‌شود.

## اجرا

```bash
flutter create . --platforms=web,android --project-name marefat_student_demo
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://yyqeymyopawhaniyemqo.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> \
  --dart-define=DEMO_EXAM_TOKEN=<staging-exam-token>
```

برای build اندروید از همان dart-defineها با `flutter build apk --release` استفاده کنید. هیچ service-role یا secret key نباید در اپ قرار بگیرد.

## مسیرهای پیاده‌شده

- ورود دانش‌آموز با `v5_student_login`
- داشبورد با `v5_student_dashboard`
- شروع/ادامه آزمون با RPCهای session-bound
- دریافت سؤال‌ها و پاسخ‌های ذخیره‌شده
- ذخیره پاسخ با `v5_student_save_answer`
- ثبت نهایی با `v5_student_submit_attempt`
- کارنامه با `v5_student_get_result`

GitHub Actions تست، تحلیل استاتیک، Flutter Web و APK را می‌سازد و خروجی‌ها را به‌صورت artifact نگه می‌دارد.
