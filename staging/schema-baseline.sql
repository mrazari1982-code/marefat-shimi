set check_function_bodies=off;
set search_path=public,extensions;
create schema v5_private;
revoke all on schema v5_private from public,anon,authenticated,service_role;
create type "public"."v5_attempt_status" as enum ('started','submitted','expired');
create type "public"."v5_difficulty" as enum ('easy','medium','hard');
create type "public"."v5_exam_status" as enum ('draft','published','closed');
create type "public"."v5_question_type" as enum ('multiple_choice','true_false','short_answer','descriptive');
create type "public"."v5_user_role" as enum ('admin','deputy','teacher','student');
create table "public"."exam_answers" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"student_id" uuid not null,
"question_id" bigint not null,
"selected_option" text,
"is_correct" boolean,
"answer_time" integer,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_profiles" ("id" uuid not null,
"full_name" text not null,
"role" v5_user_role default 'student'::v5_user_role not null,
"mobile" text,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null);
create table "public"."v5_grades" ("id" bigint generated always as identity not null,
"name" text not null,
"level_order" integer,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_fields" ("id" bigint generated always as identity not null,
"name" text not null,
"description" text,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_exam_links" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"token" text not null,
"is_active" boolean default true not null,
"max_attempts_per_student" integer,
"created_at" timestamp with time zone default now() not null,
"expires_at" timestamp with time zone);
create table "public"."v5_classes" ("id" bigint generated always as identity not null,
"name" text not null,
"grade_id" bigint,
"field_id" bigint,
"academic_year" text,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_subjects" ("id" bigint generated always as identity not null,
"name" text not null,
"code" text,
"description" text,
"grade_id" bigint,
"field_id" bigint,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_topics" ("id" bigint generated always as identity not null,
"subject_id" bigint not null,
"parent_id" bigint,
"name" text not null,
"description" text,
"sort_order" integer default 0 not null,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_sources" ("id" bigint generated always as identity not null,
"title" text not null,
"source_type" text not null,
"author" text,
"publisher" text,
"url" text,
"description" text,
"created_by" uuid,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_exam_classes" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"class_id" bigint not null);
create table "public"."v5_question_sources" ("id" bigint generated always as identity not null,
"title" text not null,
"publisher" text,
"author" text,
"edition" text,
"year" integer,
"source_type" text,
"source_url" text,
"description" text,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_question_bank" ("id" bigint generated always as identity not null,
"subject_id" bigint,
"topic_id" bigint,
"source_id" bigint,
"question_text" text not null,
"question_type" text default 'multiple_choice'::text not null,
"difficulty" text default 'medium'::text not null,
"score" numeric(8,2) default 1 not null,
"explanation" text,
"tags" text[] default '{}'::text[] not null,
"source_page" text,
"status" text default 'draft'::text not null,
"is_active" boolean default true not null,
"created_by" uuid,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null);
create table "public"."v5_question_bank_options" ("id" bigint generated always as identity not null,
"question_id" bigint not null,
"option_key" text not null,
"option_text" text not null,
"is_correct" boolean default false not null,
"sort_order" integer default 0 not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_student_answers" ("id" bigint generated always as identity not null,
"attempt_id" uuid not null,
"exam_question_id" bigint not null,
"selected_option_id" bigint,
"answer_text" text,
"is_correct" boolean,
"score_awarded" numeric(8,2) default 0 not null,
"answered_at" timestamp with time zone default now() not null);
create table "public"."v5_exams" ("id" bigint generated always as identity not null,
"exam_code" text not null,
"title" text not null,
"description" text,
"grade_id" bigint,
"field_id" bigint,
"duration_minutes" integer,
"start_at" timestamp with time zone,
"end_at" timestamp with time zone,
"status" v5_exam_status default 'draft'::v5_exam_status not null,
"randomize_questions" boolean default false not null,
"randomize_options" boolean default false not null,
"show_result_to_student" boolean default true not null,
"created_by" uuid,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null);
create table "public"."v5_attempts" ("id" uuid default gen_random_uuid() not null,
"exam_id" bigint not null,
"student_id" bigint not null,
"status" v5_attempt_status default 'started'::v5_attempt_status not null,
"started_at" timestamp with time zone default now() not null,
"submitted_at" timestamp with time zone,
"correct_count" integer default 0 not null,
"wrong_count" integer default 0 not null,
"blank_count" integer default 0 not null,
"total_score" numeric(8,2) default 0 not null,
"percentage" numeric(6,2) default 0 not null);
create table "public"."v5_students" ("id" bigint generated always as identity not null,
"user_id" uuid,
"student_code" text not null,
"full_name" text not null,
"grade_id" bigint,
"field_id" bigint,
"class_id" bigint,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null);
create table "public"."v5_questions" ("id" bigint generated always as identity not null,
"subject_id" bigint not null,
"topic_id" bigint,
"source_id" bigint,
"question_type" v5_question_type default 'multiple_choice'::v5_question_type not null,
"difficulty" v5_difficulty default 'medium'::v5_difficulty not null,
"question_text" text not null,
"explanation" text,
"page_number" integer,
"score" numeric(6,2) default 1 not null,
"created_by" uuid,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null,
"bank_question_id" bigint);
create table "public"."v5_question_options" ("id" bigint generated always as identity not null,
"question_id" bigint not null,
"option_key" text not null,
"option_text" text not null,
"is_correct" boolean default false not null,
"sort_order" integer default 0 not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."v5_exam_questions" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"question_id" bigint not null,
"question_order" integer not null,
"score" numeric(6,2) default 1 not null);
create table "public"."subjects" ("id" bigint generated always as identity not null,
"name" text not null,
"grade" text,
"field" text,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."topics" ("id" bigint generated always as identity not null,
"subject_id" bigint not null,
"name" text not null,
"chapter" text,
"description" text,
"created_at" timestamp with time zone default now() not null);
create table "public"."admin_profiles" ("id" uuid not null,
"full_name" text not null,
"role" text default 'admin'::text not null,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."questions" ("id" bigint generated always as identity not null,
"subject_id" bigint not null,
"topic_id" bigint,
"grade" text,
"field" text,
"question_type" text default 'multiple_choice'::text not null,
"question_text" text not null,
"option_a" text,
"option_b" text,
"option_c" text,
"option_d" text,
"correct_answer" text,
"explanation" text,
"difficulty" text default 'medium'::text not null,
"source_name" text,
"source_reference" text,
"score" numeric(6,2) default 1 not null,
"is_active" boolean default true not null,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null,
"chapter" text,
"topic" text,
"options" jsonb default '[]'::jsonb,
"tags" jsonb default '[]'::jsonb,
"created_by" uuid,
"points" numeric(5,2) default 1,
"exam_year" text,
"source_type" text default 'other'::text,
"sort_order" integer default 0);
create table "public"."exams" ("id" bigint generated always as identity not null,
"title" text not null,
"description" text,
"grade" text,
"field" text,
"duration_minutes" integer default 30 not null,
"total_questions" integer default 0 not null,
"start_at" timestamp with time zone,
"end_at" timestamp with time zone,
"exam_link" text,
"status" text default 'draft'::text not null,
"randomize_questions" boolean default true not null,
"randomize_options" boolean default true not null,
"show_result_after_submit" boolean default true not null,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null,
"total_score" numeric(8,2) default 20 not null,
"shuffle_questions" boolean default false not null,
"shuffle_options" boolean default false not null,
"show_result" boolean default true not null,
"allow_review" boolean default true not null,
"max_attempts" integer default 1 not null);
create table "public"."exam_questions" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"question_id" bigint not null,
"question_order" integer default 1 not null,
"score" numeric(6,2) default 1 not null,
"is_required" boolean default true not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."exam_links" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"question_id" bigint not null,
"question_order" integer default 1 not null,
"score" numeric(6,2) default 1 not null,
"created_at" timestamp with time zone default now() not null,
"token" text not null);
create table "public"."exam_results" ("id" bigint generated always as identity not null,
"exam_code" text not null,
"student_name" text not null,
"student_code" text not null,
"class_name" text not null,
"correct_count" integer default 0 not null,
"wrong_count" integer default 0 not null,
"blank_count" integer default 0 not null,
"percent" numeric(5,2) default 0 not null,
"answers" jsonb not null,
"submitted_at" timestamp with time zone default now() not null);
create table "public"."exam_attempts" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"student_id" uuid not null,
"started_at" timestamp with time zone default now() not null,
"submitted_at" timestamp with time zone,
"status" text default 'in_progress'::text not null,
"total_questions" integer default 0 not null,
"answered_questions" integer default 0 not null,
"correct_answers" integer default 0 not null,
"wrong_answers" integer default 0 not null,
"unanswered_questions" integer default 0 not null,
"score" numeric(6,2) default 0 not null,
"percentage" numeric(6,2) default 0 not null,
"duration_seconds" integer default 0 not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."student_answers" ("id" bigint generated always as identity not null,
"attempt_id" bigint not null,
"question_id" bigint not null,
"selected_option" text,
"is_correct" boolean default false not null,
"answer_time_seconds" integer default 0 not null,
"answered_at" timestamp with time zone default now() not null,
"created_at" timestamp with time zone default now() not null);
create table "public"."student_question_performance" ("id" bigint generated always as identity not null,
"student_id" uuid not null,
"question_id" bigint not null,
"total_attempts" integer default 0 not null,
"correct_attempts" integer default 0 not null,
"wrong_attempts" integer default 0 not null,
"accuracy" numeric(6,2) default 0 not null,
"average_time_seconds" numeric(10,2) default 0 not null,
"last_answered_at" timestamp with time zone,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null);
create table "public"."student_subject_performance" ("id" bigint generated always as identity not null,
"student_id" uuid not null,
"subject_id" bigint not null,
"total_questions" integer default 0 not null,
"answered_questions" integer default 0 not null,
"correct_answers" integer default 0 not null,
"wrong_answers" integer default 0 not null,
"unanswered_questions" integer default 0 not null,
"accuracy" numeric(6,2) default 0 not null,
"average_score" numeric(6,2) default 0 not null,
"average_time_seconds" numeric(10,2) default 0 not null,
"last_activity_at" timestamp with time zone,
"created_at" timestamp with time zone default now() not null,
"updated_at" timestamp with time zone default now() not null);
create table "public"."question_performance" ("id" bigint generated always as identity not null,
"question_id" bigint not null,
"total_attempts" integer default 0 not null,
"correct_attempts" integer default 0 not null,
"wrong_attempts" integer default 0 not null,
"unanswered_attempts" integer default 0 not null,
"accuracy" numeric(6,2) default 0 not null,
"average_time_seconds" numeric(10,2) default 0 not null,
"calculated_difficulty" text,
"last_calculated_at" timestamp with time zone default now() not null);
create table "public"."student_learning_summary" ("id" bigint generated always as identity not null,
"student_id" uuid not null,
"total_exams" integer default 0 not null,
"completed_exams" integer default 0 not null,
"total_questions" integer default 0 not null,
"correct_answers" integer default 0 not null,
"wrong_answers" integer default 0 not null,
"unanswered_questions" integer default 0 not null,
"overall_accuracy" numeric(6,2) default 0 not null,
"average_percentage" numeric(6,2) default 0 not null,
"strongest_subject_id" bigint,
"weakest_subject_id" bigint,
"last_exam_at" timestamp with time zone,
"updated_at" timestamp with time zone default now() not null);
create table "public"."exam_analytics" ("id" bigint generated always as identity not null,
"exam_id" bigint not null,
"total_attempts" integer default 0 not null,
"completed_attempts" integer default 0 not null,
"average_percentage" numeric(6,2) default 0 not null,
"highest_percentage" numeric(6,2) default 0 not null,
"lowest_percentage" numeric(6,2) default 0 not null,
"average_duration_seconds" numeric(10,2) default 0 not null,
"updated_at" timestamp with time zone default now() not null);
CREATE OR REPLACE FUNCTION public.v5_admin_create_question(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_question_type text DEFAULT 'multiple_choice'::text, p_difficulty text DEFAULT 'medium'::text, p_score numeric DEFAULT 1, p_explanation text DEFAULT NULL::text, p_tags text[] DEFAULT '{}'::text[], p_source_id bigint DEFAULT NULL::bigint, p_source_page text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_question_id bigint; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if trim(coalesce(p_question_text,''))='' then raise exception 'متن سؤال نمی‌تواند خالی باشد.'; end if; if p_score is null or p_score<0 then raise exception 'نمره سؤال نامعتبر است.'; end if; if p_subject_id is null or not exists(select 1 from public.v5_subjects where id=p_subject_id and is_active) then raise exception 'درس معتبر نیست.'; end if; if p_topic_id is not null and not exists(select 1 from public.v5_topics where id=p_topic_id and subject_id=p_subject_id and is_active) then raise exception 'مبحث با درس مطابقت ندارد.'; end if; insert into public.v5_question_bank(subject_id,topic_id,source_id,question_text,question_type,difficulty,score,explanation,tags,source_page,status,is_active) values(p_subject_id,p_topic_id,p_source_id,trim(p_question_text),p_question_type,p_difficulty,p_score,p_explanation,coalesce(p_tags,'{}'),p_source_page,'draft',true) returning id into v_question_id; return v_question_id; end;$function$
;
CREATE OR REPLACE FUNCTION public.refresh_question_performance(p_question_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_total integer;
    v_correct integer;
    v_wrong integer;
    v_unanswered integer;
    v_accuracy numeric;
    v_avg_time numeric;
    v_difficulty text;
begin

    select
        count(*),
        count(*) filter (where is_correct = true),
        count(*) filter (where is_correct = false),
        coalesce(
            count(*) filter (
                where selected_option is null
            ),
            0
        ),
        coalesce(avg(answer_time_seconds), 0)
    into
        v_total,
        v_correct,
        v_wrong,
        v_unanswered,
        v_avg_time
    from public.student_answers
    where question_id = p_question_id;


    if v_total > 0 then
        v_accuracy :=
            round(
                (v_correct::numeric / v_total::numeric) * 100,
                2
            );
    else
        v_accuracy := 0;
    end if;


    if v_accuracy >= 80 then
        v_difficulty := 'easy';

    elsif v_accuracy >= 50 then
        v_difficulty := 'medium';

    else
        v_difficulty := 'hard';
    end if;


    insert into public.question_performance (
        question_id,
        total_attempts,
        correct_attempts,
        wrong_attempts,
        unanswered_attempts,
        accuracy,
        average_time_seconds,
        calculated_difficulty,
        last_calculated_at
    )
    values (
        p_question_id,
        v_total,
        v_correct,
        v_wrong,
        v_unanswered,
        v_accuracy,
        v_avg_time,
        v_difficulty,
        now()
    )

    on conflict (question_id)
    do update set

        total_attempts =
            excluded.total_attempts,

        correct_attempts =
            excluded.correct_attempts,

        wrong_attempts =
            excluded.wrong_attempts,

        unanswered_attempts =
            excluded.unanswered_attempts,

        accuracy =
            excluded.accuracy,

        average_time_seconds =
            excluded.average_time_seconds,

        calculated_difficulty =
            excluded.calculated_difficulty,

        last_calculated_at =
            now();

end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_get_active_exam_link(p_exam_id bigint)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ declare v_token text; begin if not public.v5_is_staff() then raise exception 'access denied'; end if; select token into v_token from public.v5_exam_links where exam_id=p_exam_id and is_active=true order by created_at desc limit 1; if v_token is not null then return v_token; end if; if exists(select 1 from public.v5_exams where id=p_exam_id and status='published') then v_token:=replace(encode(extensions.digest((random()::text||clock_timestamp()::text||p_exam_id::text)::bytea,'sha256'),'hex'),' - ',''); insert into public.v5_exam_links(exam_id,token,is_active) values(p_exam_id,v_token,true); return v_token; end if; return null; end $function$
;
CREATE OR REPLACE FUNCTION public.get_exam_result_summary(p_exam_code text)
 RETURNS TABLE(exam_code text, total_students bigint, average_percent numeric, highest_percent numeric, lowest_percent numeric, average_correct numeric, average_wrong numeric, average_blank numeric)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select
        p_exam_code as exam_code,

        count(*) as total_students,

        round(
            coalesce(avg(percent), 0),
            2
        ) as average_percent,

        round(
            coalesce(max(percent), 0),
            2
        ) as highest_percent,

        round(
            coalesce(min(percent), 0),
            2
        ) as lowest_percent,

        round(
            coalesce(avg(correct_count), 0),
            2
        ) as average_correct,

        round(
            coalesce(avg(wrong_count), 0),
            2
        ) as average_wrong,

        round(
            coalesce(avg(blank_count), 0),
            2
        ) as average_blank

    from public.exam_results
    where exam_results.exam_code = p_exam_code;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_is_staff()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.v5_profiles
    where id = auth.uid()
      and role in ('admin', 'deputy', 'teacher')
      and is_active = true
  );
$function$
;
CREATE OR REPLACE FUNCTION public.v5_has_role(required_role v5_user_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.v5_profiles
    where id = auth.uid()
      and role = required_role
      and is_active = true
  );
$function$
;
CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select exists (
        select 1
        from public.admin_profiles
        where id = auth.uid()
          and is_active = true
          and role in ('admin', 'super_admin')
    );
$function$
;
CREATE OR REPLACE FUNCTION public.refresh_student_performance()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$

begin

    /*
     * محاسبه عملکرد هر دانش‌آموز در هر درس
     *
     * منبع پاسخ‌ها:
     * public.exam_answers
     *
     * اتصال سؤال:
     * public.questions
     *
     * درس:
     * questions.subject_id
     */

    insert into public.student_subject_performance
    (
        student_id,
        subject_id,

        total_questions,
        answered_questions,
        correct_answers,
        wrong_answers,
        unanswered_questions,

        accuracy,
        average_score,
        average_time_seconds,

        last_activity_at,
        updated_at
    )

    select

        ea.student_id,

        q.subject_id,


        -- تعداد کل پاسخ‌های ثبت‌شده
        count(*)::integer
            as total_questions,


        -- تعداد پاسخ‌های داده‌شده
        count(*)::integer
            as answered_questions,


        -- پاسخ‌های صحیح
        count(*) filter (
            where ea.is_correct = true
        )::integer
            as correct_answers,


        -- پاسخ‌های غلط
        count(*) filter (
            where ea.is_correct = false
        )::integer
            as wrong_answers,


        -- چون exam_answers فقط پاسخ‌های ثبت‌شده را نگهداری می‌کند،
        -- سؤال بدون پاسخ در این جدول وجود ندارد.
        0::integer
            as unanswered_questions,


        -- درصد دقت
        case

            when count(*) = 0 then 0

            else round(
                (
                    count(*) filter (
                        where ea.is_correct = true
                    )::numeric
                    /
                    count(*)::numeric
                ) * 100,
                2
            )

        end
            as accuracy,


        -- میانگین امتیاز سؤال
        coalesce(
            round(avg(q.score), 2),
            0
        )
            as average_score,


        -- میانگین زمان پاسخ
        coalesce(
            round(avg(ea.answer_time), 2),
            0
        )
            as average_time_seconds,


        -- آخرین فعالیت دانش‌آموز
        max(ea.created_at)
            as last_activity_at,


        now()
            as updated_at


    from public.exam_answers ea


    inner join public.questions q

        on q.id = ea.question_id


    where

        ea.student_id is not null

        and ea.question_id is not null

        and q.subject_id is not null


    group by

        ea.student_id,

        q.subject_id


    on conflict (student_id, subject_id)

    do update set

        total_questions =
            excluded.total_questions,

        answered_questions =
            excluded.answered_questions,

        correct_answers =
            excluded.correct_answers,

        wrong_answers =
            excluded.wrong_answers,

        unanswered_questions =
            excluded.unanswered_questions,

        accuracy =
            excluded.accuracy,

        average_score =
            excluded.average_score,

        average_time_seconds =
            excluded.average_time_seconds,

        last_activity_at =
            excluded.last_activity_at,

        updated_at =
            now();


end;

$function$
;
CREATE OR REPLACE FUNCTION public.v5_question_bank_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_start_attempt(p_exam_code text, p_student_code text)
 RETURNS TABLE(attempt_id uuid, exam_id bigint, exam_code text, exam_title text, student_id bigint, student_code text, full_name text, status text, duration_minutes integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_exam public.v5_exams%rowtype;
    v_student public.v5_students%rowtype;
    v_attempt public.v5_attempts%rowtype;
begin

    select e.*
    into v_exam
    from public.v5_exams as e
    where e.exam_code = trim(p_exam_code)
      and e.status = 'published'::public.v5_exam_status;

    if not found then
        raise exception 'آزمون منتشرشده با این کد پیدا نشد.';
    end if;


    select s.*
    into v_student
    from public.v5_students as s
    where s.student_code = trim(p_student_code)
      and s.is_active = true;

    if not found then
        raise exception 'دانش‌آموز فعال با این کد پیدا نشد.';
    end if;


    select a.*
    into v_attempt
    from public.v5_attempts as a
    where a.exam_id = v_exam.id
      and a.student_id = v_student.id;


    if found then

        if v_attempt.status =
           'submitted'::public.v5_attempt_status then

            return query
            select
                v_attempt.id,
                v_exam.id,
                v_exam.exam_code,
                v_exam.title,
                v_student.id,
                v_student.student_code,
                v_student.full_name,
                v_attempt.status::text,
                v_exam.duration_minutes;

            return;

        end if;

    else

        insert into public.v5_attempts(
            exam_id,
            student_id,
            status,
            correct_count,
            wrong_count,
            blank_count,
            total_score,
            percentage
        )
        values(
            v_exam.id,
            v_student.id,
            'started'::public.v5_attempt_status,
            0,
            0,
            0,
            0,
            0
        )
        returning *
        into v_attempt;

    end if;


    return query
    select
        v_attempt.id,
        v_exam.id,
        v_exam.exam_code,
        v_exam.title,
        v_student.id,
        v_student.student_code,
        v_student.full_name,
        v_attempt.status::text,
        v_exam.duration_minutes;

end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_build_exam_from_bank(p_exam_id bigint, p_bank_question_ids bigint[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_bank_id bigint;
    v_new_question_id bigint;
    v_order integer;
    v_count integer := 0;

    v_subject_id bigint;
    v_topic_id bigint;
    v_source_id bigint;
    v_question_type text;
    v_difficulty text;
    v_question_text text;
    v_explanation text;
    v_score numeric;
    v_page_number integer;

    v_option record;
begin

    -- بررسی وجود آزمون
    if not exists (
        select 1
        from public.v5_exams e
        where e.id = p_exam_id
    ) then
        raise exception
        'آزمون با شناسه % وجود ندارد.', p_exam_id;
    end if;


    -- اگر لیست سؤال خالی باشد
    if p_bank_question_ids is null
       or cardinality(p_bank_question_ids) = 0 then

        raise exception
        'هیچ سؤال بانکی برای ساخت آزمون انتخاب نشده است.';

    end if;


    -- ادامه ترتیب سؤال‌های موجود آزمون
    select
        coalesce(max(eq.question_order), 0)
    into
        v_order
    from public.v5_exam_questions eq
    where eq.exam_id = p_exam_id;


    -- پردازش سؤال‌های انتخاب‌شده
    foreach v_bank_id in array p_bank_question_ids
    loop

        -- اگر همین سؤال بانک قبلاً در همین آزمون وارد شده،
        -- دوباره ایجاد نشود.
        if exists (
            select 1
            from public.v5_questions q
            join public.v5_exam_questions eq
                on eq.question_id = q.id
            where eq.exam_id = p_exam_id
              and q.bank_question_id = v_bank_id
        ) then

            continue;

        end if;


        -- دریافت اطلاعات سؤال بانک
        select
            q.subject_id,
            q.topic_id,
            q.source_id,
            q.question_type,
            q.difficulty,
            q.question_text,
            q.explanation,
            q.score,
            nullif(q.source_page, '')::integer
        into
            v_subject_id,
            v_topic_id,
            v_source_id,
            v_question_type,
            v_difficulty,
            v_question_text,
            v_explanation,
            v_score,
            v_page_number
        from public.v5_question_bank q
        where q.id = v_bank_id
          and q.is_active = true
          and q.status = 'published';


        if not found then

            raise exception
            'سؤال بانک با شناسه % پیدا نشد یا منتشر نشده است.',
            v_bank_id;

        end if;


        -- ایجاد نسخه سؤال برای آزمون
        insert into public.v5_questions (
            subject_id,
            topic_id,
            source_id,
            question_type,
            difficulty,
            question_text,
            explanation,
            page_number,
            score,
            bank_question_id,
            is_active
        )
        values (
            v_subject_id,
            v_topic_id,
            v_source_id,
            v_question_type::public.v5_question_type,
            v_difficulty::public.v5_difficulty,
            v_question_text,
            v_explanation,
            v_page_number,
            v_score,
            v_bank_id,
            true
        )
        returning id
        into v_new_question_id;


        -- انتقال گزینه‌ها
        for v_option in
            select
                option_key,
                option_text,
                is_correct,
                sort_order
            from public.v5_question_bank_options
            where question_id = v_bank_id
            order by sort_order
        loop

            insert into public.v5_question_options (
                question_id,
                option_key,
                option_text,
                is_correct,
                sort_order
            )
            values (
                v_new_question_id,
                v_option.option_key,
                v_option.option_text,
                v_option.is_correct,
                v_option.sort_order
            );

        end loop;


        -- شماره سؤال بعدی
        v_order := v_order + 1;


        -- اتصال سؤال به آزمون
        insert into public.v5_exam_questions (
            exam_id,
            question_id,
            question_order,
            score
        )
        values (
            p_exam_id,
            v_new_question_id,
            v_order,
            v_score
        );


        v_count := v_count + 1;

    end loop;


    return v_count;

end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_update_question(p_question_id bigint, p_question_text text DEFAULT NULL::text, p_difficulty text DEFAULT NULL::text, p_score numeric DEFAULT NULL::numeric, p_explanation text DEFAULT NULL::text, p_tags text[] DEFAULT NULL::text[], p_source_page text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if not exists(select 1 from public.v5_question_bank where id=p_question_id) then raise exception 'سؤال موردنظر پیدا نشد.'; end if; if p_question_text is not null and trim(p_question_text)='' then raise exception 'متن سؤال نمی‌تواند خالی باشد.'; end if; if p_score is not null and p_score<0 then raise exception 'نمره سؤال نمی‌تواند منفی باشد.'; end if; update public.v5_question_bank set question_text=coalesce(trim(p_question_text),question_text),difficulty=coalesce(p_difficulty,difficulty),score=coalesce(p_score,score),explanation=coalesce(p_explanation,explanation),tags=coalesce(p_tags,tags),source_page=coalesce(p_source_page,source_page) where id=p_question_id; return true; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_add_option(p_question_id bigint, p_option_key text, p_option_text text, p_is_correct boolean DEFAULT false, p_sort_order integer DEFAULT 0)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_option_id bigint; v_correct_count integer; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if not exists(select 1 from public.v5_question_bank where id=p_question_id and is_active) then raise exception 'سؤال موردنظر پیدا نشد.'; end if; if trim(coalesce(p_option_key,''))='' or trim(coalesce(p_option_text,''))='' then raise exception 'کلید و متن گزینه الزامی است.'; end if; if p_is_correct then select count(*) into v_correct_count from public.v5_question_bank_options where question_id=p_question_id and is_correct; if v_correct_count>0 then raise exception 'این سؤال قبلاً یک گزینه صحیح دارد.'; end if; end if; insert into public.v5_question_bank_options(question_id,option_key,option_text,is_correct,sort_order) values(p_question_id,upper(trim(p_option_key)),trim(p_option_text),p_is_correct,p_sort_order) returning id into v_option_id; return v_option_id; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_archive_question(p_question_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; update public.v5_question_bank set status='archived',is_active=false where id=p_question_id; if not found then raise exception 'سؤال موردنظر پیدا نشد.'; end if; return true; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_delete_question(p_question_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if exists(select 1 from public.v5_questions q where q.bank_question_id=p_question_id) then raise exception 'این سؤال قبلاً استفاده شده و قابل حذف نیست.'; end if; delete from public.v5_question_bank where id=p_question_id; if not found then raise exception 'سؤال موردنظر پیدا نشد.'; end if; return true; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_publish_question(p_question_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_option_count integer; v_correct_count integer; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; select count(*) into v_option_count from public.v5_question_bank_options where question_id=p_question_id; select count(*) into v_correct_count from public.v5_question_bank_options where question_id=p_question_id and is_correct; if v_option_count<2 then raise exception 'برای انتشار سؤال حداقل دو گزینه لازم است.'; end if; if v_correct_count<>1 then raise exception 'برای انتشار سؤال باید دقیقاً یک گزینه صحیح وجود داشته باشد.'; end if; update public.v5_question_bank set status='published',is_active=true where id=p_question_id; if not found then raise exception 'سؤال موردنظر پیدا نشد.'; end if; return true; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_create_exam(p_exam_code text, p_title text, p_description text DEFAULT NULL::text, p_grade_id bigint DEFAULT NULL::bigint, p_field_id bigint DEFAULT NULL::bigint, p_duration_minutes integer DEFAULT 60, p_randomize_questions boolean DEFAULT false, p_randomize_options boolean DEFAULT false, p_show_result_to_student boolean DEFAULT true)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_exam_id bigint; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if trim(coalesce(p_exam_code,''))='' or trim(coalesce(p_title,''))='' then raise exception 'کد و عنوان آزمون الزامی است.'; end if; if p_duration_minutes is not null and p_duration_minutes<=0 then raise exception 'مدت آزمون باید بیشتر از صفر باشد.'; end if; if exists(select 1 from public.v5_exams where exam_code=trim(p_exam_code)) then raise exception 'کد آزمون قبلاً استفاده شده است.'; end if; insert into public.v5_exams(exam_code,title,description,grade_id,field_id,duration_minutes,status,randomize_questions,randomize_options,show_result_to_student,created_by,created_at,updated_at) values(trim(p_exam_code),trim(p_title),p_description,p_grade_id,p_field_id,p_duration_minutes,'draft'::public.v5_exam_status,p_randomize_questions,p_randomize_options,p_show_result_to_student,auth.uid(),now(),now()) returning id into v_exam_id; return v_exam_id; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_publish_exam(p_exam_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_question_count integer; v_invalid_questions integer; v_exam_status text; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; select status::text into v_exam_status from public.v5_exams where id=p_exam_id; if not found then raise exception 'آزمون پیدا نشد.'; end if; if v_exam_status='published' then return true; end if; select count(*) into v_question_count from public.v5_exam_questions where exam_id=p_exam_id; if v_question_count=0 then raise exception 'آزمون حداقل باید یک سؤال داشته باشد.'; end if; select count(*) into v_invalid_questions from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id where eq.exam_id=p_exam_id and (not q.is_active or (select count(*) from public.v5_question_options o where o.question_id=q.id)<2 or (select count(*) from public.v5_question_options o where o.question_id=q.id and o.is_correct)<>1); if v_invalid_questions>0 then raise exception 'تعداد % سؤال ناقص یا نامعتبر است.',v_invalid_questions; end if; update public.v5_exams set status='published'::public.v5_exam_status,updated_at=now() where id=p_exam_id; return true; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_add_bank_question_to_exam(p_exam_id bigint, p_bank_question_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_bank_question_id bigint:=p_bank_question_id; v_question_id bigint; v_next_order integer; v_score numeric; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if not exists(select 1 from public.v5_exams where id=p_exam_id) then raise exception 'آزمون پیدا نشد.'; end if; if exists(select 1 from public.v5_exams where id=p_exam_id and status::text='published') then raise exception 'آزمون منتشرشده قابل ویرایش نیست.'; end if; if not exists(select 1 from public.v5_question_bank where id=v_bank_question_id and status::text='published' and is_active) then select q.bank_question_id into v_bank_question_id from public.v5_questions q join public.v5_question_bank b on b.id=q.bank_question_id where q.id=p_bank_question_id and q.bank_question_id is not null and q.is_active and b.status::text='published' and b.is_active limit 1; end if; if v_bank_question_id is null then raise exception 'سؤال بانک وجود ندارد یا منتشر نشده است.'; end if; select score into v_score from public.v5_question_bank where id=v_bank_question_id and status::text='published' and is_active; if not found then raise exception 'سؤال بانک وجود ندارد یا منتشر نشده است.'; end if; select q.id into v_question_id from public.v5_questions q join public.v5_exam_questions eq on eq.question_id=q.id where eq.exam_id=p_exam_id and q.bank_question_id=v_bank_question_id limit 1; if found then return v_question_id; end if; insert into public.v5_questions(subject_id,topic_id,source_id,question_type,difficulty,question_text,explanation,page_number,score,bank_question_id,is_active) select subject_id,topic_id,source_id,question_type::public.v5_question_type,difficulty::public.v5_difficulty,question_text,explanation,nullif(source_page,'')::integer,score,id,true from public.v5_question_bank where id=v_bank_question_id returning id into v_question_id; insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order) select v_question_id,option_key,option_text,is_correct,sort_order from public.v5_question_bank_options where question_id=v_bank_question_id order by sort_order; select coalesce(max(question_order),0)+1 into v_next_order from public.v5_exam_questions where exam_id=p_exam_id; insert into public.v5_exam_questions(exam_id,question_id,question_order,score) values(p_exam_id,v_question_id,v_next_order,v_score); return v_question_id; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_remove_exam_question(p_exam_id bigint, p_question_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if exists(select 1 from public.v5_exams where id=p_exam_id and status::text='published') then raise exception 'آزمون منتشرشده قابل ویرایش نیست.'; end if; delete from public.v5_exam_questions where exam_id=p_exam_id and question_id=p_question_id; if not found then raise exception 'این سؤال در آزمون وجود ندارد.'; end if; return true; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_student_answers_recalculate_attempt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'DELETE' then
    perform public.v5_recalculate_attempt_result(old.attempt_id);
  else
    perform public.v5_recalculate_attempt_result(new.attempt_id);
    if tg_op = 'UPDATE' and old.attempt_id is distinct from new.attempt_id then
      perform public.v5_recalculate_attempt_result(old.attempt_id);
    end if;
  end if;
  return coalesce(new, old);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_finalize_attempt(p_attempt_id uuid)
 RETURNS v5_attempts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_attempt public.v5_attempts; v_correct integer; v_wrong integer; v_blank integer; v_score numeric; v_total numeric; begin
 select * into v_attempt from public.v5_attempts where id=p_attempt_id for update;
 if not found then raise exception 'Attempt not found'; end if;
 if v_attempt.status::text='submitted' then return v_attempt; end if;
 select count(*) filter (where sa.selected_option_id is not null and coalesce(sa.is_correct,false)=true), count(*) filter (where sa.selected_option_id is not null and coalesce(sa.is_correct,false)=false), count(*) filter (where sa.selected_option_id is null), coalesce(sum(sa.score_awarded),0), coalesce(sum(eq.score),0) into v_correct,v_wrong,v_blank,v_score,v_total from public.v5_exam_questions eq left join public.v5_student_answers sa on sa.exam_question_id=eq.id and sa.attempt_id=p_attempt_id where eq.exam_id=v_attempt.exam_id;
 update public.v5_attempts set status='submitted'::v5_attempt_status,submitted_at=now(),correct_count=v_correct,wrong_count=v_wrong,blank_count=v_blank,total_score=round(v_score,2),percentage=case when v_total=0 then 0 else round((v_score/v_total)*100,2) end where id=p_attempt_id returning * into v_attempt;
 return v_attempt;
end; $function$
;
CREATE OR REPLACE FUNCTION public.v5_close_exam(p_exam_id bigint)
 RETURNS v5_exams
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare r public.v5_exams; begin
 if not public.v5_is_staff() then raise exception 'access denied'; end if;
 update public.v5_exams set status='closed' where id=p_exam_id and status='published' returning * into r;
 if r.id is null then raise exception 'exam not found or not published'; end if; return r; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_create_exam(p_title text, p_exam_code text, p_description text DEFAULT NULL::text, p_grade_id bigint DEFAULT NULL::bigint, p_field_id bigint DEFAULT NULL::bigint, p_duration_minutes integer DEFAULT 60, p_question_ids bigint[] DEFAULT '{}'::bigint[])
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_exam_id bigint; v_uid uuid:=auth.uid(); v_i integer; begin if v_uid is null or not public.v5_is_staff() then raise exception 'ADMIN_ACCESS_REQUIRED'; end if; if nullif(trim(p_title),'') is null then raise exception 'TITLE_REQUIRED'; end if; if nullif(trim(p_exam_code),'') is null then raise exception 'EXAM_CODE_REQUIRED'; end if; if exists(select 1 from public.v5_exams where exam_code=trim(p_exam_code)) then raise exception 'EXAM_CODE_EXISTS'; end if; insert into public.v5_exams(exam_code,title,description,grade_id,field_id,duration_minutes,status,randomize_questions,randomize_options,show_result_to_student,created_by,created_at,updated_at) values(trim(p_exam_code),trim(p_title),p_description,p_grade_id,p_field_id,greatest(coalesce(p_duration_minutes,60),1),'draft',false,false,true,v_uid,now(),now()) returning id into v_exam_id; if coalesce(array_length(p_question_ids,1),0)>0 then for v_i in 1..array_length(p_question_ids,1) loop insert into public.v5_exam_questions(exam_id,question_id,question_order,score) values(v_exam_id,p_question_ids[v_i],v_i,1); end loop; end if; return v_exam_id; end; $function$
;
CREATE OR REPLACE FUNCTION public.v5_list_staff_exam_links(p_exam_id bigint DEFAULT NULL::bigint)
 RETURNS TABLE(id bigint, exam_id bigint, exam_title text, exam_code text, token text, is_active boolean, max_attempts_per_student integer, expires_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.v5_is_staff() then raise exception 'access denied'; end if;
  return query
  select l.id,l.exam_id,e.title,e.exam_code,l.token,l.is_active,l.max_attempts_per_student,l.expires_at,l.created_at
  from public.v5_exam_links l join public.v5_exams e on e.id=l.exam_id
  where p_exam_id is null or l.exam_id=p_exam_id
  order by l.id desc limit 200;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_get_saved_answers(p_attempt_id uuid, p_student_code text)
 RETURNS TABLE(exam_question_id bigint, selected_option_id bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists(
    select 1
    from public.v5_attempts a
    join public.v5_students s on s.id=a.student_id
    where a.id=p_attempt_id
      and lower(trim(s.student_code))=lower(trim(p_student_code))
      and s.is_active=true
      and a.status='started'::public.v5_attempt_status
  ) then
    raise exception 'ATTEMPT_OR_STUDENT_NOT_FOUND';
  end if;
  if not public.v5_check_attempt_time(p_attempt_id) then
    raise exception 'EXAM_TIME_EXPIRED';
  end if;
  return query
  select sa.exam_question_id,sa.selected_option_id
  from public.v5_student_answers sa
  where sa.attempt_id=p_attempt_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_get_admin_attempt_reports(p_exam_id bigint DEFAULT NULL::bigint, p_limit integer DEFAULT 100)
 RETURNS TABLE(attempt_id uuid, exam_id bigint, exam_title text, exam_code text, student_id bigint, student_name text, student_code text, correct_count integer, wrong_count integer, blank_count integer, percentage numeric, status text, started_at timestamp with time zone, submitted_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not coalesce(public.v5_is_staff(), false) then
    raise exception 'staff access required' using errcode = '42501';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 500 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  return query
  select a.id, a.exam_id, e.title, e.exam_code, a.student_id,
         s.full_name, s.student_code, a.correct_count, a.wrong_count,
         a.blank_count, a.percentage, a.status::text, a.started_at, a.submitted_at
  from public.v5_attempts a
  join public.v5_exams e on e.id = a.exam_id
  join public.v5_students s on s.id = a.student_id
  where p_exam_id is null or a.exam_id = p_exam_id
  order by a.submitted_at desc nulls last, a.started_at desc
  limit p_limit;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_set_exam_link_active(p_link_id bigint, p_is_active boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.v5_is_staff() then raise exception 'access denied'; end if;
  update public.v5_exam_links set is_active=p_is_active where id=p_link_id;
  if not found then raise exception 'LINK_NOT_FOUND'; end if;
  return p_is_active;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_get_admin_analytics(p_exam_id bigint DEFAULT NULL::bigint, p_limit integer DEFAULT 500)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare result jsonb; begin if not public.v5_is_staff() then raise exception 'access denied'; end if; if p_limit < 1 or p_limit > 500 then raise exception 'invalid limit'; end if; with attempts as (select a.id,a.exam_id,a.student_id,a.correct_count,a.wrong_count,a.blank_count,a.percentage,a.status,a.started_at,a.submitted_at from public.v5_attempts a where a.status='submitted' and (p_exam_id is null or a.exam_id=p_exam_id) order by a.submitted_at desc nulls last limit p_limit), students as (select s.id student_id,s.full_name,s.student_code,count(a.id)::integer exam_count,round(avg(a.percentage),2) average_percentage,sum(a.correct_count)::integer correct_count,sum(a.wrong_count)::integer wrong_count,sum(a.blank_count)::integer blank_count,max(a.submitted_at) last_exam_at,case when avg(a.percentage)>=85 then 'عالی' when avg(a.percentage)>=70 then 'خوب' when avg(a.percentage)>=50 then 'متوسط' else 'ضعیف' end performance_level from attempts a join public.v5_students s on s.id=a.student_id group by s.id,s.full_name,s.student_code), exams as (select e.id exam_id,e.exam_code,e.title,count(a.id)::integer attempt_count,round(avg(a.percentage),2) average_percentage,max(a.percentage) highest_percentage,min(a.percentage) lowest_percentage from public.v5_exams e left join attempts a on a.exam_id=e.id where p_exam_id is null or e.id=p_exam_id group by e.id,e.exam_code,e.title), question_stats as (select eq.exam_id,eq.id exam_question_id,eq.question_id,eq.question_order,q.question_text,q.difficulty,count(a.id)::integer total_attempts,count(sa.id)::integer answered_count,count(sa.id) filter(where sa.is_correct=true)::integer correct_count,count(sa.id) filter(where sa.is_correct=false)::integer wrong_count from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id left join attempts a on a.exam_id=eq.exam_id left join public.v5_student_answers sa on sa.attempt_id=a.id and sa.exam_question_id=eq.id where p_exam_id is null or eq.exam_id=p_exam_id group by eq.exam_id,eq.id,eq.question_id,eq.question_order,q.question_text,q.difficulty), subject_stats as (select q.subject_id,sub.name subject_name,count(*)::integer total_questions,count(sa.id)::integer answered_questions,count(sa.id) filter(where sa.is_correct=true)::integer correct_answers,count(sa.id) filter(where sa.is_correct=false)::integer wrong_answers,(count(*)-count(sa.id))::integer unanswered_questions,round(case when count(*)=0 then 0 else 100.0*count(sa.id) filter(where sa.is_correct=true)/count(*) end,2) accuracy from attempts a join public.v5_exam_questions eq on eq.exam_id=a.exam_id join public.v5_questions q on q.id=eq.question_id join public.v5_subjects sub on sub.id=q.subject_id left join public.v5_student_answers sa on sa.attempt_id=a.id and sa.exam_question_id=eq.id where p_exam_id is null or a.exam_id=p_exam_id group by q.subject_id,sub.name) select jsonb_build_object('summary',jsonb_build_object('submitted_attempts',(select count(*) from attempts),'student_count',(select count(*) from students),'average_percentage',coalesce((select round(avg(percentage),2) from attempts),0),'correct_count',coalesce((select sum(correct_count) from attempts),0),'wrong_count',coalesce((select sum(wrong_count) from attempts),0),'blank_count',coalesce((select sum(blank_count) from attempts),0)),'students',coalesce((select jsonb_agg(to_jsonb(students) order by average_percentage desc nulls last,full_name) from students),'[]'::jsonb),'exams',coalesce((select jsonb_agg(to_jsonb(exams) order by average_percentage desc nulls last) from exams),'[]'::jsonb),'question_stats',coalesce((select jsonb_agg(to_jsonb(question_stats) order by exam_id,question_order) from question_stats),'[]'::jsonb),'subject_stats',coalesce((select jsonb_agg(to_jsonb(subject_stats) order by accuracy desc nulls last,subject_name) from subject_stats),'[]'::jsonb)) into result; return result; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_get_staff_exam_publish_list()
 RETURNS TABLE(id bigint, title text, exam_code text, status text, duration_minutes integer, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ begin
 if not public.v5_is_staff() then raise exception 'access denied'; end if;
 return query select e.id,e.title,e.exam_code,e.status::text,e.duration_minutes,e.created_at from public.v5_exams e order by e.id desc limit 100;
end $function$
;
CREATE OR REPLACE FUNCTION public.v5_publish_exam(p_exam_id bigint)
 RETURNS v5_exams
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare r public.v5_exams; begin
 if not public.v5_is_staff() then raise exception 'access denied'; end if;
 update public.v5_exams set status='published' where id=p_exam_id and status='draft' returning * into r;
 if r.id is null then raise exception 'exam not found or not draft'; end if; return r; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_create_student(p_student_code text, p_full_name text)
 RETURNS v5_students
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v public.v5_students; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; if nullif(trim(p_student_code),'') is null or nullif(trim(p_full_name),'') is null then raise exception 'کد و نام دانش‌آموز الزامی است'; end if; if exists(select 1 from public.v5_students s where lower(s.student_code)=lower(trim(p_student_code))) then raise exception 'کد دانش‌آموز تکراری است'; end if; insert into public.v5_students(student_code,full_name,is_active) values(trim(p_student_code),trim(p_full_name),true) returning * into v; return v; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_list_students(p_search text DEFAULT ''::text)
 RETURNS TABLE(id bigint, student_code text, full_name text, is_active boolean, created_at timestamp with time zone, attempt_count bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select s.id,s.student_code,s.full_name,s.is_active,s.created_at,count(a.id) from public.v5_students s left join public.v5_attempts a on a.student_id=s.id where exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) and (coalesce(trim(p_search),'')='' or s.student_code ilike '%'||trim(p_search)||'%' or s.full_name ilike '%'||trim(p_search)||'%') group by s.id order by s.created_at desc $function$
;
CREATE OR REPLACE FUNCTION public.v5_set_exam_link_limits(p_link_id bigint, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_attempts integer DEFAULT NULL::integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ begin
 if not public.v5_is_staff() then raise exception 'access denied'; end if;
 if p_max_attempts is not null and p_max_attempts <> 1 then raise exception 'MAX_ATTEMPTS_MUST_BE_ONE_WITH_CURRENT_ATTEMPT_MODEL'; end if;
 if p_expires_at is not null and p_expires_at<=now() then raise exception 'INVALID_EXPIRY'; end if;
 update public.v5_exam_links set expires_at=p_expires_at,max_attempts_per_student=p_max_attempts where id=p_link_id;
 if not found then raise exception 'LINK_NOT_FOUND'; end if; return true;
end $function$
;
CREATE OR REPLACE FUNCTION public.v5_start_exam(p_token text, p_student_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_link public.v5_exam_links%rowtype;
  v_exam public.v5_exams%rowtype;
  v_student public.v5_students%rowtype;
  v_attempt public.v5_attempts%rowtype;
  v_attempt_count integer := 0;
  v_time_ok boolean;
begin
  select l.* into v_link
  from public.v5_exam_links l
  where lower(trim(l.token))=lower(trim(p_token))
    and l.is_active=true
    and (l.expires_at is null or now()<=l.expires_at)
  order by l.created_at desc
  limit 1;
  if not found then raise exception 'INVALID_EXAM_LINK'; end if;

  select e.* into v_exam from public.v5_exams e where e.id=v_link.exam_id;
  if not found then raise exception 'EXAM_NOT_FOUND'; end if;
  if v_exam.status<>'published'::public.v5_exam_status then raise exception 'EXAM_NOT_PUBLISHED'; end if;
  if v_exam.start_at is not null and now()<v_exam.start_at then raise exception 'EXAM_NOT_STARTED'; end if;
  if v_exam.end_at is not null and now()>v_exam.end_at then raise exception 'EXAM_CLOSED'; end if;

  select s.* into v_student
  from public.v5_students s
  where lower(trim(s.student_code))=lower(trim(p_student_code)) and s.is_active=true
  limit 1;
  if not found then raise exception 'STUDENT_NOT_FOUND'; end if;

  -- Resume the newest live attempt only.
  select a.* into v_attempt
  from public.v5_attempts a
  where a.exam_id=v_exam.id and a.student_id=v_student.id and a.status='started'::public.v5_attempt_status
  order by a.started_at desc nulls last
  limit 1;
  if found then
    v_time_ok := public.v5_check_attempt_time(v_attempt.id);
    if v_time_ok then
      return jsonb_build_object(
        'status','started','attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,
        'student_name',v_student.full_name,'student_code',v_student.student_code,
        'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at
      );
    end if;
    v_attempt:=v5_private.finalize_attempt(v_attempt.id);
    return jsonb_build_object('status',v_attempt.status,'attempt_id',v_attempt.id,'exam_id',v_exam.id,
     'title',v_exam.title,'student_name',v_student.full_name,'student_code',v_student.student_code);
  end if;

  select count(*)::int into v_attempt_count
  from public.v5_attempts a
  where a.exam_id=v_exam.id and a.student_id=v_student.id;

  if v_link.max_attempts_per_student is not null and v_attempt_count >= v_link.max_attempts_per_student then
    select a.* into v_attempt from public.v5_attempts a
     where a.exam_id=v_exam.id and a.student_id=v_student.id and a.status='submitted'
     order by a.submitted_at desc nulls last limit 1;
    if found then
     return jsonb_build_object('status','submitted','attempt_id',v_attempt.id,'exam_id',v_exam.id,
      'title',v_exam.title,'student_name',v_student.full_name,'student_code',v_student.student_code);
    end if;
    raise exception 'MAX_ATTEMPTS_REACHED';
  end if;

  insert into public.v5_attempts(exam_id,student_id,status,started_at)
  values(v_exam.id,v_student.id,'started'::public.v5_attempt_status,now())
  returning * into v_attempt;

  return jsonb_build_object(
    'status','started','attempt_id',v_attempt.id,'exam_id',v_exam.id,'title',v_exam.title,
    'student_name',v_student.full_name,'student_code',v_student.student_code,
    'duration_minutes',v_exam.duration_minutes,'started_at',v_attempt.started_at
  );
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_set_student_active(p_id bigint, p_active boolean)
 RETURNS v5_students
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v public.v5_students; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; update public.v5_students set is_active=p_active where id=p_id returning * into v; if v.id is null then raise exception 'دانش‌آموز پیدا نشد'; end if; return v; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_update_student(p_id bigint, p_student_code text, p_full_name text)
 RETURNS v5_students
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v public.v5_students; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; if exists(select 1 from public.v5_students s where lower(s.student_code)=lower(trim(p_student_code)) and s.id<>p_id) then raise exception 'کد دانش‌آموز تکراری است'; end if; update public.v5_students set student_code=trim(p_student_code),full_name=trim(p_full_name) where id=p_id returning * into v; if v.id is null then raise exception 'دانش‌آموز پیدا نشد'; end if; return v; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_set_exam_schedule(p_exam_id bigint, p_start_at timestamp with time zone, p_end_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ declare v_status public.v5_exam_status; begin if not public.v5_is_staff() then raise exception 'access denied'; end if; if p_start_at is not null and p_end_at is not null and p_start_at>=p_end_at then raise exception 'start_at must be before end_at'; end if; select status into v_status from public.v5_exams where id=p_exam_id; if v_status is null then raise exception 'exam not found'; end if; if v_status='closed' then raise exception 'closed exam schedule cannot be changed'; end if; update public.v5_exams set start_at=p_start_at,end_at=p_end_at,updated_at=now() where id=p_exam_id; return jsonb_build_object('exam_id',p_exam_id,'start_at',p_start_at,'end_at',p_end_at,'status',v_status); end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_set_exam_status(p_exam_id bigint, p_status v5_exam_status)
 RETURNS v5_exam_status
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ declare v_q integer; v_old public.v5_exam_status; begin if not public.v5_is_staff() then raise exception 'access denied'; end if; select status into v_old from public.v5_exams where id=p_exam_id for update; if v_old is null then raise exception 'exam not found'; end if; select count(*) into v_q from public.v5_exam_questions where exam_id=p_exam_id; if p_status='published' and v_q=0 then raise exception 'cannot publish an exam without questions'; end if; update public.v5_exams set status=p_status,updated_at=now() where id=p_exam_id; if p_status='published' then perform public.v5_ensure_exam_link(p_exam_id); else update public.v5_exam_links set is_active=false where exam_id=p_exam_id; end if; return p_status; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_get_student_result(p_attempt_id uuid, p_student_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_attempt public.v5_attempts%rowtype;
  v_student public.v5_students%rowtype;
  v_exam public.v5_exams%rowtype;
  v_details jsonb;
begin
  select * into v_attempt from public.v5_attempts where id=p_attempt_id;
  if not found then raise exception 'RESULT_NOT_FOUND'; end if;
  if v_attempt.status <> 'submitted'::public.v5_attempt_status then raise exception 'RESULT_NOT_AVAILABLE'; end if;

  select * into v_student
  from public.v5_students
  where id=v_attempt.student_id
    and lower(trim(student_code))=lower(trim(p_student_code))
    and is_active=true;
  if not found then raise exception 'STUDENT_DOES_NOT_MATCH_RESULT'; end if;

  select * into v_exam from public.v5_exams where id=v_attempt.exam_id;
  if not found then raise exception 'EXAM_NOT_FOUND'; end if;
  if coalesce(v_exam.show_result_to_student,false) = false then raise exception 'RESULT_HIDDEN'; end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_order',r.question_order,
        'question_text',r.question_text,
        'answer_text',r.answer_text,
        'is_correct',r.is_correct,
        'score_awarded',r.score_awarded
      ) order by r.question_order
    ), '[]'::jsonb
  ) into v_details
  from public.v5_attempt_answer_report_view r
  where r.attempt_id=p_attempt_id;

  return jsonb_build_object(
    'attempt_id',v_attempt.id,
    'student_name',v_student.full_name,
    'student_code',v_student.student_code,
    'exam_title',v_exam.title,
    'exam_code',v_exam.exam_code,
    'correct_count',v_attempt.correct_count,
    'wrong_count',v_attempt.wrong_count,
    'blank_count',v_attempt.blank_count,
    'total_score',v_attempt.total_score,
    'percentage',v_attempt.percentage,
    'status',v_attempt.status,
    'submitted_at',v_attempt.submitted_at,
    'details',v_details
  );
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_check_attempt_time(p_attempt_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.v5_attempts; deadline timestamptz;
begin
 select * into a from public.v5_attempts where id=p_attempt_id for update;
 if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
 if a.status<>'started' then return false; end if;
 deadline:=v5_private.attempt_deadline(a.id);
 return deadline is null or clock_timestamp()<deadline;
end $function$
;
CREATE OR REPLACE FUNCTION public.v5_get_exam_questions(p_attempt_id uuid, p_student_code text)
 RETURNS TABLE(id bigint, question_order integer, score numeric, question_text text, option_id bigint, option_key text, option_text text, sort_order integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
declare
  a public.v5_attempts;
  s public.v5_students;
begin
  select a0.* into a from public.v5_attempts as a0 where a0.id=p_attempt_id;
  if a.id is null then raise exception 'ATTEMPT_NOT_FOUND'; end if;
  select s0.* into s from public.v5_students as s0 where s0.id=a.student_id and s0.student_code=trim(p_student_code) and s0.is_active=true;
  if s.id is null then raise exception 'STUDENT_ACCESS_DENIED'; end if;
  if a.status<>'started' then raise exception 'EXAM_NOT_ACTIVE'; end if;
  if not public.v5_check_attempt_time(a.id) then raise exception 'EXAM_TIME_EXPIRED'; end if;
  return query
  select eq.id,eq.question_order,eq.score,q.question_text,qo.id,qo.option_key,qo.option_text,qo.sort_order
  from public.v5_exam_questions as eq
  join public.v5_questions as q on q.id=eq.question_id
  join public.v5_question_options as qo on qo.question_id=eq.question_id
  where eq.exam_id=a.exam_id
  order by eq.question_order,qo.sort_order;
end $function$
;
CREATE OR REPLACE FUNCTION public.v5_get_staff_question_bank(p_search text DEFAULT NULL::text, p_subject text DEFAULT NULL::text, p_grade text DEFAULT NULL::text, p_difficulty text DEFAULT NULL::text, p_limit integer DEFAULT 500)
 RETURNS TABLE(id bigint, question_text text, subject text, grade text, difficulty text, options jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.v5_is_staff() then raise exception 'access denied'; end if;
  if p_limit < 1 or p_limit > 500 then raise exception 'invalid limit'; end if;
  return query
  select q.id,
         q.question_text,
         s.name,
         g.name,
         q.difficulty::text,
         coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'text',o.option_text,'key',o.option_key,'sort_order',o.sort_order) order by o.sort_order)
                   from public.v5_question_bank_options o where o.question_id=q.id),'[]'::jsonb)
  from public.v5_question_bank q
  join public.v5_subjects s on s.id=q.subject_id
  join public.v5_grades g on g.id=s.grade_id
  where q.is_active=true
    and q.status::text='published'
    and (nullif(trim(p_search),'') is null or q.question_text ilike '%'||trim(p_search)||'%')
    and (nullif(trim(p_subject),'') is null or s.name=p_subject)
    and (nullif(trim(p_grade),'') is null or g.name=p_grade)
    and (nullif(trim(p_difficulty),'') is null or q.difficulty::text=p_difficulty)
  order by q.id desc
  limit p_limit;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_get_exam_questions(p_exam_id bigint)
 RETURNS TABLE(id bigint, question_id bigint, question_order integer, score numeric, question_text text, question_type text, difficulty text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select eq.id,eq.question_id,eq.question_order,eq.score,q.question_text,q.question_type::text,q.difficulty::text
 from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id
 where eq.exam_id=p_exam_id
 and exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active=true and p.role in ('admin','deputy','teacher'))
 order by eq.question_order;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_question_bank_context()
 RETURNS TABLE(profile_role text, profile_active boolean, published_bank_count bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select p.role::text,p.is_active,(select count(*) from public.v5_question_bank qb where qb.is_active and qb.status='published') from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy','teacher') limit 1 $function$
;
CREATE OR REPLACE FUNCTION public.v5_save_answer(p_attempt_id uuid, p_exam_question_id bigint, p_selected_option_id bigint, p_student_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  a public.v5_attempts%rowtype;
  eq public.v5_exam_questions%rowtype;
  o public.v5_question_options%rowtype;
  s public.v5_students%rowtype;
begin
  select * into a from public.v5_attempts where id=p_attempt_id for update;
  if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;


  select * into s from public.v5_students
  where id=a.student_id
    and lower(trim(student_code))=lower(trim(p_student_code))
    and is_active=true;
  if not found then raise exception 'STUDENT_DOES_NOT_MATCH_ATTEMPT'; end if;
  if a.status <> 'started'::public.v5_attempt_status then
    return jsonb_build_object('saved',false,'status',a.status::text);
  end if;

  if not public.v5_check_attempt_time(a.id) then
    perform v5_private.finalize_attempt(a.id);
    return jsonb_build_object('saved',false,'status','submitted');
  end if;

  select * into eq from public.v5_exam_questions
  where id=p_exam_question_id and exam_id=a.exam_id;
  if not found then raise exception 'QUESTION_NOT_IN_EXAM'; end if;

  select * into o from public.v5_question_options
  where id=p_selected_option_id and question_id=eq.question_id;
  if not found then raise exception 'OPTION_NOT_IN_QUESTION'; end if;

  begin
  insert into public.v5_student_answers(
    attempt_id,exam_question_id,selected_option_id,answer_text,is_correct,score_awarded,answered_at
  ) values(a.id,eq.id,o.id,o.option_text,null,0,clock_timestamp())
  on conflict(attempt_id,exam_question_id) do update
    set selected_option_id=excluded.selected_option_id,
        answer_text=excluded.answer_text,
        is_correct=null,
        score_awarded=0,
        answered_at=clock_timestamp();
  if not public.v5_check_attempt_time(a.id) then
    raise sqlstate 'ZX002' using message='SAVE_CROSSED_DEADLINE';
  end if;
  exception when sqlstate 'ZX002' then
    -- Roll back only the attempted overwrite, then grade the previously saved answers.
    perform v5_private.finalize_attempt(a.id);
    return jsonb_build_object('saved',false,'status','submitted');
  end;

  return jsonb_build_object('saved',true,'status','started');
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_save_answers(p_attempt_id uuid, p_student_code text, p_answers jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_exam_id bigint;
    v_student_id bigint;
    v_status public.v5_attempt_status;
    v_invalid_count integer;
begin
    select a.exam_id, a.student_id, a.status
      into v_exam_id, v_student_id, v_status
    from public.v5_attempts a
    join public.v5_students s on s.id = a.student_id
    where a.id = p_attempt_id
      and lower(trim(s.student_code)) = lower(trim(p_student_code))
      and s.is_active = true for update of a;

    if not found then
        raise exception 'ATTEMPT_OR_STUDENT_NOT_FOUND';
    end if;

    if v_status <> 'started'::public.v5_attempt_status then
        raise exception 'ATTEMPT_NOT_STARTED';
    end if;

    if not public.v5_check_attempt_time(p_attempt_id) then
        raise exception 'EXAM_TIME_EXPIRED';
    end if;

    if jsonb_typeof(coalesce(p_answers,'[]'::jsonb)) <> 'array' then
        raise exception 'ANSWERS_MUST_BE_ARRAY';
    end if;

    select count(*) into v_invalid_count
    from jsonb_to_recordset(coalesce(p_answers,'[]'::jsonb)) as x(exam_question_id bigint, selected_option_id bigint)
    left join public.v5_exam_questions eq
      on eq.id = x.exam_question_id and eq.exam_id = v_exam_id
    left join public.v5_question_options qo
      on qo.id = x.selected_option_id and qo.question_id = eq.question_id
    where x.exam_question_id is null
       or x.selected_option_id is null
       or eq.id is null
       or qo.id is null;

    if v_invalid_count > 0 then
        raise exception 'INVALID_EXAM_QUESTION_OR_OPTION';
    end if;

    -- Reject duplicate question entries in one payload instead of relying on a unique violation.
    if exists (
      select 1
      from jsonb_to_recordset(coalesce(p_answers,'[]'::jsonb)) as x(exam_question_id bigint, selected_option_id bigint)
      group by x.exam_question_id
      having count(*) > 1
    ) then
      raise exception 'DUPLICATE_EXAM_QUESTION';
    end if;

    delete from public.v5_student_answers where attempt_id = p_attempt_id;

    insert into public.v5_student_answers (
        attempt_id, exam_question_id, selected_option_id, answer_text, is_correct, score_awarded, answered_at
    )
    select
        p_attempt_id, x.exam_question_id, x.selected_option_id, null, null, 0, clock_timestamp()
    from jsonb_to_recordset(coalesce(p_answers,'[]'::jsonb)) as x(exam_question_id bigint, selected_option_id bigint);
    -- Raising here rolls back the entire delete/insert operation.
    if not public.v5_check_attempt_time(p_attempt_id) then
        raise exception 'EXAM_TIME_EXPIRED';
    end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_add_bank_questions_to_exam(p_exam_id bigint, p_bank_question_ids bigint[])
 RETURNS TABLE(bank_question_id bigint, question_id bigint, question_order integer, result text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_bank_id bigint; v_question_id bigint; v_before_count integer; v_after_count integer; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if p_bank_question_ids is null or cardinality(p_bank_question_ids)=0 then raise exception 'حداقل یک سؤال باید انتخاب شود.'; end if; if not exists(select 1 from public.v5_exams where id=p_exam_id) then raise exception 'آزمون پیدا نشد.'; end if; if exists(select 1 from public.v5_exams where id=p_exam_id and status::text='published') then raise exception 'آزمون منتشرشده قابل تغییر نیست.'; end if; for v_bank_id in select distinct x from unnest(p_bank_question_ids) t(x) where x is not null loop select count(*) into v_before_count from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id where eq.exam_id=p_exam_id and q.bank_question_id=v_bank_id; v_question_id:=public.v5_admin_add_bank_question_to_exam(p_exam_id,v_bank_id); select count(*) into v_after_count from public.v5_exam_questions eq join public.v5_questions q on q.id=eq.question_id where eq.exam_id=p_exam_id and q.bank_question_id=v_bank_id; select eq.question_order into question_order from public.v5_exam_questions eq where eq.exam_id=p_exam_id and eq.question_id=v_question_id order by eq.question_order limit 1; bank_question_id:=v_bank_id; question_id:=v_question_id; result:=case when v_after_count>v_before_count then 'added' else 'already_exists' end; return next; end loop; end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_create_question(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_id bigint; v_correct int; v_count int; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; if nullif(trim(p_question_text),'') is null then raise exception 'متن سؤال الزامی است'; end if; if p_subject_id is null or not exists(select 1 from public.v5_subjects s where s.id=p_subject_id and s.is_active) then raise exception 'درس معتبر نیست'; end if; if p_options is null or jsonb_array_length(p_options)<>4 then raise exception 'سؤال چهار گزینه لازم دارد'; end if; select count(*) into v_count from jsonb_array_elements(p_options) x where nullif(trim(x->>'text'),'') is not null; if v_count<>4 then raise exception 'متن هر چهار گزینه الزامی است'; end if; select count(*) into v_correct from jsonb_array_elements(p_options) x where coalesce((x->>'is_correct')::boolean,false); if v_correct<>1 then raise exception 'دقیقاً یک گزینه باید صحیح باشد'; end if; if exists(select 1 from public.v5_questions q where q.is_active and lower(trim(regexp_replace(q.question_text,'^\[جدید\]\s*',''))) = lower(trim(regexp_replace(p_question_text,'^\[جدید\]\s*','')))) then raise exception 'سؤال تکراری است'; end if; insert into public.v5_questions(subject_id,topic_id,question_type,difficulty,question_text,explanation,score,created_by,is_active) values(p_subject_id,p_topic_id,'multiple_choice',p_difficulty,'[جدید] '||trim(regexp_replace(p_question_text,'^\[جدید\]\s*','')),null,coalesce(p_score,1),auth.uid(),true) returning id into v_id; insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order) select v_id,coalesce(x->>'key',chr(64+ord::int)),trim(x->>'text'),coalesce((x->>'is_correct')::boolean,false),ord::int from jsonb_array_elements(p_options) with ordinality a(x,ord); return v_id; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_create_bank_question(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_id bigint; v_correct int; v_count int; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; if nullif(trim(p_question_text),'') is null then raise exception 'متن سؤال الزامی است'; end if; if not exists(select 1 from public.v5_subjects s where s.id=p_subject_id and s.is_active) then raise exception 'درس معتبر نیست'; end if; if p_topic_id is not null and not exists(select 1 from public.v5_topics t where t.id=p_topic_id and t.subject_id=p_subject_id and t.is_active) then raise exception 'مبحث انتخاب‌شده با درس انتخابی مطابقت ندارد'; end if; if p_options is null or jsonb_array_length(p_options)<>4 then raise exception 'سؤال چهار گزینه لازم دارد'; end if; select count(*) into v_count from jsonb_array_elements(p_options) x where nullif(trim(x->>'text'),'') is not null; if v_count<>4 then raise exception 'متن هر چهار گزینه الزامی است'; end if; select count(*) into v_correct from jsonb_array_elements(p_options) x where coalesce((x->>'is_correct')::boolean,false); if v_correct<>1 then raise exception 'دقیقاً یک گزینه باید صحیح باشد'; end if; if exists(select 1 from public.v5_question_bank b where b.is_active and lower(trim(regexp_replace(b.question_text,'^\[جدید\]\s*',''))) = lower(trim(regexp_replace(p_question_text,'^\[جدید\]\s*','')))) then raise exception 'سؤال تکراری است'; end if; insert into public.v5_question_bank(subject_id,topic_id,question_text,question_type,difficulty,score,status,is_active) values(p_subject_id,p_topic_id,'[جدید] '||trim(regexp_replace(p_question_text,'^\[جدید\]\s*','')),'multiple_choice',p_difficulty,coalesce(p_score,1),'published',true) returning id into v_id; insert into public.v5_question_bank_options(question_id,option_key,option_text,is_correct,sort_order) select v_id,coalesce(x->>'key',chr(64+ord::int)),trim(x->>'text'),coalesce((x->>'is_correct')::boolean,false),ord::int from jsonb_array_elements(p_options) with ordinality a(x,ord); return v_id; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_set_question_active(p_question_id bigint, p_active boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; update public.v5_questions set is_active=p_active,updated_at=now() where id=p_question_id; if not found then raise exception 'سؤال پیدا نشد'; end if; return true; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_auto_create_exam_link_on_publish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    perform public.v5_create_exam_link_internal(new.id, null, 1);
  end if;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_get_exam_control(p_exam_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ declare r public.v5_exams%rowtype; v_questions integer; v_attempts integer; v_submitted integer; v_active_link integer; begin if not public.v5_is_staff() then raise exception 'access denied'; end if; select * into r from public.v5_exams where id=p_exam_id; if r.id is null then raise exception 'exam not found'; end if; select count(*) into v_questions from public.v5_exam_questions where exam_id=p_exam_id; select count(*) into v_attempts from public.v5_attempts where exam_id=p_exam_id; select count(*) into v_submitted from public.v5_attempts where exam_id=p_exam_id and status='submitted'; select count(*) into v_active_link from public.v5_exam_links where exam_id=p_exam_id and is_active=true; return jsonb_build_object('id',r.id,'exam_code',r.exam_code,'title',r.title,'status',r.status,'duration_minutes',r.duration_minutes,'start_at',r.start_at,'end_at',r.end_at,'question_count',v_questions,'attempt_count',v_attempts,'submitted_count',v_submitted,'active_link_count',v_active_link); end $function$
;
CREATE OR REPLACE FUNCTION public.v5_create_exam_link(p_exam_id bigint, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_attempts integer DEFAULT 1)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
begin
  if not coalesce(public.v5_is_staff(),false) then raise exception 'access denied' using errcode='42501'; end if;
  if p_max_attempts is null or p_max_attempts < 1 or p_max_attempts > 100 then raise exception 'INVALID_MAX_ATTEMPTS'; end if;
  if p_expires_at is not null and p_expires_at <= now() then raise exception 'INVALID_EXPIRY'; end if;
  return public.v5_create_exam_link_internal(p_exam_id,p_expires_at,p_max_attempts);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_validate_exam_link(p_token text)
 RETURNS TABLE(exam_id bigint, exam_title text, exam_code text, duration_minutes integer, link_expires_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select e.id,e.title,e.exam_code,e.duration_minutes,l.expires_at from public.v5_exam_links l join public.v5_exams e on e.id=l.exam_id where l.token=p_token and l.is_active=true and e.status='published' and (l.expires_at is null or l.expires_at>now()) limit 1 $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_create_question_bank_question(p_question_text text, p_subject_id bigint, p_topic_id bigint, p_difficulty text, p_score numeric, p_options jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_id bigint; v_correct int; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر/معاون مجاز نیست'; end if; if nullif(trim(p_question_text),'') is null then raise exception 'متن سؤال الزامی است'; end if; if p_options is null or jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<>4 then raise exception 'سؤال باید دقیقاً ۴ گزینه داشته باشد'; end if; select count(*) filter(where coalesce((x->>'is_correct')::boolean,false)) into v_correct from jsonb_array_elements(p_options) x; if v_correct<>1 then raise exception 'دقیقاً یک گزینه باید صحیح باشد'; end if; if exists(select 1 from public.v5_question_bank b where lower(trim(b.question_text))=lower(trim(p_question_text))) then raise exception 'سؤال تکراری است'; end if; insert into public.v5_question_bank(question_text,subject_id,topic_id,question_type,difficulty,score,status,is_active,tags,created_by) values('[جدید] '||trim(p_question_text),p_subject_id,p_topic_id,'multiple_choice',p_difficulty,p_score,'published',true,array['new'],auth.uid()) returning id into v_id; insert into public.v5_question_bank_options(question_id,option_key,option_text,is_correct,sort_order) select v_id,x->>'option_key',x->>'option_text',coalesce((x->>'is_correct')::boolean,false),coalesce((x->>'sort_order')::int,0) from jsonb_array_elements(p_options) x; return v_id; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_auto_link_on_publish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ begin if new.status='published' and (tg_op='INSERT' or old.status is distinct from 'published') then perform public.v5_ensure_exam_link(new.id); end if; return new; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_get_question_bank(p_search text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS TABLE(id bigint, question_text text, subject text, grade text, difficulty text, score numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select qb.id,qb.question_text,s.name,g.name,qb.difficulty::text,qb.score from public.v5_question_bank qb join public.v5_subjects s on s.id=qb.subject_id left join public.v5_grades g on g.id=s.grade_id where qb.is_active=true and qb.status='published' and exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active=true and p.role in ('admin','deputy','teacher')) and (nullif(trim(p_search),'') is null or qb.question_text ilike '%'||trim(p_search)||'%' or s.name ilike '%'||trim(p_search)||'%' or coalesce(g.name,'') ilike '%'||trim(p_search)||'%') order by qb.id desc limit greatest(1,least(coalesce(p_limit,100),500)); $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_set_question_bank_active(p_question_id bigint, p_active boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر/معاون مجاز نیست'; end if; update public.v5_question_bank set is_active=p_active,updated_at=now() where id=p_question_id; if not found then raise exception 'سؤال پیدا نشد'; end if; return true; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_update_question(p_question_id bigint, p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_correct int; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر مجاز نیست'; end if; if not exists(select 1 from public.v5_questions q where q.id=p_question_id) then raise exception 'سؤال پیدا نشد'; end if; if p_options is null or jsonb_array_length(p_options)<>4 then raise exception 'سؤال چهار گزینه لازم دارد'; end if; select count(*) into v_correct from jsonb_array_elements(p_options) x where coalesce((x->>'is_correct')::boolean,false); if v_correct<>1 then raise exception 'دقیقاً یک گزینه باید صحیح باشد'; end if; update public.v5_questions set subject_id=p_subject_id,topic_id=p_topic_id,question_text=case when question_text like '[جدید] %' then '[جدید] '||trim(replace(p_question_text,'[جدید] ','')) else trim(replace(p_question_text,'[جدید] ','')) end,difficulty=p_difficulty,score=coalesce(p_score,1),updated_at=now() where id=p_question_id; delete from public.v5_question_options where question_id=p_question_id; insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order) select p_question_id,coalesce(x->>'key',chr(64+ord::int)),trim(x->>'text'),coalesce((x->>'is_correct')::boolean,false),ord::int from jsonb_array_elements(p_options) with ordinality a(x,ord); return true; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_update_question_bank_question(p_question_id bigint, p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty text, p_score numeric, p_options jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_id bigint; v_correct int; begin if not exists(select 1 from public.v5_profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','deputy')) then raise exception 'دسترسی مدیر/معاون مجاز نیست'; end if; if nullif(trim(p_question_text),'') is null then raise exception 'متن سؤال الزامی است'; end if; if p_options is null or jsonb_typeof(p_options)<>'array' or jsonb_array_length(p_options)<>4 then raise exception 'سؤال باید دقیقاً ۴ گزینه داشته باشد'; end if; select count(*) filter(where coalesce((x->>'is_correct')::boolean,false)) into v_correct from jsonb_array_elements(p_options) x; if v_correct<>1 then raise exception 'دقیقاً یک گزینه باید صحیح باشد'; end if; if exists(select 1 from public.v5_question_bank b where lower(trim(regexp_replace(b.question_text,'^\[جدید\]\s*',''))) = lower(trim(p_question_text)) and b.id<>p_question_id) then raise exception 'سؤال تکراری است'; end if; update public.v5_question_bank set question_text=case when question_text like '[جدید] %' then '[جدید] '||trim(p_question_text) else trim(p_question_text) end,subject_id=p_subject_id,topic_id=p_topic_id,difficulty=p_difficulty,score=p_score,updated_at=now() where id=p_question_id returning id into v_id; if v_id is null then raise exception 'سؤال پیدا نشد'; end if; delete from public.v5_question_bank_options where question_id=v_id; insert into public.v5_question_bank_options(question_id,option_key,option_text,is_correct,sort_order) select v_id,x->>'option_key',x->>'option_text',coalesce((x->>'is_correct')::boolean,false),coalesce((x->>'sort_order')::int,0) from jsonb_array_elements(p_options) x; return v_id; end $function$
;
CREATE OR REPLACE FUNCTION public.v5_staff_build_exam(p_title text, p_exam_code text, p_duration_minutes integer, p_question_ids bigint[])
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
 v_exam_id bigint;
 v_bank_id bigint;
 v_question_id bigint;
 v_order integer:=0;
 v_q record;
begin
 if not public.v5_is_staff() then raise exception 'access denied'; end if;
 if nullif(trim(p_title),'') is null then raise exception 'title is required'; end if;
 if nullif(trim(p_exam_code),'') is null then raise exception 'exam code is required'; end if;
 if p_duration_minutes is null or p_duration_minutes<1 or p_duration_minutes>600 then raise exception 'invalid duration'; end if;
 if p_question_ids is null or cardinality(p_question_ids)<1 or cardinality(p_question_ids)>500 then raise exception 'invalid question count'; end if;
 if exists(select 1 from unnest(p_question_ids) x group by x having count(*)>1) then raise exception 'duplicate question ids'; end if;
 if exists(select 1 from unnest(p_question_ids) x left join public.v5_question_bank q on q.id=x where q.id is null or coalesce(q.is_active,true)=false) then raise exception 'one or more questions are unavailable'; end if;
 if exists(select 1 from public.v5_exams where exam_code=trim(p_exam_code)) then raise exception 'exam code already exists'; end if;
 insert into public.v5_exams(title,exam_code,duration_minutes,status,created_by)
 values(trim(p_title),trim(p_exam_code),p_duration_minutes,'draft'::public.v5_exam_status,auth.uid()) returning id into v_exam_id;
 foreach v_bank_id in array p_question_ids loop
   select q.* into v_q from public.v5_question_bank q where q.id=v_bank_id and coalesce(q.is_active,true);
   insert into public.v5_questions(subject_id,topic_id,source_id,question_type,difficulty,question_text,explanation,page_number,score,created_by,bank_question_id)
   values(v_q.subject_id,v_q.topic_id,v_q.source_id,v_q.question_type::public.v5_question_type,v_q.difficulty::public.v5_difficulty,v_q.question_text,v_q.explanation,case when v_q.source_page ~ '^[0-9]+$' then v_q.source_page::integer else null end,v_q.score,auth.uid(),v_q.id)
   on conflict (bank_question_id) do update set updated_at=now()
   returning id into v_question_id;
   insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order)
   select v_question_id,o.option_key,o.option_text,o.is_correct,o.sort_order
   from public.v5_question_bank_options o
   where o.question_id=v_bank_id
   and not exists(select 1 from public.v5_question_options qo where qo.question_id=v_question_id);
   v_order:=v_order+1;
   insert into public.v5_exam_questions(exam_id,question_id,question_order,score) values(v_exam_id,v_question_id,v_order,v_q.score);
 end loop;
 return v_exam_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_admin_add_random_bank_questions_to_exam(p_exam_id bigint, p_count integer)
 RETURNS TABLE(bank_question_id bigint, question_id bigint, question_order integer, result text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_ids bigint[]; begin if not public.v5_is_staff() then raise exception 'STAFF_ACCESS_REQUIRED'; end if; if p_count is null or p_count<=0 then raise exception 'تعداد سؤال باید بیشتر از صفر باشد.'; end if; if not exists(select 1 from public.v5_exams where id=p_exam_id) then raise exception 'آزمون پیدا نشد.'; end if; if exists(select 1 from public.v5_exams where id=p_exam_id and status::text='published') then raise exception 'آزمون منتشرشده قابل تغییر نیست.'; end if; select array_agg(id) into v_ids from (select q.id from public.v5_question_bank q where q.status='published' and q.is_active and (select count(*) from public.v5_question_bank_options o where o.question_id=q.id)>=2 and (select count(*) from public.v5_question_bank_options o where o.question_id=q.id and o.is_correct)=1 and not exists(select 1 from public.v5_questions eq_question join public.v5_exam_questions eq on eq.question_id=eq_question.id where eq.exam_id=p_exam_id and eq_question.bank_question_id=q.id) order by random() limit p_count) s; if v_ids is null or cardinality(v_ids)=0 then raise exception 'هیچ سؤال جدید و معتبر برای افزودن به آزمون پیدا نشد.'; end if; return query select * from public.v5_admin_add_bank_questions_to_exam(p_exam_id,v_ids); end;$function$
;
CREATE OR REPLACE FUNCTION public.v5_import_question_from_bank(p_bank_question_id bigint, p_exam_id bigint, p_question_order integer DEFAULT 1)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_new_question_id bigint;
    v_q public.v5_question_bank%rowtype;
    v_option record;
begin
    if not coalesce(public.v5_is_staff(),false) then
      raise exception 'staff access required' using errcode='42501';
    end if;
    if p_question_order is null or p_question_order < 1 then
      raise exception 'invalid question order' using errcode='22023';
    end if;

    select * into v_q
    from public.v5_question_bank q
    where q.id=p_bank_question_id and q.is_active=true and q.status='published';
    if not found then raise exception 'BANK_QUESTION_NOT_AVAILABLE'; end if;

    if not exists(select 1 from public.v5_exams e where e.id=p_exam_id) then
      raise exception 'EXAM_NOT_FOUND';
    end if;

    insert into public.v5_questions(
      subject_id,topic_id,source_id,question_type,difficulty,question_text,explanation,page_number,
      score,is_active,created_by,bank_question_id
    ) values(
      v_q.subject_id,v_q.topic_id,v_q.source_id,v_q.question_type::public.v5_question_type,
      v_q.difficulty::public.v5_difficulty,v_q.question_text,v_q.explanation,
      case when coalesce(v_q.source_page,'') ~ '^[0-9]+$' then v_q.source_page::integer else null end,
      v_q.score,true,auth.uid(),v_q.id
    ) returning id into v_new_question_id;

    for v_option in
      select option_key,option_text,is_correct,sort_order
      from public.v5_question_bank_options
      where question_id=p_bank_question_id order by sort_order
    loop
      insert into public.v5_question_options(question_id,option_key,option_text,is_correct,sort_order)
      values(v_new_question_id,v_option.option_key,v_option.option_text,v_option.is_correct,v_option.sort_order);
    end loop;

    insert into public.v5_exam_questions(exam_id,question_id,question_order,score)
    values(p_exam_id,v_new_question_id,p_question_order,v_q.score);
    return v_new_question_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_ensure_exam_link(p_exam_id bigint)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_token text;
begin
  if not exists (
    select 1 from public.v5_profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and p.role in ('admin','deputy','teacher')
  ) then
    raise exception 'insufficient_privilege';
  end if;

  if not exists(
    select 1 from public.v5_exams
    where id=p_exam_id and status='published'
  ) then
    return null;
  end if;

  select token into v_token
  from public.v5_exam_links
  where exam_id=p_exam_id and is_active=true
  order by created_at desc
  limit 1;

  if v_token is not null then
    return v_token;
  end if;

  v_token:=replace(
    encode(
      extensions.digest(
        (random()::text||clock_timestamp()::text||p_exam_id::text)::bytea,
        'sha256'
      ),
      'hex'
    ),'-',''
  );

  insert into public.v5_exam_links(exam_id,token,is_active)
  values(p_exam_id,v_token,true);

  return v_token;
end
$function$
;
CREATE OR REPLACE FUNCTION public.v5_create_exam_link_internal(p_exam_id bigint, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_max_attempts integer DEFAULT 1)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$ declare v_token text; v_id bigint; begin if not exists(select 1 from public.v5_exams where id=p_exam_id and status='published') then raise exception 'EXAM_NOT_PUBLISHED'; end if; select token into v_token from public.v5_exam_links where exam_id=p_exam_id and is_active=true order by created_at desc limit 1; if v_token is not null then return v_token; end if; v_token=replace(encode(extensions.digest((random()::text||clock_timestamp()::text||p_exam_id::text)::bytea,'sha256'),'hex'),' - ',''); v_token=replace(v_token,'-',''); v_id=nextval('public.v5_exam_links_id_seq'); insert into public.v5_exam_links(id,exam_id,token,expires_at,max_attempts_per_student,is_active) overriding system value values(v_id,p_exam_id,v_token,p_expires_at,p_max_attempts,true); return v_token; end $function$
;
CREATE OR REPLACE FUNCTION public.refresh_student_question_performance(p_student_id uuid, p_question_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_total integer;
    v_correct integer;
    v_wrong integer;
    v_accuracy numeric;
    v_avg_time numeric;
    v_last_answered timestamptz;
begin

    select
        count(*),
        count(*) filter (where is_correct = true),
        count(*) filter (where is_correct = false),
        coalesce(avg(answer_time_seconds), 0),
        max(answered_at)
    into
        v_total,
        v_correct,
        v_wrong,
        v_avg_time,
        v_last_answered
    from public.student_answers sa
    join public.exam_attempts ea
        on ea.id = sa.attempt_id
    where
        ea.student_id = p_student_id
        and sa.question_id = p_question_id;


    if v_total > 0 then
        v_accuracy :=
            round(
                (v_correct::numeric / v_total::numeric) * 100,
                2
            );
    else
        v_accuracy := 0;
    end if;


    insert into public.student_question_performance (
        student_id,
        question_id,
        total_attempts,
        correct_attempts,
        wrong_attempts,
        accuracy,
        average_time_seconds,
        last_answered_at,
        updated_at
    )
    values (
        p_student_id,
        p_question_id,
        v_total,
        v_correct,
        v_wrong,
        v_accuracy,
        v_avg_time,
        v_last_answered,
        now()
    )

    on conflict (
        student_id,
        question_id
    )
    do update set

        total_attempts =
            excluded.total_attempts,

        correct_attempts =
            excluded.correct_attempts,

        wrong_attempts =
            excluded.wrong_attempts,

        accuracy =
            excluded.accuracy,

        average_time_seconds =
            excluded.average_time_seconds,

        last_answered_at =
            excluded.last_answered_at,

        updated_at =
            now();

end;
$function$
;
CREATE OR REPLACE FUNCTION public.get_educational_analytics(p_exam_code text)
 RETURNS TABLE(exam_code text, students_count bigint, average_percent numeric, highest_percent numeric, lowest_percent numeric, average_correct numeric, average_wrong numeric, average_blank numeric, excellent_count bigint, very_good_count bigint, passed_count bigint, weak_count bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
    select
        s.exam_code,
        s.students_count,
        s.average_percent,
        s.highest_percent,
        s.lowest_percent,
        s.average_correct,
        s.average_wrong,
        s.average_blank,
        s.excellent_count,
        s.very_good_count,
        s.passed_count,
        s.weak_count

    from public.exam_analytics_summary s

    where s.exam_code = p_exam_code;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_submit_attempt(p_attempt_id uuid, p_student_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.v5_attempts; visible boolean; maximum numeric;
begin
 select * into a from public.v5_attempts where id=p_attempt_id for update;
 if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
 if not exists(select 1 from public.v5_students where id=a.student_id
  and lower(trim(student_code))=lower(trim(p_student_code)) and is_active)
 then raise exception 'STUDENT_DOES_NOT_MATCH_ATTEMPT'; end if;
 if a.status='started' then a:=v5_private.finalize_attempt(a.id); end if;
 if a.status<>'submitted' then return jsonb_build_object('status',a.status,'show_result',false); end if;
 select show_result_to_student into visible from public.v5_exams where id=a.exam_id;
 if not coalesce(visible,false) then return jsonb_build_object('status','submitted','show_result',false); end if;
 select coalesce(sum(score),0) into maximum from public.v5_exam_questions where exam_id=a.exam_id;
 return jsonb_build_object('status','submitted','show_result',true,'correct_answers',a.correct_count,
  'wrong_answers',a.wrong_count,'unanswered_questions',a.blank_count,'total_score',a.total_score,
  'max_score',maximum,'percentage',a.percentage);
end $function$
;
CREATE OR REPLACE FUNCTION public.v5_recalculate_attempt_result(p_attempt_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_exam_id bigint;
  v_total_questions integer;
  v_answered integer;
  v_correct integer;
  v_wrong integer;
  v_blank integer;
  v_score numeric;
  v_max_score numeric;
  v_percentage numeric;
begin
  select exam_id into v_exam_id from public.v5_attempts where id = p_attempt_id;
  if v_exam_id is null then
    return;
  end if;

  select count(*)::int, coalesce(sum(score),0)
    into v_total_questions, v_max_score
  from public.v5_exam_questions
  where exam_id = v_exam_id;

  select
    count(distinct sa.exam_question_id)::int,
    count(distinct sa.exam_question_id) filter (where sa.is_correct = true)::int,
    count(distinct sa.exam_question_id) filter (where sa.is_correct = false)::int,
    coalesce(sum(sa.score_awarded),0)
  into v_answered, v_correct, v_wrong, v_score
  from public.v5_student_answers sa
  where sa.attempt_id = p_attempt_id;

  v_blank := greatest(v_total_questions - v_answered, 0);
  v_percentage := case when v_max_score > 0 then round((v_score / v_max_score) * 100, 2) else 0 end;

  update public.v5_attempts
  set correct_count = coalesce(v_correct,0),
      wrong_count = coalesce(v_wrong,0),
      blank_count = v_blank,
      total_score = coalesce(v_score,0),
      percentage = v_percentage
  where id = p_attempt_id;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.v5_get_admin_attempt_report_detail(p_attempt_id uuid)
 RETURNS TABLE(attempt_id uuid, student_name text, student_code text, exam_title text, exam_code text, correct_count integer, wrong_count integer, blank_count integer, percentage numeric, status text, question_order integer, question_text text, answer_text text, is_correct boolean, score_awarded numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not coalesce(public.v5_is_staff(),false) then
    raise exception 'staff access required' using errcode='42501';
  end if;
  return query
  select a.id, s.full_name, s.student_code, e.title, e.exam_code,
         a.correct_count, a.wrong_count, a.blank_count, a.percentage, a.status::text,
         eq.question_order, q.question_text, o.option_text, o.is_correct,
         case when o.is_correct then eq.score else 0 end
  from public.v5_attempts a
  join public.v5_students s on s.id=a.student_id
  join public.v5_exams e on e.id=a.exam_id
  left join public.v5_exam_questions eq on eq.exam_id=a.exam_id
  left join public.v5_questions q on q.id=eq.question_id
  left join public.v5_student_answers sa on sa.attempt_id=a.id and sa.exam_question_id=eq.id
  left join public.v5_question_options o on o.id=sa.selected_option_id
  where a.id=p_attempt_id
  order by eq.question_order;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.calculate_exam_attempt(p_attempt_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_total integer;
    v_answered integer;
    v_correct integer;
    v_wrong integer;
    v_unanswered integer;
    v_percentage numeric;
    v_duration integer;
begin

    select count(*)
    into v_answered
    from public.student_answers
    where attempt_id = p_attempt_id;


    select count(*)
    into v_correct
    from public.student_answers
    where
        attempt_id = p_attempt_id
        and is_correct = true;


    select count(*)
    into v_wrong
    from public.student_answers
    where
        attempt_id = p_attempt_id
        and is_correct = false
        and selected_option is not null;


    select total_questions
    into v_total
    from public.exam_attempts
    where id = p_attempt_id;


    v_unanswered :=
        greatest(
            coalesce(v_total, 0) - v_answered,
            0
        );


    if coalesce(v_total, 0) > 0 then
        v_percentage :=
            round(
                (v_correct::numeric /
                 v_total::numeric) * 100,
                2
            );
    else
        v_percentage := 0;
    end if;


    select
        greatest(
            0,
            extract(
                epoch from
                (
                    coalesce(submitted_at, now())
                    - started_at
                )
            )::integer
        )
    into v_duration
    from public.exam_attempts
    where id = p_attempt_id;


    update public.exam_attempts
    set
        answered_questions = v_answered,
        correct_answers = v_correct,
        wrong_answers = v_wrong,
        unanswered_questions = v_unanswered,
        percentage = v_percentage,
        score = v_percentage,
        duration_seconds = v_duration,
        submitted_at = coalesce(submitted_at, now()),
        status = 'completed'
    where id = p_attempt_id;

end;
$function$
;
CREATE OR REPLACE FUNCTION v5_private.attempt_deadline(p_attempt_id uuid)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ select least(
 case when e.duration_minutes > 0 then a.started_at + make_interval(mins=>e.duration_minutes) end,
 e.end_at)
 from public.v5_attempts a join public.v5_exams e on e.id=a.exam_id where a.id=p_attempt_id $function$
;
CREATE OR REPLACE FUNCTION v5_private.finalize_attempt(p_attempt_id uuid)
 RETURNS v5_attempts
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a public.v5_attempts; cutoff timestamptz; n integer; c integer; w integer; score numeric; max_score numeric;
begin
 select * into a from public.v5_attempts where id=p_attempt_id for update;
 if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
 if a.status <> 'started' then return a; end if;
 cutoff:=v5_private.attempt_deadline(a.id);
 update public.v5_student_answers sa set
  is_correct=case when cutoff is null or sa.answered_at<cutoff then o.is_correct else null end,
  score_awarded=case when o.is_correct and (cutoff is null or sa.answered_at<cutoff) then eq.score else 0 end
 from public.v5_exam_questions eq,public.v5_question_options o
 where sa.attempt_id=a.id and eq.id=sa.exam_question_id and eq.exam_id=a.exam_id
  and o.id=sa.selected_option_id and o.question_id=eq.question_id;
 select count(*)::int,coalesce(sum(eq.score),0),
  count(*) filter(where o.id is not null and sa.is_correct is true)::int,
  count(*) filter(where o.id is not null and sa.is_correct is false)::int,
  coalesce(sum(case when o.id is not null then sa.score_awarded else 0 end),0)
 into n,max_score,c,w,score
 from public.v5_exam_questions eq
 left join public.v5_student_answers sa on sa.exam_question_id=eq.id and sa.attempt_id=a.id
  and (cutoff is null or sa.answered_at<cutoff)
 left join public.v5_question_options o on o.id=sa.selected_option_id and o.question_id=eq.question_id
 where eq.exam_id=a.exam_id;
 update public.v5_attempts set status='submitted',submitted_at=least(clock_timestamp(),cutoff),
  correct_count=c,wrong_count=w,blank_count=n-c-w,total_score=round(score,2),
  percentage=case when max_score>0 then round(100*score/max_score,2) else 0 end
 where id=a.id returning * into a;
 return a;
end $function$
;
CREATE OR REPLACE FUNCTION v5_private.finalize_due_attempts()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a record; n integer:=0;
begin
 for a in select t.id from public.v5_attempts t
  where t.status='started' and v5_private.attempt_deadline(t.id)<=clock_timestamp()
  order by t.started_at limit 200 for update of t skip locked
 loop
  perform v5_private.finalize_attempt(a.id); n:=n+1;
 end loop;
 return n;
end $function$
;
CREATE OR REPLACE FUNCTION public.v5_get_attempt_state(p_attempt_id uuid, p_student_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.v5_attempts; duration integer; answers jsonb;
begin
 select t.* into a from public.v5_attempts t join public.v5_students s on s.id=t.student_id
 where t.id=p_attempt_id and lower(trim(s.student_code))=lower(trim(p_student_code)) and s.is_active
 for update of t;
 if not found then raise exception 'ATTEMPT_OR_STUDENT_NOT_FOUND'; end if;
 if a.status='started' and not public.v5_check_attempt_time(a.id) then
  a:=v5_private.finalize_attempt(a.id);
 end if;
 select duration_minutes into duration from public.v5_exams where id=a.exam_id;
 select coalesce(jsonb_agg(jsonb_build_object('exam_question_id',sa.exam_question_id,
  'selected_option_id',sa.selected_option_id)),'[]'::jsonb) into answers
 from public.v5_student_answers sa where sa.attempt_id=a.id;
 return jsonb_build_object('attempt_id',a.id,'status',a.status,'started_at',a.started_at,
  'submitted_at',a.submitted_at,'duration_minutes',duration,'answers',answers,
  'deadline_at',v5_private.attempt_deadline(a.id),'server_now',clock_timestamp());
end $function$
;
alter table "public"."exam_results" add constraint "exam_results_blank_check" CHECK (blank_count >= 0);
alter table "public"."exam_results" add constraint "exam_results_correct_check" CHECK (correct_count >= 0);
alter table "public"."exam_results" add constraint "exam_results_percent_check" CHECK (percent >= 0::numeric AND percent <= 100::numeric);
alter table "public"."exam_results" add constraint "exam_results_pkey" PRIMARY KEY (id);
alter table "public"."exam_results" add constraint "exam_results_wrong_check" CHECK (wrong_count >= 0);
alter table "public"."v5_profiles" add constraint "v5_profiles_pkey" PRIMARY KEY (id);
alter table "public"."v5_grades" add constraint "v5_grades_name_key" UNIQUE (name);
alter table "public"."v5_grades" add constraint "v5_grades_pkey" PRIMARY KEY (id);
alter table "public"."v5_fields" add constraint "v5_fields_name_key" UNIQUE (name);
alter table "public"."v5_fields" add constraint "v5_fields_pkey" PRIMARY KEY (id);
alter table "public"."v5_classes" add constraint "v5_classes_pkey" PRIMARY KEY (id);
alter table "public"."v5_students" add constraint "v5_students_pkey" PRIMARY KEY (id);
alter table "public"."v5_students" add constraint "v5_students_student_code_key" UNIQUE (student_code);
alter table "public"."v5_students" add constraint "v5_students_user_id_key" UNIQUE (user_id);
alter table "public"."v5_subjects" add constraint "v5_subjects_pkey" PRIMARY KEY (id);
alter table "public"."v5_topics" add constraint "v5_topics_pkey" PRIMARY KEY (id);
alter table "public"."v5_sources" add constraint "v5_sources_pkey" PRIMARY KEY (id);
alter table "public"."v5_questions" add constraint "v5_questions_pkey" PRIMARY KEY (id);
alter table "public"."v5_question_options" add constraint "v5_question_options_pkey" PRIMARY KEY (id);
alter table "public"."v5_question_options" add constraint "v5_question_options_question_id_option_key_key" UNIQUE (question_id, option_key);
alter table "public"."v5_exams" add constraint "v5_exams_exam_code_key" UNIQUE (exam_code);
alter table "public"."v5_exams" add constraint "v5_exams_pkey" PRIMARY KEY (id);
alter table "public"."v5_exam_questions" add constraint "v5_exam_questions_exam_id_question_id_key" UNIQUE (exam_id, question_id);
alter table "public"."v5_exam_questions" add constraint "v5_exam_questions_exam_id_question_order_key" UNIQUE (exam_id, question_order);
alter table "public"."v5_exam_questions" add constraint "v5_exam_questions_pkey" PRIMARY KEY (id);
alter table "public"."v5_exam_classes" add constraint "v5_exam_classes_exam_id_class_id_key" UNIQUE (exam_id, class_id);
alter table "public"."v5_exam_classes" add constraint "v5_exam_classes_pkey" PRIMARY KEY (id);
alter table "public"."v5_attempts" add constraint "v5_attempts_pkey" PRIMARY KEY (id);
alter table "public"."v5_student_answers" add constraint "v5_student_answers_attempt_id_exam_question_id_key" UNIQUE (attempt_id, exam_question_id);
alter table "public"."v5_student_answers" add constraint "v5_student_answers_pkey" PRIMARY KEY (id);
alter table "public"."subjects" add constraint "subjects_name_grade_field_key" UNIQUE (name, grade, field);
alter table "public"."subjects" add constraint "subjects_pkey" PRIMARY KEY (id);
alter table "public"."topics" add constraint "topics_pkey" PRIMARY KEY (id);
alter table "public"."questions" add constraint "questions_difficulty_check" CHECK (difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text]));
alter table "public"."questions" add constraint "questions_pkey" PRIMARY KEY (id);
alter table "public"."questions" add constraint "questions_source_type_check" CHECK (source_type = ANY (ARRAY['textbook'::text, 'teacher'::text, 'school'::text, 'exam'::text, 'konkur'::text, 'standard'::text, 'other'::text]));
alter table "public"."questions" add constraint "questions_type_check" CHECK (question_type = ANY (ARRAY['multiple_choice'::text, 'true_false'::text, 'short_answer'::text, 'descriptive'::text]));
alter table "public"."exams" add constraint "exams_exam_link_key" UNIQUE (exam_link);
alter table "public"."exams" add constraint "exams_pkey" PRIMARY KEY (id);
alter table "public"."exams" add constraint "exams_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'closed'::text]));
alter table "public"."admin_profiles" add constraint "admin_profiles_pkey" PRIMARY KEY (id);
alter table "public"."admin_profiles" add constraint "admin_profiles_role_check" CHECK (role = ANY (ARRAY['admin'::text, 'super_admin'::text]));
alter table "public"."exam_links" add constraint "exam_links_exam_id_question_id_key" UNIQUE (exam_id, question_id);
alter table "public"."exam_links" add constraint "exam_links_exam_id_question_order_key" UNIQUE (exam_id, question_order);
alter table "public"."exam_links" add constraint "exam_links_pkey" PRIMARY KEY (id);
alter table "public"."exam_questions" add constraint "exam_questions_exam_id_question_id_key" UNIQUE (exam_id, question_id);
alter table "public"."exam_questions" add constraint "exam_questions_pkey" PRIMARY KEY (id);
alter table "public"."exam_attempts" add constraint "exam_attempts_pkey" PRIMARY KEY (id);
alter table "public"."exam_attempts" add constraint "exam_attempts_status_check" CHECK (status = ANY (ARRAY['in_progress'::text, 'completed'::text, 'abandoned'::text]));
alter table "public"."student_answers" add constraint "student_answers_attempt_id_question_id_key" UNIQUE (attempt_id, question_id);
alter table "public"."student_answers" add constraint "student_answers_pkey" PRIMARY KEY (id);
alter table "public"."student_question_performance" add constraint "student_question_performance_pkey" PRIMARY KEY (id);
alter table "public"."student_question_performance" add constraint "student_question_performance_student_id_question_id_key" UNIQUE (student_id, question_id);
alter table "public"."student_subject_performance" add constraint "student_subject_performance_pkey" PRIMARY KEY (id);
alter table "public"."student_subject_performance" add constraint "student_subject_performance_student_id_subject_id_key" UNIQUE (student_id, subject_id);
alter table "public"."question_performance" add constraint "question_performance_pkey" PRIMARY KEY (id);
alter table "public"."question_performance" add constraint "question_performance_question_id_key" UNIQUE (question_id);
alter table "public"."student_learning_summary" add constraint "student_learning_summary_pkey" PRIMARY KEY (id);
alter table "public"."student_learning_summary" add constraint "student_learning_summary_student_id_key" UNIQUE (student_id);
alter table "public"."exam_analytics" add constraint "exam_analytics_exam_id_key" UNIQUE (exam_id);
alter table "public"."exam_analytics" add constraint "exam_analytics_pkey" PRIMARY KEY (id);
alter table "public"."exam_answers" add constraint "exam_answers_pkey" PRIMARY KEY (id);
alter table "public"."v5_question_sources" add constraint "v5_question_sources_pkey" PRIMARY KEY (id);
alter table "public"."v5_question_bank" add constraint "v5_qb_difficulty_check" CHECK (difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text]));
alter table "public"."v5_question_bank" add constraint "v5_qb_score_check" CHECK (score >= 0::numeric);
alter table "public"."v5_question_bank" add constraint "v5_qb_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'review'::text, 'published'::text, 'archived'::text]));
alter table "public"."v5_question_bank" add constraint "v5_qb_type_check" CHECK (question_type = ANY (ARRAY['multiple_choice'::text, 'true_false'::text, 'short_answer'::text, 'descriptive'::text]));
alter table "public"."v5_question_bank" add constraint "v5_question_bank_pkey" PRIMARY KEY (id);
alter table "public"."v5_question_bank_options" add constraint "v5_question_bank_options_pkey" PRIMARY KEY (id);
alter table "public"."v5_question_bank_options" add constraint "v5_question_bank_options_question_id_option_key_key" UNIQUE (question_id, option_key);
alter table "public"."v5_exam_links" add constraint "v5_exam_links_max_attempts_check" CHECK (max_attempts_per_student IS NULL OR max_attempts_per_student > 0);
alter table "public"."v5_exam_links" add constraint "v5_exam_links_pkey" PRIMARY KEY (id);
alter table "public"."v5_exam_links" add constraint "v5_exam_links_token_key" UNIQUE (token);
alter table "public"."v5_exam_links" add constraint "v5_exam_links_token_length" CHECK (length(token) >= 16);
alter table "public"."v5_profiles" add constraint "v5_profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."v5_classes" add constraint "v5_classes_field_id_fkey" FOREIGN KEY (field_id) REFERENCES v5_fields(id) ON DELETE SET NULL;
alter table "public"."v5_classes" add constraint "v5_classes_grade_id_fkey" FOREIGN KEY (grade_id) REFERENCES v5_grades(id) ON DELETE SET NULL;
alter table "public"."v5_students" add constraint "v5_students_class_id_fkey" FOREIGN KEY (class_id) REFERENCES v5_classes(id) ON DELETE SET NULL;
alter table "public"."v5_students" add constraint "v5_students_field_id_fkey" FOREIGN KEY (field_id) REFERENCES v5_fields(id) ON DELETE SET NULL;
alter table "public"."v5_students" add constraint "v5_students_grade_id_fkey" FOREIGN KEY (grade_id) REFERENCES v5_grades(id) ON DELETE SET NULL;
alter table "public"."v5_students" add constraint "v5_students_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."v5_subjects" add constraint "v5_subjects_field_id_fkey" FOREIGN KEY (field_id) REFERENCES v5_fields(id) ON DELETE SET NULL;
alter table "public"."v5_subjects" add constraint "v5_subjects_grade_id_fkey" FOREIGN KEY (grade_id) REFERENCES v5_grades(id) ON DELETE SET NULL;
alter table "public"."v5_topics" add constraint "v5_topics_parent_id_fkey" FOREIGN KEY (parent_id) REFERENCES v5_topics(id) ON DELETE CASCADE;
alter table "public"."v5_topics" add constraint "v5_topics_subject_id_fkey" FOREIGN KEY (subject_id) REFERENCES v5_subjects(id) ON DELETE CASCADE;
alter table "public"."v5_sources" add constraint "v5_sources_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."v5_questions" add constraint "v5_questions_bank_question_id_fkey" FOREIGN KEY (bank_question_id) REFERENCES v5_question_bank(id) ON DELETE SET NULL;
alter table "public"."v5_questions" add constraint "v5_questions_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."v5_questions" add constraint "v5_questions_source_id_fkey" FOREIGN KEY (source_id) REFERENCES v5_sources(id) ON DELETE SET NULL;
alter table "public"."v5_questions" add constraint "v5_questions_subject_id_fkey" FOREIGN KEY (subject_id) REFERENCES v5_subjects(id) ON DELETE RESTRICT;
alter table "public"."v5_questions" add constraint "v5_questions_topic_id_fkey" FOREIGN KEY (topic_id) REFERENCES v5_topics(id) ON DELETE SET NULL;
alter table "public"."v5_question_options" add constraint "v5_question_options_question_id_fkey" FOREIGN KEY (question_id) REFERENCES v5_questions(id) ON DELETE CASCADE;
alter table "public"."v5_exams" add constraint "v5_exams_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;
alter table "public"."v5_exams" add constraint "v5_exams_field_id_fkey" FOREIGN KEY (field_id) REFERENCES v5_fields(id) ON DELETE SET NULL;
alter table "public"."v5_exams" add constraint "v5_exams_grade_id_fkey" FOREIGN KEY (grade_id) REFERENCES v5_grades(id) ON DELETE SET NULL;
alter table "public"."v5_exam_questions" add constraint "v5_exam_questions_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES v5_exams(id) ON DELETE CASCADE;
alter table "public"."v5_exam_questions" add constraint "v5_exam_questions_question_id_fkey" FOREIGN KEY (question_id) REFERENCES v5_questions(id) ON DELETE RESTRICT;
alter table "public"."v5_exam_classes" add constraint "v5_exam_classes_class_id_fkey" FOREIGN KEY (class_id) REFERENCES v5_classes(id) ON DELETE CASCADE;
alter table "public"."v5_exam_classes" add constraint "v5_exam_classes_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES v5_exams(id) ON DELETE CASCADE;
alter table "public"."v5_attempts" add constraint "v5_attempts_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES v5_exams(id) ON DELETE RESTRICT;
alter table "public"."v5_attempts" add constraint "v5_attempts_student_id_fkey" FOREIGN KEY (student_id) REFERENCES v5_students(id) ON DELETE RESTRICT;
alter table "public"."v5_student_answers" add constraint "v5_student_answers_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES v5_attempts(id) ON DELETE CASCADE;
alter table "public"."v5_student_answers" add constraint "v5_student_answers_exam_question_id_fkey" FOREIGN KEY (exam_question_id) REFERENCES v5_exam_questions(id) ON DELETE RESTRICT;
alter table "public"."v5_student_answers" add constraint "v5_student_answers_selected_option_id_fkey" FOREIGN KEY (selected_option_id) REFERENCES v5_question_options(id) ON DELETE SET NULL;
alter table "public"."topics" add constraint "topics_subject_id_fkey" FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE;
alter table "public"."questions" add constraint "questions_subject_id_fkey" FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE RESTRICT;
alter table "public"."questions" add constraint "questions_topic_id_fkey" FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE SET NULL;
alter table "public"."admin_profiles" add constraint "admin_profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."exam_links" add constraint "exam_links_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE;
alter table "public"."exam_links" add constraint "exam_links_question_id_fkey" FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE;
alter table "public"."exam_questions" add constraint "exam_questions_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE;
alter table "public"."exam_questions" add constraint "exam_questions_question_id_fkey" FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE RESTRICT;
alter table "public"."exam_attempts" add constraint "exam_attempts_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE;
alter table "public"."exam_attempts" add constraint "exam_attempts_student_id_fkey" FOREIGN KEY (student_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."student_answers" add constraint "student_answers_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE;
alter table "public"."student_answers" add constraint "student_answers_question_id_fkey" FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE;
alter table "public"."student_question_performance" add constraint "student_question_performance_question_id_fkey" FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE;
alter table "public"."student_question_performance" add constraint "student_question_performance_student_id_fkey" FOREIGN KEY (student_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."student_subject_performance" add constraint "student_subject_performance_student_id_fkey" FOREIGN KEY (student_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."student_subject_performance" add constraint "student_subject_performance_subject_id_fkey" FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE;
alter table "public"."question_performance" add constraint "question_performance_question_id_fkey" FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE;
alter table "public"."student_learning_summary" add constraint "student_learning_summary_strongest_subject_id_fkey" FOREIGN KEY (strongest_subject_id) REFERENCES subjects(id) ON DELETE SET NULL;
alter table "public"."student_learning_summary" add constraint "student_learning_summary_student_id_fkey" FOREIGN KEY (student_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table "public"."student_learning_summary" add constraint "student_learning_summary_weakest_subject_id_fkey" FOREIGN KEY (weakest_subject_id) REFERENCES subjects(id) ON DELETE SET NULL;
alter table "public"."exam_analytics" add constraint "exam_analytics_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE;
alter table "public"."v5_question_bank" add constraint "v5_question_bank_source_id_fkey" FOREIGN KEY (source_id) REFERENCES v5_question_sources(id) ON DELETE SET NULL;
alter table "public"."v5_question_bank" add constraint "v5_question_bank_subject_id_fkey" FOREIGN KEY (subject_id) REFERENCES v5_subjects(id) ON DELETE SET NULL;
alter table "public"."v5_question_bank" add constraint "v5_question_bank_topic_id_fkey" FOREIGN KEY (topic_id) REFERENCES v5_topics(id) ON DELETE SET NULL;
alter table "public"."v5_question_bank_options" add constraint "v5_question_bank_options_question_id_fkey" FOREIGN KEY (question_id) REFERENCES v5_question_bank(id) ON DELETE CASCADE;
alter table "public"."v5_exam_links" add constraint "v5_exam_links_exam_id_fkey" FOREIGN KEY (exam_id) REFERENCES v5_exams(id) ON DELETE CASCADE;
CREATE INDEX questions_source_type_idx ON public.questions USING btree (source_type);
CREATE INDEX questions_subject_idx ON public.questions USING btree (subject_id);
CREATE INDEX v5_attempts_student_idx ON public.v5_attempts USING btree (student_id);
CREATE INDEX v5_subjects_field_idx ON public.v5_subjects USING btree (field_id);
CREATE INDEX v5_student_answers_exam_question_idx ON public.v5_student_answers USING btree (exam_question_id);
CREATE INDEX v5_questions_subject_topic_idx ON public.v5_questions USING btree (subject_id, topic_id);
CREATE INDEX v5_exam_classes_class_idx ON public.v5_exam_classes USING btree (class_id);
CREATE INDEX questions_exam_year_idx ON public.questions USING btree (exam_year);
CREATE INDEX v5_attempts_exam_student_started_idx ON public.v5_attempts USING btree (exam_id, student_id, started_at DESC);
CREATE INDEX exam_questions_order_idx ON public.exam_questions USING btree (exam_id, question_order);
CREATE INDEX v5_questions_topic_idx ON public.v5_questions USING btree (topic_id);
CREATE INDEX admin_profiles_active_idx ON public.admin_profiles USING btree (is_active);
CREATE INDEX v5_exams_created_at_idx ON public.v5_exams USING btree (created_at DESC);
CREATE INDEX exam_results_class_percent_idx ON public.exam_results USING btree (class_name, percent DESC);
CREATE INDEX exam_links_question_idx ON public.exam_links USING btree (question_id);
CREATE INDEX questions_field_idx ON public.questions USING btree (field);
CREATE INDEX questions_topic_idx ON public.questions USING btree (topic_id);
CREATE INDEX exam_attempts_status_idx ON public.exam_attempts USING btree (status);
CREATE INDEX v5_topics_subject_idx ON public.v5_topics USING btree (subject_id);
CREATE INDEX v5_attempts_exam_idx ON public.v5_attempts USING btree (exam_id);
CREATE INDEX v5_exam_questions_question_idx ON public.v5_exam_questions USING btree (question_id);
CREATE INDEX v5_exams_field_idx ON public.v5_exams USING btree (field_id);
CREATE INDEX exam_results_submitted_idx ON public.exam_results USING btree (submitted_at DESC);
CREATE INDEX exams_status_idx ON public.exams USING btree (status);
CREATE UNIQUE INDEX student_subject_performance_unique_idx ON public.student_subject_performance USING btree (student_id, subject_id);
CREATE INDEX v5_exams_grade_idx ON public.v5_exams USING btree (grade_id);
CREATE INDEX v5_question_options_question_idx ON public.v5_question_options USING btree (question_id);
CREATE INDEX v5_questions_source_idx ON public.v5_questions USING btree (source_id);
CREATE INDEX v5_exams_created_by_idx ON public.v5_exams USING btree (created_by);
CREATE INDEX exam_answers_exam_idx ON public.exam_answers USING btree (exam_id);
CREATE INDEX exam_results_exam_student_idx ON public.exam_results USING btree (exam_code, student_code);
CREATE INDEX student_question_performance_student_idx ON public.student_question_performance USING btree (student_id);
CREATE INDEX v5_question_bank_subject_topic_idx ON public.v5_question_bank USING btree (subject_id, topic_id);
CREATE INDEX v5_qb_source_idx ON public.v5_question_bank USING btree (source_id);
CREATE INDEX v5_student_answers_correct_idx ON public.v5_student_answers USING btree (attempt_id, is_correct);
CREATE INDEX v5_classes_grade_idx ON public.v5_classes USING btree (grade_id);
CREATE INDEX question_performance_question_idx ON public.question_performance USING btree (question_id);
CREATE INDEX exam_answers_question_idx ON public.exam_answers USING btree (question_id);
CREATE INDEX v5_exam_links_exam_idx ON public.v5_exam_links USING btree (exam_id);
CREATE INDEX exam_links_exam_idx ON public.exam_links USING btree (exam_id);
CREATE INDEX exam_results_student_idx ON public.exam_results USING btree (student_code);
CREATE INDEX exam_questions_exam_idx ON public.exam_questions USING btree (exam_id);
CREATE INDEX v5_students_field_idx ON public.v5_students USING btree (field_id);
CREATE INDEX questions_chapter_idx ON public.questions USING btree (chapter);
CREATE INDEX exams_field_idx ON public.exams USING btree (field);
CREATE INDEX v5_qb_created_at_idx ON public.v5_question_bank USING btree (created_at DESC);
CREATE INDEX v5_qb_difficulty_idx ON public.v5_question_bank USING btree (difficulty);
CREATE INDEX v5_student_answers_analytics_idx ON public.v5_student_answers USING btree (attempt_id, exam_question_id, is_correct);
CREATE UNIQUE INDEX exam_links_token_uidx ON public.exam_links USING btree (token);
CREATE INDEX v5_student_answers_selected_option_idx ON public.v5_student_answers USING btree (selected_option_id);
CREATE INDEX v5_subjects_grade_idx ON public.v5_subjects USING btree (grade_id);
CREATE INDEX topics_subject_idx ON public.topics USING btree (subject_id);
CREATE INDEX admin_profiles_role_idx ON public.admin_profiles USING btree (role);
CREATE INDEX questions_difficulty_idx ON public.questions USING btree (difficulty);
CREATE INDEX v5_student_answers_attempt_idx ON public.v5_student_answers USING btree (attempt_id);
CREATE INDEX v5_question_bank_options_question_idx ON public.v5_question_bank_options USING btree (question_id);
CREATE INDEX student_subject_performance_subject_idx ON public.student_subject_performance USING btree (subject_id);
CREATE INDEX v5_question_bank_active_idx ON public.v5_question_bank USING btree (is_active);
CREATE INDEX v5_exam_questions_exam_order_idx ON public.v5_exam_questions USING btree (exam_id, question_order);
CREATE INDEX v5_exams_start_end_status_idx ON public.v5_exams USING btree (status, start_at, end_at);
CREATE INDEX student_subject_performance_student_idx ON public.student_subject_performance USING btree (student_id);
CREATE INDEX exam_results_exam_idx ON public.exam_results USING btree (exam_code);
CREATE INDEX exam_questions_question_idx ON public.exam_questions USING btree (question_id);
CREATE INDEX exam_attempts_student_id_idx ON public.exam_attempts USING btree (student_id);
CREATE INDEX exam_results_exam_percent_idx ON public.exam_results USING btree (exam_code, percent DESC);
CREATE INDEX exams_created_at_idx ON public.exams USING btree (created_at);
CREATE INDEX student_answers_question_id_idx ON public.student_answers USING btree (question_id);
CREATE INDEX v5_attempts_status_idx ON public.v5_attempts USING btree (status);
CREATE INDEX v5_qb_subject_idx ON public.v5_question_bank USING btree (subject_id);
CREATE INDEX v5_exams_status_idx ON public.v5_exams USING btree (status);
CREATE INDEX questions_created_at_idx ON public.questions USING btree (created_at);
CREATE INDEX v5_classes_field_idx ON public.v5_classes USING btree (field_id);
CREATE INDEX questions_active_idx ON public.questions USING btree (is_active);
CREATE INDEX student_answers_attempt_id_idx ON public.student_answers USING btree (attempt_id);
CREATE INDEX v5_qb_status_idx ON public.v5_question_bank USING btree (status);
CREATE INDEX v5_attempts_student_exam_idx ON public.v5_attempts USING btree (student_id, exam_id);
CREATE INDEX v5_qb_topic_idx ON public.v5_question_bank USING btree (topic_id);
CREATE INDEX exam_attempts_exam_id_idx ON public.exam_attempts USING btree (exam_id);
CREATE INDEX v5_exam_questions_exam_idx ON public.v5_exam_questions USING btree (exam_id);
CREATE INDEX v5_students_grade_idx ON public.v5_students USING btree (grade_id);
CREATE INDEX exam_answers_student_idx ON public.exam_answers USING btree (student_id);
CREATE INDEX v5_topics_parent_idx ON public.v5_topics USING btree (parent_id);
CREATE INDEX v5_questions_created_by_idx ON public.v5_questions USING btree (created_by);
CREATE INDEX v5_attempts_analytics_idx ON public.v5_attempts USING btree (exam_id, status, student_id, submitted_at DESC);
CREATE INDEX v5_qb_status_active_idx ON public.v5_question_bank USING btree (status, is_active);
CREATE INDEX questions_grade_idx ON public.questions USING btree (grade);
CREATE INDEX exam_results_class_idx ON public.exam_results USING btree (class_name);
CREATE INDEX v5_questions_active_idx ON public.v5_questions USING btree (is_active);
CREATE INDEX v5_questions_bank_question_idx ON public.v5_questions USING btree (bank_question_id);
CREATE INDEX v5_sources_created_by_idx ON public.v5_sources USING btree (created_by);
CREATE INDEX v5_qb_tags_gin_idx ON public.v5_question_bank USING gin (tags);
CREATE INDEX v5_students_class_idx ON public.v5_students USING btree (class_id);
CREATE INDEX v5_questions_subject_idx ON public.v5_questions USING btree (subject_id);
CREATE INDEX v5_qb_subject_status_idx ON public.v5_question_bank USING btree (subject_id, status, is_active);
CREATE INDEX v5_questions_difficulty_idx ON public.v5_questions USING btree (difficulty);
CREATE INDEX v5_exam_links_active_idx ON public.v5_exam_links USING btree (token) WHERE (is_active = true);
CREATE INDEX exams_grade_idx ON public.exams USING btree (grade);
create view "public"."v5_student_result_view" with (security_invoker=true) as  SELECT a.id AS attempt_id,
    a.exam_id,
    a.student_id,
    a.status,
    a.started_at,
    a.submitted_at,
    a.correct_count,
    a.wrong_count,
    a.blank_count,
    a.total_score,
    a.percentage,
    e.exam_code,
    e.title AS exam_title,
    e.show_result_to_student
   FROM v5_attempts a
     JOIN v5_exams e ON e.id = a.exam_id;
create view "public"."v5_attempt_answer_report_view" with (security_invoker=true) as  SELECT a.id AS attempt_id,
    a.student_id,
    a.exam_id,
    eq.id AS exam_question_id,
    eq.question_order,
    eq.score AS question_score,
    q.id AS question_id,
    q.question_text,
    sa.selected_option_id,
    sa.answer_text,
    sa.is_correct,
    sa.score_awarded,
    sa.answered_at
   FROM v5_attempts a
     JOIN v5_exam_questions eq ON eq.exam_id = a.exam_id
     JOIN v5_questions q ON q.id = eq.question_id
     LEFT JOIN v5_student_answers sa ON sa.attempt_id = a.id AND sa.exam_question_id = eq.id;
create view "public"."v5_exam_link_view" with (security_invoker=true) as  SELECT l.id AS link_id,
    l.token,
    l.is_active,
    l.expires_at,
    l.max_attempts_per_student,
    e.id AS exam_id,
    e.exam_code,
    e.title,
    e.description,
    e.duration_minutes,
    e.start_at,
    e.end_at,
    e.status,
    e.show_result_to_student,
    count(eq.id)::integer AS question_count
   FROM v5_exam_links l
     JOIN v5_exams e ON e.id = l.exam_id
     LEFT JOIN v5_exam_questions eq ON eq.exam_id = e.id
  GROUP BY l.id, l.token, l.is_active, l.expires_at, l.max_attempts_per_student, e.id, e.exam_code, e.title, e.description, e.duration_minutes, e.start_at, e.end_at, e.status, e.show_result_to_student;
create view "public"."question_bank_view" with (security_invoker=true) as  SELECT q.id,
    q.subject_id,
    s.name AS subject_name,
    s.grade,
    s.field,
    q.question_text,
    q.question_type,
    q.difficulty,
    q.chapter,
    q.topic,
    q.source_type,
    q.source_name,
    q.source_reference,
    q.exam_year,
    q.options,
    q.correct_answer,
    q.explanation,
    q.points,
    q.tags,
    q.is_active,
    q.sort_order,
    q.created_by,
    q.created_at,
    q.updated_at
   FROM questions q
     JOIN subjects s ON s.id = q.subject_id;
create view "public"."exam_latest_results" with (security_invoker=true) as  SELECT DISTINCT ON (exam_code, student_code) id,
    exam_code,
    student_name,
    student_code,
    class_name,
    correct_count,
    wrong_count,
    blank_count,
    percent,
    answers,
    submitted_at
   FROM exam_results
  ORDER BY exam_code, student_code, submitted_at DESC, id DESC;
create view "public"."v5_question_bank_admin_view" with (security_invoker=true) as  SELECT q.id,
    q.subject_id,
    s.name AS subject_name,
    q.topic_id,
    t.name AS topic_name,
    q.source_id,
    src.title AS source_title,
    q.question_text,
    q.question_type,
    q.difficulty,
    q.score,
    q.explanation,
    q.tags,
    q.source_page,
    q.status,
    q.is_active,
    q.created_by,
    q.created_at,
    q.updated_at,
    ( SELECT count(*) AS count
           FROM v5_question_bank_options o
          WHERE o.question_id = q.id) AS option_count,
    ( SELECT count(*) AS count
           FROM v5_question_bank_options o
          WHERE o.question_id = q.id AND o.is_correct = true) AS correct_option_count
   FROM v5_question_bank q
     LEFT JOIN v5_subjects s ON s.id = q.subject_id
     LEFT JOIN v5_topics t ON t.id = q.topic_id
     LEFT JOIN v5_question_sources src ON src.id = q.source_id;
create view "public"."v5_question_bank_detail_view" with (security_invoker=true) as  SELECT q.id AS question_id,
    q.question_text,
    q.question_type,
    q.difficulty,
    q.score,
    q.explanation,
    q.subject_id,
    s.name AS subject_name,
    q.topic_id,
    t.name AS topic_name,
    q.source_id,
    src.title AS source_title,
    q.source_page,
    q.tags,
    q.status,
    q.is_active,
    o.id AS option_id,
    o.option_key,
    o.option_text,
    o.is_correct,
    o.sort_order,
    q.created_at,
    q.updated_at
   FROM v5_question_bank q
     LEFT JOIN v5_subjects s ON s.id = q.subject_id
     LEFT JOIN v5_topics t ON t.id = q.topic_id
     LEFT JOIN v5_question_sources src ON src.id = q.source_id
     LEFT JOIN v5_question_bank_options o ON o.question_id = q.id;
create view "public"."educational_question_analysis" with (security_invoker=true) as  SELECT question_id,
    total_attempts,
    correct_attempts,
    wrong_attempts,
    unanswered_attempts,
    accuracy,
    average_time_seconds,
    calculated_difficulty,
    last_calculated_at
   FROM question_performance qp;
create view "public"."v5_exam_builder_view" with (security_invoker=true) as  SELECT e.id,
    e.exam_code,
    e.title,
    e.description,
    e.grade_id,
    g.name AS grade_name,
    e.field_id,
    f.name AS field_name,
    e.duration_minutes,
    e.status,
    e.randomize_questions,
    e.randomize_options,
    e.show_result_to_student,
    e.start_at,
    e.end_at,
    e.created_at,
    e.updated_at,
    count(eq.id) AS question_count,
    COALESCE(sum(eq.score), 0::numeric) AS total_score
   FROM v5_exams e
     LEFT JOIN v5_grades g ON g.id = e.grade_id
     LEFT JOIN v5_fields f ON f.id = e.field_id
     LEFT JOIN v5_exam_questions eq ON eq.exam_id = e.id
  GROUP BY e.id, e.exam_code, e.title, e.description, e.grade_id, g.name, e.field_id, f.name, e.duration_minutes, e.status, e.randomize_questions, e.randomize_options, e.show_result_to_student, e.start_at, e.end_at, e.created_at, e.updated_at;
create view "public"."educational_exam_analysis" with (security_invoker=true) as  SELECT exam_id,
    total_attempts,
    completed_attempts,
    average_percentage,
    highest_percentage,
    lowest_percentage,
    average_duration_seconds,
    updated_at
   FROM exam_analytics ea;
create view "public"."v5_exam_questions_view" with (security_invoker=true) as  SELECT eq.id AS exam_question_id,
    eq.exam_id,
    e.exam_code,
    e.title AS exam_title,
    eq.question_order,
    eq.score AS exam_question_score,
    q.id AS question_id,
    q.bank_question_id,
    q.subject_id,
    s.name AS subject_name,
    q.topic_id,
    t.name AS topic_name,
    q.question_text,
    q.question_type,
    q.difficulty,
    q.score AS question_score,
    q.is_active AS question_active,
    ( SELECT count(*) AS count
           FROM v5_question_options o
          WHERE o.question_id = q.id) AS option_count,
    ( SELECT count(*) AS count
           FROM v5_question_options o
          WHERE o.question_id = q.id AND o.is_correct = true) AS correct_option_count
   FROM v5_exam_questions eq
     JOIN v5_exams e ON e.id = eq.exam_id
     JOIN v5_questions q ON q.id = eq.question_id
     LEFT JOIN v5_subjects s ON s.id = q.subject_id
     LEFT JOIN v5_topics t ON t.id = q.topic_id;
create view "public"."educational_student_analysis" with (security_invoker=true) as  SELECT student_id,
    total_exams,
    completed_exams,
    total_questions,
    correct_answers,
    wrong_answers,
    unanswered_questions,
    overall_accuracy,
    average_percentage,
    strongest_subject_id,
    weakest_subject_id,
    last_exam_at,
    updated_at
   FROM student_learning_summary;
create view "public"."student_strength_weakness" with (security_invoker=true) as  SELECT student_id,
    subject_id,
    total_questions,
    answered_questions,
    correct_answers,
    wrong_answers,
    unanswered_questions,
    accuracy,
    average_score,
    average_time_seconds,
        CASE
            WHEN accuracy >= 80::numeric THEN 'strong'::text
            WHEN accuracy >= 60::numeric THEN 'normal'::text
            WHEN accuracy >= 40::numeric THEN 'needs_improvement'::text
            ELSE 'weak'::text
        END AS learning_status,
    last_activity_at
   FROM student_subject_performance;
create view "public"."educational_hard_questions" with (security_invoker=true) as  SELECT question_id,
    total_attempts,
    correct_attempts,
    wrong_attempts,
    accuracy,
    average_time_seconds,
    calculated_difficulty
   FROM question_performance
  WHERE total_attempts > 0 AND accuracy < 50::numeric;
create view "public"."questions_need_review" with (security_invoker=true) as  SELECT question_id,
    total_attempts,
    correct_attempts,
    wrong_attempts,
    accuracy,
    average_time_seconds,
    calculated_difficulty
   FROM question_performance
  WHERE total_attempts >= 5 AND accuracy < 30::numeric;
create view "public"."class_analytics_summary" with (security_invoker=true) as  SELECT exam_code,
    class_name,
    count(*) AS students_count,
    round(COALESCE(avg(percent), 0::numeric), 2) AS average_percent,
    round(COALESCE(max(percent), 0::numeric), 2) AS highest_percent,
    round(COALESCE(min(percent), 0::numeric), 2) AS lowest_percent,
    round(COALESCE(avg(correct_count), 0::numeric), 2) AS average_correct,
    round(COALESCE(avg(wrong_count), 0::numeric), 2) AS average_wrong,
    round(COALESCE(avg(blank_count), 0::numeric), 2) AS average_blank,
    count(*) FILTER (WHERE percent >= 50::numeric) AS passed_count,
    count(*) FILTER (WHERE percent < 50::numeric) AS weak_count,
    round(count(*) FILTER (WHERE percent >= 50::numeric)::numeric / NULLIF(count(*), 0)::numeric * 100::numeric, 2) AS pass_rate
   FROM exam_latest_results
  GROUP BY exam_code, class_name;
create view "public"."student_analytics_summary" with (security_invoker=true) as  SELECT student_code,
    max(student_name) AS student_name,
    max(class_name) AS class_name,
    count(*) AS exams_count,
    round(COALESCE(avg(percent), 0::numeric), 2) AS average_percent,
    round(COALESCE(max(percent), 0::numeric), 2) AS highest_percent,
    round(COALESCE(min(percent), 0::numeric), 2) AS lowest_percent,
    round(COALESCE(avg(correct_count), 0::numeric), 2) AS average_correct,
    round(COALESCE(avg(wrong_count), 0::numeric), 2) AS average_wrong,
    round(COALESCE(avg(blank_count), 0::numeric), 2) AS average_blank,
    count(*) FILTER (WHERE percent >= 50::numeric) AS passed_exams,
    count(*) FILTER (WHERE percent < 50::numeric) AS weak_exams,
    round(count(*) FILTER (WHERE percent >= 50::numeric)::numeric / NULLIF(count(*), 0)::numeric * 100::numeric, 2) AS success_rate
   FROM exam_latest_results
  GROUP BY student_code;
create view "public"."exam_student_ranking" with (security_invoker=true) as  SELECT id,
    exam_code,
    student_name,
    student_code,
    class_name,
    correct_count,
    wrong_count,
    blank_count,
    percent,
    submitted_at,
    rank() OVER (PARTITION BY exam_code ORDER BY percent DESC) AS exam_rank,
    dense_rank() OVER (PARTITION BY exam_code ORDER BY percent DESC) AS exam_dense_rank,
    count(*) OVER (PARTITION BY exam_code) AS exam_students_count
   FROM exam_latest_results;
create view "public"."exam_analytics_summary" with (security_invoker=true) as  SELECT exam_code,
    count(*) AS students_count,
    round(COALESCE(avg(percent), 0::numeric), 2) AS average_percent,
    round(COALESCE(max(percent), 0::numeric), 2) AS highest_percent,
    round(COALESCE(min(percent), 0::numeric), 2) AS lowest_percent,
    round(COALESCE(avg(correct_count), 0::numeric), 2) AS average_correct,
    round(COALESCE(avg(wrong_count), 0::numeric), 2) AS average_wrong,
    round(COALESCE(avg(blank_count), 0::numeric), 2) AS average_blank,
    count(*) FILTER (WHERE percent >= 90::numeric) AS excellent_count,
    count(*) FILTER (WHERE percent >= 75::numeric AND percent < 90::numeric) AS very_good_count,
    count(*) FILTER (WHERE percent >= 50::numeric AND percent < 75::numeric) AS passed_count,
    count(*) FILTER (WHERE percent < 50::numeric) AS weak_count
   FROM exam_latest_results
  GROUP BY exam_code;
create view "public"."exam_answer_distribution" with (security_invoker=true) as  SELECT r.exam_code,
    a.key AS question_key,
    a.value AS selected_answer,
    count(*) AS answer_count
   FROM exam_latest_results r
     CROSS JOIN LATERAL jsonb_each(
        CASE
            WHEN jsonb_typeof(r.answers) = 'object'::text THEN r.answers
            ELSE '{}'::jsonb
        END) a(key, value)
  GROUP BY r.exam_code, a.key, a.value;
create view "public"."exam_performance_distribution" with (security_invoker=true) as  SELECT exam_code,
    count(*) AS total_students,
    count(*) FILTER (WHERE percent >= 90::numeric) AS level_excellent,
    count(*) FILTER (WHERE percent >= 75::numeric AND percent < 90::numeric) AS level_very_good,
    count(*) FILTER (WHERE percent >= 60::numeric AND percent < 75::numeric) AS level_good,
    count(*) FILTER (WHERE percent >= 50::numeric AND percent < 60::numeric) AS level_acceptable,
    count(*) FILTER (WHERE percent < 50::numeric) AS level_weak
   FROM exam_latest_results
  GROUP BY exam_code;
create view "public"."admin_dashboard_summary" with (security_invoker=true) as  SELECT count(DISTINCT student_code) AS total_students,
    count(DISTINCT exam_code) AS total_exams,
    count(*) AS total_exam_results,
    round(COALESCE(avg(percent), 0::numeric), 2) AS overall_average_percent,
    round(COALESCE(max(percent), 0::numeric), 2) AS highest_percent,
    round(COALESCE(min(percent), 0::numeric), 2) AS lowest_percent,
    count(*) FILTER (WHERE percent >= 50::numeric) AS passed_results,
    count(*) FILTER (WHERE percent < 50::numeric) AS weak_results
   FROM exam_latest_results;
create view "public"."student_performance_levels" with (security_invoker=true) as  SELECT student_code,
    student_name,
    class_name,
    exams_count,
    average_percent,
    highest_percent,
    lowest_percent,
    passed_exams,
    weak_exams,
    success_rate,
        CASE
            WHEN average_percent >= 90::numeric THEN 'عالی'::text
            WHEN average_percent >= 75::numeric THEN 'خیلی خوب'::text
            WHEN average_percent >= 60::numeric THEN 'خوب'::text
            WHEN average_percent >= 50::numeric THEN 'قابل قبول'::text
            ELSE 'نیازمند تلاش بیشتر'::text
        END AS performance_level
   FROM student_analytics_summary;
alter table "public"."exam_answers" enable row level security;
alter table "public"."v5_profiles" enable row level security;
alter table "public"."v5_grades" enable row level security;
alter table "public"."v5_fields" enable row level security;
alter table "public"."v5_exam_links" enable row level security;
alter table "public"."v5_classes" enable row level security;
alter table "public"."v5_subjects" enable row level security;
alter table "public"."v5_topics" enable row level security;
alter table "public"."v5_sources" enable row level security;
alter table "public"."v5_exam_classes" enable row level security;
alter table "public"."v5_question_sources" enable row level security;
alter table "public"."v5_question_bank" enable row level security;
alter table "public"."v5_question_bank_options" enable row level security;
alter table "public"."v5_student_answers" enable row level security;
alter table "public"."v5_exams" enable row level security;
alter table "public"."v5_attempts" enable row level security;
alter table "public"."v5_students" enable row level security;
alter table "public"."v5_questions" enable row level security;
alter table "public"."v5_question_options" enable row level security;
alter table "public"."v5_exam_questions" enable row level security;
alter table "public"."subjects" enable row level security;
alter table "public"."topics" enable row level security;
alter table "public"."admin_profiles" enable row level security;
alter table "public"."questions" enable row level security;
alter table "public"."exams" enable row level security;
alter table "public"."exam_questions" enable row level security;
alter table "public"."exam_links" enable row level security;
alter table "public"."exam_results" enable row level security;
alter table "public"."exam_attempts" enable row level security;
alter table "public"."student_answers" enable row level security;
alter table "public"."student_question_performance" enable row level security;
alter table "public"."student_subject_performance" enable row level security;
alter table "public"."question_performance" enable row level security;
alter table "public"."student_learning_summary" enable row level security;
alter table "public"."exam_analytics" enable row level security;
create policy "allow_exam_result_insert" on "public"."exam_results" as PERMISSIVE for INSERT to "anon" with check (true);
create policy "v5_grades_staff_select" on "public"."v5_grades" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_fields_staff_select" on "public"."v5_fields" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_classes_staff_select" on "public"."v5_classes" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_subjects_staff_select" on "public"."v5_subjects" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_topics_staff_select" on "public"."v5_topics" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_sources_staff_select" on "public"."v5_sources" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_questions_staff_select" on "public"."v5_questions" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_question_options_staff_select" on "public"."v5_question_options" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_exams_staff_select" on "public"."v5_exams" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_exam_questions_staff_select" on "public"."v5_exam_questions" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_exam_classes_staff_select" on "public"."v5_exam_classes" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "public_read_subjects" on "public"."subjects" as PERMISSIVE for SELECT to "anon","authenticated" using ((is_active = true));
create policy "admins_read_admin_profiles" on "public"."admin_profiles" as PERMISSIVE for SELECT to "authenticated" using (is_admin());
create policy "admins_read_questions" on "public"."questions" as PERMISSIVE for SELECT to "authenticated" using (is_admin());
create policy "admins_insert_questions" on "public"."questions" as PERMISSIVE for INSERT to "authenticated" with check (is_admin());
create policy "admins_update_questions" on "public"."questions" as PERMISSIVE for UPDATE to "authenticated" using (is_admin()) with check (is_admin());
create policy "admins_delete_questions" on "public"."questions" as PERMISSIVE for DELETE to "authenticated" using (is_admin());
create policy "admins_read_exams" on "public"."exams" as PERMISSIVE for SELECT to "authenticated" using (is_admin());
create policy "admins_insert_exams" on "public"."exams" as PERMISSIVE for INSERT to "authenticated" with check (is_admin());
create policy "admins_update_exams" on "public"."exams" as PERMISSIVE for UPDATE to "authenticated" using (is_admin()) with check (is_admin());
create policy "admins_delete_exams" on "public"."exams" as PERMISSIVE for DELETE to "authenticated" using (is_admin());
create policy "admins_read_topics" on "public"."topics" as PERMISSIVE for SELECT to "authenticated" using (is_admin());
create policy "admins_insert_topics" on "public"."topics" as PERMISSIVE for INSERT to "authenticated" with check (is_admin());
create policy "admins_update_topics" on "public"."topics" as PERMISSIVE for UPDATE to "authenticated" using (is_admin()) with check (is_admin());
create policy "admins_delete_topics" on "public"."topics" as PERMISSIVE for DELETE to "authenticated" using (is_admin());
create policy "admins_insert_subjects" on "public"."subjects" as PERMISSIVE for INSERT to "authenticated" with check (is_admin());
create policy "admins_update_subjects" on "public"."subjects" as PERMISSIVE for UPDATE to "authenticated" using (is_admin()) with check (is_admin());
create policy "admins_delete_subjects" on "public"."subjects" as PERMISSIVE for DELETE to "authenticated" using (is_admin());
create policy "authenticated_admin_read_exam_links" on "public"."exam_links" as PERMISSIVE for SELECT to "authenticated" using (true);
create policy "authenticated_admin_read_exam_questions" on "public"."exam_questions" as PERMISSIVE for SELECT to "authenticated" using (true);
create policy "authenticated_admin_insert_exam_questions" on "public"."exam_questions" as PERMISSIVE for INSERT to "authenticated" with check (true);
create policy "authenticated_admin_update_exam_questions" on "public"."exam_questions" as PERMISSIVE for UPDATE to "authenticated" using (true) with check (true);
create policy "authenticated_admin_delete_exam_questions" on "public"."exam_questions" as PERMISSIVE for DELETE to "authenticated" using (true);
create policy "authenticated_admin_read_results" on "public"."exam_results" as PERMISSIVE for SELECT to "authenticated" using (true);
create policy "students_read_own_attempts" on "public"."exam_attempts" as PERMISSIVE for SELECT to "authenticated" using ((student_id = auth.uid()));
create policy "students_insert_own_attempts" on "public"."exam_attempts" as PERMISSIVE for INSERT to "authenticated" with check ((student_id = auth.uid()));
create policy "students_read_own_answers" on "public"."student_answers" as PERMISSIVE for SELECT to "authenticated" using ((EXISTS ( SELECT 1
   FROM exam_attempts ea
  WHERE ((ea.id = student_answers.attempt_id) AND (ea.student_id = auth.uid())))));
create policy "students_insert_own_answers" on "public"."student_answers" as PERMISSIVE for INSERT to "authenticated" with check ((EXISTS ( SELECT 1
   FROM exam_attempts ea
  WHERE ((ea.id = student_answers.attempt_id) AND (ea.student_id = auth.uid())))));
create policy "students_read_question_performance" on "public"."student_question_performance" as PERMISSIVE for SELECT to "authenticated" using ((student_id = auth.uid()));
create policy "students_read_subject_performance" on "public"."student_subject_performance" as PERMISSIVE for SELECT to "authenticated" using ((student_id = auth.uid()));
create policy "students_read_learning_summary" on "public"."student_learning_summary" as PERMISSIVE for SELECT to "authenticated" using ((student_id = auth.uid()));
create policy "v5_sources_authenticated_select" on "public"."v5_question_sources" as PERMISSIVE for SELECT to "authenticated" using (true);
create policy "v5_question_bank_staff_select" on "public"."v5_question_bank" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "v5_question_bank_options_staff_select" on "public"."v5_question_bank_options" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "staff_manage_exam_links" on "public"."v5_exam_links" as PERMISSIVE for SELECT to "authenticated" using (v5_is_staff());
create policy "staff_insert_exam_links" on "public"."v5_exam_links" as PERMISSIVE for INSERT to "authenticated" with check (v5_is_staff());
create policy "staff_update_exam_links" on "public"."v5_exam_links" as PERMISSIVE for UPDATE to "authenticated" using (v5_is_staff()) with check (v5_is_staff());
create policy "v5_profiles_self_select" on "public"."v5_profiles" as PERMISSIVE for SELECT to "authenticated" using ((id = ( SELECT auth.uid() AS uid)));
create policy "v5_students_select" on "public"."v5_students" as PERMISSIVE for SELECT to "authenticated" using (((user_id = ( SELECT auth.uid() AS uid)) OR v5_is_staff()));
create policy "v5_attempts_select" on "public"."v5_attempts" as PERMISSIVE for SELECT to "authenticated" using (((EXISTS ( SELECT 1
   FROM v5_students s
  WHERE ((s.id = v5_attempts.student_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR v5_is_staff()));
create policy "v5_answers_select" on "public"."v5_student_answers" as PERMISSIVE for SELECT to "authenticated" using (((EXISTS ( SELECT 1
   FROM (v5_attempts a
     JOIN v5_students s ON ((s.id = a.student_id)))
  WHERE ((a.id = v5_student_answers.attempt_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))) OR v5_is_staff()));
CREATE TRIGGER v5_profiles_updated_at BEFORE UPDATE ON v5_profiles FOR EACH ROW EXECUTE FUNCTION v5_set_updated_at();
CREATE TRIGGER v5_students_updated_at BEFORE UPDATE ON v5_students FOR EACH ROW EXECUTE FUNCTION v5_set_updated_at();
CREATE TRIGGER v5_questions_updated_at BEFORE UPDATE ON v5_questions FOR EACH ROW EXECUTE FUNCTION v5_set_updated_at();
CREATE TRIGGER v5_exams_updated_at BEFORE UPDATE ON v5_exams FOR EACH ROW EXECUTE FUNCTION v5_set_updated_at();
CREATE TRIGGER v5_question_bank_updated_at BEFORE UPDATE ON v5_question_bank FOR EACH ROW EXECUTE FUNCTION v5_question_bank_set_updated_at();
CREATE TRIGGER trg_v5_student_answers_recalculate_attempt AFTER INSERT OR DELETE OR UPDATE ON v5_student_answers FOR EACH ROW EXECUTE FUNCTION v5_student_answers_recalculate_attempt();
CREATE TRIGGER v5_auto_exam_link_on_publish AFTER INSERT OR UPDATE OF status ON v5_exams FOR EACH ROW EXECUTE FUNCTION v5_auto_create_exam_link_on_publish();
revoke all on all tables in schema public from public,anon,authenticated,service_role;
revoke all on all sequences in schema public from public,anon,authenticated,service_role;
revoke all on all functions in schema public,v5_private from public,anon,authenticated,service_role;
grant SELECT on sequence "public"."exam_answers_id_seq" to "anon";
grant UPDATE on sequence "public"."exam_answers_id_seq" to "anon";
grant USAGE on sequence "public"."exam_answers_id_seq" to "anon";
grant SELECT on sequence "public"."exam_answers_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exam_answers_id_seq" to "authenticated";
grant USAGE on sequence "public"."exam_answers_id_seq" to "authenticated";
grant SELECT on sequence "public"."exam_answers_id_seq" to "service_role";
grant UPDATE on sequence "public"."exam_answers_id_seq" to "service_role";
grant USAGE on sequence "public"."exam_answers_id_seq" to "service_role";
grant INSERT on table "public"."exam_answers" to "anon";
grant SELECT on table "public"."exam_answers" to "anon";
grant UPDATE on table "public"."exam_answers" to "anon";
grant DELETE on table "public"."exam_answers" to "anon";
grant TRUNCATE on table "public"."exam_answers" to "anon";
grant REFERENCES on table "public"."exam_answers" to "anon";
grant TRIGGER on table "public"."exam_answers" to "anon";
grant MAINTAIN on table "public"."exam_answers" to "anon";
grant INSERT on table "public"."exam_answers" to "authenticated";
grant SELECT on table "public"."exam_answers" to "authenticated";
grant UPDATE on table "public"."exam_answers" to "authenticated";
grant DELETE on table "public"."exam_answers" to "authenticated";
grant TRUNCATE on table "public"."exam_answers" to "authenticated";
grant REFERENCES on table "public"."exam_answers" to "authenticated";
grant TRIGGER on table "public"."exam_answers" to "authenticated";
grant MAINTAIN on table "public"."exam_answers" to "authenticated";
grant INSERT on table "public"."exam_answers" to "service_role";
grant SELECT on table "public"."exam_answers" to "service_role";
grant UPDATE on table "public"."exam_answers" to "service_role";
grant DELETE on table "public"."exam_answers" to "service_role";
grant TRUNCATE on table "public"."exam_answers" to "service_role";
grant REFERENCES on table "public"."exam_answers" to "service_role";
grant TRIGGER on table "public"."exam_answers" to "service_role";
grant MAINTAIN on table "public"."exam_answers" to "service_role";
grant INSERT on table "public"."class_analytics_summary" to "anon";
grant SELECT on table "public"."class_analytics_summary" to "anon";
grant UPDATE on table "public"."class_analytics_summary" to "anon";
grant DELETE on table "public"."class_analytics_summary" to "anon";
grant TRUNCATE on table "public"."class_analytics_summary" to "anon";
grant REFERENCES on table "public"."class_analytics_summary" to "anon";
grant TRIGGER on table "public"."class_analytics_summary" to "anon";
grant MAINTAIN on table "public"."class_analytics_summary" to "anon";
grant INSERT on table "public"."class_analytics_summary" to "authenticated";
grant SELECT on table "public"."class_analytics_summary" to "authenticated";
grant UPDATE on table "public"."class_analytics_summary" to "authenticated";
grant DELETE on table "public"."class_analytics_summary" to "authenticated";
grant TRUNCATE on table "public"."class_analytics_summary" to "authenticated";
grant REFERENCES on table "public"."class_analytics_summary" to "authenticated";
grant TRIGGER on table "public"."class_analytics_summary" to "authenticated";
grant MAINTAIN on table "public"."class_analytics_summary" to "authenticated";
grant INSERT on table "public"."class_analytics_summary" to "service_role";
grant SELECT on table "public"."class_analytics_summary" to "service_role";
grant UPDATE on table "public"."class_analytics_summary" to "service_role";
grant DELETE on table "public"."class_analytics_summary" to "service_role";
grant TRUNCATE on table "public"."class_analytics_summary" to "service_role";
grant REFERENCES on table "public"."class_analytics_summary" to "service_role";
grant TRIGGER on table "public"."class_analytics_summary" to "service_role";
grant MAINTAIN on table "public"."class_analytics_summary" to "service_role";
grant INSERT on table "public"."student_analytics_summary" to "anon";
grant SELECT on table "public"."student_analytics_summary" to "anon";
grant UPDATE on table "public"."student_analytics_summary" to "anon";
grant DELETE on table "public"."student_analytics_summary" to "anon";
grant TRUNCATE on table "public"."student_analytics_summary" to "anon";
grant REFERENCES on table "public"."student_analytics_summary" to "anon";
grant TRIGGER on table "public"."student_analytics_summary" to "anon";
grant MAINTAIN on table "public"."student_analytics_summary" to "anon";
grant INSERT on table "public"."student_analytics_summary" to "authenticated";
grant SELECT on table "public"."student_analytics_summary" to "authenticated";
grant UPDATE on table "public"."student_analytics_summary" to "authenticated";
grant DELETE on table "public"."student_analytics_summary" to "authenticated";
grant TRUNCATE on table "public"."student_analytics_summary" to "authenticated";
grant REFERENCES on table "public"."student_analytics_summary" to "authenticated";
grant TRIGGER on table "public"."student_analytics_summary" to "authenticated";
grant MAINTAIN on table "public"."student_analytics_summary" to "authenticated";
grant INSERT on table "public"."student_analytics_summary" to "service_role";
grant SELECT on table "public"."student_analytics_summary" to "service_role";
grant UPDATE on table "public"."student_analytics_summary" to "service_role";
grant DELETE on table "public"."student_analytics_summary" to "service_role";
grant TRUNCATE on table "public"."student_analytics_summary" to "service_role";
grant REFERENCES on table "public"."student_analytics_summary" to "service_role";
grant TRIGGER on table "public"."student_analytics_summary" to "service_role";
grant MAINTAIN on table "public"."student_analytics_summary" to "service_role";
grant INSERT on table "public"."v5_student_result_view" to "anon";
grant SELECT on table "public"."v5_student_result_view" to "anon";
grant UPDATE on table "public"."v5_student_result_view" to "anon";
grant DELETE on table "public"."v5_student_result_view" to "anon";
grant TRUNCATE on table "public"."v5_student_result_view" to "anon";
grant REFERENCES on table "public"."v5_student_result_view" to "anon";
grant TRIGGER on table "public"."v5_student_result_view" to "anon";
grant MAINTAIN on table "public"."v5_student_result_view" to "anon";
grant INSERT on table "public"."v5_student_result_view" to "authenticated";
grant SELECT on table "public"."v5_student_result_view" to "authenticated";
grant UPDATE on table "public"."v5_student_result_view" to "authenticated";
grant DELETE on table "public"."v5_student_result_view" to "authenticated";
grant TRUNCATE on table "public"."v5_student_result_view" to "authenticated";
grant REFERENCES on table "public"."v5_student_result_view" to "authenticated";
grant TRIGGER on table "public"."v5_student_result_view" to "authenticated";
grant MAINTAIN on table "public"."v5_student_result_view" to "authenticated";
grant INSERT on table "public"."v5_student_result_view" to "service_role";
grant SELECT on table "public"."v5_student_result_view" to "service_role";
grant UPDATE on table "public"."v5_student_result_view" to "service_role";
grant DELETE on table "public"."v5_student_result_view" to "service_role";
grant TRUNCATE on table "public"."v5_student_result_view" to "service_role";
grant REFERENCES on table "public"."v5_student_result_view" to "service_role";
grant TRIGGER on table "public"."v5_student_result_view" to "service_role";
grant MAINTAIN on table "public"."v5_student_result_view" to "service_role";
grant INSERT on table "public"."v5_attempt_answer_report_view" to "anon";
grant SELECT on table "public"."v5_attempt_answer_report_view" to "anon";
grant UPDATE on table "public"."v5_attempt_answer_report_view" to "anon";
grant DELETE on table "public"."v5_attempt_answer_report_view" to "anon";
grant TRUNCATE on table "public"."v5_attempt_answer_report_view" to "anon";
grant REFERENCES on table "public"."v5_attempt_answer_report_view" to "anon";
grant TRIGGER on table "public"."v5_attempt_answer_report_view" to "anon";
grant MAINTAIN on table "public"."v5_attempt_answer_report_view" to "anon";
grant INSERT on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant SELECT on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant UPDATE on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant DELETE on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant TRUNCATE on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant REFERENCES on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant TRIGGER on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant MAINTAIN on table "public"."v5_attempt_answer_report_view" to "authenticated";
grant INSERT on table "public"."v5_attempt_answer_report_view" to "service_role";
grant SELECT on table "public"."v5_attempt_answer_report_view" to "service_role";
grant UPDATE on table "public"."v5_attempt_answer_report_view" to "service_role";
grant DELETE on table "public"."v5_attempt_answer_report_view" to "service_role";
grant TRUNCATE on table "public"."v5_attempt_answer_report_view" to "service_role";
grant REFERENCES on table "public"."v5_attempt_answer_report_view" to "service_role";
grant TRIGGER on table "public"."v5_attempt_answer_report_view" to "service_role";
grant MAINTAIN on table "public"."v5_attempt_answer_report_view" to "service_role";
grant SELECT on sequence "public"."v5_exam_links_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_exam_links_id_seq" to "anon";
grant USAGE on sequence "public"."v5_exam_links_id_seq" to "anon";
grant SELECT on sequence "public"."v5_exam_links_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_exam_links_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_exam_links_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_exam_links_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_exam_links_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_exam_links_id_seq" to "service_role";
grant INSERT on table "public"."v5_profiles" to "anon";
grant SELECT on table "public"."v5_profiles" to "anon";
grant UPDATE on table "public"."v5_profiles" to "anon";
grant DELETE on table "public"."v5_profiles" to "anon";
grant TRUNCATE on table "public"."v5_profiles" to "anon";
grant REFERENCES on table "public"."v5_profiles" to "anon";
grant TRIGGER on table "public"."v5_profiles" to "anon";
grant MAINTAIN on table "public"."v5_profiles" to "anon";
grant INSERT on table "public"."v5_profiles" to "authenticated";
grant SELECT on table "public"."v5_profiles" to "authenticated";
grant UPDATE on table "public"."v5_profiles" to "authenticated";
grant DELETE on table "public"."v5_profiles" to "authenticated";
grant TRUNCATE on table "public"."v5_profiles" to "authenticated";
grant REFERENCES on table "public"."v5_profiles" to "authenticated";
grant TRIGGER on table "public"."v5_profiles" to "authenticated";
grant MAINTAIN on table "public"."v5_profiles" to "authenticated";
grant INSERT on table "public"."v5_profiles" to "service_role";
grant SELECT on table "public"."v5_profiles" to "service_role";
grant UPDATE on table "public"."v5_profiles" to "service_role";
grant DELETE on table "public"."v5_profiles" to "service_role";
grant TRUNCATE on table "public"."v5_profiles" to "service_role";
grant REFERENCES on table "public"."v5_profiles" to "service_role";
grant TRIGGER on table "public"."v5_profiles" to "service_role";
grant MAINTAIN on table "public"."v5_profiles" to "service_role";
grant INSERT on table "public"."v5_grades" to "anon";
grant SELECT on table "public"."v5_grades" to "anon";
grant UPDATE on table "public"."v5_grades" to "anon";
grant DELETE on table "public"."v5_grades" to "anon";
grant TRUNCATE on table "public"."v5_grades" to "anon";
grant REFERENCES on table "public"."v5_grades" to "anon";
grant TRIGGER on table "public"."v5_grades" to "anon";
grant MAINTAIN on table "public"."v5_grades" to "anon";
grant INSERT on table "public"."v5_grades" to "authenticated";
grant SELECT on table "public"."v5_grades" to "authenticated";
grant UPDATE on table "public"."v5_grades" to "authenticated";
grant DELETE on table "public"."v5_grades" to "authenticated";
grant TRUNCATE on table "public"."v5_grades" to "authenticated";
grant REFERENCES on table "public"."v5_grades" to "authenticated";
grant TRIGGER on table "public"."v5_grades" to "authenticated";
grant MAINTAIN on table "public"."v5_grades" to "authenticated";
grant INSERT on table "public"."v5_grades" to "service_role";
grant SELECT on table "public"."v5_grades" to "service_role";
grant UPDATE on table "public"."v5_grades" to "service_role";
grant DELETE on table "public"."v5_grades" to "service_role";
grant TRUNCATE on table "public"."v5_grades" to "service_role";
grant REFERENCES on table "public"."v5_grades" to "service_role";
grant TRIGGER on table "public"."v5_grades" to "service_role";
grant MAINTAIN on table "public"."v5_grades" to "service_role";
grant INSERT on table "public"."v5_fields" to "anon";
grant SELECT on table "public"."v5_fields" to "anon";
grant UPDATE on table "public"."v5_fields" to "anon";
grant DELETE on table "public"."v5_fields" to "anon";
grant TRUNCATE on table "public"."v5_fields" to "anon";
grant REFERENCES on table "public"."v5_fields" to "anon";
grant TRIGGER on table "public"."v5_fields" to "anon";
grant MAINTAIN on table "public"."v5_fields" to "anon";
grant INSERT on table "public"."v5_fields" to "authenticated";
grant SELECT on table "public"."v5_fields" to "authenticated";
grant UPDATE on table "public"."v5_fields" to "authenticated";
grant DELETE on table "public"."v5_fields" to "authenticated";
grant TRUNCATE on table "public"."v5_fields" to "authenticated";
grant REFERENCES on table "public"."v5_fields" to "authenticated";
grant TRIGGER on table "public"."v5_fields" to "authenticated";
grant MAINTAIN on table "public"."v5_fields" to "authenticated";
grant INSERT on table "public"."v5_fields" to "service_role";
grant SELECT on table "public"."v5_fields" to "service_role";
grant UPDATE on table "public"."v5_fields" to "service_role";
grant DELETE on table "public"."v5_fields" to "service_role";
grant TRUNCATE on table "public"."v5_fields" to "service_role";
grant REFERENCES on table "public"."v5_fields" to "service_role";
grant TRIGGER on table "public"."v5_fields" to "service_role";
grant MAINTAIN on table "public"."v5_fields" to "service_role";
grant SELECT on sequence "public"."exam_results_id_seq" to "anon";
grant UPDATE on sequence "public"."exam_results_id_seq" to "anon";
grant USAGE on sequence "public"."exam_results_id_seq" to "anon";
grant SELECT on sequence "public"."exam_results_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exam_results_id_seq" to "authenticated";
grant USAGE on sequence "public"."exam_results_id_seq" to "authenticated";
grant SELECT on sequence "public"."exam_results_id_seq" to "service_role";
grant UPDATE on sequence "public"."exam_results_id_seq" to "service_role";
grant USAGE on sequence "public"."exam_results_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_grades_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_grades_id_seq" to "anon";
grant USAGE on sequence "public"."v5_grades_id_seq" to "anon";
grant SELECT on sequence "public"."v5_grades_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_grades_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_grades_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_grades_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_grades_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_grades_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_fields_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_fields_id_seq" to "anon";
grant USAGE on sequence "public"."v5_fields_id_seq" to "anon";
grant SELECT on sequence "public"."v5_fields_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_fields_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_fields_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_fields_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_fields_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_fields_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_classes_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_classes_id_seq" to "anon";
grant USAGE on sequence "public"."v5_classes_id_seq" to "anon";
grant SELECT on sequence "public"."v5_classes_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_classes_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_classes_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_classes_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_classes_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_classes_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_students_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_students_id_seq" to "anon";
grant USAGE on sequence "public"."v5_students_id_seq" to "anon";
grant SELECT on sequence "public"."v5_students_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_students_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_students_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_students_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_students_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_students_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_subjects_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_subjects_id_seq" to "anon";
grant USAGE on sequence "public"."v5_subjects_id_seq" to "anon";
grant SELECT on sequence "public"."v5_subjects_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_subjects_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_subjects_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_subjects_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_subjects_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_subjects_id_seq" to "service_role";
grant INSERT on table "public"."v5_exam_links" to "anon";
grant SELECT on table "public"."v5_exam_links" to "anon";
grant UPDATE on table "public"."v5_exam_links" to "anon";
grant DELETE on table "public"."v5_exam_links" to "anon";
grant TRUNCATE on table "public"."v5_exam_links" to "anon";
grant REFERENCES on table "public"."v5_exam_links" to "anon";
grant TRIGGER on table "public"."v5_exam_links" to "anon";
grant MAINTAIN on table "public"."v5_exam_links" to "anon";
grant INSERT on table "public"."v5_exam_links" to "authenticated";
grant SELECT on table "public"."v5_exam_links" to "authenticated";
grant UPDATE on table "public"."v5_exam_links" to "authenticated";
grant DELETE on table "public"."v5_exam_links" to "authenticated";
grant TRUNCATE on table "public"."v5_exam_links" to "authenticated";
grant REFERENCES on table "public"."v5_exam_links" to "authenticated";
grant TRIGGER on table "public"."v5_exam_links" to "authenticated";
grant MAINTAIN on table "public"."v5_exam_links" to "authenticated";
grant INSERT on table "public"."v5_exam_links" to "service_role";
grant SELECT on table "public"."v5_exam_links" to "service_role";
grant UPDATE on table "public"."v5_exam_links" to "service_role";
grant DELETE on table "public"."v5_exam_links" to "service_role";
grant TRUNCATE on table "public"."v5_exam_links" to "service_role";
grant REFERENCES on table "public"."v5_exam_links" to "service_role";
grant TRIGGER on table "public"."v5_exam_links" to "service_role";
grant MAINTAIN on table "public"."v5_exam_links" to "service_role";
grant SELECT on sequence "public"."v5_question_sources_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_question_sources_id_seq" to "anon";
grant USAGE on sequence "public"."v5_question_sources_id_seq" to "anon";
grant SELECT on sequence "public"."v5_question_sources_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_question_sources_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_question_sources_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_question_sources_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_question_sources_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_question_sources_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_topics_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_topics_id_seq" to "anon";
grant USAGE on sequence "public"."v5_topics_id_seq" to "anon";
grant SELECT on sequence "public"."v5_topics_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_topics_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_topics_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_topics_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_topics_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_topics_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_sources_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_sources_id_seq" to "anon";
grant USAGE on sequence "public"."v5_sources_id_seq" to "anon";
grant SELECT on sequence "public"."v5_sources_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_sources_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_sources_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_sources_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_sources_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_sources_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_question_bank_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_question_bank_id_seq" to "anon";
grant USAGE on sequence "public"."v5_question_bank_id_seq" to "anon";
grant SELECT on sequence "public"."v5_question_bank_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_question_bank_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_question_bank_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_question_bank_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_question_bank_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_question_bank_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_questions_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_questions_id_seq" to "anon";
grant USAGE on sequence "public"."v5_questions_id_seq" to "anon";
grant SELECT on sequence "public"."v5_questions_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_questions_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_questions_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_questions_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_questions_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_questions_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_question_options_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_question_options_id_seq" to "anon";
grant USAGE on sequence "public"."v5_question_options_id_seq" to "anon";
grant SELECT on sequence "public"."v5_question_options_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_question_options_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_question_options_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_question_options_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_question_options_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_question_options_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_question_bank_options_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_question_bank_options_id_seq" to "anon";
grant USAGE on sequence "public"."v5_question_bank_options_id_seq" to "anon";
grant SELECT on sequence "public"."v5_question_bank_options_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_question_bank_options_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_question_bank_options_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_question_bank_options_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_question_bank_options_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_question_bank_options_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_exams_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_exams_id_seq" to "anon";
grant USAGE on sequence "public"."v5_exams_id_seq" to "anon";
grant SELECT on sequence "public"."v5_exams_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_exams_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_exams_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_exams_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_exams_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_exams_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_exam_questions_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_exam_questions_id_seq" to "anon";
grant USAGE on sequence "public"."v5_exam_questions_id_seq" to "anon";
grant SELECT on sequence "public"."v5_exam_questions_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_exam_questions_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_exam_questions_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_exam_questions_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_exam_questions_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_exam_questions_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_exam_classes_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_exam_classes_id_seq" to "anon";
grant USAGE on sequence "public"."v5_exam_classes_id_seq" to "anon";
grant SELECT on sequence "public"."v5_exam_classes_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_exam_classes_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_exam_classes_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_exam_classes_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_exam_classes_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_exam_classes_id_seq" to "service_role";
grant SELECT on sequence "public"."v5_student_answers_id_seq" to "anon";
grant UPDATE on sequence "public"."v5_student_answers_id_seq" to "anon";
grant USAGE on sequence "public"."v5_student_answers_id_seq" to "anon";
grant SELECT on sequence "public"."v5_student_answers_id_seq" to "authenticated";
grant UPDATE on sequence "public"."v5_student_answers_id_seq" to "authenticated";
grant USAGE on sequence "public"."v5_student_answers_id_seq" to "authenticated";
grant SELECT on sequence "public"."v5_student_answers_id_seq" to "service_role";
grant UPDATE on sequence "public"."v5_student_answers_id_seq" to "service_role";
grant USAGE on sequence "public"."v5_student_answers_id_seq" to "service_role";
grant INSERT on table "public"."v5_classes" to "anon";
grant SELECT on table "public"."v5_classes" to "anon";
grant UPDATE on table "public"."v5_classes" to "anon";
grant DELETE on table "public"."v5_classes" to "anon";
grant TRUNCATE on table "public"."v5_classes" to "anon";
grant REFERENCES on table "public"."v5_classes" to "anon";
grant TRIGGER on table "public"."v5_classes" to "anon";
grant MAINTAIN on table "public"."v5_classes" to "anon";
grant INSERT on table "public"."v5_classes" to "authenticated";
grant SELECT on table "public"."v5_classes" to "authenticated";
grant UPDATE on table "public"."v5_classes" to "authenticated";
grant DELETE on table "public"."v5_classes" to "authenticated";
grant TRUNCATE on table "public"."v5_classes" to "authenticated";
grant REFERENCES on table "public"."v5_classes" to "authenticated";
grant TRIGGER on table "public"."v5_classes" to "authenticated";
grant MAINTAIN on table "public"."v5_classes" to "authenticated";
grant INSERT on table "public"."v5_classes" to "service_role";
grant SELECT on table "public"."v5_classes" to "service_role";
grant UPDATE on table "public"."v5_classes" to "service_role";
grant DELETE on table "public"."v5_classes" to "service_role";
grant TRUNCATE on table "public"."v5_classes" to "service_role";
grant REFERENCES on table "public"."v5_classes" to "service_role";
grant TRIGGER on table "public"."v5_classes" to "service_role";
grant MAINTAIN on table "public"."v5_classes" to "service_role";
grant INSERT on table "public"."v5_subjects" to "anon";
grant SELECT on table "public"."v5_subjects" to "anon";
grant UPDATE on table "public"."v5_subjects" to "anon";
grant DELETE on table "public"."v5_subjects" to "anon";
grant TRUNCATE on table "public"."v5_subjects" to "anon";
grant REFERENCES on table "public"."v5_subjects" to "anon";
grant TRIGGER on table "public"."v5_subjects" to "anon";
grant MAINTAIN on table "public"."v5_subjects" to "anon";
grant INSERT on table "public"."v5_subjects" to "authenticated";
grant SELECT on table "public"."v5_subjects" to "authenticated";
grant UPDATE on table "public"."v5_subjects" to "authenticated";
grant DELETE on table "public"."v5_subjects" to "authenticated";
grant TRUNCATE on table "public"."v5_subjects" to "authenticated";
grant REFERENCES on table "public"."v5_subjects" to "authenticated";
grant TRIGGER on table "public"."v5_subjects" to "authenticated";
grant MAINTAIN on table "public"."v5_subjects" to "authenticated";
grant INSERT on table "public"."v5_subjects" to "service_role";
grant SELECT on table "public"."v5_subjects" to "service_role";
grant UPDATE on table "public"."v5_subjects" to "service_role";
grant DELETE on table "public"."v5_subjects" to "service_role";
grant TRUNCATE on table "public"."v5_subjects" to "service_role";
grant REFERENCES on table "public"."v5_subjects" to "service_role";
grant TRIGGER on table "public"."v5_subjects" to "service_role";
grant MAINTAIN on table "public"."v5_subjects" to "service_role";
grant INSERT on table "public"."v5_topics" to "anon";
grant SELECT on table "public"."v5_topics" to "anon";
grant UPDATE on table "public"."v5_topics" to "anon";
grant DELETE on table "public"."v5_topics" to "anon";
grant TRUNCATE on table "public"."v5_topics" to "anon";
grant REFERENCES on table "public"."v5_topics" to "anon";
grant TRIGGER on table "public"."v5_topics" to "anon";
grant MAINTAIN on table "public"."v5_topics" to "anon";
grant INSERT on table "public"."v5_topics" to "authenticated";
grant SELECT on table "public"."v5_topics" to "authenticated";
grant UPDATE on table "public"."v5_topics" to "authenticated";
grant DELETE on table "public"."v5_topics" to "authenticated";
grant TRUNCATE on table "public"."v5_topics" to "authenticated";
grant REFERENCES on table "public"."v5_topics" to "authenticated";
grant TRIGGER on table "public"."v5_topics" to "authenticated";
grant MAINTAIN on table "public"."v5_topics" to "authenticated";
grant INSERT on table "public"."v5_topics" to "service_role";
grant SELECT on table "public"."v5_topics" to "service_role";
grant UPDATE on table "public"."v5_topics" to "service_role";
grant DELETE on table "public"."v5_topics" to "service_role";
grant TRUNCATE on table "public"."v5_topics" to "service_role";
grant REFERENCES on table "public"."v5_topics" to "service_role";
grant TRIGGER on table "public"."v5_topics" to "service_role";
grant MAINTAIN on table "public"."v5_topics" to "service_role";
grant INSERT on table "public"."v5_sources" to "anon";
grant SELECT on table "public"."v5_sources" to "anon";
grant UPDATE on table "public"."v5_sources" to "anon";
grant DELETE on table "public"."v5_sources" to "anon";
grant TRUNCATE on table "public"."v5_sources" to "anon";
grant REFERENCES on table "public"."v5_sources" to "anon";
grant TRIGGER on table "public"."v5_sources" to "anon";
grant MAINTAIN on table "public"."v5_sources" to "anon";
grant INSERT on table "public"."v5_sources" to "authenticated";
grant SELECT on table "public"."v5_sources" to "authenticated";
grant UPDATE on table "public"."v5_sources" to "authenticated";
grant DELETE on table "public"."v5_sources" to "authenticated";
grant TRUNCATE on table "public"."v5_sources" to "authenticated";
grant REFERENCES on table "public"."v5_sources" to "authenticated";
grant TRIGGER on table "public"."v5_sources" to "authenticated";
grant MAINTAIN on table "public"."v5_sources" to "authenticated";
grant INSERT on table "public"."v5_sources" to "service_role";
grant SELECT on table "public"."v5_sources" to "service_role";
grant UPDATE on table "public"."v5_sources" to "service_role";
grant DELETE on table "public"."v5_sources" to "service_role";
grant TRUNCATE on table "public"."v5_sources" to "service_role";
grant REFERENCES on table "public"."v5_sources" to "service_role";
grant TRIGGER on table "public"."v5_sources" to "service_role";
grant MAINTAIN on table "public"."v5_sources" to "service_role";
grant INSERT on table "public"."v5_exam_classes" to "anon";
grant SELECT on table "public"."v5_exam_classes" to "anon";
grant UPDATE on table "public"."v5_exam_classes" to "anon";
grant DELETE on table "public"."v5_exam_classes" to "anon";
grant TRUNCATE on table "public"."v5_exam_classes" to "anon";
grant REFERENCES on table "public"."v5_exam_classes" to "anon";
grant TRIGGER on table "public"."v5_exam_classes" to "anon";
grant MAINTAIN on table "public"."v5_exam_classes" to "anon";
grant INSERT on table "public"."v5_exam_classes" to "authenticated";
grant SELECT on table "public"."v5_exam_classes" to "authenticated";
grant UPDATE on table "public"."v5_exam_classes" to "authenticated";
grant DELETE on table "public"."v5_exam_classes" to "authenticated";
grant TRUNCATE on table "public"."v5_exam_classes" to "authenticated";
grant REFERENCES on table "public"."v5_exam_classes" to "authenticated";
grant TRIGGER on table "public"."v5_exam_classes" to "authenticated";
grant MAINTAIN on table "public"."v5_exam_classes" to "authenticated";
grant INSERT on table "public"."v5_exam_classes" to "service_role";
grant SELECT on table "public"."v5_exam_classes" to "service_role";
grant UPDATE on table "public"."v5_exam_classes" to "service_role";
grant DELETE on table "public"."v5_exam_classes" to "service_role";
grant TRUNCATE on table "public"."v5_exam_classes" to "service_role";
grant REFERENCES on table "public"."v5_exam_classes" to "service_role";
grant TRIGGER on table "public"."v5_exam_classes" to "service_role";
grant MAINTAIN on table "public"."v5_exam_classes" to "service_role";
grant SELECT on sequence "public"."subjects_id_seq" to "anon";
grant UPDATE on sequence "public"."subjects_id_seq" to "anon";
grant USAGE on sequence "public"."subjects_id_seq" to "anon";
grant SELECT on sequence "public"."subjects_id_seq" to "authenticated";
grant UPDATE on sequence "public"."subjects_id_seq" to "authenticated";
grant USAGE on sequence "public"."subjects_id_seq" to "authenticated";
grant SELECT on sequence "public"."subjects_id_seq" to "service_role";
grant UPDATE on sequence "public"."subjects_id_seq" to "service_role";
grant USAGE on sequence "public"."subjects_id_seq" to "service_role";
grant INSERT on table "public"."v5_question_sources" to "anon";
grant SELECT on table "public"."v5_question_sources" to "anon";
grant UPDATE on table "public"."v5_question_sources" to "anon";
grant DELETE on table "public"."v5_question_sources" to "anon";
grant TRUNCATE on table "public"."v5_question_sources" to "anon";
grant REFERENCES on table "public"."v5_question_sources" to "anon";
grant TRIGGER on table "public"."v5_question_sources" to "anon";
grant MAINTAIN on table "public"."v5_question_sources" to "anon";
grant INSERT on table "public"."v5_question_sources" to "authenticated";
grant SELECT on table "public"."v5_question_sources" to "authenticated";
grant UPDATE on table "public"."v5_question_sources" to "authenticated";
grant DELETE on table "public"."v5_question_sources" to "authenticated";
grant TRUNCATE on table "public"."v5_question_sources" to "authenticated";
grant REFERENCES on table "public"."v5_question_sources" to "authenticated";
grant TRIGGER on table "public"."v5_question_sources" to "authenticated";
grant MAINTAIN on table "public"."v5_question_sources" to "authenticated";
grant INSERT on table "public"."v5_question_sources" to "service_role";
grant SELECT on table "public"."v5_question_sources" to "service_role";
grant UPDATE on table "public"."v5_question_sources" to "service_role";
grant DELETE on table "public"."v5_question_sources" to "service_role";
grant TRUNCATE on table "public"."v5_question_sources" to "service_role";
grant REFERENCES on table "public"."v5_question_sources" to "service_role";
grant TRIGGER on table "public"."v5_question_sources" to "service_role";
grant MAINTAIN on table "public"."v5_question_sources" to "service_role";
grant SELECT on sequence "public"."topics_id_seq" to "anon";
grant UPDATE on sequence "public"."topics_id_seq" to "anon";
grant USAGE on sequence "public"."topics_id_seq" to "anon";
grant SELECT on sequence "public"."topics_id_seq" to "authenticated";
grant UPDATE on sequence "public"."topics_id_seq" to "authenticated";
grant USAGE on sequence "public"."topics_id_seq" to "authenticated";
grant SELECT on sequence "public"."topics_id_seq" to "service_role";
grant UPDATE on sequence "public"."topics_id_seq" to "service_role";
grant USAGE on sequence "public"."topics_id_seq" to "service_role";
grant INSERT on table "public"."v5_exam_link_view" to "anon";
grant SELECT on table "public"."v5_exam_link_view" to "anon";
grant UPDATE on table "public"."v5_exam_link_view" to "anon";
grant DELETE on table "public"."v5_exam_link_view" to "anon";
grant TRUNCATE on table "public"."v5_exam_link_view" to "anon";
grant REFERENCES on table "public"."v5_exam_link_view" to "anon";
grant TRIGGER on table "public"."v5_exam_link_view" to "anon";
grant MAINTAIN on table "public"."v5_exam_link_view" to "anon";
grant INSERT on table "public"."v5_exam_link_view" to "authenticated";
grant SELECT on table "public"."v5_exam_link_view" to "authenticated";
grant UPDATE on table "public"."v5_exam_link_view" to "authenticated";
grant DELETE on table "public"."v5_exam_link_view" to "authenticated";
grant TRUNCATE on table "public"."v5_exam_link_view" to "authenticated";
grant REFERENCES on table "public"."v5_exam_link_view" to "authenticated";
grant TRIGGER on table "public"."v5_exam_link_view" to "authenticated";
grant MAINTAIN on table "public"."v5_exam_link_view" to "authenticated";
grant INSERT on table "public"."v5_exam_link_view" to "service_role";
grant SELECT on table "public"."v5_exam_link_view" to "service_role";
grant UPDATE on table "public"."v5_exam_link_view" to "service_role";
grant DELETE on table "public"."v5_exam_link_view" to "service_role";
grant TRUNCATE on table "public"."v5_exam_link_view" to "service_role";
grant REFERENCES on table "public"."v5_exam_link_view" to "service_role";
grant TRIGGER on table "public"."v5_exam_link_view" to "service_role";
grant MAINTAIN on table "public"."v5_exam_link_view" to "service_role";
grant INSERT on table "public"."v5_question_bank" to "anon";
grant SELECT on table "public"."v5_question_bank" to "anon";
grant UPDATE on table "public"."v5_question_bank" to "anon";
grant DELETE on table "public"."v5_question_bank" to "anon";
grant TRUNCATE on table "public"."v5_question_bank" to "anon";
grant REFERENCES on table "public"."v5_question_bank" to "anon";
grant TRIGGER on table "public"."v5_question_bank" to "anon";
grant MAINTAIN on table "public"."v5_question_bank" to "anon";
grant INSERT on table "public"."v5_question_bank" to "authenticated";
grant SELECT on table "public"."v5_question_bank" to "authenticated";
grant UPDATE on table "public"."v5_question_bank" to "authenticated";
grant DELETE on table "public"."v5_question_bank" to "authenticated";
grant TRUNCATE on table "public"."v5_question_bank" to "authenticated";
grant REFERENCES on table "public"."v5_question_bank" to "authenticated";
grant TRIGGER on table "public"."v5_question_bank" to "authenticated";
grant MAINTAIN on table "public"."v5_question_bank" to "authenticated";
grant INSERT on table "public"."v5_question_bank" to "service_role";
grant SELECT on table "public"."v5_question_bank" to "service_role";
grant UPDATE on table "public"."v5_question_bank" to "service_role";
grant DELETE on table "public"."v5_question_bank" to "service_role";
grant TRUNCATE on table "public"."v5_question_bank" to "service_role";
grant REFERENCES on table "public"."v5_question_bank" to "service_role";
grant TRIGGER on table "public"."v5_question_bank" to "service_role";
grant MAINTAIN on table "public"."v5_question_bank" to "service_role";
grant SELECT on sequence "public"."questions_id_seq" to "anon";
grant UPDATE on sequence "public"."questions_id_seq" to "anon";
grant USAGE on sequence "public"."questions_id_seq" to "anon";
grant SELECT on sequence "public"."questions_id_seq" to "authenticated";
grant UPDATE on sequence "public"."questions_id_seq" to "authenticated";
grant USAGE on sequence "public"."questions_id_seq" to "authenticated";
grant SELECT on sequence "public"."questions_id_seq" to "service_role";
grant UPDATE on sequence "public"."questions_id_seq" to "service_role";
grant USAGE on sequence "public"."questions_id_seq" to "service_role";
grant INSERT on table "public"."v5_question_bank_options" to "anon";
grant SELECT on table "public"."v5_question_bank_options" to "anon";
grant UPDATE on table "public"."v5_question_bank_options" to "anon";
grant DELETE on table "public"."v5_question_bank_options" to "anon";
grant TRUNCATE on table "public"."v5_question_bank_options" to "anon";
grant REFERENCES on table "public"."v5_question_bank_options" to "anon";
grant TRIGGER on table "public"."v5_question_bank_options" to "anon";
grant MAINTAIN on table "public"."v5_question_bank_options" to "anon";
grant INSERT on table "public"."v5_question_bank_options" to "authenticated";
grant SELECT on table "public"."v5_question_bank_options" to "authenticated";
grant UPDATE on table "public"."v5_question_bank_options" to "authenticated";
grant DELETE on table "public"."v5_question_bank_options" to "authenticated";
grant TRUNCATE on table "public"."v5_question_bank_options" to "authenticated";
grant REFERENCES on table "public"."v5_question_bank_options" to "authenticated";
grant TRIGGER on table "public"."v5_question_bank_options" to "authenticated";
grant MAINTAIN on table "public"."v5_question_bank_options" to "authenticated";
grant INSERT on table "public"."v5_question_bank_options" to "service_role";
grant SELECT on table "public"."v5_question_bank_options" to "service_role";
grant UPDATE on table "public"."v5_question_bank_options" to "service_role";
grant DELETE on table "public"."v5_question_bank_options" to "service_role";
grant TRUNCATE on table "public"."v5_question_bank_options" to "service_role";
grant REFERENCES on table "public"."v5_question_bank_options" to "service_role";
grant TRIGGER on table "public"."v5_question_bank_options" to "service_role";
grant MAINTAIN on table "public"."v5_question_bank_options" to "service_role";
grant SELECT on sequence "public"."student_learning_summary_id_seq" to "anon";
grant UPDATE on sequence "public"."student_learning_summary_id_seq" to "anon";
grant USAGE on sequence "public"."student_learning_summary_id_seq" to "anon";
grant SELECT on sequence "public"."student_learning_summary_id_seq" to "authenticated";
grant UPDATE on sequence "public"."student_learning_summary_id_seq" to "authenticated";
grant USAGE on sequence "public"."student_learning_summary_id_seq" to "authenticated";
grant SELECT on sequence "public"."student_learning_summary_id_seq" to "service_role";
grant UPDATE on sequence "public"."student_learning_summary_id_seq" to "service_role";
grant USAGE on sequence "public"."student_learning_summary_id_seq" to "service_role";
grant SELECT on table "public"."v5_student_answers" to "anon";
grant DELETE on table "public"."v5_student_answers" to "anon";
grant TRUNCATE on table "public"."v5_student_answers" to "anon";
grant REFERENCES on table "public"."v5_student_answers" to "anon";
grant TRIGGER on table "public"."v5_student_answers" to "anon";
grant MAINTAIN on table "public"."v5_student_answers" to "anon";
grant INSERT on table "public"."v5_student_answers" to "authenticated";
grant SELECT on table "public"."v5_student_answers" to "authenticated";
grant UPDATE on table "public"."v5_student_answers" to "authenticated";
grant DELETE on table "public"."v5_student_answers" to "authenticated";
grant TRUNCATE on table "public"."v5_student_answers" to "authenticated";
grant REFERENCES on table "public"."v5_student_answers" to "authenticated";
grant TRIGGER on table "public"."v5_student_answers" to "authenticated";
grant MAINTAIN on table "public"."v5_student_answers" to "authenticated";
grant INSERT on table "public"."v5_student_answers" to "service_role";
grant SELECT on table "public"."v5_student_answers" to "service_role";
grant UPDATE on table "public"."v5_student_answers" to "service_role";
grant DELETE on table "public"."v5_student_answers" to "service_role";
grant TRUNCATE on table "public"."v5_student_answers" to "service_role";
grant REFERENCES on table "public"."v5_student_answers" to "service_role";
grant TRIGGER on table "public"."v5_student_answers" to "service_role";
grant MAINTAIN on table "public"."v5_student_answers" to "service_role";
grant INSERT on table "public"."v5_exams" to "anon";
grant UPDATE on table "public"."v5_exams" to "anon";
grant DELETE on table "public"."v5_exams" to "anon";
grant TRUNCATE on table "public"."v5_exams" to "anon";
grant REFERENCES on table "public"."v5_exams" to "anon";
grant TRIGGER on table "public"."v5_exams" to "anon";
grant MAINTAIN on table "public"."v5_exams" to "anon";
grant INSERT on table "public"."v5_exams" to "authenticated";
grant SELECT on table "public"."v5_exams" to "authenticated";
grant UPDATE on table "public"."v5_exams" to "authenticated";
grant DELETE on table "public"."v5_exams" to "authenticated";
grant TRUNCATE on table "public"."v5_exams" to "authenticated";
grant REFERENCES on table "public"."v5_exams" to "authenticated";
grant TRIGGER on table "public"."v5_exams" to "authenticated";
grant MAINTAIN on table "public"."v5_exams" to "authenticated";
grant INSERT on table "public"."v5_exams" to "service_role";
grant SELECT on table "public"."v5_exams" to "service_role";
grant UPDATE on table "public"."v5_exams" to "service_role";
grant DELETE on table "public"."v5_exams" to "service_role";
grant TRUNCATE on table "public"."v5_exams" to "service_role";
grant REFERENCES on table "public"."v5_exams" to "service_role";
grant TRIGGER on table "public"."v5_exams" to "service_role";
grant MAINTAIN on table "public"."v5_exams" to "service_role";
grant SELECT on sequence "public"."exams_id_seq" to "anon";
grant UPDATE on sequence "public"."exams_id_seq" to "anon";
grant USAGE on sequence "public"."exams_id_seq" to "anon";
grant SELECT on sequence "public"."exams_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exams_id_seq" to "authenticated";
grant USAGE on sequence "public"."exams_id_seq" to "authenticated";
grant SELECT on sequence "public"."exams_id_seq" to "service_role";
grant UPDATE on sequence "public"."exams_id_seq" to "service_role";
grant USAGE on sequence "public"."exams_id_seq" to "service_role";
grant INSERT on table "public"."v5_attempts" to "anon";
grant UPDATE on table "public"."v5_attempts" to "anon";
grant DELETE on table "public"."v5_attempts" to "anon";
grant TRUNCATE on table "public"."v5_attempts" to "anon";
grant REFERENCES on table "public"."v5_attempts" to "anon";
grant TRIGGER on table "public"."v5_attempts" to "anon";
grant MAINTAIN on table "public"."v5_attempts" to "anon";
grant INSERT on table "public"."v5_attempts" to "authenticated";
grant SELECT on table "public"."v5_attempts" to "authenticated";
grant UPDATE on table "public"."v5_attempts" to "authenticated";
grant DELETE on table "public"."v5_attempts" to "authenticated";
grant TRUNCATE on table "public"."v5_attempts" to "authenticated";
grant REFERENCES on table "public"."v5_attempts" to "authenticated";
grant TRIGGER on table "public"."v5_attempts" to "authenticated";
grant MAINTAIN on table "public"."v5_attempts" to "authenticated";
grant INSERT on table "public"."v5_attempts" to "service_role";
grant SELECT on table "public"."v5_attempts" to "service_role";
grant UPDATE on table "public"."v5_attempts" to "service_role";
grant DELETE on table "public"."v5_attempts" to "service_role";
grant TRUNCATE on table "public"."v5_attempts" to "service_role";
grant REFERENCES on table "public"."v5_attempts" to "service_role";
grant TRIGGER on table "public"."v5_attempts" to "service_role";
grant MAINTAIN on table "public"."v5_attempts" to "service_role";
grant INSERT on table "public"."v5_students" to "anon";
grant UPDATE on table "public"."v5_students" to "anon";
grant DELETE on table "public"."v5_students" to "anon";
grant TRUNCATE on table "public"."v5_students" to "anon";
grant REFERENCES on table "public"."v5_students" to "anon";
grant TRIGGER on table "public"."v5_students" to "anon";
grant MAINTAIN on table "public"."v5_students" to "anon";
grant INSERT on table "public"."v5_students" to "authenticated";
grant SELECT on table "public"."v5_students" to "authenticated";
grant UPDATE on table "public"."v5_students" to "authenticated";
grant DELETE on table "public"."v5_students" to "authenticated";
grant TRUNCATE on table "public"."v5_students" to "authenticated";
grant REFERENCES on table "public"."v5_students" to "authenticated";
grant TRIGGER on table "public"."v5_students" to "authenticated";
grant MAINTAIN on table "public"."v5_students" to "authenticated";
grant INSERT on table "public"."v5_students" to "service_role";
grant SELECT on table "public"."v5_students" to "service_role";
grant UPDATE on table "public"."v5_students" to "service_role";
grant DELETE on table "public"."v5_students" to "service_role";
grant TRUNCATE on table "public"."v5_students" to "service_role";
grant REFERENCES on table "public"."v5_students" to "service_role";
grant TRIGGER on table "public"."v5_students" to "service_role";
grant MAINTAIN on table "public"."v5_students" to "service_role";
grant INSERT on table "public"."v5_questions" to "anon";
grant UPDATE on table "public"."v5_questions" to "anon";
grant DELETE on table "public"."v5_questions" to "anon";
grant TRUNCATE on table "public"."v5_questions" to "anon";
grant REFERENCES on table "public"."v5_questions" to "anon";
grant TRIGGER on table "public"."v5_questions" to "anon";
grant MAINTAIN on table "public"."v5_questions" to "anon";
grant INSERT on table "public"."v5_questions" to "authenticated";
grant SELECT on table "public"."v5_questions" to "authenticated";
grant UPDATE on table "public"."v5_questions" to "authenticated";
grant DELETE on table "public"."v5_questions" to "authenticated";
grant TRUNCATE on table "public"."v5_questions" to "authenticated";
grant REFERENCES on table "public"."v5_questions" to "authenticated";
grant TRIGGER on table "public"."v5_questions" to "authenticated";
grant MAINTAIN on table "public"."v5_questions" to "authenticated";
grant INSERT on table "public"."v5_questions" to "service_role";
grant SELECT on table "public"."v5_questions" to "service_role";
grant UPDATE on table "public"."v5_questions" to "service_role";
grant DELETE on table "public"."v5_questions" to "service_role";
grant TRUNCATE on table "public"."v5_questions" to "service_role";
grant REFERENCES on table "public"."v5_questions" to "service_role";
grant TRIGGER on table "public"."v5_questions" to "service_role";
grant MAINTAIN on table "public"."v5_questions" to "service_role";
grant INSERT on table "public"."v5_question_options" to "anon";
grant UPDATE on table "public"."v5_question_options" to "anon";
grant DELETE on table "public"."v5_question_options" to "anon";
grant TRUNCATE on table "public"."v5_question_options" to "anon";
grant REFERENCES on table "public"."v5_question_options" to "anon";
grant TRIGGER on table "public"."v5_question_options" to "anon";
grant MAINTAIN on table "public"."v5_question_options" to "anon";
grant INSERT on table "public"."v5_question_options" to "authenticated";
grant SELECT on table "public"."v5_question_options" to "authenticated";
grant UPDATE on table "public"."v5_question_options" to "authenticated";
grant DELETE on table "public"."v5_question_options" to "authenticated";
grant TRUNCATE on table "public"."v5_question_options" to "authenticated";
grant REFERENCES on table "public"."v5_question_options" to "authenticated";
grant TRIGGER on table "public"."v5_question_options" to "authenticated";
grant MAINTAIN on table "public"."v5_question_options" to "authenticated";
grant INSERT on table "public"."v5_question_options" to "service_role";
grant SELECT on table "public"."v5_question_options" to "service_role";
grant UPDATE on table "public"."v5_question_options" to "service_role";
grant DELETE on table "public"."v5_question_options" to "service_role";
grant TRUNCATE on table "public"."v5_question_options" to "service_role";
grant REFERENCES on table "public"."v5_question_options" to "service_role";
grant TRIGGER on table "public"."v5_question_options" to "service_role";
grant MAINTAIN on table "public"."v5_question_options" to "service_role";
grant INSERT on table "public"."v5_exam_questions" to "anon";
grant UPDATE on table "public"."v5_exam_questions" to "anon";
grant DELETE on table "public"."v5_exam_questions" to "anon";
grant TRUNCATE on table "public"."v5_exam_questions" to "anon";
grant REFERENCES on table "public"."v5_exam_questions" to "anon";
grant TRIGGER on table "public"."v5_exam_questions" to "anon";
grant MAINTAIN on table "public"."v5_exam_questions" to "anon";
grant INSERT on table "public"."v5_exam_questions" to "authenticated";
grant SELECT on table "public"."v5_exam_questions" to "authenticated";
grant UPDATE on table "public"."v5_exam_questions" to "authenticated";
grant DELETE on table "public"."v5_exam_questions" to "authenticated";
grant TRUNCATE on table "public"."v5_exam_questions" to "authenticated";
grant REFERENCES on table "public"."v5_exam_questions" to "authenticated";
grant TRIGGER on table "public"."v5_exam_questions" to "authenticated";
grant MAINTAIN on table "public"."v5_exam_questions" to "authenticated";
grant INSERT on table "public"."v5_exam_questions" to "service_role";
grant SELECT on table "public"."v5_exam_questions" to "service_role";
grant UPDATE on table "public"."v5_exam_questions" to "service_role";
grant DELETE on table "public"."v5_exam_questions" to "service_role";
grant TRUNCATE on table "public"."v5_exam_questions" to "service_role";
grant REFERENCES on table "public"."v5_exam_questions" to "service_role";
grant TRIGGER on table "public"."v5_exam_questions" to "service_role";
grant MAINTAIN on table "public"."v5_exam_questions" to "service_role";
grant INSERT on table "public"."subjects" to "anon";
grant SELECT on table "public"."subjects" to "anon";
grant UPDATE on table "public"."subjects" to "anon";
grant DELETE on table "public"."subjects" to "anon";
grant TRUNCATE on table "public"."subjects" to "anon";
grant REFERENCES on table "public"."subjects" to "anon";
grant TRIGGER on table "public"."subjects" to "anon";
grant MAINTAIN on table "public"."subjects" to "anon";
grant INSERT on table "public"."subjects" to "authenticated";
grant SELECT on table "public"."subjects" to "authenticated";
grant UPDATE on table "public"."subjects" to "authenticated";
grant DELETE on table "public"."subjects" to "authenticated";
grant TRUNCATE on table "public"."subjects" to "authenticated";
grant REFERENCES on table "public"."subjects" to "authenticated";
grant TRIGGER on table "public"."subjects" to "authenticated";
grant MAINTAIN on table "public"."subjects" to "authenticated";
grant INSERT on table "public"."subjects" to "service_role";
grant SELECT on table "public"."subjects" to "service_role";
grant UPDATE on table "public"."subjects" to "service_role";
grant DELETE on table "public"."subjects" to "service_role";
grant TRUNCATE on table "public"."subjects" to "service_role";
grant REFERENCES on table "public"."subjects" to "service_role";
grant TRIGGER on table "public"."subjects" to "service_role";
grant MAINTAIN on table "public"."subjects" to "service_role";
grant INSERT on table "public"."topics" to "anon";
grant SELECT on table "public"."topics" to "anon";
grant UPDATE on table "public"."topics" to "anon";
grant DELETE on table "public"."topics" to "anon";
grant TRUNCATE on table "public"."topics" to "anon";
grant REFERENCES on table "public"."topics" to "anon";
grant TRIGGER on table "public"."topics" to "anon";
grant MAINTAIN on table "public"."topics" to "anon";
grant INSERT on table "public"."topics" to "authenticated";
grant SELECT on table "public"."topics" to "authenticated";
grant UPDATE on table "public"."topics" to "authenticated";
grant DELETE on table "public"."topics" to "authenticated";
grant TRUNCATE on table "public"."topics" to "authenticated";
grant REFERENCES on table "public"."topics" to "authenticated";
grant TRIGGER on table "public"."topics" to "authenticated";
grant MAINTAIN on table "public"."topics" to "authenticated";
grant INSERT on table "public"."topics" to "service_role";
grant SELECT on table "public"."topics" to "service_role";
grant UPDATE on table "public"."topics" to "service_role";
grant DELETE on table "public"."topics" to "service_role";
grant TRUNCATE on table "public"."topics" to "service_role";
grant REFERENCES on table "public"."topics" to "service_role";
grant TRIGGER on table "public"."topics" to "service_role";
grant MAINTAIN on table "public"."topics" to "service_role";
grant INSERT on table "public"."admin_profiles" to "anon";
grant SELECT on table "public"."admin_profiles" to "anon";
grant UPDATE on table "public"."admin_profiles" to "anon";
grant DELETE on table "public"."admin_profiles" to "anon";
grant TRUNCATE on table "public"."admin_profiles" to "anon";
grant REFERENCES on table "public"."admin_profiles" to "anon";
grant TRIGGER on table "public"."admin_profiles" to "anon";
grant MAINTAIN on table "public"."admin_profiles" to "anon";
grant INSERT on table "public"."admin_profiles" to "authenticated";
grant SELECT on table "public"."admin_profiles" to "authenticated";
grant UPDATE on table "public"."admin_profiles" to "authenticated";
grant DELETE on table "public"."admin_profiles" to "authenticated";
grant TRUNCATE on table "public"."admin_profiles" to "authenticated";
grant REFERENCES on table "public"."admin_profiles" to "authenticated";
grant TRIGGER on table "public"."admin_profiles" to "authenticated";
grant MAINTAIN on table "public"."admin_profiles" to "authenticated";
grant INSERT on table "public"."admin_profiles" to "service_role";
grant SELECT on table "public"."admin_profiles" to "service_role";
grant UPDATE on table "public"."admin_profiles" to "service_role";
grant DELETE on table "public"."admin_profiles" to "service_role";
grant TRUNCATE on table "public"."admin_profiles" to "service_role";
grant REFERENCES on table "public"."admin_profiles" to "service_role";
grant TRIGGER on table "public"."admin_profiles" to "service_role";
grant MAINTAIN on table "public"."admin_profiles" to "service_role";
grant INSERT on table "public"."questions" to "anon";
grant SELECT on table "public"."questions" to "anon";
grant UPDATE on table "public"."questions" to "anon";
grant DELETE on table "public"."questions" to "anon";
grant TRUNCATE on table "public"."questions" to "anon";
grant REFERENCES on table "public"."questions" to "anon";
grant TRIGGER on table "public"."questions" to "anon";
grant MAINTAIN on table "public"."questions" to "anon";
grant INSERT on table "public"."questions" to "authenticated";
grant SELECT on table "public"."questions" to "authenticated";
grant UPDATE on table "public"."questions" to "authenticated";
grant DELETE on table "public"."questions" to "authenticated";
grant TRUNCATE on table "public"."questions" to "authenticated";
grant REFERENCES on table "public"."questions" to "authenticated";
grant TRIGGER on table "public"."questions" to "authenticated";
grant MAINTAIN on table "public"."questions" to "authenticated";
grant INSERT on table "public"."questions" to "service_role";
grant SELECT on table "public"."questions" to "service_role";
grant UPDATE on table "public"."questions" to "service_role";
grant DELETE on table "public"."questions" to "service_role";
grant TRUNCATE on table "public"."questions" to "service_role";
grant REFERENCES on table "public"."questions" to "service_role";
grant TRIGGER on table "public"."questions" to "service_role";
grant MAINTAIN on table "public"."questions" to "service_role";
grant INSERT on table "public"."exams" to "anon";
grant SELECT on table "public"."exams" to "anon";
grant UPDATE on table "public"."exams" to "anon";
grant DELETE on table "public"."exams" to "anon";
grant TRUNCATE on table "public"."exams" to "anon";
grant REFERENCES on table "public"."exams" to "anon";
grant TRIGGER on table "public"."exams" to "anon";
grant MAINTAIN on table "public"."exams" to "anon";
grant INSERT on table "public"."exams" to "authenticated";
grant SELECT on table "public"."exams" to "authenticated";
grant UPDATE on table "public"."exams" to "authenticated";
grant DELETE on table "public"."exams" to "authenticated";
grant TRUNCATE on table "public"."exams" to "authenticated";
grant REFERENCES on table "public"."exams" to "authenticated";
grant TRIGGER on table "public"."exams" to "authenticated";
grant MAINTAIN on table "public"."exams" to "authenticated";
grant INSERT on table "public"."exams" to "service_role";
grant SELECT on table "public"."exams" to "service_role";
grant UPDATE on table "public"."exams" to "service_role";
grant DELETE on table "public"."exams" to "service_role";
grant TRUNCATE on table "public"."exams" to "service_role";
grant REFERENCES on table "public"."exams" to "service_role";
grant TRIGGER on table "public"."exams" to "service_role";
grant MAINTAIN on table "public"."exams" to "service_role";
grant INSERT on table "public"."question_bank_view" to "anon";
grant SELECT on table "public"."question_bank_view" to "anon";
grant UPDATE on table "public"."question_bank_view" to "anon";
grant DELETE on table "public"."question_bank_view" to "anon";
grant TRUNCATE on table "public"."question_bank_view" to "anon";
grant REFERENCES on table "public"."question_bank_view" to "anon";
grant TRIGGER on table "public"."question_bank_view" to "anon";
grant MAINTAIN on table "public"."question_bank_view" to "anon";
grant INSERT on table "public"."question_bank_view" to "authenticated";
grant SELECT on table "public"."question_bank_view" to "authenticated";
grant UPDATE on table "public"."question_bank_view" to "authenticated";
grant DELETE on table "public"."question_bank_view" to "authenticated";
grant TRUNCATE on table "public"."question_bank_view" to "authenticated";
grant REFERENCES on table "public"."question_bank_view" to "authenticated";
grant TRIGGER on table "public"."question_bank_view" to "authenticated";
grant MAINTAIN on table "public"."question_bank_view" to "authenticated";
grant INSERT on table "public"."question_bank_view" to "service_role";
grant SELECT on table "public"."question_bank_view" to "service_role";
grant UPDATE on table "public"."question_bank_view" to "service_role";
grant DELETE on table "public"."question_bank_view" to "service_role";
grant TRUNCATE on table "public"."question_bank_view" to "service_role";
grant REFERENCES on table "public"."question_bank_view" to "service_role";
grant TRIGGER on table "public"."question_bank_view" to "service_role";
grant MAINTAIN on table "public"."question_bank_view" to "service_role";
grant SELECT on sequence "public"."exam_questions_id_seq" to "anon";
grant UPDATE on sequence "public"."exam_questions_id_seq" to "anon";
grant USAGE on sequence "public"."exam_questions_id_seq" to "anon";
grant SELECT on sequence "public"."exam_questions_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exam_questions_id_seq" to "authenticated";
grant USAGE on sequence "public"."exam_questions_id_seq" to "authenticated";
grant SELECT on sequence "public"."exam_questions_id_seq" to "service_role";
grant UPDATE on sequence "public"."exam_questions_id_seq" to "service_role";
grant USAGE on sequence "public"."exam_questions_id_seq" to "service_role";
grant INSERT on table "public"."exam_student_ranking" to "anon";
grant SELECT on table "public"."exam_student_ranking" to "anon";
grant UPDATE on table "public"."exam_student_ranking" to "anon";
grant DELETE on table "public"."exam_student_ranking" to "anon";
grant TRUNCATE on table "public"."exam_student_ranking" to "anon";
grant REFERENCES on table "public"."exam_student_ranking" to "anon";
grant TRIGGER on table "public"."exam_student_ranking" to "anon";
grant MAINTAIN on table "public"."exam_student_ranking" to "anon";
grant INSERT on table "public"."exam_student_ranking" to "authenticated";
grant SELECT on table "public"."exam_student_ranking" to "authenticated";
grant UPDATE on table "public"."exam_student_ranking" to "authenticated";
grant DELETE on table "public"."exam_student_ranking" to "authenticated";
grant TRUNCATE on table "public"."exam_student_ranking" to "authenticated";
grant REFERENCES on table "public"."exam_student_ranking" to "authenticated";
grant TRIGGER on table "public"."exam_student_ranking" to "authenticated";
grant MAINTAIN on table "public"."exam_student_ranking" to "authenticated";
grant INSERT on table "public"."exam_student_ranking" to "service_role";
grant SELECT on table "public"."exam_student_ranking" to "service_role";
grant UPDATE on table "public"."exam_student_ranking" to "service_role";
grant DELETE on table "public"."exam_student_ranking" to "service_role";
grant TRUNCATE on table "public"."exam_student_ranking" to "service_role";
grant REFERENCES on table "public"."exam_student_ranking" to "service_role";
grant TRIGGER on table "public"."exam_student_ranking" to "service_role";
grant MAINTAIN on table "public"."exam_student_ranking" to "service_role";
grant INSERT on table "public"."exam_analytics_summary" to "anon";
grant SELECT on table "public"."exam_analytics_summary" to "anon";
grant UPDATE on table "public"."exam_analytics_summary" to "anon";
grant DELETE on table "public"."exam_analytics_summary" to "anon";
grant TRUNCATE on table "public"."exam_analytics_summary" to "anon";
grant REFERENCES on table "public"."exam_analytics_summary" to "anon";
grant TRIGGER on table "public"."exam_analytics_summary" to "anon";
grant MAINTAIN on table "public"."exam_analytics_summary" to "anon";
grant INSERT on table "public"."exam_analytics_summary" to "authenticated";
grant SELECT on table "public"."exam_analytics_summary" to "authenticated";
grant UPDATE on table "public"."exam_analytics_summary" to "authenticated";
grant DELETE on table "public"."exam_analytics_summary" to "authenticated";
grant TRUNCATE on table "public"."exam_analytics_summary" to "authenticated";
grant REFERENCES on table "public"."exam_analytics_summary" to "authenticated";
grant TRIGGER on table "public"."exam_analytics_summary" to "authenticated";
grant MAINTAIN on table "public"."exam_analytics_summary" to "authenticated";
grant INSERT on table "public"."exam_analytics_summary" to "service_role";
grant SELECT on table "public"."exam_analytics_summary" to "service_role";
grant UPDATE on table "public"."exam_analytics_summary" to "service_role";
grant DELETE on table "public"."exam_analytics_summary" to "service_role";
grant TRUNCATE on table "public"."exam_analytics_summary" to "service_role";
grant REFERENCES on table "public"."exam_analytics_summary" to "service_role";
grant TRIGGER on table "public"."exam_analytics_summary" to "service_role";
grant MAINTAIN on table "public"."exam_analytics_summary" to "service_role";
grant INSERT on table "public"."exam_latest_results" to "anon";
grant SELECT on table "public"."exam_latest_results" to "anon";
grant UPDATE on table "public"."exam_latest_results" to "anon";
grant DELETE on table "public"."exam_latest_results" to "anon";
grant TRUNCATE on table "public"."exam_latest_results" to "anon";
grant REFERENCES on table "public"."exam_latest_results" to "anon";
grant TRIGGER on table "public"."exam_latest_results" to "anon";
grant MAINTAIN on table "public"."exam_latest_results" to "anon";
grant INSERT on table "public"."exam_latest_results" to "authenticated";
grant SELECT on table "public"."exam_latest_results" to "authenticated";
grant UPDATE on table "public"."exam_latest_results" to "authenticated";
grant DELETE on table "public"."exam_latest_results" to "authenticated";
grant TRUNCATE on table "public"."exam_latest_results" to "authenticated";
grant REFERENCES on table "public"."exam_latest_results" to "authenticated";
grant TRIGGER on table "public"."exam_latest_results" to "authenticated";
grant MAINTAIN on table "public"."exam_latest_results" to "authenticated";
grant INSERT on table "public"."exam_latest_results" to "service_role";
grant SELECT on table "public"."exam_latest_results" to "service_role";
grant UPDATE on table "public"."exam_latest_results" to "service_role";
grant DELETE on table "public"."exam_latest_results" to "service_role";
grant TRUNCATE on table "public"."exam_latest_results" to "service_role";
grant REFERENCES on table "public"."exam_latest_results" to "service_role";
grant TRIGGER on table "public"."exam_latest_results" to "service_role";
grant MAINTAIN on table "public"."exam_latest_results" to "service_role";
grant SELECT on sequence "public"."exam_links_id_seq" to "anon";
grant UPDATE on sequence "public"."exam_links_id_seq" to "anon";
grant USAGE on sequence "public"."exam_links_id_seq" to "anon";
grant SELECT on sequence "public"."exam_links_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exam_links_id_seq" to "authenticated";
grant USAGE on sequence "public"."exam_links_id_seq" to "authenticated";
grant SELECT on sequence "public"."exam_links_id_seq" to "service_role";
grant UPDATE on sequence "public"."exam_links_id_seq" to "service_role";
grant USAGE on sequence "public"."exam_links_id_seq" to "service_role";
grant INSERT on table "public"."exam_questions" to "anon";
grant SELECT on table "public"."exam_questions" to "anon";
grant UPDATE on table "public"."exam_questions" to "anon";
grant DELETE on table "public"."exam_questions" to "anon";
grant TRUNCATE on table "public"."exam_questions" to "anon";
grant REFERENCES on table "public"."exam_questions" to "anon";
grant TRIGGER on table "public"."exam_questions" to "anon";
grant MAINTAIN on table "public"."exam_questions" to "anon";
grant INSERT on table "public"."exam_questions" to "authenticated";
grant SELECT on table "public"."exam_questions" to "authenticated";
grant UPDATE on table "public"."exam_questions" to "authenticated";
grant DELETE on table "public"."exam_questions" to "authenticated";
grant TRUNCATE on table "public"."exam_questions" to "authenticated";
grant REFERENCES on table "public"."exam_questions" to "authenticated";
grant TRIGGER on table "public"."exam_questions" to "authenticated";
grant MAINTAIN on table "public"."exam_questions" to "authenticated";
grant INSERT on table "public"."exam_questions" to "service_role";
grant SELECT on table "public"."exam_questions" to "service_role";
grant UPDATE on table "public"."exam_questions" to "service_role";
grant DELETE on table "public"."exam_questions" to "service_role";
grant TRUNCATE on table "public"."exam_questions" to "service_role";
grant REFERENCES on table "public"."exam_questions" to "service_role";
grant TRIGGER on table "public"."exam_questions" to "service_role";
grant MAINTAIN on table "public"."exam_questions" to "service_role";
grant INSERT on table "public"."exam_links" to "anon";
grant SELECT on table "public"."exam_links" to "anon";
grant UPDATE on table "public"."exam_links" to "anon";
grant DELETE on table "public"."exam_links" to "anon";
grant TRUNCATE on table "public"."exam_links" to "anon";
grant REFERENCES on table "public"."exam_links" to "anon";
grant TRIGGER on table "public"."exam_links" to "anon";
grant MAINTAIN on table "public"."exam_links" to "anon";
grant INSERT on table "public"."exam_links" to "authenticated";
grant SELECT on table "public"."exam_links" to "authenticated";
grant UPDATE on table "public"."exam_links" to "authenticated";
grant DELETE on table "public"."exam_links" to "authenticated";
grant TRUNCATE on table "public"."exam_links" to "authenticated";
grant REFERENCES on table "public"."exam_links" to "authenticated";
grant TRIGGER on table "public"."exam_links" to "authenticated";
grant MAINTAIN on table "public"."exam_links" to "authenticated";
grant INSERT on table "public"."exam_links" to "service_role";
grant SELECT on table "public"."exam_links" to "service_role";
grant UPDATE on table "public"."exam_links" to "service_role";
grant DELETE on table "public"."exam_links" to "service_role";
grant TRUNCATE on table "public"."exam_links" to "service_role";
grant REFERENCES on table "public"."exam_links" to "service_role";
grant TRIGGER on table "public"."exam_links" to "service_role";
grant MAINTAIN on table "public"."exam_links" to "service_role";
grant INSERT on table "public"."exam_results" to "anon";
grant SELECT on table "public"."exam_results" to "anon";
grant UPDATE on table "public"."exam_results" to "anon";
grant DELETE on table "public"."exam_results" to "anon";
grant TRUNCATE on table "public"."exam_results" to "anon";
grant REFERENCES on table "public"."exam_results" to "anon";
grant TRIGGER on table "public"."exam_results" to "anon";
grant MAINTAIN on table "public"."exam_results" to "anon";
grant INSERT on table "public"."exam_results" to "authenticated";
grant SELECT on table "public"."exam_results" to "authenticated";
grant UPDATE on table "public"."exam_results" to "authenticated";
grant DELETE on table "public"."exam_results" to "authenticated";
grant TRUNCATE on table "public"."exam_results" to "authenticated";
grant REFERENCES on table "public"."exam_results" to "authenticated";
grant TRIGGER on table "public"."exam_results" to "authenticated";
grant MAINTAIN on table "public"."exam_results" to "authenticated";
grant INSERT on table "public"."exam_results" to "service_role";
grant SELECT on table "public"."exam_results" to "service_role";
grant UPDATE on table "public"."exam_results" to "service_role";
grant DELETE on table "public"."exam_results" to "service_role";
grant TRUNCATE on table "public"."exam_results" to "service_role";
grant REFERENCES on table "public"."exam_results" to "service_role";
grant TRIGGER on table "public"."exam_results" to "service_role";
grant MAINTAIN on table "public"."exam_results" to "service_role";
grant SELECT on sequence "public"."exam_attempts_id_seq" to "anon";
grant UPDATE on sequence "public"."exam_attempts_id_seq" to "anon";
grant USAGE on sequence "public"."exam_attempts_id_seq" to "anon";
grant SELECT on sequence "public"."exam_attempts_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exam_attempts_id_seq" to "authenticated";
grant USAGE on sequence "public"."exam_attempts_id_seq" to "authenticated";
grant SELECT on sequence "public"."exam_attempts_id_seq" to "service_role";
grant UPDATE on sequence "public"."exam_attempts_id_seq" to "service_role";
grant USAGE on sequence "public"."exam_attempts_id_seq" to "service_role";
grant INSERT on table "public"."v5_question_bank_admin_view" to "anon";
grant SELECT on table "public"."v5_question_bank_admin_view" to "anon";
grant UPDATE on table "public"."v5_question_bank_admin_view" to "anon";
grant DELETE on table "public"."v5_question_bank_admin_view" to "anon";
grant TRUNCATE on table "public"."v5_question_bank_admin_view" to "anon";
grant REFERENCES on table "public"."v5_question_bank_admin_view" to "anon";
grant TRIGGER on table "public"."v5_question_bank_admin_view" to "anon";
grant MAINTAIN on table "public"."v5_question_bank_admin_view" to "anon";
grant INSERT on table "public"."v5_question_bank_admin_view" to "authenticated";
grant SELECT on table "public"."v5_question_bank_admin_view" to "authenticated";
grant UPDATE on table "public"."v5_question_bank_admin_view" to "authenticated";
grant DELETE on table "public"."v5_question_bank_admin_view" to "authenticated";
grant TRUNCATE on table "public"."v5_question_bank_admin_view" to "authenticated";
grant REFERENCES on table "public"."v5_question_bank_admin_view" to "authenticated";
grant TRIGGER on table "public"."v5_question_bank_admin_view" to "authenticated";
grant MAINTAIN on table "public"."v5_question_bank_admin_view" to "authenticated";
grant INSERT on table "public"."v5_question_bank_admin_view" to "service_role";
grant SELECT on table "public"."v5_question_bank_admin_view" to "service_role";
grant UPDATE on table "public"."v5_question_bank_admin_view" to "service_role";
grant DELETE on table "public"."v5_question_bank_admin_view" to "service_role";
grant TRUNCATE on table "public"."v5_question_bank_admin_view" to "service_role";
grant REFERENCES on table "public"."v5_question_bank_admin_view" to "service_role";
grant TRIGGER on table "public"."v5_question_bank_admin_view" to "service_role";
grant MAINTAIN on table "public"."v5_question_bank_admin_view" to "service_role";
grant INSERT on table "public"."exam_answer_distribution" to "anon";
grant SELECT on table "public"."exam_answer_distribution" to "anon";
grant UPDATE on table "public"."exam_answer_distribution" to "anon";
grant DELETE on table "public"."exam_answer_distribution" to "anon";
grant TRUNCATE on table "public"."exam_answer_distribution" to "anon";
grant REFERENCES on table "public"."exam_answer_distribution" to "anon";
grant TRIGGER on table "public"."exam_answer_distribution" to "anon";
grant MAINTAIN on table "public"."exam_answer_distribution" to "anon";
grant INSERT on table "public"."exam_answer_distribution" to "authenticated";
grant SELECT on table "public"."exam_answer_distribution" to "authenticated";
grant UPDATE on table "public"."exam_answer_distribution" to "authenticated";
grant DELETE on table "public"."exam_answer_distribution" to "authenticated";
grant TRUNCATE on table "public"."exam_answer_distribution" to "authenticated";
grant REFERENCES on table "public"."exam_answer_distribution" to "authenticated";
grant TRIGGER on table "public"."exam_answer_distribution" to "authenticated";
grant MAINTAIN on table "public"."exam_answer_distribution" to "authenticated";
grant INSERT on table "public"."exam_answer_distribution" to "service_role";
grant SELECT on table "public"."exam_answer_distribution" to "service_role";
grant UPDATE on table "public"."exam_answer_distribution" to "service_role";
grant DELETE on table "public"."exam_answer_distribution" to "service_role";
grant TRUNCATE on table "public"."exam_answer_distribution" to "service_role";
grant REFERENCES on table "public"."exam_answer_distribution" to "service_role";
grant TRIGGER on table "public"."exam_answer_distribution" to "service_role";
grant MAINTAIN on table "public"."exam_answer_distribution" to "service_role";
grant SELECT on sequence "public"."student_answers_id_seq" to "anon";
grant UPDATE on sequence "public"."student_answers_id_seq" to "anon";
grant USAGE on sequence "public"."student_answers_id_seq" to "anon";
grant SELECT on sequence "public"."student_answers_id_seq" to "authenticated";
grant UPDATE on sequence "public"."student_answers_id_seq" to "authenticated";
grant USAGE on sequence "public"."student_answers_id_seq" to "authenticated";
grant SELECT on sequence "public"."student_answers_id_seq" to "service_role";
grant UPDATE on sequence "public"."student_answers_id_seq" to "service_role";
grant USAGE on sequence "public"."student_answers_id_seq" to "service_role";
grant INSERT on table "public"."v5_question_bank_detail_view" to "anon";
grant SELECT on table "public"."v5_question_bank_detail_view" to "anon";
grant UPDATE on table "public"."v5_question_bank_detail_view" to "anon";
grant DELETE on table "public"."v5_question_bank_detail_view" to "anon";
grant TRUNCATE on table "public"."v5_question_bank_detail_view" to "anon";
grant REFERENCES on table "public"."v5_question_bank_detail_view" to "anon";
grant TRIGGER on table "public"."v5_question_bank_detail_view" to "anon";
grant MAINTAIN on table "public"."v5_question_bank_detail_view" to "anon";
grant INSERT on table "public"."v5_question_bank_detail_view" to "authenticated";
grant SELECT on table "public"."v5_question_bank_detail_view" to "authenticated";
grant UPDATE on table "public"."v5_question_bank_detail_view" to "authenticated";
grant DELETE on table "public"."v5_question_bank_detail_view" to "authenticated";
grant TRUNCATE on table "public"."v5_question_bank_detail_view" to "authenticated";
grant REFERENCES on table "public"."v5_question_bank_detail_view" to "authenticated";
grant TRIGGER on table "public"."v5_question_bank_detail_view" to "authenticated";
grant MAINTAIN on table "public"."v5_question_bank_detail_view" to "authenticated";
grant INSERT on table "public"."v5_question_bank_detail_view" to "service_role";
grant SELECT on table "public"."v5_question_bank_detail_view" to "service_role";
grant UPDATE on table "public"."v5_question_bank_detail_view" to "service_role";
grant DELETE on table "public"."v5_question_bank_detail_view" to "service_role";
grant TRUNCATE on table "public"."v5_question_bank_detail_view" to "service_role";
grant REFERENCES on table "public"."v5_question_bank_detail_view" to "service_role";
grant TRIGGER on table "public"."v5_question_bank_detail_view" to "service_role";
grant MAINTAIN on table "public"."v5_question_bank_detail_view" to "service_role";
grant SELECT on sequence "public"."student_question_performance_id_seq" to "anon";
grant UPDATE on sequence "public"."student_question_performance_id_seq" to "anon";
grant USAGE on sequence "public"."student_question_performance_id_seq" to "anon";
grant SELECT on sequence "public"."student_question_performance_id_seq" to "authenticated";
grant UPDATE on sequence "public"."student_question_performance_id_seq" to "authenticated";
grant USAGE on sequence "public"."student_question_performance_id_seq" to "authenticated";
grant SELECT on sequence "public"."student_question_performance_id_seq" to "service_role";
grant UPDATE on sequence "public"."student_question_performance_id_seq" to "service_role";
grant USAGE on sequence "public"."student_question_performance_id_seq" to "service_role";
grant INSERT on table "public"."student_performance_levels" to "anon";
grant SELECT on table "public"."student_performance_levels" to "anon";
grant UPDATE on table "public"."student_performance_levels" to "anon";
grant DELETE on table "public"."student_performance_levels" to "anon";
grant TRUNCATE on table "public"."student_performance_levels" to "anon";
grant REFERENCES on table "public"."student_performance_levels" to "anon";
grant TRIGGER on table "public"."student_performance_levels" to "anon";
grant MAINTAIN on table "public"."student_performance_levels" to "anon";
grant INSERT on table "public"."student_performance_levels" to "authenticated";
grant SELECT on table "public"."student_performance_levels" to "authenticated";
grant UPDATE on table "public"."student_performance_levels" to "authenticated";
grant DELETE on table "public"."student_performance_levels" to "authenticated";
grant TRUNCATE on table "public"."student_performance_levels" to "authenticated";
grant REFERENCES on table "public"."student_performance_levels" to "authenticated";
grant TRIGGER on table "public"."student_performance_levels" to "authenticated";
grant MAINTAIN on table "public"."student_performance_levels" to "authenticated";
grant INSERT on table "public"."student_performance_levels" to "service_role";
grant SELECT on table "public"."student_performance_levels" to "service_role";
grant UPDATE on table "public"."student_performance_levels" to "service_role";
grant DELETE on table "public"."student_performance_levels" to "service_role";
grant TRUNCATE on table "public"."student_performance_levels" to "service_role";
grant REFERENCES on table "public"."student_performance_levels" to "service_role";
grant TRIGGER on table "public"."student_performance_levels" to "service_role";
grant MAINTAIN on table "public"."student_performance_levels" to "service_role";
grant INSERT on table "public"."exam_performance_distribution" to "anon";
grant SELECT on table "public"."exam_performance_distribution" to "anon";
grant UPDATE on table "public"."exam_performance_distribution" to "anon";
grant DELETE on table "public"."exam_performance_distribution" to "anon";
grant TRUNCATE on table "public"."exam_performance_distribution" to "anon";
grant REFERENCES on table "public"."exam_performance_distribution" to "anon";
grant TRIGGER on table "public"."exam_performance_distribution" to "anon";
grant MAINTAIN on table "public"."exam_performance_distribution" to "anon";
grant INSERT on table "public"."exam_performance_distribution" to "authenticated";
grant SELECT on table "public"."exam_performance_distribution" to "authenticated";
grant UPDATE on table "public"."exam_performance_distribution" to "authenticated";
grant DELETE on table "public"."exam_performance_distribution" to "authenticated";
grant TRUNCATE on table "public"."exam_performance_distribution" to "authenticated";
grant REFERENCES on table "public"."exam_performance_distribution" to "authenticated";
grant TRIGGER on table "public"."exam_performance_distribution" to "authenticated";
grant MAINTAIN on table "public"."exam_performance_distribution" to "authenticated";
grant INSERT on table "public"."exam_performance_distribution" to "service_role";
grant SELECT on table "public"."exam_performance_distribution" to "service_role";
grant UPDATE on table "public"."exam_performance_distribution" to "service_role";
grant DELETE on table "public"."exam_performance_distribution" to "service_role";
grant TRUNCATE on table "public"."exam_performance_distribution" to "service_role";
grant REFERENCES on table "public"."exam_performance_distribution" to "service_role";
grant TRIGGER on table "public"."exam_performance_distribution" to "service_role";
grant MAINTAIN on table "public"."exam_performance_distribution" to "service_role";
grant SELECT on sequence "public"."student_subject_performance_id_seq" to "anon";
grant UPDATE on sequence "public"."student_subject_performance_id_seq" to "anon";
grant USAGE on sequence "public"."student_subject_performance_id_seq" to "anon";
grant SELECT on sequence "public"."student_subject_performance_id_seq" to "authenticated";
grant UPDATE on sequence "public"."student_subject_performance_id_seq" to "authenticated";
grant USAGE on sequence "public"."student_subject_performance_id_seq" to "authenticated";
grant SELECT on sequence "public"."student_subject_performance_id_seq" to "service_role";
grant UPDATE on sequence "public"."student_subject_performance_id_seq" to "service_role";
grant USAGE on sequence "public"."student_subject_performance_id_seq" to "service_role";
grant INSERT on table "public"."admin_dashboard_summary" to "anon";
grant SELECT on table "public"."admin_dashboard_summary" to "anon";
grant UPDATE on table "public"."admin_dashboard_summary" to "anon";
grant DELETE on table "public"."admin_dashboard_summary" to "anon";
grant TRUNCATE on table "public"."admin_dashboard_summary" to "anon";
grant REFERENCES on table "public"."admin_dashboard_summary" to "anon";
grant TRIGGER on table "public"."admin_dashboard_summary" to "anon";
grant MAINTAIN on table "public"."admin_dashboard_summary" to "anon";
grant INSERT on table "public"."admin_dashboard_summary" to "authenticated";
grant SELECT on table "public"."admin_dashboard_summary" to "authenticated";
grant UPDATE on table "public"."admin_dashboard_summary" to "authenticated";
grant DELETE on table "public"."admin_dashboard_summary" to "authenticated";
grant TRUNCATE on table "public"."admin_dashboard_summary" to "authenticated";
grant REFERENCES on table "public"."admin_dashboard_summary" to "authenticated";
grant TRIGGER on table "public"."admin_dashboard_summary" to "authenticated";
grant MAINTAIN on table "public"."admin_dashboard_summary" to "authenticated";
grant INSERT on table "public"."admin_dashboard_summary" to "service_role";
grant SELECT on table "public"."admin_dashboard_summary" to "service_role";
grant UPDATE on table "public"."admin_dashboard_summary" to "service_role";
grant DELETE on table "public"."admin_dashboard_summary" to "service_role";
grant TRUNCATE on table "public"."admin_dashboard_summary" to "service_role";
grant REFERENCES on table "public"."admin_dashboard_summary" to "service_role";
grant TRIGGER on table "public"."admin_dashboard_summary" to "service_role";
grant MAINTAIN on table "public"."admin_dashboard_summary" to "service_role";
grant SELECT on sequence "public"."question_performance_id_seq" to "anon";
grant UPDATE on sequence "public"."question_performance_id_seq" to "anon";
grant USAGE on sequence "public"."question_performance_id_seq" to "anon";
grant SELECT on sequence "public"."question_performance_id_seq" to "authenticated";
grant UPDATE on sequence "public"."question_performance_id_seq" to "authenticated";
grant USAGE on sequence "public"."question_performance_id_seq" to "authenticated";
grant SELECT on sequence "public"."question_performance_id_seq" to "service_role";
grant UPDATE on sequence "public"."question_performance_id_seq" to "service_role";
grant USAGE on sequence "public"."question_performance_id_seq" to "service_role";
grant SELECT on sequence "public"."exam_analytics_id_seq" to "anon";
grant UPDATE on sequence "public"."exam_analytics_id_seq" to "anon";
grant USAGE on sequence "public"."exam_analytics_id_seq" to "anon";
grant SELECT on sequence "public"."exam_analytics_id_seq" to "authenticated";
grant UPDATE on sequence "public"."exam_analytics_id_seq" to "authenticated";
grant USAGE on sequence "public"."exam_analytics_id_seq" to "authenticated";
grant SELECT on sequence "public"."exam_analytics_id_seq" to "service_role";
grant UPDATE on sequence "public"."exam_analytics_id_seq" to "service_role";
grant USAGE on sequence "public"."exam_analytics_id_seq" to "service_role";
grant INSERT on table "public"."exam_attempts" to "anon";
grant SELECT on table "public"."exam_attempts" to "anon";
grant UPDATE on table "public"."exam_attempts" to "anon";
grant DELETE on table "public"."exam_attempts" to "anon";
grant TRUNCATE on table "public"."exam_attempts" to "anon";
grant REFERENCES on table "public"."exam_attempts" to "anon";
grant TRIGGER on table "public"."exam_attempts" to "anon";
grant MAINTAIN on table "public"."exam_attempts" to "anon";
grant INSERT on table "public"."exam_attempts" to "authenticated";
grant SELECT on table "public"."exam_attempts" to "authenticated";
grant UPDATE on table "public"."exam_attempts" to "authenticated";
grant DELETE on table "public"."exam_attempts" to "authenticated";
grant TRUNCATE on table "public"."exam_attempts" to "authenticated";
grant REFERENCES on table "public"."exam_attempts" to "authenticated";
grant TRIGGER on table "public"."exam_attempts" to "authenticated";
grant MAINTAIN on table "public"."exam_attempts" to "authenticated";
grant INSERT on table "public"."exam_attempts" to "service_role";
grant SELECT on table "public"."exam_attempts" to "service_role";
grant UPDATE on table "public"."exam_attempts" to "service_role";
grant DELETE on table "public"."exam_attempts" to "service_role";
grant TRUNCATE on table "public"."exam_attempts" to "service_role";
grant REFERENCES on table "public"."exam_attempts" to "service_role";
grant TRIGGER on table "public"."exam_attempts" to "service_role";
grant MAINTAIN on table "public"."exam_attempts" to "service_role";
grant INSERT on table "public"."student_answers" to "anon";
grant SELECT on table "public"."student_answers" to "anon";
grant UPDATE on table "public"."student_answers" to "anon";
grant DELETE on table "public"."student_answers" to "anon";
grant TRUNCATE on table "public"."student_answers" to "anon";
grant REFERENCES on table "public"."student_answers" to "anon";
grant TRIGGER on table "public"."student_answers" to "anon";
grant MAINTAIN on table "public"."student_answers" to "anon";
grant INSERT on table "public"."student_answers" to "authenticated";
grant SELECT on table "public"."student_answers" to "authenticated";
grant UPDATE on table "public"."student_answers" to "authenticated";
grant DELETE on table "public"."student_answers" to "authenticated";
grant TRUNCATE on table "public"."student_answers" to "authenticated";
grant REFERENCES on table "public"."student_answers" to "authenticated";
grant TRIGGER on table "public"."student_answers" to "authenticated";
grant MAINTAIN on table "public"."student_answers" to "authenticated";
grant INSERT on table "public"."student_answers" to "service_role";
grant SELECT on table "public"."student_answers" to "service_role";
grant UPDATE on table "public"."student_answers" to "service_role";
grant DELETE on table "public"."student_answers" to "service_role";
grant TRUNCATE on table "public"."student_answers" to "service_role";
grant REFERENCES on table "public"."student_answers" to "service_role";
grant TRIGGER on table "public"."student_answers" to "service_role";
grant MAINTAIN on table "public"."student_answers" to "service_role";
grant INSERT on table "public"."educational_question_analysis" to "anon";
grant SELECT on table "public"."educational_question_analysis" to "anon";
grant UPDATE on table "public"."educational_question_analysis" to "anon";
grant DELETE on table "public"."educational_question_analysis" to "anon";
grant TRUNCATE on table "public"."educational_question_analysis" to "anon";
grant REFERENCES on table "public"."educational_question_analysis" to "anon";
grant TRIGGER on table "public"."educational_question_analysis" to "anon";
grant MAINTAIN on table "public"."educational_question_analysis" to "anon";
grant INSERT on table "public"."educational_question_analysis" to "authenticated";
grant SELECT on table "public"."educational_question_analysis" to "authenticated";
grant UPDATE on table "public"."educational_question_analysis" to "authenticated";
grant DELETE on table "public"."educational_question_analysis" to "authenticated";
grant TRUNCATE on table "public"."educational_question_analysis" to "authenticated";
grant REFERENCES on table "public"."educational_question_analysis" to "authenticated";
grant TRIGGER on table "public"."educational_question_analysis" to "authenticated";
grant MAINTAIN on table "public"."educational_question_analysis" to "authenticated";
grant INSERT on table "public"."educational_question_analysis" to "service_role";
grant SELECT on table "public"."educational_question_analysis" to "service_role";
grant UPDATE on table "public"."educational_question_analysis" to "service_role";
grant DELETE on table "public"."educational_question_analysis" to "service_role";
grant TRUNCATE on table "public"."educational_question_analysis" to "service_role";
grant REFERENCES on table "public"."educational_question_analysis" to "service_role";
grant TRIGGER on table "public"."educational_question_analysis" to "service_role";
grant MAINTAIN on table "public"."educational_question_analysis" to "service_role";
grant INSERT on table "public"."v5_exam_builder_view" to "anon";
grant SELECT on table "public"."v5_exam_builder_view" to "anon";
grant UPDATE on table "public"."v5_exam_builder_view" to "anon";
grant DELETE on table "public"."v5_exam_builder_view" to "anon";
grant TRUNCATE on table "public"."v5_exam_builder_view" to "anon";
grant REFERENCES on table "public"."v5_exam_builder_view" to "anon";
grant TRIGGER on table "public"."v5_exam_builder_view" to "anon";
grant MAINTAIN on table "public"."v5_exam_builder_view" to "anon";
grant INSERT on table "public"."v5_exam_builder_view" to "authenticated";
grant SELECT on table "public"."v5_exam_builder_view" to "authenticated";
grant UPDATE on table "public"."v5_exam_builder_view" to "authenticated";
grant DELETE on table "public"."v5_exam_builder_view" to "authenticated";
grant TRUNCATE on table "public"."v5_exam_builder_view" to "authenticated";
grant REFERENCES on table "public"."v5_exam_builder_view" to "authenticated";
grant TRIGGER on table "public"."v5_exam_builder_view" to "authenticated";
grant MAINTAIN on table "public"."v5_exam_builder_view" to "authenticated";
grant INSERT on table "public"."v5_exam_builder_view" to "service_role";
grant SELECT on table "public"."v5_exam_builder_view" to "service_role";
grant UPDATE on table "public"."v5_exam_builder_view" to "service_role";
grant DELETE on table "public"."v5_exam_builder_view" to "service_role";
grant TRUNCATE on table "public"."v5_exam_builder_view" to "service_role";
grant REFERENCES on table "public"."v5_exam_builder_view" to "service_role";
grant TRIGGER on table "public"."v5_exam_builder_view" to "service_role";
grant MAINTAIN on table "public"."v5_exam_builder_view" to "service_role";
grant INSERT on table "public"."educational_exam_analysis" to "anon";
grant SELECT on table "public"."educational_exam_analysis" to "anon";
grant UPDATE on table "public"."educational_exam_analysis" to "anon";
grant DELETE on table "public"."educational_exam_analysis" to "anon";
grant TRUNCATE on table "public"."educational_exam_analysis" to "anon";
grant REFERENCES on table "public"."educational_exam_analysis" to "anon";
grant TRIGGER on table "public"."educational_exam_analysis" to "anon";
grant MAINTAIN on table "public"."educational_exam_analysis" to "anon";
grant INSERT on table "public"."educational_exam_analysis" to "authenticated";
grant SELECT on table "public"."educational_exam_analysis" to "authenticated";
grant UPDATE on table "public"."educational_exam_analysis" to "authenticated";
grant DELETE on table "public"."educational_exam_analysis" to "authenticated";
grant TRUNCATE on table "public"."educational_exam_analysis" to "authenticated";
grant REFERENCES on table "public"."educational_exam_analysis" to "authenticated";
grant TRIGGER on table "public"."educational_exam_analysis" to "authenticated";
grant MAINTAIN on table "public"."educational_exam_analysis" to "authenticated";
grant INSERT on table "public"."educational_exam_analysis" to "service_role";
grant SELECT on table "public"."educational_exam_analysis" to "service_role";
grant UPDATE on table "public"."educational_exam_analysis" to "service_role";
grant DELETE on table "public"."educational_exam_analysis" to "service_role";
grant TRUNCATE on table "public"."educational_exam_analysis" to "service_role";
grant REFERENCES on table "public"."educational_exam_analysis" to "service_role";
grant TRIGGER on table "public"."educational_exam_analysis" to "service_role";
grant MAINTAIN on table "public"."educational_exam_analysis" to "service_role";
grant INSERT on table "public"."v5_exam_questions_view" to "anon";
grant SELECT on table "public"."v5_exam_questions_view" to "anon";
grant UPDATE on table "public"."v5_exam_questions_view" to "anon";
grant DELETE on table "public"."v5_exam_questions_view" to "anon";
grant TRUNCATE on table "public"."v5_exam_questions_view" to "anon";
grant REFERENCES on table "public"."v5_exam_questions_view" to "anon";
grant TRIGGER on table "public"."v5_exam_questions_view" to "anon";
grant MAINTAIN on table "public"."v5_exam_questions_view" to "anon";
grant INSERT on table "public"."v5_exam_questions_view" to "authenticated";
grant SELECT on table "public"."v5_exam_questions_view" to "authenticated";
grant UPDATE on table "public"."v5_exam_questions_view" to "authenticated";
grant DELETE on table "public"."v5_exam_questions_view" to "authenticated";
grant TRUNCATE on table "public"."v5_exam_questions_view" to "authenticated";
grant REFERENCES on table "public"."v5_exam_questions_view" to "authenticated";
grant TRIGGER on table "public"."v5_exam_questions_view" to "authenticated";
grant MAINTAIN on table "public"."v5_exam_questions_view" to "authenticated";
grant INSERT on table "public"."v5_exam_questions_view" to "service_role";
grant SELECT on table "public"."v5_exam_questions_view" to "service_role";
grant UPDATE on table "public"."v5_exam_questions_view" to "service_role";
grant DELETE on table "public"."v5_exam_questions_view" to "service_role";
grant TRUNCATE on table "public"."v5_exam_questions_view" to "service_role";
grant REFERENCES on table "public"."v5_exam_questions_view" to "service_role";
grant TRIGGER on table "public"."v5_exam_questions_view" to "service_role";
grant MAINTAIN on table "public"."v5_exam_questions_view" to "service_role";
grant INSERT on table "public"."educational_student_analysis" to "anon";
grant SELECT on table "public"."educational_student_analysis" to "anon";
grant UPDATE on table "public"."educational_student_analysis" to "anon";
grant DELETE on table "public"."educational_student_analysis" to "anon";
grant TRUNCATE on table "public"."educational_student_analysis" to "anon";
grant REFERENCES on table "public"."educational_student_analysis" to "anon";
grant TRIGGER on table "public"."educational_student_analysis" to "anon";
grant MAINTAIN on table "public"."educational_student_analysis" to "anon";
grant INSERT on table "public"."educational_student_analysis" to "authenticated";
grant SELECT on table "public"."educational_student_analysis" to "authenticated";
grant UPDATE on table "public"."educational_student_analysis" to "authenticated";
grant DELETE on table "public"."educational_student_analysis" to "authenticated";
grant TRUNCATE on table "public"."educational_student_analysis" to "authenticated";
grant REFERENCES on table "public"."educational_student_analysis" to "authenticated";
grant TRIGGER on table "public"."educational_student_analysis" to "authenticated";
grant MAINTAIN on table "public"."educational_student_analysis" to "authenticated";
grant INSERT on table "public"."educational_student_analysis" to "service_role";
grant SELECT on table "public"."educational_student_analysis" to "service_role";
grant UPDATE on table "public"."educational_student_analysis" to "service_role";
grant DELETE on table "public"."educational_student_analysis" to "service_role";
grant TRUNCATE on table "public"."educational_student_analysis" to "service_role";
grant REFERENCES on table "public"."educational_student_analysis" to "service_role";
grant TRIGGER on table "public"."educational_student_analysis" to "service_role";
grant MAINTAIN on table "public"."educational_student_analysis" to "service_role";
grant INSERT on table "public"."student_strength_weakness" to "anon";
grant SELECT on table "public"."student_strength_weakness" to "anon";
grant UPDATE on table "public"."student_strength_weakness" to "anon";
grant DELETE on table "public"."student_strength_weakness" to "anon";
grant TRUNCATE on table "public"."student_strength_weakness" to "anon";
grant REFERENCES on table "public"."student_strength_weakness" to "anon";
grant TRIGGER on table "public"."student_strength_weakness" to "anon";
grant MAINTAIN on table "public"."student_strength_weakness" to "anon";
grant INSERT on table "public"."student_strength_weakness" to "authenticated";
grant SELECT on table "public"."student_strength_weakness" to "authenticated";
grant UPDATE on table "public"."student_strength_weakness" to "authenticated";
grant DELETE on table "public"."student_strength_weakness" to "authenticated";
grant TRUNCATE on table "public"."student_strength_weakness" to "authenticated";
grant REFERENCES on table "public"."student_strength_weakness" to "authenticated";
grant TRIGGER on table "public"."student_strength_weakness" to "authenticated";
grant MAINTAIN on table "public"."student_strength_weakness" to "authenticated";
grant INSERT on table "public"."student_strength_weakness" to "service_role";
grant SELECT on table "public"."student_strength_weakness" to "service_role";
grant UPDATE on table "public"."student_strength_weakness" to "service_role";
grant DELETE on table "public"."student_strength_weakness" to "service_role";
grant TRUNCATE on table "public"."student_strength_weakness" to "service_role";
grant REFERENCES on table "public"."student_strength_weakness" to "service_role";
grant TRIGGER on table "public"."student_strength_weakness" to "service_role";
grant MAINTAIN on table "public"."student_strength_weakness" to "service_role";
grant INSERT on table "public"."educational_hard_questions" to "anon";
grant SELECT on table "public"."educational_hard_questions" to "anon";
grant UPDATE on table "public"."educational_hard_questions" to "anon";
grant DELETE on table "public"."educational_hard_questions" to "anon";
grant TRUNCATE on table "public"."educational_hard_questions" to "anon";
grant REFERENCES on table "public"."educational_hard_questions" to "anon";
grant TRIGGER on table "public"."educational_hard_questions" to "anon";
grant MAINTAIN on table "public"."educational_hard_questions" to "anon";
grant INSERT on table "public"."educational_hard_questions" to "authenticated";
grant SELECT on table "public"."educational_hard_questions" to "authenticated";
grant UPDATE on table "public"."educational_hard_questions" to "authenticated";
grant DELETE on table "public"."educational_hard_questions" to "authenticated";
grant TRUNCATE on table "public"."educational_hard_questions" to "authenticated";
grant REFERENCES on table "public"."educational_hard_questions" to "authenticated";
grant TRIGGER on table "public"."educational_hard_questions" to "authenticated";
grant MAINTAIN on table "public"."educational_hard_questions" to "authenticated";
grant INSERT on table "public"."educational_hard_questions" to "service_role";
grant SELECT on table "public"."educational_hard_questions" to "service_role";
grant UPDATE on table "public"."educational_hard_questions" to "service_role";
grant DELETE on table "public"."educational_hard_questions" to "service_role";
grant TRUNCATE on table "public"."educational_hard_questions" to "service_role";
grant REFERENCES on table "public"."educational_hard_questions" to "service_role";
grant TRIGGER on table "public"."educational_hard_questions" to "service_role";
grant MAINTAIN on table "public"."educational_hard_questions" to "service_role";
grant INSERT on table "public"."questions_need_review" to "anon";
grant SELECT on table "public"."questions_need_review" to "anon";
grant UPDATE on table "public"."questions_need_review" to "anon";
grant DELETE on table "public"."questions_need_review" to "anon";
grant TRUNCATE on table "public"."questions_need_review" to "anon";
grant REFERENCES on table "public"."questions_need_review" to "anon";
grant TRIGGER on table "public"."questions_need_review" to "anon";
grant MAINTAIN on table "public"."questions_need_review" to "anon";
grant INSERT on table "public"."questions_need_review" to "authenticated";
grant SELECT on table "public"."questions_need_review" to "authenticated";
grant UPDATE on table "public"."questions_need_review" to "authenticated";
grant DELETE on table "public"."questions_need_review" to "authenticated";
grant TRUNCATE on table "public"."questions_need_review" to "authenticated";
grant REFERENCES on table "public"."questions_need_review" to "authenticated";
grant TRIGGER on table "public"."questions_need_review" to "authenticated";
grant MAINTAIN on table "public"."questions_need_review" to "authenticated";
grant INSERT on table "public"."questions_need_review" to "service_role";
grant SELECT on table "public"."questions_need_review" to "service_role";
grant UPDATE on table "public"."questions_need_review" to "service_role";
grant DELETE on table "public"."questions_need_review" to "service_role";
grant TRUNCATE on table "public"."questions_need_review" to "service_role";
grant REFERENCES on table "public"."questions_need_review" to "service_role";
grant TRIGGER on table "public"."questions_need_review" to "service_role";
grant MAINTAIN on table "public"."questions_need_review" to "service_role";
grant INSERT on table "public"."student_question_performance" to "anon";
grant SELECT on table "public"."student_question_performance" to "anon";
grant UPDATE on table "public"."student_question_performance" to "anon";
grant DELETE on table "public"."student_question_performance" to "anon";
grant TRUNCATE on table "public"."student_question_performance" to "anon";
grant REFERENCES on table "public"."student_question_performance" to "anon";
grant TRIGGER on table "public"."student_question_performance" to "anon";
grant MAINTAIN on table "public"."student_question_performance" to "anon";
grant INSERT on table "public"."student_question_performance" to "authenticated";
grant SELECT on table "public"."student_question_performance" to "authenticated";
grant UPDATE on table "public"."student_question_performance" to "authenticated";
grant DELETE on table "public"."student_question_performance" to "authenticated";
grant TRUNCATE on table "public"."student_question_performance" to "authenticated";
grant REFERENCES on table "public"."student_question_performance" to "authenticated";
grant TRIGGER on table "public"."student_question_performance" to "authenticated";
grant MAINTAIN on table "public"."student_question_performance" to "authenticated";
grant INSERT on table "public"."student_question_performance" to "service_role";
grant SELECT on table "public"."student_question_performance" to "service_role";
grant UPDATE on table "public"."student_question_performance" to "service_role";
grant DELETE on table "public"."student_question_performance" to "service_role";
grant TRUNCATE on table "public"."student_question_performance" to "service_role";
grant REFERENCES on table "public"."student_question_performance" to "service_role";
grant TRIGGER on table "public"."student_question_performance" to "service_role";
grant MAINTAIN on table "public"."student_question_performance" to "service_role";
grant INSERT on table "public"."student_subject_performance" to "anon";
grant SELECT on table "public"."student_subject_performance" to "anon";
grant UPDATE on table "public"."student_subject_performance" to "anon";
grant DELETE on table "public"."student_subject_performance" to "anon";
grant TRUNCATE on table "public"."student_subject_performance" to "anon";
grant REFERENCES on table "public"."student_subject_performance" to "anon";
grant TRIGGER on table "public"."student_subject_performance" to "anon";
grant MAINTAIN on table "public"."student_subject_performance" to "anon";
grant INSERT on table "public"."student_subject_performance" to "authenticated";
grant SELECT on table "public"."student_subject_performance" to "authenticated";
grant UPDATE on table "public"."student_subject_performance" to "authenticated";
grant DELETE on table "public"."student_subject_performance" to "authenticated";
grant TRUNCATE on table "public"."student_subject_performance" to "authenticated";
grant REFERENCES on table "public"."student_subject_performance" to "authenticated";
grant TRIGGER on table "public"."student_subject_performance" to "authenticated";
grant MAINTAIN on table "public"."student_subject_performance" to "authenticated";
grant INSERT on table "public"."student_subject_performance" to "service_role";
grant SELECT on table "public"."student_subject_performance" to "service_role";
grant UPDATE on table "public"."student_subject_performance" to "service_role";
grant DELETE on table "public"."student_subject_performance" to "service_role";
grant TRUNCATE on table "public"."student_subject_performance" to "service_role";
grant REFERENCES on table "public"."student_subject_performance" to "service_role";
grant TRIGGER on table "public"."student_subject_performance" to "service_role";
grant MAINTAIN on table "public"."student_subject_performance" to "service_role";
grant INSERT on table "public"."question_performance" to "anon";
grant SELECT on table "public"."question_performance" to "anon";
grant UPDATE on table "public"."question_performance" to "anon";
grant DELETE on table "public"."question_performance" to "anon";
grant TRUNCATE on table "public"."question_performance" to "anon";
grant REFERENCES on table "public"."question_performance" to "anon";
grant TRIGGER on table "public"."question_performance" to "anon";
grant MAINTAIN on table "public"."question_performance" to "anon";
grant INSERT on table "public"."question_performance" to "authenticated";
grant SELECT on table "public"."question_performance" to "authenticated";
grant UPDATE on table "public"."question_performance" to "authenticated";
grant DELETE on table "public"."question_performance" to "authenticated";
grant TRUNCATE on table "public"."question_performance" to "authenticated";
grant REFERENCES on table "public"."question_performance" to "authenticated";
grant TRIGGER on table "public"."question_performance" to "authenticated";
grant MAINTAIN on table "public"."question_performance" to "authenticated";
grant INSERT on table "public"."question_performance" to "service_role";
grant SELECT on table "public"."question_performance" to "service_role";
grant UPDATE on table "public"."question_performance" to "service_role";
grant DELETE on table "public"."question_performance" to "service_role";
grant TRUNCATE on table "public"."question_performance" to "service_role";
grant REFERENCES on table "public"."question_performance" to "service_role";
grant TRIGGER on table "public"."question_performance" to "service_role";
grant MAINTAIN on table "public"."question_performance" to "service_role";
grant INSERT on table "public"."student_learning_summary" to "anon";
grant SELECT on table "public"."student_learning_summary" to "anon";
grant UPDATE on table "public"."student_learning_summary" to "anon";
grant DELETE on table "public"."student_learning_summary" to "anon";
grant TRUNCATE on table "public"."student_learning_summary" to "anon";
grant REFERENCES on table "public"."student_learning_summary" to "anon";
grant TRIGGER on table "public"."student_learning_summary" to "anon";
grant MAINTAIN on table "public"."student_learning_summary" to "anon";
grant INSERT on table "public"."student_learning_summary" to "authenticated";
grant SELECT on table "public"."student_learning_summary" to "authenticated";
grant UPDATE on table "public"."student_learning_summary" to "authenticated";
grant DELETE on table "public"."student_learning_summary" to "authenticated";
grant TRUNCATE on table "public"."student_learning_summary" to "authenticated";
grant REFERENCES on table "public"."student_learning_summary" to "authenticated";
grant TRIGGER on table "public"."student_learning_summary" to "authenticated";
grant MAINTAIN on table "public"."student_learning_summary" to "authenticated";
grant INSERT on table "public"."student_learning_summary" to "service_role";
grant SELECT on table "public"."student_learning_summary" to "service_role";
grant UPDATE on table "public"."student_learning_summary" to "service_role";
grant DELETE on table "public"."student_learning_summary" to "service_role";
grant TRUNCATE on table "public"."student_learning_summary" to "service_role";
grant REFERENCES on table "public"."student_learning_summary" to "service_role";
grant TRIGGER on table "public"."student_learning_summary" to "service_role";
grant MAINTAIN on table "public"."student_learning_summary" to "service_role";
grant INSERT on table "public"."exam_analytics" to "anon";
grant SELECT on table "public"."exam_analytics" to "anon";
grant UPDATE on table "public"."exam_analytics" to "anon";
grant DELETE on table "public"."exam_analytics" to "anon";
grant TRUNCATE on table "public"."exam_analytics" to "anon";
grant REFERENCES on table "public"."exam_analytics" to "anon";
grant TRIGGER on table "public"."exam_analytics" to "anon";
grant MAINTAIN on table "public"."exam_analytics" to "anon";
grant INSERT on table "public"."exam_analytics" to "authenticated";
grant SELECT on table "public"."exam_analytics" to "authenticated";
grant UPDATE on table "public"."exam_analytics" to "authenticated";
grant DELETE on table "public"."exam_analytics" to "authenticated";
grant TRUNCATE on table "public"."exam_analytics" to "authenticated";
grant REFERENCES on table "public"."exam_analytics" to "authenticated";
grant TRIGGER on table "public"."exam_analytics" to "authenticated";
grant MAINTAIN on table "public"."exam_analytics" to "authenticated";
grant INSERT on table "public"."exam_analytics" to "service_role";
grant SELECT on table "public"."exam_analytics" to "service_role";
grant UPDATE on table "public"."exam_analytics" to "service_role";
grant DELETE on table "public"."exam_analytics" to "service_role";
grant TRUNCATE on table "public"."exam_analytics" to "service_role";
grant REFERENCES on table "public"."exam_analytics" to "service_role";
grant TRIGGER on table "public"."exam_analytics" to "service_role";
grant MAINTAIN on table "public"."exam_analytics" to "service_role";
grant EXECUTE on function "public"."v5_admin_create_question"(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_question_type text, p_difficulty text, p_score numeric, p_explanation text, p_tags text[], p_source_id bigint, p_source_page text) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_question"(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_question_type text, p_difficulty text, p_score numeric, p_explanation text, p_tags text[], p_source_id bigint, p_source_page text) to "service_role";
grant EXECUTE on function "public"."refresh_question_performance"(p_question_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_get_active_exam_link"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_get_active_exam_link"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."get_exam_result_summary"(p_exam_code text) to "service_role";
grant EXECUTE on function "public"."v5_is_staff"() to "authenticated";
grant EXECUTE on function "public"."v5_is_staff"() to "service_role";
grant EXECUTE on function "public"."v5_has_role"(required_role v5_user_role) to "authenticated";
grant EXECUTE on function "public"."v5_has_role"(required_role v5_user_role) to "service_role";
grant EXECUTE on function "public"."is_admin"() to "authenticated";
grant EXECUTE on function "public"."is_admin"() to "service_role";
grant EXECUTE on function "public"."refresh_student_performance"() to "service_role";
grant EXECUTE on function "public"."v5_question_bank_set_updated_at"() to "service_role";
grant EXECUTE on function "public"."v5_start_attempt"(p_exam_code text, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_build_exam_from_bank"(p_exam_id bigint, p_bank_question_ids bigint[]) to "authenticated";
grant EXECUTE on function "public"."v5_build_exam_from_bank"(p_exam_id bigint, p_bank_question_ids bigint[]) to "service_role";
grant EXECUTE on function "public"."v5_admin_update_question"(p_question_id bigint, p_question_text text, p_difficulty text, p_score numeric, p_explanation text, p_tags text[], p_source_page text) to "authenticated";
grant EXECUTE on function "public"."v5_admin_update_question"(p_question_id bigint, p_question_text text, p_difficulty text, p_score numeric, p_explanation text, p_tags text[], p_source_page text) to "service_role";
grant EXECUTE on function "public"."v5_admin_add_option"(p_question_id bigint, p_option_key text, p_option_text text, p_is_correct boolean, p_sort_order integer) to "authenticated";
grant EXECUTE on function "public"."v5_admin_add_option"(p_question_id bigint, p_option_key text, p_option_text text, p_is_correct boolean, p_sort_order integer) to "service_role";
grant EXECUTE on function "public"."v5_admin_archive_question"(p_question_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_archive_question"(p_question_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_delete_question"(p_question_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_delete_question"(p_question_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_publish_question"(p_question_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_publish_question"(p_question_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_create_exam"(p_exam_code text, p_title text, p_description text, p_grade_id bigint, p_field_id bigint, p_duration_minutes integer, p_randomize_questions boolean, p_randomize_options boolean, p_show_result_to_student boolean) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_exam"(p_exam_code text, p_title text, p_description text, p_grade_id bigint, p_field_id bigint, p_duration_minutes integer, p_randomize_questions boolean, p_randomize_options boolean, p_show_result_to_student boolean) to "service_role";
grant EXECUTE on function "public"."v5_admin_publish_exam"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_publish_exam"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_add_bank_question_to_exam"(p_exam_id bigint, p_bank_question_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_add_bank_question_to_exam"(p_exam_id bigint, p_bank_question_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_remove_exam_question"(p_exam_id bigint, p_question_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_remove_exam_question"(p_exam_id bigint, p_question_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_student_answers_recalculate_attempt"() to "service_role";
grant EXECUTE on function "public"."v5_finalize_attempt"(p_attempt_id uuid) to "service_role";
grant EXECUTE on function "public"."v5_close_exam"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_close_exam"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_create_exam"(p_title text, p_exam_code text, p_description text, p_grade_id bigint, p_field_id bigint, p_duration_minutes integer, p_question_ids bigint[]) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_exam"(p_title text, p_exam_code text, p_description text, p_grade_id bigint, p_field_id bigint, p_duration_minutes integer, p_question_ids bigint[]) to "service_role";
grant EXECUTE on function "public"."v5_list_staff_exam_links"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_list_staff_exam_links"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_get_saved_answers"(p_attempt_id uuid, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_get_saved_answers"(p_attempt_id uuid, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_get_saved_answers"(p_attempt_id uuid, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_get_admin_attempt_reports"(p_exam_id bigint, p_limit integer) to "authenticated";
grant EXECUTE on function "public"."v5_get_admin_attempt_reports"(p_exam_id bigint, p_limit integer) to "service_role";
grant EXECUTE on function "public"."v5_set_exam_link_active"(p_link_id bigint, p_is_active boolean) to "authenticated";
grant EXECUTE on function "public"."v5_set_exam_link_active"(p_link_id bigint, p_is_active boolean) to "service_role";
grant EXECUTE on function "public"."v5_get_admin_analytics"(p_exam_id bigint, p_limit integer) to "authenticated";
grant EXECUTE on function "public"."v5_get_admin_analytics"(p_exam_id bigint, p_limit integer) to "service_role";
grant EXECUTE on function "public"."v5_get_staff_exam_publish_list"() to "authenticated";
grant EXECUTE on function "public"."v5_get_staff_exam_publish_list"() to "service_role";
grant EXECUTE on function "public"."v5_publish_exam"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_publish_exam"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_create_student"(p_student_code text, p_full_name text) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_student"(p_student_code text, p_full_name text) to "service_role";
grant EXECUTE on function "public"."v5_admin_list_students"(p_search text) to "authenticated";
grant EXECUTE on function "public"."v5_admin_list_students"(p_search text) to "service_role";
grant EXECUTE on function "public"."v5_set_exam_link_limits"(p_link_id bigint, p_expires_at timestamp with time zone, p_max_attempts integer) to "authenticated";
grant EXECUTE on function "public"."v5_set_exam_link_limits"(p_link_id bigint, p_expires_at timestamp with time zone, p_max_attempts integer) to "service_role";
grant EXECUTE on function "public"."v5_start_exam"(p_token text, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_start_exam"(p_token text, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_start_exam"(p_token text, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_admin_set_student_active"(p_id bigint, p_active boolean) to "authenticated";
grant EXECUTE on function "public"."v5_admin_set_student_active"(p_id bigint, p_active boolean) to "service_role";
grant EXECUTE on function "public"."v5_admin_update_student"(p_id bigint, p_student_code text, p_full_name text) to "authenticated";
grant EXECUTE on function "public"."v5_admin_update_student"(p_id bigint, p_student_code text, p_full_name text) to "service_role";
grant EXECUTE on function "public"."v5_admin_set_exam_schedule"(p_exam_id bigint, p_start_at timestamp with time zone, p_end_at timestamp with time zone) to "authenticated";
grant EXECUTE on function "public"."v5_admin_set_exam_schedule"(p_exam_id bigint, p_start_at timestamp with time zone, p_end_at timestamp with time zone) to "service_role";
grant EXECUTE on function "public"."v5_admin_set_exam_status"(p_exam_id bigint, p_status v5_exam_status) to "authenticated";
grant EXECUTE on function "public"."v5_admin_set_exam_status"(p_exam_id bigint, p_status v5_exam_status) to "service_role";
grant EXECUTE on function "public"."v5_get_student_result"(p_attempt_id uuid, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_get_student_result"(p_attempt_id uuid, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_get_student_result"(p_attempt_id uuid, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_check_attempt_time"(p_attempt_id uuid) to "service_role";
grant EXECUTE on function "public"."v5_get_exam_questions"(p_attempt_id uuid, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_get_exam_questions"(p_attempt_id uuid, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_get_exam_questions"(p_attempt_id uuid, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_get_staff_question_bank"(p_search text, p_subject text, p_grade text, p_difficulty text, p_limit integer) to "authenticated";
grant EXECUTE on function "public"."v5_get_staff_question_bank"(p_search text, p_subject text, p_grade text, p_difficulty text, p_limit integer) to "service_role";
grant EXECUTE on function "public"."v5_admin_get_exam_questions"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_get_exam_questions"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_admin_question_bank_context"() to "authenticated";
grant EXECUTE on function "public"."v5_admin_question_bank_context"() to "service_role";
grant EXECUTE on function "public"."v5_save_answer"(p_attempt_id uuid, p_exam_question_id bigint, p_selected_option_id bigint, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_save_answer"(p_attempt_id uuid, p_exam_question_id bigint, p_selected_option_id bigint, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_save_answer"(p_attempt_id uuid, p_exam_question_id bigint, p_selected_option_id bigint, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_save_answers"(p_attempt_id uuid, p_student_code text, p_answers jsonb) to "anon";
grant EXECUTE on function "public"."v5_save_answers"(p_attempt_id uuid, p_student_code text, p_answers jsonb) to "authenticated";
grant EXECUTE on function "public"."v5_save_answers"(p_attempt_id uuid, p_student_code text, p_answers jsonb) to "service_role";
grant EXECUTE on function "public"."v5_admin_add_bank_questions_to_exam"(p_exam_id bigint, p_bank_question_ids bigint[]) to "authenticated";
grant EXECUTE on function "public"."v5_admin_add_bank_questions_to_exam"(p_exam_id bigint, p_bank_question_ids bigint[]) to "service_role";
grant EXECUTE on function "public"."v5_admin_create_question"(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_question"(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb) to "service_role";
grant EXECUTE on function "public"."v5_admin_create_bank_question"(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_bank_question"(p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb) to "service_role";
grant EXECUTE on function "public"."v5_admin_set_question_active"(p_question_id bigint, p_active boolean) to "authenticated";
grant EXECUTE on function "public"."v5_admin_set_question_active"(p_question_id bigint, p_active boolean) to "service_role";
grant EXECUTE on function "public"."v5_auto_create_exam_link_on_publish"() to "service_role";
grant EXECUTE on function "public"."v5_admin_get_exam_control"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_admin_get_exam_control"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_create_exam_link"(p_exam_id bigint, p_expires_at timestamp with time zone, p_max_attempts integer) to "authenticated";
grant EXECUTE on function "public"."v5_create_exam_link"(p_exam_id bigint, p_expires_at timestamp with time zone, p_max_attempts integer) to "service_role";
grant EXECUTE on function "public"."v5_validate_exam_link"(p_token text) to "anon";
grant EXECUTE on function "public"."v5_validate_exam_link"(p_token text) to "authenticated";
grant EXECUTE on function "public"."v5_validate_exam_link"(p_token text) to "service_role";
grant EXECUTE on function "public"."v5_admin_create_question_bank_question"(p_question_text text, p_subject_id bigint, p_topic_id bigint, p_difficulty text, p_score numeric, p_options jsonb) to "authenticated";
grant EXECUTE on function "public"."v5_admin_create_question_bank_question"(p_question_text text, p_subject_id bigint, p_topic_id bigint, p_difficulty text, p_score numeric, p_options jsonb) to "service_role";
grant EXECUTE on function "public"."v5_auto_link_on_publish"() to "service_role";
grant EXECUTE on function "public"."v5_admin_get_question_bank"(p_search text, p_limit integer) to "authenticated";
grant EXECUTE on function "public"."v5_admin_get_question_bank"(p_search text, p_limit integer) to "service_role";
grant EXECUTE on function "public"."v5_admin_set_question_bank_active"(p_question_id bigint, p_active boolean) to "authenticated";
grant EXECUTE on function "public"."v5_admin_set_question_bank_active"(p_question_id bigint, p_active boolean) to "service_role";
grant EXECUTE on function "public"."v5_admin_update_question"(p_question_id bigint, p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb) to "authenticated";
grant EXECUTE on function "public"."v5_admin_update_question"(p_question_id bigint, p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty v5_difficulty, p_score numeric, p_options jsonb) to "service_role";
grant EXECUTE on function "public"."v5_admin_update_question_bank_question"(p_question_id bigint, p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty text, p_score numeric, p_options jsonb) to "authenticated";
grant EXECUTE on function "public"."v5_admin_update_question_bank_question"(p_question_id bigint, p_subject_id bigint, p_topic_id bigint, p_question_text text, p_difficulty text, p_score numeric, p_options jsonb) to "service_role";
grant EXECUTE on function "public"."v5_staff_build_exam"(p_title text, p_exam_code text, p_duration_minutes integer, p_question_ids bigint[]) to "authenticated";
grant EXECUTE on function "public"."v5_staff_build_exam"(p_title text, p_exam_code text, p_duration_minutes integer, p_question_ids bigint[]) to "service_role";
grant EXECUTE on function "public"."v5_admin_add_random_bank_questions_to_exam"(p_exam_id bigint, p_count integer) to "authenticated";
grant EXECUTE on function "public"."v5_admin_add_random_bank_questions_to_exam"(p_exam_id bigint, p_count integer) to "service_role";
grant EXECUTE on function "public"."v5_import_question_from_bank"(p_bank_question_id bigint, p_exam_id bigint, p_question_order integer) to "authenticated";
grant EXECUTE on function "public"."v5_import_question_from_bank"(p_bank_question_id bigint, p_exam_id bigint, p_question_order integer) to "service_role";
grant EXECUTE on function "public"."v5_ensure_exam_link"(p_exam_id bigint) to "authenticated";
grant EXECUTE on function "public"."v5_ensure_exam_link"(p_exam_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_create_exam_link_internal"(p_exam_id bigint, p_expires_at timestamp with time zone, p_max_attempts integer) to "service_role";
grant EXECUTE on function "public"."refresh_student_question_performance"(p_student_id uuid, p_question_id bigint) to "service_role";
grant EXECUTE on function "public"."get_educational_analytics"(p_exam_code text) to "service_role";
grant EXECUTE on function "public"."v5_submit_attempt"(p_attempt_id uuid, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_submit_attempt"(p_attempt_id uuid, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_submit_attempt"(p_attempt_id uuid, p_student_code text) to "service_role";
grant EXECUTE on function "public"."v5_recalculate_attempt_result"(p_attempt_id uuid) to "service_role";
grant EXECUTE on function "public"."v5_set_updated_at"() to "service_role";
grant EXECUTE on function "public"."v5_get_admin_attempt_report_detail"(p_attempt_id uuid) to "authenticated";
grant EXECUTE on function "public"."v5_get_admin_attempt_report_detail"(p_attempt_id uuid) to "service_role";
grant EXECUTE on function "public"."calculate_exam_attempt"(p_attempt_id bigint) to "service_role";
grant EXECUTE on function "public"."v5_get_attempt_state"(p_attempt_id uuid, p_student_code text) to "anon";
grant EXECUTE on function "public"."v5_get_attempt_state"(p_attempt_id uuid, p_student_code text) to "authenticated";
grant EXECUTE on function "public"."v5_get_attempt_state"(p_attempt_id uuid, p_student_code text) to "service_role";
notify pgrst, 'reload schema';
