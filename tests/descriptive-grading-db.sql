begin;
do $$
declare
  student_a bigint := 20; student_b bigint := 21; exam_id bigint := 191;
  descriptive_eq bigint := 32; objective_eq bigint := 31;
  token_a text := repeat('a',64); token_b text := repeat('b',64);
  active_attempt uuid := gen_random_uuid(); expired_attempt uuid := gen_random_uuid(); foreign_attempt uuid := gen_random_uuid();
  wrong_attempt uuid := gen_random_uuid(); blank_attempt uuid := gen_random_uuid();
  admin_id uuid := '10000000-0000-4000-8000-000000000099';
  objective_option bigint; wrong_option bigint; descriptive_answer bigint;
  payload jsonb; blocked boolean;
begin
  insert into auth.users(id,email) values(admin_id,'objective-grading-test@example.invalid');
  insert into public.v5_profiles(id,full_name,role,is_active) values(admin_id,'Objective Grading Test Admin','admin',true);
  insert into v5_auth_private.sessions(token_hash,student_id,expires_at) values
    (encode(extensions.digest(token_a,'sha256'),'hex'),student_a,clock_timestamp()+interval '1 hour'),
    (encode(extensions.digest(token_b,'sha256'),'hex'),student_b,clock_timestamp()+interval '1 hour');
  insert into public.v5_attempts(id,exam_id,student_id,status,started_at) values
    (active_attempt,exam_id,student_a,'started',clock_timestamp()),
    (expired_attempt,exam_id,student_a,'started',clock_timestamp()-interval '2 hours'),
    (foreign_attempt,exam_id,student_b,'started',clock_timestamp()),
    (wrong_attempt,exam_id,student_a,'started',clock_timestamp()),
    (blank_attempt,exam_id,student_a,'started',clock_timestamp());

  blocked:=false;
  begin perform public.v5_student_save_descriptive_answer(foreign_attempt,descriptive_eq,'unauthorized',token_a);
  exception when sqlstate '42501' then blocked:=true; end;
  if not blocked then raise exception 'OWNERSHIP_DENIAL_FAILED'; end if;

  blocked:=false;
  begin perform public.v5_student_save_descriptive_answer(active_attempt,objective_eq,'not descriptive',token_a);
  exception when others then blocked := sqlerrm like '%QUESTION_NOT_DESCRIPTIVE%'; end;
  if not blocked then raise exception 'TYPE_ENFORCEMENT_FAILED'; end if;

  perform public.v5_student_save_descriptive_answer(active_attempt,descriptive_eq,'  پاسخ آزمایشی  ',token_a);
  if (select answer_text from public.v5_student_answers where attempt_id=active_attempt and exam_question_id=descriptive_eq) <> 'پاسخ آزمایشی' then raise exception 'ANSWER_TRIM_FAILED'; end if;
  perform public.v5_student_save_descriptive_answer(active_attempt,descriptive_eq,'   ',token_a);
  if exists(select 1 from public.v5_student_answers where attempt_id=active_attempt and exam_question_id=descriptive_eq) then raise exception 'EMPTY_DELETE_FAILED'; end if;

  blocked:=false;
  begin perform public.v5_student_save_descriptive_answer(active_attempt,descriptive_eq,repeat('x',10001),token_a);
  exception when others then blocked := sqlerrm like '%ANSWER_TOO_LONG%'; end;
  if not blocked then raise exception 'LENGTH_REJECTION_FAILED'; end if;

  perform public.v5_student_save_descriptive_answer(active_attempt,descriptive_eq,'پاسخ نهایی',token_a);
  select qo.id into strict objective_option
  from public.v5_exam_questions eq
  join public.v5_question_options qo on qo.question_id=eq.question_id and qo.is_correct
  where eq.id=objective_eq;
  insert into public.v5_student_answers(attempt_id,exam_question_id,selected_option_id,is_correct,score_awarded)
  values(active_attempt,objective_eq,objective_option,null,0);
  payload := public.v5_student_submit_attempt(active_attempt,token_a);
  if payload->>'grading_status' <> 'pending_manual'
     or payload->'percentage' <> 'null'::jsonb or payload->'total_score' <> 'null'::jsonb
     or payload->'max_score' <> 'null'::jsonb or payload->>'result_visible' <> 'false'
  then raise exception 'PENDING_RESULT_LEAK: %',payload; end if;
  if not exists(
    select 1 from public.v5_student_answers
    where attempt_id=active_attempt and exam_question_id=objective_eq
      and is_correct is true and score_awarded=1
  ) then raise exception 'OBJECTIVE_ANSWER_NOT_NORMALIZED'; end if;
  if not exists(
    select 1 from public.v5_attempts
    where id=active_attempt and correct_count=1 and wrong_count=0 and blank_count=0 and total_score=1
  ) then raise exception 'SUBMISSION_COUNTERS_INVALID'; end if;

  update public.v5_attempts set correct_count=0,wrong_count=0,blank_count=0 where id=active_attempt;
  select id into strict descriptive_answer from public.v5_student_answers
  where attempt_id=active_attempt and exam_question_id=descriptive_eq;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  payload := public.v5_admin_grade_descriptive_answer(descriptive_answer,1.5,'regression test');
  if not exists(
    select 1 from public.v5_attempts
    where id=active_attempt and correct_count=1 and wrong_count=0 and blank_count=0
      and total_score=2.5 and percentage=83.33 and grading_status='graded'
  ) then raise exception 'MANUAL_GRADING_COUNTERS_INVALID'; end if;

  select qo.id into strict wrong_option
  from public.v5_exam_questions eq
  join public.v5_question_options qo on qo.question_id=eq.question_id and not qo.is_correct
  where eq.id=objective_eq
  order by qo.id limit 1;
  insert into public.v5_student_answers(attempt_id,exam_question_id,selected_option_id,is_correct,score_awarded)
  values(wrong_attempt,objective_eq,wrong_option,null,0);
  perform public.v5_student_submit_attempt(wrong_attempt,token_a);
  if not exists(
    select 1 from public.v5_student_answers
    where attempt_id=wrong_attempt and exam_question_id=objective_eq
      and is_correct is false and score_awarded=0
  ) or not exists(
    select 1 from public.v5_attempts
    where id=wrong_attempt and correct_count=0 and wrong_count=1 and blank_count=1
  ) then raise exception 'WRONG_OBJECTIVE_NORMALIZATION_INVALID'; end if;

  perform public.v5_student_submit_attempt(blank_attempt,token_a);
  if not exists(
    select 1 from public.v5_attempts
    where id=blank_attempt and correct_count=0 and wrong_count=0 and blank_count=2 and total_score=0
  ) then raise exception 'BLANK_COUNTER_INVALID'; end if;

  blocked:=false;
  begin perform public.v5_student_submit_attempt(active_attempt,token_a);
  exception when others then blocked := sqlerrm like '%ATTEMPT_NOT_STARTED%'; end;
  if not blocked then raise exception 'RESUBMIT_REJECTION_FAILED'; end if;

  payload := public.v5_student_submit_attempt(expired_attempt,token_a);
  if payload->>'status' <> 'expired' or payload->>'result_visible' <> 'false'
  then raise exception 'DEADLINE_REJECTION_FAILED: %',payload; end if;
  if (select status from public.v5_attempts where id=expired_attempt) <> 'expired'
  then raise exception 'EXPIRED_STATUS_NOT_PERSISTED'; end if;
end $$;
rollback;
select 'PASS: ownership, objective normalization, counters, manual grading, pending visibility, resubmit and deadline' result;
