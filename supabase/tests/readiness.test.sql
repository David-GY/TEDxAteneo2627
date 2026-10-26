do $$declare t text;begin foreach t in array array['deliverable_readiness_policies','deliverable_readiness_events','deliverable_scope_exceptions','deliverable_external_authorizations']loop
 if not exists(select 1 from pg_class where oid=('public.'||t)::regclass and relrowsecurity and relforcerowsecurity)or has_table_privilege('authenticated','public.'||t,'select')or has_table_privilege('service_role','public.'||t,'insert')then raise exception 'P29 raw/RLS violation';end if;end loop;
 if has_function_privilege('anon','public.accept_deliverable(uuid,text,text,integer,integer,text,uuid)','execute')or has_function_privilege('service_role','public.read_deliverable_readiness(uuid)','execute')then raise exception 'P29 command grant leak';end if;
 begin update public.deliverable_readiness_events set reason='Rewrite';raise exception 'Mutable acceptance';exception when sqlstate '55000'then null;end;
end$$;select 'P29 raw/RLS/immutable acceptance checks pass'::text tap;
