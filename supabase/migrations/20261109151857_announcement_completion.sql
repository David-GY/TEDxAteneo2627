-- P42: retain the source049 publication engine; extend only bulletin contracts.
create table public.announcement_acknowledgments(
 term_id uuid not null references public.terms(id),announcement_id uuid not null references public.presentation_controls(work_item_id),
 material_revision_id uuid not null references public.presentation_versions(id),actor_id uuid not null references auth.users(id),
 publication_id uuid not null references public.presentation_versions(id),acknowledged_at timestamptz not null default statement_timestamp(),
 primary key(announcement_id,material_revision_id,actor_id)
);
alter table public.announcement_acknowledgments enable row level security;
alter table public.announcement_acknowledgments force row level security;
revoke all on public.announcement_acknowledgments from public,anon,authenticated,service_role;
create trigger immutable_announcement_acknowledgment before update or delete on public.announcement_acknowledgments for each row execute function app_private.request_history_guard();

alter function app_private.validate_presentation(text,jsonb) rename to validate_presentation_before_bulletin_completion;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql immutable set search_path='' as $$
declare entry jsonb;
begin
 if p_kind is distinct from 'bulletin' or d->'version' is distinct from '2'::jsonb then
  perform app_private.validate_presentation_before_bulletin_completion(p_kind,d);return;
 end if;
 if not coalesce(app_private.definition_keys(d,array['version','title','body','requiredAck','pinned','expiresAt','attachments','guests']),false)
  or(select count(*)from jsonb_object_keys(d))<>8 or jsonb_typeof(d->'attachments')is distinct from 'array' or jsonb_typeof(d->'guests')is distinct from 'array'
  or jsonb_array_length(d->'attachments')>10 or jsonb_array_length(d->'guests')>20 then raise exception using errcode='22023',message='command_validation_failed';end if;
 perform app_private.validate_presentation_before_bulletin_completion('bulletin',(d-array['attachments','guests'])||'{"version":1}'::jsonb);
 for entry in select value from jsonb_array_elements(d->'attachments')union all select value from jsonb_array_elements(d->'guests')loop
  if jsonb_typeof(entry)is distinct from 'string' or entry#>>'{}'!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 end loop;
 if(select count(distinct value)from jsonb_array_elements(d->'attachments'))<>jsonb_array_length(d->'attachments')
  or(select count(distinct value)from jsonb_array_elements(d->'guests'))<>jsonb_array_length(d->'guests')then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;

create function app_private.bulletin_references(p_term uuid,d jsonb)returns void language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;
begin
 m:=app_private.request_actor(p_term);
 if exists(select 1 from jsonb_array_elements_text(coalesce(d->'attachments','[]'))x where not exists(
  select 1 from public.assets a join public.work_items w on w.id=a.origin_work_item_id where a.id=x::uuid and w.term_id=p_term and w.archived_at is null
   and a.kind='upload' and a.state='finalized' and public.can_access_work(w.id,'detail')))
  or exists(select 1 from jsonb_array_elements_text(coalesce(d->'guests','[]'))x where not exists(
   select 1 from public.guest_invitations i where i.id=x::uuid and i.term_id=p_term and i.sponsor_id=m.id and i.revoked_at is null
    and i.expires_at>statement_timestamp() and i.redeemed_by is not null and i.email=app_private.verified_google_email(i.redeemed_by) and app_private.active_guest_sponsor(i.sponsor_id)))
 then raise exception using errcode='42501',message='command_permission_denied';end if;
end$$;

alter function public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid) set schema app_private;
alter function app_private.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid) rename to save_presentation_before_bulletin_completion;
create function public.save_presentation_draft(p_term_id uuid,p_kind text,p_target_kind text,p_target_id uuid,p_definition jsonb,p_base_version integer,p_expected_version integer,p_request_id uuid,p_rollback_version_id uuid default null)returns jsonb
language plpgsql security definer set search_path='' as $$begin
 if p_kind='bulletin'then
  perform app_private.readiness_lock(p_term_id);perform app_private.presentation_actor(p_term_id,p_kind,p_target_kind,p_target_id,true);
  perform app_private.validate_presentation(p_kind,p_definition);perform app_private.bulletin_references(p_term_id,p_definition);
 end if;
 return app_private.save_presentation_before_bulletin_completion(p_term_id,p_kind,p_target_kind,p_target_id,p_definition,p_base_version,p_expected_version,p_request_id,p_rollback_version_id);
end$$;
alter function public.preview_presentation_configuration(uuid) set schema app_private;
alter function app_private.preview_presentation_configuration(uuid) rename to preview_presentation_before_bulletin_completion;
create function public.preview_presentation_configuration(p_draft_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare d public.presentation_drafts;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();
 if d.kind='bulletin'then perform app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id);perform app_private.validate_presentation(d.kind,d.definition);perform app_private.bulletin_references(d.term_id,d.definition);end if;
 return app_private.preview_presentation_before_bulletin_completion(p_draft_id);
end$$;
alter function public.publish_presentation_configuration(uuid,integer,text,text,uuid) set schema app_private;
alter function app_private.publish_presentation_configuration(uuid,integer,text,text,uuid) rename to publish_presentation_before_bulletin_completion;
create function public.publish_presentation_configuration(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare d public.presentation_drafts;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();
 if d.kind='bulletin'then
  perform app_private.readiness_lock(d.term_id);perform app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id,true);
  perform app_private.validate_presentation(d.kind,d.definition);perform app_private.bulletin_references(d.term_id,d.definition);
 end if;
 return app_private.publish_presentation_before_bulletin_completion(p_draft_id,p_expected_version,p_review_hash,p_reason,p_request_id);
end$$;

-- Material identity is a contiguous revision run, not a reusable content hash.
create function app_private.bulletin_material(d jsonb)returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_array(d->'title',d->'body',d->'requiredAck',coalesce((select jsonb_agg(value order by value)from jsonb_array_elements(coalesce(d->'attachments','[]'))),'[]'))
$$;
create function app_private.bulletin_material_revision(p_control uuid,p_version integer,d jsonb)returns uuid language sql stable security definer set search_path='' as $$
 select id from public.presentation_versions v where v.control_id=p_control and v.version<=p_version
  and v.version>coalesce((select max(prior.version)from public.presentation_versions prior where prior.control_id=p_control and prior.version<=p_version and app_private.bulletin_material(prior.definition)is distinct from app_private.bulletin_material(d)),0)
 order by v.version limit 1
$$;
create function app_private.bulletin_reader(p_term uuid)returns uuid language plpgsql stable security definer set search_path='' as $$declare invitation uuid;begin
 if public.current_term_membership(p_term)is not null then perform app_private.request_actor(p_term);return null;end if;
 invitation:=app_private.current_guest_invitation(p_term);
 if invitation is null or not exists(select 1 from public.terms t join public.organizations o on o.id=t.organization_id where t.id=p_term and t.state in('active','frozen')and o.state='active'and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on)
 then raise exception using errcode='42501',message='command_permission_denied';end if;
 return invitation;
end$$;

create or replace function app_private.visible_announcements(p_term_id uuid,p_id uuid default null)returns table(announcement_id uuid,publication jsonb)
language plpgsql stable security definer set search_path='' as $$
declare m uuid;invitation uuid;r record;d jsonb;expired boolean;material uuid;ack_at timestamptz;files jsonb;
begin
 invitation:=app_private.bulletin_reader(p_term_id);m:=public.current_term_membership(p_term_id);
 for r in select c.work_item_id,c.target_kind,c.target_id,u.name as unit_name,v.*,publisher.display_name as publisher_name
  from public.presentation_controls c join public.work_items w on w.id=c.work_item_id and w.term_id=c.term_id and w.archived_at is null
  left join public.org_units u on u.id=c.target_id and u.term_id=c.term_id
  cross join lateral(select pv.*from public.presentation_versions pv where pv.control_id=c.work_item_id order by pv.version desc limit 1)v
  join public.members publisher on publisher.auth_user_id=v.actor_id and publisher.organization_id=w.organization_id
  where c.term_id=p_term_id and c.kind='bulletin'and(p_id is null or c.work_item_id=p_id)
   and((invitation is null and((c.target_kind='term'and c.target_id=p_term_id)or(c.target_kind='unit'and u.archived_at is null and u.id is not null and exists(
     select 1 from public.unit_memberships um where um.term_membership_id=m and um.term_id=p_term_id and um.organization_id=w.organization_id and um.unit_id=c.target_id and um.status='active'and um.effective_from<=statement_timestamp()and um.effective_to>statement_timestamp()))))
    or(invitation is not null and exists(select 1 from public.guest_invitations share where share.term_id=p_term_id and share.redeemed_by=auth.uid()
     and share.email=app_private.verified_google_email(auth.uid())and share.revoked_at is null and share.expires_at>statement_timestamp()
     and app_private.active_guest_sponsor(share.sponsor_id)and coalesce(v.definition->'guests','[]')?share.id::text)))
 loop
  d:=r.definition;begin perform app_private.validate_presentation('bulletin',d);exception when invalid_parameter_value then continue;end;
  expired:=(d->>'expiresAt')::timestamptz<=statement_timestamp();material:=app_private.bulletin_material_revision(r.work_item_id,r.version,d);
  select acknowledged_at into ack_at from public.announcement_acknowledgments a where a.announcement_id=r.work_item_id and a.material_revision_id=material and a.actor_id=auth.uid();
  select coalesce(jsonb_agg(jsonb_build_object('assetId',a.id,'workId',a.origin_work_item_id,'name',a.filename)order by x.ord),'[]')into files
   from jsonb_array_elements_text(coalesce(d->'attachments','[]'))with ordinality x(id,ord)join public.assets a on a.id=x.id::uuid
   join public.work_items origin on origin.id=a.origin_work_item_id and origin.term_id=p_term_id and origin.archived_at is null
   where a.state='finalized'and a.kind='upload'and public.can_access_work(origin.id,'detail');
  announcement_id:=r.work_item_id;
  publication:=jsonb_build_object('id',r.work_item_id,'revisionId',r.id,'version',r.version,'materialRevisionId',material,'acknowledged',ack_at is not null,'acknowledgedAt',ack_at,
   'title',d->>'title','body',d->>'body','requiredAck',(d->>'requiredAck')::boolean,'pinned',(d->>'pinned')::boolean and not expired,'expired',expired,'expiresAt',d->>'expiresAt',
   'publishedAt',r.published_at,'publisherName',r.publisher_name,'attachments',files,
   'audience',jsonb_build_object('kind',case when invitation is not null then 'shared'when r.target_kind='term'then 'core'else'unit'end,
    'id',case when invitation is not null then null else r.target_id end,'name',case when invitation is not null then 'Shared with you'when r.target_kind='term'then 'Core team'else r.unit_name end));
  return next;
 end loop;
end$$;

-- Preserve source064 public pagination/null semantics, extending the actor check to explicit guests.
create or replace function public.read_announcements(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 perform app_private.bulletin_reader(p_term_id);
 if p_page is null or p_page<1 or p_page>1000000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 with visible as materialized(select *from app_private.visible_announcements(p_term_id)),page as(select *from visible order by(publication->>'pinned')::boolean desc,(publication->>'publishedAt')::timestamptz desc,announcement_id limit 20 offset(p_page::bigint-1)*20)
 select jsonb_build_object('items',coalesce((select jsonb_agg(publication-'body'order by(publication->>'pinned')::boolean desc,(publication->>'publishedAt')::timestamptz desc,announcement_id)from page),'[]'::jsonb),
  'total',(select count(*)from visible),'pinnedCount',(select count(*)from visible where(publication->>'pinned')::boolean),'page',p_page,'hasMore',(select count(*)from visible)>p_page::bigint*20)into result;return result;
end$$;
create or replace function public.read_announcement(p_term_id uuid,p_announcement_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 perform app_private.bulletin_reader(p_term_id);if p_announcement_id is null then return null;end if;
 return(select publication from app_private.visible_announcements(p_term_id,p_announcement_id));
end$$;

create function public.acknowledge_announcement(p_term_id uuid,p_announcement_id uuid,p_material_revision_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$declare v jsonb;payload jsonb;r jsonb;w public.work_items;at_time timestamptz;begin
 perform app_private.readiness_lock(p_term_id);perform app_private.bulletin_reader(p_term_id);
 v:=public.read_announcement(p_term_id,p_announcement_id);
 if v is null or not exists(select 1 from public.terms where id=p_term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 -- Current scope precedes retry. Exact old receipts remain replayable after a newer publication,
 -- but never mutate or acknowledge that newer material revision.
 payload:=jsonb_build_array(p_term_id,p_announcement_id,p_material_revision_id,p_expected_version);
 r:=app_private.begin_work_command('acknowledge_announcement',p_request_id,payload);if r is not null then return r;end if;
 if p_material_revision_id is distinct from(v->>'materialRevisionId')::uuid or p_expected_version is distinct from(v->>'version')::integer then raise exception using errcode='40001',message='command_stale_version';end if;
 if v->'requiredAck'is distinct from'true'::jsonb then raise exception using errcode='22023',message='command_validation_failed';end if;
 select *into w from public.work_items where id=p_announcement_id;
 insert into public.announcement_acknowledgments(term_id,announcement_id,material_revision_id,actor_id,publication_id)values(p_term_id,w.id,p_material_revision_id,auth.uid(),(v->>'revisionId')::uuid)on conflict do nothing;
 select acknowledged_at into at_time from public.announcement_acknowledgments where announcement_id=w.id and material_revision_id=p_material_revision_id and actor_id=auth.uid();
 r:=jsonb_build_object('version',w.version,'materialRevisionId',p_material_revision_id,'acknowledgedAt',at_time);
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'acknowledge_announcement',p_request_id,w.organization_id,w.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),r);
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(w.organization_id,w.term_id,auth.uid(),'Announcement reader','acknowledge_announcement',w.id,w.version,p_request_id,'{"fields":["reading_acknowledgment"]}');
 return r;
end$$;

create function public.read_announcement_publishing_options(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;r record;targets jsonb:='[]';begin
 m:=app_private.request_actor(p_term_id);
 for r in select a.target_kind,a.target_id,case when a.target_kind='term'then 'Core team'else u.name end as name from public.announcement_publishers a left join public.org_units u on u.id=a.target_id
  where a.term_id=p_term_id and a.membership_id=m.id and a.revoked_at is null order by a.target_kind,a.target_id loop
  begin perform app_private.presentation_actor(p_term_id,'bulletin',r.target_kind,r.target_id,true);
   targets:=targets||jsonb_build_array(jsonb_build_object('kind',r.target_kind,'id',r.target_id,'name',r.name));
  exception when insufficient_privilege then continue;end;
 end loop;
 if targets='[]'::jsonb then return jsonb_build_object('targets',targets,'attachments','[]'::jsonb,'guests','[]'::jsonb);end if;
 return jsonb_build_object('targets',targets,
 'attachments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.filename,'workTitle',w.title)order by a.id)from public.assets a join public.work_items w on w.id=a.origin_work_item_id
  where w.term_id=p_term_id and w.archived_at is null and a.state='finalized'and a.kind='upload'and public.can_access_work(w.id,'detail')),'[]'),
 'guests',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'name',i.email,'expiresAt',i.expires_at)order by i.id)from public.guest_invitations i where i.term_id=p_term_id and i.sponsor_id=m.id and i.revoked_at is null and i.expires_at>statement_timestamp()and i.redeemed_by is not null and i.email=app_private.verified_google_email(i.redeemed_by)and app_private.active_guest_sponsor(i.sponsor_id)),'[]'));
end$$;

create function public.search_announcements(p_term_id uuid,p_query text,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare q text;result jsonb;begin
 perform app_private.bulletin_reader(p_term_id);q:=btrim(p_query);
 if q is null or length(q)>120 or p_page is null or p_page<1 or p_page>1000000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 with authorized as materialized(select *from app_private.visible_announcements(p_term_id)),
 matched as materialized(select *from authorized where q=''or strpos(lower(publication->>'title'),lower(q))>0 or strpos(lower(publication->>'body'),lower(q))>0),
 page as(select *from matched order by(publication->>'pinned')::boolean desc,(publication->>'publishedAt')::timestamptz desc,announcement_id limit 20 offset(p_page::bigint-1)*20)
 select jsonb_build_object('items',coalesce((select jsonb_agg(publication-'body'order by(publication->>'pinned')::boolean desc,(publication->>'publishedAt')::timestamptz desc,announcement_id)from page),'[]'),
  'total',(select count(*)from matched),'pinnedCount',(select count(*)from matched where(publication->>'pinned')::boolean),'page',p_page,'hasMore',(select count(*)from matched)>p_page::bigint*20)into result;return result;
end$$;
revoke all on function public.search_announcements(uuid,text,integer)from public,anon,authenticated,service_role;
grant execute on function public.search_announcements(uuid,text,integer)to authenticated;

revoke all on function app_private.validate_presentation_before_bulletin_completion(text,jsonb),app_private.validate_presentation(text,jsonb),app_private.bulletin_references(uuid,jsonb),
 app_private.save_presentation_before_bulletin_completion(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),app_private.preview_presentation_before_bulletin_completion(uuid),app_private.publish_presentation_before_bulletin_completion(uuid,integer,text,text,uuid),
 app_private.bulletin_material(jsonb),app_private.bulletin_material_revision(uuid,integer,jsonb),app_private.bulletin_reader(uuid),app_private.visible_announcements(uuid,uuid),
 public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),public.preview_presentation_configuration(uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid),
 public.read_announcements(uuid,integer),public.read_announcement(uuid,uuid),public.acknowledge_announcement(uuid,uuid,uuid,integer,uuid),public.read_announcement_publishing_options(uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),public.preview_presentation_configuration(uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid),
 public.read_announcements(uuid,integer),public.read_announcement(uuid,uuid),public.acknowledge_announcement(uuid,uuid,uuid,integer,uuid),public.read_announcement_publishing_options(uuid)to authenticated;
