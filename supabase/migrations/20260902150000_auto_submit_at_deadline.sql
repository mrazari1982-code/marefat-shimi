-- Finalize persisted answers when the server deadline is reached.
-- Answer-save RPCs continue to reject writes after the deadline.
create or replace function public.v5_student_save_answer(
  p_attempt_id uuid,
  p_exam_question_id bigint,
  p_selected_option_id bigint,
  p_session_token text
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype;
  v_exam_question public.v5_exam_questions%rowtype;
  v_option public.v5_question_options%rowtype;
  v_deadline timestamptz;
begin
  v_student:=v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  if v_attempt.status<>'started' then
    return jsonb_build_object('saved',false,'status',v_attempt.status::text);
  end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_deadline:=case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at+v_exam.duration_minutes*interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at+v_exam.duration_minutes*interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp()>=v_deadline then
    return jsonb_build_object('saved',false,'status','deadline_passed');
  end if;
  select eq.* into v_exam_question from public.v5_exam_questions eq
  join public.v5_questions q on q.id=eq.question_id
  where eq.id=p_exam_question_id and eq.exam_id=v_attempt.exam_id
    and q.question_type<>'descriptive';
  if not found then raise exception 'QUESTION_NOT_IN_EXAM'; end if;
  select o.* into v_option from public.v5_question_options o
  where o.id=p_selected_option_id and o.question_id=v_exam_question.question_id;
  if not found then raise exception 'OPTION_NOT_IN_QUESTION'; end if;
  begin
    insert into public.v5_student_answers(
      attempt_id,exam_question_id,selected_option_id,answer_text,is_correct,score_awarded,answered_at
    ) values(
      v_attempt.id,v_exam_question.id,v_option.id,v_option.option_text,null,0,clock_timestamp()
    ) on conflict(attempt_id,exam_question_id) do update set
      selected_option_id=excluded.selected_option_id,answer_text=excluded.answer_text,
      is_correct=null,score_awarded=0,answered_at=excluded.answered_at;
    if v_deadline is not null and clock_timestamp()>=v_deadline then
      raise sqlstate 'ZX002' using message='SAVE_CROSSED_DEADLINE';
    end if;
  exception when sqlstate 'ZX002' then
    return jsonb_build_object('saved',false,'status','deadline_passed');
  end;
  return jsonb_build_object('saved',true,'status','started');
end
$$;

create or replace function public.v5_student_save_descriptive_answer(
  p_attempt_id uuid,
  p_exam_question_id bigint,
  p_answer_text text,
  p_session_token text
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype;
  v_question_type public.v5_question_type;
  v_answer text:=btrim(coalesce(p_answer_text,''));
  v_deadline timestamptz;
begin
  v_student:=v5_auth_private.student_for_token(p_session_token);
  if char_length(v_answer)>10000 then raise exception 'ANSWER_TOO_LONG'; end if;
  select a.* into v_attempt from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  if v_attempt.status<>'started' then
    return jsonb_build_object('saved',false,'status',v_attempt.status::text);
  end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_deadline:=case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at+v_exam.duration_minutes*interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at+v_exam.duration_minutes*interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp()>=v_deadline then
    return jsonb_build_object('saved',false,'status','deadline_passed');
  end if;
  select q.question_type into v_question_type
  from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id
  where eq.id=p_exam_question_id and eq.exam_id=v_attempt.exam_id;
  if not found then raise exception 'QUESTION_NOT_IN_ATTEMPT'; end if;
  if v_question_type<>'descriptive' then raise exception 'QUESTION_NOT_DESCRIPTIVE'; end if;
  begin
    if v_answer='' then
      delete from public.v5_student_answers
      where attempt_id=p_attempt_id and exam_question_id=p_exam_question_id;
    else
      insert into public.v5_student_answers(
        attempt_id,exam_question_id,answer_text,selected_option_id,
        is_correct,score_awarded,answered_at,graded_by,graded_at,grading_feedback
      ) values(
        p_attempt_id,p_exam_question_id,v_answer,null,
        null,0,clock_timestamp(),null,null,null
      ) on conflict(attempt_id,exam_question_id) do update set
        answer_text=excluded.answer_text,selected_option_id=null,is_correct=null,
        score_awarded=0,answered_at=excluded.answered_at,graded_by=null,
        graded_at=null,grading_feedback=null;
    end if;
    if v_deadline is not null and clock_timestamp()>=v_deadline then
      raise sqlstate 'ZX002' using message='SAVE_CROSSED_DEADLINE';
    end if;
  exception when sqlstate 'ZX002' then
    return jsonb_build_object('saved',false,'status','deadline_passed');
  end;
  return jsonb_build_object('saved',true,'status','started','answered',v_answer<>'');
end
$$;

create or replace function public.v5_student_submit_attempt(
  p_attempt_id uuid,
  p_session_token text
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype;
  v_correct integer := 0;
  v_wrong integer := 0;
  v_blank integer := 0;
  v_pending_manual_count integer := 0;
  v_total_score numeric := 0;
  v_max_score numeric := 0;
  v_percentage numeric := 0;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt
  from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id
  for update;
  if not found then
    raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501';
  end if;
  select e.* into strict v_exam
  from public.v5_exams e
  where e.id=v_attempt.exam_id;

  if v_attempt.status='submitted' then
    select
      count(*) filter (where q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null),
      coalesce(sum(eq.score),0)
    into v_pending_manual_count,v_max_score
    from public.v5_exam_questions eq
    join public.v5_questions q on q.id=eq.question_id
    left join public.v5_student_answers sa on sa.attempt_id=v_attempt.id and sa.exam_question_id=eq.id
    where eq.exam_id=v_attempt.exam_id;
    return jsonb_build_object(
      'status','submitted',
      'show_result',case when v_pending_manual_count>0 then false else v_exam.show_result_to_student end,
      'result_visible',case when v_pending_manual_count>0 then false else v_exam.show_result_to_student end,
      'grading_status',v_attempt.grading_status,
      'pending_manual_count',v_pending_manual_count,
      'correct_answers',case when v_pending_manual_count>0 then null else v_attempt.correct_count end,
      'wrong_answers',case when v_pending_manual_count>0 then null else v_attempt.wrong_count end,
      'unanswered_questions',case when v_pending_manual_count>0 then null else v_attempt.blank_count end,
      'total_score',case when v_pending_manual_count>0 then null else v_attempt.total_score end,
      'max_score',case when v_pending_manual_count>0 then null else v_max_score end,
      'percentage',case when v_pending_manual_count>0 then null else v_attempt.percentage end
    );
  end if;
  if v_attempt.status<>'started' then
    raise exception 'ATTEMPT_NOT_STARTED' using errcode='55000';
  end if;

  update public.v5_student_answers sa set
    is_correct=exists(
      select 1 from public.v5_question_options qo
      where qo.id=sa.selected_option_id
        and qo.question_id=eq.question_id
        and qo.is_correct
    ),
    score_awarded=case when exists(
      select 1 from public.v5_question_options qo
      where qo.id=sa.selected_option_id
        and qo.question_id=eq.question_id
        and qo.is_correct
    ) then eq.score else 0 end
  from public.v5_exam_questions eq
  join public.v5_questions q on q.id=eq.question_id
  where sa.attempt_id=v_attempt.id
    and sa.exam_question_id=eq.id
    and q.question_type<>'descriptive'
    and sa.selected_option_id is not null;

  select
    count(*) filter (where q.question_type<>'descriptive' and sa.selected_option_id is not null and sa.is_correct is true),
    count(*) filter (where q.question_type<>'descriptive' and sa.selected_option_id is not null and sa.is_correct is false),
    count(*) filter (where (q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is null)
                          or (q.question_type<>'descriptive' and sa.selected_option_id is null)),
    count(*) filter (where q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null),
    coalesce(sum(sa.score_awarded),0),
    coalesce(sum(eq.score),0)
  into v_correct,v_wrong,v_blank,v_pending_manual_count,v_total_score,v_max_score
  from public.v5_exam_questions eq
  join public.v5_questions q on q.id=eq.question_id
  left join public.v5_student_answers sa on sa.attempt_id=v_attempt.id and sa.exam_question_id=eq.id
  where eq.exam_id=v_attempt.exam_id;

  v_percentage := case when v_max_score>0 then round(v_total_score*100/v_max_score,2) else 0 end;
  update public.v5_attempts set
    status='submitted',submitted_at=clock_timestamp(),
    correct_count=v_correct,wrong_count=v_wrong,blank_count=v_blank,total_score=v_total_score,
    percentage=v_percentage,
    grading_status=case when v_pending_manual_count>0 then 'pending_manual' else 'graded' end
  where id=v_attempt.id;

  return jsonb_build_object(
    'status','submitted',
    'show_result',case when v_pending_manual_count>0 then false else v_exam.show_result_to_student end,
    'result_visible',case when v_pending_manual_count>0 then false else v_exam.show_result_to_student end,
    'grading_status',case when v_pending_manual_count>0 then 'pending_manual' else 'graded' end,
    'pending_manual_count',v_pending_manual_count,
    'correct_answers',case when v_pending_manual_count>0 then null else v_correct end,
    'wrong_answers',case when v_pending_manual_count>0 then null else v_wrong end,
    'unanswered_questions',case when v_pending_manual_count>0 then null else v_blank end,
    'total_score',case when v_pending_manual_count>0 then null else v_total_score end,
    'max_score',case when v_pending_manual_count>0 then null else v_max_score end,
    'percentage',case when v_pending_manual_count>0 then null else v_percentage end
  );
end
$$;

create or replace function public.v5_student_resume_attempt(
  p_attempt_id uuid,
  p_session_token text
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype;
  v_deadline timestamptz;
  v_result jsonb;
begin
  v_student:=v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  if v_attempt.status='submitted' then
    return jsonb_build_object('available',false,'reason','submitted','status','submitted','attempt_id',v_attempt.id);
  end if;
  if v_attempt.status='expired' then raise exception 'ATTEMPT_EXPIRED'; end if;
  if v_exam.status<>'published' then raise exception 'EXAM_CLOSED'; end if;
  v_deadline:=case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at+v_exam.duration_minutes*interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at+v_exam.duration_minutes*interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp()>=v_deadline then
    v_result:=public.v5_student_submit_attempt(p_attempt_id,p_session_token);
    return v_result||jsonb_build_object('available',false,'reason','submitted','attempt_id',v_attempt.id);
  end if;
  return jsonb_build_object(
    'available',true,'attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,
    'student_name',v_student.full_name,'status',v_attempt.status,
    'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at,
    'deadline_at',v_deadline,'server_now',clock_timestamp()
  );
end
$$;

revoke all on function public.v5_student_save_answer(uuid,bigint,bigint,text) from public;
grant execute on function public.v5_student_save_answer(uuid,bigint,bigint,text) to anon,authenticated;
revoke all on function public.v5_student_save_descriptive_answer(uuid,bigint,text,text) from public;
grant execute on function public.v5_student_save_descriptive_answer(uuid,bigint,text,text) to anon,authenticated;
revoke all on function public.v5_student_submit_attempt(uuid,text) from public;
grant execute on function public.v5_student_submit_attempt(uuid,text) to anon,authenticated;
revoke all on function public.v5_student_resume_attempt(uuid,text) from public;
grant execute on function public.v5_student_resume_attempt(uuid,text) to anon,authenticated;
