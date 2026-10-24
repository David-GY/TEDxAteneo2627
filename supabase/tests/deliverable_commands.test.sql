begin;
select '1..3' as tap;
create function pg_temp.require(ok boolean,message text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'Assertion failed: %',message;end if;end$$;
create function pg_temp.rejects(command text,expected text) returns void language plpgsql as $$begin
  begin execute command;exception when others then if sqlstate=expected then return;end if;raise;end;
  raise exception 'Expected rejected command %',expected;
end$$;
create function pg_temp.data() returns jsonb language sql as $$select jsonb_build_object(
 'title','Fictional internal checklist','summary','Synthetic internal output','body','Fictional working notes',
 'ownerId','33333333-3333-4333-8333-333333333331','leadUnitId','44444444-4444-4444-8444-444444444441',
 'phase','Preparation','outcome','Internal checklist','criteria','Checklist reviewed with team','dueOn','2027-04-10','dueAt',null,'classification','ordinary','reason','Fictional scoped change')$$;
grant execute on function pg_temp.require(boolean,text),pg_temp.rejects(text,text),pg_temp.data() to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333331',true);
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data(),false,gen_random_uuid())$q$,'42501');
select pg_temp.rejects($q$select public.create_work_item('22222222-2222-4222-8222-222222222221','deliverable','Bypass','','','ordinary')$q$,'55000');
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data()||jsonb_build_object('ownerId','33333333-3333-4333-8333-333333333332'),true,gen_random_uuid())$q$,'42501');
select set_config('p09.created',(public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data(),true,'09000000-0000-4000-8000-000000000001')->>'workItemId'),true);
select pg_temp.require(public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data(),true,'09000000-0000-4000-8000-000000000001')->>'workItemId'=current_setting('p09.created'),'identical create retry returns earlier UUID');
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data()||' {"title":"Changed"}',true,'09000000-0000-4000-8000-000000000001')$q$,'22023');
reset role;
update public.members set account_state='suspended' where id='33333333-3333-4333-8333-333333333331';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333332',true);
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data(),false,gen_random_uuid())$q$,'22023');
select pg_temp.require(public.read_deliverable_authoring('22222222-2222-4222-8222-222222222221')->'queue' @> jsonb_build_array(jsonb_build_object('id',current_setting('p09.created'))),'departed owner appears in scoped reassignment queue');
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222222',pg_temp.data(),false,gen_random_uuid())$q$,'42501');
reset role;
update public.members set account_state='active' where id='33333333-3333-4333-8333-333333333331';
insert into public.members(id,organization_id,email,display_name,account_state) values('33333333-3333-4333-8333-333333333334','11111111-1111-4111-8111-111111111111','fictional.other-term@example.invalid','Fictional other-term owner','active');
insert into public.term_memberships(organization_id,term_id,member_id,status,joined_at,ends_at) values('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333334','active',statement_timestamp()-interval'1 day',statement_timestamp()+interval'30 days');
set local role authenticated;
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data()||jsonb_build_object('ownerId','33333333-3333-4333-8333-333333333334'),false,gen_random_uuid())$q$,'22023');
select pg_temp.rejects($q$select public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data()||jsonb_build_object('leadUnitId','44444444-4444-4444-8444-444444444444'),false,gen_random_uuid())$q$,'22023');
select pg_temp.require(public.transition_deliverable(current_setting('p09.created')::uuid,'approve_proposal','Scoped head approves commitment',null,1,gen_random_uuid())->>'version'='2','manager approves proposal');
select 'ok 1 - P09_A1: current scoped authority, active same-term owner/unit, self-proposal only, generic bypass denied and reassignment queue' as tap;
select public.update_deliverable(current_setting('p09.created')::uuid,pg_temp.data()||'{"dueOn":"2027-04-12","criteria":"Revised checklist criteria","reason":"Synthetic schedule extension"}',2,'09000000-0000-4000-8000-000000000002');
select pg_temp.require(public.update_deliverable(current_setting('p09.created')::uuid,pg_temp.data()||'{"dueOn":"2027-04-12","criteria":"Revised checklist criteria","reason":"Synthetic schedule extension"}',2,'09000000-0000-4000-8000-000000000002')->>'version'='3','exact update retry has no duplicate effects');
select pg_temp.rejects($q$select public.update_deliverable(current_setting('p09.created')::uuid,pg_temp.data(),2,gen_random_uuid())$q$,'40001');
select pg_temp.require((select count(*)=3 from public.deliverable_revisions where work_item_id=current_setting('p09.created')::uuid),'create/approve/edit immutable snapshots only');
select pg_temp.require((select reason='Synthetic schedule extension' and actor_id=auth.uid() and criteria_revision=2 from public.deliverable_revisions where work_item_id=current_setting('p09.created')::uuid and work_version=3),'change reason/actor and criteria revision attributed');
select pg_temp.require(public.read_deliverable(current_setting('p09.created')::uuid)->>'originalDueOn'='2027-04-10' and public.read_deliverable(current_setting('p09.created')::uuid)->>'dueOn'='2027-04-12','original deadline survives extension');
select 'ok 2 - P09_A2: original deadline, reasoned actor snapshot, criteria revisions, retry deduplication and stale conflict' as tap;
select pg_temp.rejects($q$update public.work_items set status_id=(select id from public.status_definitions where stable_key='p09_accepted' limit 1) where id=current_setting('p09.created')::uuid$q$,'42501');
select pg_temp.rejects($q$select public.update_work_item(current_setting('p09.created')::uuid,'Bypass','','',3,gen_random_uuid())$q$,'55000');
select pg_temp.rejects($q$update public.deliverables set workflow_state='accepted' where work_item_id=current_setting('p09.created')::uuid$q$,'42501');
select pg_temp.rejects($q$select public.transition_deliverable(current_setting('p09.created')::uuid,'accept','Skip owner',null,3,gen_random_uuid())$q$,'42501');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333331',true);
select pg_temp.rejects($q$select public.transition_deliverable(current_setting('p09.created')::uuid,'submit','No evidence','',3,gen_random_uuid())$q$,'55000');
select public.transition_deliverable(current_setting('p09.created')::uuid,'start','Begin work',null,3,gen_random_uuid());
select public.transition_deliverable(current_setting('p09.created')::uuid,'submit','Checklist complete','Fictional final checklist reference',4,gen_random_uuid());
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333332',true);
select pg_temp.rejects($q$select public.transition_deliverable(current_setting('p09.created')::uuid,'accept','Unmet criteria','Not yet verified',5,gen_random_uuid(),1)$q$,'55000');
select pg_temp.rejects($q$select public.transition_deliverable(current_setting('p09.created')::uuid,'accept','Unresolved gates','Verified revised criteria',5,'09000000-0000-4000-8000-000000000003',2)$q$,'55000');
select pg_temp.require((select count(*)=5 from public.deliverable_revisions where work_item_id=current_setting('p09.created')::uuid),'denied transition writes no revision');
select pg_temp.require(not exists(select 1 from public.audit_events where request_id='09000000-0000-4000-8000-000000000003'),'denied transition writes no success audit');
reset role;
select pg_temp.require(not exists(select 1 from public.idempotency_keys where client_key='09000000-0000-4000-8000-000000000003'),'denied transition creates no receipt');
-- Trusted-only fixture: no governed plans/publicity/contributions. There is no client write/waiver RPC.
insert into public.deliverable_gate_assessments(work_item_id,work_version,gate,disposition,reason,assessed_by)
select current_setting('p09.created')::uuid,4,gate,'not_applicable','Fictional internal checklist only','66666666-6666-4666-8666-666666666662' from unnest(array['finance','publicity','contributions'])gate;
set local role authenticated;
select pg_temp.rejects($q$select public.transition_deliverable(current_setting('p09.created')::uuid,'accept','Stale gate version','Verified revised criteria',5,gen_random_uuid(),2)$q$,'55000');
reset role;
insert into public.deliverable_gate_assessments(work_item_id,work_version,gate,disposition,reason,assessed_by)
select current_setting('p09.created')::uuid,5,gate,'not_applicable','Fictional internal checklist only','66666666-6666-4666-8666-666666666662' from unnest(array['finance','publicity','contributions'])gate;
set local role authenticated;
select pg_temp.require(public.transition_deliverable(current_setting('p09.created')::uuid,'accept','Independent scoped acceptance','Verified each revised checklist criterion',5,gen_random_uuid(),2)->>'version'='6','authorized clean non-governed acceptance succeeds');
select pg_temp.require((select workflow_state='accepted' and final_evidence='Fictional final checklist reference' from public.deliverable_revisions where work_item_id=current_setting('p09.created')::uuid and work_version=6),'acceptance preserves final evidence');
select pg_temp.rejects($q$update public.deliverable_revisions set reason='overwrite' where work_item_id=current_setting('p09.created')::uuid$q$,'42501');
select pg_temp.rejects($q$insert into public.deliverable_gate_assessments values(current_setting('p09.created')::uuid,6,'finance','not_applicable','bypass','66666666-6666-4666-8666-666666666662',now())$q$,'42501');
select set_config('p09.self',(public.create_deliverable('22222222-2222-4222-8222-222222222221',pg_temp.data()||'{"ownerId":"33333333-3333-4333-8333-333333333332"}',false,gen_random_uuid())->>'workItemId'),true);
select public.transition_deliverable(current_setting('p09.self')::uuid,'submit','My finished output','Fictional final evidence',1,gen_random_uuid());
select pg_temp.rejects($q$select public.transition_deliverable(current_setting('p09.self')::uuid,'accept','Self acceptance','Verified criteria',2,gen_random_uuid(),1)$q$,'42501');
select public.transition_deliverable(current_setting('p09.self')::uuid,'revise','Need corrections',null,2,gen_random_uuid());
select public.transition_deliverable(current_setting('p09.self')::uuid,'cancel','Cancelled synthetic commitment',null,3,gen_random_uuid());
select 'ok 3 - P09_A3: direct completion denied, evidence/current gates required, stale assessments rejected, independent clean acceptance atomic' as tap;
rollback;
