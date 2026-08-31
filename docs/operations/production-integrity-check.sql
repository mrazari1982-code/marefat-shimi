-- Read-only production integrity checks. No row is changed.
-- Run with a role allowed to read the V5 operational tables.

select 'duplicate_student_codes' as check_name, count(*) as issue_count
from (
  select lower(trim(student_code))
  from public.v5_students
  group by 1
  having count(*) > 1
) duplicates
union all
select 'orphan_attempt_students', count(*)
from public.v5_attempts a
left join public.v5_students s on s.id = a.student_id
where s.id is null
union all
select 'orphan_attempt_exams', count(*)
from public.v5_attempts a
left join public.v5_exams e on e.id = a.exam_id
where e.id is null
union all
select 'orphan_answers', count(*)
from public.v5_student_answers sa
left join public.v5_attempts a on a.id = sa.attempt_id
where a.id is null
union all
select 'submitted_without_timestamp', count(*)
from public.v5_attempts
where status = 'submitted' and submitted_at is null
union all
select 'invalid_percentage', count(*)
from public.v5_attempts
where percentage < 0 or percentage > 100
union all
select 'answer_exam_mismatch', count(*)
from public.v5_student_answers sa
join public.v5_attempts a on a.id = sa.attempt_id
join public.v5_exam_questions eq on eq.id = sa.exam_question_id
where eq.exam_id <> a.exam_id
order by check_name;

select
  u.email_confirmed_at is not null as email_confirmed,
  p.role,
  p.is_active
from auth.users u
join public.v5_profiles p on p.id = u.id
where p.role = 'admin' and p.is_active is true;

select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd
from pg_policies
where schemaname = 'public'
  and (policyname ilike '%test%' or policyname ilike '%anon%')
order by tablename, policyname;
