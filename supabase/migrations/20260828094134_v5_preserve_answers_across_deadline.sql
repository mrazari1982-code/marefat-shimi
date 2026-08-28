CREATE OR REPLACE FUNCTION public.v5_save_answer(p_attempt_id uuid, p_exam_question_id bigint, p_selected_option_id bigint, p_student_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  a public.v5_attempts%rowtype;
  eq public.v5_exam_questions%rowtype;
  o public.v5_question_options%rowtype;
  s public.v5_students%rowtype;
begin
  select * into a from public.v5_attempts where id=p_attempt_id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;


  select * into s from public.v5_students
  where id=a.student_id
    and lower(trim(student_code))=lower(trim(p_student_code))
    and is_active=true;
  if not found then raise exception 'STUDENT_DOES_NOT_MATCH_ATTEMPT'; end if;
  if a.status <> 'started'::public.v5_attempt_status then
    return jsonb_build_object('saved',false,'status',a.status::text);
  end if;

  if not public.v5_check_attempt_time(a.id) then
    perform v5_private.finalize_attempt(a.id);
    return jsonb_build_object('saved',false,'status','submitted');
  end if;

  select * into eq from public.v5_exam_questions
  where id=p_exam_question_id and exam_id=a.exam_id;
  if not found then raise exception 'QUESTION_NOT_IN_EXAM'; end if;

  select * into o from public.v5_question_options
  where id=p_selected_option_id and question_id=eq.question_id;
  if not found then raise exception 'OPTION_NOT_IN_QUESTION'; end if;

  begin
  insert into public.v5_student_answers(
    attempt_id,exam_question_id,selected_option_id,answer_text,is_correct,score_awarded,answered_at
  ) values(a.id,eq.id,o.id,o.option_text,null,0,clock_timestamp())
  on conflict(attempt_id,exam_question_id) do update
    set selected_option_id=excluded.selected_option_id,
        answer_text=excluded.answer_text,
        is_correct=null,
        score_awarded=0,
        answered_at=clock_timestamp();
  if not public.v5_check_attempt_time(a.id) then
    raise sqlstate 'ZX002' using message='SAVE_CROSSED_DEADLINE';
  end if;
  exception when sqlstate 'ZX002' then
    -- Roll back only the attempted overwrite, then grade the previously saved answers.
    perform v5_private.finalize_attempt(a.id);
    return jsonb_build_object('saved',false,'status','submitted');
  end;

  return jsonb_build_object('saved',true,'status','started');
end;
$function$;


CREATE OR REPLACE FUNCTION public.v5_save_answers(p_attempt_id uuid, p_student_code text, p_answers jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_exam_id bigint;
    v_student_id bigint;
    v_status public.v5_attempt_status;
    v_invalid_count integer;
begin
    select a.exam_id, a.student_id, a.status
      into v_exam_id, v_student_id, v_status
    from public.v5_attempts a
    join public.v5_students s on s.id = a.student_id
    where a.id = p_attempt_id
      and lower(trim(s.student_code)) = lower(trim(p_student_code))
      and s.is_active = true for update of a;

    if not found then
        raise exception 'ATTEMPT_OR_STUDENT_NOT_FOUND';
    end if;

    if v_status <> 'started'::public.v5_attempt_status then
        raise exception 'ATTEMPT_NOT_STARTED';
    end if;

    if not public.v5_check_attempt_time(p_attempt_id) then
        raise exception 'EXAM_TIME_EXPIRED';
    end if;

    if jsonb_typeof(coalesce(p_answers,'[]'::jsonb)) <> 'array' then
        raise exception 'ANSWERS_MUST_BE_ARRAY';
    end if;

    select count(*) into v_invalid_count
    from jsonb_to_recordset(coalesce(p_answers,'[]'::jsonb)) as x(exam_question_id bigint, selected_option_id bigint)
    left join public.v5_exam_questions eq
      on eq.id = x.exam_question_id and eq.exam_id = v_exam_id
    left join public.v5_question_options qo
      on qo.id = x.selected_option_id and qo.question_id = eq.question_id
    where x.exam_question_id is null
       or x.selected_option_id is null
       or eq.id is null
       or qo.id is null;

    if v_invalid_count > 0 then
        raise exception 'INVALID_EXAM_QUESTION_OR_OPTION';
    end if;

    -- Reject duplicate question entries in one payload instead of relying on a unique violation.
    if exists (
      select 1
      from jsonb_to_recordset(coalesce(p_answers,'[]'::jsonb)) as x(exam_question_id bigint, selected_option_id bigint)
      group by x.exam_question_id
      having count(*) > 1
    ) then
      raise exception 'DUPLICATE_EXAM_QUESTION';
    end if;

    delete from public.v5_student_answers where attempt_id = p_attempt_id;

    insert into public.v5_student_answers (
        attempt_id, exam_question_id, selected_option_id, answer_text, is_correct, score_awarded, answered_at
    )
    select
        p_attempt_id, x.exam_question_id, x.selected_option_id, null, null, 0, clock_timestamp()
    from jsonb_to_recordset(coalesce(p_answers,'[]'::jsonb)) as x(exam_question_id bigint, selected_option_id bigint);
    -- Raising here rolls back the entire delete/insert operation.
    if not public.v5_check_attempt_time(p_attempt_id) then
        raise exception 'EXAM_TIME_EXPIRED';
    end if;
end;
$function$;


-- Uses only synthetic fixtures. The inner subtransaction always rolls them back.
-- Any failed assertion aborts the caller; safe to append to an atomic migration.
do $test$
declare
 sid bigint; eid bigint; qid bigint; eqid bigint; yesid bigint; noid bigint;
 aid uuid; otheraid uuid; r jsonb; before_result jsonb; after_result jsonb;
 code text := 'AUDIT-EXPIRY-' || gen_random_uuid()::text;
 token text;
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
  -- Reopening in the deadline-to-worker window must return the same finalized attempt.
  update public.v5_exams set status='published',duration_minutes=1,end_at=null where id=eid;
  select l.token into token from public.v5_exam_links l where l.exam_id=eid and l.is_active order by l.id desc limit 1;
  insert into public.v5_attempts(exam_id,student_id,started_at)
   values(eid,sid,clock_timestamp()-interval '2 minutes') returning id into otheraid;
  r:=public.v5_start_exam(token,code);
  assert r->>'status'='submitted' and (r->>'attempt_id')::uuid=otheraid,
   'reopening overdue attempt must return its result without a new attempt';
  -- Delay writes to our fixture only, to force a request across the deadline.
  -- Function and trigger are rolled back together with all synthetic records.
  execute $ddl$create function pg_temp.v5_audit_slow_write() returns trigger language plpgsql as $fn$
   begin
    if coalesce(new.attempt_id,old.attempt_id)::text=current_setting('audit.slow_attempt',true) then
     perform pg_sleep(0.2);
    end if;
    return coalesce(new,old);
   end $fn$$ddl$;
  execute 'create trigger v5_audit_slow_write after insert or update or delete on public.v5_student_answers for each row execute function pg_temp.v5_audit_slow_write()';
  update public.v5_exams set end_at=null,duration_minutes=null where id=eid;
  insert into public.v5_attempts(exam_id,student_id,started_at) values(eid,sid,clock_timestamp()) returning id into otheraid;
  perform public.v5_save_answer(otheraid,eqid,yesid,code);
  perform set_config('audit.slow_attempt',otheraid::text,true);
  update public.v5_exams set end_at=clock_timestamp()+interval '100 milliseconds' where id=eid;
  r:=public.v5_save_answer(otheraid,eqid,noid,code);
  assert r->>'saved'='false', 'save completing after deadline must be rejected';
  assert (select selected_option_id=yesid from public.v5_student_answers where attempt_id=otheraid),
   'boundary-straddling upsert must preserve the previous answer';
  perform set_config('audit.slow_attempt','',true);
  update public.v5_exams set end_at=null where id=eid;
  insert into public.v5_attempts(exam_id,student_id,started_at) values(eid,sid,clock_timestamp()) returning id into otheraid;
  perform public.v5_save_answer(otheraid,eqid,yesid,code);
  perform set_config('audit.slow_attempt',otheraid::text,true);
  update public.v5_exams set end_at=clock_timestamp()+interval '100 milliseconds' where id=eid;
  begin
   perform public.v5_save_answers(otheraid,code,'[]');
   raise exception 'boundary-straddling bulk save was accepted';
  exception when raise_exception then
   if sqlerrm <> 'EXAM_TIME_EXPIRED' then raise; end if;
  end;
  assert (select selected_option_id=yesid from public.v5_student_answers where attempt_id=otheraid),
   'boundary-straddling bulk save must preserve previous answers';
  assert not has_function_privilege('anon','v5_private.finalize_attempt(uuid)','execute'), 'private grading must not be public';
  assert not has_function_privilege('authenticated','v5_private.finalize_due_attempts()','execute'), 'scheduler must not be callable by clients';
  raise sqlstate 'ZX001' using message='fixtures complete: rollback';
 exception when sqlstate 'ZX001' then null;
 end;
end $test$;

