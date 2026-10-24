begin;
create table public.guest_contact_profiles (
  user_id uuid primary key references auth.users(id),
  display_name text check(display_name is null or length(display_name)<=200),
  contact_route text check(contact_route is null or length(contact_route)<=320),
  version integer not null default 1 check(version>0),
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid references auth.users(id),
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid references auth.users(id)
);
create table public.guest_profile_commands (
  user_id uuid not null references auth.users(id),
  request_id uuid not null,
  invitation_id uuid not null references public.guest_invitations(id),
  fingerprint text not null check(length(fingerprint)=64),
  result_version integer not null check(result_version>0),
  occurred_at timestamptz not null default statement_timestamp(),
  primary key(user_id,request_id)
);
create index guest_profile_commands_invitation on public.guest_profile_commands(invitation_id);
create index guest_contact_profiles_created_by on public.guest_contact_profiles(created_by);
create index guest_contact_profiles_updated_by on public.guest_contact_profiles(updated_by);
alter table public.guest_contact_profiles enable row level security;
alter table public.guest_contact_profiles force row level security;
alter table public.guest_profile_commands enable row level security;
alter table public.guest_profile_commands force row level security;
revoke all on public.guest_contact_profiles,public.guest_profile_commands from public,anon,authenticated,service_role;
create trigger stamp_guest_contact_profile before insert or update on public.guest_contact_profiles
for each row execute function public.stamp_identity_row();

create function app_private.current_guest_invitation(p_term_id uuid) returns uuid
language sql stable set search_path='' as $$
  select i.id from public.guest_invitations i where i.term_id=p_term_id and i.redeemed_by=auth.uid()
    and i.email=app_private.verified_google_email(auth.uid()) and i.revoked_at is null
    and i.expires_at>statement_timestamp() and app_private.active_guest_sponsor(i.sponsor_id)
  order by i.expires_at desc,i.id limit 1
$$;
create function public.read_guest_contacts(p_term_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('own',jsonb_build_object(
    'displayName',coalesce(p.display_name,'Invited guest'),
    'verifiedEmail',app_private.verified_google_email(auth.uid()),
    'contactRoute',p.contact_route,'version',coalesce(p.version,0)),
    'sharedContacts','[]'::jsonb,'scopeMode','awaiting_record_attachment')
  from auth.users u left join public.guest_contact_profiles p on p.user_id=u.id
  where u.id=auth.uid() and app_private.current_guest_invitation(p_term_id) is not null
$$;
create function public.save_guest_contact_profile(p_term_id uuid,p_values jsonb,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare invitation uuid; previous public.guest_profile_commands; old_profile public.guest_contact_profiles;
  field record; fingerprint text; new_version integer;
begin
  invitation:=app_private.current_guest_invitation(p_term_id);
  if invitation is null then raise exception using errcode='42501',message='guest_profile_permission_denied'; end if;
  perform 1 from auth.users where id=auth.uid() for update;
  invitation:=app_private.current_guest_invitation(p_term_id);
  if invitation is null then raise exception using errcode='42501',message='guest_profile_permission_denied'; end if;
  if p_request_id is null or p_expected_version is null or p_expected_version<0
    or p_values is null or jsonb_typeof(p_values)<>'object' or p_values='{}'::jsonb then
    raise exception using errcode='22023',message='guest_profile_invalid_input'; end if;
  for field in select key,value from jsonb_each(p_values) loop
    if field.key not in ('displayName','contactRoute') or jsonb_typeof(field.value) not in ('string','null')
      or length(field.value #>> '{}')>(case field.key when 'displayName' then 200 else 320 end) then
      raise exception using errcode='22023',message='guest_profile_invalid_field'; end if;
  end loop;
  fingerprint:=encode(sha256(convert_to(jsonb_build_array(p_term_id,p_values,p_expected_version)::text,'UTF8')),'hex');
  select * into previous from public.guest_profile_commands where user_id=auth.uid() and request_id=p_request_id;
  if found then
    if previous.fingerprint<>fingerprint then raise exception using errcode='22023',message='guest_profile_request_conflict'; end if;
    return public.read_guest_contacts(p_term_id);
  end if;
  select * into old_profile from public.guest_contact_profiles where user_id=auth.uid() for update;
  if coalesce(old_profile.version,0)<>p_expected_version then raise exception using errcode='40001',message='guest_profile_version_conflict'; end if;
  insert into public.guest_contact_profiles(user_id,display_name,contact_route)
  values(auth.uid(),case when p_values?'displayName' then nullif(btrim(p_values->>'displayName'),'') else old_profile.display_name end,
    case when p_values?'contactRoute' then nullif(btrim(p_values->>'contactRoute'),'') else old_profile.contact_route end)
  on conflict(user_id) do update set display_name=excluded.display_name,contact_route=excluded.contact_route
  returning version into new_version;
  insert into public.guest_profile_commands(user_id,request_id,invitation_id,fingerprint,result_version)
  values(auth.uid(),p_request_id,invitation,fingerprint,new_version);
  return public.read_guest_contacts(p_term_id);
end;
$$;
revoke all on function app_private.current_guest_invitation(uuid),public.read_guest_contacts(uuid),public.save_guest_contact_profile(uuid,jsonb,integer,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.read_guest_contacts(uuid),public.save_guest_contact_profile(uuid,jsonb,integer,uuid) to authenticated;
commit;
