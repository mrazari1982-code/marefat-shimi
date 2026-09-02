-- Keep the option separator ASCII-only so SQL transport cannot corrupt it.
create or replace function public.v5_student_get_result_v2(
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
  v_details jsonb;
  v_visible boolean;
begin
  v_student:=v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt
  from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id and a.status='submitted';
  if not found then raise exception 'RESULT_NOT_FOUND' using errcode='42501'; end if;

  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_visible:=v_exam.show_result_to_student is true and v_attempt.grading_status<>'pending_manual';
  if not v_visible then
    return jsonb_build_object(
      'attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
      'exam_title',v_exam.title,'exam_code',v_exam.exam_code,'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
      'grading_status',v_attempt.grading_status,'result_visible',false,'detail_visible',false,'percentage',null,
      'correct_count',null,'wrong_count',null,'blank_count',null,'total_score',null,'details',null
    );
  end if;

  if v_exam.status='closed' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'question_order',eq.question_order,
      'question_text',q.question_text,
      'answer_text',coalesce(o.option_key||' - '||o.option_text,sa.answer_text),
      'is_correct',sa.is_correct,
      'score_awarded',coalesce(sa.score_awarded,0),
      'grading_feedback',sa.grading_feedback,
      'correct_option_key',co.option_key,
      'correct_option_text',co.option_text
    ) order by eq.question_order),'[]'::jsonb)
    into v_details
    from public.v5_exam_questions eq
    join public.v5_questions q on q.id=eq.question_id
    left join public.v5_student_answers sa on sa.attempt_id=v_attempt.id and sa.exam_question_id=eq.id
    left join public.v5_question_options o on o.id=sa.selected_option_id
    left join public.v5_question_options co on co.question_id=eq.question_id and co.is_correct
    where eq.exam_id=v_exam.id;
  else
    v_details:='[]'::jsonb;
  end if;

  return jsonb_build_object(
    'attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
    'exam_title',v_exam.title,'exam_code',v_exam.exam_code,'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
    'grading_status',v_attempt.grading_status,'result_visible',true,'detail_visible',v_exam.status='closed',
    'percentage',v_attempt.percentage,'correct_count',v_attempt.correct_count,'wrong_count',v_attempt.wrong_count,
    'blank_count',v_attempt.blank_count,'total_score',v_attempt.total_score,'details',v_details
  );
end
$$;

revoke all on function public.v5_student_get_result_v2(uuid,text) from public;
grant execute on function public.v5_student_get_result_v2(uuid,text) to anon,authenticated;
