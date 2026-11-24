-- P42 current-audience reader of the existing source049/source051 publications.
-- No new publication engine, guest grant, file link or acknowledgment side effect.
create function app_private.visible_announcements(p_term_id uuid, p_id uuid default null)
returns table(announcement_id uuid, publication jsonb)
language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships; r record; d jsonb; expired boolean;
begin
 m:=app_private.request_actor(p_term_id);
 -- Audience precedes definition validation/projection and all public aggregation.
 -- Configuration/publisher authority, record grants and unit aliases do not add an audience.
 for r in
  select c.work_item_id,c.target_kind,c.target_id,u.name as unit_name,v.*,
   publisher.display_name as publisher_name
  from public.presentation_controls c
  join public.work_items w on w.id=c.work_item_id and w.term_id=c.term_id and w.organization_id=m.organization_id and w.archived_at is null
  left join public.org_units u on u.id=c.target_id and u.term_id=c.term_id and u.organization_id=m.organization_id
  cross join lateral(select pv.* from public.presentation_versions pv where pv.control_id=c.work_item_id order by pv.version desc limit 1)v
  join public.members publisher on publisher.auth_user_id=v.actor_id and publisher.organization_id=m.organization_id
  where c.term_id=p_term_id and c.kind='bulletin' and (p_id is null or c.work_item_id=p_id)
   and ((c.target_kind='term' and c.target_id=p_term_id)
    or(c.target_kind='unit' and u.archived_at is null and u.id is not null and exists(
     select 1 from public.unit_memberships um where um.term_membership_id=m.id
      and um.organization_id=m.organization_id and um.term_id=m.term_id and um.unit_id=c.target_id
      and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())))
 loop
  d:=r.definition;
  begin
   perform app_private.validate_presentation('bulletin',d);
  exception when invalid_parameter_value then
   -- Retired/corrupt latest definitions are closed; never expose an older publication.
   continue;
  end;
  expired:=(d->>'expiresAt')::timestamptz<=statement_timestamp();
  announcement_id:=r.work_item_id;
  publication:=jsonb_build_object('id',r.work_item_id,'revisionId',r.id,'version',r.version,
   'title',d->>'title','body',d->>'body','requiredAck',(d->>'requiredAck')::boolean,
   'pinned',(d->>'pinned')::boolean and not expired,'expired',expired,'expiresAt',d->>'expiresAt',
   'publishedAt',r.published_at,'publisherName',r.publisher_name,
   'audience',jsonb_build_object('kind',case when r.target_kind='term' then 'core' else 'unit' end,
    'id',r.target_id,'name',case when r.target_kind='term' then 'Core team' else r.unit_name end));
  return next;
 end loop;
end$$;

create function public.read_announcements(p_term_id uuid, p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform app_private.request_actor(p_term_id);
 if p_page is null or p_page<1 or p_page>1000000 then
  raise exception using errcode='22023',message='command_validation_failed';
 end if;
 with visible as materialized(select * from app_private.visible_announcements(p_term_id)),
 page as(select announcement_id,publication from visible
  order by (publication->>'pinned')::boolean desc,(publication->>'publishedAt')::timestamptz desc,announcement_id
  limit 20 offset (p_page::bigint-1)*20)
 select jsonb_build_object('items',coalesce((select jsonb_agg(publication-'body'
   order by (publication->>'pinned')::boolean desc,(publication->>'publishedAt')::timestamptz desc,announcement_id)from page),'[]'::jsonb),
  'total',(select count(*)from visible),'pinnedCount',(select count(*)from visible where (publication->>'pinned')::boolean),
  'page',p_page,'hasMore',(select count(*)from visible)>p_page::bigint*20) into result;
 return result;
end$$;

create function public.read_announcement(p_term_id uuid, p_announcement_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform app_private.request_actor(p_term_id);
 -- Null, unknown, unpublished, wrong-kind/term and inaccessible IDs share one result.
 if p_announcement_id is null then return null;end if;
 return(select publication from app_private.visible_announcements(p_term_id,p_announcement_id));
end$$;

revoke all on function app_private.visible_announcements(uuid,uuid),
 public.read_announcements(uuid,integer),public.read_announcement(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_announcements(uuid,integer),public.read_announcement(uuid,uuid) to authenticated;
