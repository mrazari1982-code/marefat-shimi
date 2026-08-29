begin;

insert into v5_auth_private.credentials(student_id,password_hash)
select id,extensions.crypt('ownership-test-password-a',extensions.gen_salt('bf',10))
from public.v5_students where student_code='STAGING-STUDENT-001'
on conflict(student_id) do update set password_hash=excluded.password_hash,updated_at=clock_timestamp();
insert into v5_auth_private.credentials(student_id,password_hash)
select id,extensions.crypt('ownership-test-password-b',extensions.gen_salt('bf',10))
from public.v5_students where student_code='STAGING-STUDENT-002'
on conflict(student_id) do update set password_hash=excluded.password_hash,updated_at=clock_timestamp();

select set_config('test.attempt_a',(select a.id::text from public.v5_attempts a join public.v5_students s on s.id=a.student_id where s.student_code='STAGING-STUDENT-001' limit 1),true);
select set_config('test.attempt_b',(select a.id::text from public.v5_attempts a join public.v5_students s on s.id=a.student_id where s.student_code='STAGING-STUDENT-002' limit 1),true);

set local role anon;
do $$
declare
 login_a jsonb;
 token_a text;
 attempt_a uuid:=current_setting('test.attempt_a')::uuid;
 attempt_b uuid:=current_setting('test.attempt_b')::uuid;
 blocked boolean;
begin
 login_a:=public.v5_student_login('STAGING-STUDENT-001','ownership-test-password-a');
 token_a:=login_a->>'token';
 if token_a is null or public.v5_student_profile(token_a)->>'student_code'<>'STAGING-STUDENT-001' then
  raise exception 'ANON_LOGIN_OR_PROFILE_FAILED';
 end if;
 if public.v5_student_login('STAGING-STUDENT-001','wrong-password') is not null then raise exception 'WRONG_PASSWORD_ACCEPTED'; end if;
 if public.v5_student_get_result(attempt_a,token_a) is null then raise exception 'OWN_RESULT_DENIED'; end if;

 blocked:=false; begin perform public.v5_student_get_attempt_state(attempt_b,token_a); exception when others then blocked:=true; end;
 if not blocked then raise exception 'CROSS_STUDENT_STATE_ALLOWED'; end if;
 blocked:=false; begin perform * from public.v5_student_get_exam_questions(attempt_b,token_a); exception when others then blocked:=true; end;
 if not blocked then raise exception 'CROSS_STUDENT_QUESTIONS_ALLOWED'; end if;
 blocked:=false; begin perform * from public.v5_student_get_saved_answers(attempt_b,token_a); exception when others then blocked:=true; end;
 if not blocked then raise exception 'CROSS_STUDENT_SAVED_ALLOWED'; end if;
 blocked:=false; begin perform public.v5_student_save_answer(attempt_b,0,0,token_a); exception when others then blocked:=true; end;
 if not blocked then raise exception 'CROSS_STUDENT_SAVE_ALLOWED'; end if;
 blocked:=false; begin perform public.v5_student_submit_attempt(attempt_b,token_a); exception when others then blocked:=true; end;
 if not blocked then raise exception 'CROSS_STUDENT_SUBMIT_ALLOWED'; end if;
 blocked:=false; begin perform public.v5_student_get_result(attempt_b,token_a); exception when others then blocked:=true; end;
 if not blocked then raise exception 'CROSS_STUDENT_RESULT_ALLOWED'; end if;

 blocked:=false; begin perform * from v5_auth_private.credentials; exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'PRIVATE_CREDENTIALS_READABLE_BY_ANON'; end if;
 blocked:=false; begin perform public.v5_get_student_result(attempt_a,'STAGING-STUDENT-001'); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'LEGACY_CODE_RPC_EXECUTABLE_BY_ANON'; end if;
end $$;
reset role;
rollback;
select 'PASS: anon RPCs enforce ownership across students and legacy/private ACLs' as result;
