begin;

create table app_private.telegram_links (
  membership_id uuid primary key references public.term_memberships(id),
  subject_id uuid not null references auth.users(id),
  generation uuid not null default gen_random_uuid(),
  state text not null check(state in ('linked','relink','unlinked')),
  chat_hash text unique check(chat_hash ~ '^[a-f0-9]{64}$'),
  sealed_chat text check(sealed_chat ~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,120}$'),
  linked_at timestamptz not null default statement_timestamp(),
  check((chat_hash is null)=(sealed_chat is null) and (state='linked')=(chat_hash is not null))
);
create table app_private.telegram_attempts (
  membership_id uuid primary key references public.term_memberships(id),
  subject_id uuid not null references auth.users(id),
  start_hash text not null unique check(start_hash ~ '^[a-f0-9]{64}$'),
  confirm_hash text check(confirm_hash ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz not null,
  chat_hash text check(chat_hash ~ '^[a-f0-9]{64}$'),
  sealed_chat text check(sealed_chat ~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,120}$'),
  check((confirm_hash is null)=(chat_hash is null) and (chat_hash is null)=(sealed_chat is null))
);
create index telegram_attempts_expiry on app_private.telegram_attempts(expires_at);
create table app_private.telegram_jobs (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references app_private.telegram_links(membership_id),
  generation uuid not null,
  mode text not null check(mode in ('immediate','digest')),
  digest_day date,
  state text not null default 'waiting' check(state in ('waiting','sending','sent','skipped','relink','failed','uncertain')),
  run_at timestamptz not null,
  lease uuid,
  lease_until timestamptz,
  attempts integer not null default 0 check(attempts between 0 and 4),
  updated_at timestamptz not null default statement_timestamp(),
  check((state='sending')=(lease is not null) and (lease is null)=(lease_until is null)),
  check((mode='digest')=(digest_day is not null)),
  unique(membership_id,digest_day)
);
create index telegram_jobs_ready on app_private.telegram_jobs(run_at,id) where state='waiting';
create index telegram_jobs_in_flight on app_private.telegram_jobs(lease_until,id) where state='sending';
create index telegram_jobs_status on app_private.telegram_jobs(membership_id,generation,updated_at desc);
create table app_private.telegram_job_items (
  notification_id uuid primary key references public.notifications(id),
  job_id uuid not null references app_private.telegram_jobs(id)
);
create index telegram_job_items_job on app_private.telegram_job_items(job_id);

do $$
declare relation text;
begin
  foreach relation in array array['telegram_links','telegram_attempts','telegram_jobs','telegram_job_items'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
  end loop;
end $$;

-- Service calls use the same current core identity and scope requirements, without setting an actor claim.
create function app_private.telegram_member_live(p_membership uuid,p_subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.term_memberships m join public.members person on person.id=m.member_id
    join public.terms t on t.id=m.term_id join public.organizations o on o.id=t.organization_id
    where m.id=p_membership and m.membership_kind='core' and m.status='active' and m.joined_at<=statement_timestamp()
      and m.ends_at>statement_timestamp() and person.account_state='active' and person.auth_user_id=p_subject
      and app_private.is_school_identity(p_subject) and app_private.verified_google_email(p_subject)=person.normalized_email
      and o.state='active' and t.state in ('active','frozen')
      and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
      and exists(select 1 from app_private.effective_role_assignments a
        join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope=a.scope_type
        where a.term_membership_id=m.id and a.term_id=t.id and a.scope_type in ('own','term')
          and p.capability='workspace.read' and app_private.access_assignment_live(a.id))
      and not app_private.disposition_replay_required(t.id));
$$;

create function public.telegram_status(p_term_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare member public.term_memberships; link app_private.telegram_links; attempt app_private.telegram_attempts; latest text;
begin
  member:=app_private.request_actor(p_term_id,false);
  if app_private.disposition_replay_required(p_term_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  select * into link from app_private.telegram_links where membership_id=member.id and subject_id=auth.uid();
  select * into attempt from app_private.telegram_attempts where membership_id=member.id and subject_id=auth.uid();
  select case when state='sending' and lease_until<=statement_timestamp() then 'uncertain'
    when state='waiting' and attempts>0 then 'retry' when state in ('failed','uncertain') then state end
    into latest from app_private.telegram_jobs
    where membership_id=member.id and generation=link.generation order by updated_at desc,id limit 1;
  return jsonb_build_object('state',coalesce(link.state,'unlinked'),
    'attempt',case when attempt.expires_at<=statement_timestamp() then 'expired'
      when attempt.confirm_hash is not null then 'confirm' when attempt.start_hash is not null then 'start' end,
    'issue',latest);
end;
$$;

create function public.telegram_link(p_term_id uuid,p_action text,p_request_id uuid,p_hash text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare member public.term_memberships; link app_private.telegram_links; attempt app_private.telegram_attempts;
  payload jsonb; result jsonb;
begin
  member:=app_private.request_actor(p_term_id,false);
  if not app_private.telegram_member_live(member.id,auth.uid()) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  if p_action is null or p_action not in ('start','confirm','cancel','unlink') or p_request_id is null
    or (p_action in ('cancel','unlink') and p_hash is not null)
    or (p_action in ('start','confirm') and (p_hash is null or p_hash !~ '^[a-f0-9]{64}$')) then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('telegram:'||member.id,0));
  select * into link from app_private.telegram_links where membership_id=member.id;
  payload:=jsonb_build_array(p_term_id,p_action,p_hash);
  result:=app_private.begin_work_command('telegram_link',p_request_id,payload);
  if result is not null then return result; end if;
  if p_action in ('cancel','unlink') then
    delete from app_private.telegram_attempts where membership_id=member.id;
    if p_action='unlink' then
      update app_private.telegram_links set state='unlinked',generation=gen_random_uuid(),chat_hash=null,sealed_chat=null
        where membership_id=member.id and subject_id=auth.uid();
    end if;
    result:=jsonb_build_object('state',case when p_action='cancel' then 'cancelled' else 'unlinked' end);
  else
    if (link.membership_id is not null and (link.state='linked' or link.subject_id<>auth.uid()))
      or not exists(select 1 from public.terms where id=p_term_id and state='active') then
      raise exception using errcode='42501',message='command_permission_denied';
    end if;
    if p_action='start' then
      insert into app_private.telegram_attempts(membership_id,subject_id,start_hash,expires_at)
        values(member.id,auth.uid(),p_hash,statement_timestamp()+interval '8 minutes')
        on conflict(membership_id) do update set subject_id=excluded.subject_id,start_hash=excluded.start_hash,
          expires_at=excluded.expires_at,confirm_hash=null,chat_hash=null,sealed_chat=null;
      result:=jsonb_build_object('state','start');
    else
      select * into attempt from app_private.telegram_attempts where membership_id=member.id for update;
      if not found or attempt.subject_id<>auth.uid() or attempt.expires_at<=statement_timestamp()
        or attempt.confirm_hash is distinct from p_hash then
        raise exception using errcode='40001',message='command_stale_version';
      end if;
      perform pg_advisory_xact_lock(hashtextextended('telegram-chat:'||attempt.chat_hash,0));
      if exists(select 1 from app_private.telegram_links other where other.chat_hash=attempt.chat_hash) then
        raise exception using errcode='40001',message='command_stale_version';
      end if;
      insert into app_private.telegram_links(membership_id,subject_id,state,chat_hash,sealed_chat)
        values(member.id,auth.uid(),'linked',attempt.chat_hash,attempt.sealed_chat)
        on conflict(membership_id) do update set state='linked',generation=gen_random_uuid(),
          linked_at=statement_timestamp(),chat_hash=excluded.chat_hash,sealed_chat=excluded.sealed_chat;
      delete from app_private.telegram_attempts where membership_id=member.id;
      result:=jsonb_build_object('state','linked');
    end if;
  end if;
  return app_private.notification_receipt(p_term_id,'telegram_link',p_request_id,payload,result);
end;
$$;

create function public.telegram_stage(p_action text,p_chat_hash text,p_start_hash text default null,p_confirm_hash text default null,
  p_sealed_chat text default null,p_provider_seconds bigint default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare attempt app_private.telegram_attempts; stopped_at timestamptz;
begin
  if p_chat_hash is null or p_chat_hash !~ '^[a-f0-9]{64}$' then return false; end if;
  if p_action='stop' then
    if p_provider_seconds is null or p_provider_seconds not between 1 and 4102444800 then return false; end if;
    stopped_at:=to_timestamp(p_provider_seconds);
    if stopped_at<statement_timestamp()-interval '1 day' or stopped_at>statement_timestamp()+interval '1 minute'
      then return false; end if;
    update app_private.telegram_links set state='relink',generation=gen_random_uuid(),chat_hash=null,sealed_chat=null
      where chat_hash=p_chat_hash and linked_at<stopped_at+interval '1 second';
    return found;
  end if;
  if p_action='abandon' then
    update app_private.telegram_attempts set expires_at=statement_timestamp(),confirm_hash=null,chat_hash=null,sealed_chat=null
      where start_hash=p_start_hash and confirm_hash=p_confirm_hash and chat_hash=p_chat_hash;
    return found;
  end if;
  if p_action is distinct from 'stage' or p_start_hash is null or p_start_hash !~ '^[a-f0-9]{64}$'
    or p_confirm_hash is null or p_confirm_hash !~ '^[a-f0-9]{64}$' or p_sealed_chat is null
    or p_sealed_chat !~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,120}$' then return false; end if;
  select * into attempt from app_private.telegram_attempts where start_hash=p_start_hash
    and expires_at>statement_timestamp() and confirm_hash is null for update;
  if not found or not app_private.telegram_member_live(attempt.membership_id,attempt.subject_id)
    or exists(select 1 from app_private.telegram_links where chat_hash=p_chat_hash) then return false; end if;
  update app_private.telegram_attempts set confirm_hash=p_confirm_hash,chat_hash=p_chat_hash,sealed_chat=p_sealed_chat
    where membership_id=attempt.membership_id;
  return true;
end;
$$;

-- Reuse P41's exact current assignee and pending-source checks. V1 only mirrors still-unread owned work.
create function app_private.telegram_not_before(p_mode text,p_local_at timestamp) returns timestamptz
language sql stable set search_path='' as $$
  select (case when p_mode='digest' or p_local_at::time>=time '20:00' then p_local_at::date+1+time '08:00'
    when p_local_at::time<time '08:00' then p_local_at::date+time '08:00' else p_local_at end) at time zone 'Asia/Manila';
$$;

create function app_private.telegram_sources(l app_private.telegram_links)
returns table(notification_id uuid,mode text,digest_day date,send_at timestamptz)
language sql stable security definer set search_path='' set timezone='UTC' as $$
  with candidate as (
    select n.id,
      case when pref.mode='mute' or r.mode='mute' then 'mute'
        when pref.mode='digest' or r.mode='digest' then 'digest' else 'immediate' end mode,
      greatest(n.created_at,r.optional_at) at time zone 'Asia/Manila' local_at
    from public.notifications n join public.outbox_jobs j on j.id=n.job_id and j.state='delivered'
    join public.work_items w on w.id=n.target_id and w.id=j.work_item_id and w.kind=n.target_kind
    left join public.notification_rule_reservations r on r.job_id=j.id
    left join public.notification_preferences pref on pref.membership_id=n.recipient_id
    where n.recipient_id=l.membership_id and n.target_kind in ('task','deliverable') and n.read_at is null
      and n.created_at>=greatest(l.linked_at,pref.updated_at) and n.created_at>statement_timestamp()-interval '3 days'
      and app_private.notification_pending(w) and app_private.notification_assignee(w)=l.membership_id
      and (r.job_id is null or (r.channel='telegram' and r.recipient_id=n.recipient_id
        and r.deadline=coalesce(w.due_on::text,w.due_at::text)))
      and (j.reminder_key is null or j.reminder_key like w.id::text||':'||coalesce(w.due_on::text,w.due_at::text)||':%')
  )
  select id,mode,case when mode='digest' then local_at::date end,
    app_private.telegram_not_before(mode,local_at)
  from candidate where mode in ('immediate','digest');
$$;

create function public.telegram_delivery(p_action text,p_id uuid default null,p_lease uuid default null,
  p_outcome text default null,p_delay integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare job app_private.telegram_jobs; link app_private.telegram_links; item record;
  outcome text; changed boolean;
begin
  if p_action='finish' then
    if p_outcome is null or p_outcome not in ('sent','retry','relink','failed','uncertain')
      or (p_outcome='retry' and (p_delay is null or p_delay not between 1 and 3600)) then
      raise exception using errcode='22023',message='command_validation_failed';
    end if;
    select * into job from app_private.telegram_jobs where id=p_id and state='sending'
      and lease=p_lease and lease_until>statement_timestamp() for update;
    if not found then return jsonb_build_object('recorded',false); end if;
    outcome:=case when p_outcome='retry' then case when job.attempts>=4 then 'failed' else 'waiting' end else p_outcome end;
    update app_private.telegram_jobs set state=outcome,lease=null,lease_until=null,updated_at=statement_timestamp(),
      run_at=case when outcome='waiting' then statement_timestamp()+greatest(p_delay,30*2^(job.attempts-1))*interval '1 second'
        else run_at end where id=job.id;
    if outcome='relink' then
      update app_private.telegram_links set state='relink',generation=gen_random_uuid(),chat_hash=null,sealed_chat=null
        where membership_id=job.membership_id and generation=job.generation;
    end if;
    return jsonb_build_object('recorded',true);
  end if;
  if p_action is distinct from 'prepare' then raise exception using errcode='22023',message='command_validation_failed'; end if;
  -- Serialize reservations. An acquired send lease is never reclaimed for another network attempt.
  if not pg_try_advisory_xact_lock(hashtextextended('telegram-dispatch',0)) then return null; end if;
  delete from app_private.telegram_attempts where membership_id in
    (select membership_id from app_private.telegram_attempts where expires_at<=statement_timestamp()
      order by expires_at limit 24 for update skip locked);
  update app_private.telegram_jobs set state='uncertain',lease=null,lease_until=null,updated_at=statement_timestamp()
    where id in(select id from app_private.telegram_jobs where state='sending' and lease_until<=statement_timestamp()
      order by lease_until limit 24 for update skip locked);
  if app_private.telegram_not_before('immediate',statement_timestamp() at time zone 'Asia/Manila')>statement_timestamp()
    then return null; end if;

  select * into job from app_private.telegram_jobs where state='waiting' and run_at<=statement_timestamp()
    order by run_at,id limit 1 for update skip locked;
  if not found then
    select s.*,l.membership_id,l.generation into item from app_private.telegram_links l
      cross join lateral app_private.telegram_sources(l) s
      where l.state='linked' and app_private.telegram_member_live(l.membership_id,l.subject_id)
        and s.send_at<=statement_timestamp()
        and not exists(select 1 from app_private.telegram_job_items i where i.notification_id=s.notification_id)
        and (s.digest_day is null or not exists(select 1 from app_private.telegram_jobs x
          where x.membership_id=l.membership_id and x.digest_day=s.digest_day))
      order by s.send_at,s.notification_id limit 1;
    if not found then return null; end if;
    insert into app_private.telegram_jobs(membership_id,generation,mode,digest_day,run_at)
      values(item.membership_id,item.generation,item.mode,item.digest_day,item.send_at) returning * into job;
    select * into link from app_private.telegram_links where membership_id=job.membership_id for share;
    insert into app_private.telegram_job_items(notification_id,job_id)
      select s.notification_id,job.id from app_private.telegram_sources(link) s
        where s.notification_id=item.notification_id or (s.mode='digest' and s.digest_day=item.digest_day)
      on conflict(notification_id) do nothing;
  else
    select * into link from app_private.telegram_links where membership_id=job.membership_id for share;
  end if;
  changed:=link.state is distinct from 'linked' or link.generation is distinct from job.generation
    or not app_private.telegram_member_live(link.membership_id,link.subject_id)
    or not exists(select 1 from app_private.telegram_job_items i
        join app_private.telegram_sources(link) s on s.notification_id=i.notification_id
        where i.job_id=job.id and s.mode=job.mode and s.send_at<=statement_timestamp());
  if changed then
    update app_private.telegram_jobs set state='skipped',updated_at=statement_timestamp() where id=job.id;
    return jsonb_build_object('skipped',true);
  end if;
  update app_private.telegram_jobs set state='sending',lease=gen_random_uuid(),
    lease_until=statement_timestamp()+interval '60 seconds',attempts=attempts+1,updated_at=statement_timestamp()
    where id=job.id returning * into job;
  return jsonb_build_object('id',job.id,'lease',job.lease,'mode',job.mode,'chatHash',link.chat_hash,'sealedChat',link.sealed_chat);
end;
$$;

revoke all on function app_private.telegram_member_live(uuid,uuid),app_private.telegram_sources(app_private.telegram_links),
  app_private.telegram_not_before(text,timestamp),
  public.telegram_status(uuid),public.telegram_link(uuid,text,uuid,text),
  public.telegram_stage(text,text,text,text,text,bigint),public.telegram_delivery(text,uuid,uuid,text,integer)
  from public,anon,authenticated,service_role;
grant execute on function public.telegram_status(uuid),public.telegram_link(uuid,text,uuid,text) to authenticated;
grant execute on function public.telegram_stage(text,text,text,text,text,bigint),
  public.telegram_delivery(text,uuid,uuid,text,integer) to service_role;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,category,'term',array[id_column],
  format('select app_private.disposition_key(%L,array[x.%I::text]) target_hash,
    %L category,null::uuid root_id,app_private.retention_is_held($1,%L,null::uuid,null::uuid) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x %s
    join public.term_memberships m on m.id=%s where m.term_id=$1',
    'app_private.'||source,id_column,category,category,source,joins,membership),
  app_private.disposition_structure('app_private.'||source),false
from (values
  ('telegram_links','privacy','membership_id','','x.membership_id'),
  ('telegram_attempts','privacy','membership_id','','x.membership_id'),
  ('telegram_jobs','security','id','','x.membership_id'),
  ('telegram_job_items','security','notification_id','join app_private.telegram_jobs j on j.id=x.job_id','j.membership_id')
) definitions(source,category,id_column,joins,membership);

commit;
