-- Catalog/privilege assertions complement the actual command/state tests in test-config-publication.cjs.
do $$begin
 if(select count(*)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
  and c.relname in('configuration_drafts','configuration_controls','configuration_publications')and c.relrowsecurity and c.relforcerowsecurity)<>3
 then raise exception 'configuration RLS missing';end if;
 if has_table_privilege('authenticated','public.configuration_drafts','SELECT')
  or has_table_privilege('service_role','public.configuration_publications','INSERT')
  or has_function_privilege('anon','public.publish_configuration(uuid,integer,text,text,uuid,uuid)','EXECUTE')
  or has_function_privilege('authenticated','app_private.configuration_problem(public.request_types,public.configuration_drafts,uuid)','EXECUTE')
 then raise exception 'configuration privilege leak';end if;
end$$;
select 'ok - configuration boundary: forced RLS, denied raw writes/reads/private helpers/anonymous publication'::text tap;
