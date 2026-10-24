begin;
select '1..3' as tap;
create function pg_temp.fid(s text) returns uuid language sql immutable as $$select md5('P07:'||s)::uuid$$;
create function pg_temp.login(s text) returns void language sql as $$select set_config('request.jwt.claim.sub',pg_temp.fid(s)::text,true)::void$$;
create function pg_temp.require(ok boolean,message text) returns void language plpgsql as $$begin
  if ok is distinct from true then raise exception 'Assertion failed: %',message; end if;
end$$;
create function pg_temp.reject(command text,expected text) returns void language plpgsql as $$begin
  begin execute command; exception when others then if sqlstate=expected then return; end if; raise; end;
  raise exception 'Expected rejection: %',command;
end$$;
grant execute on function pg_temp.fid(text),pg_temp.login(text),pg_temp.require(boolean,text),pg_temp.reject(text,text) to authenticated,anon;
insert into public.organizations(id,slug,name) values(pg_temp.fid('org'),'p07-fictional','Fictional P07 workspace'),(pg_temp.fid('other-org'),'p07-other','Fictional other workspace');
insert into public.terms(id,organization_id,label,event_date,starts_on,closes_on,state)
select pg_temp.fid(s||'-term'),pg_temp.fid(s),'Fictional term',current_date,current_date-30,current_date+30,'active' from(values('org'),('other-org'))v(s);
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.fid(s),s||case when s='guest' then '@example.invalid' else '@student.ateneo.edu' end,statement_timestamp()
from unnest(array['owner','peer','outsider','editor','role-reader','unit-peer','other-owner','guest'])s;
insert into auth.identities(provider_id,user_id,provider,identity_data)
select id::text,id,'google',jsonb_build_object('email',email,'email_verified',true) from auth.users where id in
  (select pg_temp.fid(s) from unnest(array['owner','peer','outsider','editor','role-reader','unit-peer','other-owner','guest'])s);
insert into public.members(id,organization_id,auth_user_id,email,display_name,account_state)
select pg_temp.fid(s),pg_temp.fid(case when s='other-owner' then 'other-org' else 'org' end),pg_temp.fid(s),s||'@student.ateneo.edu','Fictional '||s,'active'
from unnest(array['owner','peer','outsider','editor','role-reader','unit-peer','other-owner'])s;
insert into public.term_memberships(id,organization_id,term_id,member_id,status,joined_at,ends_at)
select pg_temp.fid('tm-'||s),pg_temp.fid(case when s='other-owner' then 'other-org' else 'org' end),
pg_temp.fid(case when s='other-owner' then 'other-org-term' else 'org-term' end),pg_temp.fid(s),'active',statement_timestamp()-interval'1 day',statement_timestamp()+interval'20 days'
from unnest(array['owner','peer','outsider','editor','role-reader','unit-peer','other-owner'])s;
insert into public.org_units(id,organization_id,term_id,code,name)
values(pg_temp.fid('unit'),pg_temp.fid('org'),pg_temp.fid('org-term'),'FICTIONAL','Fictional production support');
insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)
values(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('tm-unit-peer'),pg_temp.fid('unit'),'member',statement_timestamp()-interval'1 day',statement_timestamp()+interval'20 days',pg_temp.fid('tm-owner'));
insert into public.roles(id,organization_id,term_id,code,name)
select pg_temp.fid(s),pg_temp.fid('org'),pg_temp.fid('org-term'),replace(s,'-','_'),'Fictional '||s from unnest(array['reader-role','sponsor-role','work-role'])s;
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
values(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('reader-role'),'workspace.read','term'),
(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('sponsor-role'),'roles.manage','term'),
(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('work-role'),'workspace.read','work');
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)
select pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('tm-'||s),pg_temp.fid('reader-role'),'term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'20 days',pg_temp.fid('tm-owner')
from unnest(array['owner','peer','outsider','editor','unit-peer'])s;
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)
values(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('tm-owner'),pg_temp.fid('sponsor-role'),'term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'20 days',pg_temp.fid('tm-owner'));
create temp table refs(name text primary key,result jsonb);
create temp table checks(name text primary key,result jsonb);
grant all on refs,checks to authenticated;
create function pg_temp.item(s text) returns uuid language sql as $$select (result->>'workItemId')::uuid from refs where name=s$$;
grant execute on function pg_temp.item(text) to authenticated,anon;
set local role authenticated;
select pg_temp.login('owner');
insert into refs values('parent',public.create_work_item(pg_temp.fid('org-term'),'task','RESTRICTED PARENT','Private summary','RESTRICTED PARENT BODY','restricted',null,null,null,pg_temp.fid('create-parent')));
insert into refs values('child',public.create_work_item(pg_temp.fid('org-term'),'task','Shared child','Child summary','CHILD BODY','restricted',null,pg_temp.item('parent'),1,pg_temp.fid('create-child')));
insert into refs values('sibling',public.create_work_item(pg_temp.fid('org-term'),'task','RESTRICTED SIBLING','Private sibling','SIBLING BODY','restricted',null,pg_temp.item('parent'),1,pg_temp.fid('create-sibling')));
insert into refs values('ordinary',public.create_work_item(pg_temp.fid('org-term'),'deliverable','Ordinary draft summary','Core-safe summary','PARTICIPANT DETAIL','ordinary',null,null,null,pg_temp.fid('create-ordinary')));
insert into refs values('request',public.create_work_item(pg_temp.fid('org-term'),'request','Draft request','','Request draft','ordinary',null,null,null,pg_temp.fid('create-request')));
insert into refs values('announcement',public.create_work_item(pg_temp.fid('org-term'),'announcement','Draft announcement','','Unpublished detail','ordinary',null,null,null,pg_temp.fid('create-announcement')));
insert into refs values('peer-grant',public.grant_work_access(pg_temp.item('child'),pg_temp.fid('peer'),null,null,'read',statement_timestamp()+interval'2 days',1,pg_temp.fid('grant-peer')));
insert into refs values('editor-grant',public.grant_work_access(pg_temp.item('child'),pg_temp.fid('editor'),null,null,'edit',statement_timestamp()+interval'2 days',2,pg_temp.fid('grant-editor')));
insert into refs values('unit-grant',public.grant_work_access(pg_temp.item('sibling'),null,pg_temp.fid('unit'),null,'read',statement_timestamp()+interval'2 days',1,pg_temp.fid('grant-unit')));
insert into refs values('invitation',public.create_guest_invitation(pg_temp.fid('org-term'),'guest@example.invalid',pg_temp.fid('invite')));
insert into refs values('guest-grant',public.grant_work_access(pg_temp.item('child'),null,null,((select result from refs where name='invitation')->>'id')::uuid,'read',statement_timestamp()+interval'2 days',3,pg_temp.fid('grant-guest')));
select pg_temp.require(public.read_work_parent(pg_temp.item('child'))->>'id'=pg_temp.item('parent')::text,'owner reads independently authorized parent summary');
select pg_temp.require((select value->>'scopeMode'='explicit_records' and (value->>'sharedRecordCount')::integer=1 from jsonb_array_elements(public.list_guest_invitations(pg_temp.fid('org-term'))) where value->>'id'=(select result->>'id' from refs where name='invitation')),'sponsor preview counts only attached records');
reset role;
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,work_id,effective_from,effective_to,granted_by)
values(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('tm-role-reader'),pg_temp.fid('work-role'),'work',pg_temp.item('child'),statement_timestamp()-interval'1 day',statement_timestamp()+interval'20 days',pg_temp.fid('tm-owner'));
set constraints all immediate;
set constraints all deferred;
set local role authenticated;
select pg_temp.login('outsider');
select pg_temp.require((select count(*)=3 from public.work_items),'ordinary summaries only');
select pg_temp.require((select count(*)=0 from public.tasks) and (select count(*)=0 from public.deliverables),'ordinary summaries never expose participant details');
select pg_temp.require((select count(*)=0 from public.audit_events),'summary access does not expose detail audit');
select pg_temp.login('peer');
select pg_temp.require((select body='CHILD BODY' from public.tasks where work_item_id=pg_temp.item('child')),'explicit child detail read');
select pg_temp.require((select count(*)=0 from public.work_items where id in(pg_temp.item('parent'),pg_temp.item('sibling'))),'no parent/sibling metadata');
select pg_temp.require(public.read_work_parent(pg_temp.item('child')) is null,'parent lookup cannot bypass independent parent access');
select pg_temp.require((select count(*)=1 from public.record_grants),'only own grant, not unrelated principals');
select pg_temp.reject($q$select parent_work_item_id from public.work_items where id=pg_temp.item('child')$q$,'42501');
select pg_temp.reject($q$update public.work_items set status_id=pg_temp.fid('fake-status') where id=pg_temp.item('child')$q$,'42501');
select pg_temp.reject($q$update public.work_items set owner_member_id=pg_temp.fid('peer') where id=pg_temp.item('child')$q$,'42501');
select pg_temp.reject($q$update public.tasks set body='Direct bypass' where work_item_id=pg_temp.item('child')$q$,'42501');
select pg_temp.login('role-reader');
select pg_temp.require(public.has_work_capability(pg_temp.item('child'),'workspace.read') and not public.has_capability(pg_temp.fid('org-term'),'workspace.read'),'work role never becomes term authority');
select pg_temp.require((select count(*)=1 from public.work_items) and (select count(*)=1 from public.tasks),'work role only selected child');
select pg_temp.login('unit-peer');
select pg_temp.require((select count(*)=1 from public.tasks where work_item_id=pg_temp.item('sibling')),'effective unit grants apply to exact record');
select pg_temp.login('guest');
select pg_temp.require((public.redeem_guest_invitation((select result->>'token' from refs where name='invitation'))->>'sharedRecords')::integer=1,'redemption returns actual attached record count');
select pg_temp.require((select count(*)=1 from public.work_items) and (select count(*)=1 from public.tasks),'guest exact child only, no core summaries');
select pg_temp.require(public.read_work_parent(pg_temp.item('child')) is null,'guest child scope cannot enumerate parent');
select pg_temp.require((select count(*)=0 from public.read_directory(pg_temp.fid('org-term'))),'guest record access grants no directory');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('org-term'))->>'scopeMode'='explicit_records'
  and jsonb_array_length(public.read_guest_contacts(pg_temp.fid('org-term'))->'sharedContacts')=1
  and public.read_guest_contacts(pg_temp.fid('org-term'))->'sharedContacts'->0->>'organizationContact'='owner@student.ateneo.edu','only explicit record owner organization contact shared');
select pg_temp.require(not (public.read_guest_contacts(pg_temp.fid('org-term'))->'sharedContacts'->0 ? 'phone'),'no private contact fields in guest scoped contacts');
select pg_temp.reject($q$select public.update_work_item(pg_temp.item('child'),'Guest edit','','',4,pg_temp.fid('guest-edit'))$q$,'42501');
reset role;
update public.role_assignments set status='revoked' where role_id=pg_temp.fid('sponsor-role');
set local role authenticated;
select pg_temp.require(not public.can_access_work(pg_temp.item('child'),'detail') and public.read_guest_contacts(pg_temp.fid('org-term')) is null,'sponsor loss denies linked work and contacts under unchanged guest subject');
reset role;
update public.role_assignments set status='active' where role_id=pg_temp.fid('sponsor-role');
update public.record_grants set starts_at=statement_timestamp()-interval'2 days',expires_at=statement_timestamp()-interval'1 day' where id=((select result from refs where name='peer-grant')->>'grantId')::uuid;
set local role authenticated;
select pg_temp.login('peer');
select pg_temp.require(not public.can_access_work(pg_temp.item('child'),'detail'),'expired record grant removes detail access');
reset role;
update public.record_grants set starts_at=statement_timestamp()-interval'1 hour',expires_at=statement_timestamp()+interval'2 days' where id=((select result from refs where name='peer-grant')->>'grantId')::uuid;
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
values(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.fid('work-role'),'committee.manage','work');
set local role authenticated;
select pg_temp.login('role-reader');
select pg_temp.require(public.can_access_work(pg_temp.item('child'),'edit') and not public.can_access_work(pg_temp.item('parent'),'edit')
  and not public.has_capability(pg_temp.fid('org-term'),'committee.manage'),'record-scoped edit role is exact, never parent/term authority');
reset role;
select pg_temp.reject($q$insert into public.record_grants(organization_id,term_id,work_item_id,member_id,grant_kind,expires_at,grantor_id)
  values(pg_temp.fid('org'),pg_temp.fid('org-term'),pg_temp.item('child'),pg_temp.fid('other-owner'),'read',statement_timestamp()+interval'1 day',pg_temp.fid('tm-owner'))$q$,'23503');
select pg_temp.reject($q$insert into public.announcements(work_item_id,organization_id,term_id) values(pg_temp.item('child'),pg_temp.fid('org'),pg_temp.fid('org-term'))$q$,'23503');
select pg_temp.reject($q$insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)
  select organization_id,term_id,kind,'Orphan','restricted',owner_member_id,owner_display_name,status_id from public.work_items where id=pg_temp.item('child'); set constraints all immediate$q$,'23514');
select pg_temp.reject($q$update public.status_definitions set semantic_category='approved' where resource_kind='task'$q$,'42501');
select pg_temp.reject($q$update public.audit_events set actor_display_name='Rewritten history'$q$,'42501');
select pg_temp.reject($q$update public.tasks set work_item_id=pg_temp.item('sibling') where work_item_id=pg_temp.item('child')$q$,'42501');
select 'ok 1 - P07_A1: exact child/grant/unit/work-role/guest scope; summary/detail separation; no parent/sibling/direct mutation; same-term/type/history invariants' as tap;

set local role authenticated;
select pg_temp.login('owner');
insert into refs values('create-retry',public.create_work_item(pg_temp.fid('org-term'),'task','Shared child','Child summary','CHILD BODY','restricted',null,pg_temp.item('parent'),1,pg_temp.fid('create-child')));
select pg_temp.require((select result from refs where name='create-retry')=(select result from refs where name='child'),'create retry earlier version one even after grants bumped version');
set local timezone='Asia/Manila';
select pg_temp.require(public.grant_work_access(pg_temp.item('child'),pg_temp.fid('peer'),null,null,'read',statement_timestamp()+interval'2 days',1,pg_temp.fid('grant-peer'))=(select result from refs where name='peer-grant'),'grant retry returns earlier exact receipt across session timezones');
set local timezone='UTC';
select pg_temp.reject($q$select public.create_work_item(pg_temp.fid('org-term'),'task','Changed payload','Child summary','CHILD BODY','restricted',null,pg_temp.item('parent'),1,pg_temp.fid('create-child'))$q$,'22023');
select pg_temp.login('editor');
insert into refs values('update-first',public.update_work_item(pg_temp.item('child'),'First edit','Safe edit','DETAIL EDIT ONE',4,pg_temp.fid('update-first')));
insert into refs values('update-second',public.update_work_item(pg_temp.item('child'),'Second edit','Safe edit','DETAIL EDIT TWO',5,pg_temp.fid('update-second')));
insert into refs values('update-retry',public.update_work_item(pg_temp.item('child'),'First edit','Safe edit','DETAIL EDIT ONE',4,pg_temp.fid('update-first')));
select pg_temp.require((select result from refs where name='update-first')=(select result from refs where name='update-retry'),'retry returns exact earlier result, not current version');
select pg_temp.require((select version=6 from public.work_items where id=pg_temp.item('child')) and (select body='DETAIL EDIT TWO' from public.tasks where work_item_id=pg_temp.item('child')),'retry never restores old body or increments version');
select pg_temp.require((select version=3 and created_by=pg_temp.fid('owner') and updated_by=pg_temp.fid('editor') from public.tasks where work_item_id=pg_temp.item('child')),'typed-child edits preserve creation actor and local version stamps');
select pg_temp.reject($q$select public.update_work_item(pg_temp.item('child'),'Changed payload','Safe edit','DETAIL EDIT ONE',4,pg_temp.fid('update-first'))$q$,'22023');
reset role;
select pg_temp.require((select count(*)=1 from public.audit_events where actor_id=pg_temp.fid('editor') and request_id=pg_temp.fid('update-first')),'single audit for repeated command');
select pg_temp.require((select count(*)=1 from public.outbox_jobs j join public.audit_events a on a.id=j.event_id where a.request_id=pg_temp.fid('update-first')),'single outbox for repeated command');
select pg_temp.require(not exists(select 1 from public.audit_events where redacted_diff::text like '%DETAIL EDIT%' or redacted_diff::text like '%RESTRICTED%'),'no raw title/detail payload in audit');
select pg_temp.require(not exists(select 1 from public.outbox_jobs where payload::text like '%DETAIL EDIT%' or payload::text like '%RESTRICTED%'),'no raw title/detail payload in outbox');
select 'ok 2 - P07_A2: exact earlier create/update result; changed reused-key payload rejected; one business/audit/outbox result' as tap;

set local role authenticated;
select pg_temp.login('owner');
insert into checks values('owner-version',jsonb_build_object('version',(select version from public.work_items where id=pg_temp.item('child'))));
select pg_temp.login('editor');
insert into checks values('editor-version',jsonb_build_object('version',(select version from public.work_items where id=pg_temp.item('child'))));
select pg_temp.require((select result from checks where name='owner-version')=(select result from checks where name='editor-version'),'two actors observed the same version');
select pg_temp.login('owner');
select public.update_work_item(pg_temp.item('child'),'Winning update','Safe winner','WINNING BODY',6,pg_temp.fid('winner'));
reset role;
insert into checks values('before-denied',jsonb_build_array((select count(*) from public.work_items),(select count(*) from public.record_grants),(select count(*) from public.idempotency_keys),(select count(*) from public.audit_events),(select count(*) from public.outbox_jobs)));
set local role authenticated;
select pg_temp.login('editor');
select pg_temp.reject($q$select public.update_work_item(pg_temp.item('child'),'Stale loser','','LOSING BODY',6,pg_temp.fid('stale-loser'))$q$,'40001');
select pg_temp.login('outsider');
select pg_temp.reject($q$select public.update_work_item(pg_temp.item('child'),'Denied','','DENIED BODY',7,pg_temp.fid('denied'))$q$,'42501');
select pg_temp.reject($q$select public.grant_work_access(pg_temp.item('child'),pg_temp.fid('outsider'),null,null,'edit',statement_timestamp()+interval'1 day',7,pg_temp.fid('self-grant'))$q$,'42501');
reset role;
select pg_temp.require((select result from checks where name='before-denied')=jsonb_build_array((select count(*) from public.work_items),(select count(*) from public.record_grants),(select count(*) from public.idempotency_keys),(select count(*) from public.audit_events),(select count(*) from public.outbox_jobs)),'denied/stale commands create zero successful effects');
select pg_temp.require((select body='WINNING BODY' from public.tasks where work_item_id=pg_temp.item('child')),'stale/denied commands preserve winner');
create function pg_temp.fail_outbox() returns trigger language plpgsql as $$begin raise exception 'P07 forced outbox failure'; end$$;
create trigger p07_forced_failure before insert on public.outbox_jobs for each row execute function pg_temp.fail_outbox();
set local role authenticated;
select pg_temp.login('owner');
select pg_temp.reject($q$select public.update_work_item(pg_temp.item('child'),'Rolled back','','ROLLBACK BODY',7,pg_temp.fid('outbox-failure'))$q$,'P0001');
reset role;
select pg_temp.require((select result from checks where name='before-denied')=jsonb_build_array((select count(*) from public.work_items),(select count(*) from public.record_grants),(select count(*) from public.idempotency_keys),(select count(*) from public.audit_events),(select count(*) from public.outbox_jobs)),'outbox failure rolls back business/idempotency/audit');
select pg_temp.require((select version=7 from public.work_items where id=pg_temp.item('child')) and (select body='WINNING BODY' from public.tasks where work_item_id=pg_temp.item('child')),'failed outbox restores prior row and detail');
drop trigger p07_forced_failure on public.outbox_jobs;
set local role authenticated;
select public.revoke_work_access(((select result from refs where name='guest-grant')->>'grantId')::uuid,7,pg_temp.fid('revoke-guest-grant'));
select pg_temp.require((public.revoke_work_access(((select result from refs where name='guest-grant')->>'grantId')::uuid,7,pg_temp.fid('revoke-guest-grant'))->>'version')::integer=8,'revoke retry returns earlier receipt without another increment');
select pg_temp.login('guest');
select pg_temp.require(not public.can_access_work(pg_temp.item('child'),'summary') and (select count(*)=0 from public.tasks),'record revoke denies unchanged guest subject');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('org-term'))->'sharedContacts'='[]'::jsonb,'record revoke removes related shared contacts');
reset role;
update public.unit_memberships set status='revoked' where term_membership_id=pg_temp.fid('tm-unit-peer');
set local role authenticated;
select pg_temp.login('unit-peer');
select pg_temp.require(not public.can_access_work(pg_temp.item('sibling'),'detail'),'unit deployment loss denies old subject');
select pg_temp.login('role-reader');
reset role;
update public.role_assignments set status='revoked' where scope_type='work';
update public.members set display_name='Renamed current owner',account_state='suspended' where id=pg_temp.fid('owner');
set local role authenticated;
select pg_temp.require(not public.can_access_work(pg_temp.item('child'),'detail'),'work role loss denies old subject');
select pg_temp.login('owner');
select pg_temp.require(not public.can_access_work(pg_temp.item('child'),'detail'),'suspended owner has no old-subject work access');
select pg_temp.reject($q$select public.create_work_item(pg_temp.fid('org-term'),'task','Shared child','Child summary','CHILD BODY','restricted',null,pg_temp.item('parent'),1,pg_temp.fid('create-child'))$q$,'42501');
select pg_temp.login('peer');
select pg_temp.require((select owner_display_name='Fictional owner' from public.work_items where id=pg_temp.item('child')),'past work attribution survives inactive owner without private profile read');
select pg_temp.require((select count(*)=0 from public.private_profiles),'work grant exposes no private profiles');
set local role anon;
select pg_temp.reject($q$select public.can_access_work(pg_temp.item('child'),'summary')$q$,'42501');
select pg_temp.reject($q$select * from public.outbox_jobs$q$,'42501');
select 'ok 3 - P07_A3: two-actor stale update rejected; denied/failed outbox leaves no successful effects; current revoke/unit/role gates and retained attribution' as tap;
set constraints all immediate;
rollback;
