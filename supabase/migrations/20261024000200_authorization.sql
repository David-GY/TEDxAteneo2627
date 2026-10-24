begin;

-- The trusted owner must bypass FORCE RLS to avoid recursive membership policies.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'Authorization migration requires a trusted RLS-bypassing owner';
  end if;
end; $$;

create function public.current_term_membership(p_term_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select tm.id from public.term_memberships tm
  join public.members m on m.id = tm.member_id and m.organization_id = tm.organization_id
  join public.terms t on t.id = tm.term_id and t.organization_id = tm.organization_id
  join public.organizations o on o.id = tm.organization_id
  where m.auth_user_id = (select auth.uid()) and m.account_state = 'active'
    and tm.term_id = p_term_id and tm.status = 'active' and o.state = 'active'
    and tm.joined_at <= statement_timestamp() and tm.ends_at > statement_timestamp()
    and t.state in ('active', 'frozen')
    and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
$$;

create function public.owns_active_member(p_member_id uuid, p_write boolean default false) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.term_memberships tm join public.terms t on t.id = tm.term_id
    where tm.member_id = p_member_id and tm.id = public.current_term_membership(tm.term_id)
      and (not p_write or t.state = 'active')
  )
$$;

create function public.has_capability(p_term_id uuid, p_capability text, p_unit_id uuid default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.role_assignments a
    join public.roles r on r.id = a.role_id and r.term_id = a.term_id and r.organization_id = a.organization_id
    join public.role_permissions p on p.role_id = r.id and p.term_id = a.term_id and p.organization_id = a.organization_id
    join public.term_memberships tm on tm.id = a.term_membership_id
    where a.term_membership_id = public.current_term_membership(p_term_id)
      and a.term_id = p_term_id and tm.membership_kind = 'core'
      and a.status = 'active' and r.state = 'active'
      and a.effective_from <= statement_timestamp() and a.effective_to > statement_timestamp()
      and p.capability = p_capability and p.allowed_scope = a.scope_type
      and ((a.scope_type in ('term', 'own') and p_unit_id is null) or
        (a.scope_type = 'unit' and a.unit_id = p_unit_id and exists (
          select 1 from public.unit_memberships d join public.org_units u on u.id = d.unit_id
          where d.term_membership_id = tm.id and d.unit_id = a.unit_id and d.term_id = a.term_id
            and d.organization_id = a.organization_id and d.status = 'active' and u.archived_at is null
            and d.effective_from <= statement_timestamp() and d.effective_to > statement_timestamp()
        )))
  )
$$;

create function public.read_directory(p_term_id uuid)
returns table(member_id uuid, display_name text)
language sql stable security definer set search_path = '' as $$
  select m.id, m.display_name
  from public.members m join public.term_memberships tm on tm.member_id = m.id and tm.organization_id = m.organization_id
  where public.has_capability(p_term_id, 'directory.read') and tm.term_id = p_term_id
    and tm.membership_kind = 'core' and tm.status = 'active' and m.account_state = 'active'
    and tm.joined_at <= statement_timestamp() and tm.ends_at > statement_timestamp()
  order by m.display_name, m.id
$$;

create function public.explain_access(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('membership_id', public.current_term_membership(p_term_id),
    'grants', coalesce((select jsonb_agg(jsonb_build_object(
      'role_id', a.role_id, 'capability', p.capability, 'scope', a.scope_type,
      'unit_id', a.unit_id, 'expires_at', a.effective_to) order by a.id, p.capability)
      from public.role_assignments a join public.role_permissions p on p.role_id = a.role_id
      join public.roles r on r.id = a.role_id and r.state = 'active'
      where a.term_membership_id = public.current_term_membership(p_term_id)
        and a.status = 'active' and a.effective_from <= statement_timestamp() and a.effective_to > statement_timestamp()
        and p.allowed_scope = a.scope_type and public.has_capability(p_term_id, p.capability, a.unit_id)), '[]'::jsonb))
$$;

-- Only authenticated callers; these accept a resource context, never an actor ID.
revoke all on function public.current_term_membership(uuid), public.owns_active_member(uuid,boolean),
  public.has_capability(uuid,text,uuid), public.read_directory(uuid), public.explain_access(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.current_term_membership(uuid), public.owns_active_member(uuid,boolean),
  public.has_capability(uuid,text,uuid), public.read_directory(uuid), public.explain_access(uuid) to authenticated;

grant select(id, slug, name, state) on public.organizations to authenticated;
create policy organizations_member_read on public.organizations for select to authenticated using (
  exists (select 1 from public.terms t where t.organization_id = organizations.id and public.current_term_membership(t.id) is not null)
);
grant select(id, organization_id, label, event_date, starts_on, closes_on, state, frozen_at) on public.terms to authenticated;
create policy terms_member_read on public.terms for select to authenticated using (public.current_term_membership(id) is not null);

-- A directory projection does not require broad SELECT on raw member identity.
grant select(id, organization_id, display_name, version) on public.members to authenticated;
grant update(display_name) on public.members to authenticated;
create policy members_own_read on public.members for select to authenticated using (public.owns_active_member(id));
create policy members_own_update on public.members for update to authenticated
  using (public.owns_active_member(id, true)) with check (public.owns_active_member(id, true));

grant select(id, organization_id, term_id, member_id, membership_kind, status, joined_at, ends_at, affiliation_tag, version)
  on public.term_memberships to authenticated;
grant update(affiliation_tag) on public.term_memberships to authenticated;
create policy term_memberships_own_read on public.term_memberships for select to authenticated
  using (id = public.current_term_membership(term_id));
create policy term_memberships_own_affiliation on public.term_memberships for update to authenticated
  using (id = public.current_term_membership(term_id) and public.owns_active_member(member_id, true))
  with check (id = public.current_term_membership(term_id) and public.owns_active_member(member_id, true));

grant select on public.private_profiles to authenticated;
grant insert(member_id, organization_id, course, year_level, phone, external_contact,
  share_course, share_year_level, share_phone, share_external_contact) on public.private_profiles to authenticated;
grant update(course, year_level, phone, external_contact, share_course, share_year_level, share_phone, share_external_contact)
  on public.private_profiles to authenticated;
create policy private_profiles_own_read on public.private_profiles for select to authenticated using (public.owns_active_member(member_id));
create policy private_profiles_own_insert on public.private_profiles for insert to authenticated with check (public.owns_active_member(member_id, true));
create policy private_profiles_own_update on public.private_profiles for update to authenticated
  using (public.owns_active_member(member_id, true)) with check (public.owns_active_member(member_id, true));

grant select(id, organization_id, term_id, code, name, delivery_committee, review_service, archived_at, version)
  on public.org_units to authenticated;
create policy org_units_scoped_read on public.org_units for select to authenticated using (
  archived_at is null and (public.has_capability(term_id, 'workspace.read')
    or public.has_capability(term_id, 'committee.manage', id)
    or public.has_capability(term_id, 'department.review', id)
    or public.has_capability(term_id, 'finance.review', id)
    or public.has_capability(term_id, 'feedback.review', id))
);
grant select(id, organization_id, term_id, term_membership_id, unit_id, deployment_type, status, effective_from, effective_to, approved_by, version)
  on public.unit_memberships to authenticated;
create policy unit_memberships_own_read on public.unit_memberships for select to authenticated
  using (term_membership_id = public.current_term_membership(term_id));

grant select(id, organization_id, term_id, term_membership_id, role_id, scope_type, unit_id, status, effective_from, effective_to, granted_by, version)
  on public.role_assignments to authenticated;
create policy role_assignments_own_read on public.role_assignments for select to authenticated
  using (term_membership_id = public.current_term_membership(term_id));
grant select(id, organization_id, term_id, code, name, privileged, state, version) on public.roles to authenticated;
create policy roles_assigned_read on public.roles for select to authenticated using (
  exists (select 1 from public.role_assignments a where a.role_id = roles.id
    and a.term_membership_id = public.current_term_membership(roles.term_id)
    and a.status = 'active' and a.effective_from <= statement_timestamp() and a.effective_to > statement_timestamp())
);
grant select(id, organization_id, term_id, role_id, capability, resource, action, allowed_scope, privileged, version)
  on public.role_permissions to authenticated;
create policy role_permissions_assigned_read on public.role_permissions for select to authenticated using (
  exists (select 1 from public.role_assignments a where a.role_id = role_permissions.role_id
    and a.term_membership_id = public.current_term_membership(role_permissions.term_id)
    and a.status = 'active' and a.effective_from <= statement_timestamp() and a.effective_to > statement_timestamp())
);

-- Grant/expiry/organization/role mutations remain closed even to application admins.
-- Future audited server commands must enforce delegation ceilings before writing them.
commit;
