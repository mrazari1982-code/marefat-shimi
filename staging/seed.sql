-- Fresh staging database only; synthetic data. Run after schema-baseline.sql.
insert into public.v5_subjects(name,code) values ('درس آزمایشی محیط تست','STAGING-SUBJECT');
do $$
declare sid bigint; eid bigint; qid bigint; i integer; j integer;
begin
 select id into sid from public.v5_subjects where code='STAGING-SUBJECT';
 insert into public.v5_students(student_code,full_name) values
 ('STAGING-STUDENT-001','دانش‌آموز آزمایشی اول'),('STAGING-STUDENT-002','دانش‌آموز آزمایشی دوم');
 insert into public.v5_exams(exam_code,title,duration_minutes,status,show_result_to_student)
 values('STAGING-EXAM-001','آزمون سه‌سؤالی محیط تست',5,'draft',true) returning id into eid;
 for i in 1..3 loop
 insert into public.v5_questions(subject_id,question_text,score) values(sid,'سؤال آزمایشی '||i||': حاصل '||i||' + 1 چیست؟',1) returning id into qid;
 for j in 1..4 loop
 insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order) values(qid,chr(64+j),(i+j)::text,j=1,j);
 end loop;
 insert into public.v5_exam_questions(exam_id,question_id,question_order,score) values(eid,qid,i,1);
 end loop;
 update public.v5_exams set status='published' where id=eid;
 update public.v5_exam_links set max_attempts_per_student=10 where exam_id=eid;
end $$;
