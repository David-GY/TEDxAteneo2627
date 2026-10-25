do $$declare t text;begin foreach t in array array['publicity_reviews','publicity_approvals','publicity_review_policies','publicity_authority_designations','publicity_review_bindings','publicity_approval_events']loop
 if not exists(select 1 from pg_class where oid=('public.'||t)::regclass and relrowsecurity and relforcerowsecurity)or has_table_privilege('authenticated','public.'||t,'select')or has_table_privilege('service_role','public.'||t,'insert')then raise exception 'P28 raw/RLS violation';end if;end loop;
 if has_function_privilege('anon','public.decide_publicity_request(uuid,integer,integer,text,text,text,timestamptz,uuid)','execute')or has_function_privilege('service_role','public.read_publicity_request(uuid,uuid,integer)','execute')then raise exception 'P28 grant leak';end if;
 begin update public.publicity_reviews set payload='{}';raise exception 'Mutable publicity';exception when sqlstate '55000'then null;end;
 begin delete from public.publicity_approvals;raise exception 'Deletable decision';exception when sqlstate '55000'then null;end;end$$;
select 'P28 RLS/raw/immutable history checks pass'::text tap;
