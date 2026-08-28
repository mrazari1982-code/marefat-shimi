# انتشار اصلاح‌شده سامانه معرفت

## علت اصلاح

تنظیمات پیش‌فرض قبلی مربوط به Pages بود، اما انتشار با Workers انجام می‌شد.
تنظیمات دوم کل مخزن را به‌عنوان فایل عمومی آپلود می‌کرد. اکنون هر دو فایل
Wrangler فقط پوشه public را منتشر می‌کنند. HTMLها و auto-link.js بدون تغییر
محتوا به این پوشه منتقل شده‌اند؛ آدرس صفحات روی سایت تغییر نمی‌کند.
SQL، تست‌ها، فایل‌های تنظیمات و مستندات بیرون از public باقی می‌مانند.

## تنظیمات Cloudflare Workers Builds

برای Worker با نام marefat-shimi و شاخه اصلی main:

| گزینه | مقدار |
| --- | --- |
| Root directory | ریشه مخزن؛ نه public |
| Build command | خالی؛ سایت به مرحله ساخت نیاز ندارد |
| Deploy command | `npx wrangler deploy --config wrangler.jsonc` |
| Non-production deploy command، در صورت فعال بودن | `npx wrangler versions upload --config wrangler.jsonc` |

فرمان deploy را در بخش Build قرار ندهید. فایل wrangler-cloudflare.jsonc
برای سازگاری با فرمان قبلی حفظ شده و همان تنظیمات امن را دارد.
فقط پوشه public را به GitHub نفرستید؛ کل محتوای این پروژه باید در ریشه مخزن
قرار بگیرد، بدون پوشه اضافی marefat-shimi-main درون مخزن.
نسخه جدید صفحات را فقط داخل public ویرایش کنید.

## بررسی پیش از انتشار

```bash
python3 tests/deployment-safety.py
node tests/question-manager-selection.js
npx wrangler deploy --dry-run --config wrangler.jsonc
```

دو تست اول محلی هستند. دستور سوم به نصب Wrangler نیاز دارد و انتشار انجام نمی‌دهد.

## بررسی پس از انتشار

1. صفحه اصلی، ورود مدیر، ورود دانش‌آموز، آزمون و کارنامه را باز کنید.
2. در Network مرورگر بررسی کنید مسیرهای زیر محتوای فایل داخلی را برنگردانند
   و وضعیت HTTP 404 داشته باشند: `/.git/HEAD`، `/supabase.sql`،
   `/staging/seed.sql`، `/wrangler.jsonc`، `/tests/question-manager-selection.js`.
3. مسیر کامل آزمون را با حساب و داده آزمایشی اجرا کنید؛ ثبت نهایی روی داده واقعی انجام نشود.
4. نسخه‌ها و Preview URLهای قدیمی که ممکن است فایل‌های داخلی داشته باشند بررسی شوند.
   این بسته به‌تنهایی دسترسی به نسخه‌های قدیمی را حذف نمی‌کند.
5. اگر فایل یا تاریخچه Git قبلاً کلید محرمانه داشته است، آن کلید باید در سرویس مربوط
   باطل و جایگزین شود. وجود کلید محرمانه با بررسی این ZIP به‌تنهایی قابل رد یا تأیید نیست.

## محدوده این اصلاح

هیچ SQL یا تغییر دیتابیسی اجرا نشده است. محتوا و منطق صفحات تغییر نکرده‌اند.
تست کامل Supabase، RLS، ورود و محاسبه نمره نیازمند بررسی محیط واقعی است.
فایل‌های staging که در لاگ قبلی نام برده شده‌اند در ZIP ورودی حاضر نیستند؛
این بسته جایگزین بررسی یا بازیابی آن‌ها نیست.

مراجع:
- https://developers.cloudflare.com/workers/static-assets/binding/
- https://developers.cloudflare.com/workers/ci-cd/builds/configuration/
