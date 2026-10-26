do $$declare t text;r record;begin
 foreach t in array array['organization_control','unit_aliases','unit_links','organization_changes','work_unit_origins']loop
 if has_table_privilege('authenticated','public.'||t,'select')or has_table_privilege('anon','public.'||t,'insert')or has_table_privilege('service_role','public.'||t,'update')then raise exception 'P33 raw table grant leak: %',t;end if;
 select relrowsecurity,relforcerowsecurity into r from pg_class where relname=t;if not r.relrowsecurity or not r.relforcerowsecurity then raise exception 'P33 missing forced RLS';end if;
 end loop;
 if has_function_privilege('anon','public.read_organization(uuid)','execute')or has_function_privilege('authenticated','app_private.organization_obligations(uuid,uuid,uuid)','execute')then raise exception 'P33 unauthorized execute';end if;
end$$;
select 'P33 unit changes raw/RLS/private-helper checks PASS'::text tap;
