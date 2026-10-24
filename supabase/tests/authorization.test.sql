-- Authenticated-role SQL regression suite. Fictional fixtures and writes roll back.
begin;
select '1..3' as tap;
create function pg_temp.fid(label text) returns uuid language sql immutable as $$ select md5('P03:' || label)::uuid $$;
create function pg_temp.login(label text) returns void language plpgsql as $$ begin
  perform set_config('request.jwt.claim.sub', pg_temp.fid('user:' || label)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.fid('user:' || label),
    'role','authenticated','email',label || '@student.ateneo.edu',
    'user_metadata',jsonb_build_object('role','super_admin','affiliation','MEAn'),
    'app_metadata',jsonb_build_object('role','super_admin'))::text, true);
end; $$;
create function pg_temp.require(ok boolean, message text) returns void language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'Assertion failed: %', message; end if;
end; $$;
create function pg_temp.denied(statement text) returns void language plpgsql as $$ begin
  begin execute statement; exception when insufficient_privilege then return; end;
  raise exception 'Expected permission denial: %', statement;
end; $$;
grant execute on function pg_temp.fid(text), pg_temp.login(text), pg_temp.require(boolean,text), pg_temp.denied(text) to authenticated, anon;

insert into public.organizations(id,slug,name) values (pg_temp.fid('org'),'p03-fictional','P03 fictional organization'),
  (pg_temp.fid('other-org'),'p03-other-fictional','P03 other fictional organization');
insert into public.terms(id,organization_id,label,event_date,starts_on,closes_on,state)
select pg_temp.fid(x || ':term'), pg_temp.fid(x), 'P03 local term', current_date, current_date-30, current_date+30, 'active'
from (values ('org'),('other-org')) s(x);
insert into auth.users(id) select pg_temp.fid('user:' || name) from unnest(array[
  'pm','head','mean','nonmean','associate','guest','expired','suspended','account_suspended','other','nonmember']) name;
insert into public.members(id,organization_id,auth_user_id,email,display_name,account_state)
select pg_temp.fid('member:' || name), pg_temp.fid(case when name='other' then 'other-org' else 'org' end),
  pg_temp.fid('user:' || name), name || '@example.invalid', 'Fictional ' || name,
  case when name='account_suspended' then 'suspended' else 'active' end
from unnest(array['pm','head','mean','nonmean','associate','guest','expired','suspended','account_suspended','other']) name;
insert into public.term_memberships(id,organization_id,term_id,member_id,membership_kind,status,joined_at,ends_at,affiliation_tag)
select pg_temp.fid('tm:' || name), pg_temp.fid(case when name='other' then 'other-org' else 'org' end),
  pg_temp.fid(case when name='other' then 'other-org:term' else 'org:term' end), pg_temp.fid('member:' || name),
  case when name in ('guest','expired') then 'guest' else 'core' end,
  case when name='suspended' then 'suspended' else 'active' end,
  statement_timestamp()-interval '10 days',
  statement_timestamp()+case when name='expired' then interval '-1 day' else interval '10 days' end,
  case when name='mean' then 'MEAn' when name='nonmean' then 'non-MEAn' end
from unnest(array['pm','head','mean','nonmean','associate','guest','expired','suspended','account_suspended','other']) name;
insert into public.private_profiles(member_id,organization_id,phone)
select id,organization_id,'fictional-private-contact' from public.members where organization_id in (pg_temp.fid('org'),pg_temp.fid('other-org'));
insert into public.org_units(id,organization_id,term_id,code,name,delivery_committee,review_service)
select pg_temp.fid('unit:' || x),pg_temp.fid('org'),pg_temp.fid('org:term'),x,'Fictional unit ' || x,true,true
from (values ('A'),('B')) s(x);
insert into public.roles(id,organization_id,term_id,code,name,privileged)
select pg_temp.fid('role:' || x),pg_temp.fid('org'),pg_temp.fid('org:term'),x,'Fictional ' || x,x <> 'reader'
from (values ('reader'),('pm'),('head'),('associate')) s(x);
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
select pg_temp.fid('org'),pg_temp.fid('org:term'),pg_temp.fid('role:' || role),cap,scope
from (values ('reader','workspace.read','term'),('reader','directory.read','term'),
  ('pm','workspace.read','term'),('pm','directory.read','term'),('pm','admin.configure','term'),
  ('head','workspace.read','term'),('head','directory.read','term'),('head','committee.manage','unit'),
  ('associate','department.review','unit')) s(role,cap,scope);
insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)
select pg_temp.fid('org'),pg_temp.fid('org:term'),pg_temp.fid('tm:' || x),pg_temp.fid('unit:A'),
  case when x='head' then 'head' else 'associate' end,statement_timestamp()-interval '1 day',statement_timestamp()+interval '5 days',pg_temp.fid('tm:pm')
from (values ('head'),('associate')) s(x);
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)
select pg_temp.fid('org'),pg_temp.fid('org:term'),pg_temp.fid('tm:' || x),pg_temp.fid('role:' || role),scope,
  case when scope='unit' then pg_temp.fid('unit:A') end,statement_timestamp()-interval '1 day',statement_timestamp()+interval '5 days',pg_temp.fid('tm:pm')
from (values ('pm','pm','term'),('head','head','term'),('head','head','unit'),('mean','reader','term'),
  ('nonmean','reader','term'),('associate','associate','unit'),('guest','reader','term'),
  ('expired','reader','term'),('suspended','reader','term'),('account_suspended','reader','term')) s(x,role,scope);

set local role authenticated;
do $$ declare principal text; n bigint; statement text;
begin
  perform pg_temp.require(current_user='authenticated' and not exists(select 1 from pg_roles where rolname=current_user and (rolsuper or rolbypassrls)), 'assertions must execute as unprivileged authenticated role');
  foreach principal in array array['nonmember','expired','suspended','account_suspended'] loop
    perform pg_temp.login(principal);
    perform pg_temp.require(public.current_term_membership(pg_temp.fid('org:term')) is null, principal || ' membership');
    perform pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'workspace.read'),principal || ' capability');
    perform pg_temp.require((select count(*)=0 from public.read_directory(pg_temp.fid('org:term'))),principal || ' directory');
    foreach statement in array array[
      'select count(id) from public.organizations','select count(id) from public.terms',
      'select count(id) from public.members','select count(id) from public.term_memberships',
      'select count(member_id) from public.private_profiles','select count(id) from public.org_units',
      'select count(id) from public.unit_memberships','select count(id) from public.roles',
      'select count(id) from public.role_permissions','select count(id) from public.role_assignments'] loop
      execute statement into n;
      perform pg_temp.require(n=0,principal || ' leaked workspace rows: ' || statement);
    end loop;
  end loop;
  perform pg_temp.login('other');
  perform pg_temp.require((select count(*)=0 from public.read_directory(pg_temp.fid('org:term'))),'cross-organization directory');
  perform pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'workspace.read'),'cross-organization capability');
end; $$;
reset role;
select 'ok 1 - P03_A1: authenticated nonmember/expired/suspended principals see zero workspace rows; cross-org denied' as tap;

create temporary table p03_results(name text, result jsonb);
grant select,insert on p03_results to authenticated;
set local role authenticated;
do $$ declare principal text;
begin
  foreach principal in array array['mean','nonmean'] loop
    perform pg_temp.login(principal);
    insert into p03_results values (principal,jsonb_build_object(
      'cap',public.has_capability(pg_temp.fid('org:term'),'workspace.read'),
      'directory',(select jsonb_agg(to_jsonb(d) order by member_id) from public.read_directory(pg_temp.fid('org:term')) d),
      'units',(select jsonb_agg(id order by id) from public.org_units)));
  end loop;
  perform pg_temp.require((select a.result=b.result and (a.result->>'cap')::boolean from p03_results a,p03_results b where a.name='mean' and b.name='nonmean'),'affiliation parity');
  perform pg_temp.login('associate');
  perform pg_temp.require(public.has_capability(pg_temp.fid('org:term'),'department.review',pg_temp.fid('unit:A')),'associate unit A');
  perform pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'department.review',pg_temp.fid('unit:B')),'associate unit B denied');
  perform pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'finance.review',pg_temp.fid('unit:A')),'no FIN from department title');
  perform pg_temp.require((select count(*)=1 and bool_and(id=pg_temp.fid('unit:A')) from public.org_units),'only configured unit rows');
  perform pg_temp.login('head');
  perform pg_temp.require(public.has_capability(pg_temp.fid('org:term'),'committee.manage',pg_temp.fid('unit:A')),'head configured grant');
  perform pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'committee.manage',pg_temp.fid('unit:B')),'head other unit denied');
  perform pg_temp.login('guest');
  perform pg_temp.require(public.current_term_membership(pg_temp.fid('org:term')) is not null,'active guest identity');
  perform pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'directory.read'),'guest cannot inherit core permission');
  perform pg_temp.require((select count(*)=0 from public.read_directory(pg_temp.fid('org:term'))),'guest no directory');
end; $$;
reset role;
-- Effective dates/revocation are evaluated immediately, not from cached identity claims.
update public.unit_memberships set status='revoked' where term_membership_id=pg_temp.fid('tm:associate');
set local role authenticated;
select pg_temp.login('associate');
select pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'department.review',pg_temp.fid('unit:A')),'revoked deployment');
reset role;
update public.unit_memberships set status='active',effective_to=statement_timestamp()-interval '1 hour' where term_membership_id=pg_temp.fid('tm:associate');
set local role authenticated;
select pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'department.review',pg_temp.fid('unit:A')),'expired deployment still marked active');
reset role;
select 'ok 2 - P03_A2: equivalent affiliation grants identical; unit scopes, guest, revocation and expiry enforced' as tap;

update public.role_assignments set effective_from=statement_timestamp()+interval '1 hour'
  where term_membership_id=pg_temp.fid('tm:head') and scope_type='term';
set local role authenticated;
select pg_temp.login('head');
select pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'workspace.read'),'future role assignment');
reset role;
update public.role_assignments set effective_from=statement_timestamp()-interval '2 days',effective_to=statement_timestamp()-interval '1 hour'
  where term_membership_id=pg_temp.fid('tm:head') and scope_type='term';
set local role authenticated;
select pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'workspace.read'),'expired role assignment still active');
reset role;
update public.roles set state='retired' where id=pg_temp.fid('role:head');
set local role authenticated;
select pg_temp.require(not public.has_capability(pg_temp.fid('org:term'),'committee.manage',pg_temp.fid('unit:A')),'retired role');
reset role;
delete from public.private_profiles where member_id=pg_temp.fid('member:guest');

set local role authenticated;
do $$ declare changed integer; actual text; actual_version integer; principal text;
begin
  foreach principal in array array['pm','head','mean','nonmean','associate','guest'] loop
    perform pg_temp.login(principal);
    perform pg_temp.require((select count(*)=0 from public.private_profiles where member_id=pg_temp.fid('member:other')),'other private profile denied for ' || principal);
    perform pg_temp.require((select count(*)=0 from public.private_profiles where member_id=pg_temp.fid('member:' || case when principal='mean' then 'nonmean' else 'mean' end)),'same-org private profile denied');
    perform pg_temp.denied('insert into public.role_assignments default values');
    perform pg_temp.denied('update public.role_assignments set scope_type=''term''');
    perform pg_temp.denied('update public.role_assignments set effective_to=statement_timestamp()+interval ''99 years''');
    perform pg_temp.denied('update public.role_permissions set capability=''roles.manage''');
    perform pg_temp.denied('update public.term_memberships set status=''active''');
    perform pg_temp.denied('update public.term_memberships set ends_at=statement_timestamp()+interval ''99 years''');
    perform pg_temp.denied('update public.members set auth_user_id=auth.uid()');
    perform pg_temp.denied('update public.members set organization_id=gen_random_uuid()');
    perform pg_temp.denied('select email,auth_user_id,normalized_email from public.members');
    perform pg_temp.denied('delete from public.private_profiles');
    perform pg_temp.denied(format('insert into public.private_profiles(member_id,organization_id) values (%L,%L)',pg_temp.fid('member:other'),pg_temp.fid('other-org')));
    update public.private_profiles set share_phone=true where member_id=pg_temp.fid('member:other');
    get diagnostics changed=row_count;
    perform pg_temp.require(changed=0,'cannot change another visibility choice');
    update public.members set display_name='Forbidden other person edit' where id=pg_temp.fid('member:other');
    get diagnostics changed=row_count;
    perform pg_temp.require(changed=0,'cannot edit another display name');
  end loop;
  perform pg_temp.login('guest');
  insert into public.private_profiles(member_id,organization_id,course) values (pg_temp.fid('member:guest'),pg_temp.fid('org'),'Fictional guest course');
  get diagnostics changed=row_count;
  perform pg_temp.require(changed=1 and exists(select 1 from public.private_profiles where member_id=pg_temp.fid('member:guest') and course='Fictional guest course' and version=1 and created_by=auth.uid()),'actual own private insert');
  perform pg_temp.login('mean');
  update public.members set display_name='Fictional corrected name' where id=pg_temp.fid('member:mean') returning display_name,version into actual,actual_version;
  get diagnostics changed=row_count;
  perform pg_temp.require(changed=1 and actual='Fictional corrected name' and actual_version=2,'actual own display-name row changed');
  update public.private_profiles set course='Fictional optional course',share_course=true where member_id=pg_temp.fid('member:mean');
  get diagnostics changed=row_count;
  perform pg_temp.require(changed=1 and exists(select 1 from public.private_profiles where member_id=pg_temp.fid('member:mean') and course='Fictional optional course' and share_course and updated_by=auth.uid() and version=2),'actual own private row changed/stamped');
  update public.term_memberships set affiliation_tag='non-MEAn' where id=pg_temp.fid('tm:mean');
  get diagnostics changed=row_count;
  perform pg_temp.require(changed=1 and exists(select 1 from public.term_memberships where id=pg_temp.fid('tm:mean') and affiliation_tag='non-MEAn'),'actual own affiliation row changed');
  perform pg_temp.require(public.has_capability(pg_temp.fid('org:term'),'workspace.read'),'affiliation edit cannot affect authority');
  perform pg_temp.require(public.explain_access(pg_temp.fid('org:term'))->>'membership_id'=pg_temp.fid('tm:mean')::text,'self-only access explanation');
end; $$;
reset role;
update public.terms set state='frozen',frozen_at=statement_timestamp() where id=pg_temp.fid('org:term');
set local role authenticated;
do $$ declare changed integer; begin
  perform pg_temp.require(public.has_capability(pg_temp.fid('org:term'),'workspace.read'),'frozen term read');
  update public.members set display_name='Forbidden frozen edit' where id=pg_temp.fid('member:mean');
  get diagnostics changed=row_count;
  perform pg_temp.require(changed=0,'frozen term writes blocked');
end; $$;
reset role;
set local role anon;
select pg_temp.denied('select public.current_term_membership(null)');
select pg_temp.denied('select member_id from public.private_profiles');
reset role;
do $$ begin
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.prosecdef and not coalesce(p.proconfig @> array['search_path=""'],false)) then
    raise exception 'Unpinned security definer search_path';
  end if;
end; $$;
select 'ok 3 - P03_A3: API-role self-grants/private reads denied; permitted own writes change actual rows; frozen writes denied' as tap;
rollback;
