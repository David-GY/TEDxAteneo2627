begin;

-- The controlled deployment provisions one named, approved target per term.
create table app_private.calendar_sync_targets (
  term_id uuid primary key references public.terms(id),
  calendar_id text not null unique check(calendar_id ~ '^[a-zA-Z0-9._-]{1,160}@group\.calendar\.google\.com$'),
  label text not null check(length(btrim(label)) between 1 and 160),
  custodian_id uuid not null references public.term_memberships(id),
  approved_by uuid not null references public.term_memberships(id) check(approved_by<>custodian_id),
  approval_reference text not null check(length(btrim(approval_reference)) between 1 and 500),
  approval_expires_at timestamptz not null check(isfinite(approval_expires_at)),
  generation uuid not null default gen_random_uuid(),
  state text not null default 'disconnected' check(state in ('disconnected','connected','reconnect','revoking')),
  sealed_refresh text check(length(sealed_refresh)<=6017 and sealed_refresh ~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,}$'),
  state_hash text check(state_hash ~ '^[a-f0-9]{64}$'),
  sealed_verifier text check(length(sealed_verifier)<=6017 and sealed_verifier ~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,}$'),
  attempt_expires_at timestamptz,
  check((state_hash is null)=(attempt_expires_at is null)),
  check(sealed_verifier is null or state_hash is not null),
  check((state='disconnected')=(sealed_refresh is null))
);

create table app_private.calendar_sync_mappings (
  work_item_id uuid primary key references public.calendar_events(work_item_id),
  term_id uuid not null references app_private.calendar_sync_targets(term_id),
  remote_event_id text not null unique default ('ev'||replace(gen_random_uuid()::text,'-','')),
  desired_version integer not null check(desired_version>0),
  applied_version integer check(applied_version<=desired_version),
  tombstone boolean not null default false,
  etag text,
  state text not null default 'queued' check(state in ('queued','current','removed','retry','conflict','reconnect')),
  attempts integer not null default 0 check(attempts between 0 and 8),
  next_attempt_at timestamptz not null default statement_timestamp(),
  last_verified_at timestamptz,
  lease uuid,
  lease_until timestamptz,
  claimed_version integer,
  claimed_tombstone boolean,
  check((lease is null)=(lease_until is null) and (lease is null)=(claimed_version is null) and (lease is null)=(claimed_tombstone is null))
);
create index calendar_sync_ready on app_private.calendar_sync_mappings(term_id,next_attempt_at)
  where state in ('queued','retry');
alter table app_private.calendar_sync_targets enable row level security;
alter table app_private.calendar_sync_targets force row level security;
alter table app_private.calendar_sync_mappings enable row level security;
alter table app_private.calendar_sync_mappings force row level security;
revoke all on app_private.calendar_sync_targets,app_private.calendar_sync_mappings from public,anon,authenticated,service_role;

create function app_private.calendar_sync_keep_target() returns trigger language plpgsql set search_path='' as $$
begin
  if (old.term_id,old.calendar_id,old.custodian_id) is distinct from (new.term_id,new.calendar_id,new.custodian_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  return new;
end;
$$;
create trigger calendar_sync_target_binding before update on app_private.calendar_sync_targets
  for each row execute function app_private.calendar_sync_keep_target();
revoke all on function app_private.calendar_sync_keep_target() from public,anon,authenticated,service_role;

create function app_private.calendar_sync_target_live(t app_private.calendar_sync_targets)
returns boolean language sql stable security definer set search_path='' as $$
  select t.approval_expires_at>statement_timestamp() and exists(
    select 1 from public.term_memberships m join public.members person on person.id=m.member_id
    join public.terms term on term.id=m.term_id
    where m.id=t.custodian_id and m.term_id=t.term_id and m.membership_kind='core' and m.status='active'
      and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp() and person.account_state='active' and term.state='active'
  ) and exists(
    select 1 from public.term_memberships m join public.members person on person.id=m.member_id
    where m.id=t.approved_by and m.term_id=t.term_id and m.membership_kind='core' and m.status='active'
      and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp() and person.account_state='active'
  );
$$;

create function app_private.calendar_sync_manager(t app_private.calendar_sync_targets)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce(app_private.calendar_sync_target_live(t)
    and t.custodian_id=public.current_term_membership(t.term_id)
    and app_private.calendar_editor(t.term_id,'core',null,null),false);
$$;
revoke all on function app_private.calendar_sync_target_live(app_private.calendar_sync_targets),
  app_private.calendar_sync_manager(app_private.calendar_sync_targets) from public,anon,authenticated,service_role;

create function public.calendar_sync_status(p_term_id uuid,p_event_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  target app_private.calendar_sync_targets;
  mapping app_private.calendar_sync_mappings;
  can_manage boolean;
begin
  perform app_private.request_actor(p_term_id,false);
  select * into target from app_private.calendar_sync_targets where term_id=p_term_id;
  if not found then return null; end if;
  can_manage:=app_private.calendar_sync_manager(target);
  if p_event_id is null then
    if not can_manage then return null; end if;
  else
    if not exists(select 1 from public.work_items work join public.calendar_events event on event.work_item_id=work.id
      where work.id=p_event_id and work.term_id=p_term_id and work.archived_at is null and event.visibility='core'
        and app_private.calendar_visible(work,event)) then return null; end if;
    select * into mapping from app_private.calendar_sync_mappings where work_item_id=p_event_id and term_id=p_term_id;
    if not found and not can_manage then return null; end if;
  end if;
  return jsonb_build_object('calendar',target.label,'canManage',can_manage,
    'connection',case when app_private.calendar_sync_target_live(target) is not true then 'reconnect' else target.state end,
    'state',mapping.state,'tombstone',coalesce(mapping.tombstone,false),'lastVerifiedAt',mapping.last_verified_at,
    'pausedRemoval',p_event_id is null and exists(select 1 from app_private.calendar_sync_mappings
      where term_id=p_term_id and tombstone and state='conflict'));
end;
$$;

create function public.calendar_sync_queue(p_term_id uuid,p_event_id uuid,p_version integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target app_private.calendar_sync_targets; work public.work_items; event public.calendar_events;
begin
  select * into target from app_private.calendar_sync_targets where term_id=p_term_id;
  if not app_private.calendar_sync_manager(target) then raise exception using errcode='42501',message='command_permission_denied'; end if;
  select w.* into work from public.work_items w where w.id=p_event_id and w.term_id=p_term_id and w.archived_at is null for update;
  select * into event from public.calendar_events where work_item_id=work.id and visibility='core';
  if not found then raise exception using errcode='42501',message='command_permission_denied'; end if;
  if work.version is distinct from p_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if event.state='cancelled' and not exists(select 1 from app_private.calendar_sync_mappings where work_item_id=work.id) then
    raise exception using errcode='55000',message='command_dependency_blocked';
  end if;
  insert into app_private.calendar_sync_mappings as m(work_item_id,term_id,desired_version,tombstone)
    values(work.id,p_term_id,work.version,event.state='cancelled')
  on conflict(work_item_id) do update
    set desired_version=excluded.desired_version,tombstone=m.tombstone or excluded.tombstone,
      state='queued',attempts=0,next_attempt_at=statement_timestamp()
    where m.lease is null or m.lease_until<=statement_timestamp();
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.calendar_sync_status(uuid,uuid),public.calendar_sync_queue(uuid,uuid,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.calendar_sync_status(uuid,uuid),public.calendar_sync_queue(uuid,uuid,integer) to authenticated;

-- Updates opt in only events already mapped. A private or cancelled revision becomes a terminal removal.
create function app_private.calendar_sync_source_changed() returns trigger language plpgsql security definer set search_path='' as $$
begin
  update app_private.calendar_sync_mappings m
    set desired_version=w.version,tombstone=m.tombstone or new.visibility<>'core' or new.state='cancelled',
      state='queued',attempts=0,next_attempt_at=statement_timestamp()
    from public.work_items w where m.work_item_id=new.work_item_id and w.id=m.work_item_id;
  return new;
end;
$$;
create trigger calendar_sync_source_update after update on public.calendar_events
  for each row execute function app_private.calendar_sync_source_changed();
revoke all on function app_private.calendar_sync_source_changed() from public,anon,authenticated,service_role;

create function public.calendar_sync_credential(p_term_id uuid,p_subject_id uuid,p_action text,
  p_guard text default null,p_sealed text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target app_private.calendar_sync_targets;
begin
  select t.* into target from app_private.calendar_sync_targets t
    join public.term_memberships m on m.id=t.custodian_id join public.members person on person.id=m.member_id
    where t.term_id=p_term_id and person.auth_user_id=p_subject_id and app_private.calendar_sync_target_live(t)
    for update of t;
  if not found then raise exception using errcode='42501',message='command_permission_denied'; end if;
  case p_action
    when 'read' then
      return jsonb_build_object('calendarId',target.calendar_id,'generation',target.generation,'state',target.state,'sealed',target.sealed_refresh);
    when 'start' then
      if target.state not in ('disconnected','reconnect') or p_guard is null or p_sealed is null then
        raise exception using errcode='40001',message='command_stale_version';
      end if;
      update app_private.calendar_sync_targets set state_hash=p_guard,sealed_verifier=p_sealed,
        attempt_expires_at=statement_timestamp()+interval '10 minutes' where term_id=p_term_id;
    when 'claim','finish' then
      if p_guard is null or target.state_hash is distinct from p_guard or target.attempt_expires_at<=statement_timestamp()
        or (p_action='claim') is distinct from (target.sealed_verifier is not null) then
        raise exception using errcode='40001',message='command_stale_version';
      end if;
      if p_action='claim' then
        update app_private.calendar_sync_targets set sealed_verifier=null where term_id=p_term_id;
        return jsonb_build_object('calendarId',target.calendar_id,'sealed',target.sealed_verifier);
      end if;
      update app_private.calendar_sync_targets set state_hash=null,attempt_expires_at=null, sealed_refresh=p_sealed,
        generation=gen_random_uuid(),state='connected' where term_id=p_term_id;
      update app_private.calendar_sync_mappings set state='queued',attempts=0,next_attempt_at=statement_timestamp(),
        lease=null,lease_until=null,claimed_version=null,claimed_tombstone=null
        where term_id=p_term_id;
    when 'cancel' then
      update app_private.calendar_sync_targets set state_hash=null,sealed_verifier=null,attempt_expires_at=null
        where term_id=p_term_id and state_hash=p_guard;
    when 'disconnect' then
      if target.state='disconnected' then
        update app_private.calendar_sync_targets set state_hash=null,sealed_verifier=null,attempt_expires_at=null where term_id=p_term_id;
        return jsonb_build_object('state','disconnected');
      end if;
      update app_private.calendar_sync_targets set state='revoking',state_hash=null,sealed_verifier=null,attempt_expires_at=null where term_id=p_term_id;
      return jsonb_build_object('state','revoking','generation',target.generation,'sealed',target.sealed_refresh);
    when 'revoked' then
      if target.state<>'revoking' or target.generation::text is distinct from p_guard then
        raise exception using errcode='40001',message='command_stale_version';
      end if;
      update app_private.calendar_sync_targets set state='disconnected',sealed_refresh=null,generation=gen_random_uuid() where term_id=p_term_id;
    else raise exception using errcode='22023',message='command_validation_failed';
  end case;
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.calendar_sync_credential(uuid,uuid,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.calendar_sync_credential(uuid,uuid,text,text,text) to service_role;

create function public.calendar_sync_job(p_term_id uuid,p_action text,p_event_id uuid default null,
  p_lease uuid default null,p_generation uuid default null,p_version integer default null,
  p_outcome text default null,p_etag text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target app_private.calendar_sync_targets; job app_private.calendar_sync_mappings; event public.calendar_events; obsolete boolean;
begin
  select * into target from app_private.calendar_sync_targets where term_id=p_term_id for update;
  if not found or target.state<>'connected' or app_private.calendar_sync_target_live(target) is not true
    or target.generation is distinct from p_generation then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  if p_action in ('claim','claim_removal') then
    select * into job from app_private.calendar_sync_mappings m
      where m.term_id=p_term_id and (p_event_id is null or m.work_item_id=p_event_id)
        and ((p_action='claim' and m.state in ('queued','retry'))
          or (p_action='claim_removal' and p_event_id is null and m.tombstone and m.state='conflict'))
        and m.next_attempt_at<=statement_timestamp() and (m.lease is null or m.lease_until<=statement_timestamp())
      order by m.next_attempt_at,m.work_item_id limit 1 for update skip locked;
    if not found then return null; end if;
    select event_row.* into event from public.calendar_events event_row join public.work_items w on w.id=event_row.work_item_id
      where w.id=job.work_item_id and w.term_id=p_term_id and w.archived_at is null
        and event_row.visibility='core' and event_row.state='confirmed';
    if not job.tombstone and event.work_item_id is not null and not exists(
      select 1 from public.work_items w where w.id=job.work_item_id and w.version=job.desired_version) then
      raise exception using errcode='40001',message='command_stale_version';
    end if;
    update app_private.calendar_sync_mappings set lease=gen_random_uuid(),lease_until=statement_timestamp()+interval '90 seconds',
      tombstone=job.tombstone or event.work_item_id is null,claimed_version=desired_version,
      claimed_tombstone=job.tombstone or event.work_item_id is null
      where work_item_id=job.work_item_id returning * into job;
    return jsonb_build_object('work',job.work_item_id,'lease',job.lease,'generation',target.generation,
      'id',job.remote_event_id,'version',job.claimed_version,'tombstone',job.claimed_tombstone,'etag',job.etag,
      'event',case when not job.claimed_tombstone then jsonb_build_object(
        'title',event.title,'allDay',event.all_day,'startOn',event.start_on,'endOn',event.end_on,
        'startsAt',event.starts_at,'endsAt',event.ends_at) end);
  end if;

  select * into job from app_private.calendar_sync_mappings where term_id=p_term_id and work_item_id=p_event_id
    and lease=p_lease and lease_until>statement_timestamp() and claimed_version=p_version for update;
  if not found then raise exception using errcode='40001',message='command_stale_version'; end if;
  if p_action='verify' then
    if job.desired_version<>job.claimed_version or job.tombstone<>job.claimed_tombstone or
      (not job.tombstone and not exists(select 1 from public.work_items w join public.calendar_events e on e.work_item_id=w.id
        where w.id=job.work_item_id and w.version=job.claimed_version and w.archived_at is null
          and e.visibility='core' and e.state='confirmed')) then
      raise exception using errcode='40001',message='command_stale_version';
    end if;
    return jsonb_build_object('ok',true);
  end if;
  if p_action<>'finish' or p_outcome is null or p_outcome not in ('verified','retry','conflict','reconnect')
    or (p_outcome='verified' and (p_etag is null)<>job.claimed_tombstone) then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  if p_outcome='reconnect' then
    update app_private.calendar_sync_targets set state='reconnect'
      where term_id=p_term_id and generation=p_generation and state='connected';
  end if;
  obsolete:=job.desired_version<>job.claimed_version or job.tombstone<>job.claimed_tombstone;
  update app_private.calendar_sync_mappings set
    applied_version=case when p_outcome='verified' then job.claimed_version else applied_version end,
    etag=case when p_outcome='verified' then p_etag else etag end,
    last_verified_at=case when p_outcome='verified' then statement_timestamp() else last_verified_at end,
    attempts=case when p_outcome='retry' and not obsolete then least(8,attempts+1) else 0 end,
    next_attempt_at=case when p_outcome='retry' and not obsolete then statement_timestamp()+least(3600,30*(2^attempts))*interval '1 second'
      else statement_timestamp() end,
    state=case when obsolete then 'queued'
      when p_outcome='verified' then case when job.tombstone then 'removed' else 'current' end
      when p_outcome='retry' and attempts>=7 then 'conflict' else p_outcome end,
    lease=null,lease_until=null,claimed_version=null,claimed_tombstone=null
    where work_item_id=job.work_item_id;
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.calendar_sync_job(uuid,text,uuid,uuid,uuid,integer,text,text) from public,anon,authenticated,service_role;
grant execute on function public.calendar_sync_job(uuid,text,uuid,uuid,uuid,integer,text,text) to service_role;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
values
('app_private.calendar_sync_targets','operational','term',array['term_id'],
  'select app_private.disposition_key(''app_private.calendar_sync_targets'',array[t.term_id::text]) target_hash,
    ''operational'' category,null::uuid root_id,app_private.retention_is_held($1,''operational'',null::uuid,null::uuid) held,
    encode(sha256(convert_to(to_jsonb(t)::text,''UTF8'')),''hex'') state_hash from app_private.calendar_sync_targets t where t.term_id=$1',
  app_private.disposition_structure('app_private.calendar_sync_targets'),false),
('app_private.calendar_sync_mappings','operational','term',array['work_item_id'],
  'select app_private.disposition_key(''app_private.calendar_sync_mappings'',array[m.work_item_id::text]) target_hash,
    ''operational'' category,m.work_item_id root_id,app_private.retention_is_held($1,''operational'',null::uuid,m.work_item_id) held,
    encode(sha256(convert_to(to_jsonb(m)::text,''UTF8'')),''hex'') state_hash from app_private.calendar_sync_mappings m where m.term_id=$1',
  app_private.disposition_structure('app_private.calendar_sync_mappings'),false);

commit;
