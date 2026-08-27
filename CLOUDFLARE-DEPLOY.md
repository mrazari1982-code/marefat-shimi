# استقرار سامانه معرفت روی Cloudflare

این مخزن برای استقرار آزمایشی روی Cloudflare Pages آماده شده است.

## وضعیت

- سایت فعلی Netlify دست‌نخورده می‌ماند.
- شاخه production برابر `main` است.
- پروژه یک سایت استاتیک HTML/JS است و build command لازم ندارد.
- خروجی Pages ریشه مخزن (`.`) است.
- دیتابیس همچنان Supabase است و در این انتقال جابه‌جا نمی‌شود.

## راه‌اندازی Cloudflare Pages

در Cloudflare Dashboard به **Workers & Pages** بروید و یک Pages project جدید بسازید و GitHub را متصل کنید. مخزن `mrazari1982-code/marefat-shimi` را انتخاب کنید.

تنظیمات پیشنهادی:

- Production branch: `main`
- Build command: خالی
- Build output directory: `.`

بعد از اولین deploy، Cloudflare یک آدرس `pages.dev` برای نسخه آزمایشی می‌دهد.

## نکته مهم

تا زمانی که نسخه Cloudflare با ورود مدیر، ساخت آزمون، لینک آزمون، ورود دانش‌آموز، پاسخ‌دهی، ثبت نهایی، کارنامه و تحلیل آموزشی آزمایش نشده است، Netlify را حذف یا تغییر ندهید.

این فایل صرفاً راهنمای استقرار است و هیچ رمز عبور، کلید خصوصی یا Secret در آن قرار نمی‌گیرد.
