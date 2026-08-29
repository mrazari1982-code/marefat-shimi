-- Admin-only, atomic bulk import of students and password credentials.
create unique index if not exists v5_students_code_ci_uidx
 on public.v5_students(lower(trim(student_code)));

create or replace function public.v5_admin_student_import_context()
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
begin
 if not exists(select 1 from public.v5_profiles where id=auth.uid() and is_active and role in ('admin','deputy')) then
  raise exception 'ACCESS_DENIED' using errcode='42501';
 end if;
 return jsonb_build_object(
  'grades',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by level_order),'[]'::jsonb) from public.v5_grades where is_active),
  'fields',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]'::jsonb) from public.v5_fields where is_active),
  'classes',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'grade_id',grade_id,'field_id',field_id) order by name),'[]'::jsonb) from public.v5_classes where is_active),
  'existingCodes',(select coalesce(jsonb_agg(student_code order by student_code),'[]'::jsonb) from public.v5_students)
 );
end $$;

create or replace function public.v5_admin_import_students(p_rows jsonb)
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,v5_auth_private,extensions as $$
declare
 v_item jsonb; v_results jsonb:='[]'::jsonb; v_student public.v5_students%rowtype;
 v_code text; v_name text; v_password text;
 v_grade_id bigint; v_field_id bigint; v_class_id bigint;
 v_class_grade bigint; v_class_field bigint;
begin
 if not exists(select 1 from public.v5_profiles where id=auth.uid() and is_active and role in ('admin','deputy')) then
  raise exception 'ACCESS_DENIED' using errcode='42501';
 end if;
 if p_rows is null or jsonb_typeof(p_rows)<>'array' then raise exception 'INVALID_ROWS'; end if;
 if jsonb_array_length(p_rows)<1 or jsonb_array_length(p_rows)>500 then raise exception 'ROW_LIMIT'; end if;
 if pg_column_size(p_rows)>524288 then raise exception 'PAYLOAD_LIMIT'; end if;
 if exists(select 1 from jsonb_array_elements(p_rows) item group by lower(trim(item->>'student_code')) having count(*)>1) then
  raise exception 'DUPLICATE_CODE_IN_FILE';
 end if;

 for v_item in select value from jsonb_array_elements(p_rows) loop
  v_code:=trim(v_item->>'student_code'); v_name:=trim(v_item->>'full_name'); v_password:=v_item->>'password';
  v_grade_id:=nullif(v_item->>'grade_id','')::bigint; v_field_id:=nullif(v_item->>'field_id','')::bigint; v_class_id:=nullif(v_item->>'class_id','')::bigint;
  if nullif(v_code,'') is null or length(v_code)>128 or nullif(v_name,'') is null then raise exception 'INVALID_STUDENT'; end if;
  if v_password is null or char_length(v_password)<8 or octet_length(v_password)>72 then raise exception 'PASSWORD_POLICY'; end if;
  if v_grade_id is not null and not exists(select 1 from public.v5_grades where id=v_grade_id and is_active) then raise exception 'INVALID_GRADE'; end if;
  if v_field_id is not null and not exists(select 1 from public.v5_fields where id=v_field_id and is_active) then raise exception 'INVALID_FIELD'; end if;
  if v_class_id is not null then
   select grade_id,field_id into v_class_grade,v_class_field from public.v5_classes where id=v_class_id and is_active;
   if not found then raise exception 'INVALID_CLASS'; end if;
   if v_grade_id is not null and v_class_grade is not null and v_grade_id<>v_class_grade then raise exception 'CLASS_GRADE_MISMATCH'; end if;
   if v_field_id is not null and v_class_field is not null and v_field_id<>v_class_field then raise exception 'CLASS_FIELD_MISMATCH'; end if;
  end if;
 end loop;

 for v_item in select value from jsonb_array_elements(p_rows) loop
  v_code:=trim(v_item->>'student_code'); v_name:=trim(v_item->>'full_name'); v_password:=v_item->>'password';
  v_grade_id:=nullif(v_item->>'grade_id','')::bigint; v_field_id:=nullif(v_item->>'field_id','')::bigint; v_class_id:=nullif(v_item->>'class_id','')::bigint;
  select * into v_student from public.v5_students where lower(trim(student_code))=lower(v_code) limit 1;
  if found then
   v_results:=v_results||jsonb_build_array(jsonb_build_object('student_code',v_student.student_code,'student_id',v_student.id,'status','existing'));
  else
   insert into public.v5_students(student_code,full_name,grade_id,field_id,class_id,is_active)
   values(v_code,v_name,v_grade_id,v_field_id,v_class_id,true) returning * into v_student;
   insert into v5_auth_private.credentials(student_id,password_hash,updated_at)
   values(v_student.id,extensions.crypt(v_password,extensions.gen_salt('bf',10)),clock_timestamp());
   v_results:=v_results||jsonb_build_array(jsonb_build_object('student_code',v_student.student_code,'student_id',v_student.id,'status','created'));
  end if;
 end loop;
 return v_results;
end $$;

revoke all on function public.v5_admin_student_import_context() from public,anon;
revoke all on function public.v5_admin_import_students(jsonb) from public,anon;
grant execute on function public.v5_admin_student_import_context(),public.v5_admin_import_students(jsonb) to authenticated;
