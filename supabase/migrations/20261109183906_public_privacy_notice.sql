-- P46 public audience is an independent, trusted institutional decision. No row
-- is seeded and no client can enroll/approve a route or claim contact verification.
create table public.privacy_public_notice_routes(
 route_key text primary key check(route_key~'^[a-z][a-z0-9-]{0,59}$'),term_id uuid not null references public.terms(id),
 notice_version_id uuid not null references public.presentation_versions(id),approved_by uuid not null references public.term_memberships(id),
 approval_reference text not null check(length(btrim(approval_reference))between 1 and 500),
 contact_verified_at timestamptz not null check(isfinite(contact_verified_at)),approved_at timestamptz not null default statement_timestamp(),
 expires_at timestamptz not null,revoked_at timestamptz,
 check(contact_verified_at<=approved_at),check(isfinite(expires_at)and expires_at>approved_at)
);
alter table public.privacy_public_notice_routes enable row level security;alter table public.privacy_public_notice_routes force row level security;
revoke all on public.privacy_public_notice_routes from public,anon,authenticated,service_role;
create function public.get_public_privacy_notice(p_route text default 'workspace')returns jsonb language plpgsql stable security definer set search_path='' as $$declare r public.privacy_public_notice_routes;v public.presentation_versions;author uuid;n jsonb;begin
 if p_route is null or p_route!~'^[a-z][a-z0-9-]{0,59}$'then return null;end if;
 select x.*into r from public.privacy_public_notice_routes x join public.terms t on t.id=x.term_id join public.organizations o on o.id=t.organization_id and o.state='active'
  join public.term_memberships m on m.id=x.approved_by and m.term_id=x.term_id and m.membership_kind='core'and m.status='active'and m.joined_at<=statement_timestamp()and m.ends_at>statement_timestamp()
  join public.members approver on approver.id=m.member_id and approver.account_state='active'
  where x.route_key=p_route and x.approved_at<=statement_timestamp()and x.contact_verified_at<=statement_timestamp()and x.expires_at>statement_timestamp()and x.revoked_at is null;
 if not found then return null;end if;
 select pv.*into v from public.presentation_versions pv join public.presentation_controls c on c.work_item_id=pv.control_id and c.term_id=r.term_id and c.kind='privacy'and c.target_kind='term'and c.target_id=r.term_id
  join public.work_items w on w.id=c.work_item_id and w.archived_at is null
  where pv.id=r.notice_version_id and not exists(select 1 from public.presentation_versions newer where newer.control_id=pv.control_id and newer.version>pv.version);
 if not found then return null;end if;
 select tm.id into author from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=r.term_id and m.auth_user_id=v.actor_id;
 if author is null or author=r.approved_by or not app_private.privacy_notice_approved(r.term_id,v.definition,author)then return null;end if;
 begin perform app_private.validate_presentation('privacy',v.definition);exception when invalid_parameter_value then return null;end;
 -- Public projection deliberately omits private policy review references, opaque
 -- IDs, custody records, acknowledgments, queue summaries and account information.
 n:=v.definition-'policyReference';
 return jsonb_build_object('notice',n,'version',v.version,'publishedAt',v.published_at,'contactCheckedAt',r.contact_verified_at,'validUntil',least(r.expires_at,
  (select a.expires_at from public.privacy_notice_approvals a where a.term_id=r.term_id and a.definition_hash=encode(sha256(convert_to(v.definition::text,'UTF8')),'hex')),
  (select m.ends_at from public.term_memberships m where m.id=r.approved_by)));
end$$;
revoke all on function public.get_public_privacy_notice(text)from public,anon,authenticated,service_role;
grant execute on function public.get_public_privacy_notice(text)to anon,authenticated;
