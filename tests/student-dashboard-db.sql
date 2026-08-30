begin;

insert into v5_auth_private.credentials(student_id,password_hash)
select id,extensions.crypt('ownership-test-password-a',extensions.gen_salt('bf',10))
from public.v5_students where student_code='STAGING-STUDENT-001'
on conflict(student_id) do update set password_hash=excluded.password_hash,updated_at=clock_timestamp();
insert into v5_auth_private.credentials(student_id,password_hash)
select id,extensions.crypt('ownership-test-password-b',extensions.gen_salt('bf',10))
from public.v5_students where student_code='STAGING-STUDENT-002'
on conflict(student_id) do update set password_hash=excluded.password_hash,updated_at=clock_timestamp();

do $$
declare
  student_a bigint;
  student_b bigint;
  fixture_now timestamptz := clock_timestamp();
  history_exam bigint; hidden_exam bigint; active_exam bigint; expired_exam bigint;
  closed_exam bigint; deadline_exam bigint; earlier_exam bigint; details_exam bigint; foreign_exam bigint;
  details_attempt uuid; details_subject bigint; details_question bigint; details_exam_question bigint; details_option bigint;
begin
  select id into strict student_a from public.v5_students where student_code='STAGING-STUDENT-001';
  select id into strict student_b from public.v5_students where student_code='STAGING-STUDENT-002';
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-HISTORY','Task 1 history','published',60,true) returning id into history_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-HIDDEN','Task 1 hidden','published',60,false) returning id into hidden_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,end_at,show_result_to_student) values('TASK1-ACTIVE','Task 1 active','published',60,fixture_now+interval '10 minutes',true) returning id into active_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-EXPIRED','Task 1 expired','published',60,true) returning id into expired_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-CLOSED','Task 1 closed','closed',60,true) returning id into closed_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-DEADLINE','Task 1 deadline','published',1,true) returning id into deadline_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,end_at,show_result_to_student) values('TASK1-EARLIER','Task 1 earlier deadline','published',60,fixture_now-interval '1 second',true) returning id into earlier_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-DETAILS','Task 1 details','closed',60,true) returning id into details_exam;
  insert into public.v5_exams(exam_code,title,status,duration_minutes,show_result_to_student) values('TASK1-FOREIGN','Task 1 foreign','published',60,true) returning id into foreign_exam;
  insert into public.v5_attempts(exam_id,student_id,status,started_at,submitted_at,correct_count,wrong_count,blank_count,percentage)
  select history_exam,student_a,'submitted',fixture_now-interval '2 hours'-g*interval '1 second',fixture_now-interval '2 hours'-g*interval '1 second',6,2,1,75 from generate_series(1,101) as g;
  insert into public.v5_attempts(exam_id,student_id,status,started_at,submitted_at,correct_count,wrong_count,blank_count,percentage) values(hidden_exam,student_a,'submitted',fixture_now-interval '1 minute',fixture_now-interval '1 minute',9,0,0,90);
  insert into public.v5_attempts(exam_id,student_id,status,started_at) values(active_exam,student_a,'started',fixture_now-interval '1 minute');
  insert into public.v5_attempts(exam_id,student_id,status,started_at) values(expired_exam,student_a,'expired',fixture_now-interval '2 minutes');
  insert into public.v5_attempts(exam_id,student_id,status,started_at) values(closed_exam,student_a,'started',fixture_now-interval '3 minutes');
  insert into public.v5_attempts(exam_id,student_id,status,started_at) values(deadline_exam,student_a,'started',fixture_now-interval '10 minutes');
  insert into public.v5_attempts(exam_id,student_id,status,started_at) values(earlier_exam,student_a,'started',fixture_now-interval '1 minute');
  select id into strict details_subject from public.v5_subjects order by id limit 1;
  insert into public.v5_questions(subject_id,question_text) values(details_subject,'Task 2 detail question') returning id into details_question;
  insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order) values(details_question,'A','Task 2 correct',true,1) returning id into details_option;
  insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order) values(details_question,'B','Task 2 wrong',false,2);
  insert into public.v5_exam_questions(exam_id,question_id,question_order,score) values(details_exam,details_question,1,1) returning id into details_exam_question;
  insert into public.v5_attempts(exam_id,student_id,status,started_at,submitted_at,correct_count,wrong_count,blank_count,total_score,percentage) values(details_exam,student_a,'submitted',fixture_now-interval '4 minutes',fixture_now-interval '4 minutes',7,1,0,1,87.5) returning id into details_attempt;
  insert into public.v5_student_answers(attempt_id,exam_question_id,selected_option_id,is_correct,score_awarded) values(details_attempt,details_exam_question,details_option,true,1);
  insert into public.v5_attempts(exam_id,student_id,status,started_at,submitted_at) values(foreign_exam,student_b,'submitted',fixture_now-interval '30 seconds',fixture_now-interval '30 seconds'),(foreign_exam,student_b,'submitted',fixture_now-interval '31 seconds',fixture_now-interval '31 seconds');
end $$;

set local role anon;
do $$
declare login_a jsonb := public.v5_student_login('STAGING-STUDENT-001','ownership-test-password-a'); login_b jsonb := public.v5_student_login('STAGING-STUDENT-002','ownership-test-password-b');
begin
  if login_a->>'token' is null or login_b->>'token' is null then raise exception 'DASHBOARD_LOGIN_FAILED'; end if;
  perform set_config('test.dashboard_token_a',login_a->>'token',true); perform set_config('test.dashboard_token_b',login_b->>'token',true);
end $$;
reset role;

do $$
declare
  token_a text := current_setting('test.dashboard_token_a'); token_b text := current_setting('test.dashboard_token_b');
  active_id uuid; submitted_id uuid; expired_id uuid; closed_id uuid; deadline_id uuid; earlier_id uuid; foreign_id uuid; detail_id uuid;
  active_resume jsonb; deadline_resume jsonb; earlier_resume jsonb; hidden_result jsonb; published_result jsonb; closed_result jsonb;
  active_end_at timestamptz; resume_keys text[]; result_keys text[]; detail_keys text[]; closed_detail jsonb; blocked boolean;
begin
  select a.id into strict active_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-ACTIVE';
  select a.id into strict submitted_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-HISTORY' order by a.id limit 1;
  select a.id into strict expired_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-EXPIRED';
  select a.id into strict closed_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-CLOSED';
  select a.id into strict deadline_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-DEADLINE';
  select a.id into strict earlier_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-EARLIER';
  select a.id into strict foreign_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-FOREIGN' limit 1;
  select a.id into strict detail_id from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where e.exam_code='TASK1-DETAILS';
  select end_at into strict active_end_at from public.v5_exams where id=(select exam_id from public.v5_attempts where id=active_id);

  set local role anon;
  active_resume := public.v5_student_resume_attempt(active_id,token_a);
  reset role;
  select array_agg(key order by key) into resume_keys from jsonb_object_keys(active_resume) key;
  if resume_keys is distinct from array['attempt_id','available','deadline_at','duration_minutes','exam_id','server_now','started_at','status','student_name','title'] then raise exception 'RESUME_CONTRACT_INVALID'; end if;
  if active_resume->>'available' <> 'true' or active_resume->>'attempt_id' <> active_id::text or active_resume->>'exam_id' is null or active_resume->>'title' is null or active_resume->>'student_name' is null or active_resume->>'status' <> 'started' or active_resume->>'duration_minutes' <> '60' or active_resume->>'started_at' is null or (active_resume->>'deadline_at')::timestamptz is distinct from active_end_at or active_resume->>'server_now' is null then raise exception 'ACTIVE_RESUME_INVALID'; end if;

  set local role anon;
  blocked:=false; begin perform public.v5_student_resume_attempt(foreign_id,token_a); exception when insufficient_privilege then blocked:=sqlerrm='ATTEMPT_NOT_FOUND'; end; if not blocked then raise exception 'CROSS_STUDENT_RESUME_ALLOWED'; end if;
  blocked:=false; begin perform public.v5_student_resume_attempt(submitted_id,token_a); exception when raise_exception then blocked:=sqlerrm='ATTEMPT_SUBMITTED'; end; if not blocked then raise exception 'SUBMITTED_RESUME_NOT_DENIED'; end if;
  blocked:=false; begin perform public.v5_student_resume_attempt(expired_id,token_a); exception when raise_exception then blocked:=sqlerrm='ATTEMPT_EXPIRED'; end; if not blocked then raise exception 'EXPIRED_RESUME_NOT_DENIED'; end if;
  blocked:=false; begin perform public.v5_student_resume_attempt(closed_id,token_a); exception when raise_exception then blocked:=sqlerrm='EXAM_CLOSED'; end; if not blocked then raise exception 'CLOSED_RESUME_NOT_DENIED'; end if;
  deadline_resume:=public.v5_student_resume_attempt(deadline_id,token_a);
  earlier_resume:=public.v5_student_resume_attempt(earlier_id,token_a); reset role;
  if deadline_resume is distinct from jsonb_build_object('available',false,'reason','deadline_passed') then raise exception 'DEADLINE_RESUME_NOT_STABLE'; end if;
  if (select status::text from public.v5_attempts where id=deadline_id) <> 'expired' then raise exception 'DEADLINE_EXPIRY_NOT_PERSISTED'; end if;
  if earlier_resume is distinct from jsonb_build_object('available',false,'reason','deadline_passed') then raise exception 'EARLIER_RESUME_NOT_STABLE'; end if;
  if (select status::text from public.v5_attempts where id=earlier_id) <> 'expired' then raise exception 'EARLIER_DEADLINE_NOT_USED'; end if;
  update public.v5_attempts set status='started' where id=deadline_id;
  update public.v5_attempts set status='started' where id=earlier_id;

  update public.v5_exams set show_result_to_student=false,status='published' where id=(select exam_id from public.v5_attempts where id=detail_id);
  set local role anon; hidden_result:=public.v5_student_get_result(detail_id,token_a); reset role;
  select array_agg(key order by key) into result_keys from jsonb_object_keys(hidden_result) key;
  if result_keys is distinct from array['attempt_id','blank_count','correct_count','detail_visible','details','exam_code','exam_title','percentage','result_visible','status','student_code','student_name','submitted_at','total_score','wrong_count'] then raise exception 'HIDDEN_RESULT_CONTRACT_INVALID'; end if;
  if hidden_result->'result_visible' <> 'false'::jsonb or hidden_result->'detail_visible' <> 'false'::jsonb or hidden_result->'correct_count' <> 'null'::jsonb or hidden_result->'wrong_count' <> 'null'::jsonb or hidden_result->'blank_count' <> 'null'::jsonb or hidden_result->'total_score' <> 'null'::jsonb or hidden_result->'percentage' <> 'null'::jsonb or hidden_result->'details' <> 'null'::jsonb or hidden_result->>'exam_title' <> 'Task 1 details' or hidden_result->>'status' <> 'submitted' or hidden_result->>'submitted_at' is null then raise exception 'HIDDEN_RESULT_DISCLOSED'; end if;
  update public.v5_exams set show_result_to_student=true,status='published' where id=(select exam_id from public.v5_attempts where id=detail_id);
  set local role anon; published_result:=public.v5_student_get_result(detail_id,token_a); reset role;
  select array_agg(key order by key) into result_keys from jsonb_object_keys(published_result) key;
  if result_keys is distinct from array['attempt_id','blank_count','correct_count','detail_visible','details','exam_code','exam_title','percentage','result_visible','status','student_code','student_name','submitted_at','total_score','wrong_count'] then raise exception 'PRE_CLOSE_RESULT_CONTRACT_INVALID'; end if;
  if published_result->'result_visible' <> 'true'::jsonb or published_result->'detail_visible' <> 'false'::jsonb or published_result->>'correct_count' <> '1' or published_result->>'wrong_count' <> '0' or published_result->>'blank_count' <> '0' or (published_result->>'total_score')::numeric <> 1 or (published_result->>'percentage')::numeric <> 100 or published_result->'details' <> '[]'::jsonb then raise exception 'PRE_CLOSE_RESULT_INVALID'; end if;
  update public.v5_exams set status='closed' where id=(select exam_id from public.v5_attempts where id=detail_id);
  set local role anon; closed_result:=public.v5_student_get_result(detail_id,token_a); reset role;
  select array_agg(key order by key) into result_keys from jsonb_object_keys(closed_result) key;
  if result_keys is distinct from array['attempt_id','blank_count','correct_count','detail_visible','details','exam_code','exam_title','percentage','result_visible','status','student_code','student_name','submitted_at','total_score','wrong_count'] then raise exception 'CLOSED_RESULT_CONTRACT_INVALID'; end if;
  if closed_result->'result_visible' <> 'true'::jsonb or closed_result->'detail_visible' <> 'true'::jsonb or jsonb_array_length(closed_result->'details') <> 1 then raise exception 'POST_CLOSE_DETAILS_MISSING'; end if;
  closed_detail:=closed_result->'details'->0;
  select array_agg(key order by key) into detail_keys from jsonb_object_keys(closed_detail) key;
  if detail_keys is distinct from array['answer_text','correct_option_key','correct_option_text','is_correct','question_order','question_text','score_awarded'] then raise exception 'CLOSED_DETAIL_CONTRACT_INVALID'; end if;
  if closed_detail->>'question_order' <> '1' or closed_detail->>'question_text' <> 'Task 2 detail question' or closed_detail->>'answer_text' <> 'A — Task 2 correct' or closed_detail->'is_correct' <> 'true'::jsonb or (closed_detail->>'score_awarded')::numeric <> 1 or closed_detail->>'correct_option_key' <> 'A' or closed_detail->>'correct_option_text' <> 'Task 2 correct' then raise exception 'CLOSED_DETAIL_VALUES_INVALID'; end if;
  if not has_function_privilege('anon','public.v5_student_resume_attempt(uuid,text)','execute') or not has_function_privilege('authenticated','public.v5_student_resume_attempt(uuid,text)','execute') or has_function_privilege('public','public.v5_student_resume_attempt(uuid,text)','execute') then raise exception 'RESUME_RPC_ACL_INVALID'; end if;
  if not has_function_privilege('anon','public.v5_student_get_result(uuid,text)','execute') or not has_function_privilege('authenticated','public.v5_student_get_result(uuid,text)','execute') or has_function_privilege('public','public.v5_student_get_result(uuid,text)','execute') then raise exception 'RESULT_RPC_ACL_INVALID'; end if;
end $$;

do $$
declare
  token_a text := current_setting('test.dashboard_token_a'); token_b text := current_setting('test.dashboard_token_b');
  dashboard jsonb; no_visible_dashboard jsonb; active_attempt jsonb; hidden_attempt jsonb; details_attempt jsonb;
  expected_ids uuid[]; returned_ids uuid[]; expected_summary jsonb; profile_keys text[]; summary_keys text[]; attempt_keys text[]; blocked boolean;
begin
  set local role anon; dashboard := public.v5_student_dashboard(token_a,1000); reset role;
  select array_agg(key order by key) into profile_keys from jsonb_object_keys(dashboard->'profile') key;
  select array_agg(key order by key) into summary_keys from jsonb_object_keys(dashboard->'summary') key;
  select array_agg(key order by key) into attempt_keys from jsonb_object_keys((dashboard->'attempts')->0) key;
  if profile_keys is distinct from array['class_name','field_name','full_name','grade_name','student_code'] then raise exception 'PROFILE_CONTRACT_INVALID'; end if;
  if summary_keys is distinct from array['attempt_count','average_percentage','blank_count','correct_count','in_progress_count','submitted_count','visible_result_count','wrong_count'] then raise exception 'SUMMARY_CONTRACT_INVALID'; end if;
  if attempt_keys is distinct from array['attempt_id','blank_count','can_resume','correct_count','detail_visible','exam_code','exam_title','percentage','result_visible','resume_reason','started_at','status','submitted_at','wrong_count'] then raise exception 'ATTEMPT_CONTRACT_INVALID'; end if;
  if dashboard->'profile'->>'student_code' <> 'STAGING-STUDENT-001' or dashboard->'profile'->>'full_name' is null then raise exception 'DASHBOARD_PROFILE_LEAK'; end if;
  if jsonb_array_length(dashboard->'attempts') <> 100 then raise exception 'LIMIT_OVER_100_NOT_CLAMPED'; end if;
  select array_agg(a.id order by a.started_at desc nulls last,a.id desc) into expected_ids from (select a.id,a.started_at from public.v5_attempts a where a.student_id=(select id from public.v5_students where student_code='STAGING-STUDENT-001') order by a.started_at desc nulls last,a.id desc limit 100) a;
  select array_agg((x.value->>'attempt_id')::uuid order by x.ordinality) into returned_ids from jsonb_array_elements(dashboard->'attempts') with ordinality as x(value,ordinality);
  if returned_ids is distinct from expected_ids then raise exception 'ATTEMPTS_NOT_NEWEST_FIRST'; end if;
  set local role anon;
  if jsonb_array_length(public.v5_student_dashboard(token_a,0)->'attempts') <> 0 then raise exception 'LIMIT_ZERO_NOT_HONORED'; end if;
  if jsonb_array_length(public.v5_student_dashboard(token_a,100)->'attempts') <> 100 then raise exception 'LIMIT_100_NOT_HONORED'; end if;
  blocked := false; begin perform public.v5_student_dashboard(token_a,-1); exception when others then blocked := sqlerrm='INVALID_LIMIT'; end; if not blocked then raise exception 'NEGATIVE_LIMIT_ACCEPTED'; end if;
  reset role;
  if exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where (x->>'attempt_id')::uuid in (select a.id from public.v5_attempts a join public.v5_students s on s.id=a.student_id where s.student_code='STAGING-STUDENT-002')) then raise exception 'DASHBOARD_ATTEMPT_LEAK'; end if;
  select x into hidden_attempt from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-HIDDEN';
  if hidden_attempt is null or (select count(*) from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-HIDDEN') <> 1 then raise exception 'HIDDEN_ATTEMPT_NOT_PRESERVED'; end if;
  if hidden_attempt->'result_visible' <> 'false'::jsonb or hidden_attempt->'percentage' <> 'null'::jsonb or hidden_attempt->'correct_count' <> 'null'::jsonb or hidden_attempt->'wrong_count' <> 'null'::jsonb or hidden_attempt->'blank_count' <> 'null'::jsonb then raise exception 'HIDDEN_RESULT_NOT_MASKED'; end if;
  select jsonb_build_object('attempt_count',count(*),'submitted_count',count(*) filter (where a.status='submitted'),'in_progress_count',count(*) filter (where a.status='started'),'visible_result_count',count(*) filter (where a.status='submitted' and e.show_result_to_student is true),'average_percentage',avg(a.percentage) filter (where a.status='submitted' and e.show_result_to_student is true),'correct_count',coalesce(sum(a.correct_count) filter (where a.status='submitted' and e.show_result_to_student is true),0),'wrong_count',coalesce(sum(a.wrong_count) filter (where a.status='submitted' and e.show_result_to_student is true),0),'blank_count',coalesce(sum(a.blank_count) filter (where a.status='submitted' and e.show_result_to_student is true),0)) into expected_summary from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where a.student_id=(select id from public.v5_students where student_code='STAGING-STUDENT-001');
  if dashboard->'summary' is distinct from expected_summary then raise exception 'SUMMARY_VALUES_INVALID'; end if;
  select x into active_attempt from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-ACTIVE'; select x into details_attempt from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-DETAILS';
  if (active_attempt->>'can_resume')::boolean is not true or active_attempt->>'resume_reason' is not null then raise exception 'ACTIVE_RESUME_INVALID'; end if;
  if details_attempt->'detail_visible' <> 'true'::jsonb then raise exception 'CLOSED_VISIBLE_DETAILS_HIDDEN'; end if;
  if exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-HISTORY' and x->'detail_visible' <> 'false'::jsonb) then raise exception 'OPEN_DETAILS_EXPOSED'; end if;
  if not exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where x->>'status'='submitted' and x->>'resume_reason'='submitted') then raise exception 'SUBMITTED_REASON_MISSING'; end if;
  if not exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-EXPIRED' and x->>'resume_reason'='expired') then raise exception 'EXPIRED_REASON_MISSING'; end if;
  if not exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-CLOSED' and x->>'resume_reason'='exam_closed') then raise exception 'CLOSED_REASON_MISSING'; end if;
  if not exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-DEADLINE' and x->>'resume_reason'='deadline_passed') then raise exception 'DEADLINE_REASON_MISSING'; end if;
  if not exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where x->>'exam_code'='TASK1-EARLIER' and x->>'resume_reason'='deadline_passed') then raise exception 'EARLIER_DEADLINE_NOT_USED'; end if;
  if exists (select 1 from jsonb_array_elements(dashboard->'attempts') x where (x->>'can_resume')::boolean and x->>'resume_reason' is not null) then raise exception 'RESUME_STATE_INCONSISTENT'; end if;
  update public.v5_exams set show_result_to_student=false where id in (select a.exam_id from public.v5_attempts a where a.student_id=(select id from public.v5_students where student_code='STAGING-STUDENT-002'));
  set local role anon; no_visible_dashboard := public.v5_student_dashboard(token_b,100); reset role;
  if no_visible_dashboard->'summary'->'average_percentage' <> 'null'::jsonb or no_visible_dashboard->'summary'->'correct_count' <> '0'::jsonb or no_visible_dashboard->'summary'->'wrong_count' <> '0'::jsonb or no_visible_dashboard->'summary'->'blank_count' <> '0'::jsonb then raise exception 'EMPTY_VISIBLE_SUMMARY_INVALID'; end if;
  update v5_auth_private.sessions set expires_at=created_at+interval '1 microsecond' where token_hash=encode(extensions.digest(token_a,'sha256'),'hex');
  set local role anon; blocked:=false; begin perform public.v5_student_dashboard(token_a,100); exception when insufficient_privilege then blocked:=true; end; if not blocked then raise exception 'EXPIRED_SESSION_ACCEPTED'; end if; reset role;
  update public.v5_students set is_active=false where student_code='STAGING-STUDENT-002';
  set local role anon; blocked:=false; begin perform public.v5_student_dashboard(token_b,100); exception when insufficient_privilege then blocked:=true; end; if not blocked then raise exception 'INACTIVE_STUDENT_ACCEPTED'; end if; reset role;
  if not has_function_privilege('anon','public.v5_student_dashboard(text,integer)','execute') or not has_function_privilege('authenticated','public.v5_student_dashboard(text,integer)','execute') or has_function_privilege('public','public.v5_student_dashboard(text,integer)','execute') then raise exception 'DASHBOARD_RPC_ACL_INVALID'; end if;
  if has_table_privilege('anon','public.v5_students','select') or has_table_privilege('anon','public.v5_attempts','select') or has_table_privilege('anon','public.v5_exams','select') then raise exception 'DASHBOARD_TABLE_PRIVILEGE_EXPOSED'; end if;
end $$;

rollback;
select 'PASS: student dashboard contract, masking, ownership, limits and resume states' as result;
