begin;
do $$ begin if to_regnamespace('v5_auth_private') is null then raise exception 'AUTH_SCHEMA_NOT_IMPLEMENTED'; end if; end $$;
do $$
declare sid bigint; login jsonb; token text; profile jsonb; denied boolean;
begin
 select id into strict sid from public.v5_students where student_code='STAGING-STUDENT-001';
 insert into v5_auth_private.credentials(student_id,password_hash) values(sid,extensions.crypt('AuditPass-2026',extensions.gen_salt('bf',10)));
 if exists(select from v5_auth_private.credentials where student_id=sid and password_hash like '%AuditPass%') then raise exception 'PLAINTEXT_STORED'; end if;
 if public.v5_student_login('STAGING-STUDENT-001','wrong-password') is not null then raise exception 'WRONG_PASSWORD_ACCEPTED'; end if;
 login:=public.v5_student_login(' staging-student-001 ','AuditPass-2026'); token:=login->>'token';
 if token !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_TOKEN'; end if;
 profile:=public.v5_student_profile(token);
 if (profile->>'student_id')::bigint<>sid then raise exception 'WRONG_OWNER'; end if;
 denied:=false; begin perform public.v5_student_profile(repeat('0',64)); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'FORGED_TOKEN_ACCEPTED'; end if;
 update v5_auth_private.credentials set password_hash=extensions.crypt('AuditPass-2027',extensions.gen_salt('bf',10)) where student_id=sid;
 update v5_auth_private.sessions set revoked_at=clock_timestamp() where student_id=sid;
 denied:=false; begin perform public.v5_student_profile(token); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'OLD_SESSION_SURVIVED_RESET'; end if;
 if has_function_privilege('anon','public.v5_start_exam(text,text)','execute') then raise exception 'OLD_CODE_LOGIN_STILL_EXECUTABLE'; end if;
 if not has_function_privilege('anon','public.v5_student_start_exam(text,text)','execute') then raise exception 'SESSION_WRAPPER_NOT_EXECUTABLE'; end if;
 if has_table_privilege('anon','v5_auth_private.credentials','select') then raise exception 'CREDENTIALS_EXPOSED'; end if;
 denied:=false; begin perform public.v5_admin_set_student_password(sid,'Unauthorized-Password'); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'ANON_PASSWORD_RESET_ALLOWED'; end if;
end $$;
select 'PASS: password hash, login, forged token, reset revocation, ACL' result;
rollback;
