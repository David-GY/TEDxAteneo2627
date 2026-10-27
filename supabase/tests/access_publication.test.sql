do $$declare t text;begin
 foreach t in array array['access_control','access_role_versions','access_assignment_sources','access_custody_nominations','access_changes']loop
  if has_table_privilege('authenticated','public.'||t,'select,insert,update,delete')or has_table_privilege('service_role','public.'||t,'select,insert,update,delete')or not exists(select 1 from pg_class where relname=t and relrowsecurity and relforcerowsecurity)then raise exception 'P34 publication raw/RLS boundary %',t;end if;
 end loop;
 if has_table_privilege('authenticated','app_private.effective_role_assignments','select')or has_function_privilege('authenticated','app_private.access_lineage_current(uuid,uuid[])','execute')or has_function_privilege('anon','public.publish_access_change(uuid,text,jsonb,integer,text,text,uuid)','execute')then raise exception 'P34 publication helper/view/anonymous leak';end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where(n.nspname||'.'||p.proname)in('public.has_capability','public.has_work_capability','app_private.finance_role','app_private.publicity_role','app_private.workflow_role','app_private.active_guest_sponsor','app_private.readiness_authority')and p.prosrc not like '%effective_role_assignments%')then raise exception 'P34 missing current-lineage authority consumer';end if;
end$$;
select 'P34 publication raw/RLS/private-helper and central authority lineage guards PASS'::text tap;
