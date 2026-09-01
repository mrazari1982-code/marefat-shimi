-- Keep descriptive-answer RPCs compatible with the canonical answer table,
-- where question order belongs to v5_exam_questions rather than answer rows.

create or replace function public.v5_student_save_descriptive_answer(
  p_attempt_id uuid,p_exam_question_id bigint,p_answer_text text,p_session_token text
) returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private as $$
declare
  v_student public.v5_students%rowtype; v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype; v_question_type public.v5_question_type;
  v_answer text:=btrim(coalesce(p_answer_text,'')); v_deadline timestamptz;
begin
  v_student:=v5_auth_private.student_for_token(p_session_token);
  if char_length(v_answer)>10000 then raise exception 'ANSWER_TOO_LONG'; end if;
  select a.* into v_attempt from public.v5_attempts a
   where a.id=p_attempt_id and a.student_id=v_student.id and a.status='started' for update;
  if not found then raise exception 'ATTEMPT_NOT_AVAILABLE' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_deadline:=case when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at+v_exam.duration_minutes*interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at+v_exam.duration_minutes*interval '1 minute') end;
  if v_deadline is not null and clock_timestamp()>=v_deadline then
    update public.v5_attempts set status='expired' where id=v_attempt.id;
    return jsonb_build_object('saved',false,'status','expired');
  end if;
  select q.question_type into v_question_type from public.v5_exam_questions eq
   join public.v5_questions q on q.id=eq.question_id
   where eq.id=p_exam_question_id and eq.exam_id=v_attempt.exam_id;
  if not found then raise exception 'QUESTION_NOT_IN_ATTEMPT'; end if;
  if v_question_type<>'descriptive' then raise exception 'QUESTION_NOT_DESCRIPTIVE'; end if;
  if v_answer='' then
    delete from public.v5_student_answers where attempt_id=p_attempt_id and exam_question_id=p_exam_question_id;
  else
    insert into public.v5_student_answers(attempt_id,exam_question_id,answer_text,selected_option_id,is_correct,score_awarded,answered_at,graded_by,graded_at,grading_feedback)
    values(p_attempt_id,p_exam_question_id,v_answer,null,null,0,clock_timestamp(),null,null,null)
    on conflict(attempt_id,exam_question_id) do update set answer_text=excluded.answer_text,
      selected_option_id=null,is_correct=null,score_awarded=0,answered_at=excluded.answered_at,
      graded_by=null,graded_at=null,grading_feedback=null;
  end if;
  return jsonb_build_object('saved',true,'status','started','answered',v_answer<>'');
end $$;

create or replace function public.v5_student_get_attempt_state(p_attempt_id uuid,p_session_token text)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private as $$
declare
  v_student public.v5_students%rowtype; v_attempt public.v5_attempts%rowtype;
  v_exam public.v5_exams%rowtype; v_answers jsonb; v_deadline timestamptz;
begin
  v_student:=v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt from public.v5_attempts a where a.id=p_attempt_id and a.student_id=v_student.id;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_deadline:=case when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at+v_exam.duration_minutes*interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at+v_exam.duration_minutes*interval '1 minute') end;
  select coalesce(jsonb_agg(jsonb_build_object('exam_question_id',sa.exam_question_id,
    'selected_option_id',sa.selected_option_id,'answer_text',sa.answer_text)
    order by sa.answered_at,sa.id),'[]'::jsonb) into v_answers
  from public.v5_student_answers sa where sa.attempt_id=v_attempt.id;
  return jsonb_build_object('status',v_attempt.status,'answers',v_answers,
    'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at,
    'deadline_at',v_deadline,'server_now',clock_timestamp());
end $$;

revoke all on function public.v5_student_save_descriptive_answer(uuid,bigint,text,text) from public;
grant execute on function public.v5_student_save_descriptive_answer(uuid,bigint,text,text) to anon,authenticated;
revoke all on function public.v5_student_get_attempt_state(uuid,text) from public;
grant execute on function public.v5_student_get_attempt_state(uuid,text) to anon,authenticated;
