begin;
create table public.profile_commands (
  member_id uuid not null references public.members(id),
  request_id uuid not null,
  actor_id uuid not null references auth.users(id),
  command text not null check(command in ('values','visibility')),
  fingerprint text not null check(length(fingerprint)=64),
  result_version integer not null check(result_version>0),
  occurred_at timestamptz not null default statement_timestamp(),
  primary key(member_id,request_id)
);
create index profile_commands_actor on public.profile_commands(actor_id);
alter table public.profile_commands enable row level security;
alter table public.profile_commands force row level security;
revoke all on public.profile_commands from public,anon,authenticated,service_role;
-- Close P03's direct-write path: all profile edits now require the audited commands.
revoke insert,update on public.private_profiles from authenticated;
revoke insert(member_id,organization_id,course,year_level,phone,external_contact,share_course,share_year_level,share_phone,share_external_contact),
  update(course,year_level,phone,external_contact,share_course,share_year_level,share_phone,share_external_contact)
  on public.private_profiles from authenticated;

create function app_private.change_profile(p_term_id uuid,p_command text,p_payload jsonb,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare tm public.term_memberships; old_profile public.private_profiles; previous public.profile_commands;
  field record; fingerprint text; current_version integer; new_version integer;
begin
  select * into tm from public.term_memberships where id=public.current_term_membership(p_term_id) and membership_kind='core';
  if not found then raise exception using errcode='42501',message='profile_permission_denied'; end if;
  -- Profile spans terms: serialize on the member, including concurrent first inserts/retries.
  perform 1 from public.members where id=tm.member_id for update;
  if tm.id is distinct from public.current_term_membership(p_term_id)
    or not exists(select 1 from public.terms where id=p_term_id and state='active') then
    raise exception using errcode='42501',message='profile_permission_denied'; end if;
  if p_request_id is null or p_expected_version is null or p_expected_version<0
    or p_command not in ('values','visibility') or p_payload is null or jsonb_typeof(p_payload)<>'object' or p_payload='{}'::jsonb then
    raise exception using errcode='22023',message='profile_invalid_input'; end if;
  for field in select key,value from jsonb_each(p_payload) loop
    if p_command='values' then
      if field.key not in ('course','yearLevel','phone','externalContact') or jsonb_typeof(field.value) not in ('string','null') then
        raise exception using errcode='22023',message='profile_invalid_field'; end if;
      if length(field.value #>> '{}') > (case field.key when 'course' then 200 when 'externalContact' then 320 else 80 end) then
        raise exception using errcode='22023',message='profile_value_too_long'; end if;
    else
      if field.key not in ('shareCourse','shareYearLevel','sharePhone','shareExternalContact') or jsonb_typeof(field.value)<>'boolean' then
        raise exception using errcode='22023',message='profile_invalid_visibility'; end if;
    end if;
  end loop;
  fingerprint:=encode(sha256(convert_to(jsonb_build_array(p_term_id,p_command,p_payload,p_expected_version)::text,'UTF8')),'hex');
  select * into previous from public.profile_commands where member_id=tm.member_id and request_id=p_request_id;
  if found then
    if previous.fingerprint<>fingerprint then raise exception using errcode='22023',message='profile_request_conflict'; end if;
    -- A delayed retry must never restore old values or disclose a stale private revision.
    return public.read_own_profile(p_term_id);
  end if;
  select * into old_profile from public.private_profiles where member_id=tm.member_id for update;
  current_version:=coalesce(old_profile.version,0);
  if current_version<>p_expected_version then raise exception using errcode='40001',message='profile_version_conflict'; end if;
  insert into public.private_profiles(member_id,organization_id,course,year_level,phone,external_contact,
    share_course,share_year_level,share_phone,share_external_contact)
  values(tm.member_id,tm.organization_id,
    case when p_payload?'course' then nullif(btrim(p_payload->>'course'),'') else old_profile.course end,
    case when p_payload?'yearLevel' then nullif(btrim(p_payload->>'yearLevel'),'') else old_profile.year_level end,
    case when p_payload?'phone' then nullif(btrim(p_payload->>'phone'),'') else old_profile.phone end,
    case when p_payload?'externalContact' then nullif(btrim(p_payload->>'externalContact'),'') else old_profile.external_contact end,
    coalesce((p_payload->>'shareCourse')::boolean,old_profile.share_course,false),
    coalesce((p_payload->>'shareYearLevel')::boolean,old_profile.share_year_level,false),
    coalesce((p_payload->>'sharePhone')::boolean,old_profile.share_phone,false),
    coalesce((p_payload->>'shareExternalContact')::boolean,old_profile.share_external_contact,false))
  on conflict(member_id) do update set course=excluded.course,year_level=excluded.year_level,phone=excluded.phone,
    external_contact=excluded.external_contact,share_course=excluded.share_course,share_year_level=excluded.share_year_level,
    share_phone=excluded.share_phone,share_external_contact=excluded.share_external_contact
  returning version into new_version;
  insert into public.profile_commands(member_id,request_id,actor_id,command,fingerprint,result_version)
  values(tm.member_id,p_request_id,auth.uid(),p_command,fingerprint,new_version);
  return public.read_own_profile(p_term_id);
end;
$$;
create function public.save_private_profile(p_term_id uuid,p_values jsonb,p_expected_version integer,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select app_private.change_profile(p_term_id,'values',p_values,p_expected_version,p_request_id)
$$;
create function public.set_profile_visibility(p_term_id uuid,p_visibility jsonb,p_expected_version integer,p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select app_private.change_profile(p_term_id,'visibility',p_visibility,p_expected_version,p_request_id)
$$;
revoke all on function app_private.change_profile(uuid,text,jsonb,integer,uuid),public.save_private_profile(uuid,jsonb,integer,uuid),public.set_profile_visibility(uuid,jsonb,integer,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.save_private_profile(uuid,jsonb,integer,uuid),public.set_profile_visibility(uuid,jsonb,integer,uuid) to authenticated;
commit;
