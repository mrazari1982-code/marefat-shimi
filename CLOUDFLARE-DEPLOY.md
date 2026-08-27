# استقرار سامانه معرفت روی Cloudflare

## وضعیت فعلی

نسخه اصلی سامانه روی Cloudflare Workers مستقر شده و به مخزن GitHub متصل است:

- Worker: `marefat-shimi`
- Production URL: `https://marefat-shimi.m-r-azari-1982.workers.dev/`
- GitHub repository: `mrazari1982-code/marefat-shimi`
- Production branch: `main`
- Database/Backend: Supabase
- Frontend: HTML/CSS/JavaScript

> نکته: مستندات قدیمی این فایل به Cloudflare Pages اشاره می‌کردند. اکنون استقرار واقعی پروژه روی **Cloudflare Workers** انجام شده است؛ بنابراین تنظیمات فعلی Dashboard و Wrangler باید مبنای عملیات قرار گیرند.

## معماری انتشار

```text
GitHub (main)
      |
      v
Cloudflare Workers
      |
      v
marefat-shimi.m-r-azari-1982.workers.dev
      |
      v
Supabase
```

## قواعد انتشار

1. هر تغییر ابتدا در GitHub و در یک Commit مشخص ثبت شود.
2. همان Commit باید مبنای Deployment باشد.
3. قبل از حذف یا تغییر مسیر پشتیبان، مسیر کامل آزمون روی Production بررسی شود.
4. Database همچنان روی Supabase باقی می‌ماند و با Deployment فرانت‌اند جابه‌جا نمی‌شود.
5. هیچ Secret یا `service_role` key نباید در فایل‌های Frontend یا Repository قرار گیرد.

## چک‌لیست Production

- [ ] باز شدن URL اصلی Worker
- [ ] بارگذاری صفحه ورود آزمون
- [ ] اتصال Supabase
- [ ] اعتبارسنجی لینک آزمون
- [ ] ورود دانش‌آموز
- [ ] شروع آزمون
- [ ] دریافت سؤال‌ها بدون answer key
- [ ] ذخیره پاسخ
- [ ] بازیابی پاسخ‌ها
- [ ] تایمر و پایان زمان
- [ ] ثبت نهایی
- [ ] کارنامه
- [ ] ورود مدیر
- [ ] بانک سؤال
- [ ] ساخت و انتشار آزمون
- [ ] ایجاد لینک
- [ ] گزارش و تحلیل آموزشی
- [ ] تست دسترسی‌های غیرمجاز

## وضعیت Backup

Netlify به‌عنوان مسیر پشتیبان/سابقه حذف یا تخریب نمی‌شود تا زمانی که تست کامل Production روی Cloudflare انجام نشده باشد.

## محدودیت فعلی

تست مرورگر تعاملی و مشاهده Console/Network در این محیط به Dashboard یا مرورگر کاربر وابسته است. در صورت مشاهده خطا در URL بالا، متن خطا یا تصویر صفحه برای بررسی دقیق لازم است.
