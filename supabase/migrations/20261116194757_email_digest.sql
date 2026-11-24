begin;

-- Provisioned only after independent verification in the authorized environment.
create table app_private.email_sender_approvals (
  term_id uuid primary key references public.terms(id),
  sender text not null unique check(length(sender)<=254 and sender=lower(sender)
    and sender ~ '^[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-z0-9-]+([.][a-z0-9-]+)+$'),
  domain_id uuid not null unique,
  verified_by uuid not null references public.term_memberships(id),
  approved_by uuid not null references public.term_memberships(id) check(approved_by<>verified_by),
  evidence_reference text not null check(length(btrim(evidence_reference)) between 1 and 400),
  dns_verified_at timestamptz not null check(isfinite(dns_verified_at)),
  delivery_verified_at timestamptz not null check(isfinite(delivery_verified_at)),
  quota_verified_at timestamptz not null check(isfinite(quota_verified_at)),
  approval_expires_at timestamptz not null check(isfinite(approval_expires_at)),
  daily_cap integer not null check(daily_cap between 1 and 100),
  domain_checked_at timestamptz,
  quota_blocked_at timestamptz,
  revoked_at timestamptz
);
create table app_private.email_digest_preferences (
  membership_id uuid primary key references public.term_memberships(id),
  email_hash text check(email_hash ~ '^[a-f0-9]{64}$'),
  bounced_hash text check(bounced_hash ~ '^[a-f0-9]{64}$'),
  opted_at timestamptz,
  generation uuid not null default gen_random_uuid(),
  version integer not null default 1 check(version>0),
  check((email_hash is null)=(opted_at is null))
);
create table app_private.email_digest_jobs (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references app_private.email_sender_approvals(term_id),
  membership_id uuid not null references app_private.email_digest_preferences(membership_id),
  generation uuid not null,
  email_hash text not null check(email_hash ~ '^[a-f0-9]{64}$'),
  digest_day date not null,
  state text not null default 'waiting' check(state in ('waiting','sending','accepted','delivered','bounced','failed','skipped','uncertain')),
  next_at timestamptz not null,
  verify_until timestamptz,
  provider_id uuid unique,
  lease uuid,
  lease_until timestamptz,
  attempts integer not null default 0 check(attempts between 0 and 4),
  changed_at timestamptz not null default statement_timestamp(),
  check((lease is null)=(lease_until is null)),
  unique(membership_id,digest_day)
);
create index email_digest_jobs_queue on app_private.email_digest_jobs(term_id,state,next_at);
create index email_digest_jobs_status on app_private.email_digest_jobs(membership_id,generation,changed_at desc);
create table app_private.email_digest_quota (
  term_id uuid not null references app_private.email_sender_approvals(term_id),
  utc_day date not null,
  attempts integer not null check(attempts between 1 and 100),
  primary key(term_id,utc_day)
);

do $$
declare relation text;
begin
  foreach relation in array array['email_sender_approvals','email_digest_preferences','email_digest_jobs','email_digest_quota'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
  end loop;
end $$;

create function app_private.email_current_school_address(p_membership uuid) returns text
language sql stable security definer set search_path='' as $$
  select m.normalized_email from public.term_memberships tm join public.members m on m.id=tm.member_id
    join public.terms t on t.id=tm.term_id join public.organizations o on o.id=t.organization_id
  where tm.id=p_membership and tm.membership_kind='core' and tm.status='active' and m.account_state='active'
    and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp() and t.state='active' and o.state='active'
    and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
    and app_private.is_school_identity(m.auth_user_id) and app_private.verified_google_email(m.auth_user_id)=m.normalized_email
    and m.normalized_email ~ '^[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@student[.]ateneo[.]edu$'
    and exists(select 1 from app_private.effective_role_assignments a
      join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope=a.scope_type
      where a.term_membership_id=tm.id and a.term_id=t.id and a.scope_type in ('term','own')
        and p.capability='workspace.read' and app_private.access_assignment_live(a.id));
$$;

create function app_private.email_approval_live(a app_private.email_sender_approvals,p_now timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(a.revoked_at is null and a.approval_expires_at>p_now and a.dns_verified_at<=p_now
    and a.delivery_verified_at<=p_now and a.quota_verified_at<=p_now
    and exists(select 1 from public.term_memberships tm where tm.id=a.approved_by and tm.term_id=a.term_id)
    and exists(select 1 from public.term_memberships tm where tm.id=a.verified_by and tm.term_id=a.term_id)
    and app_private.email_current_school_address(a.approved_by) is not null
    and app_private.email_current_school_address(a.verified_by) is not null
    and not app_private.disposition_replay_required(a.term_id),false);
$$;

create function app_private.email_quota_blocked(a app_private.email_sender_approvals,p_now timestamptz) returns boolean
language sql stable security definer set search_path='' as $$
  select a.quota_blocked_at is not null or coalesce((select q.attempts from app_private.email_digest_quota q
    where q.term_id=a.term_id and q.utc_day=(p_now at time zone 'UTC')::date),0)>=a.daily_cap;
$$;

create function public.email_digest_status(p_term_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships; a app_private.email_sender_approvals; prefs app_private.email_digest_preferences;
  health text; activation text; address_hash text;
begin
  m:=app_private.request_actor(p_term_id,false);
  if app_private.disposition_replay_required(p_term_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  address_hash:=encode(sha256(convert_to(app_private.email_current_school_address(m.id),'UTF8')),'hex');
  select * into a from app_private.email_sender_approvals where term_id=p_term_id;
  select * into prefs from app_private.email_digest_preferences where membership_id=m.id;
  activation:=case when not app_private.email_approval_live(a,statement_timestamp()) then 'sender'
    when app_private.email_quota_blocked(a,statement_timestamp()) then 'quota'
    when a.domain_checked_at is null or a.domain_checked_at<=statement_timestamp()-interval '1 day' then 'domain'
    else 'ready' end;
  select case when (state='sending' and lease_until<=statement_timestamp())
    or (state='accepted' and verify_until<=statement_timestamp()) then 'uncertain' else state end
    into health from app_private.email_digest_jobs where membership_id=m.id and generation=prefs.generation
      and state<>'skipped' order by changed_at desc,id limit 1;
  return jsonb_build_object('activation',activation,'enabled',coalesce(address_hash=prefs.email_hash,false),
    'version',coalesce(prefs.version,0),'health',health,'bounced',coalesce(address_hash=prefs.bounced_hash,false));
end;
$$;

create function public.set_email_digest(p_term_id uuid,p_enabled boolean,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.term_memberships; a app_private.email_sender_approvals; prefs app_private.email_digest_preferences;
  address_hash text; receipt jsonb; payload jsonb;
begin
  m:=app_private.request_actor(p_term_id,false);
  if app_private.disposition_replay_required(p_term_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  if p_enabled is null or p_request_id is null then raise exception using errcode='22023',message='command_validation_failed'; end if;
  perform pg_advisory_xact_lock(hashtextextended('email-preference:'||m.id,0));
  select * into prefs from app_private.email_digest_preferences where membership_id=m.id for update;
  payload:=jsonb_build_array(p_term_id,p_enabled,p_expected_version);
  receipt:=app_private.begin_work_command('set_email_digest',p_request_id,payload);
  if receipt is not null then return receipt; end if;
  if coalesce(prefs.version,0) is distinct from p_expected_version
    then raise exception using errcode='40001',message='command_stale_version'; end if;
  if p_enabled then
    select * into a from app_private.email_sender_approvals where term_id=p_term_id;
    address_hash:=encode(sha256(convert_to(app_private.email_current_school_address(m.id),'UTF8')),'hex');
    if address_hash is null or address_hash=prefs.bounced_hash or not app_private.email_approval_live(a,statement_timestamp())
      or app_private.email_quota_blocked(a,statement_timestamp())
      or a.domain_checked_at is null or a.domain_checked_at<=statement_timestamp()-interval '1 day' then
      raise exception using errcode='55000',message='command_dependency_blocked';
    end if;
  end if;
  insert into app_private.email_digest_preferences as p(membership_id,email_hash,opted_at)
    values(m.id,address_hash,case when p_enabled then statement_timestamp() end)
    on conflict(membership_id) do update set email_hash=excluded.email_hash,opted_at=excluded.opted_at,
      generation=gen_random_uuid(),version=p.version+1 returning * into prefs;
  return app_private.notification_receipt(p_term_id,'set_email_digest',p_request_id,payload,
    jsonb_build_object('version',prefs.version,'enabled',p_enabled));
end;
$$;

create function app_private.email_has_digest(prefs app_private.email_digest_preferences,p_day date,p_now timestamptz) returns boolean
language sql stable security definer set search_path='' set timezone='UTC' as $$
  select prefs.opted_at is not null and exists(
    select 1 from public.notifications n
      join public.outbox_jobs j on j.id=n.job_id and j.state='delivered'
      join public.work_items w on w.id=n.target_id and w.id=j.work_item_id and w.kind=n.target_kind
      left join public.notification_rule_reservations r on r.job_id=j.id
      left join public.notification_preferences mode on mode.membership_id=n.recipient_id
    where n.recipient_id=prefs.membership_id and n.read_at is null and n.target_kind in ('task','deliverable')
      and n.created_at>=prefs.opted_at and n.created_at>=(p_day::timestamp at time zone 'Asia/Manila')
      and n.created_at<((p_day+1)::timestamp at time zone 'Asia/Manila') and mode.mode is distinct from 'mute'
      and app_private.notification_pending(w) and app_private.notification_assignee(w)=prefs.membership_id
      and (r.job_id is null or (r.channel='email' and r.mode<>'mute' and r.optional_at<=p_now
        and r.recipient_id=n.recipient_id and r.deadline=coalesce(w.due_on::text,w.due_at::text)))
      and (j.reminder_key is null or j.reminder_key like w.id::text||':'||coalesce(w.due_on::text,w.due_at::text)||':%'));
$$;

-- The public worker entry always supplies the database clock. The private routine also supports isolated schedule tests.
create function app_private.email_dispatch_at(p_term_id uuid,p_action text,p_sender text,p_domain_id uuid,p_now timestamptz,
  p_id uuid,p_lease uuid,p_outcome text,p_provider_id uuid,p_delay integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a app_private.email_sender_approvals; job app_private.email_digest_jobs; prefs app_private.email_digest_preferences;
  local_time timestamp; target_day date; quota_day date; recipient text; state_after text;
begin
  select * into a from app_private.email_sender_approvals where term_id=p_term_id for update;
  if not found or a.sender is distinct from p_sender or a.domain_id is distinct from p_domain_id
    or not app_private.email_approval_live(a,p_now) then return jsonb_build_object('allowed',false,'blocked','sender'); end if;
  if p_action='domain' then
    update app_private.email_sender_approvals set domain_checked_at=case when p_outcome='verified' then p_now end
      where term_id=p_term_id;
    return jsonb_build_object('recorded',true);
  end if;
  if p_action='gate' then return jsonb_build_object('allowed',a.quota_blocked_at is null,
    'reason',case when a.quota_blocked_at is not null then 'quota' end); end if;
  if p_action='check' then
    select * into job from app_private.email_digest_jobs where term_id=p_term_id
      and state in ('accepted','delivered') and provider_id is not null and next_at<=p_now and verify_until>p_now
      and (lease is null or lease_until<=p_now)
      order by next_at,id limit 1 for update skip locked;
    if not found then return null; end if;
    update app_private.email_digest_jobs set lease=gen_random_uuid(),lease_until=p_now+interval '60 seconds'
      where id=job.id returning * into job;
    return jsonb_build_object('id',job.id,'lease',job.lease,'providerId',job.provider_id);
  end if;
  if p_action in ('finish','reconcile') then
    select * into job from app_private.email_digest_jobs where id=p_id and term_id=p_term_id and lease=p_lease
      and lease_until>p_now for update;
    if not found then return jsonb_build_object('recorded',false); end if;
    if p_action='reconcile' and job.state in ('accepted','delivered') and p_outcome in ('pending','delivered','bounced','failed') then
      state_after:=case when p_outcome='pending' then job.state else p_outcome end;
      update app_private.email_digest_jobs set state=state_after,lease=null,lease_until=null,next_at=p_now+interval '6 hours',
        changed_at=case when state_after<>state then p_now else changed_at end where id=job.id;
      if state_after='bounced' then
        update app_private.email_digest_preferences set bounced_hash=job.email_hash,
          email_hash=case when email_hash=job.email_hash then null else email_hash end,
          opted_at=case when email_hash=job.email_hash then null else opted_at end,version=version+1
          where membership_id=job.membership_id;
      end if;
    elsif p_action='finish' and job.state='sending' and p_outcome in ('accepted','failed','retry','quota','uncertain')
      and (p_outcome<>'accepted' or p_provider_id is not null)
      and (p_outcome<>'retry' or p_delay between 1 and 3600) then
      state_after:=case when p_outcome='retry' and job.attempts<4 then 'waiting'
        when p_outcome in ('quota','retry') then 'failed' else p_outcome end;
      update app_private.email_digest_jobs set state=state_after,lease=null,lease_until=null,changed_at=p_now,
        provider_id=case when state_after='accepted' then p_provider_id end,
        verify_until=case when state_after='accepted' then p_now+interval '7 days' end,
        next_at=p_now+case when state_after='accepted' then interval '5 minutes' when state_after='waiting'
          then greatest(p_delay,30*2^(job.attempts-1))*interval '1 second' else interval '0 seconds' end
        where id=job.id;
      if p_outcome='quota' then update app_private.email_sender_approvals set quota_blocked_at=p_now where term_id=p_term_id; end if;
    else
      raise exception using errcode='22023',message='command_validation_failed';
    end if;
    return jsonb_build_object('recorded',true);
  end if;
  if p_action is distinct from 'prepare' then raise exception using errcode='22023',message='command_validation_failed'; end if;
  if app_private.email_quota_blocked(a,p_now) then return jsonb_build_object('blocked','quota'); end if;
  if a.domain_checked_at is null or a.domain_checked_at<=p_now-interval '1 day' then
    return jsonb_build_object('blocked','domain');
  end if;
  update app_private.email_digest_jobs set state='uncertain',lease=null,lease_until=null,changed_at=p_now
    where id in(select id from app_private.email_digest_jobs where term_id=p_term_id and state='sending'
      and lease_until<=p_now order by lease_until limit 24 for update skip locked);
  local_time:=p_now at time zone 'Asia/Manila';
  if local_time::time<time '08:00' or local_time::time>=time '20:00' then return null; end if;
  target_day:=local_time::date-1;
  quota_day:=(p_now at time zone 'UTC')::date;
  select * into job from app_private.email_digest_jobs where term_id=p_term_id and state='waiting'
    and next_at<=p_now order by next_at,id limit 1 for update skip locked;
  if not found then
    select pr.* into prefs from app_private.email_digest_preferences pr join public.term_memberships tm on tm.id=pr.membership_id
      where tm.term_id=p_term_id and pr.email_hash is not null and pr.email_hash is distinct from pr.bounced_hash
        and pr.email_hash=encode(sha256(convert_to(app_private.email_current_school_address(pr.membership_id),'UTF8')),'hex')
        and not exists(select 1 from app_private.email_digest_jobs j where j.membership_id=pr.membership_id and j.digest_day=target_day)
        and app_private.email_has_digest(pr,target_day,p_now)
      order by pr.membership_id limit 1;
    if not found then return null; end if;
    insert into app_private.email_digest_jobs(term_id,membership_id,generation,email_hash,digest_day,next_at)
      values(p_term_id,prefs.membership_id,prefs.generation,prefs.email_hash,target_day,p_now) returning * into job;
  end if;
  select * into prefs from app_private.email_digest_preferences where membership_id=job.membership_id for share;
  recipient:=app_private.email_current_school_address(job.membership_id);
  if prefs.generation is distinct from job.generation or recipient is null or prefs.email_hash is distinct from job.email_hash
    or prefs.email_hash=prefs.bounced_hash or job.digest_day<>target_day
    or job.email_hash is distinct from encode(sha256(convert_to(recipient,'UTF8')),'hex')
    or not app_private.email_has_digest(prefs,target_day,p_now) then
    update app_private.email_digest_jobs set state='skipped',changed_at=p_now where id=job.id;
    return jsonb_build_object('skipped',true);
  end if;
  insert into app_private.email_digest_quota as q(term_id,utc_day,attempts) values(p_term_id,quota_day,1)
    on conflict(term_id,utc_day) do update set attempts=q.attempts+1;
  update app_private.email_digest_jobs set state='sending',lease=gen_random_uuid(),lease_until=p_now+interval '60 seconds',
    attempts=attempts+1,changed_at=p_now where id=job.id returning * into job;
  return jsonb_build_object('id',job.id,'lease',job.lease,'recipient',recipient);
end;
$$;

create function public.email_digest_dispatch(p_term_id uuid,p_action text,p_sender text,p_domain_id uuid,p_id uuid default null,
  p_lease uuid default null,p_outcome text default null,p_provider_id uuid default null,p_delay integer default null)
returns jsonb language sql security definer set search_path='' as $$
  select app_private.email_dispatch_at(p_term_id,p_action,p_sender,p_domain_id,statement_timestamp(),
    p_id,p_lease,p_outcome,p_provider_id,p_delay);
$$;

create function public.read_guest_work(p_term_id uuid,p_page integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare invitation uuid; rows jsonb; more boolean;
begin
  invitation:=app_private.current_guest_invitation(p_term_id);
  if invitation is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  if p_page is null or p_page not between 1 and 10000 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  with visible as materialized(
    select w.id,w.title,w.kind
    from public.work_items w
    where w.term_id=p_term_id and w.archived_at is null and w.kind in ('task','deliverable')
      and exists(select 1 from public.record_grants g where g.work_item_id=w.id and g.term_id=p_term_id
        and g.guest_invitation_id=invitation and g.grant_kind='read' and app_private.work_grant_matches(g))
      and public.can_access_work(w.id,'detail')
    order by w.title,w.id limit 21 offset ((p_page-1)*20)
  )
  select coalesce((select jsonb_agg(to_jsonb(item) order by item.title,item.id)
    from (select * from visible order by title,id limit 20) item),'[]'::jsonb),count(*)>20
    into rows,more from visible;
  perform app_private.record_content_read('read_guest_work',p_term_id,null,jsonb_array_length(rows)>0);
  return jsonb_build_object('items',rows,'hasMore',more);
end;
$$;
insert into public.restricted_read_endpoints(endpoint,argument_types) values('read_guest_work','uuid, integer');

-- Preserve the P52 projection and bring its post-P46 entry point under the existing read audit and restore guard.
alter function public.read_drive_copy(uuid,uuid,uuid,uuid) set schema app_private;
alter function app_private.read_drive_copy(uuid,uuid,uuid,uuid) rename to p46_read_drive_copy;
revoke all on function app_private.p46_read_drive_copy(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
create function public.read_drive_copy(p_term_id uuid,p_work_item_id uuid,p_asset_id uuid,p_destination_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  result:=app_private.p46_read_drive_copy(p_term_id,p_work_item_id,p_asset_id,p_destination_id);
  perform app_private.record_content_read('read_drive_copy',p_term_id,p_work_item_id,
    p_destination_id is not null or jsonb_array_length(coalesce(result->'destinations','[]'::jsonb))>0);
  return result;
end;
$$;
insert into public.restricted_read_endpoints(endpoint,argument_types) values('read_drive_copy','uuid, uuid, uuid, uuid');
revoke all on function public.read_drive_copy(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_drive_copy(uuid,uuid,uuid,uuid) to authenticated;

revoke all on function app_private.email_current_school_address(uuid),
  app_private.email_approval_live(app_private.email_sender_approvals,timestamptz),
  app_private.email_quota_blocked(app_private.email_sender_approvals,timestamptz),
  app_private.email_has_digest(app_private.email_digest_preferences,date,timestamptz),
  app_private.email_dispatch_at(uuid,text,text,uuid,timestamptz,uuid,uuid,text,uuid,integer),
  public.email_digest_dispatch(uuid,text,text,uuid,uuid,uuid,text,uuid,integer),
  public.email_digest_status(uuid),public.set_email_digest(uuid,boolean,integer,uuid),public.read_guest_work(uuid,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.email_digest_dispatch(uuid,text,text,uuid,uuid,uuid,text,uuid,integer) to service_role;
grant execute on function public.email_digest_status(uuid),public.set_email_digest(uuid,boolean,integer,uuid),
  public.read_guest_work(uuid,integer) to authenticated;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,category,'term',keys,
  format('select app_private.disposition_key(%L,%s) target_hash,
    %L category,null::uuid root_id,app_private.retention_is_held($1,%L,null::uuid,null::uuid) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x %s where %s=$1',
    'app_private.'||source,key_expression,category,category,source,joins,term_expression),
  app_private.disposition_structure('app_private.'||source),false
from (values
  ('email_sender_approvals','security',array['term_id'],'array[x.term_id::text]','','x.term_id'),
  ('email_digest_preferences','privacy',array['membership_id'],'array[x.membership_id::text]',
    'join public.term_memberships m on m.id=x.membership_id','m.term_id'),
  ('email_digest_jobs','security',array['id'],'array[x.id::text]','','x.term_id'),
  ('email_digest_quota','security',array['term_id','utc_day'],'array[x.term_id::text,x.utc_day::text]','','x.term_id')
) definitions(source,category,keys,key_expression,joins,term_expression);

commit;
