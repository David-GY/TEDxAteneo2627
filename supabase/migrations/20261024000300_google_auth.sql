begin;
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated, service_role;

-- auth.identities is provider-managed; never use raw_user_meta_data for admission.
create function app_private.is_school_identity(p_user_id uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists(select 1 from auth.users u join auth.identities i on i.user_id=u.id
    where u.id=p_user_id and u.email_confirmed_at is not null
      and lower(btrim(u.email)) ~ '^[^@[:space:]]+@student[.]ateneo[.]edu$'
      and i.provider='google' and i.identity_data->'email_verified'='true'::jsonb
      and lower(btrim(i.identity_data->>'email'))=lower(btrim(u.email)))
$$;
revoke all on function app_private.is_school_identity(uuid) from public,anon,authenticated,service_role;

create or replace function public.current_term_membership(p_term_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select tm.id from public.term_memberships tm
  join public.members m on m.id=tm.member_id and m.organization_id=tm.organization_id
  join public.terms t on t.id=tm.term_id and t.organization_id=tm.organization_id
  join public.organizations o on o.id=tm.organization_id
  join auth.users u on u.id=m.auth_user_id and lower(btrim(u.email))=m.normalized_email
  where m.auth_user_id=(select auth.uid()) and app_private.is_school_identity(u.id)
    and m.account_state='active' and tm.membership_kind='core'
    and tm.term_id=p_term_id and tm.status='active' and o.state='active'
    and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
    and t.state in ('active','frozen')
    and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
$$;

-- The only automatic linkage: an exact, verified provider identity to one preapproved roster member.
create function public.resolve_auth_context() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); candidates uuid[]; member_row public.members; membership public.term_memberships;
begin
  if actor is null or not app_private.is_school_identity(actor) then return jsonb_build_object('state','denied'); end if;
  select array_agg(m.id) into candidates from public.members m join auth.users u on u.id=actor
    where m.normalized_email=lower(btrim(u.email)) and m.account_state in ('invited','active')
      and (m.auth_user_id is null or m.auth_user_id=actor);
  if coalesce(cardinality(candidates),0)<>1 then return jsonb_build_object('state','denied'); end if;
  select * into member_row from public.members where id=candidates[1] for update;
  -- Recheck mutable identity/status after the row lock.
  if member_row.account_state not in ('invited','active') or (member_row.auth_user_id is not null and member_row.auth_user_id<>actor)
    or not exists(select 1 from auth.users u where u.id=actor and lower(btrim(u.email))=member_row.normalized_email) then
    return jsonb_build_object('state','denied');
  end if;
  select tm.* into membership from public.term_memberships tm join public.terms t on t.id=tm.term_id
    join public.organizations o on o.id=tm.organization_id
    where tm.member_id=member_row.id and tm.membership_kind='core' and tm.status='active'
      and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
      and o.state='active' and t.state in ('active','frozen')
      and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
    order by (t.state='active') desc,t.starts_on desc,tm.id limit 1;
  if not found then return jsonb_build_object('state','denied'); end if;
  if member_row.auth_user_id is null or member_row.account_state='invited' then
    update public.members set auth_user_id=actor, account_state='active' where id=member_row.id;
  end if;
  if public.current_term_membership(membership.term_id) is null then return jsonb_build_object('state','denied'); end if;
  return jsonb_build_object('state','authorized','memberId',member_row.id,'displayName',member_row.display_name,
    'organizationId',member_row.organization_id,'termId',membership.term_id,'termMembershipId',membership.id,
    'expiresAt',membership.ends_at,'capabilities',coalesce((select jsonb_agg(distinct g->>'capability')
      from jsonb_array_elements(public.explain_access(membership.term_id)->'grants') g),'[]'::jsonb));
end;
$$;
revoke all on function public.resolve_auth_context() from public,anon,authenticated,service_role;
grant execute on function public.resolve_auth_context() to authenticated;
commit;
