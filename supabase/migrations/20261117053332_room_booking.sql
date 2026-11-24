begin;
create extension if not exists btree_gist with schema extensions;
set local search_path=pg_catalog,extensions,public;

-- These deferred request checks run at commit, after the RPC returns to the authenticated role.
alter function app_private.request_payload_presence() security definer;
alter function app_private.finance_revision_required() security definer;
revoke all on function app_private.request_payload_presence(),app_private.finance_revision_required()
  from public,anon,authenticated,service_role;

create function app_private.room_equipment_valid(items text[]) returns boolean
language sql immutable set search_path='' as $$
  select items is not null and cardinality(items)<=12
    and not exists(select 1 from unnest(items) tag where tag is null or tag !~ '^[a-z][a-z0-9_-]{0,39}$')
    and cardinality(items)=(select count(distinct tag) from unnest(items) tag);
$$;

create table app_private.rooms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  label text not null check(length(btrim(label)) between 1 and 160),
  capacity integer not null check(capacity between 1 and 10000),
  accessible boolean not null,
  equipment text[] not null default '{}',
  setup_minutes integer not null default 0 check(setup_minutes between 0 and 240),
  cleanup_minutes integer not null default 0 check(cleanup_minutes between 0 and 240),
  retired_at timestamptz,
  check(app_private.room_equipment_valid(equipment)),
  unique(organization_id,label)
);

-- No room catalogue or governing school policy is seeded into an actual term.
create table app_private.room_booking_policies (
  term_id uuid not null references public.terms(id),
  version integer not null check(version>0),
  request_type_id uuid not null references public.request_types(id),
  logistics_unit_id uuid not null references public.org_units(id),
  evidence_mode text not null check(evidence_mode in ('required','official_not_required','disabled')),
  approved_by uuid not null references public.term_memberships(id),
  approval_reference text not null check(length(btrim(approval_reference)) between 3 and 500),
  approved_at timestamptz not null check(isfinite(approved_at)),
  expires_at timestamptz not null check(isfinite(expires_at) and expires_at>approved_at),
  max_hold_minutes integer not null check(max_hold_minutes between 1 and 120),
  primary key(term_id,version)
);
create trigger immutable_room_booking_policy before update or delete on app_private.room_booking_policies
  for each row execute function app_private.request_history_guard();

create table app_private.room_bookings (
  request_id uuid primary key references public.requests(work_item_id),
  term_id uuid not null references public.terms(id),
  source_revision_id uuid not null references public.request_revisions(id),
  room_id uuid not null references app_private.rooms(id),
  starts_at timestamptz not null check(isfinite(starts_at)),
  ends_at timestamptz not null check(isfinite(ends_at) and ends_at>starts_at and ends_at-starts_at<=interval '1 day'),
  setup_minutes integer not null check(setup_minutes between 0 and 240),
  cleanup_minutes integer not null check(cleanup_minutes between 0 and 240),
  blocked_slot tstzrange not null,
  purpose text not null check(length(btrim(purpose)) between 1 and 1000),
  attendees integer not null check(attendees between 1 and 10000),
  needs_accessible boolean not null,
  equipment text[] not null check(app_private.room_equipment_valid(equipment)),
  state text not null check(state in ('requested','held','confirmed','cancelled')),
  hold_expires_at timestamptz,
  evidence_policy_version integer,
  evidence_version integer,
  evidence_manifest_id uuid references public.asset_manifests(id),
  evidence_reference text check(length(btrim(evidence_reference)) between 3 and 500),
  confirmed_by uuid references public.term_memberships(id),
  version integer not null default 1 check(version>0),
  changed_at timestamptz not null default clock_timestamp(),
  check(blocked_slot=tstzrange(starts_at-make_interval(mins=>setup_minutes),ends_at+make_interval(mins=>cleanup_minutes),'[)')),
  check((state='held')=(hold_expires_at is not null)),
  check(state<>'confirmed' or (evidence_policy_version is not null and evidence_version=version and confirmed_by is not null)),
  check(evidence_version is null or evidence_version between 1 and version),
  foreign key(term_id,evidence_policy_version) references app_private.room_booking_policies(term_id,version),
  constraint room_bookings_no_overlap exclude using gist (room_id with =,blocked_slot with &&)
    where (state in ('held','confirmed'))
);
create index room_bookings_calendar on app_private.room_bookings(term_id,starts_at) where state='confirmed';
create index room_bookings_expiry on app_private.room_bookings(room_id,hold_expires_at) where state='held';

create table app_private.room_booking_history (
  request_id uuid not null references app_private.room_bookings(request_id),
  version integer not null,
  actor_id uuid not null references auth.users(id),
  action text not null check(action in ('request_booking','hold_booking','confirm_booking','cancel_booking','hold_expired')),
  reason text not null check(length(btrim(reason)) between 1 and 2000),
  snapshot jsonb not null,
  recorded_at timestamptz not null default clock_timestamp(),
  primary key(request_id,version)
);
create trigger immutable_room_booking_history before update or delete on app_private.room_booking_history
  for each row execute function app_private.request_history_guard();
do $$declare relation text;
begin
  foreach relation in array array['rooms','room_booking_policies','room_bookings','room_booking_history'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
  end loop;
end $$;

create function app_private.current_room_policy(p_term uuid,p_now timestamptz)
returns app_private.room_booking_policies language sql stable security definer set search_path='' as $$
  select p.* from (
    select x.* from app_private.room_booking_policies x where x.term_id=p_term and x.approved_at<=p_now
    order by x.version desc limit 1
  ) p join public.term_memberships approver on approver.id=p.approved_by and approver.term_id=p.term_id
  join public.members person on person.id=approver.member_id and person.account_state='active'
  join public.request_types service on service.id=p.request_type_id and service.term_id=p.term_id
  join public.org_units u on u.id=p.logistics_unit_id and u.term_id=p.term_id
  where p.expires_at>p_now and p.evidence_mode<>'disabled' and u.archived_at is null and u.review_service
    and approver.membership_kind='core' and approver.status='active' and approver.joined_at<=p_now and approver.ends_at>p_now
    and service.receiving_unit_id=p.logistics_unit_id and service.governed_kind='general'
    and service.authority_confirmed and service.live_enabled;
$$;

-- The normal command receipt retains only a pointer. Private booking fields stay in booking history.
create function app_private.room_command_result(p_request uuid,receipt jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare snapshot jsonb; version_at integer; booking jsonb;
begin
  version_at:=(receipt->>'version')::integer;
  if version_at is not null then
    select h.snapshot into snapshot from app_private.room_booking_history h
      where h.request_id=p_request and h.version=version_at;
    if snapshot is null then raise exception using errcode='55000',message='command_dependency_blocked'; end if;
    booking:=app_private.room_booking_view(jsonb_populate_record(null::app_private.room_bookings,snapshot),
      (receipt->>'at')::timestamptz);
  end if;
  return (receipt-array['version','at'])||jsonb_build_object('booking',booking);
end;
$$;

create function app_private.room_booking_view(b app_private.room_bookings,p_now timestamptz)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('requestId',b.request_id,'version',b.version,'sourceRevision',rev.revision_no,
    'reference',jsonb_build_object('value',r.tracking_id,'termId',t.id,'termLabel',t.label),
    'room',jsonb_build_object('id',room.id,'name',room.label),'startsAt',b.starts_at,'endsAt',b.ends_at,
    'setupMinutes',b.setup_minutes,'cleanupMinutes',b.cleanup_minutes,'attendees',b.attendees,
    'accessible',b.needs_accessible,'equipment',b.equipment,'purpose',b.purpose,
    'state',case when b.state='held' and b.hold_expires_at<=p_now then 'requested' else b.state end,
    'holdUntil',case when b.state='held' and b.hold_expires_at>p_now then b.hold_expires_at end,
    'holdExpired',coalesce(b.state='held' and b.hold_expires_at<=p_now,false) or exists(
      select 1 from app_private.room_booking_history h where h.request_id=b.request_id and h.version=b.version and h.action='hold_expired'),
    'requestChanged',b.source_revision_id is distinct from r.current_revision_id,
    'evidence',case when b.evidence_version is not null then jsonb_build_object(
      'version',b.evidence_version,'policyVersion',b.evidence_policy_version,
      'kind',case when b.evidence_manifest_id is not null then 'school_record' else 'official_not_required' end) end)
  from public.requests r join public.terms t on t.id=r.term_id join app_private.rooms room on room.id=b.room_id
    join public.request_revisions rev on rev.id=b.source_revision_id and rev.request_id=r.work_item_id
  where r.work_item_id=b.request_id;
$$;

create function public.read_booking_rooms(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.room_booking_policies; rooms jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);
  policy:=app_private.current_room_policy(p_term_id,statement_timestamp());
  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'name',r.label,'capacity',r.capacity,
    'accessible',r.accessible,'equipment',r.equipment,'setupMinutes',r.setup_minutes,'cleanupMinutes',r.cleanup_minutes)
    order by r.label,r.id),'[]'::jsonb) into rooms
    from app_private.rooms r where policy.term_id is not null and r.organization_id=actor.organization_id and r.retired_at is null;
  perform app_private.record_content_read('read_booking_rooms',p_term_id,null,jsonb_array_length(rooms)>0);
  return jsonb_build_object('rooms',rooms,'policyVersion',policy.version,'evidenceMode',policy.evidence_mode);
end;
$$;

create function public.read_room_booking(p_term_id uuid,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; r public.requests; w public.work_items; b app_private.room_bookings;
begin
  actor:=app_private.request_actor(p_term_id,false);
  select * into r from public.requests where work_item_id=p_request_id and term_id=p_term_id;
  select * into w from public.work_items where id=r.work_item_id;
  select * into b from app_private.room_bookings where request_id=r.work_item_id;
  if b.request_id is null or w.archived_at is not null or
    (w.owner_member_id is distinct from actor.member_id and not coalesce(app_private.workflow_manager(r,actor),false)) then
    perform app_private.record_content_read('read_room_booking',p_term_id,null,false);
    return null;
  end if;
  perform app_private.record_content_read('read_room_booking',p_term_id,w.id,true);
  return app_private.room_booking_view(b,statement_timestamp());
end;
$$;

create function app_private.save_room_booking(p_action text,p_term uuid,p_request uuid,p_version integer,p_room uuid,
  p_start timestamptz,p_end timestamptz,p_purpose text,p_attendees integer,p_accessible boolean,p_equipment text[],
  p_hold integer,p_policy integer,p_manifest uuid,p_reference text,p_reason text,p_key uuid)
returns jsonb language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare actor public.term_memberships; r public.requests; w public.work_items; term public.terms; room app_private.rooms;
  policy app_private.room_booking_policies; b app_private.room_bookings; expired app_private.room_bookings;
  who_owns boolean; logistics boolean; now_at timestamptz; payload jsonb; result jsonb; is_new boolean;
begin
  actor:=app_private.request_actor(p_term,true);
  perform app_private.readiness_lock(p_term);
  -- Booking decisions share a lock across terms because a physical room can be reused by different terms.
  perform pg_advisory_xact_lock(hashtextextended('room-booking-transitions',0));
  now_at:=clock_timestamp();
  if app_private.disposition_replay_required(p_term) then
    raise exception using errcode='55000',message='privacy_restore_replay_required';
  end if;
  select * into w from public.work_items where id=p_request and term_id=p_term for update;
  select * into r from public.requests where work_item_id=w.id and term_id=p_term;
  select * into b from app_private.room_bookings where request_id=r.work_item_id for update;
  is_new:=b.request_id is null;
  who_owns:=w.owner_member_id=actor.member_id;
  logistics:=coalesce(app_private.workflow_manager(r,actor),false);
  if r.work_item_id is null or (w.archived_at is not null and p_action<>'cancel_booking')
    or (p_action='request_booking' and not coalesce(who_owns,false))
    or (p_action in ('hold_booking','confirm_booking') and not logistics)
    or (p_action='cancel_booking' and not coalesce(logistics or who_owns and b.state in ('requested','cancelled'),false)) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term,p_request,p_version,p_room,p_start,p_end,p_purpose,p_attendees,p_accessible,p_equipment,
    p_hold,p_policy,p_manifest,p_reference,p_reason);
  result:=app_private.begin_work_command(p_action,p_key,payload);
  if result is not null then return app_private.room_command_result(p_request,result); end if;
  if coalesce(b.version,0) is distinct from p_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if p_reason is null or length(btrim(p_reason)) not between 1 and 2000
    then raise exception using errcode='22023',message='command_validation_failed'; end if;
  if p_action='cancel_booking' then
    if is_new or b.state='cancelled' then raise exception using errcode='55000',message='command_booking_state_changed'; end if;
    update app_private.room_bookings set state='cancelled',hold_expires_at=null,version=version+1,changed_at=now_at
      where request_id=p_request returning * into b;
  else
    policy:=app_private.current_room_policy(p_term,now_at);
    if policy.term_id is null or r.request_type_id is distinct from policy.request_type_id
      or r.receiving_unit_id is distinct from policy.logistics_unit_id or r.tracking_id is null
      or not app_private.workflow_hooks_ready(r)
      or r.request_state not in ('paused','in_review','approved','completed') then
      raise exception using errcode='55000',message='command_booking_request_unavailable';
    end if;
    if b.state='cancelled' or (p_action='request_booking' and b.state='confirmed')
      or (p_action='hold_booking' and (is_new or b.state='confirmed'))
      or (p_action='confirm_booking' and is_new)
      or (p_action in ('hold_booking','confirm_booking') and b.state<>'confirmed' and b.source_revision_id<>r.current_revision_id)
      then raise exception using errcode='55000',message='command_booking_state_changed'; end if;

    if p_action='request_booking' then
      b.purpose:=btrim(p_purpose);b.attendees:=p_attendees;b.needs_accessible:=p_accessible;b.equipment:=p_equipment;
      if b.purpose is null or length(b.purpose) not between 1 and 1000 or b.attendees is null or b.attendees not between 1 and 10000
        or b.needs_accessible is null or not app_private.room_equipment_valid(b.equipment)
        then raise exception using errcode='22023',message='command_validation_failed'; end if;
    end if;
    if p_action='hold_booking' then
      if p_hold is null or p_hold not between 1 and policy.max_hold_minutes
        then raise exception using errcode='22023',message='command_validation_failed'; end if;
      p_room:=b.room_id;p_start:=b.starts_at;p_end:=b.ends_at;
    end if;
    select * into room from app_private.rooms where id=p_room and organization_id=actor.organization_id and retired_at is null for share;
    if room.id is null or room.capacity<b.attendees or (b.needs_accessible and not room.accessible)
      or not room.equipment@>b.equipment then
      select * into b from app_private.room_bookings where request_id=p_request;
      return app_private.room_command_result(p_request,app_private.notification_receipt(p_term,p_action,p_key,payload,
        jsonb_build_object('outcome','blocked','reason','room_unsuitable','version',b.version,'at',now_at)));
    end if;
    select * into term from public.terms where id=p_term;
    if p_start is null or p_end is null or not isfinite(p_start) or not isfinite(p_end) or p_end<=p_start
      or p_end-p_start>interval '1 day' or (p_start at time zone 'Asia/Manila')::date<term.starts_on
      or ((p_end-interval '1 microsecond') at time zone 'Asia/Manila')::date>term.closes_on
      or (p_action in ('hold_booking','confirm_booking') and p_start<=now_at)
      then raise exception using errcode='22023',message='command_booking_invalid_slot'; end if;
    if p_action='confirm_booking' then
      if p_policy is distinct from policy.version then raise exception using errcode='40001',message='command_booking_policy_changed'; end if;
      if b.state<>'confirmed' and (p_room,p_start,p_end) is distinct from (b.room_id,b.starts_at,b.ends_at) then
        raise exception using errcode='55000',message='command_booking_request_slot_changed';
      end if;
      if policy.evidence_mode='required' then
        if p_reference is null or length(btrim(p_reference)) not between 3 and 500
          or not exists(select 1 from public.asset_manifests m join public.asset_manifest_items item on item.manifest_id=m.id
            join public.assets a on a.id=item.asset_id and a.state='finalized' and a.origin_work_item_id=w.id
            where m.id=p_manifest and m.work_item_id=w.id)
          or exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id
            where i.manifest_id=p_manifest and (a.origin_work_item_id<>w.id or a.state<>'finalized')) then
          raise exception using errcode='55000',message='command_booking_official_evidence_required';
        end if;
      elsif p_manifest is not null or p_reference is not null then
        raise exception using errcode='22023',message='command_validation_failed';
      end if;
    end if;

    if p_action in ('hold_booking','confirm_booking') then
      for expired in update app_private.room_bookings set state='requested',hold_expires_at=null,
        version=version+1,changed_at=now_at where room_id=p_room and request_id<>p_request and state='held' and hold_expires_at<=now_at
        returning *
      loop
        insert into app_private.room_booking_history(request_id,version,actor_id,action,reason,snapshot)
          values(expired.request_id,expired.version,auth.uid(),'hold_expired','Hold expired before a new reservation',to_jsonb(expired));
      end loop;
    end if;
    b.request_id:=p_request;b.term_id:=p_term;b.source_revision_id:=r.current_revision_id;b.room_id:=p_room;
    b.starts_at:=p_start;b.ends_at:=p_end;b.setup_minutes:=room.setup_minutes;b.cleanup_minutes:=room.cleanup_minutes;
    b.blocked_slot:=tstzrange(p_start-make_interval(mins=>b.setup_minutes),p_end+make_interval(mins=>b.cleanup_minutes),'[)');
    if p_action='hold_booking' and lower(b.blocked_slot)<=now_at then
      raise exception using errcode='22023',message='command_booking_invalid_slot';
    end if;
    b.state:=case p_action when 'request_booking' then 'requested' when 'hold_booking' then 'held' else 'confirmed' end;
    b.hold_expires_at:=case when b.state='held' then least(now_at+make_interval(mins=>p_hold),lower(b.blocked_slot)) end;
    b.version:=coalesce(b.version,0)+1;b.changed_at:=now_at;
    b.evidence_policy_version:=case when b.state='confirmed' then policy.version end;
    b.evidence_version:=case when b.state='confirmed' then b.version end;
    b.evidence_manifest_id:=case when b.state='confirmed' then p_manifest end;
    b.evidence_reference:=case when b.state='confirmed' and p_reference is not null then btrim(p_reference) end;
    b.confirmed_by:=case when b.state='confirmed' then actor.id end;
    begin
      insert into app_private.room_bookings values(b.*) on conflict(request_id) do update
        set source_revision_id=excluded.source_revision_id,room_id=excluded.room_id,starts_at=excluded.starts_at,
          ends_at=excluded.ends_at,setup_minutes=excluded.setup_minutes,cleanup_minutes=excluded.cleanup_minutes,
          blocked_slot=excluded.blocked_slot,purpose=excluded.purpose,attendees=excluded.attendees,
          needs_accessible=excluded.needs_accessible,equipment=excluded.equipment,state=excluded.state,
          hold_expires_at=excluded.hold_expires_at,evidence_policy_version=excluded.evidence_policy_version,
          evidence_version=excluded.evidence_version,evidence_manifest_id=excluded.evidence_manifest_id,
          evidence_reference=excluded.evidence_reference,confirmed_by=excluded.confirmed_by,version=excluded.version,changed_at=excluded.changed_at;
    exception when exclusion_violation then
      select * into b from app_private.room_bookings where request_id=p_request;
      return app_private.room_command_result(p_request,app_private.notification_receipt(p_term,p_action,p_key,payload,
        jsonb_build_object('outcome','conflict','reason','slot_unavailable','version',b.version,'at',now_at)));
    end;
  end if;
  insert into app_private.room_booking_history(request_id,version,actor_id,action,reason,snapshot)
    values(b.request_id,b.version,auth.uid(),p_action,btrim(p_reason),to_jsonb(b));
  result:=app_private.finish_work_command(w,p_action,p_key,payload,
    jsonb_build_object('outcome','saved','version',b.version,'at',now_at),jsonb_build_array('room_booking'));
  return app_private.room_command_result(p_request,result);
end;
$$;

create function public.request_booking(p_term_id uuid,p_request_id uuid,p_expected_version integer,p_room_id uuid,
  p_starts_at timestamptz,p_ends_at timestamptz,p_purpose text,p_attendees integer,p_accessible boolean,p_equipment text[],
  p_reason text,p_key uuid) returns jsonb language sql security definer set search_path='' as $$
  select app_private.save_room_booking('request_booking',p_term_id,p_request_id,p_expected_version,p_room_id,p_starts_at,p_ends_at,
    p_purpose,p_attendees,p_accessible,p_equipment,null,null,null,null,p_reason,p_key);
$$;
create function public.hold_booking(p_term_id uuid,p_request_id uuid,p_expected_version integer,p_minutes integer,p_reason text,p_key uuid)
returns jsonb language sql security definer set search_path='' as $$
  select app_private.save_room_booking('hold_booking',p_term_id,p_request_id,p_expected_version,null,null,null,null,null,null,null,
    p_minutes,null,null,null,p_reason,p_key);
$$;
create function public.confirm_booking(p_term_id uuid,p_request_id uuid,p_expected_version integer,p_room_id uuid,
  p_starts_at timestamptz,p_ends_at timestamptz,p_policy_version integer,p_evidence_manifest_id uuid default null,p_official_reference text default null,
  p_reason text default null,p_key uuid default null) returns jsonb language sql security definer set search_path='' as $$
  select app_private.save_room_booking('confirm_booking',p_term_id,p_request_id,p_expected_version,p_room_id,p_starts_at,p_ends_at,
    null,null,null,null,null,p_policy_version,p_evidence_manifest_id,p_official_reference,p_reason,p_key);
$$;
create function public.cancel_booking(p_term_id uuid,p_request_id uuid,p_expected_version integer,p_reason text,p_key uuid)
returns jsonb language sql security definer set search_path='' as $$
  select app_private.save_room_booking('cancel_booking',p_term_id,p_request_id,p_expected_version,null,null,null,null,null,null,null,
    null,null,null,null,p_reason,p_key);
$$;

alter function app_private.calendar_rows(uuid) rename to calendar_rows_before_bookings;
create function app_private.calendar_rows(term uuid) returns setof jsonb
language sql stable security definer set search_path='' as $$
  select * from app_private.calendar_rows_before_bookings(term)
  union all
  select jsonb_build_object('key','booking:'||b.request_id,'version',b.version,'title','Officially confirmed room',
    'description','Room confirmed through Logistics.','location',room.label,'visibility','restricted',
    'unitId',r.receiving_unit_id,'allDay',false,'startOn',null,'endOn',null,'startsAt',b.starts_at,'endsAt',b.ends_at,
    'state','confirmed','updatedAt',b.changed_at,'source','booking','href',null,'canEdit',false,'exportAllowed',false)
  from app_private.room_bookings b join app_private.rooms room on room.id=b.room_id
    join public.requests r on r.work_item_id=b.request_id join public.work_items w on w.id=b.request_id
    join public.term_memberships viewer on viewer.id=public.current_term_membership(term)
  where b.term_id=term and b.state='confirmed' and w.archived_at is null
    and public.has_capability(term,'workspace.read')
    and (viewer.member_id=w.owner_member_id or app_private.workflow_manager(r,viewer));
$$;

insert into public.restricted_read_endpoints(endpoint,argument_types)
values('read_booking_rooms','uuid'),('read_room_booking','uuid, uuid');
revoke all on function app_private.room_equipment_valid(text[]),app_private.current_room_policy(uuid,timestamptz),
  app_private.room_booking_view(app_private.room_bookings,timestamptz),app_private.calendar_rows(uuid),
  app_private.room_command_result(uuid,jsonb),
  app_private.save_room_booking(text,uuid,uuid,integer,uuid,timestamptz,timestamptz,text,integer,boolean,text[],integer,integer,uuid,text,text,uuid),
  public.read_booking_rooms(uuid),public.read_room_booking(uuid,uuid),
  public.request_booking(uuid,uuid,integer,uuid,timestamptz,timestamptz,text,integer,boolean,text[],text,uuid),
  public.hold_booking(uuid,uuid,integer,integer,text,uuid),
  public.confirm_booking(uuid,uuid,integer,uuid,timestamptz,timestamptz,integer,uuid,text,text,uuid),
  public.cancel_booking(uuid,uuid,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_booking_rooms(uuid),public.read_room_booking(uuid,uuid),
  public.request_booking(uuid,uuid,integer,uuid,timestamptz,timestamptz,text,integer,boolean,text[],text,uuid),
  public.hold_booking(uuid,uuid,integer,integer,text,uuid),
  public.confirm_booking(uuid,uuid,integer,uuid,timestamptz,timestamptz,integer,uuid,text,text,uuid),
  public.cancel_booking(uuid,uuid,integer,text,uuid) to authenticated;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,category,'term',keys,
  format('select app_private.disposition_key(%L,%s) target_hash,%L category,%s root_id,
    app_private.retention_is_held($1,%L,null::uuid,%s) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x %s where %s=$1',
    'app_private.'||source,key_expr,category,root_expr,category,root_expr,source,joins,term_expr),
  app_private.disposition_structure('app_private.'||source),false
from (values
 ('room_booking_policies','security',array['term_id','version'],'array[x.term_id::text,x.version::text]','null::uuid','','x.term_id'),
 ('room_bookings','restricted',array['request_id'],'array[x.request_id::text]','x.request_id','','x.term_id'),
 ('room_booking_history','restricted',array['request_id','version'],'array[x.request_id::text,x.version::text]','x.request_id',
  'join app_private.room_bookings b on b.request_id=x.request_id','b.term_id')
) definitions(source,category,keys,key_expr,root_expr,joins,term_expr);
insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
values('app_private.rooms','operational','shared',array['id'],null,app_private.disposition_structure('app_private.rooms'),true);
commit;
