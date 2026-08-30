# چک‌لیست تست واقعی سامانه آزمون معرفت V5

## مسیر اصلی دانش‌آموز
- [ ] باز کردن لینک آزمون با token
- [ ] ورود کد دانش‌آموز معتبر
- [ ] شروع آزمون Published
- [ ] نمایش صحیح سؤال‌ها و گزینه‌ها
- [ ] عدم نمایش answer key در داده دریافتی
- [ ] انتخاب پاسخ
- [ ] تغییر پاسخ
- [ ] ذخیره پاسخ در سرور
- [ ] Refresh و بازیابی Attempt
- [ ] نمایش تایمر
- [ ] جلوگیری از پاسخ بعد از پایان زمان
- [ ] ثبت نهایی
- [ ] محاسبه صحیح/غلط/نزده
- [ ] نمایش درصد
- [ ] جلوگیری از Submit دوباره

## مسیرهای منفی
- [ ] token نامعتبر
- [ ] آزمون Draft
- [ ] آزمون Closed
- [ ] دانش‌آموز نامعتبر
- [ ] Attempt متعلق به دانش‌آموز دیگر
- [ ] گزینه متعلق به سؤال دیگر
- [ ] پاسخ بعد از انقضای زمان
- [ ] نتیجه قبل از Submit

## پنل مدیر
- [ ] ورود مدیر
- [ ] ساخت آزمون
- [ ] انتشار آزمون
- [ ] ساخت لینک
- [ ] غیرفعال کردن لینک
- [ ] فعال کردن لینک
- [ ] مشاهده وضعیت آزمون

## مرورگر
- [ ] Chrome دسکتاپ
- [ ] Chrome موبایل
- [ ] Firefox/Edge
- [ ] نمایش RTL و فارسی

## پذیرش مرحله ۸ — ۱۴۰۵/۰۶/۰۸ (2026-08-30)

### تست‌های خودکار

- [x] `node --test tests/*.cjs` — 44/44 موفق؛ harness آزمون 18/18 و داشبورد 18/18
- [x] `node tests/question-manager-selection.js` — PASS
- [x] `python3 tests/deployment-safety.py` — 3/3 موفق
- [x] `git diff --check` — بدون خطا
- [x] HTML browser scripts — 24 فایل بدون خطای syntax

### staging پایگاه داده

- [x] migration ثبت‌شده: `20260830085333_student_dashboard_and_resume`
- [x] سه RPC داشبورد، ادامه آزمون و نتیجه با `SECURITY DEFINER` و `search_path=pg_catalog, public, v5_auth_private`
- [x] `PUBLIC EXECUTE=false` برای هر سه RPC؛ اجرای `anon` و `authenticated` عمدی و همراه با احراز نشست opaque درون تابع
- [x] `anon` و `authenticated` روی جدول‌های `v5_auth_private.credentials` و `v5_auth_private.sessions` مجوز SELECT ندارند؛ `anon` روی schema نیز USAGE ندارد
- [x] مجموعه‌های SQL staging در اجرای قبلی همین مرحله موفق ثبت شدند: `simple-student-auth.sql`، `student-auth-ownership.sql`، `student-dashboard-db.sql` و `student-import-db.sql`

### Advisorهای staging

- [x] Security: 85 مورد موجود — 5 `rls_enabled_no_policy`، 14 `anon_security_definer_function_executable` و 66 `authenticated_security_definer_function_executable`
- [x] Performance: 94 مورد موجود — 3 `unindexed_foreign_keys`، 7 `auth_rls_initplan`، 83 `unused_index` و 1 `duplicate_index`
- [x] سه RPC این شاخه search path ثابت و ACL صریح دارند؛ هشدار اجرای anon برای آن‌ها به دلیل مدل ورود سفارشی و بررسی مالکیت داخل تابع عمدی است

### پیش‌نمایش مرورگر متصل فقط به staging

- [x] پیش‌نمایش موقت Cloudflare با 25 فایل دارای ref staging و صفر ref production ساخته شد
- [x] Chrome cloud desktop با viewport `1363×936`: صفحه اصلی فارسی/RTL و دو مسیر نقش نمایش داده شد
- [x] `index.html?token=...` توکن را دقیقاً یک بار در return امن ورود دانش‌آموز حفظ کرد
- [x] `admin.html` نشست‌نداشته را به ورود رسمی مدیریت هدایت کرد
- [x] `exam-access.html` توکن آزمایشی نامعتبر را بدون شروع attempt رد کرد
- [x] دسترسی بدون نشست به `student-dashboard.html` به ورود دانش‌آموز هدایت شد
- [x] فایل‌های داخلی `/.git/HEAD`، `/wrangler.jsonc`، `/tests/question-manager-selection.js` و `/supabase.sql` همگی HTTP 404 دادند
- [x] رفتار عرض 320px با تست ساختاری خودکار داشبورد پوشش داده شد
- [ ] ورود زنده، سابقه، resume، نتیجه و logout با حساب staging — طبق انتخاب کاربر، هیچ اعتبار ورود به مرورگر ارسال نشد
- [ ] تست زنده با viewport واقعی 320px — مرورگر ابری امکان تغییر viewport نداشت

### دروازه تولید

- [x] در این مرحله هیچ داده، schema، migration یا frontend تولیدی تغییر نکرد
- [ ] migration و deployment تولیدی فقط پس از تأیید صریح جداگانه

## اجرای production — 2026-08-30

- [x] تأیید صریح کاربر برای ورود به مرحله production دریافت شد
- [x] migration با نسخهٔ تولیدشدهٔ `20260830145021` و نام `student_dashboard_and_resume` در production اعمال شد
- [x] `v5_student_dashboard(text,integer)`، `v5_student_resume_attempt(uuid,text)` و `v5_student_get_result(uuid,text)` در catalog production موجودند
- [x] هر سه تابع `SECURITY DEFINER` با `search_path=pg_catalog, public, v5_auth_private` هستند
- [x] `PUBLIC EXECUTE=false` و grantهای عمدی `anon`/`authenticated` برای هر سه تابع تأیید شد
- [x] `anon` و `authenticated` روی `v5_auth_private.credentials` و `v5_auth_private.sessions` مجوز SELECT ندارند
- [x] advisor امنیت production پس از migration اجرا شد: 86 مورد — 85 مورد در دسته‌های موجود staging و یک تنظیم Auth با نام `auth_leaked_password_protection`
- [ ] frontend production منتشر و URLهای واقعی بررسی شود
