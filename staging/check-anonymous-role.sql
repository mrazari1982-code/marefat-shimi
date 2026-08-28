-- Staging only. Uses synthetic fixture token; commits a synthetic result.
begin;
set local role anon;
do $$
declare r jsonb; res jsonb; aid uuid; q record; seen int:=0; denied boolean:=false;
begin
 r:=public.v5_start_exam('f17a0d6e9b249631a86d5a70c12909a209d19c808c51765cdfa9c6d8bea67942',' staging-student-002 ');
 aid:=(r->>'attempt_id')::uuid;
 if r->>'student_code'<>'STAGING-STUDENT-002' then raise exception 'Canonical code failed'; end if;
 if public.v5_get_attempt_state(aid,'STAGING-STUDENT-002')->>'deadline_at' is null then raise exception 'Deadline absent'; end if;
 begin perform public.v5_get_attempt_state(aid,'INVALID'); exception when others then
  if sqlerrm in ('STUDENT_ACCESS_DENIED','ATTEMPT_OR_STUDENT_NOT_FOUND') then denied:=true; else raise; end if;
 end;
 if not denied then raise exception 'Wrong student accepted'; end if;
 for q in select * from public.v5_get_exam_questions(aid,'STAGING-STUDENT-002') where option_key='A' loop
  r:=public.v5_save_answer(aid,q.id,q.option_id,'STAGING-STUDENT-002');
  if not (r->>'saved')::boolean then raise exception 'Save failed'; end if;
  seen:=seen+1;
 end loop;
 if seen<>3 then raise exception 'Question count incorrect'; end if;
 r:=public.v5_start_exam('f17a0d6e9b249631a86d5a70c12909a209d19c808c51765cdfa9c6d8bea67942','STAGING-STUDENT-002');
 if (r->>'attempt_id')::uuid<>aid then raise exception 'Resume changed attempt'; end if;
 res:=public.v5_submit_attempt(aid,'STAGING-STUDENT-002');
 if (res->>'percentage')::numeric<>100 or res->>'status'<>'submitted' then raise exception 'Score wrong: %',res; end if;
 if public.v5_submit_attempt(aid,'STAGING-STUDENT-002')<>res then raise exception 'Retry changed result'; end if;
 denied:=false;
 begin perform public.v5_get_staff_exam_publish_list(); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Staff API accessible'; end if;
 begin if exists(select 1 from public.v5_students) then raise exception 'Student table exposed'; end if; exception when insufficient_privilege then null; end;
 begin if exists(select 1 from public.v5_question_options) then raise exception 'Answer key exposed'; end if; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: anonymous-role start/save/resume/submit/security checks' as result;
commit;
