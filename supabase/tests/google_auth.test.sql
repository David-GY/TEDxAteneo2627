begin;
select '1..3' as tap;
create function pg_temp.fid(s text) returns uuid language sql immutable as $$ select md5('P04:'||s)::uuid $$;
create function pg_temp.login(s text) returns void language plpgsql as $$ begin
  perform set_config('request.jwt.claim.sub',pg_temp.fid('user:'||s)::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.fid('user:'||s),'email','approved@student.ateneo.edu','user_metadata',jsonb_build_object('email_verified',true,'role','super_admin'))::text,true);
end; $$;
create function pg_temp.require(ok boolean, message text) returns void language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'Assertion failed: %',message; end if;
end; $$;
grant execute on function pg_temp.fid(text),pg_temp.login(text),pg_temp.require(boolean,text) to authenticated;

insert into public.organizations(id,slug,name) values(pg_temp.fid('org'),'p04-fictional','P04 fictional local organization');
insert into public.terms(id,organization_id,label,event_date,starts_on,closes_on,state)
values(pg_temp.fid('term'),pg_temp.fid('org'),'P04 fictional term',current_date,current_date-30,current_date+30,'active');
insert into public.org_units(id,organization_id,term_id,code,name,delivery_committee)
values(pg_temp.fid('unit'),pg_temp.fid('org'),pg_temp.fid('term'),'P04_TEST','Fictional populated unit',true);
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.fid('user:'||s),case when s='lookalike' then 'lookalike@student.ateneo.edu.evil.test'
  when s='prefix' then 'prefix@evilstudent.ateneo.edu' else s||'@student.ateneo.edu' end,statement_timestamp()
from unnest(array['approved','otherstudent','lookalike','prefix','unverified','nongoogle','suspended','expired','guest']) s;
insert into auth.identities(provider_id,user_id,provider,identity_data)
select id::text,id,case when email like 'nongoogle@%' then 'email' else 'google' end,
  jsonb_build_object('email',email,'email_verified',email not like 'unverified@%') from auth.users where id in (
    select pg_temp.fid('user:'||s) from unnest(array['approved','otherstudent','lookalike','prefix','unverified','nongoogle','suspended','expired','guest']) s);
insert into public.members(id,organization_id,auth_user_id,email,display_name,account_state)
select pg_temp.fid('member:'||s),pg_temp.fid('org'),case when s='approved' then null else u.id end,u.email,'Fictional '||s,
  case when s='approved' then 'invited' else 'active' end
from unnest(array['approved','lookalike','prefix','unverified','nongoogle','suspended','expired','guest']) s
join auth.users u on u.id=pg_temp.fid('user:'||s);
insert into public.term_memberships(id,organization_id,term_id,member_id,membership_kind,status,joined_at,ends_at)
select pg_temp.fid('tm:'||s),pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('member:'||s),
  case when s='guest' then 'guest' else 'core' end,case when s='suspended' then 'suspended' else 'active' end,
  statement_timestamp()-interval '2 days',statement_timestamp()+case when s='expired' then interval '-1 day' else interval '2 days' end
from unnest(array['approved','lookalike','prefix','unverified','nongoogle','suspended','expired','guest']) s;
insert into public.roles(id,organization_id,term_id,code,name) values(pg_temp.fid('role'),pg_temp.fid('org'),pg_temp.fid('term'),'p04_reader','Fictional reader');
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('role'),'workspace.read','term');
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)
select pg_temp.fid('org'),pg_temp.fid('term'),id,pg_temp.fid('role'),'term',statement_timestamp()-interval '1 day',statement_timestamp()+interval '1 day',pg_temp.fid('tm:approved')
from public.term_memberships where term_id=pg_temp.fid('term');

set local role authenticated;
do $$ declare result jsonb; s text; begin
  perform pg_temp.require(current_user='authenticated','non-owner principal');
  perform pg_temp.login('approved');
  result:=public.resolve_auth_context();
  perform pg_temp.require(result->>'state'='authorized' and result->>'termMembershipId'=pg_temp.fid('tm:approved')::text,'approved member enters');
  perform pg_temp.require(public.has_capability(pg_temp.fid('term'),'workspace.read'),'new linkage usable by policies');
  perform pg_temp.require((select count(id)=1 from public.org_units),'authorized data fixture is not empty');
  perform pg_temp.require(public.resolve_auth_context()->>'state'='authorized','repeat resolution succeeds');
  perform pg_temp.require((select version=2 from public.members where id=pg_temp.fid('member:approved')),'repeat resolution does not rewrite linkage');
  foreach s in array array['otherstudent','lookalike','prefix','unverified','nongoogle','guest'] loop
    perform pg_temp.login(s);
    perform pg_temp.require(public.resolve_auth_context()->>'state'='denied','deny '||s);
    perform pg_temp.require(public.current_term_membership(pg_temp.fid('term')) is null,'direct RLS helper deny '||s);
    perform pg_temp.require((select count(id)=0 from public.org_units),'no direct unit data '||s);
    perform pg_temp.require((select count(id)=0 from public.members),'no raw own identity rows '||s);
  end loop;
end; $$;
reset role;
select pg_temp.require((select auth_user_id=pg_temp.fid('user:approved') and account_state='active' and updated_by=pg_temp.fid('user:approved') from public.members where id=pg_temp.fid('member:approved')),'actual server linkage changed');
select 'ok 1 - P04_A1: verified Google plus exact school roster enters; nonmember/lookalikes/unverified/non-Google/guest denied' as tap;

set local role authenticated;
do $$ declare s text; begin
  foreach s in array array['expired','suspended'] loop
    perform pg_temp.login(s);
    perform pg_temp.require(public.resolve_auth_context()->>'state'='denied',s||' admission');
    perform pg_temp.require(not public.has_capability(pg_temp.fid('term'),'workspace.read'),s||' old-token capability');
  end loop;
end; $$;
reset role;
update public.term_memberships set status='suspended' where id=pg_temp.fid('tm:approved');
set local role authenticated;
select pg_temp.login('approved');
select pg_temp.require(public.resolve_auth_context()->>'state'='denied','formerly admitted user suspended');
select pg_temp.require((select count(id)=0 from public.members),'old subject cannot read member row after suspension');
reset role;
update public.term_memberships set status='active' where id=pg_temp.fid('tm:approved');
update auth.users set email='changed@student.ateneo.edu' where id=pg_temp.fid('user:approved');
set local role authenticated;
select pg_temp.require(public.current_term_membership(pg_temp.fid('term')) is null,'canonical email change invalidates old linked token');
reset role;
select 'ok 2 - P04_A2: expiry/suspension/canonical identity change revoke old subject access at database boundary' as tap;
select 'ok 3 - P04_A3: local admission checks only; live Google PKCE and Supabase API verification BLOCKED externally' as tap;
rollback;
