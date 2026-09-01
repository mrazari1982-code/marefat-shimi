begin;
do $$
declare
  student_a bigint := 20; student_b bigint := 21; exam_id bigint := 191;
  descriptive_eq bigint := 32; objective_eq bigint := 31;
  token_a text := repeat('a',64); token_b text := repeat('b',64);
  active_attempt uuid := gen_random_uuid(); expired_attempt uuid := gen_random_uuid(); foreign_attempt uuid := gen_random_uuid();
  payload jsonb; blocked boolean;
begin
  insert into v5_auth_private.sessions(token_hash,student_id,expires_at) values
    (encode(extensions.digest(token_a,'sha256'),'hex'),student_a,clock_timestamp()+interval '1 hour'),
    (encode(extensions.digest(token_b,'sha256'),'hex'),student_b,clock_timestamp()+interval '1 hour');
  insert into public.v5_attempts(id,exam_id,student_id,status,started_at) values
    (active_attempt,exam_id,student_a,'started',clock_timestamp()),
    (expired_attempt,exam_id,student_a,'started',clock_timestamp()-interval '2 hours'),
    (foreign_attempt,exam_id,student_b,'started',clock_timestamp());

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
  payload := public.v5_student_submit_attempt(active_attempt,token_a);
  if payload->>'grading_status' <> 'pending_manual'
     or payload->'percentage' <> 'null'::jsonb or payload->'total_score' <> 'null'::jsonb
     or payload->'max_score' <> 'null'::jsonb or payload->>'result_visible' <> 'false'
  then raise exception 'PENDING_RESULT_LEAK: %',payload; end if;

  blocked:=false;
  begin perform public.v5_student_submit_attempt(active_attempt,token_a);
  exception when others then blocked := sqlerrm like '%ATTEMPT_NOT_STARTED%'; end;
  if not blocked then raise exception 'RESUBMIT_REJECTION_FAILED'; end if;

  blocked:=false;
  begin perform public.v5_student_submit_attempt(expired_attempt,token_a);
  exception when others then blocked := sqlerrm like '%ATTEMPT_EXPIRED%'; end;
  if not blocked then raise exception 'DEADLINE_REJECTION_FAILED'; end if;
end $$;
rollback;
select 'PASS: ownership, type, trim/delete, length, pending visibility, resubmit and deadline' result;
