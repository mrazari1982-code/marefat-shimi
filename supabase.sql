-- SQL برای Supabase
create table if not exists public.exam_results (
 id bigint generated always as identity primary key,
 exam_code text not null,
 student_name text not null,
 student_code text not null,
 class_name text not null,
 correct_count integer not null,
 wrong_count integer not null,
 blank_count integer not null,
 percent numeric(5,2) not null,
 answers jsonb not null,
 submitted_at timestamptz not null default now()
);

create index if not exists exam_results_exam_idx on public.exam_results(exam_code);
create index if not exists exam_results_class_idx on public.exam_results(class_name);
create index if not exists exam_results_student_idx on public.exam_results(student_code);

alter table public.exam_results enable row level security;

-- دانش‌آموز بدون احراز هویت اجازه خواندن نتایج ندارد.
-- درج نتیجه برای نسخه واقعی باید با سیاست دقیق و ترجیحاً Edge Function انجام شود.
-- مدیر احراز هویت‌شده می‌تواند نتایج را بخواند:
create policy "authenticated_admin_read_results"
on public.exam_results for select
to authenticated
using (true);

-- برای جلوگیری از جعل نام/کلاس/نتیجه از سمت مرورگر، پیشنهاد می‌شود INSERT عمومی
-- مستقیماً باز نباشد و ثبت نهایی از طریق Edge Function انجام شود.
