begin;

create table app_private.room_booking_offers (
  request_id uuid not null,
  booking_version integer not null,
  version integer not null check(version>0),
  term_id uuid not null,
  policy_version integer not null,
  room_id uuid not null references app_private.rooms(id),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  actor_id uuid not null references auth.users(id),
  reason text not null check(length(btrim(reason)) between 1 and 2000),
  recorded_at timestamptz not null default clock_timestamp(),
  primary key(request_id,booking_version,version),
  foreign key(request_id,booking_version) references app_private.room_booking_history(request_id,version),
  foreign key(term_id,policy_version) references app_private.room_booking_policies(term_id,version),
  check(isfinite(starts_at) and isfinite(ends_at) and ends_at>starts_at and ends_at-starts_at<=interval '1 day')
);
alter table app_private.room_booking_offers enable row level security;
alter table app_private.room_booking_offers force row level security;
revoke all on app_private.room_booking_offers from public,anon,authenticated,service_role;
create trigger immutable_room_booking_offer before update or delete on app_private.room_booking_offers
  for each row execute function app_private.request_history_guard();

create function app_private.require_room_booking_closed() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from app_private.room_bookings b where b.request_id=new.work_item_id and b.state<>'cancelled') then
    raise exception using errcode='55000',message='command_room_booking_open';
  end if;
  return new;
end;
$$;
create trigger close_room_before_request before update of request_state on public.requests
  for each row when (old.request_state is distinct from new.request_state and new.request_state='cancelled')
  execute function app_private.require_room_booking_closed();
revoke all on function app_private.require_room_booking_closed() from public,anon,authenticated,service_role;

create function app_private.room_slot_available(room app_private.rooms,p_request uuid,
  p_start timestamptz,p_end timestamptz,p_now timestamptz)
returns boolean language sql stable set search_path='' as $$
  select p_start>p_now and not exists(select 1 from app_private.room_bookings other
    where other.room_id=room.id and other.request_id<>p_request
      and other.state in ('confirmed','held') and (other.state='confirmed' or other.hold_expires_at>p_now)
      and other.blocked_slot && tstzrange(p_start-make_interval(mins=>room.setup_minutes),
        p_end+make_interval(mins=>room.cleanup_minutes),'[)'));
$$;

create function public.offer_room_alternative(p_term_id uuid,p_request_id uuid,p_expected_version integer,
  p_expected_offer_version integer,p_policy_version integer,p_room_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,
  p_reason text,p_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor public.term_memberships; r public.requests; w public.work_items; b app_private.room_bookings;
  t public.terms; room app_private.rooms; policy app_private.room_booking_policies;
  now_at timestamptz; payload jsonb; result jsonb; prior integer;
begin
  actor:=app_private.request_actor(p_term_id,true);
  perform app_private.readiness_lock(p_term_id);
  perform pg_advisory_xact_lock(hashtextextended('room-booking-transitions',0));
  now_at:=clock_timestamp();
  if app_private.disposition_replay_required(p_term_id) then
    raise exception using errcode='55000',message='privacy_restore_replay_required';
  end if;
  select * into w from public.work_items where id=p_request_id and term_id=p_term_id for update;
  select * into r from public.requests where work_item_id=w.id and term_id=p_term_id;
  if r.work_item_id is null or w.archived_at is not null or not coalesce(app_private.workflow_manager(r,actor),false) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_request_id,p_expected_version,p_expected_offer_version,p_policy_version,
    p_room_id,p_starts_at,p_ends_at,p_reason);
  result:=app_private.begin_work_command('offer_room_alternative',p_key,payload);
  if result is not null then return result; end if;
  select * into b from app_private.room_bookings where request_id=r.work_item_id;
  select coalesce(max(version),0) into prior from app_private.room_booking_offers
    where request_id=b.request_id and booking_version=b.version;
  if b.version is distinct from p_expected_version or prior is distinct from p_expected_offer_version then
    raise exception using errcode='40001',message='command_stale_version';
  end if;
  policy:=app_private.current_room_policy(p_term_id,now_at);
  if policy.version is null or policy.version is distinct from p_policy_version then
    raise exception using errcode='40001',message='command_booking_policy_changed';
  end if;
  if b.state is null or b.state not in ('requested','held') or b.source_revision_id is distinct from r.current_revision_id
    or r.request_type_id is distinct from policy.request_type_id or r.receiving_unit_id is distinct from policy.logistics_unit_id
    or not app_private.workflow_hooks_ready(r) or r.request_state not in ('paused','in_review','approved','completed') then
    raise exception using errcode='55000',message='command_booking_state_changed';
  end if;
  select * into t from public.terms where id=p_term_id;
  if p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at)
    or p_starts_at<=now_at or p_ends_at<=p_starts_at or p_ends_at-p_starts_at>interval '1 day'
    or (p_starts_at at time zone 'Asia/Manila')::date<t.starts_on
    or ((p_ends_at-interval '1 microsecond') at time zone 'Asia/Manila')::date>t.closes_on
    or (p_room_id,p_starts_at,p_ends_at) is not distinct from (b.room_id,b.starts_at,b.ends_at) then
    raise exception using errcode='22023',message='command_booking_invalid_slot';
  end if;
  select * into room from app_private.rooms where id=p_room_id and organization_id=actor.organization_id
    and retired_at is null for share;
  if room.id is null or room.capacity<b.attendees or b.needs_accessible and not room.accessible
    or not room.equipment@>b.equipment then
    raise exception using errcode='22023',message='command_booking_room_unsuitable';
  end if;
  if not app_private.room_slot_available(room,b.request_id,p_starts_at,p_ends_at,now_at) then
    raise exception using errcode='23P01',message='command_booking_slot_unavailable';
  end if;
  if p_reason is null or length(btrim(p_reason)) not between 1 and 2000 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  insert into app_private.room_booking_offers(request_id,booking_version,version,term_id,policy_version,room_id,
    starts_at,ends_at,actor_id,reason)
  values(b.request_id,b.version,prior+1,p_term_id,policy.version,room.id,p_starts_at,p_ends_at,auth.uid(),btrim(p_reason));
  return app_private.finish_work_command(w,'offer_room_alternative',p_key,payload,
    jsonb_build_object('outcome','offered','offerVersion',prior+1),jsonb_build_array('room_booking_offer'));
end;
$$;

-- Reuse the private upload/seal/finalize pipeline. Logistics can add evidence to
-- the active booking without acquiring edit or package-read access to the request.
alter table public.assets add column room_booking_evidence boolean not null default false;

create function app_private.room_evidence_writer(w public.work_items)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.requests r join app_private.room_bookings b on b.request_id=r.work_item_id
    join public.terms t on t.id=r.term_id
    join public.term_memberships m on m.id=public.current_term_membership(t.id) and m.membership_kind='core'
    join lateral app_private.current_room_policy(t.id,statement_timestamp()) policy on policy.request_type_id=r.request_type_id
    where r.work_item_id=w.id and w.archived_at is null and t.state='active' and policy.evidence_mode='required'
      and r.receiving_unit_id=policy.logistics_unit_id and r.request_state in ('paused','in_review','approved','completed')
      and b.state in ('requested','held','confirmed') and (b.source_revision_id=r.current_revision_id or b.state='confirmed')
      and app_private.workflow_hooks_ready(r) and public.has_capability(t.id,'workspace.read') and app_private.workflow_manager(r,m)
      and not app_private.disposition_replay_required(t.id));
$$;

create function app_private.lock_room_evidence_work(p_work_item_id uuid,p_version integer)
returns public.work_items language plpgsql set search_path='' as $$
declare w public.work_items;
begin
  select * into w from public.work_items where id=p_work_item_id for update;
  if not app_private.room_evidence_writer(w) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  if w.version is distinct from p_version then
    raise exception using errcode='40001',message='command_stale_version';
  end if;
  return w;
end;
$$;

create or replace function public.reserve_upload(p_work_item_id uuid,p_name text,p_mime text,p_size integer,p_sha256 text,p_source_id uuid,p_source_version integer,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;s public.assets;room_evidence boolean;payload jsonb;result jsonb;path text;begin
 select * into w from public.work_items where id=p_work_item_id;
 room_evidence:=app_private.room_evidence_writer(w);
 if not(public.can_access_work(w.id,'edit')or app_private.can_add_finance_receipt(w) or room_evidence) or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_name,p_mime,p_size,p_sha256,p_source_id,p_source_version,p_expected_version);result:=app_private.begin_work_command('reserve_upload',p_request_id,payload);if result is not null then return result;end if;
 if room_evidence then w:=app_private.lock_room_evidence_work(p_work_item_id,p_expected_version);
 else w:=app_private.file_work(p_work_item_id,p_expected_version); end if;
 if p_name is null or length(p_name) not between 1 and 160 or p_name ~ '[\r\n]' or p_mime is null or p_mime not in ('application/pdf','image/jpeg','image/png') or p_size is null or p_size not between 1 and 5242880 or p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 if (select coalesce(sum(size_bytes),0) from public.assets where origin_work_item_id=w.id and (state='validated' or(state='reserved' and expires_at>statement_timestamp())))+p_size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if (app_private.can_add_finance_receipt(w) and p_source_id is not null)
   or (room_evidence and (p_source_id is not null or p_source_version is not null)) then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_source_id is not null then select * into s from public.assets where id=p_source_id and kind='working_link' and origin_work_item_id=w.id and version=p_source_version;if not found then raise exception using errcode='40001',message='command_stale_version';end if;end if;
 path:=gen_random_uuid()::text||'/'||gen_random_uuid()::text||case p_mime when 'application/pdf' then '.pdf' when 'image/png' then '.png' else '.jpg' end;
 insert into public.assets(origin_work_item_id,kind,classification,filename,mime_type,size_bytes,sha256,object_path,state,created_by,expires_at,source_snapshot,room_booking_evidence)
 values(w.id,'upload',w.classification,p_name,p_mime,p_size,p_sha256,path,'reserved',auth.uid(),statement_timestamp()+interval'20 minutes',case when s.id is not null then jsonb_build_object('assetId',s.id,'version',s.version,'url',s.source_url,'label',s.source_label,'accessNotes',s.access_notes) end,room_evidence) returning * into a;
 insert into public.asset_links(asset_id,work_item_id,created_by) values(a.id,w.id,auth.uid());
 return app_private.finish_work_command(w,'reserve_upload',p_request_id,payload,jsonb_build_object('assetId',a.id,'path',path,'version',1),'["asset_reservation"]');
end$$;


create or replace function public.finalize_upload(p_work_item_id uuid,p_asset_ids uuid[],p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;room_evidence boolean;payload jsonb;result jsonb;entries jsonb;size integer;mid uuid;begin
 select * into w from public.work_items where id=p_work_item_id;
 room_evidence:=app_private.room_evidence_writer(w);
 if not(public.can_access_work(w.id,'edit')or app_private.can_add_finance_receipt(w) or room_evidence) or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_ids,p_expected_version);result:=app_private.begin_work_command('finalize_upload',p_request_id,payload);if result is not null then return result;end if;
 if room_evidence then w:=app_private.lock_room_evidence_work(p_work_item_id,p_expected_version);
 else w:=app_private.file_work(p_work_item_id,p_expected_version); end if;
 if p_asset_ids is null or cardinality(p_asset_ids) not between 1 and 20 or array_ndims(p_asset_ids)>1 or cardinality(p_asset_ids)<>(select count(distinct x) from unnest(p_asset_ids)x) then raise exception using errcode='22023',message='command_validation_failed';end if;
 for a in select * from public.assets where id=any(p_asset_ids) order by id for update loop
 if a.kind<>'upload' or a.state not in ('validated','finalized') or a.origin_work_item_id<>w.id
   or (room_evidence and not a.room_booking_evidence) then raise exception using errcode='42501',message='command_permission_denied';end if;end loop;
 if (select count(*) from public.assets where id=any(p_asset_ids))<>cardinality(p_asset_ids) then raise exception using errcode='42501',message='command_permission_denied';end if;
 select sum(size_bytes)::integer,jsonb_agg(jsonb_build_object('assetId',id,'sha256',sha256,'size',size_bytes,'mime',mime_type,'classification',classification,'source',source_snapshot)order by id) into size,entries from public.assets where id=any(p_asset_ids);
 if size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
 insert into public.asset_manifests(work_item_id,work_version,entries,sha256,size_bytes,created_by) values(w.id,w.version,entries,encode(sha256(convert_to(entries::text,'UTF8')),'hex'),size,auth.uid()) returning id into mid;
 insert into public.asset_manifest_items(manifest_id,asset_id) select mid,unnest(p_asset_ids);
 update public.assets set state='finalized',version=version+1,updated_at=statement_timestamp() where id=any(p_asset_ids) and state='validated';
 return app_private.finish_work_command(w,'finalize_upload',p_request_id,payload,jsonb_build_object('manifestId',mid,'sha256',encode(sha256(convert_to(entries::text,'UTF8')),'hex')),'["immutable_manifest"]');
end$$;

alter function public.read_files(uuid) rename to read_files_before_room_evidence;
alter function public.read_files_before_room_evidence(uuid) set schema app_private;
create function public.read_files(p_work_item_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;
begin
  select * into w from public.work_items where id=p_work_item_id;
  if not app_private.room_evidence_writer(w) then
    return app_private.read_files_before_room_evidence(p_work_item_id);
  end if;
  return jsonb_build_object('workVersion',w.version,'canEdit',true,'manifests','[]'::jsonb,
    'assets',coalesce((select jsonb_agg(to_jsonb(a)-array['object_path','created_by','expires_at'] order by a.created_at,a.id)
      from public.assets a where a.origin_work_item_id=w.id and a.room_booking_evidence and a.state in ('validated','finalized')),'[]'));
end;
$$;

alter function public.authorize_asset_download(uuid,uuid,uuid) rename to authorize_asset_before_room_evidence;
alter function public.authorize_asset_before_room_evidence(uuid,uuid,uuid) set schema app_private;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items; a public.assets; payload jsonb;
begin
  select * into a from public.assets where id=p_asset_id and origin_work_item_id=p_work_item_id
    and room_booking_evidence and state in ('validated','finalized');
  select * into w from public.work_items where id=p_work_item_id;
  if a.id is null or not app_private.room_evidence_writer(w) then
    return app_private.authorize_asset_before_room_evidence(p_work_item_id,p_asset_id,p_request_id);
  end if;
  payload:=jsonb_build_array(w.id,a.id);
  if app_private.begin_work_command('authorize_room_evidence',p_request_id,payload) is null then
    insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,
      request_id,redacted_diff) values(w.organization_id,w.term_id,auth.uid(),'Current Logistics custodian',
      'room_evidence_download',w.id,w.version,p_request_id,'{"fields":["room_evidence_bytes"]}');
    insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)
      values(auth.uid(),'authorize_room_evidence',p_request_id,w.organization_id,w.term_id,
        encode(sha256(convert_to(payload::text,'UTF8')),'hex'),'{}');
  end if;
  return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind',a.kind,'mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256);
end;
$$;

revoke all on function app_private.room_evidence_writer(public.work_items),app_private.lock_room_evidence_work(uuid,integer),
  app_private.read_files_before_room_evidence(uuid),app_private.authorize_asset_before_room_evidence(uuid,uuid,uuid),
  public.read_files(uuid),public.authorize_asset_download(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_files(uuid),public.authorize_asset_download(uuid,uuid,uuid) to authenticated;
update app_private.disposition_sources set structure_hash=app_private.disposition_structure(source_key) where source_key='public.assets';

-- The catalogue remains separate from case details and live occupancy.
create function public.read_room_booking_workspace(p_term_id uuid,p_request_id uuid,
  p_starts_at timestamptz default null,p_ends_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  actor public.term_memberships; r public.requests; w public.work_items;
  b app_private.room_bookings; policy app_private.room_booking_policies;
  t public.terms; now_at timestamptz:=statement_timestamp();
  requester boolean; manager boolean; routing boolean; editable boolean;
  rooms jsonb; evidence jsonb; alternative jsonb; offer_version integer;
  offered app_private.room_booking_offers; offered_room app_private.rooms;
  desired jsonb; contact jsonb; school_files jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);
  select * into r from public.requests where work_item_id=p_request_id and term_id=p_term_id;
  select * into w from public.work_items where id=r.work_item_id;
  requester:=coalesce(w.owner_member_id=actor.member_id,false);
  manager:=coalesce(app_private.workflow_manager(r,actor),false);
  if r.work_item_id is null or w.archived_at is not null or not (requester or manager) then
    perform app_private.record_content_read('read_room_booking_workspace',p_term_id,null,false);
    return null;
  end if;
  select * into b from app_private.room_bookings where request_id=w.id;
  select * into t from public.terms where id=p_term_id;
  policy:=app_private.current_room_policy(p_term_id,now_at);
  routing:=coalesce(r.request_type_id=policy.request_type_id and r.receiving_unit_id=policy.logistics_unit_id
    and r.tracking_id is not null and r.request_state in ('paused','in_review','approved','completed')
    and app_private.workflow_hooks_ready(r),false);
  if not routing and b.request_id is null then
    perform app_private.record_content_read('read_room_booking_workspace',p_term_id,null,false);
    return null;
  end if;
  if b.request_id is not null then
    select jsonb_build_object('room',jsonb_build_object('id',room.id,'name',room.label),
      'startsAt',h.snapshot->'starts_at','endsAt',h.snapshot->'ends_at') into desired
    from app_private.room_booking_history h join app_private.rooms room on room.id=(h.snapshot->>'room_id')::uuid
    where h.request_id=b.request_id and h.action='request_booking' order by h.version desc limit 1;
  end if;
  select jsonb_build_object('id',d.member_id,'name',d.display_name) into contact
    from public.request_types service join public.term_memberships cm on cm.id=service.primary_contact_id
    join public.read_directory(p_term_id) d on d.member_id=cm.member_id
    where service.id=r.request_type_id and app_private.request_contact_active(service,cm.id);
  editable:=routing and t.state='active';
  select * into offered from app_private.room_booking_offers where request_id=b.request_id and booking_version=b.version
    order by version desc limit 1;
  offer_version:=coalesce(offered.version,0);
  if routing and offered.policy_version=policy.version and b.source_revision_id=r.current_revision_id then
    select * into offered_room from app_private.rooms where id=offered.room_id and retired_at is null;
    if offered_room.id is not null then
      alternative:=jsonb_build_object('room',jsonb_build_object('id',offered_room.id,'name',offered_room.label),
        'startsAt',offered.starts_at,'endsAt',offered.ends_at,
        'available',app_private.room_slot_available(offered_room,b.request_id,offered.starts_at,offered.ends_at,now_at));
    end if;
  end if;
  p_starts_at:=coalesce(p_starts_at,b.starts_at);
  p_ends_at:=coalesce(p_ends_at,b.ends_at);
  if p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at)
    or p_ends_at<=p_starts_at or p_ends_at-p_starts_at>interval '1 day'
    or (p_starts_at at time zone 'Asia/Manila')::date<t.starts_on
    or ((p_ends_at-interval '1 microsecond') at time zone 'Asia/Manila')::date>t.closes_on then
    p_starts_at:=null;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id',room.id,'name',room.label,'capacity',room.capacity,
    'accessible',room.accessible,'equipment',room.equipment,'setupMinutes',room.setup_minutes,
    'cleanupMinutes',room.cleanup_minutes,'available',case when p_starts_at is not null then
      app_private.room_slot_available(room,w.id,p_starts_at,p_ends_at,now_at) end)
    order by room.label,room.id),'[]'::jsonb) into rooms
  from app_private.rooms room where routing and room.organization_id=actor.organization_id and room.retired_at is null;

  if manager and editable and policy.evidence_mode='required' then
    select jsonb_agg(jsonb_build_object('id',m.id,'createdAt',m.created_at,'names',m.names)
      order by m.created_at desc,m.id) into evidence
    from (select m.id,m.created_at,array_agg(a.filename order by a.filename,a.id) names
      from public.asset_manifests m join public.asset_manifest_items i on i.manifest_id=m.id
      join public.assets a on a.id=i.asset_id
      where m.work_item_id=w.id
      group by m.id,m.created_at having bool_and(a.origin_work_item_id=w.id and a.state='finalized')
        and (bool_and(a.room_booking_evidence) or public.can_read_manifest(m.id))
      order by m.created_at desc,m.id limit 100) m;
  end if;
  if b.evidence_manifest_id is not null then
    select jsonb_agg(a.filename order by a.filename,a.id) into school_files
      from public.asset_manifest_items i join public.assets a on a.id=i.asset_id
      where i.manifest_id=b.evidence_manifest_id and a.origin_work_item_id=w.id and a.state='finalized'
        and (a.room_booking_evidence or public.can_read_manifest(b.evidence_manifest_id));
  end if;

  perform app_private.record_content_read('read_room_booking_workspace',p_term_id,w.id,true);
  return jsonb_build_object('booking',case when b.request_id is not null then app_private.room_booking_view(b,now_at) end,
    'rooms',rooms,'availabilityWindow',case when p_starts_at is not null then
      jsonb_build_object('startsAt',p_starts_at,'endsAt',p_ends_at) end,
    'reference',jsonb_build_object('value',r.tracking_id,'termId',t.id,'termLabel',t.label),
    'requestTitle',w.title,'service',r.service_label,'requester',requester,
    'policyVersion',case when routing then policy.version end,
    'evidenceMode',case when routing then policy.evidence_mode end,
    'maxHoldMinutes',case when routing then policy.max_hold_minutes end,
    'canRequest',editable and requester and (b.state is null or b.state in ('requested','held')),
    'canDecide',editable and manager and coalesce(b.state in ('requested','held','confirmed')
      and (b.source_revision_id=r.current_revision_id or b.state='confirmed'),false),
    'canCancel',t.state='active' and coalesce(b.state<>'cancelled' and (manager or requester and b.state='requested'),false),
    'officialReference',b.evidence_reference,'evidence',coalesce(evidence,'[]'::jsonb),'schoolFiles',coalesce(school_files,'[]'::jsonb),
    'desiredSlot',desired,'contact',contact,
    'alternative',alternative,'offerVersion',offer_version);
end;
$$;

insert into public.restricted_read_endpoints(endpoint,argument_types)
values('read_room_booking_workspace','uuid, uuid, timestamp with time zone, timestamp with time zone');
revoke all on function app_private.room_slot_available(app_private.rooms,uuid,timestamptz,timestamptz,timestamptz),
  public.offer_room_alternative(uuid,uuid,integer,integer,integer,uuid,timestamptz,timestamptz,text,uuid),
  public.read_room_booking_workspace(uuid,uuid,timestamptz,timestamptz)
  from public,anon,authenticated,service_role;
grant execute on function public.read_room_booking_workspace(uuid,uuid,timestamptz,timestamptz),
  public.offer_room_alternative(uuid,uuid,integer,integer,integer,uuid,timestamptz,timestamptz,text,uuid) to authenticated;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
values('app_private.room_booking_offers','restricted','term',array['request_id','booking_version','version'],
  $query$select app_private.disposition_key('app_private.room_booking_offers',
    array[x.request_id::text,x.booking_version::text,x.version::text]) target_hash,'restricted' category,x.request_id root_id,
    app_private.retention_is_held($1,'restricted',null::uuid,x.request_id) held,
    encode(sha256(convert_to(to_jsonb(x)::text,'UTF8')),'hex') state_hash from app_private.room_booking_offers x where x.term_id=$1$query$,
  app_private.disposition_structure('app_private.room_booking_offers'),false);

commit;
