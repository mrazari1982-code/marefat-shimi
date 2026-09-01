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
  v_deadline timestamptz;
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
  if v_attempt.status <> 'started' then
    raise exception 'ATTEMPT_NOT_STARTED' using errcode='55000';
  end if;

  select e.* into strict v_exam
  from public.v5_exams e
  where e.id=v_attempt.exam_id;
  v_deadline := case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at + v_exam.duration_minutes * interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at + v_exam.duration_minutes * interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp() > v_deadline then
    update public.v5_attempts
      set status='expired'
    where id=v_attempt.id;
    raise exception 'ATTEMPT_EXPIRED' using errcode='55000';
  end if;

  select
    count(*) filter (where q.question_type<>'descriptive' and sa.selected_option_id is not null and qo.is_correct),
    count(*) filter (where q.question_type<>'descriptive' and sa.selected_option_id is not null and not qo.is_correct),
    count(*) filter (where (q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is null)
                          or (q.question_type<>'descriptive' and sa.selected_option_id is null)),
    count(*) filter (where q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null),
    coalesce(sum(case when q.question_type<>'descriptive' and qo.is_correct then eq.score
                      when q.question_type='descriptive' then coalesce(sa.score_awarded,0) else 0 end),0),
    coalesce(sum(eq.score),0)
  into v_correct,v_wrong,v_blank,v_pending_manual_count,v_total_score,v_max_score
  from public.v5_exam_questions eq
  join public.v5_questions q on q.id=eq.question_id
  left join public.v5_student_answers sa on sa.attempt_id=v_attempt.id and sa.exam_question_id=eq.id
  left join public.v5_question_options qo on qo.id=sa.selected_option_id
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

revoke all on function public.v5_student_submit_attempt(uuid,text) from public;
grant execute on function public.v5_student_submit_attempt(uuid,text) to anon,authenticated;
