-- Run only after the session-aware frontend is live.
revoke execute on function public.v5_start_exam(text,text),public.v5_get_attempt_state(uuid,text),
 public.v5_get_exam_questions(uuid,text),public.v5_get_saved_answers(uuid,text),
 public.v5_save_answer(uuid,bigint,bigint,text),public.v5_save_answers(uuid,text,jsonb),
 public.v5_submit_attempt(uuid,text),public.v5_get_student_result(uuid,text) from public,anon,authenticated;
