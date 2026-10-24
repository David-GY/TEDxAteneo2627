begin;
select '1..3' as tap;
create function pg_temp.fid(s text) returns uuid language sql immutable as $$ select md5('P06_G:'||s)::uuid $$;
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
grant execute on function pg_temp.fid(text),pg_temp.login(text),pg_temp.require(boolean,text),pg_temp.reject(text,text) to authenticated,anon;
insert into public.organizations(id,slug,name) values(pg_temp.fid('org'),'p06-guest-contacts','P05 fictional local organization');
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
create temp table saved_invite(result jsonb);
grant all on saved_invite to authenticated;
set local role authenticated;
select pg_temp.login('sponsor');
insert into saved_invite values(public.create_guest_invitation(pg_temp.fid('term'),'visitor@example.invalid',pg_temp.fid('invitation-request')));
select pg_temp.login('guest');
select public.redeem_guest_invitation((select result->>'token' from saved_invite));
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term'))->'own'->>'verifiedEmail'='visitor@example.invalid','own verified email only');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term'))->'sharedContacts'='[]'::jsonb,'zero shared contacts before record scopes');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('wrong-term')) is null,'no other term contact read');
select public.save_guest_contact_profile(pg_temp.fid('term'),'{"displayName":" Fictional visitor ","contactRoute":"Fictional contact route"}',0,pg_temp.fid('first-save'));
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term'))->'own'->>'displayName'='Fictional visitor' and (public.read_guest_contacts(pg_temp.fid('term'))->'own'->>'version')::integer=1,'actual trimmed first save');
select public.save_guest_contact_profile(pg_temp.fid('term'),'{"displayName":" Fictional visitor ","contactRoute":"Fictional contact route"}',0,pg_temp.fid('first-save'));
select pg_temp.require((public.read_guest_contacts(pg_temp.fid('term'))->'own'->>'version')::integer=1,'retry no duplicate write');
select pg_temp.reject($q$select public.save_guest_contact_profile(pg_temp.fid('term'),'{"contactRoute":"Stale"}',0,pg_temp.fid('stale'))$q$,'40001');
select pg_temp.reject($q$select public.save_guest_contact_profile(pg_temp.fid('term'),'{"displayName":"Changed payload"}',0,pg_temp.fid('first-save'))$q$,'22023');
select pg_temp.reject($q$select public.save_guest_contact_profile(pg_temp.fid('term'),'{"user_id":"Other identity"}',1,pg_temp.fid('identity-injection'))$q$,'22023');
select pg_temp.reject($q$select * from public.guest_contact_profiles$q$,'42501');
select pg_temp.require(public.read_people_directory(pg_temp.fid('term'))='[]'::jsonb,'own contact never grants full directory');
select 'ok 1 - P06_G1: guest own-only read/edit, verified email, zero shared contacts, version/retry/validation isolation' as tap;
select pg_temp.login('other');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term')) is null,'other guest cannot read saved contact');
select pg_temp.login('sponsor');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term')) is null,'sponsor has no implicit private guest profile access');
reset role;
select pg_temp.require((select count(*)=1 from public.guest_profile_commands where user_id=pg_temp.fid('guest')),'one redacted audit');
select pg_temp.require(not exists(select 1 from public.guest_profile_commands where row_to_json(guest_profile_commands)::text like '%Fictional contact route%'),'no contact payload in audit');
update public.role_assignments set status='revoked' where term_membership_id=pg_temp.fid('tm');
set local role authenticated;
select pg_temp.login('guest');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term')) is null,'sponsor loss denies old guest subject');
select pg_temp.reject($q$select public.save_guest_contact_profile(pg_temp.fid('term'),'{"contactRoute":null}',1,pg_temp.fid('lost-sponsor'))$q$,'42501');
reset role;
update public.role_assignments set status='active' where term_membership_id=pg_temp.fid('tm');
update public.guest_invitations set created_at=statement_timestamp()-interval '2 days',expires_at=statement_timestamp()-interval '1 day' where id=((select result from saved_invite)->>'id')::uuid;
set local role authenticated;
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term')) is null,'expiry denies old guest subject');
reset role;
update public.guest_invitations set expires_at=statement_timestamp()+interval '1 day' where id=((select result from saved_invite)->>'id')::uuid;
set local role authenticated;
select pg_temp.login('sponsor');
select public.revoke_guest_access(((select result from saved_invite)->>'id')::uuid,2,pg_temp.fid('revoke'));
select pg_temp.login('guest');
select pg_temp.require(public.read_guest_contacts(pg_temp.fid('term')) is null,'revocation denies old guest subject');
select pg_temp.reject($q$select public.save_guest_contact_profile(pg_temp.fid('term'),'{"displayName":"Revoked"}',1,pg_temp.fid('revoked-save'))$q$,'42501');
select 'ok 2 - P06_G2: no sponsor/other-guest enumeration; sponsor loss, expiry and revoke deny old subject reads/writes' as tap;
reset role;
set local role anon;
select pg_temp.reject($q$select public.read_guest_contacts(pg_temp.fid('term'))$q$,'42501');
select pg_temp.reject($q$select * from public.guest_profile_commands$q$,'42501');
select 'ok 3 - P06_G3: anonymous RPC/table access denied' as tap;
rollback;
