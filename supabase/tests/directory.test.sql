begin;
select '1..3' as tap;
create function pg_temp.fid(s text) returns uuid language sql immutable as $$ select md5('P06:'||s)::uuid $$;
create function pg_temp.require(ok boolean,message text) returns void language plpgsql as $$ begin
  if ok is distinct from true then raise exception 'Assertion failed: %',message; end if;
end; $$;
grant execute on function pg_temp.fid(text),pg_temp.require(boolean,text) to authenticated;
create function pg_temp.reject(command text,expected text) returns void language plpgsql as $$ begin
  begin execute command; exception when others then if sqlstate=expected then return; end if; raise; end;
  raise exception 'Expected rejection';
end; $$;
grant execute on function pg_temp.reject(text,text) to authenticated;
insert into public.organizations(id,slug,name) values(pg_temp.fid('org'),'p06-fictional','Fictional directory');
insert into public.terms(id,organization_id,label,event_date,starts_on,closes_on,state)
values(pg_temp.fid('term'),pg_temp.fid('org'),'Fictional term',current_date,current_date-30,current_date+30,'active');
insert into auth.users(id) values(pg_temp.fid('head')), (pg_temp.fid('member')), (pg_temp.fid('guest'));
update auth.users set email=case id when pg_temp.fid('head') then 'head@student.ateneo.edu' when pg_temp.fid('member') then 'member@student.ateneo.edu' else 'guest@example.invalid' end,email_confirmed_at=statement_timestamp()
where id in(pg_temp.fid('head'),pg_temp.fid('member'),pg_temp.fid('guest'));
insert into auth.identities(provider_id,user_id,provider,identity_data)
select id::text,id,'google',jsonb_build_object('email',email,'email_verified',true) from auth.users where id in(pg_temp.fid('head'),pg_temp.fid('member'),pg_temp.fid('guest'));
insert into public.members(id,organization_id,auth_user_id,email,display_name,account_state)
select pg_temp.fid(s),pg_temp.fid('org'),pg_temp.fid(s),s||'@student.ateneo.edu','Fictional '||s,'active' from (values('head'),('member')) v(s);
insert into public.term_memberships(id,organization_id,term_id,member_id,status,joined_at,ends_at)
select pg_temp.fid('tm-'||s),pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid(s),'active',statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days' from (values('head'),('member')) v(s);
insert into public.roles(id,organization_id,term_id,code,name) values(pg_temp.fid('role'),pg_temp.fid('org'),pg_temp.fid('term'),'reader','Fictional reader');
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('role'),'directory.read','term');
insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('role'),'committee.manage','unit');
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('tm-head'),pg_temp.fid('role'),'term',statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days',pg_temp.fid('tm-head'));
insert into public.private_profiles(member_id,organization_id,course,phone)
values(pg_temp.fid('member'),pg_temp.fid('org'),'Private course','Private phone');
insert into public.org_units(id,organization_id,term_id,code,name)
select pg_temp.fid(s),pg_temp.fid('org'),pg_temp.fid('term'),s,'Fictional process '||s from (values('ONE'),('TWO')) v(s);
insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)
select pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('tm-member'),pg_temp.fid(s),'primary_contact',statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days',pg_temp.fid('tm-head') from (values('ONE'),('TWO')) v(s);
insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('tm-head'),pg_temp.fid('ONE'),'head',statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days',pg_temp.fid('tm-member'));
insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)
values(pg_temp.fid('org'),pg_temp.fid('term'),pg_temp.fid('tm-head'),pg_temp.fid('role'),'unit',pg_temp.fid('ONE'),statement_timestamp()-interval '1 day',statement_timestamp()+interval '20 days',pg_temp.fid('tm-member'));
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.fid('head')::text,true);
select pg_temp.require(public.has_capability(pg_temp.fid('term'),'committee.manage',pg_temp.fid('ONE')),'test caller actually has head management capability');
select pg_temp.require(public.read_own_profile(pg_temp.fid('term'))->>'memberId'=pg_temp.fid('head')::text
  and (public.read_own_profile(pg_temp.fid('term'))->>'version')::integer=0
  and public.read_own_profile(pg_temp.fid('term'))->>'course' is null,'head reads only self, absent profile has version zero');
select set_config('request.jwt.claim.sub',pg_temp.fid('member')::text,true);
select pg_temp.require(not public.has_capability(pg_temp.fid('term'),'directory.read')
  and public.read_own_profile(pg_temp.fid('term'))->>'course'='Private course'
  and public.read_own_profile(pg_temp.fid('term'))->>'phone'='Private phone'
  and (public.read_own_profile(pg_temp.fid('term'))->>'shareCourse')::boolean=false
  and (public.read_own_profile(pg_temp.fid('term'))->>'version')::integer=1,'owner can read unshared values and version without directory capability');
select pg_temp.require(public.read_own_profile(pg_temp.fid('other-term')) is null,'wrong term cannot reveal own profile');
select set_config('request.jwt.claim.sub',pg_temp.fid('head')::text,true);
select pg_temp.require((select count(*)=0 from public.private_profiles),'head cannot read another raw profile');
select pg_temp.reject($q$update public.private_profiles set share_course=true where member_id=pg_temp.fid('member')$q$,'42501');
select pg_temp.require((select value->>'course' is null and value->>'phone' is null from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'head cannot override or see unshared fields');
reset role;
update public.private_profiles set share_course=true where member_id=pg_temp.fid('member');
set local role authenticated;
select pg_temp.require((select value->>'course'='Private course' and value->>'phone' is null from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'only separately shared course appears');
reset role;
update public.private_profiles set share_course=false where member_id=pg_temp.fid('member');
set local role authenticated;
select pg_temp.require((select value->>'course' is null from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'withdrawal removes disclosure');
select 'ok 1 - P06_A1: raw profile isolation, head override denied, consent and withdrawal enforced' as tap;
select pg_temp.require(jsonb_array_length(public.read_people_directory(pg_temp.fid('term')))=2,'blank affiliation does not remove people');
select 'ok 2 - P06_A2: directory access independent of blank affiliation; persistent help/work links checked in UI' as tap;
select pg_temp.require((select jsonb_array_length(value->'units')=2 from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'two units in one person');
select pg_temp.require((select bool_and(jsonb_array_length(value->'primary')=1 and value->'backup'='[]'::jsonb) from jsonb_array_elements(public.read_process_contacts(pg_temp.fid('term')))),'primary and missing backup explicit');
select public.save_private_profile(pg_temp.fid('term'),'{"course":null}',0,pg_temp.fid('head-first-save'));
select pg_temp.require((public.read_own_profile(pg_temp.fid('term'))->>'version')::integer=1,'first absent-profile save creates version one');
select set_config('request.jwt.claim.sub',pg_temp.fid('member')::text,true);
select public.save_private_profile(pg_temp.fid('term'),'{"course":"  Updated course  ","phone":null}',3,pg_temp.fid('save'));
select pg_temp.require(public.read_own_profile(pg_temp.fid('term'))->>'course'='Updated course'
  and public.read_own_profile(pg_temp.fid('term'))->>'phone' is null,'owner saves private values, trims and clears');
select public.save_private_profile(pg_temp.fid('term'),'{"course":"  Updated course  ","phone":null}',3,pg_temp.fid('save'));
select pg_temp.require((public.read_own_profile(pg_temp.fid('term'))->>'version')::integer=4,'retry performs no second write');
select pg_temp.reject($q$select public.save_private_profile(pg_temp.fid('term'),'{"course":"Overwrite"}',3,pg_temp.fid('stale'))$q$,'40001');
select pg_temp.reject($q$select public.save_private_profile(pg_temp.fid('term'),'{"course":"Changed payload"}',3,pg_temp.fid('save'))$q$,'22023');
select pg_temp.reject($q$select public.save_private_profile(pg_temp.fid('term'),'{"shareCourse":true}',4,pg_temp.fid('bypass'))$q$,'22023');
select pg_temp.reject($q$select public.set_profile_visibility(pg_temp.fid('term'),'{"shareCourse":"true"}',4,pg_temp.fid('badtype'))$q$,'22023');
select public.set_profile_visibility(pg_temp.fid('term'),'{"shareCourse":true}',4,pg_temp.fid('share'));
select set_config('request.jwt.claim.sub',pg_temp.fid('head')::text,true);
select pg_temp.require((select value->>'course'='Updated course' from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'separate visibility command exposes consented field');
select set_config('request.jwt.claim.sub',pg_temp.fid('member')::text,true);
select public.set_profile_visibility(pg_temp.fid('term'),'{"shareCourse":false}',5,pg_temp.fid('withdraw'));
select public.save_private_profile(pg_temp.fid('term'),'{"course":"  Updated course  ","phone":null}',3,pg_temp.fid('save'));
select pg_temp.require((public.read_own_profile(pg_temp.fid('term'))->>'version')::integer=6 and (public.read_own_profile(pg_temp.fid('term'))->>'shareCourse')::boolean=false,'delayed save retry cannot undo withdrawal');
reset role;
select pg_temp.require((select count(*)=3 from public.profile_commands where member_id=pg_temp.fid('member')),'one audit record per accepted command');
select pg_temp.require(not exists(select 1 from public.profile_commands where row_to_json(profile_commands)::text like '%Updated course%'),'no private values in audit');
set local role authenticated;
select public.save_private_profile(pg_temp.fid('term'),'{"skills":"Fictional sound editing","pronunciation":"Fictional pronunciation","affiliation":"MEAn"}',6,pg_temp.fid('extras'));
select pg_temp.require(not public.has_capability(pg_temp.fid('term'),'directory.read'),'MEAn does not grant directory access');
select set_config('request.jwt.claim.sub',pg_temp.fid('head')::text,true);
select pg_temp.require((select value->>'skills' is null and value->>'pronunciation' is null and value->>'affiliation' is null from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'optional disclosures default private even for head');
select pg_temp.reject($q$update public.term_memberships set affiliation_tag='Overridden' where id=pg_temp.fid('tm-member')$q$,'42501');
select set_config('request.jwt.claim.sub',pg_temp.fid('member')::text,true);
select public.set_profile_visibility(pg_temp.fid('term'),'{"shareSkills":true,"shareAffiliation":true}',7,pg_temp.fid('share-extras'));
select set_config('request.jwt.claim.sub',pg_temp.fid('head')::text,true);
select pg_temp.require((select value->>'skills'='Fictional sound editing' and value->>'affiliation'='MEAn' and value->>'pronunciation' is null from jsonb_array_elements(public.read_people_directory(pg_temp.fid('term'))) where value->>'id'=pg_temp.fid('member')::text),'skills and affiliation independently shared, pronunciation private');
select set_config('request.jwt.claim.sub',pg_temp.fid('member')::text,true);
select public.save_private_profile(pg_temp.fid('term'),'{"affiliation":"  "}',8,pg_temp.fid('blank-affiliation'));
select pg_temp.require(public.read_own_profile(pg_temp.fid('term'))->>'affiliation' is null and public.current_term_membership(pg_temp.fid('term')) is not null,'blank affiliation preserves access');
select pg_temp.reject($q$select public.save_private_profile(pg_temp.fid('term'),jsonb_build_object('skills',repeat('x',1001)),9,pg_temp.fid('too-long'))$q$,'22023');
reset role;
update public.terms set state='frozen',frozen_at=statement_timestamp() where id=pg_temp.fid('term');
set local role authenticated;
select pg_temp.reject($q$select public.save_private_profile(pg_temp.fid('term'),'{"course":"Frozen"}',9,pg_temp.fid('frozen'))$q$,'42501');
reset role;
update public.terms set state='active' where id=pg_temp.fid('term');
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.fid('guest')::text,true);
select pg_temp.require(public.read_people_directory(pg_temp.fid('term'))='[]'::jsonb and public.read_process_contacts(pg_temp.fid('term'))='[]'::jsonb,'no guest-wide directory');
select pg_temp.require(public.read_own_profile(pg_temp.fid('term')) is null,'external guest cannot read a core private profile');
select pg_temp.reject($q$select public.save_private_profile(pg_temp.fid('term'),'{"course":"Guest"}',0,pg_temp.fid('guest-save'))$q$,'42501');
reset role;
update public.members set account_state='suspended' where id=pg_temp.fid('member');
update public.members set display_name='Renamed current label' where id=pg_temp.fid('member');
select pg_temp.require((select bool_and(actor_display_name='Fictional member') from public.profile_commands where member_id=pg_temp.fid('member')),'past commands retain captured attribution after rename/suspension without joining private profile');
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.fid('member')::text,true);
select pg_temp.require(public.read_own_profile(pg_temp.fid('term')) is null,'suspension denies own profile with same subject');
select set_config('request.jwt.claim.sub',pg_temp.fid('head')::text,true);
select pg_temp.require(jsonb_array_length(public.read_people_directory(pg_temp.fid('term')))=1,'former member profile absent');
select 'ok 3 - P06_A3: unique people with multiple units, missing backup and former/guest isolation; mobile checked separately' as tap;
rollback;
