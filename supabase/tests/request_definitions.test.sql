begin;
select '1..3' as tap;
create function pg_temp.require(ok boolean) returns void language plpgsql as $$begin perform set_config('p19.assert',(coalesce(nullif(current_setting('p19.assert',true),''),'0')::int+1)::text,true);if ok is distinct from true then raise exception 'P19 assertion failed %',current_setting('p19.assert');end if;end$$;
create function pg_temp.rejects(command text,code text) returns void language plpgsql as $$begin begin execute command;exception when others then if sqlstate=code then return;end if;raise;end;raise exception 'Expected P19 rejection %',code;end$$;
grant execute on function pg_temp.require(boolean),pg_temp.rejects(text,text) to authenticated;
select set_config('p19.type',(select id::text from public.request_types where term_id='22222222-2222-4222-8222-222222222221' and stable_key='general'),true);
select set_config('p19.form',(select schema_json::text from public.form_versions where request_type_id=current_setting('p19.type')::uuid),true);
select pg_temp.require((select count(*)=3 and bool_and(not authority_confirmed and not live_enabled and receiving_unit_id is null) from public.request_types where term_id='22222222-2222-4222-8222-222222222221'));
select pg_temp.rejects($q$update public.form_versions set schema_json=jsonb_set(schema_json,'{fields,0,label}','"Changed"') where request_type_id=current_setting('p19.type')::uuid$q$,'55000');
select pg_temp.rejects($q$delete from public.workflow_versions where request_type_id=current_setting('p19.type')::uuid$q$,'55000');
select pg_temp.require((select schema_json::text=current_setting('p19.form') from public.form_versions where request_type_id=current_setting('p19.type')::uuid));
-- Explicit synthetic positive readiness, then archive/revocation negatives; no live case is created.
insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)
 values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221','66666666-6666-4666-8666-666666666661','44444444-4444-4444-8444-444444444442','backup_contact',statement_timestamp()-interval '1 day',statement_timestamp()+interval '1 day','66666666-6666-4666-8666-666666666662');
insert into public.workflow_versions(request_type_id,version,state,published_at,definition_json)
 values(current_setting('p19.type')::uuid,2,'published',statement_timestamp(),'{"schemaVersion":1,"stages":[{"key":"triage","label":"Fictional reviewer","review":"one","reviewers":["66666666-6666-4666-8666-666666666662"],"entryFields":["purpose"],"outcome":"pending","reminderDays":7}]}');
update public.request_types set receiving_unit_id='44444444-4444-4444-8444-444444444442',primary_contact_id='66666666-6666-4666-8666-666666666662',backup_contact_id='66666666-6666-4666-8666-666666666661',authority_confirmed=true,live_enabled=true,
 workflow_version_id=(select id from public.workflow_versions where request_type_id=current_setting('p19.type')::uuid and version=2) where id=current_setting('p19.type')::uuid;
select pg_temp.require((select app_private.request_service_ready(r) from public.request_types r where id=current_setting('p19.type')::uuid));
update public.org_units set archived_at=statement_timestamp() where id='44444444-4444-4444-8444-444444444442';
select pg_temp.require((select not app_private.request_service_ready(r) from public.request_types r where id=current_setting('p19.type')::uuid));
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333332',true);
select pg_temp.rejects($q$select public.create_work_item('22222222-2222-4222-8222-222222222221','request','Bypass','','{}','ordinary',null,null,null,gen_random_uuid())$q$,'55000');
select pg_temp.rejects($q$insert into public.request_types(organization_id,term_id,stable_key,label,need,governed_kind,process_note) values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222221','forged','Forged','Bypass','general','Bypass')$q$,'42501');
reset role;
select 'ok 1 - P19_A1 published form/workflow immutable; positive readiness becomes false on service archive; generic request bypass and direct configuration writes denied' as tap;

select app_private.validate_form_definition(current_setting('p19.form')::jsonb,false);
select pg_temp.rejects($q$insert into public.form_versions(request_type_id,version,state,schema_json) values(current_setting('p19.type')::uuid,5,'draft',current_setting('p19.form')::jsonb||'{"default":"PRIVATE FINANCIAL VALUE"}')$q$,'22023');
select app_private.validate_form_condition('{"op":"eq","field":"purpose","value":"support"}',current_setting('p19.form')::jsonb->'fields');
select pg_temp.rejects($q$select app_private.validate_form_condition('{"op":"gt","field":"purpose","value":3}',current_setting('p19.form')::jsonb->'fields')$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_form_definition(current_setting('p19.form')::jsonb||'{"script":"alert(1)"}',false)$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_form_definition(jsonb_set(current_setting('p19.form')::jsonb,'{fields}',(current_setting('p19.form')::jsonb->'fields')||(current_setting('p19.form')::jsonb->'fields')),false)$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_form_definition(jsonb_set(current_setting('p19.form')::jsonb,'{fields,0,requiredWhen}','{"op":"javascript","value":"true"}'),false)$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_form_definition(jsonb_set(current_setting('p19.form')::jsonb,'{fields,0,regex}','".*"'),false)$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_form_definition(jsonb_set(current_setting('p19.form')::jsonb,'{fields,0,key}','"authorized_ceiling"'),false)$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_form_definition(jsonb_set(current_setting('p19.form')::jsonb,'{fields,0,classification}','"confidential"'),false)$q$,'22023');
select pg_temp.rejects($q$select app_private.validate_workflow_definition('{"schemaVersion":1,"stages":[{"key":"x","script":"SQL"}]}')$q$,'22023');
select pg_temp.require((select schema_json::text=current_setting('p19.form') from public.form_versions where request_type_id=current_setting('p19.type')::uuid));
select 'ok 2 - P19_A2 unknown/duplicate/protected/confidential keys and executable/regex conditions rejected; original schema unchanged' as tap;

-- A private draft exists but never reaches either generic catalog or exact published definition.
insert into public.form_versions(request_type_id,version,state,schema_json) values(current_setting('p19.type')::uuid,2,'draft',jsonb_set(current_setting('p19.form')::jsonb,'{fields,0,label}','"PRIVATE DRAFT sentinel"'));
update public.private_profiles set phone='PRIVATE PHONE sentinel' where member_id='33333333-3333-4333-8333-333333333331';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333332',true);
select pg_temp.require(jsonb_array_length(public.read_request_catalog('22222222-2222-4222-8222-222222222221')->'items')=3);
select pg_temp.require((public.read_request_catalog('22222222-2222-4222-8222-222222222221',current_setting('p19.type')::uuid)->'items'->0->'form')::text=current_setting('p19.form'));
select pg_temp.require(public.read_request_catalog('22222222-2222-4222-8222-222222222221')::text not like '%PRIVATE%');
select pg_temp.require(public.read_request_catalog('22222222-2222-4222-8222-222222222221',current_setting('p19.type')::uuid)::text not like '%PRIVATE%');
select pg_temp.require(public.read_request_catalog('22222222-2222-4222-8222-222222222222') is null);
select pg_temp.rejects($q$select * from public.form_versions$q$,'42501');
select pg_temp.rejects($q$select app_private.validate_form_definition('{}',false)$q$,'42501');
reset role;
update public.term_memberships set status='revoked' where member_id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select pg_temp.require(public.read_request_catalog('22222222-2222-4222-8222-222222222221') is null);
reset role;
select pg_temp.require(not has_function_privilege('anon','public.read_request_catalog(uuid,uuid)','execute') and not has_function_privilege('service_role','public.read_request_catalog(uuid,uuid)','execute'));
select 'ok 3 - P19_A3 current scoped published-only projection excludes drafts/private profiles/workflow identities/case data; unauthorized roles/terms denied' as tap;
rollback;
