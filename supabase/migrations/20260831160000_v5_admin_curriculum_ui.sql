begin;

create or replace function public.v5_require_admin() returns void language plpgsql security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not public.v5_has_role('admin'::public.v5_user_role) then raise exception 'admin access required'; end if;
end $$;

create or replace function public.v5_admin_create_academic_year(p_label text,p_starts_on date default null,p_ends_on date default null,p_create_default_classes boolean default true)
returns bigint language plpgsql security definer set search_path='' as $$
declare yid bigint;
begin
 perform public.v5_require_admin();
 if nullif(btrim(p_label),'') is null then raise exception 'academic year label is required'; end if;
 if p_starts_on is not null and p_ends_on is not null and p_starts_on>=p_ends_on then raise exception 'invalid dates'; end if;
 insert into public.v5_academic_years(label,starts_on,ends_on,status,created_by) values(btrim(p_label),p_starts_on,p_ends_on,'preparing',(select auth.uid())) returning id into yid;
 if p_create_default_classes then perform public.v5_create_default_classes(yid); end if;
 return yid;
end $$;

create or replace function public.v5_admin_set_active_academic_year(p_academic_year_id bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 perform public.v5_require_admin();
 if not exists(select 1 from public.v5_academic_years where id=p_academic_year_id) then raise exception 'academic year not found'; end if;
 update public.v5_academic_years set status='closed',updated_at=now() where status='active' and id<>p_academic_year_id;
 update public.v5_academic_years set status='active',updated_at=now() where id=p_academic_year_id;
end $$;

create or replace function public.v5_admin_add_class(p_academic_year_id bigint,p_grade_id bigint,p_field_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare n integer; cid bigint; yl text; gn text; fn text;
begin
 perform public.v5_require_admin();
 select label into yl from public.v5_academic_years where id=p_academic_year_id;
 select name into gn from public.v5_grades where id=p_grade_id and is_active;
 select name into fn from public.v5_fields where id=p_field_id and is_active and is_program_field;
 if yl is null or gn is null or fn is null then raise exception 'invalid year, grade or field'; end if;
 perform pg_advisory_xact_lock(p_academic_year_id,(p_grade_id*100000+p_field_id)::integer);
 select coalesce(max(class_number),0)+1 into n from public.v5_classes where academic_year_id=p_academic_year_id and grade_id=p_grade_id and field_id=p_field_id;
 insert into public.v5_classes(name,grade_id,field_id,academic_year,academic_year_id,class_number,is_active) values(gn||' '||fn||' '||n,p_grade_id,p_field_id,yl,p_academic_year_id,n,true) returning id into cid;
 return cid;
end $$;

create or replace function public.v5_admin_save_curriculum_question(p_topic_id bigint,p_question_type public.v5_question_type,p_question_text text,p_difficulty public.v5_difficulty,p_score numeric,p_options jsonb default '[]',p_answer_key text default null,p_grading_rubric text default null,p_expected_keywords text[] default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare qid bigint; sid bigint; oc integer; cc integer;
begin
 if (select auth.uid()) is null or not public.v5_is_staff() then raise exception 'staff access required'; end if;
 select subject_id into sid from public.v5_topics where id=p_topic_id and is_active;
 if sid is null then raise exception 'curriculum node is required'; end if;
 if nullif(btrim(p_question_text),'') is null or coalesce(p_score,0)<=0 then raise exception 'question text and positive score are required'; end if;
 if p_question_type='multiple_choice' then
  select count(*),count(*) filter(where coalesce((j->>'is_correct')::boolean,false)) into oc,cc from jsonb_array_elements(coalesce(p_options,'[]')) j;
  if oc<2 or cc<>1 then raise exception 'exactly one correct option is required'; end if;
 elsif nullif(btrim(p_answer_key),'') is null then raise exception 'answer key is required'; end if;
 insert into public.v5_questions(subject_id,topic_id,question_type,difficulty,question_text,score,created_by,answer_key,grading_rubric,expected_keywords,manual_grading_required)
 values(sid,p_topic_id,p_question_type,p_difficulty,btrim(p_question_text),p_score,(select auth.uid()),nullif(btrim(p_answer_key),''),nullif(btrim(p_grading_rubric),''),p_expected_keywords,p_question_type<>'multiple_choice') returning id into qid;
 if p_question_type='multiple_choice' then
  insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order)
  select qid,coalesce(j->>'option_key',chr(64+o::integer)),j->>'option_text',coalesce((j->>'is_correct')::boolean,false),o from jsonb_array_elements(p_options) with ordinality a(j,o);
 end if;
 return qid;
end $$;

create or replace function public.v5_get_curriculum_questions(p_search text default null,p_book_id bigint default null,p_node_id bigint default null,p_limit integer default 500)
returns table(id bigint,question_text text,question_type text,difficulty text,score numeric,topic_id bigint,book_id bigint,book_title text,node_name text)
language sql security definer set search_path='' as $$
 select q.id,q.question_text,q.question_type::text,q.difficulty::text,q.score,q.topic_id,t.book_id,b.title,t.name
 from public.v5_questions q join public.v5_topics t on t.id=q.topic_id join public.v5_books b on b.id=t.book_id
 where public.v5_is_staff() and q.is_active and q.bank_question_id is null and (nullif(btrim(p_search),'') is null or q.question_text ilike '%'||btrim(p_search)||'%') and (p_book_id is null or t.book_id=p_book_id)
 and (p_node_id is null or t.id=p_node_id or t.parent_id=p_node_id or t.parent_id in(select id from public.v5_topics where parent_id=p_node_id))
 order by q.id desc limit least(greatest(p_limit,1),500) $$;

create or replace function public.v5_staff_build_curriculum_exam(p_title text,p_exam_code text,p_duration_minutes integer,p_question_ids bigint[],p_academic_year_id bigint,p_exam_kind public.v5_exam_kind,p_class_ids bigint[] default '{}')
returns bigint language plpgsql security definer set search_path='' as $$
declare eid bigint; qid bigint; snapshot_id bigint; n integer:=0; q public.v5_questions%rowtype;
begin
 if (select auth.uid()) is null or not public.v5_is_staff() then raise exception 'staff access required'; end if;
 if nullif(btrim(p_title),'') is null or nullif(btrim(p_exam_code),'') is null or p_duration_minutes not between 1 and 600 or coalesce(cardinality(p_question_ids),0)<1 then raise exception 'invalid exam data'; end if;
 insert into public.v5_exams(title,exam_code,duration_minutes,status,created_by,academic_year_id,exam_kind) values(btrim(p_title),btrim(p_exam_code),p_duration_minutes,'draft',(select auth.uid()),p_academic_year_id,p_exam_kind) returning id into eid;
 foreach qid in array p_question_ids loop
  select * into q from public.v5_questions where id=qid and is_active and bank_question_id is null;
  if not found then raise exception 'question unavailable'; end if;
  insert into public.v5_questions(subject_id,topic_id,source_id,question_type,difficulty,question_text,explanation,page_number,score,created_by,is_active,bank_question_id,answer_key,grading_rubric,expected_keywords,manual_grading_required)
  values(q.subject_id,q.topic_id,q.source_id,q.question_type,q.difficulty,q.question_text,q.explanation,q.page_number,q.score,(select auth.uid()),true,q.id,q.answer_key,q.grading_rubric,q.expected_keywords,q.manual_grading_required)
  returning id into snapshot_id;
  insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order)
  select snapshot_id,option_key,option_text,is_correct,sort_order from public.v5_question_options where question_id=qid;
  n:=n+1;
  insert into public.v5_exam_questions(exam_id,question_id,question_order,score) values(eid,snapshot_id,n,q.score);
 end loop;
 insert into public.v5_exam_classes(exam_id,class_id) select eid,x from unnest(coalesce(p_class_ids,'{}')) x join public.v5_classes c on c.id=x and c.academic_year_id=p_academic_year_id on conflict do nothing;
 return eid;
end $$;

revoke all on function public.v5_require_admin() from public,anon,authenticated;
revoke all on function public.v5_admin_create_academic_year(text,date,date,boolean) from public,anon;
revoke all on function public.v5_admin_set_active_academic_year(bigint) from public,anon;
revoke all on function public.v5_admin_add_class(bigint,bigint,bigint) from public,anon;
revoke all on function public.v5_admin_save_curriculum_question(bigint,public.v5_question_type,text,public.v5_difficulty,numeric,jsonb,text,text,text[]) from public,anon;
revoke all on function public.v5_get_curriculum_questions(text,bigint,bigint,integer) from public,anon;
revoke all on function public.v5_staff_build_curriculum_exam(text,text,integer,bigint[],bigint,public.v5_exam_kind,bigint[]) from public,anon;
grant execute on function public.v5_admin_create_academic_year(text,date,date,boolean),public.v5_admin_set_active_academic_year(bigint),public.v5_admin_add_class(bigint,bigint,bigint),public.v5_admin_save_curriculum_question(bigint,public.v5_question_type,text,public.v5_difficulty,numeric,jsonb,text,text,text[]),public.v5_get_curriculum_questions(text,bigint,bigint,integer),public.v5_staff_build_curriculum_exam(text,text,integer,bigint[],bigint,public.v5_exam_kind,bigint[]) to authenticated,service_role;
commit;
