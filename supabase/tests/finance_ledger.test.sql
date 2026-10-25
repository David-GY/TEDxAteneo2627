do $$declare t text;begin
 foreach t in array array['budget_accounts','budget_entries','actual_finance_records','actual_finance_events']loop
 if not exists(select 1 from pg_class where oid=('public.'||t)::regclass and relrowsecurity and relforcerowsecurity)then raise exception 'P27 RLS missing';end if;
 if has_table_privilege('authenticated','public.'||t,'select')or has_table_privilege('service_role','public.'||t,'insert')then raise exception 'P27 raw access leaked';end if;
 end loop;
 if has_function_privilege('anon','public.record_finance_actual(uuid,text,text,uuid,text,date,text,integer,uuid)','execute')or has_function_privilege('service_role','public.read_finance_ledger(uuid,uuid)','execute')then raise exception 'P27 command grant leaked';end if;
 begin update public.budget_entries set reason='Rewrite';raise exception 'P27 mutable ledger';exception when sqlstate '55000'then null;end;
 begin delete from public.actual_finance_records;raise exception 'P27 deletable actual';exception when sqlstate '55000'then null;end;
end$$;
select 'P27 RLS/raw grants/immutable history checks pass'::text tap;
