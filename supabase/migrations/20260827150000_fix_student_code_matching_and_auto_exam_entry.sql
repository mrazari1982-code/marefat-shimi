create or replace function public.v5_start_exam(p_token text, p_student_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.v5_exam_links;
  v_exam public.v5_exams;
  v_student public.v5_students;
  v_attempt public.v5_attempts;
  v_attempt_count integer;
  v_time_ok boolean;
begin
  select l.* into v_link
  from public.v5_exam_links l
  where lower(trim(l.token)) = lower(trim(p_token))
    and l.is_active = true
    and (l.expires_at is null or now() <= l.expires_at)
  limit 1;
  if v_link.id is null then raise exception 'INVALID_EXAM_LINK'; end if;

  select e.* into v_exam from public.v5_exams e where e.id = v_link.exam_id;
  if v_exam.id is null then raise exception 'EXAM_NOT_FOUND'; end if;
  if v_exam.status::text <> 'published' then raise exception 'EXAM_NOT_PUBLISHED'; end if;
  if v_exam.start_at is not null and now() < v_exam.start_at then raise exception 'EXAM_NOT_STARTED'; end if;
  if v_exam.end_at is not null and now() > v_exam.end_at then raise exception 'EXAM_CLOSED'; end if;

  select s.* into v_student
  from public.v5_students s
  where lower(trim(s.student_code)) = lower(trim(p_student_code))
    and s.is_active = true
  limit 1;
  if v_student.id is null then raise exception 'STUDENT_NOT_FOUND'; end if;

  select a.* into v_attempt
  from public.v5_attempts a
  where a.exam_id = v_exam.id and a.student_id = v_student.id
  order by a.started_at desc nulls last
  limit 1;

  if v_attempt.id is not null then
    if v_attempt.status = 'started' then
      v_time_ok := public.v5_check_attempt_time(v_attempt.id);
      select a.* into v_attempt from public.v5_attempts a where a.id = v_attempt.id;
      if v_time_ok and v_attempt.status = 'started' then
        return jsonb_build_object('status','started','attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,'student_name',v_student.full_name,'student_code',v_student.student_code,'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at);
      end if;
    end if;
    if v_attempt.status = 'submitted' then
      return jsonb_build_object('status','already_submitted','attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,'student_name',v_student.full_name,'student_code',v_student.student_code);
    end if;
    if v_attempt.status = 'expired' then
      return jsonb_build_object('status','expired','attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,'student_name',v_student.full_name,'student_code',v_student.student_code);
    end if;
  end if;

  select count(*)::int into v_attempt_count
  from public.v5_attempts a
  where a.exam_id = v_exam.id and a.student_id = v_student.id;
  if v_link.max_attempts_per_student is not null and v_attempt_count >= v_link.max_attempts_per_student then
    raise exception 'MAX_ATTEMPTS_REACHED';
  end if;

  insert into public.v5_attempts(exam_id, student_id, status, started_at)
  values(v_exam.id, v_student.id, 'started', now())
  returning * into v_attempt;

  return jsonb_build_object('status','started','attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,'student_name',v_student.full_name,'student_code',v_student.student_code,'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at);
end;
$$;

revoke all on function public.v5_start_exam(text,text) from public;
grant execute on function public.v5_start_exam(text,text) to anon, authenticated;