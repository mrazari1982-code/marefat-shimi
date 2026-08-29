-- Keep valid and invalid usernames on one bcrypt verification path.
create or replace function public.v5_student_login(p_username text,p_password text)
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,v5_auth_private,extensions as $$
declare
 v_student public.v5_students%rowtype;
 v_student_id bigint;
 v_hash text;
 v_token text;
 v_expires timestamptz;
 v_valid boolean;
begin
 if p_username is null or p_password is null or length(p_username)>128 or octet_length(p_password)>72 then return null; end if;
 select s.id,c.password_hash into v_student_id,v_hash
 from public.v5_students s join v5_auth_private.credentials c on c.student_id=s.id
 where lower(trim(s.student_code))=lower(trim(p_username)) and s.is_active=true limit 1;
 v_valid:=extensions.crypt(p_password,coalesce(v_hash,'$2a$10$JqS06gbjraW0RhK7OQGAiul0tn/z90MyZRiAjkQ1mMlNovq7oMNZm'))
   =coalesce(v_hash,'$2a$10$JqS06gbjraW0RhK7OQGAiul0tn/z90MyZRiAjkQ1mMlNovq7oMNZm');
 if v_hash is null or not v_valid then return null; end if;
 select * into strict v_student from public.v5_students where id=v_student_id and is_active=true;
 v_token:=encode(extensions.gen_random_bytes(32),'hex');
 v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 v_expires:=clock_timestamp()+interval '8 hours';
 insert into v5_auth_private.sessions(token_hash,student_id,expires_at) values(v_hash,v_student.id,v_expires);
 delete from v5_auth_private.sessions where expires_at<clock_timestamp()-interval '1 day';
 return jsonb_build_object('token',v_token,'expires_at',v_expires,'student_id',v_student.id,
  'student_code',v_student.student_code,'student_name',v_student.full_name);
end $$;
revoke all on function public.v5_student_login(text,text) from public;
grant execute on function public.v5_student_login(text,text) to anon,authenticated;
