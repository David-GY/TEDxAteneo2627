-- Canonicalize the two associative CHECK expressions that pg_dump/pg_restore
-- flattened on native PostgreSQL. Rebuild validated constraints with the same
-- predicates and names. Do not bless other structural differences.
begin;
do $$
begin
  if not app_private.disposition_catalog_current() then
    raise exception using errcode='55000', message='privacy_disposition_catalog_changed';
  end if;
end;
$$;

alter table public.assets drop constraint assets_filename_check,
  add constraint assets_filename_check check(length(filename) >= 1 and length(filename) <= 160 and filename !~ '[\r\n]');

alter table public.work_items drop constraint work_schedule_calendar_range,
  add constraint work_schedule_calendar_range check(planned_start_on is null or (
    planned_start_on >= date '0001-01-01' and planned_start_on <= date '9999-12-31'
    and planned_start_on <= coalesce(due_on,(due_at at time zone 'Asia/Manila')::date,planned_start_on)
  ));

update app_private.disposition_sources
set structure_hash=app_private.disposition_structure(source_key)
where source_key in ('public.assets','public.work_items');
commit;
