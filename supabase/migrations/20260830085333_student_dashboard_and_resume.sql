create or replace function public.v5_student_dashboard(
  p_session_token text,
  p_limit integer default 100
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
  v_limit integer;
  v_profile jsonb;
  v_summary jsonb;
  v_attempts jsonb;
  v_now timestamptz;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  if p_limit is null or p_limit < 0 then
    raise exception 'INVALID_LIMIT';
  end if;
  v_limit := least(p_limit,100);
  v_now := clock_timestamp();

  select jsonb_build_object(
    'student_code',v_student.student_code,
    'full_name',v_student.full_name,
    'grade_name',g.name,
    'field_name',f.name,
    'class_name',c.name
  ) into v_profile
  from public.v5_students s
  left join public.v5_grades g on g.id=s.grade_id
  left join public.v5_fields f on f.id=s.field_id
  left join public.v5_classes c on c.id=s.class_id
  where s.id=v_student.id;

  with attempt_source as (
    select
      a.id,
      a.exam_id,
      a.status::text as status,
      a.started_at,
      a.submitted_at,
      a.percentage,
      a.correct_count,
      a.wrong_count,
      a.blank_count,
      e.exam_code,
      e.title as exam_title,
      e.status::text as exam_status,
      e.duration_minutes,
      e.end_at,
      case
        when e.end_at is null then a.started_at + e.duration_minutes * interval '1 minute'
        when e.duration_minutes is null or a.started_at is null then e.end_at
        else least(e.end_at,a.started_at + e.duration_minutes * interval '1 minute')
      end as deadline_at,
      (a.status = 'submitted' and e.show_result_to_student is true) as result_visible,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.percentage else null end as visible_percentage,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.correct_count else null end as visible_correct_count,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.wrong_count else null end as visible_wrong_count,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.blank_count else null end as visible_blank_count
    from public.v5_attempts a
    join public.v5_exams e on e.id=a.exam_id
    where a.student_id = v_student.id
  )
  select jsonb_build_object(
    'attempt_count',count(*),
    'submitted_count',count(*) filter (where status='submitted'),
    'in_progress_count',count(*) filter (where status='started'),
    'visible_result_count',count(*) filter (where result_visible),
    'average_percentage',avg(visible_percentage) filter (where result_visible),
    'correct_count',coalesce(sum(visible_correct_count) filter (where result_visible),0),
    'wrong_count',coalesce(sum(visible_wrong_count) filter (where result_visible),0),
    'blank_count',coalesce(sum(visible_blank_count) filter (where result_visible),0)
  ) into v_summary
  from attempt_source;

  with attempt_source as (
    select
      a.id,
      a.exam_id,
      a.status::text as status,
      a.started_at,
      a.submitted_at,
      e.exam_code,
      e.title as exam_title,
      e.status::text as exam_status,
      case
        when e.end_at is null then a.started_at + e.duration_minutes * interval '1 minute'
        when e.duration_minutes is null or a.started_at is null then e.end_at
        else least(e.end_at,a.started_at + e.duration_minutes * interval '1 minute')
      end as deadline_at,
      (a.status = 'submitted' and e.show_result_to_student is true) as result_visible,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.percentage else null end as visible_percentage,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.correct_count else null end as visible_correct_count,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.wrong_count else null end as visible_wrong_count,
      case when a.status = 'submitted' and e.show_result_to_student is true
           then a.blank_count else null end as visible_blank_count
    from public.v5_attempts a
    join public.v5_exams e on e.id=a.exam_id
    where a.student_id = v_student.id
  ), attempts_with_resume as (
    select *,
      status='started' and exam_status='published'
        and (deadline_at is null or deadline_at>v_now) as can_resume,
      case
        when status='submitted' then 'submitted'
        when status='expired' then 'expired'
        when exam_status<>'published' then 'exam_closed'
        when deadline_at is not null and deadline_at<=v_now then 'deadline_passed'
        else null
      end as resume_reason
    from attempt_source
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'attempt_id',id,
    'exam_code',exam_code,
    'exam_title',exam_title,
    'status',status,
    'started_at',started_at,
    'submitted_at',submitted_at,
    'result_visible',result_visible,
    'detail_visible',result_visible and exam_status='closed',
    'percentage',visible_percentage,
    'correct_count',visible_correct_count,
    'wrong_count',visible_wrong_count,
    'blank_count',visible_blank_count,
    'can_resume',can_resume,
    'resume_reason',resume_reason
  ) order by started_at desc nulls last,id desc),'[]'::jsonb)
  into v_attempts
  from (
    select * from attempts_with_resume
    order by started_at desc nulls last,id desc
    limit v_limit
  ) limited_attempts;

  return jsonb_build_object('profile',v_profile,'summary',v_summary,'attempts',v_attempts);
end;
$$;

revoke all on function public.v5_student_dashboard(text,integer) from public;
grant execute on function public.v5_student_dashboard(text,integer) to anon,authenticated;

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
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt from public.v5_attempts a
   where a.id=p_attempt_id and a.student_id=v_student.id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  if v_attempt.status = 'submitted' then raise exception 'ATTEMPT_SUBMITTED'; end if;
  if v_attempt.status = 'expired' then raise exception 'ATTEMPT_EXPIRED'; end if;
  if v_exam.status <> 'published' then raise exception 'EXAM_CLOSED'; end if;
  v_deadline := case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at + v_exam.duration_minutes * interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at + v_exam.duration_minutes * interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp() >= v_deadline then
    update public.v5_attempts set status='expired' where id=v_attempt.id;
    return jsonb_build_object('available',false,'reason','deadline_passed');
  end if;
  return jsonb_build_object(
    'available',true,'attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,
    'student_name',v_student.full_name,'status',v_attempt.status,
    'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at,
    'deadline_at',v_deadline,'server_now',clock_timestamp()
  );
end
$$;

create or replace function public.v5_student_get_result(
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
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt
  from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id and a.status='submitted';
  if not found then raise exception 'RESULT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;

  if not v_exam.show_result_to_student then
    return jsonb_build_object(
      'attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
      'exam_title',v_exam.title,'exam_code',v_exam.exam_code,
      'correct_count',null,'wrong_count',null,'blank_count',null,'total_score',null,'percentage',null,
      'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
      'result_visible',false,'detail_visible',false,'details',null
    );
  end if;

  if v_exam.status <> 'closed' then
    return jsonb_build_object(
      'attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
      'exam_title',v_exam.title,'exam_code',v_exam.exam_code,
      'correct_count',v_attempt.correct_count,'wrong_count',v_attempt.wrong_count,
      'blank_count',v_attempt.blank_count,'total_score',v_attempt.total_score,'percentage',v_attempt.percentage,
      'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
      'result_visible',true,'detail_visible',false,'details','[]'::jsonb
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'question_order',eq.question_order,
    'question_text',q.question_text,
    'answer_text',coalesce(selected_option.option_key || ' — ' || selected_option.option_text,sa.answer_text),
    'is_correct',coalesce(sa.is_correct,false),
    'score_awarded',coalesce(sa.score_awarded,0),
    'correct_option_key',correct_option.option_key,
    'correct_option_text',correct_option.option_text
  ) order by eq.question_order),'[]'::jsonb)
  into v_details
  from public.v5_exam_questions eq
  join public.v5_questions q on q.id=eq.question_id
  left join public.v5_student_answers sa on sa.attempt_id=v_attempt.id and sa.exam_question_id=eq.id
  left join public.v5_question_options selected_option on selected_option.id=sa.selected_option_id
  left join public.v5_question_options correct_option on correct_option.question_id=eq.question_id and correct_option.is_correct
  where eq.exam_id=v_exam.id;

  return jsonb_build_object(
    'attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
    'exam_title',v_exam.title,'exam_code',v_exam.exam_code,
    'correct_count',v_attempt.correct_count,'wrong_count',v_attempt.wrong_count,
    'blank_count',v_attempt.blank_count,'total_score',v_attempt.total_score,'percentage',v_attempt.percentage,
    'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
    'result_visible',true,'detail_visible',true,'details',v_details
  );
end
$$;

revoke all on function public.v5_student_resume_attempt(uuid,text) from public;
grant execute on function public.v5_student_resume_attempt(uuid,text) to anon,authenticated;
revoke all on function public.v5_student_get_result(uuid,text) from public;
grant execute on function public.v5_student_get_result(uuid,text) to anon,authenticated;
