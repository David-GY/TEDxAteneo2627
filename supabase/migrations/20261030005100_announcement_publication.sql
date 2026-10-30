-- Explicit trusted publisher mapping, not inferred from resource drafting or site configuration.
create table public.announcement_publishers(
 term_id uuid not null references public.terms(id),membership_id uuid not null references public.term_memberships(id),
 target_kind text not null check(target_kind in('term','unit')),target_id uuid not null,
 approved_by uuid not null references public.term_memberships(id),revoked_at timestamptz,
 primary key(term_id,membership_id,target_kind,target_id),check(membership_id<>approved_by)
);
alter table public.announcement_publishers enable row level security;
alter table public.announcement_publishers force row level security;
revoke all on public.announcement_publishers from public,anon,authenticated,service_role;
-- No public provisioning endpoint and no production publisher seeded.
alter table public.presentation_controls drop constraint presentation_controls_kind_check,
 add constraint presentation_controls_kind_check check(kind in('site','layout','notification','bulletin')),
 drop constraint presentation_controls_check,add constraint presentation_controls_check check(kind in('layout','bulletin')or target_kind='term');
alter table public.presentation_drafts drop constraint presentation_drafts_kind_check,
 add constraint presentation_drafts_kind_check check(kind in('site','layout','notification','bulletin')),
 drop constraint presentation_drafts_check,add constraint presentation_drafts_check check(kind in('layout','bulletin')or target_kind='term');

alter function app_private.presentation_actor(uuid,text,text,uuid,boolean)rename to presentation_actor_before_announcements;
create function app_private.presentation_actor(p_term uuid,p_kind text,p_target_kind text,p_target uuid,p_write boolean default false)returns public.term_memberships
language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 if p_kind is distinct from 'bulletin'then return app_private.presentation_actor_before_announcements(p_term,p_kind,p_target_kind,p_target,p_write);end if;
 m:=app_private.request_actor(p_term,p_write);
 if p_target_kind is null or p_target_kind not in('term','unit')or p_target is null
  or(p_target_kind='term'and p_target<>p_term)
  or(p_target_kind='unit'and not exists(select 1 from public.org_units where id=p_target and term_id=p_term and archived_at is null))
  or not exists(select 1 from public.announcement_publishers a join public.term_memberships approver on approver.id=a.approved_by
   where a.term_id=p_term and a.membership_id=m.id and a.target_kind=p_target_kind and a.target_id=p_target and a.revoked_at is null
    and approver.term_id=p_term and approver.membership_kind='core')
  or not(public.has_capability(p_term,'admin.configure')or(p_target_kind='unit'and public.has_capability(p_term,'committee.manage',p_target)
   and exists(select 1 from public.unit_memberships where term_membership_id=m.id and unit_id=p_target and status='active'and deployment_type='head'and effective_from<=statement_timestamp()and effective_to>statement_timestamp())))
 then raise exception using errcode='42501',message='command_permission_denied';end if;
 return m;
end$$;
alter function app_private.validate_presentation(text,jsonb)rename to validate_presentation_before_announcements;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql immutable set search_path='' as $$begin
 if p_kind is distinct from 'bulletin'then perform app_private.validate_presentation_before_announcements(p_kind,d);return;end if;
 if not coalesce(app_private.definition_keys(d,array['version','title','body','requiredAck','pinned','expiresAt']),false)
  or(select count(*)from jsonb_object_keys(d))<>6 or d->'version'is distinct from '1'::jsonb
  or not app_private.presentation_text(d->'title',200)or not app_private.presentation_text(d->'body',10000)
  or jsonb_typeof(d->'requiredAck')is distinct from 'boolean'or jsonb_typeof(d->'pinned')is distinct from 'boolean'
  or jsonb_typeof(d->'expiresAt')is distinct from 'string'or(d->>'expiresAt')!~'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
 then raise exception using errcode='22023',message='command_validation_failed';end if;
 begin perform(d->>'expiresAt')::timestamptz;exception when others then raise exception using errcode='22023',message='command_validation_failed';end;
end$$;
revoke all on function app_private.presentation_actor_before_announcements(uuid,text,text,uuid,boolean),app_private.presentation_actor(uuid,text,text,uuid,boolean),
 app_private.validate_presentation_before_announcements(text,jsonb),app_private.validate_presentation(text,jsonb)from public,anon,authenticated,service_role;
