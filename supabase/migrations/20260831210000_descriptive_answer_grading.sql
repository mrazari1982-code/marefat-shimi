-- Descriptive answers and staff manual grading. Apply on staging before production.

alter table public.v5_attempts
  add column if not exists grading_status text not null default 'graded'
    check (grading_status in ('graded','pending_manual'));

alter table public.v5_student_answers
  add column if not exists graded_by uuid references auth.users(id),
  add column if not exists graded_at timestamptz,
  add column if not exists grading_feedback text;

drop function if exists public.v5_student_get_exam_questions(uuid,text);
create or replace function public.v5_student_get_exam_questions(
  p_attempt_id uuid,
  p_session_token text
) returns table(
  id bigint,
  question_order integer,
  score numeric,
  question_type public.v5_question_type,
  question_text text,
  option_id bigint,
  option_key text,
  option_text text,
  sort_order integer
)
language plpgsql security definer
set search_path = pg_catalog, public, v5_auth_private
as $$
declare
  v_student public.v5_students%rowtype;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  if not exists (
    select 1 from public.v5_attempts a
    where a.id=p_attempt_id and a.student_id=v_student.id and a.status='started'
  ) then
    raise exception 'ATTEMPT_NOT_AVAILABLE' using errcode='42501';
  end if;

  return query
  select eq.id,eq.question_order,eq.score,q.question_type,q.question_text,
         o.id,o.option_key,o.option_text,o.sort_order
  from public.v5_attempts a
  join public.v5_exam_questions eq on eq.exam_id=a.exam_id
  join public.v5_questions q on q.id=eq.question_id
  left join public.v5_question_options o on o.question_id=q.id
  where a.id=p_attempt_id and a.student_id=v_student.id
  order by eq.question_order,o.sort_order nulls last;
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
  v_answer text := btrim(coalesce(p_answer_text,''));
  v_deadline timestamptz;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  if char_length(v_answer) > 10000 then raise exception 'ANSWER_TOO_LONG'; end if;

  select a.* into v_attempt from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id = v_student.id and a.status = 'started'
  for update;
  if not found then raise exception 'ATTEMPT_NOT_AVAILABLE' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_deadline := case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at + v_exam.duration_minutes * interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at + v_exam.duration_minutes * interval '1 minute')
  end;
  if v_deadline is not null and clock_timestamp() >= v_deadline then
    update public.v5_attempts set status='expired' where id=v_attempt.id;
    return jsonb_build_object('saved',false,'status','expired');
  end if;

  select q.question_type into v_question_type
  from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id
  where eq.id=p_exam_question_id and eq.exam_id=v_attempt.exam_id;
  if not found then raise exception 'QUESTION_NOT_IN_ATTEMPT'; end if;
  if v_question_type <> 'descriptive' then raise exception 'QUESTION_NOT_DESCRIPTIVE'; end if;

  if v_answer='' then
    delete from public.v5_student_answers
    where attempt_id=p_attempt_id and exam_question_id=p_exam_question_id;
  else
    insert into public.v5_student_answers(
      attempt_id,exam_question_id,answer_text,selected_option_id,
      is_correct,score_awarded,answered_at,graded_by,graded_at,grading_feedback
    ) values (
      p_attempt_id,p_exam_question_id,v_answer,null,
      null,0,clock_timestamp(),null,null,null
    )
    on conflict (attempt_id,exam_question_id) do update set
      answer_text=excluded.answer_text,selected_option_id=null,is_correct=null,
      score_awarded=0,answered_at=excluded.answered_at,graded_by=null,graded_at=null,
      grading_feedback=null;
  end if;
  return jsonb_build_object('saved',true,'status','started','answered',v_answer<>'');
end
$$;

create or replace function public.v5_student_get_attempt_state(
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
  v_answers jsonb;
  v_deadline timestamptz;
begin
  v_student := v5_auth_private.student_for_token(p_session_token);
  select a.* into v_attempt from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
  v_deadline := case
    when v_exam.end_at is null and v_exam.duration_minutes is null then null
    when v_exam.end_at is null then v_attempt.started_at + v_exam.duration_minutes * interval '1 minute'
    when v_exam.duration_minutes is null then v_exam.end_at
    else least(v_exam.end_at,v_attempt.started_at + v_exam.duration_minutes * interval '1 minute')
  end;
  select coalesce(jsonb_agg(jsonb_build_object(
    'exam_question_id',sa.exam_question_id,
    'selected_option_id',sa.selected_option_id,
    'answer_text',sa.answer_text
  ) order by sa.answered_at,sa.id),'[]'::jsonb) into v_answers
  from public.v5_student_answers sa where sa.attempt_id=v_attempt.id;
  return jsonb_build_object(
    'status',v_attempt.status,'answers',v_answers,'duration_minutes',v_exam.duration_minutes,
    'started_at',v_attempt.started_at,'deadline_at',v_deadline,'server_now',clock_timestamp()
  );
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
  select a.* into v_attempt from public.v5_attempts a
  where a.id=p_attempt_id and a.student_id=v_student.id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND' using errcode='42501'; end if;
  select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;

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
    status='submitted',submitted_at=coalesce(submitted_at,clock_timestamp()),
    correct_count=v_correct,wrong_count=v_wrong,blank_count=v_blank,total_score=v_total_score,
    percentage=v_percentage,
    grading_status=case when v_pending_manual_count>0 then 'pending_manual' else 'graded' end
  where id=v_attempt.id;

  return jsonb_build_object(
    'status','submitted','show_result',v_exam.show_result_to_student,
    'result_visible',v_exam.show_result_to_student,
    'grading_status',case when v_pending_manual_count>0 then 'pending_manual' else 'graded' end,
    'pending_manual_count',v_pending_manual_count,
    'correct_answers',v_correct,'wrong_answers',v_wrong,'unanswered_questions',v_blank,
    'total_score',v_total_score,'max_score',v_max_score,
    'percentage',case when v_pending_manual_count>0 then null else v_percentage end
  );
end
$$;

revoke all on function public.v5_student_get_exam_questions(uuid,text) from public;
grant execute on function public.v5_student_get_exam_questions(uuid,text) to anon,authenticated;
revoke all on function public.v5_student_get_attempt_state(uuid,text) from public;
grant execute on function public.v5_student_get_attempt_state(uuid,text) to anon,authenticated;
revoke all on function public.v5_student_save_descriptive_answer(uuid,bigint,text,text) from public;
grant execute on function public.v5_student_save_descriptive_answer(uuid,bigint,text,text) to anon,authenticated;
revoke all on function public.v5_student_submit_attempt(uuid,text) from public;
grant execute on function public.v5_student_submit_attempt(uuid,text) to anon,authenticated;

create or replace function public.v5_admin_pending_descriptive_answers()
returns table(answer_id bigint,attempt_id uuid,student_name text,student_code text,exam_title text,question_order integer,question_text text,answer_text text,answer_key text,grading_rubric text,max_score numeric,grading_feedback text)
language plpgsql security definer set search_path = pg_catalog, public as $$
begin
 if (select auth.uid()) is null or not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED' using errcode='42501'; end if;
 return query select sa.id,a.id,s.full_name,s.student_code,e.title,eq.question_order,q.question_text,sa.answer_text,q.answer_key,q.grading_rubric,eq.score,sa.grading_feedback
 from public.v5_student_answers sa join public.v5_attempts a on a.id=sa.attempt_id join public.v5_students s on s.id=a.student_id
 join public.v5_exams e on e.id=a.exam_id join public.v5_exam_questions eq on eq.id=sa.exam_question_id join public.v5_questions q on q.id=eq.question_id
 where a.status='submitted' and q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null
 order by a.submitted_at,eq.question_order,sa.id;
end $$;

create or replace function public.v5_admin_grade_descriptive_answer(p_answer_id bigint,p_score numeric,p_feedback text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_attempt_id uuid; v_max_score numeric; v_pending integer; v_total numeric; v_max_total numeric; v_percentage numeric;
begin
 if (select auth.uid()) is null or not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED' using errcode='42501'; end if;
 select sa.attempt_id,eq.score into v_attempt_id,v_max_score from public.v5_student_answers sa
 join public.v5_exam_questions eq on eq.id=sa.exam_question_id join public.v5_questions q on q.id=eq.question_id join public.v5_attempts a on a.id=sa.attempt_id
 where sa.id=p_answer_id and q.question_type='descriptive' and a.status='submitted' for update of sa,a;
 if not found then raise exception 'ANSWER_NOT_FOUND'; end if;
 if p_score is null or p_score < 0 or p_score > v_max_score then raise exception 'SCORE_OUT_OF_RANGE'; end if;
 update public.v5_student_answers set score_awarded=p_score,is_correct=case when p_score=v_max_score then true when p_score=0 then false else null end,
 graded_by = auth.uid(),graded_at = clock_timestamp(),grading_feedback=nullif(btrim(coalesce(p_feedback,'')),'') where id=p_answer_id;
 select count(*) into v_pending from public.v5_student_answers sa join public.v5_exam_questions eq on eq.id=sa.exam_question_id join public.v5_questions q on q.id=eq.question_id
 where sa.attempt_id=v_attempt_id and q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null;
 select coalesce(sum(case when q.question_type<>'descriptive' and qo.is_correct then eq.score
   when q.question_type='descriptive' then coalesce(sa.score_awarded,0) else 0 end),0),coalesce(sum(eq.score),0)
 into v_total,v_max_total from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id
 left join public.v5_student_answers sa on sa.attempt_id=v_attempt_id and sa.exam_question_id=eq.id
 left join public.v5_question_options qo on qo.id=sa.selected_option_id
 where eq.exam_id=(select exam_id from public.v5_attempts where id=v_attempt_id);
 v_percentage:=case when v_max_total>0 then round(v_total*100/v_max_total,2) else 0 end;
 update public.v5_attempts set total_score=v_total,percentage=v_percentage,grading_status=case when v_pending>0 then 'pending_manual' else 'graded' end where id=v_attempt_id;
 return jsonb_build_object('answer_id',p_answer_id,'attempt_id',v_attempt_id,'grading_status',case when v_pending>0 then 'pending_manual' else 'graded' end,
 'pending_manual_count',v_pending,'total_score',v_total,'percentage',case when v_pending>0 then null else v_percentage end);
end $$;

revoke all on function public.v5_admin_pending_descriptive_answers() from public,anon;
grant execute on function public.v5_admin_pending_descriptive_answers() to authenticated;
revoke all on function public.v5_admin_grade_descriptive_answer(bigint,numeric,text) from public,anon;
grant execute on function public.v5_admin_grade_descriptive_answer(bigint,numeric,text) to authenticated;

create or replace function public.v5_student_dashboard_v2(p_session_token text,p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, v5_auth_private as $$
declare v_student public.v5_students%rowtype; v_profile jsonb; v_summary jsonb; v_attempts jsonb; v_limit integer;
begin
 v_student:=v5_auth_private.student_for_token(p_session_token);
 if p_limit is null or p_limit<0 then raise exception 'INVALID_LIMIT'; end if; v_limit:=least(p_limit,100);
 select jsonb_build_object('student_code',s.student_code,'full_name',s.full_name,'grade_name',g.name,'field_name',f.name,'class_name',c.name)
 into v_profile from public.v5_students s left join public.v5_grades g on g.id=s.grade_id left join public.v5_fields f on f.id=s.field_id
 left join public.v5_classes c on c.id=s.class_id where s.id=v_student.id;
 with own as (
  select a.*,e.exam_code,e.title exam_title,e.status::text exam_status,
   (a.status='submitted' and a.grading_status<>'pending_manual' and e.show_result_to_student is true) result_visible
  from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where a.student_id=v_student.id
 ) select jsonb_build_object('attempt_count',count(*),'submitted_count',count(*) filter(where status='submitted'),
  'in_progress_count',count(*) filter(where status='started'),'visible_result_count',count(*) filter(where result_visible),
  'average_percentage',avg(percentage) filter(where result_visible),'correct_count',coalesce(sum(correct_count) filter(where result_visible),0),
  'wrong_count',coalesce(sum(wrong_count) filter(where result_visible),0),'blank_count',coalesce(sum(blank_count) filter(where result_visible),0)) into v_summary from own;
 with own as (
  select a.*,e.exam_code,e.title exam_title,e.status::text exam_status,e.end_at,e.duration_minutes,
   case when e.end_at is null and e.duration_minutes is null then null when e.end_at is null then a.started_at+e.duration_minutes*interval '1 minute'
    when e.duration_minutes is null then e.end_at else least(e.end_at,a.started_at+e.duration_minutes*interval '1 minute') end deadline_at,
   (a.status='submitted' and a.grading_status<>'pending_manual' and e.show_result_to_student is true) result_visible
  from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where a.student_id=v_student.id
 ), limited as (select * from own order by started_at desc nulls last,id desc limit v_limit)
 select coalesce(jsonb_agg(jsonb_build_object('attempt_id',id,'exam_code',exam_code,'exam_title',exam_title,'status',status,
  'grading_status',grading_status,'started_at',started_at,'submitted_at',submitted_at,'result_visible',result_visible,
  'detail_visible',result_visible and exam_status='closed','percentage',case when result_visible then percentage else null end,
  'correct_count',case when result_visible then correct_count else null end,'wrong_count',case when result_visible then wrong_count else null end,
  'blank_count',case when result_visible then blank_count else null end,'can_resume',status='started' and exam_status='published' and (deadline_at is null or deadline_at>clock_timestamp()),
  'resume_reason',case when status='submitted' then 'submitted' when status='expired' then 'expired' when exam_status<>'published' then 'exam_closed'
   when deadline_at is not null and deadline_at<=clock_timestamp() then 'deadline_passed' else null end) order by started_at desc nulls last,id desc),'[]'::jsonb)
 into v_attempts from limited;
 return jsonb_build_object('profile',v_profile,'summary',v_summary,'attempts',v_attempts);
end $$;

create or replace function public.v5_student_get_result_v2(p_attempt_id uuid,p_session_token text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, v5_auth_private as $$
declare v_student public.v5_students%rowtype; v_attempt public.v5_attempts%rowtype; v_exam public.v5_exams%rowtype; v_details jsonb; v_visible boolean;
begin
 v_student:=v5_auth_private.student_for_token(p_session_token);
 select a.* into v_attempt from public.v5_attempts a where a.id=p_attempt_id and a.student_id=v_student.id and a.status='submitted';
 if not found then raise exception 'RESULT_NOT_FOUND' using errcode='42501'; end if;
 select e.* into strict v_exam from public.v5_exams e where e.id=v_attempt.exam_id;
 v_visible:=v_exam.show_result_to_student is true and v_attempt.grading_status<>'pending_manual';
 if not v_visible then return jsonb_build_object('attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
  'exam_title',v_exam.title,'exam_code',v_exam.exam_code,'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
  'grading_status',v_attempt.grading_status,'result_visible',false,'detail_visible',false,'percentage',null,'correct_count',null,
  'wrong_count',null,'blank_count',null,'total_score',null,'details',null); end if;
 if v_exam.status='closed' then
  select coalesce(jsonb_agg(jsonb_build_object('question_order',eq.question_order,'question_text',q.question_text,
   'answer_text',coalesce(o.option_key||' — '||o.option_text,sa.answer_text),'is_correct',sa.is_correct,'score_awarded',coalesce(sa.score_awarded,0),
   'grading_feedback',sa.grading_feedback,'correct_option_key',co.option_key,'correct_option_text',co.option_text) order by eq.question_order),'[]'::jsonb)
  into v_details from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id
  left join public.v5_student_answers sa on sa.attempt_id=v_attempt.id and sa.exam_question_id=eq.id
  left join public.v5_question_options o on o.id=sa.selected_option_id left join public.v5_question_options co on co.question_id=eq.question_id and co.is_correct
  where eq.exam_id=v_exam.id;
 else v_details:='[]'::jsonb; end if;
 return jsonb_build_object('attempt_id',v_attempt.id,'student_name',v_student.full_name,'student_code',v_student.student_code,
  'exam_title',v_exam.title,'exam_code',v_exam.exam_code,'status',v_attempt.status,'submitted_at',v_attempt.submitted_at,
  'grading_status',v_attempt.grading_status,'result_visible',true,'detail_visible',v_exam.status='closed','percentage',v_attempt.percentage,
  'correct_count',v_attempt.correct_count,'wrong_count',v_attempt.wrong_count,'blank_count',v_attempt.blank_count,
  'total_score',v_attempt.total_score,'details',v_details);
end $$;

revoke all on function public.v5_student_dashboard_v2(text,integer) from public;
grant execute on function public.v5_student_dashboard_v2(text,integer) to anon,authenticated;
revoke all on function public.v5_student_get_result_v2(uuid,text) from public;
grant execute on function public.v5_student_get_result_v2(uuid,text) to anon,authenticated;
