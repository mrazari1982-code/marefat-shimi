-- Simple student username/password authentication (staging first)
create schema if not exists v5_auth_private;
revoke all on schema v5_auth_private from public, anon, authenticated;

create table if not exists v5_auth_private.credentials (
 student_id bigint primary key references public.v5_students(id) on delete cascade,
 password_hash text not null check (password_hash like '$2%'),
 updated_at timestamptz not null default now()
);
create table if not exists v5_auth_private.sessions (
 token_hash text primary key check (token_hash ~ '^[0-9a-f]{64}$'),
 student_id bigint not null references public.v5_students(id) on delete cascade,
 created_at timestamptz not null default now(),
 last_used_at timestamptz not null default now(),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 check (expires_at > created_at)
);
create index if not exists v5_student_sessions_active_idx
 on v5_auth_private.sessions(student_id,expires_at) where revoked_at is null;
alter table v5_auth_private.credentials enable row level security;
alter table v5_auth_private.sessions enable row level security;
revoke all on all tables in schema v5_auth_private from public,anon,authenticated;

create or replace function v5_auth_private.student_for_token(p_token text)
returns public.v5_students language plpgsql security definer
set search_path=pg_catalog,public,v5_auth_private,extensions as $$
declare v_student public.v5_students%rowtype; v_hash text;
begin
 if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'UNAUTHORIZED' using errcode='42501'; end if;
 v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
 select s.* into v_student from v5_auth_private.sessions x join public.v5_students s on s.id=x.student_id
 join v5_auth_private.credentials c on c.student_id=s.id
 where x.token_hash=v_hash and x.revoked_at is null and x.expires_at>clock_timestamp() and s.is_active=true
 for update of x;
 if not found then raise exception 'UNAUTHORIZED' using errcode='42501'; end if;
 update v5_auth_private.sessions set last_used_at=clock_timestamp() where token_hash=v_hash;
 return v_student;
end $$;
revoke all on function v5_auth_private.student_for_token(text) from public,anon,authenticated;

create or replace function public.v5_student_login(p_username text,p_password text)
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,v5_auth_private,extensions as $$
declare v_student public.v5_students%rowtype; v_student_id bigint; v_hash text; v_token text; v_expires timestamptz; v_valid boolean;
begin
 if p_username is null or p_password is null or length(p_username)>128 or octet_length(p_password)>72 then return null; end if;
 select s.id,c.password_hash into v_student_id,v_hash
 from public.v5_students s join v5_auth_private.credentials c on c.student_id=s.id
 where lower(trim(s.student_code))=lower(trim(p_username)) and s.is_active=true limit 1;
 v_valid:=extensions.crypt(p_password,coalesce(v_hash,'$2a$10$JqS06gbjraW0RhK7OQGAiul0tn/z90MyZRiAjkQ1mMlNovq7oMNZm'))
   =coalesce(v_hash,'$2a$10$JqS06gbjraW0RhK7OQGAiul0tn/z90MyZRiAjkQ1mMlNovq7oMNZm');
 if v_hash is null or not v_valid then return null; end if;
 select * into strict v_student from public.v5_students where id=v_student_id and is_active=true;
 v_token:=encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 v_expires:=clock_timestamp()+interval '8 hours';
 insert into v5_auth_private.sessions(token_hash,student_id,expires_at) values(v_hash,v_student.id,v_expires);
 delete from v5_auth_private.sessions where expires_at<clock_timestamp()-interval '1 day';
 return jsonb_build_object('token',v_token,'expires_at',v_expires,'student_id',v_student.id,
  'student_code',v_student.student_code,'student_name',v_student.full_name);
end $$;

create or replace function public.v5_admin_set_student_password(p_student_id bigint,p_password text)
returns boolean language plpgsql security definer
set search_path=pg_catalog,public,v5_auth_private,extensions as $$
begin
 if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then
  raise exception 'ACCESS_DENIED' using errcode='42501';
 end if;
 if p_password is null or char_length(p_password)<8 or octet_length(p_password)>72 then raise exception 'PASSWORD_POLICY'; end if;
 if not exists(select 1 from public.v5_students where id=p_student_id and is_active=true) then raise exception 'STUDENT_NOT_FOUND'; end if;
 insert into v5_auth_private.credentials(student_id,password_hash,updated_at)
 values(p_student_id,extensions.crypt(p_password,extensions.gen_salt('bf',10)),clock_timestamp())
 on conflict(student_id) do update set password_hash=excluded.password_hash,updated_at=excluded.updated_at;
 update v5_auth_private.sessions set revoked_at=clock_timestamp()
 where student_id=p_student_id and revoked_at is null;
 return true;
end $$;

create or replace function public.v5_student_logout(p_session_token text)
returns boolean language plpgsql security definer
set search_path=pg_catalog,public,v5_auth_private,extensions as $$
declare v_hash text;
begin
 if p_session_token is null or p_session_token !~ '^[0-9a-f]{64}$' then return true; end if;
 v_hash:=encode(extensions.digest(p_session_token,'sha256'),'hex');
 update v5_auth_private.sessions set revoked_at=clock_timestamp() where token_hash=v_hash and revoked_at is null;
 return true;
end $$;

create or replace function public.v5_student_profile(p_session_token text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype;
begin s:=v5_auth_private.student_for_token(p_session_token);
 return jsonb_build_object('student_id',s.id,'student_code',s.student_code,'student_name',s.full_name);
end $$;

create or replace function public.v5_student_start_exam(p_exam_token text,p_session_token text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return public.v5_start_exam(p_exam_token,s.student_code); end $$;
create or replace function public.v5_student_get_attempt_state(p_attempt_id uuid,p_session_token text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return public.v5_get_attempt_state(p_attempt_id,s.student_code); end $$;
create or replace function public.v5_student_get_exam_questions(p_attempt_id uuid,p_session_token text)
returns table(id bigint,question_order integer,score numeric,question_text text,option_id bigint,option_key text,option_text text,sort_order integer)
language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return query select * from public.v5_get_exam_questions(p_attempt_id,s.student_code); end $$;
create or replace function public.v5_student_get_saved_answers(p_attempt_id uuid,p_session_token text)
returns table(exam_question_id bigint,selected_option_id bigint)
language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return query select * from public.v5_get_saved_answers(p_attempt_id,s.student_code); end $$;
create or replace function public.v5_student_save_answer(p_attempt_id uuid,p_exam_question_id bigint,p_selected_option_id bigint,p_session_token text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return public.v5_save_answer(p_attempt_id,p_exam_question_id,p_selected_option_id,s.student_code); end $$;
create or replace function public.v5_student_save_answers(p_attempt_id uuid,p_answers jsonb,p_session_token text)
returns void language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 perform public.v5_save_answers(p_attempt_id,s.student_code,p_answers); end $$;
create or replace function public.v5_student_submit_attempt(p_attempt_id uuid,p_session_token text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return public.v5_submit_attempt(p_attempt_id,s.student_code); end $$;
create or replace function public.v5_student_get_result(p_attempt_id uuid,p_session_token text)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public,v5_auth_private as $$
declare s public.v5_students%rowtype; begin s:=v5_auth_private.student_for_token(p_session_token);
 return public.v5_get_student_result(p_attempt_id,s.student_code); end $$;

revoke all on function public.v5_admin_set_student_password(bigint,text) from public,anon;
grant execute on function public.v5_admin_set_student_password(bigint,text) to authenticated;
revoke all on function public.v5_student_login(text,text),public.v5_student_logout(text),public.v5_student_profile(text),
 public.v5_student_start_exam(text,text),public.v5_student_get_attempt_state(uuid,text),
 public.v5_student_get_exam_questions(uuid,text),public.v5_student_get_saved_answers(uuid,text),
 public.v5_student_save_answer(uuid,bigint,bigint,text),public.v5_student_save_answers(uuid,jsonb,text),
 public.v5_student_submit_attempt(uuid,text),public.v5_student_get_result(uuid,text) from public;
grant execute on function public.v5_student_login(text,text),public.v5_student_logout(text),public.v5_student_profile(text),
 public.v5_student_start_exam(text,text),public.v5_student_get_attempt_state(uuid,text),
 public.v5_student_get_exam_questions(uuid,text),public.v5_student_get_saved_answers(uuid,text),
 public.v5_student_save_answer(uuid,bigint,bigint,text),public.v5_student_save_answers(uuid,jsonb,text),
 public.v5_student_submit_attempt(uuid,text),public.v5_student_get_result(uuid,text) to anon,authenticated;
