begin;

create table app_private.tedx_positions (
  term_id uuid not null references public.terms(id),
  role_id uuid primary key references public.roles(id),
  unit_id uuid references public.org_units(id),
  tier text not null check (tier in ('leadership', 'head', 'core')),
  administrator boolean not null,
  unique (term_id, role_id),
  check ((tier = 'leadership') = (unit_id is null))
);

create table app_private.tedx_seats (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id),
  membership_id uuid not null references public.term_memberships(id),
  role_id uuid not null references app_private.tedx_positions(role_id),
  deployment_id uuid references public.unit_memberships(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  revoked boolean not null default false,
  version integer not null default 1,
  check (starts_at < ends_at)
);

create index tedx_seats_term_idx on app_private.tedx_seats(term_id, membership_id, role_id);
create table app_private.tedx_seat_grants (
  grant_id uuid primary key references public.role_assignments(id),
  seat_id uuid not null references app_private.tedx_seats(id)
);
create index tedx_seat_grants_seat_idx on app_private.tedx_seat_grants(seat_id);

create table app_private.tedx_seat_history (
  seat_id uuid not null references app_private.tedx_seats(id),
  version integer not null,
  actor_id uuid not null references public.term_memberships(id),
  changed_at timestamptz not null default statement_timestamp(),
  reason text not null,
  before_value jsonb,
  after_value jsonb not null,
  primary key (seat_id, version)
);

alter table app_private.tedx_positions enable row level security;
alter table app_private.tedx_seats enable row level security;
alter table app_private.tedx_seat_grants enable row level security;
alter table app_private.tedx_seat_history enable row level security;
revoke all on app_private.tedx_positions, app_private.tedx_seats, app_private.tedx_seat_grants,
  app_private.tedx_seat_history from public, anon, authenticated, service_role;

-- Existing grants still use the existing identity, validity, scope and lineage rules.
-- A preset grant additionally needs its own live seat and, for committee roles, its exact deployment.
create function app_private.tedx_seat_grant_live(p_grant public.role_assignments) returns boolean
language sql stable set search_path = '' as $$
  select not exists (select 1 from app_private.tedx_positions p where p.role_id = p_grant.role_id)
  or exists (
    select 1 from app_private.tedx_seat_grants g
    join app_private.tedx_seats s on s.id = g.seat_id
    join app_private.tedx_positions p on p.role_id = s.role_id
    where g.grant_id = p_grant.id and s.role_id = p_grant.role_id and s.term_id = p_grant.term_id
      and s.membership_id = p_grant.term_membership_id and not s.revoked
      and s.starts_at <= statement_timestamp() and s.ends_at > statement_timestamp()
      and (p.unit_id is null or exists (
        select 1 from public.unit_memberships d join public.org_units u on u.id = d.unit_id
        where d.id = s.deployment_id and d.unit_id = p.unit_id and d.term_membership_id = s.membership_id
          and d.status = 'active' and u.archived_at is null
          and d.effective_from <= statement_timestamp() and d.effective_to > statement_timestamp()
      ))
  )
$$;
revoke all on function app_private.tedx_seat_grant_live(public.role_assignments) from public, anon, authenticated, service_role;

create or replace function app_private.access_base_live(p_assignment uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id join public.members m on m.id=tm.member_id join public.terms t on t.id=a.term_id join public.organizations o on o.id=tm.organization_id
 where a.id=p_assignment and app_private.tedx_seat_grant_live(a) and a.term_id=tm.term_id and r.term_id=a.term_id and r.state='active'and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()
 and tm.membership_kind='core'and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and m.account_state='active'and app_private.is_school_identity(m.auth_user_id)and app_private.verified_google_email(m.auth_user_id)=m.normalized_email
 and t.state in('active','frozen')and o.state='active'and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and(a.scope_type<>'unit'or exists(select 1 from public.unit_memberships d join public.org_units u on u.id=d.unit_id where d.term_membership_id=tm.id and d.unit_id=a.unit_id and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()and u.archived_at is null))
 and(a.scope_type<>'work'or exists(select 1 from public.work_items w where w.id=a.work_id and w.term_id=a.term_id and w.archived_at is null)))
$$;

create function app_private.tedx_materialize_seat(
  p_seat app_private.tedx_seats, p_position app_private.tedx_positions, p_actor public.term_memberships
) returns app_private.tedx_seats language plpgsql set search_path = '' as $$
declare
  seat app_private.tedx_seats := p_seat;
  deployment uuid;
  grant_scope record;
  new_grant uuid;
begin
  if p_position.unit_id is not null then
    insert into public.unit_memberships (
      organization_id, term_id, term_membership_id, unit_id, deployment_type,
      effective_from, effective_to, approved_by
    ) values (
      p_actor.organization_id, seat.term_id, seat.membership_id, p_position.unit_id,
      case when p_position.tier = 'head' then 'head' else 'member' end,
      seat.starts_at, seat.ends_at, p_actor.id
    ) on conflict (term_membership_id, unit_id, deployment_type, effective_from) do update
      set status = 'active', effective_to = excluded.effective_to, approved_by = excluded.approved_by
      where public.unit_memberships.status = 'revoked' and exists (
        select 1 from app_private.tedx_seat_history h
        where h.seat_id = seat.id and h.after_value->>'deployment_id' = public.unit_memberships.id::text
      )
    returning id into deployment;
    if deployment is null then
      raise exception using errcode = '23505', message = 'command_deployment_overlap';
    end if;
    update app_private.tedx_seats set deployment_id = deployment where id = seat.id returning * into seat;
  end if;
  for grant_scope in select distinct allowed_scope from public.role_permissions where role_id = p_position.role_id loop
    insert into public.role_assignments (
      organization_id, term_id, term_membership_id, role_id, scope_type, unit_id,
      effective_from, effective_to, granted_by
    ) values (
      p_actor.organization_id, seat.term_id, seat.membership_id, seat.role_id, grant_scope.allowed_scope,
      case when grant_scope.allowed_scope = 'unit' then p_position.unit_id end,
      seat.starts_at, seat.ends_at, p_actor.id
    ) returning id into new_grant;
    insert into app_private.tedx_seat_grants values (new_grant, seat.id);
  end loop;
  return seat;
end;
$$;
revoke all on function app_private.tedx_materialize_seat(app_private.tedx_seats,app_private.tedx_positions,public.term_memberships)
  from public, anon, authenticated, service_role;

create function public.read_tedx_positions(p_term_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform app_private.organization_actor(p_term_id);
  return jsonb_build_object(
    'positions', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.role_id, 'name', r.name, 'unitId', p.unit_id,
        'tier', p.tier, 'administrator', p.administrator,
        'available', r.state = 'active' and (p.unit_id is null or u.archived_at is null))
        order by case when p.tier = 'leadership' then 0 else 1 end, u.name,
          case when p.tier = 'head' then 0 else 1 end, r.name)
      from app_private.tedx_positions p join public.roles r on r.id = p.role_id
      left join public.org_units u on u.id = p.unit_id where p.term_id = p_term_id
    ), '[]'::jsonb),
    'seats', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'membershipId', s.membership_id, 'roleId', s.role_id,
        'deploymentId', s.deployment_id, 'version', s.version, 'from', s.starts_at, 'to', s.ends_at,
        'state', case when s.ends_at <= statement_timestamp() then 'Expired'
          when s.starts_at > statement_timestamp() then 'Scheduled'
          when exists (
            select 1 from app_private.tedx_seat_grants g
            where g.seat_id = s.id and app_private.access_base_live(g.grant_id)
          ) then 'Active' else 'Pending access' end,
        'managed', s.membership_id <> public.current_term_membership(p_term_id)
          or not p.administrator)
        order by s.starts_at, s.id)
      from app_private.tedx_seats s join app_private.tedx_positions p on p.role_id = s.role_id
      where s.term_id = p_term_id and not s.revoked
    ), '[]'::jsonb)
  );
end;
$$;

create function public.save_tedx_seat(
  p_term_id uuid, p_seat_id uuid, p_expected_version integer, p_membership_id uuid,
  p_role_id uuid, p_from timestamptz, p_to timestamptz, p_remove boolean, p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor public.term_memberships;
  target public.term_memberships;
  seat app_private.tedx_seats;
  previous app_private.tedx_seats;
  position app_private.tedx_positions;
  old_position app_private.tedx_positions;
  payload jsonb;
  receipt jsonb;
begin
  perform app_private.readiness_lock(p_term_id);
  actor := app_private.organization_actor(p_term_id, true);
  if p_reason is null or length(btrim(p_reason)) not between 1 and 1000 or p_remove is null then
    raise exception using errcode = '22023', message = 'command_validation_failed';
  end if;
  payload := jsonb_build_array(p_term_id, p_seat_id, p_expected_version, p_membership_id, p_role_id, p_from, p_to, p_remove, btrim(p_reason));
  receipt := app_private.begin_work_command('save_tedx_seat', p_request_id, payload);
  if receipt is not null then return receipt; end if;

  if p_seat_id is not null then
    select * into previous from app_private.tedx_seats where id = p_seat_id and term_id = p_term_id for update;
    if not found or previous.revoked or previous.version is distinct from p_expected_version then
      raise exception using errcode = '40001', message = 'command_stale_version';
    end if;
    if previous.membership_id is distinct from p_membership_id then
      raise exception using errcode = '22023', message = 'command_validation_failed';
    end if;
    select * into old_position from app_private.tedx_positions where role_id = previous.role_id;
  elsif p_remove or p_expected_version is not null then
    raise exception using errcode = '22023', message = 'command_validation_failed';
  end if;

  if not p_remove then
    select p.* into position from app_private.tedx_positions p
      join public.roles r on r.id = p.role_id and r.state = 'active'
      left join public.org_units u on u.id = p.unit_id
      where p.role_id = p_role_id and p.term_id = p_term_id and (p.unit_id is null or u.archived_at is null);
    select tm.* into target from public.term_memberships tm join public.members m on m.id = tm.member_id
      where tm.id = p_membership_id and tm.term_id = p_term_id and tm.membership_kind = 'core'
      and tm.status = 'active' and m.account_state in ('active', 'invited')
      and m.normalized_email ~ '^[^[:space:]@]+@student[.]ateneo[.]edu$';
    if position.role_id is null or target.id is null or p_from is null or p_to is null
      or not isfinite(p_from) or not isfinite(p_to) or p_from >= p_to
      or p_from < target.joined_at or p_to > target.ends_at or p_to <= statement_timestamp() then
      raise exception using errcode = '22023', message = 'command_validation_failed';
    end if;
    if exists (
      select 1 from app_private.tedx_seats s
      where s.term_id = p_term_id and s.membership_id = target.id and s.role_id = p_role_id
      and not s.revoked and s.id is distinct from p_seat_id and s.starts_at < p_to and s.ends_at > p_from
    ) then
      raise exception using errcode = '23505', message = 'command_position_overlap';
    end if;
  end if;

  if p_membership_id = actor.id and (coalesce(position.administrator, false) or coalesce(old_position.administrator, false)) then
    raise exception using errcode = '42501', message = 'command_permission_denied';
  end if;

  if previous.id is not null and previous.ends_at > statement_timestamp()
    and (p_remove or p_role_id <> previous.role_id or p_from > previous.starts_at or p_to < previous.ends_at) then
    if exists (
      select 1 from app_private.organization_obligations(p_term_id, null, previous.membership_id) w
        where old_position.unit_id is null or old_position.unit_id = w.lead_unit_id
          or exists (select 1 from public.tasks t where t.work_item_id = w.id and t.assigned_unit_id = old_position.unit_id)
          or exists (select 1 from public.requests r where r.work_item_id = w.id and r.receiving_unit_id = old_position.unit_id)
    ) or exists (
      select 1 from public.request_types rt where rt.term_id = p_term_id and rt.live_enabled and rt.archived_at is null
        and rt.receiving_unit_id = old_position.unit_id
        and previous.membership_id in (rt.primary_contact_id, rt.backup_contact_id)
    ) then
      raise exception using errcode = '55000', message = 'command_dependency_blocked';
    end if;
  end if;

  if previous.id is null then
    insert into app_private.tedx_seats(term_id, membership_id, role_id, starts_at, ends_at)
      values(p_term_id, target.id, position.role_id, p_from, p_to) returning * into seat;
    seat := app_private.tedx_materialize_seat(seat, position, actor);
  elsif p_remove then
    update public.role_assignments a set status = 'revoked'
      from app_private.tedx_seat_grants g where g.seat_id = previous.id and a.id = g.grant_id and a.status = 'active';
    update public.unit_memberships set status = 'revoked' where id = previous.deployment_id;
    update app_private.tedx_seats set revoked = true, version = version + 1 where id = previous.id returning * into seat;
  elsif previous.role_id = position.role_id then
    update public.unit_memberships set effective_from = p_from, effective_to = p_to where id = previous.deployment_id;
    update public.role_assignments a set effective_from = p_from, effective_to = p_to
      from app_private.tedx_seat_grants g where g.seat_id = previous.id and a.id = g.grant_id and a.status = 'active';
    update app_private.tedx_seats set starts_at = p_from, ends_at = p_to, version = version + 1
      where id = previous.id returning * into seat;
  else
    update public.role_assignments a set status = 'revoked'
      from app_private.tedx_seat_grants g where g.seat_id = previous.id and a.id = g.grant_id and a.status = 'active';
    update public.unit_memberships set status = 'revoked' where id = previous.deployment_id;
    update app_private.tedx_seats set role_id = position.role_id, deployment_id = null,
      starts_at = p_from, ends_at = p_to, version = version + 1 where id = previous.id returning * into seat;
    seat := app_private.tedx_materialize_seat(seat, position, actor);
  end if;

  insert into app_private.tedx_seat_history(seat_id, version, actor_id, reason, before_value, after_value)
    values(seat.id, seat.version, actor.id, btrim(p_reason), case when previous.id is not null then to_jsonb(previous) end, to_jsonb(seat));
  receipt := jsonb_build_object('id', seat.id, 'version', seat.version);
  insert into public.idempotency_keys(actor_id, command, client_key, organization_id, term_id, payload_hash, result_reference)
    values(auth.uid(), 'save_tedx_seat', p_request_id, actor.organization_id, p_term_id,
      encode(sha256(convert_to(payload::text, 'UTF8')), 'hex'), receipt);
  return receipt;
end;
$$;
revoke all on function public.read_tedx_positions(uuid),
  public.save_tedx_seat(uuid,uuid,integer,uuid,uuid,timestamptz,timestamptz,boolean,text,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.read_tedx_positions(uuid),
  public.save_tedx_seat(uuid,uuid,integer,uuid,uuid,timestamptz,timestamptz,boolean,text,uuid) to authenticated;

-- Seed only the requested workspace and term. Existing units and assignments are retained.
do $$
declare
  term_row public.terms;
  committee record;
  unit uuid;
  preset record;
  role uuid;
begin
  select t.* into term_row from public.terms t join public.organizations o on o.id = t.organization_id
    where o.slug = 'tedx-ateneo-de-manila-u' and t.label = '2026-2027';
  if not found then return; end if;
  perform app_private.readiness_lock(term_row.id);
  for committee in select * from (values
    ('RECSEC','Recruitment Secretariat'), ('WEBDEV','Website Development'),
    ('MARKSTRAT','Marketing Strategy'), ('PROGACT','Programs & Activities'), ('FIN','Finance'),
    ('TALREC','Talent Recruitment'), ('LOG','Logistics'), ('STAGEMAN','Stage Management'), ('EXREL','External Relations')
  ) as names(code, name) loop
    insert into public.org_units(organization_id, term_id, code, name, delivery_committee)
      values(term_row.organization_id, term_row.id, committee.code, committee.name, true)
      on conflict(term_id, code) do nothing;
    select id into unit from public.org_units where term_id = term_row.id and code = committee.code;
    perform app_private.organization_alias(term_row.id, committee.code, unit);
    perform app_private.organization_alias(term_row.id, committee.name, unit);
  end loop;

  for preset in
    select v.code, v.name, null::uuid as unit_id, 'leadership'::text as tier, true as administrator
      from (values ('tedx_vp_hrtd','VP HRTD'), ('tedx_pm','Project Manager (PM)')) v(code, name)
    union all
    select 'tedx_' || lower(u.code) || '_' || tier.name,
      (case u.code when 'RECSEC' then 'RecSec' when 'WEBDEV' then 'WebDev' when 'MARKSTRAT' then 'MarkStrat'
        when 'PROGACT' then 'ProgAct' when 'TALREC' then 'TalRec' when 'LOG' then 'Log'
        when 'STAGEMAN' then 'StageMan' when 'EXREL' then 'ExRel' else u.code end) || ' ' || initcap(tier.name),
      u.id, tier.name, (u.code = 'WEBDEV' and tier.name = 'head')
      from public.org_units u cross join (values ('head'), ('core')) tier(name)
      where u.term_id = term_row.id and u.code in ('RECSEC','WEBDEV','MARKSTRAT','PROGACT','FIN','TALREC','LOG','STAGEMAN','EXREL')
  loop
    insert into public.roles(organization_id, term_id, code, name, privileged)
      values(term_row.organization_id, term_row.id, preset.code, preset.name, preset.administrator or preset.tier = 'head')
      on conflict(term_id, code) do nothing returning id into role;
    if role is null then continue; end if;
    insert into app_private.tedx_positions values(term_row.id, role, preset.unit_id, preset.tier, preset.administrator);
    insert into public.role_permissions(organization_id, term_id, role_id, capability, allowed_scope)
      select term_row.organization_id, term_row.id, role, p.capability, p.scope
      from (values ('workspace.read','term'), ('directory.read','term'), ('profile.edit_own','own'),
        ('committee.manage','unit'), ('admin.configure','term'), ('roles.manage','term'), ('reports.view','term')
      ) p(capability, scope)
      where (p.scope <> 'unit' or preset.tier = 'head')
        and (p.capability not in ('admin.configure','roles.manage','reports.view') or preset.administrator);
  end loop;

end;
$$;

commit;
