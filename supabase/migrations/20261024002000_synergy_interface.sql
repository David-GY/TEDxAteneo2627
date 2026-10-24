begin;
create function app_private.synergy_sources(p_parent_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name','Finalized files · version '||m.work_version||' · '||to_char(m.created_at at time zone 'Asia/Manila','Mon DD, YYYY HH24:MI'))order by m.created_at,m.id),'[]') from public.asset_manifests m where m.work_item_id=p_parent_id and public.can_read_manifest(m.id)
$$;
revoke all on function app_private.synergy_sources(uuid) from public,anon,authenticated,service_role;
-- Preserve P14's safe projection; enrich only after its current-head authorization succeeds.
alter function public.read_synergy(uuid) rename to read_synergy_p14;
alter function public.read_synergy_p14(uuid) set schema app_private;
revoke all on function app_private.read_synergy_p14(uuid) from public,anon,authenticated,service_role;
create function public.read_synergy(p_agreement_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; a public.synergy_agreements; w public.work_items; actor uuid; responding boolean;
begin
 result:=app_private.read_synergy_p14(p_agreement_id); if result is null then return null;end if;
 select * into a from public.synergy_agreements where id=p_agreement_id;
 select * into w from public.work_items where id=a.parent_work_item_id;
 actor:=app_private.synergy_actor(a.term_id);
 responding:=a.state in('proposed','countered') and app_private.synergy_head(a.term_id,case when a.state='countered' then a.requester_unit_id else a.receiver_unit_id end,actor)
 and actor<>(select proposer_member_id from public.agreement_revisions where agreement_id=a.id and revision=a.current_revision);
 return result||jsonb_build_object('interface',jsonb_build_object(
 'requesterUnitName',(select name from public.org_units where id=a.requester_unit_id),
 'receiverUnitName',(select name from public.org_units where id=a.receiver_unit_id),
 'ownerName',(select display_name from public.members where id=(result#>>'{terms,ownerId}')::uuid),
 'pendingWith',case a.state when 'proposed' then 'receiver' when 'countered' then 'requester' else null end,
 'actions',case when responding then case when a.state='proposed' then '["accept","decline","counter"]'::jsonb else '["accept","decline"]'::jsonb end else '[]'::jsonb end,
 'owners',case when responding and a.state='proposed' then coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'name',m.display_name)order by m.display_name,m.id)from public.members m where app_private.synergy_owner(a.term_id,a.receiver_unit_id,m.id)),'[]')else '[]'::jsonb end,
 'sourceOptions',app_private.synergy_sources(w.id),
 'canAmend',public.can_access_work(w.id,'edit') and app_private.synergy_head(a.term_id,a.requester_unit_id,actor) and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active') and exists(select 1 from public.deliverables where work_item_id=w.id and workflow_state in('draft','in_progress')),
 'parentVersion',case when public.can_access_work(w.id,'edit') and app_private.synergy_head(a.term_id,a.requester_unit_id,actor) then w.version end));
end$$;

create function public.synergy_options(p_term_id uuid,p_parent_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('parentVersion',w.version,'sourceOptions',app_private.synergy_sources(w.id),'receivers',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name)order by u.name,u.id)from public.org_units u where u.term_id=w.term_id and u.id<>w.lead_unit_id and u.delivery_committee and u.archived_at is null),'[]'))
 from public.work_items w join public.terms t on t.id=w.term_id and t.state='active' where w.id=p_parent_id and w.term_id=p_term_id and w.kind='deliverable' and w.archived_at is null and exists(select 1 from public.deliverables where work_item_id=w.id and workflow_state in('draft','in_progress')) and public.can_access_work(w.id,'edit') and app_private.synergy_head(w.term_id,w.lead_unit_id,app_private.synergy_actor(w.term_id))
$$;

create function public.list_synergies(p_term_id uuid,p_view text default 'outgoing',p_parent_id uuid default null,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare agreements jsonb; contributions jsonb; more boolean; actor uuid;
begin
 actor:=app_private.synergy_actor(p_term_id);
 if actor is null or not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id) and membership_kind='core')then return null;end if;
 if p_view is null or p_view not in('outgoing','incoming','contributions','parent')or p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 -- Parent discovery itself requires independent summary access, including before counts/pagination.
 if p_view='parent' and (p_parent_id is null or not public.can_access_work(p_parent_id,'summary'))then return null;end if;
 with eligible as (
 select a.id from public.synergy_agreements a where a.term_id=p_term_id and app_private.synergy_visible(a)
 and ((p_view='parent' and a.parent_work_item_id=p_parent_id)or(p_view='outgoing' and app_private.synergy_head(a.term_id,a.requester_unit_id,actor))or(p_view='incoming' and app_private.synergy_head(a.term_id,a.receiver_unit_id,actor)))
 ), page as(select id from eligible order by id limit 20 offset (p_page-1)*20)
 select coalesce((select jsonb_agg(public.read_synergy(id)order by id)from page),'[]'),(select count(*)>p_page*20 from eligible)into agreements,more;
 with eligible as (
 select c.work_item_id id from public.contributions c where c.term_id=p_term_id and public.can_access_work(c.work_item_id,'detail')
 and ((p_view='parent' and c.parent_work_item_id=p_parent_id)or p_view='contributions')
 ), page as(select id from eligible order by id limit 20 offset (p_page-1)*20)
 select coalesce((select jsonb_agg(public.read_contribution(id)order by id)from page),'[]'),more or(select count(*)>p_page*20 from eligible)into contributions,more;
 return jsonb_build_object('agreements',agreements,'contributions',contributions,'hasMore',more,'page',p_page);
end$$;
revoke all on function public.read_synergy(uuid),public.synergy_options(uuid,uuid),public.list_synergies(uuid,text,uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.read_synergy(uuid),public.synergy_options(uuid,uuid),public.list_synergies(uuid,text,uuid,integer) to authenticated;
commit;
