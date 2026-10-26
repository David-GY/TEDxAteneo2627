do $$begin
 if has_table_privilege('authenticated','public.notifications','select')or has_table_privilege('service_role','public.outbox_jobs','update')or has_function_privilege('authenticated','public.claim_notification_jobs(integer)','execute')or has_function_privilege('anon','public.read_notifications(uuid,integer)','execute')then raise exception 'P30 grant leak';end if;
 if exists(select 1 from pg_class where relname in('notifications','notification_preferences')and(not relrowsecurity or not relforcerowsecurity))then raise exception 'P30 missing forced RLS';end if;
end$$;select 'P30 forced RLS/private routing/service-only dispatcher passes'::text tap;
