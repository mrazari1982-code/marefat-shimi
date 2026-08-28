create or replace function public.v5_get_attempt_state(p_attempt_id uuid,p_student_code text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare a public.v5_attempts; duration integer; answers jsonb;
begin
 select t.* into a from public.v5_attempts t join public.v5_students s on s.id=t.student_id
 where t.id=p_attempt_id and lower(trim(s.student_code))=lower(trim(p_student_code)) and s.is_active
 for update of t;
 if not found then raise exception 'ATTEMPT_OR_STUDENT_NOT_FOUND'; end if;
 if a.status='started' and not public.v5_check_attempt_time(a.id) then
  a:=v5_private.finalize_attempt(a.id);
 end if;
 select duration_minutes into duration from public.v5_exams where id=a.exam_id;
 select coalesce(jsonb_agg(jsonb_build_object('exam_question_id',sa.exam_question_id,
  'selected_option_id',sa.selected_option_id)),'[]'::jsonb) into answers
 from public.v5_student_answers sa where sa.attempt_id=a.id;
 return jsonb_build_object('attempt_id',a.id,'status',a.status,'started_at',a.started_at,
  'submitted_at',a.submitted_at,'duration_minutes',duration,'answers',answers,
  'deadline_at',v5_private.attempt_deadline(a.id),'server_now',clock_timestamp());
end $$;
revoke all on function public.v5_get_attempt_state(uuid,text) from public;
grant execute on function public.v5_get_attempt_state(uuid,text) to anon,authenticated,service_role;

-- Uses only synthetic fixtures. The inner subtransaction always rolls them back.
-- Any failed assertion aborts the caller; safe to append to an atomic migration.
do $test$
declare
 sid bigint; eid bigint; qid bigint; eqid bigint; yesid bigint; noid bigint;
 aid uuid; otheraid uuid; r jsonb; before_result jsonb; after_result jsonb;
 code text := 'AUDIT-EXPIRY-' || gen_random_uuid()::text;
begin
 begin
  insert into public.v5_students(student_code,full_name) values(code,'Synthetic expiry test') returning id into sid;
  insert into public.v5_exams(exam_code,title,duration_minutes,show_result_to_student)
   values(code,'Synthetic expiry test',1,true) returning id into eid;
  insert into public.v5_questions(subject_id,question_text)
   values((select min(id) from public.v5_subjects),'Synthetic expiry question') returning id into qid;
  insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order)
   values(qid,'A','Correct',true,1) returning id into yesid;
  insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order)
   values(qid,'B','Wrong',false,2) returning id into noid;
  insert into public.v5_exam_questions(exam_id,question_id,question_order,score)
   values(eid,qid,1,2) returning id into eqid;
  insert into public.v5_attempts(exam_id,student_id,started_at)
   values(eid,sid,clock_timestamp()) returning id into aid;
  r := public.v5_save_answer(aid,eqid,yesid,code);
  assert (r->>'saved')::boolean, 'save before deadline must succeed';
  r := public.v5_get_attempt_state(aid,lower(code));
  assert r->>'deadline_at' is not null and r->>'server_now' is not null,
   'state must provide authoritative deadline and server time';
  -- Move only our fixture to a point after its deadline, preserving a pre-deadline answer.
  update public.v5_attempts set started_at=clock_timestamp()-interval '2 minutes' where id=aid;
  update public.v5_student_answers set answered_at=clock_timestamp()-interval '90 seconds' where attempt_id=aid;
  r := public.v5_submit_attempt(aid,code);
  assert r->>'status'='submitted', 'deadline must finalize, not expire';
  assert (r->>'correct_answers')::int=1 and (r->>'percentage')::numeric=100,
   'automatic finalization must grade the saved answer';
  select to_jsonb(a) into before_result from public.v5_attempts a where id=aid;
  r := public.v5_save_answer(aid,eqid,noid,code);
  assert not (r->>'saved')::boolean, 'post-deadline answer must be rejected';
  assert (select selected_option_id=yesid from public.v5_student_answers where attempt_id=aid),
   'late answer must not replace saved answer';
  r := public.v5_submit_attempt(aid,code);
  select to_jsonb(a) into after_result from public.v5_attempts a where id=aid;
  assert before_result=after_result, 'retry must not change grade or submission time';
  assert (r->>'percentage')::numeric=100, 'retry must return existing permitted result';
  begin
   perform public.v5_submit_attempt(aid,'WRONG-STUDENT');
   raise exception 'unauthorized submit was accepted';
  exception when raise_exception then
   if sqlerrm <> 'STUDENT_DOES_NOT_MATCH_ATTEMPT' then raise; end if;
  end;
  update public.v5_exams set show_result_to_student=false where id=eid;
  r:=public.v5_submit_attempt(aid,code);
  assert r->>'show_result'='false' and not (r ? 'percentage'), 'hidden result must stay hidden';
  -- Scheduler path: browser is absent, no answers, includes global exam end_at.
  update public.v5_exams set duration_minutes=null,end_at=clock_timestamp()-interval '1 second' where id=eid;
  insert into public.v5_attempts(exam_id,student_id,started_at)
   values(eid,sid,clock_timestamp()-interval '10 seconds') returning id into otheraid;
  perform v5_private.finalize_due_attempts();
  assert (select status='submitted' and blank_count=1 and percentage=0 from public.v5_attempts where id=otheraid),
   'scheduler must finalize unanswered attempt after exam end';
  -- Legacy bulk API must not clear saved answers after deadline.
  begin
   perform public.v5_save_answers(aid,code,'[]'::jsonb);
   raise exception 'bulk overwrite after submit was accepted';
  exception when raise_exception then
   if sqlerrm not in ('ATTEMPT_NOT_STARTED','EXAM_TIME_EXPIRED') then raise; end if;
  end;
  assert (select selected_option_id=yesid from public.v5_student_answers where attempt_id=aid),
   'bulk rejection must preserve submitted answers';
  -- A late save also finalizes, but cannot contribute an answer.
  insert into public.v5_attempts(exam_id,student_id,started_at)
   values(eid,sid,clock_timestamp()-interval '10 seconds') returning id into otheraid;
  r:=public.v5_save_answer(otheraid,eqid,yesid,code);
  assert r->>'status'='submitted' and r->>'saved'='false', 'late save must finalize without accepting answer';
  assert (select blank_count=1 and correct_count=0 from public.v5_attempts where id=otheraid), 'late answer must remain blank';
  -- No deadline: the worker must not close a live attempt.
  update public.v5_exams set end_at=null,duration_minutes=null where id=eid;
  insert into public.v5_attempts(exam_id,student_id,started_at)
   values(eid,sid,clock_timestamp()) returning id into otheraid;
  perform v5_private.finalize_due_attempts();
  assert (select status='started' from public.v5_attempts where id=otheraid), 'unlimited attempt must remain open';
  r:=public.v5_submit_attempt(otheraid,code);
  assert r->>'status'='submitted', 'manual submit must still work';
  assert not has_function_privilege('anon','v5_private.finalize_attempt(uuid)','execute'), 'private grading must not be public';
  assert not has_function_privilege('authenticated','v5_private.finalize_due_attempts()','execute'), 'scheduler must not be callable by clients';
  raise sqlstate 'ZX001' using message='fixtures complete: rollback';
 exception when sqlstate 'ZX001' then null;
 end;
end $test$;

