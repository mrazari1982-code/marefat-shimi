-- Keep objective answer rows and attempt aggregates consistent for mixed exams.
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
    update public.v5_attempts set status='expired' where id=v_attempt.id;
    return jsonb_build_object(
      'status','expired',
      'show_result',false,
      'result_visible',false
    );
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

revoke all on function public.v5_student_submit_attempt(uuid,text) from public;
grant execute on function public.v5_student_submit_attempt(uuid,text) to anon,authenticated;

create or replace function public.v5_admin_grade_descriptive_answer(
  p_answer_id bigint,
  p_score numeric,
  p_feedback text default null
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_attempt_id uuid;
  v_exam_id bigint;
  v_max_score numeric;
  v_pending integer;
  v_correct integer;
  v_wrong integer;
  v_blank integer;
  v_total numeric;
  v_max_total numeric;
  v_percentage numeric;
begin
  if (select auth.uid()) is null or not public.v5_is_staff() then
    raise exception 'STAFF_ACCESS_REQUIRED' using errcode='42501';
  end if;
  select sa.attempt_id,a.exam_id,eq.score into v_attempt_id,v_exam_id,v_max_score
  from public.v5_student_answers sa
  join public.v5_exam_questions eq on eq.id=sa.exam_question_id
  join public.v5_questions q on q.id=eq.question_id
  join public.v5_attempts a on a.id=sa.attempt_id
  where sa.id=p_answer_id and q.question_type='descriptive' and a.status='submitted'
  for update of sa,a;
  if not found then raise exception 'ANSWER_NOT_FOUND'; end if;
  if p_score is null or p_score<0 or p_score>v_max_score then raise exception 'SCORE_OUT_OF_RANGE'; end if;

  update public.v5_student_answers set
    score_awarded=p_score,
    is_correct=case when p_score=v_max_score then true when p_score=0 then false else null end,
    graded_by=auth.uid(),graded_at=clock_timestamp(),
    grading_feedback=nullif(btrim(coalesce(p_feedback,'')),'')
  where id=p_answer_id;

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
  where sa.attempt_id=v_attempt_id
    and sa.exam_question_id=eq.id
    and q.question_type<>'descriptive'
    and sa.selected_option_id is not null;

  select
    count(*) filter (where q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null),
    count(*) filter (where q.question_type<>'descriptive' and sa.selected_option_id is not null and sa.is_correct is true),
    count(*) filter (where q.question_type<>'descriptive' and sa.selected_option_id is not null and sa.is_correct is false),
    count(*) filter (where (q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is null)
                          or (q.question_type<>'descriptive' and sa.selected_option_id is null)),
    coalesce(sum(sa.score_awarded),0),
    coalesce(sum(eq.score),0)
  into v_pending,v_correct,v_wrong,v_blank,v_total,v_max_total
  from public.v5_exam_questions eq
  join public.v5_questions q on q.id=eq.question_id
  left join public.v5_student_answers sa on sa.attempt_id=v_attempt_id and sa.exam_question_id=eq.id
  where eq.exam_id=v_exam_id;

  v_percentage:=case when v_max_total>0 then round(v_total*100/v_max_total,2) else 0 end;
  update public.v5_attempts set
    correct_count=v_correct,wrong_count=v_wrong,blank_count=v_blank,
    total_score=v_total,percentage=v_percentage,
    grading_status=case when v_pending>0 then 'pending_manual' else 'graded' end
  where id=v_attempt_id;
  return jsonb_build_object(
    'answer_id',p_answer_id,'attempt_id',v_attempt_id,
    'grading_status',case when v_pending>0 then 'pending_manual' else 'graded' end,
    'pending_manual_count',v_pending,'total_score',v_total,
    'percentage',case when v_pending>0 then null else v_percentage end
  );
end
$$;

revoke all on function public.v5_admin_grade_descriptive_answer(bigint,numeric,text) from public,anon;
grant execute on function public.v5_admin_grade_descriptive_answer(bigint,numeric,text) to authenticated;
