do $$begin
 if has_table_privilege('authenticated','public.delegation_ceilings','select')or has_table_privilege('service_role','public.verified_app_custodians','insert')or has_function_privilege('anon','public.preflight_access_change(uuid,jsonb)','execute')or has_function_privilege('authenticated','app_private.access_verified_custodian(uuid)','execute')then raise exception 'P34 raw/helper grant leak';end if;
 if exists(select 1 from pg_class where relname in('delegation_ceilings','verified_app_custodians')and(not relrowsecurity or not relforcerowsecurity))then raise exception 'P34 missing forced RLS';end if;
end$$;
select 'P34 inspection/preflight RLS and execute boundary PASS; full mutation acceptance unverified'::text tap;
do $$declare role_id uuid;begin
 insert into public.roles(organization_id,term_id,code,name,privileged)values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221','fictional_p34_catalog','Fictional P34 catalog test',true)returning id into role_id;
 insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221',role_id,'workspace.read','work'),('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221',role_id,'committee.manage','work'),('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221',role_id,'mcd.review','unit');
 begin insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221',role_id,'finance.review','work');raise exception 'P34 sensitive work-scope constraint opened';exception when check_violation then null;end;
 if has_table_privilege('authenticated','public.role_assignments','update')or has_table_privilege('authenticated','public.role_permissions','insert')then raise exception 'P34 existing raw role mutation path open';end if;
end$$;
select 'P34 restored exact-work catalog and preserved MCD/sensitive scope constraints PASS'::text tap;
