begin;
select '1..2' as tap;
do $$begin
 if has_function_privilege('anon','public.read_committee_timeline(uuid,jsonb,integer,integer)','EXECUTE')
 or has_function_privilege('service_role','public.read_committee_timeline(uuid,jsonb,integer,integer)','EXECUTE')
 or not has_function_privilege('authenticated','public.read_committee_timeline(uuid,jsonb,integer,integer)','EXECUTE')
 then raise exception 'P16A_A1 projection privilege assertion failed';end if;
end$$;
select 'ok 1 - P16A_A1 projection function: authenticated-only bounded interface' as tap;
do $$begin
 if not exists(select 1 from pg_constraint where conname='work_schedule_calendar_range' and convalidated)
 or not exists(select 1 from information_schema.columns where table_schema='public' and table_name='work_items' and column_name='planned_start_on' and is_nullable='YES' and column_default is null)
 or has_column_privilege('authenticated','public.work_items','planned_start_on','UPDATE')
 or has_function_privilege('anon','public.update_work_schedule(uuid,date,integer,uuid)','EXECUTE')
 or has_function_privilege('service_role','public.update_work_schedule(uuid,date,integer,uuid)','EXECUTE')
 or not has_function_privilege('authenticated','public.update_work_schedule(uuid,date,integer,uuid)','EXECUTE')
 or not exists(select 1 from pg_proc where oid='public.update_work_schedule(uuid,date,integer,uuid)'::regprocedure and prosecdef and proconfig @> array['search_path=""'])
 then raise exception 'P16A_A2 schema/authority assertion failed';end if;
end$$;
select 'ok 2 - P16A_A2 schedule foundation: nullable canonical dates, invariant, privileges and function hardening' as tap;
rollback;
