begin;
alter table public.private_profiles
  add column skills text check(skills is null or length(skills)<=1000),
  add column pronunciation text check(pronunciation is null or length(pronunciation)<=200),
  add column share_skills boolean not null default false,
  add column share_pronunciation boolean not null default false,
  add column share_affiliation boolean not null default false;
-- Preserve the existing term-specific affiliation source; it never grants privilege.
revoke update(affiliation_tag) on public.term_memberships from authenticated;
alter table public.profile_commands add column actor_display_name text;
comment on column public.profile_commands.actor_display_name is 'Name captured at command time for attribution, no private-profile join. Older events remain null rather than inventing a historic name.';
create or replace function app_private.change_profile(p_term_id uuid,p_command text,p_payload jsonb,p_expected_version integer,p_request_id uuid) returns jsonb
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
      if field.key not in ('course','yearLevel','phone','externalContact','skills','pronunciation','affiliation') or jsonb_typeof(field.value) not in ('string','null') then
        raise exception using errcode='22023',message='profile_invalid_field'; end if;
      if length(field.value #>> '{}') > (case field.key when 'course' then 200 when 'externalContact' then 320 when 'skills' then 1000 when 'pronunciation' then 200 else 80 end) then
        raise exception using errcode='22023',message='profile_value_too_long'; end if;
    else
      if field.key not in ('shareCourse','shareYearLevel','sharePhone','shareExternalContact','shareSkills','sharePronunciation','shareAffiliation') or jsonb_typeof(field.value)<>'boolean' then
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
  insert into public.private_profiles(member_id,organization_id,course,year_level,phone,external_contact,skills,pronunciation,
    share_course,share_year_level,share_phone,share_external_contact,share_skills,share_pronunciation,share_affiliation)
  values(tm.member_id,tm.organization_id,
    case when p_payload?'course' then nullif(btrim(p_payload->>'course'),'') else old_profile.course end,
    case when p_payload?'yearLevel' then nullif(btrim(p_payload->>'yearLevel'),'') else old_profile.year_level end,
    case when p_payload?'phone' then nullif(btrim(p_payload->>'phone'),'') else old_profile.phone end,
    case when p_payload?'externalContact' then nullif(btrim(p_payload->>'externalContact'),'') else old_profile.external_contact end,
    case when p_payload?'skills' then nullif(btrim(p_payload->>'skills'),'') else old_profile.skills end,
    case when p_payload?'pronunciation' then nullif(btrim(p_payload->>'pronunciation'),'') else old_profile.pronunciation end,
    coalesce((p_payload->>'shareCourse')::boolean,old_profile.share_course,false),
    coalesce((p_payload->>'shareYearLevel')::boolean,old_profile.share_year_level,false),
    coalesce((p_payload->>'sharePhone')::boolean,old_profile.share_phone,false),
    coalesce((p_payload->>'shareExternalContact')::boolean,old_profile.share_external_contact,false),
    coalesce((p_payload->>'shareSkills')::boolean,old_profile.share_skills,false),
    coalesce((p_payload->>'sharePronunciation')::boolean,old_profile.share_pronunciation,false),
    coalesce((p_payload->>'shareAffiliation')::boolean,old_profile.share_affiliation,false))
  on conflict(member_id) do update set course=excluded.course,year_level=excluded.year_level,phone=excluded.phone,
    external_contact=excluded.external_contact,share_course=excluded.share_course,share_year_level=excluded.share_year_level,
    share_phone=excluded.share_phone,share_external_contact=excluded.share_external_contact,skills=excluded.skills,pronunciation=excluded.pronunciation,share_skills=excluded.share_skills,share_pronunciation=excluded.share_pronunciation,share_affiliation=excluded.share_affiliation
  returning version into new_version;
  if p_command='values' and p_payload?'affiliation' then
    update public.term_memberships set affiliation_tag=nullif(btrim(p_payload->>'affiliation'),'') where id=tm.id;
  end if;
  insert into public.profile_commands(member_id,request_id,actor_id,command,fingerprint,result_version,actor_display_name)
  values(tm.member_id,p_request_id,auth.uid(),p_command,fingerprint,new_version,(select display_name from public.members where id=tm.member_id));
  return public.read_own_profile(p_term_id);
end;
$$;

create or replace function public.read_own_profile(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'memberId', tm.member_id, 'displayName', m.display_name,
    'version', coalesce(p.version,0),
    'skills',p.skills,'pronunciation',p.pronunciation,'affiliation',tm.affiliation_tag,
    'shareSkills',coalesce(p.share_skills,false),'sharePronunciation',coalesce(p.share_pronunciation,false),'shareAffiliation',coalesce(p.share_affiliation,false),
    'course', p.course, 'yearLevel', p.year_level,
    'phone', p.phone, 'externalContact', p.external_contact,
    'shareCourse', coalesce(p.share_course,false),
    'shareYearLevel', coalesce(p.share_year_level,false),
    'sharePhone', coalesce(p.share_phone,false),
    'shareExternalContact', coalesce(p.share_external_contact,false)
  ) from public.term_memberships tm
  join public.members m on m.id=tm.member_id and m.organization_id=tm.organization_id
  left join public.private_profiles p on p.member_id=tm.member_id and p.organization_id=tm.organization_id
  where tm.id=public.current_term_membership(p_term_id)
    and tm.membership_kind='core'
$$;


create or replace function public.read_people_directory(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.member_id, 'name', d.display_name,
    'contact', case when m.normalized_email like '%@student.ateneo.edu' then m.normalized_email end,
    'units', coalesce((select jsonb_agg(x.name order by x.name) from (
      select distinct u.name from public.unit_memberships um
      join public.org_units u on u.id=um.unit_id and u.archived_at is null
      where um.term_membership_id=tm.id and um.status='active'
        and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()
    ) x),'[]'::jsonb),
    'roles', coalesce((select jsonb_agg(x.name order by x.name) from (
      select distinct r.name from public.role_assignments a join public.roles r on r.id=a.role_id
      where a.term_membership_id=tm.id and a.status='active' and r.state='active'
        and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp()
        and (a.unit_id is null or exists(select 1 from public.unit_memberships um
          join public.org_units u on u.id=um.unit_id and u.archived_at is null
          where um.term_membership_id=tm.id and um.unit_id=a.unit_id and um.status='active'
            and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()))
    ) x),'[]'::jsonb),
    'skills',case when p.share_skills then p.skills end,
    'pronunciation',case when p.share_pronunciation then p.pronunciation end,
    'affiliation',case when p.share_affiliation then tm.affiliation_tag end,
    'course', case when p.share_course then p.course end,
    'year', case when p.share_year_level then p.year_level end,
    'phone', case when p.share_phone then p.phone end,
    'externalContact', case when p.share_external_contact then p.external_contact end
  ) order by d.display_name,d.member_id),'[]'::jsonb)
  from public.read_directory(p_term_id) d
  join public.members m on m.id=d.member_id
  join public.term_memberships tm on tm.member_id=d.member_id and tm.term_id=p_term_id
  left join public.private_profiles p on p.member_id=d.member_id
$$;


commit;
