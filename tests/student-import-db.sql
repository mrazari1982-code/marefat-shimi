begin;
do $$
begin
 if to_regprocedure('public.v5_admin_student_import_context()') is null then
  raise exception 'IMPORT_CONTEXT_NOT_IMPLEMENTED';
 end if;
 if to_regprocedure('public.v5_admin_import_students(jsonb)') is null then
  raise exception 'IMPORT_RPC_NOT_IMPLEMENTED';
 end if;
end $$;

do $$
declare admin_id uuid:=gen_random_uuid(); existing_id bigint; existing_hash text;
begin
 insert into auth.users(id,email) values(admin_id,'bulk-import-test@example.invalid');
 insert into public.v5_profiles(id,full_name,role,is_active) values(admin_id,'Bulk Import Test Admin','admin',true);
 insert into public.v5_students(student_code,full_name,is_active)
 values('BULK-TDD-EXISTING','دانش‌آموز موجود آزمایشی',true)
 returning id into existing_id;
 insert into v5_auth_private.credentials(student_id,password_hash)
 values(existing_id,extensions.crypt('existing-password-unchanged',extensions.gen_salt('bf',10)))
 on conflict(student_id) do update set password_hash=excluded.password_hash,updated_at=clock_timestamp();
 select password_hash into strict existing_hash from v5_auth_private.credentials where student_id=existing_id;
 perform set_config('request.jwt.claim.sub',admin_id::text,true);
 perform set_config('test.existing_student_id',existing_id::text,true);
 perform set_config('test.existing_hash',existing_hash,true);
end $$;

set local role authenticated;
do $$
declare context jsonb; result jsonb; before_count bigint; blocked boolean;
begin
 context:=public.v5_admin_student_import_context();
 if jsonb_typeof(context->'grades')<>'array' or jsonb_typeof(context->'existingCodes')<>'array' then
  raise exception 'CONTEXT_SHAPE_INVALID';
 end if;
 result:=public.v5_admin_import_students(jsonb_build_array(
  jsonb_build_object('student_code','BULK-TDD-001','full_name','دانش‌آموز گروهی یک','password','BatchPassword23','grade_id',null,'field_id',null,'class_id',null),
  jsonb_build_object('student_code','BULK-TDD-002','full_name','دانش‌آموز گروهی دو','password','BatchPassword24','grade_id',null,'field_id',null,'class_id',null),
  jsonb_build_object('student_code','BULK-TDD-EXISTING','full_name','نباید تغییر کند','password','MustNotReplace88','grade_id',null,'field_id',null,'class_id',null)
 ));
 if jsonb_array_length(result)<>3 then raise exception 'RESULT_COUNT_WRONG'; end if;
 if (select count(*) from jsonb_array_elements(result) x where x->>'status'='created')<>2 then raise exception 'CREATED_COUNT_WRONG'; end if;
 if (select count(*) from jsonb_array_elements(result) x where x->>'status'='existing')<>1 then raise exception 'EXISTING_COUNT_WRONG'; end if;
 if (select count(*) from public.v5_students where student_code in ('BULK-TDD-001','BULK-TDD-002'))<>2 then raise exception 'STUDENTS_NOT_INSERTED'; end if;
 select count(*) into before_count from public.v5_students;
 blocked:=false;
 begin
  perform public.v5_admin_import_students(jsonb_build_array(
   jsonb_build_object('student_code','BULK-MUST-ROLLBACK','full_name','نباید ثبت شود','password','BatchPassword25','grade_id',null,'field_id',null,'class_id',null),
   jsonb_build_object('student_code','BULK-BAD-GRADE','full_name','نامعتبر','password','BatchPassword26','grade_id',-999,'field_id',null,'class_id',null)
  ));
 exception when others then blocked:=true;
 end;
 if not blocked then raise exception 'INVALID_BATCH_ACCEPTED'; end if;
 if (select count(*) from public.v5_students)<>before_count or exists(select 1 from public.v5_students where student_code='BULK-MUST-ROLLBACK') then
  raise exception 'INVALID_BATCH_PARTIALLY_INSERTED';
 end if;

 blocked:=false;
 begin
  perform public.v5_admin_import_students(jsonb_build_array(
   jsonb_build_object('student_code','DUPLICATE','full_name','یک','password','BatchPassword27'),
   jsonb_build_object('student_code','duplicate','full_name','دو','password','BatchPassword28')
  ));
 exception when others then blocked:=true;
 end;
 if not blocked then raise exception 'IN_FILE_DUPLICATE_ACCEPTED'; end if;
end $$;

reset role;
do $$
begin
 if not exists(
  select 1 from public.v5_students s join v5_auth_private.credentials c on c.student_id=s.id
  where s.student_code='BULK-TDD-001' and c.password_hash=extensions.crypt('BatchPassword23',c.password_hash)
    and position('BatchPassword23' in c.password_hash)=0
 ) then raise exception 'PASSWORD_NOT_HASHED'; end if;
 if (select password_hash from v5_auth_private.credentials where student_id=current_setting('test.existing_student_id')::bigint)<>current_setting('test.existing_hash') then
  raise exception 'EXISTING_PASSWORD_CHANGED';
 end if;
end $$;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$
declare login_data jsonb; blocked boolean;
begin
 login_data:=public.v5_student_login('BULK-TDD-001','BatchPassword23');
 if login_data->>'token' is null then raise exception 'CREATED_LOGIN_FAILED'; end if;
 blocked:=false;
 begin perform public.v5_admin_import_students('[]'::jsonb); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'ANON_IMPORT_ALLOWED'; end if;
 blocked:=false;
 begin perform public.v5_admin_student_import_context(); exception when insufficient_privilege then blocked:=true; end;
 if not blocked then raise exception 'ANON_CONTEXT_ALLOWED'; end if;
end $$;
reset role;
rollback;
select 'PASS: admin batch import, bcrypt, duplicate skip, atomic rollback, login and ACL' result;
