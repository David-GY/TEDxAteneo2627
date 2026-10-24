begin;

-- P02 has no permitted client policies. P03 must grant narrowly and add RLS together.
revoke create on schema public from public, anon, authenticated;
alter default privileges in schema public revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema public revoke all on sequences from public, anon, authenticated, service_role;
-- PUBLIC execute is a global default; a schema-only revoke cannot remove it.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated, service_role;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null check (length(btrim(name)) between 1 and 200),
  state text not null default 'active' check (state in ('active', 'archived'))
);

create table public.terms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  label text not null check (length(btrim(label)) between 1 and 200),
  event_date date not null,
  starts_on date not null,
  closes_on date not null,
  state text not null default 'draft' check (state in ('draft', 'active', 'frozen', 'archived')),
  frozen_at timestamptz,
  unique (organization_id, id),
  unique (organization_id, label),
  check (starts_on <= event_date and event_date <= closes_on),
  check (state <> 'frozen' or frozen_at is not null)
);
create unique index terms_one_active_per_org on public.terms(organization_id) where state = 'active';

create table public.members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  auth_user_id uuid unique references auth.users(id),
  email text not null,
  normalized_email text generated always as (lower(btrim(email))) stored not null,
  display_name text not null check (length(btrim(display_name)) between 1 and 200),
  account_state text not null default 'invited' check (account_state in ('invited', 'active', 'suspended', 'archived')),
  unique (organization_id, id),
  unique (organization_id, normalized_email),
  check (normalized_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$')
);

create table public.term_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  member_id uuid not null,
  membership_kind text not null default 'core' check (membership_kind in ('core', 'guest')),
  status text not null default 'pending' check (status in ('pending', 'active', 'suspended', 'expired', 'revoked')),
  joined_at timestamptz not null,
  ends_at timestamptz not null,
  affiliation_tag text check (affiliation_tag is null or length(btrim(affiliation_tag)) between 1 and 80),
  unique (organization_id, term_id, id),
  unique (term_id, member_id),
  foreign key (organization_id, term_id) references public.terms(organization_id, id),
  foreign key (organization_id, member_id) references public.members(organization_id, id),
  check (joined_at < ends_at)
);
create index term_memberships_member_idx on public.term_memberships(organization_id, member_id);

create table public.private_profiles (
  member_id uuid primary key,
  organization_id uuid not null,
  course text check (course is null or length(course) <= 200),
  year_level text check (year_level is null or length(year_level) <= 80),
  phone text check (phone is null or length(phone) <= 80),
  external_contact text check (external_contact is null or length(external_contact) <= 320),
  share_course boolean not null default false,
  share_year_level boolean not null default false,
  share_phone boolean not null default false,
  share_external_contact boolean not null default false,
  foreign key (organization_id, member_id) references public.members(organization_id, id)
);
create index private_profiles_org_member_idx on public.private_profiles(organization_id, member_id);

create table public.org_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  code text not null check (code ~ '^[A-Z][A-Z0-9_-]{0,39}$'),
  name text not null check (length(btrim(name)) between 1 and 200),
  delivery_committee boolean not null default false,
  review_service boolean not null default false,
  archived_at timestamptz,
  unique (organization_id, term_id, id),
  unique (term_id, code),
  foreign key (organization_id, term_id) references public.terms(organization_id, id)
);

create table public.unit_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  term_membership_id uuid not null,
  unit_id uuid not null,
  deployment_type text not null check (deployment_type in ('member', 'head', 'associate', 'primary_contact', 'backup_contact')),
  status text not null default 'active' check (status in ('active', 'expired', 'revoked')),
  effective_from timestamptz not null,
  effective_to timestamptz not null,
  approved_by uuid not null,
  unique (term_membership_id, unit_id, deployment_type, effective_from),
  foreign key (organization_id, term_id, term_membership_id) references public.term_memberships(organization_id, term_id, id),
  foreign key (organization_id, term_id, unit_id) references public.org_units(organization_id, term_id, id),
  foreign key (organization_id, term_id, approved_by) references public.term_memberships(organization_id, term_id, id),
  check (effective_from < effective_to)
);
create index unit_memberships_member_idx on public.unit_memberships(organization_id, term_id, term_membership_id);
create index unit_memberships_unit_idx on public.unit_memberships(organization_id, term_id, unit_id);
create index unit_memberships_approver_idx on public.unit_memberships(organization_id, term_id, approved_by);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  code text not null check (code ~ '^[a-z][a-z0-9_]{0,59}$'),
  name text not null check (length(btrim(name)) between 1 and 200),
  privileged boolean not null default false,
  state text not null default 'active' check (state in ('active', 'retired')),
  unique (organization_id, term_id, id),
  unique (term_id, code),
  foreign key (organization_id, term_id) references public.terms(organization_id, id)
);

create table public.role_permissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  role_id uuid not null,
  capability text not null check (capability in (
    'workspace.read', 'directory.read', 'profile.edit_own', 'committee.manage',
    'department.review', 'finance.review', 'feedback.review', 'mentoring.view',
    'reports.view', 'admin.configure', 'roles.manage'
  )),
  resource text generated always as (split_part(capability, '.', 1)) stored not null,
  action text generated always as (split_part(capability, '.', 2)) stored not null,
  allowed_scope text not null check (allowed_scope in ('own', 'unit', 'term')),
  privileged boolean generated always as (capability in (
    'committee.manage', 'department.review', 'finance.review', 'feedback.review', 'admin.configure', 'roles.manage'
  )) stored not null,
  unique (role_id, capability, allowed_scope),
  foreign key (organization_id, term_id, role_id) references public.roles(organization_id, term_id, id),
  check (
    (capability = 'profile.edit_own' and allowed_scope = 'own') or
    (capability in ('committee.manage', 'department.review', 'finance.review', 'feedback.review') and allowed_scope = 'unit') or
    (capability in ('workspace.read', 'directory.read', 'reports.view', 'admin.configure', 'roles.manage') and allowed_scope = 'term') or
    (capability = 'mentoring.view' and allowed_scope = 'own')
  )
);
create index role_permissions_role_idx on public.role_permissions(organization_id, term_id, role_id);

create table public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  term_id uuid not null,
  term_membership_id uuid not null,
  role_id uuid not null,
  scope_type text not null check (scope_type in ('own', 'unit', 'term')),
  unit_id uuid,
  status text not null default 'active' check (status in ('active', 'expired', 'revoked')),
  effective_from timestamptz not null,
  effective_to timestamptz not null,
  granted_by uuid not null,
  foreign key (organization_id, term_id, term_membership_id) references public.term_memberships(organization_id, term_id, id),
  foreign key (organization_id, term_id, role_id) references public.roles(organization_id, term_id, id),
  foreign key (organization_id, term_id, unit_id) references public.org_units(organization_id, term_id, id),
  foreign key (organization_id, term_id, granted_by) references public.term_memberships(organization_id, term_id, id),
  check ((scope_type = 'unit') = (unit_id is not null)),
  check (effective_from < effective_to)
  -- No work_id/scope='work' until P07 supplies a real work_items FK.
);
create index role_assignments_member_idx on public.role_assignments(organization_id, term_id, term_membership_id);
create index role_assignments_role_idx on public.role_assignments(organization_id, term_id, role_id);
create index role_assignments_unit_idx on public.role_assignments(organization_id, term_id, unit_id);
create index role_assignments_grantor_idx on public.role_assignments(organization_id, term_id, granted_by);

create function public.stamp_identity_row() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := statement_timestamp();
    new.created_by := auth.uid();
    new.version := 1;
  else
    new.created_at := old.created_at;
    new.created_by := old.created_by;
    new.version := old.version + 1;
  end if;
  new.updated_at := statement_timestamp();
  new.updated_by := auth.uid();
  return new;
end;
$$;

create function public.protect_member_identity() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin') then
    if tg_op = 'INSERT' then
      raise exception 'Member identity is server controlled' using errcode = '42501';
    elsif new.auth_user_id is distinct from old.auth_user_id
       or new.email is distinct from old.email
       or new.organization_id is distinct from old.organization_id then
      raise exception 'Member identity is server controlled' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
create trigger members_protect_identity before insert or update on public.members
for each row execute function public.protect_member_identity();

do $$
declare table_name text;
begin
  foreach table_name in array array['organizations', 'terms', 'members', 'term_memberships',
    'private_profiles', 'org_units', 'unit_memberships', 'roles', 'role_permissions', 'role_assignments']
  loop
    execute format('alter table public.%I
      add column created_at timestamptz not null default statement_timestamp(),
      add column created_by uuid references auth.users(id),
      add column updated_at timestamptz not null default statement_timestamp(),
      add column updated_by uuid references auth.users(id),
      add column version integer not null default 1 check (version > 0)', table_name);
    execute format('create index %I on public.%I(created_by)', table_name || '_created_by_idx', table_name);
    execute format('create index %I on public.%I(updated_by)', table_name || '_updated_by_idx', table_name);
    execute format('create trigger stamp_identity_row before insert or update on public.%I
      for each row execute function public.stamp_identity_row()', table_name);
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', table_name);
  end loop;
end;
$$;
revoke all on function public.stamp_identity_row(), public.protect_member_identity() from public, anon, authenticated, service_role;

comment on column public.term_memberships.affiliation_tag is 'Nullable description only. Never an authorization input.';
comment on column public.org_units.delivery_committee is 'Delivery responsibility independent of review_service; both may be true.';
comment on column public.members.auth_user_id is 'Stable member linked to verified auth identity only by trusted server code. No metadata-driven provisioning.';
comment on table public.role_assignments is 'P03 checks effective membership, status, dates and capability scope. P07 adds work scope with a real FK.';
commit;
