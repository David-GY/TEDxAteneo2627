begin;
-- No work-item IDs or implied organization membership before P07.
create table public.guest_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  sponsor_id uuid not null,
  email text not null check (length(email)<=254 and email=lower(btrim(email)) and email ~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'),
  token_hash text not null unique check (token_hash ~ '^[a-f0-9]{64}$'),
  scope_mode text not null default 'awaiting_record_attachment' check (scope_mode='awaiting_record_attachment'),
  created_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz not null default statement_timestamp()+interval '14 days',
  redeemed_by uuid references auth.users(id),
  redeemed_at timestamptz,
  revoked_at timestamptz,
  version integer not null default 1 check (version>0),
  request_id uuid not null,
  replaces_id uuid references public.guest_invitations(id),
  unique(sponsor_id,request_id),
  foreign key (sponsor_id,organization_id,term_id) references public.term_memberships(id,organization_id,term_id),
  check (expires_at>created_at and expires_at<=created_at+interval '14 days'),
  check ((redeemed_by is null)=(redeemed_at is null))
);
create index guest_invitations_redeemed on public.guest_invitations(redeemed_by) where redeemed_by is not null;
create table public.guest_invitation_events (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null references public.guest_invitations(id),
  actor_id uuid not null references auth.users(id),
  event text not null check (event in ('created','redeemed','revoked','renewed')),
  occurred_at timestamptz not null default statement_timestamp(),
  request_id uuid,
  unique(invitation_id,request_id)
);
alter table public.guest_invitations enable row level security;
alter table public.guest_invitations force row level security;
alter table public.guest_invitation_events enable row level security;
alter table public.guest_invitation_events force row level security;
revoke all on public.guest_invitations,public.guest_invitation_events from public,anon,authenticated,service_role;

create function app_private.verified_google_email(p_user uuid) returns text
language sql stable set search_path='' as $$
  select lower(btrim(u.email)) from auth.users u where u.id=p_user and u.email_confirmed_at is not null
    and exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='google'
      and i.identity_data->'email_verified'='true'::jsonb
      and lower(btrim(i.identity_data->>'email'))=lower(btrim(u.email)))
$$;
-- Evaluate the sponsor's current authority even when the caller is a guest.
create function app_private.active_guest_sponsor(p_sponsor uuid) returns boolean
language sql stable set search_path='' as $$
  select exists(select 1 from public.term_memberships tm
    join public.members m on m.id=tm.member_id
    join public.terms t on t.id=tm.term_id join public.organizations o on o.id=tm.organization_id
    join public.role_assignments a on a.term_membership_id=tm.id
    join public.roles r on r.id=a.role_id
    join public.role_permissions p on p.role_id=r.id and p.capability='roles.manage' and p.allowed_scope='term'
    where tm.id=p_sponsor and tm.membership_kind='core' and tm.status='active'
      and m.account_state='active' and app_private.is_school_identity(m.auth_user_id)
      and m.normalized_email=app_private.verified_google_email(m.auth_user_id)
      and o.state='active' and t.state='active'
      and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
      and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
      and a.status='active' and a.scope_type='term' and r.state='active'
      and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp())
$$;

create function public.create_guest_invitation(p_term_id uuid,p_email text,p_request_id uuid,
  p_expires_at timestamptz default null,p_replaces_id uuid default null,p_expected_version integer default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare sponsor uuid:=public.current_term_membership(p_term_id); row public.guest_invitations;
  old_row public.guest_invitations; token text; mail text:=lower(btrim(p_email)); expiry timestamptz;
begin
  if sponsor is null or not app_private.active_guest_sponsor(sponsor) then raise exception using errcode='42501',message='guest_permission_denied'; end if;
  -- Serialize creation/retries for this sponsor, not all organizations.
  perform 1 from public.term_memberships where id=sponsor for update;
  if p_request_id is null or mail is null or length(mail)>254 or mail !~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' then
    raise exception using errcode='22023',message='guest_invalid_input'; end if;
  select * into row from public.guest_invitations where sponsor_id=sponsor and request_id=p_request_id;
  if found then
    if row.email<>mail or row.replaces_id is distinct from p_replaces_id or (p_expires_at is not null and row.expires_at<>p_expires_at) then
      raise exception using errcode='22023',message='guest_request_conflict'; end if;
    return jsonb_build_object('id',row.id,'token',null,'reused',true);
  end if;
  expiry:=coalesce(p_expires_at,statement_timestamp()+interval '14 days');
  if expiry<=statement_timestamp() or expiry>statement_timestamp()+interval '14 days' then
    raise exception using errcode='22023',message='guest_invalid_expiry'; end if;
  if p_replaces_id is not null then
    select * into old_row from public.guest_invitations where id=p_replaces_id for update;
    if not found or old_row.sponsor_id<>sponsor then raise exception using errcode='42501',message='guest_permission_denied'; end if;
    if p_expected_version is null or old_row.version<>p_expected_version or old_row.revoked_at is not null then
      raise exception using errcode='40001',message='guest_version_conflict'; end if;
    if old_row.email<>mail then raise exception using errcode='22023',message='guest_request_conflict'; end if;
    update public.guest_invitations set revoked_at=statement_timestamp(),version=version+1 where id=old_row.id;
    insert into public.guest_invitation_events(invitation_id,actor_id,event,request_id) values(old_row.id,auth.uid(),'renewed',p_request_id);
  end if;
  token:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  insert into public.guest_invitations(organization_id,term_id,sponsor_id,email,token_hash,expires_at,request_id,replaces_id)
    select tm.organization_id,p_term_id,sponsor,mail,encode(sha256(convert_to(token,'UTF8')),'hex'),expiry,p_request_id,p_replaces_id
    from public.term_memberships tm where tm.id=sponsor returning * into row;
  insert into public.guest_invitation_events(invitation_id,actor_id,event,request_id) values(row.id,auth.uid(),'created',p_request_id);
  return jsonb_build_object('id',row.id,'token',token,'reused',false);
end; $$;

create function public.redeem_guest_invitation(p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare row public.guest_invitations; mail text:=app_private.verified_google_email(auth.uid());
begin
  if mail is null or p_token is null or p_token !~ '^[a-f0-9]{64}$' then raise exception using errcode='42501',message='guest_invitation_unavailable'; end if;
  select * into row from public.guest_invitations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
  if not found or row.email<>mail or row.revoked_at is not null or row.redeemed_at is not null
    or row.expires_at<=statement_timestamp() or not app_private.active_guest_sponsor(row.sponsor_id) then
    raise exception using errcode='42501',message='guest_invitation_unavailable'; end if;
  update public.guest_invitations set redeemed_by=auth.uid(),redeemed_at=statement_timestamp(),version=version+1 where id=row.id;
  insert into public.guest_invitation_events(invitation_id,actor_id,event) values(row.id,auth.uid(),'redeemed');
  return jsonb_build_object('state','redeemed','sharedRecords',0,'expiresAt',row.expires_at);
end; $$;

create function public.revoke_guest_access(p_invitation_id uuid,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare row public.guest_invitations;
begin
  select * into row from public.guest_invitations where id=p_invitation_id for update;
  if not found or row.sponsor_id is distinct from public.current_term_membership(row.term_id)
    or not app_private.active_guest_sponsor(row.sponsor_id) then raise exception using errcode='42501',message='guest_permission_denied'; end if;
  if p_request_id is null then raise exception using errcode='22023',message='guest_invalid_input'; end if;
  if exists(select 1 from public.guest_invitation_events where invitation_id=row.id and request_id=p_request_id and event='revoked') then
    return jsonb_build_object('state','revoked'); end if;
  if row.version is distinct from p_expected_version or row.revoked_at is not null then raise exception using errcode='40001',message='guest_version_conflict'; end if;
  update public.guest_invitations set revoked_at=statement_timestamp(),version=version+1 where id=row.id;
  insert into public.guest_invitation_events(invitation_id,actor_id,event,request_id) values(row.id,auth.uid(),'revoked',p_request_id);
  return jsonb_build_object('state','revoked');
end; $$;

create function public.list_guest_invitations(p_term_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'expiresAt',i.expires_at,
    'redeemedAt',i.redeemed_at,'revokedAt',i.revoked_at,'version',i.version,'scopeMode',i.scope_mode) order by i.created_at desc),'[]'::jsonb)
  from public.guest_invitations i where i.term_id=p_term_id
    and i.sponsor_id=public.current_term_membership(p_term_id) and app_private.active_guest_sponsor(i.sponsor_id)
$$;

-- Keep the core resolver private and unchanged; no guest membership/roles are created.
alter function public.resolve_auth_context() set schema app_private;
create function public.resolve_auth_context() returns jsonb
language plpgsql security definer set search_path='' as $$
declare core jsonb; row public.guest_invitations;
begin
  core:=app_private.resolve_auth_context();
  if core->>'state'='authorized' then return core; end if;
  select * into row from public.guest_invitations i where i.redeemed_by=auth.uid()
    and i.email=app_private.verified_google_email(auth.uid()) and i.revoked_at is null
    and i.expires_at>statement_timestamp() and app_private.active_guest_sponsor(i.sponsor_id)
    order by i.expires_at desc,i.id limit 1;
  if not found then return jsonb_build_object('state','denied'); end if;
  return jsonb_build_object('state','authorized','audience','guest','guestAccessId',row.id,'displayName','Invited guest',
    'organizationId',row.organization_id,'termId',row.term_id,'expiresAt',row.expires_at,'capabilities','[]'::jsonb);
end; $$;
revoke all on all functions in schema app_private from public,anon,authenticated,service_role;
revoke all on function public.create_guest_invitation(uuid,text,uuid,timestamptz,uuid,integer),
  public.redeem_guest_invitation(text),public.revoke_guest_access(uuid,integer,uuid),
  public.list_guest_invitations(uuid),public.resolve_auth_context() from public,anon,authenticated,service_role;
grant execute on function public.create_guest_invitation(uuid,text,uuid,timestamptz,uuid,integer),
  public.redeem_guest_invitation(text),public.revoke_guest_access(uuid,integer,uuid),
  public.list_guest_invitations(uuid),public.resolve_auth_context() to authenticated;
commit;
