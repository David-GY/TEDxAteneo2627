begin;
select '1..3' as tap;
create function pg_temp.fid(s text) returns uuid language sql immutable as $$ select md5('P05:'||s)::uuid $$;
create function pg_temp.login(s text) returns void language sql as $$ select set_config('request.jwt.claim.sub',pg_temp.fid(s)::text,true)::void $$;
create function pg_temp.require(ok boolean,message text) returns void language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'Assertion failed: %',message; end if;
end; $$;
create function pg_temp.reject(command text,expected text) returns void language plpgsql as $$ begin
  begin execute command; exception when others then
    if sqlstate=expected then return; end if; raise;
  end;
  raise exception 'Expected rejection: %',command;
end; $$;
grant execute on function pg_temp.fid(text),pg_temp.login(text),pg_temp.require(boolean,text),pg_temp.reject(text,text) to authenticated;
insert into public.organizations(id,slug,name) values(pg_temp.fid('org'),'p05-fictional','P05 fictional local organization');
insert into public.terms(id,organization_id,label,event_date,starts_on,closes_on,state)
values(pg_temp.fid('term'),pg_temp.fid('org'),'Fictional term',current_date,current_date-30,current_date+30,'active');
insert into auth.users(id,email,email_confirmed_at)
values(pg_temp.fid('sponsor'),'sponsor@student.ateneo.edu',statement_timestamp()),
  (pg_temp.fid('guest'),'visitor@example.invalid',statement_timestamp()),
  (pg_temp.fid('other'),'other@example.invalid',statement_timestamp()),
  (pg_temp.fid('unverified'),'unverified@example.invalid',statement_timestamp());
insert into auth.identities(provider_id,user_id,provider,identity_data)
select id::text,id,'google',jsonb_build_object('email',email,'email_verified',id<>pg_temp.fid('unverified'))
  from auth.users where id in (pg_temp.fid('sponsor'),pg_temp.fid('guest'),pg_temp.fid('other'),pg_temp.fid('unverified'));
insert into public.members(id,organization_id,auth_user_id,email,display_name,account_state)
values(pg_temp.fid('member'),pg_temp.fid('org'),pg_temp.fid('sponsor'),'sponsor@student.ateneo.edu','Fictional sponsor','active');
insert into public.term_memberships(id,organization_id,term_id,member_id,membership_kind,status,joined_at,ends_at)
values(pg_temp.fid('tm'),pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('member'),'core','active',statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days');
insert into public.roles(id,organization_id,term_id,code,name,privileged)
values(pg_temp.fid('role'),pg_temp.fid('org'),pg_temp.fid('term'),'p05_admin','Fictional access administrator',true);
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('role'),'roles.manage','term');
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('tm'),pg_temp.fid('role'),'term',statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days',pg_temp.fid('tm'));
create temp table test_invites(name text primary key,result jsonb);
grant all on test_invites to authenticated;
set local role authenticated;
select pg_temp.login('sponsor');
select pg_temp.require(public.resolve_auth_context()->>'memberId'=pg_temp.fid('member')::text,'core context preserved through guest wrapper');
insert into test_invites values('first',public.create_guest_invitation(pg_temp.fid('term'),' Visitor@Example.invalid ',pg_temp.fid('request')));
select pg_temp.require(public.create_guest_invitation(pg_temp.fid('term'),'visitor@example.invalid',pg_temp.fid('request'))->>'token' is null,'retry never reveals bearer');
select pg_temp.reject($q$select public.create_guest_invitation(pg_temp.fid('term'),'other@example.invalid',pg_temp.fid('request'))$q$,'22023');
select pg_temp.login('other');
select pg_temp.reject($q$select public.redeem_guest_invitation((select result->>'token' from test_invites where name='first'))$q$,'42501');
select pg_temp.login('unverified');
select pg_temp.reject($q$select public.redeem_guest_invitation((select result->>'token' from test_invites where name='first'))$q$,'42501');
select pg_temp.login('guest');
select pg_temp.require(public.redeem_guest_invitation((select result->>'token' from test_invites where name='first'))->>'state'='redeemed','external Google exact email redeems');
select pg_temp.reject($q$select public.redeem_guest_invitation((select result->>'token' from test_invites where name='first'))$q$,'42501');
reset role;
select pg_temp.require((select redeemed_by=pg_temp.fid('guest') and version=2 and expires_at=created_at+interval '14 days' from public.guest_invitations where request_id=pg_temp.fid('request')),'actual row redemption and default expiry');
set local role authenticated;
select pg_temp.login('sponsor');
insert into test_invites values('expired',public.create_guest_invitation(pg_temp.fid('term'),'visitor@example.invalid',pg_temp.fid('expired-request')));
reset role;
update public.guest_invitations set created_at=statement_timestamp()-interval '15 days',expires_at=statement_timestamp()-interval '1 day' where request_id=pg_temp.fid('expired-request');
set local role authenticated;
select pg_temp.login('guest');
select pg_temp.reject($q$select public.redeem_guest_invitation((select result->>'token' from test_invites where name='expired'))$q$,'42501');
select 'ok 1 - P05_A1: exact verified email, one-use, expiry, retry conflict and actual redemption row' as tap;
select pg_temp.require(public.resolve_auth_context()->>'audience'='guest','guest context exists');
select pg_temp.require(public.current_term_membership(pg_temp.fid('term')) is null,'no term membership');
select pg_temp.require(not public.has_capability(pg_temp.fid('term'),'directory.read'),'no inherited capabilities');
select pg_temp.require((select count(*)=0 from public.read_directory(pg_temp.fid('term'))),'empty directory projection');
select pg_temp.require((select count(id)=0 from public.members),'no raw member rows');
select pg_temp.require((select count(id)=0 from public.org_units),'no unit rows');
select pg_temp.reject('select token_hash from public.guest_invitations','42501');
select pg_temp.reject($q$select public.create_guest_invitation(pg_temp.fid('term'),'other@example.invalid',pg_temp.fid('self-grant'))$q$,'42501');
select 'ok 2 - P05_A2: guest context grants no membership, directory, units, invitation enumeration or self-grants' as tap;
select pg_temp.login('sponsor');
select pg_temp.reject($q$select public.revoke_guest_access((select (result->>'id')::uuid from test_invites where name='first'),1,pg_temp.fid('revoke'))$q$,'40001');
select public.revoke_guest_access((select (result->>'id')::uuid from test_invites where name='first'),2,pg_temp.fid('revoke'));
select public.revoke_guest_access((select (result->>'id')::uuid from test_invites where name='first'),2,pg_temp.fid('revoke'));
select pg_temp.login('guest');
select pg_temp.require(public.resolve_auth_context()->>'state'='denied','unchanged authenticated subject denied immediately after revoke');
select pg_temp.login('sponsor');
insert into test_invites values('renew-source',public.create_guest_invitation(pg_temp.fid('term'),'visitor@example.invalid',pg_temp.fid('renew-source')));
insert into test_invites values('renewed',public.create_guest_invitation(pg_temp.fid('term'),'visitor@example.invalid',pg_temp.fid('renewed'),null,(select (result->>'id')::uuid from test_invites where name='renew-source'),1));
select pg_temp.login('guest');
select pg_temp.reject($q$select public.redeem_guest_invitation((select result->>'token' from test_invites where name='renew-source'))$q$,'42501');
select public.redeem_guest_invitation((select result->>'token' from test_invites where name='renewed'));
reset role;
update public.role_assignments set status='expired' where term_membership_id=pg_temp.fid('tm');
set local role authenticated;
select pg_temp.require(public.resolve_auth_context()->>'state'='denied','sponsor lost authority invalidates guest');
reset role;
select pg_temp.require(not exists(select 1 from public.guest_invitations i cross join test_invites t where to_jsonb(i)::text like '%'||(t.result->>'token')||'%'),'no raw tokens stored');
select pg_temp.require(not exists(select 1 from public.guest_invitation_events e cross join test_invites t where to_jsonb(e)::text like '%'||(t.result->>'token')||'%'),'no tokens in audit');
select pg_temp.require((select count(*)=1 from public.guest_invitation_events where event='revoked'),'idempotent revoke audit');
select pg_temp.require((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c where c.oid in ('public.guest_invitations'::regclass,'public.guest_invitation_events'::regclass)),'forced RLS');
select pg_temp.require(not has_table_privilege('anon','public.guest_invitations','SELECT') and not has_table_privilege('authenticated','public.guest_invitation_events','INSERT'),'no exposed table grants');
select pg_temp.require(not has_function_privilege('anon','public.redeem_guest_invitation(text)','EXECUTE'),'no anonymous redemption');
select pg_temp.require(not has_function_privilege('authenticated','app_private.resolve_auth_context()','EXECUTE'),'private core resolver is not directly callable');
select pg_temp.require((select bool_and(p.prosecdef and 'search_path=""'=any(p.proconfig)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('create_guest_invitation','redeem_guest_invitation','revoke_guest_access','list_guest_invitations','resolve_auth_context')),'RPCs fix empty search path and use trusted owner');
select 'ok 3 - P05_A3: unchanged subject revocation, renewal invalidation, sponsor loss, hashed-only storage/audit and deny-default tables; real JWT transport BLOCKED' as tap;
rollback;
