-- Recalculate objective answers from their snapshot option when a descriptive
-- score is saved. Objective answer rows are not required to persist awarded score.
create or replace function public.v5_admin_grade_descriptive_answer(p_answer_id bigint,p_score numeric,p_feedback text default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_attempt_id uuid; v_max_score numeric; v_pending integer; v_total numeric; v_max_total numeric; v_percentage numeric;
begin
 if (select auth.uid()) is null or not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED' using errcode='42501'; end if;
 select sa.attempt_id,eq.score into v_attempt_id,v_max_score from public.v5_student_answers sa
 join public.v5_exam_questions eq on eq.id=sa.exam_question_id join public.v5_questions q on q.id=eq.question_id join public.v5_attempts a on a.id=sa.attempt_id
 where sa.id=p_answer_id and q.question_type='descriptive' and a.status='submitted' for update of sa,a;
 if not found then raise exception 'ANSWER_NOT_FOUND'; end if;
 if p_score is null or p_score<0 or p_score>v_max_score then raise exception 'SCORE_OUT_OF_RANGE'; end if;
 update public.v5_student_answers set score_awarded=p_score,
  is_correct=case when p_score=v_max_score then true when p_score=0 then false else null end,
  graded_by=auth.uid(),graded_at=clock_timestamp(),grading_feedback=nullif(btrim(coalesce(p_feedback,'')),'') where id=p_answer_id;
 select count(*) into v_pending from public.v5_student_answers sa
 join public.v5_exam_questions eq on eq.id=sa.exam_question_id join public.v5_questions q on q.id=eq.question_id
 where sa.attempt_id=v_attempt_id and q.question_type='descriptive' and nullif(btrim(sa.answer_text),'') is not null and sa.graded_at is null;
 select coalesce(sum(case when q.question_type<>'descriptive' and qo.is_correct then eq.score
   when q.question_type='descriptive' then coalesce(sa.score_awarded,0) else 0 end),0),coalesce(sum(eq.score),0)
 into v_total,v_max_total from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id
 left join public.v5_student_answers sa on sa.attempt_id=v_attempt_id and sa.exam_question_id=eq.id
 left join public.v5_question_options qo on qo.id=sa.selected_option_id
 where eq.exam_id=(select exam_id from public.v5_attempts where id=v_attempt_id);
 v_percentage:=case when v_max_total>0 then round(v_total*100/v_max_total,2) else 0 end;
 update public.v5_attempts set total_score=v_total,percentage=v_percentage,
  grading_status=case when v_pending>0 then 'pending_manual' else 'graded' end where id=v_attempt_id;
 return jsonb_build_object('answer_id',p_answer_id,'attempt_id',v_attempt_id,
  'grading_status',case when v_pending>0 then 'pending_manual' else 'graded' end,
  'pending_manual_count',v_pending,'total_score',v_total,
  'percentage',case when v_pending>0 then null else v_percentage end);
end $$;
revoke all on function public.v5_admin_grade_descriptive_answer(bigint,numeric,text) from public,anon;
grant execute on function public.v5_admin_grade_descriptive_answer(bigint,numeric,text) to authenticated;
