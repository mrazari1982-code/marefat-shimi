create or replace function public.v5_auto_create_exam_link_on_publish()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    perform public.v5_create_exam_link_internal(new.id, null, 1);
  end if;
  return new;
end;
$$;

drop trigger if exists v5_exam_auto_link_on_publish on public.v5_exams;

create trigger v5_exam_auto_link_on_publish
after insert or update of status on public.v5_exams
for each row
execute function public.v5_auto_create_exam_link_on_publish();

-- Backfill an active link for every already-published exam that does not have one.
do $$
declare
  r record;
begin
  for r in
    select e.id
    from public.v5_exams e
    where e.status = 'published'
      and not exists (
        select 1
        from public.v5_exam_links l
        where l.exam_id = e.id
          and l.is_active = true
      )
  loop
    perform public.v5_create_exam_link_internal(r.id, null, 1);
  end loop;
end;
$$;
