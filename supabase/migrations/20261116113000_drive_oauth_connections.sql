begin;

create table app_private.drive_oauth_connections (
  membership_id uuid primary key references public.term_memberships(id) on delete cascade,
  subject_id uuid not null references auth.users(id) on delete cascade,
  generation uuid not null default gen_random_uuid(),
  state_hash text check (state_hash ~ '^[a-f0-9]{64}$'),
  attempt_ends_at timestamptz,
  sealed_verifier text check (length(sealed_verifier)<=6017 and sealed_verifier ~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,}$'),
  sealed_refresh text check (length(sealed_refresh)<=6017 and sealed_refresh ~ '^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,}$'),
  revoking boolean not null default false,
  check ((state_hash is null) = (attempt_ends_at is null)),
  check (sealed_verifier is null or state_hash is not null),
  check (sealed_refresh is null or state_hash is null),
  check (not revoking or sealed_refresh is not null)
);
alter table app_private.drive_oauth_connections enable row level security;
alter table app_private.drive_oauth_connections force row level security;
revoke all on app_private.drive_oauth_connections from public, anon, authenticated, service_role;

create function public.drive_oauth_scope(p_term_id uuid, p_work_item_id uuid default null)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare membership public.term_memberships;
begin
  membership := app_private.request_actor(p_term_id, p_work_item_id is not null);
  if p_work_item_id is not null and not exists (
    select 1 from public.work_items work
    where work.id = p_work_item_id and work.term_id = p_term_id
      and work.kind in ('task','deliverable') and work.archived_at is null
      and public.can_access_work(work.id,'edit')
  ) then
    raise exception using errcode='42501', message='command_permission_denied';
  end if;
  return membership.id;
end;
$$;
revoke all on function public.drive_oauth_scope(uuid,uuid) from public, anon, authenticated, service_role;
grant execute on function public.drive_oauth_scope(uuid,uuid) to authenticated;

create function public.drive_oauth_store(
  p_membership_id uuid, p_subject_id uuid, p_action text, p_guard text default null, p_sealed text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare connection app_private.drive_oauth_connections;
begin
  if not exists (
    select 1 from public.term_memberships membership join public.members member on member.id=membership.member_id
    where membership.id=p_membership_id and member.auth_user_id=p_subject_id
      and membership.membership_kind='core' and membership.status='active' and member.account_state='active'
      and membership.joined_at<=statement_timestamp() and membership.ends_at>statement_timestamp()
  ) then
    raise exception using errcode='42501', message='command_permission_denied';
  end if;

  if p_action='start' then
    if p_guard is null or p_sealed is null then
      raise exception using errcode='22023', message='command_validation_failed';
    end if;
    insert into app_private.drive_oauth_connections as existing(membership_id,subject_id,state_hash,sealed_verifier,attempt_ends_at)
    values(p_membership_id,p_subject_id,p_guard,p_sealed,statement_timestamp()+interval '10 minutes')
    on conflict (membership_id) do update set
      state_hash=excluded.state_hash, sealed_verifier=excluded.sealed_verifier, attempt_ends_at=excluded.attempt_ends_at
    where existing.subject_id=p_subject_id and existing.sealed_refresh is null
    returning * into connection;
    if not found then raise exception using errcode='40001', message='command_stale_version'; end if;
    return jsonb_build_object('state','awaiting_consent');
  end if;

  select * into connection from app_private.drive_oauth_connections
    where membership_id=p_membership_id and subject_id=p_subject_id for update;

  if p_action='status' then
    return jsonb_build_object('state',case when connection.revoking then 'revocation_pending'
      when connection.sealed_refresh is not null then 'authorized'
      when connection.attempt_ends_at>statement_timestamp() then 'awaiting_consent'
      else 'disconnected' end);
  end if;

  if p_action='picker' then
    if connection.sealed_refresh is null or connection.revoking then
      return jsonb_build_object('state',case when connection.revoking then 'revocation_pending' else 'disconnected' end);
    end if;
    return jsonb_build_object('state','authorized','sealed',connection.sealed_refresh,'generation',connection.generation);
  end if;

  if p_action='expire' then
    delete from app_private.drive_oauth_connections where membership_id=p_membership_id
      and subject_id=p_subject_id and not revoking and generation::text=p_guard and sealed_refresh is not null;
    return jsonb_build_object('state','disconnected');
  end if;

  if p_action in ('claim','finish') then
    if p_guard is null or connection.state_hash is distinct from p_guard
      or connection.attempt_ends_at<=statement_timestamp()
      or (p_action='claim') is distinct from (connection.sealed_verifier is not null) then
      raise exception using errcode='40001', message='command_stale_version';
    end if;
    if p_action='claim' then
      update app_private.drive_oauth_connections set sealed_verifier=null where membership_id=p_membership_id;
      return jsonb_build_object('state','awaiting_consent','sealed',connection.sealed_verifier);
    end if;
    if p_sealed is null then raise exception using errcode='22023', message='command_validation_failed'; end if;
    update app_private.drive_oauth_connections set state_hash=null, attempt_ends_at=null,
      sealed_refresh=p_sealed, generation=gen_random_uuid() where membership_id=p_membership_id;
    return jsonb_build_object('state','authorized');
  end if;

  if p_action='cancel' then
    delete from app_private.drive_oauth_connections where membership_id=p_membership_id
      and subject_id=p_subject_id and state_hash=p_guard and sealed_refresh is null;
    if not found then raise exception using errcode='40001', message='command_stale_version'; end if;
    return jsonb_build_object('state','disconnected');
  end if;

  if p_action='disconnect' then
    if connection.membership_id is null then return jsonb_build_object('state','disconnected'); end if;
    if connection.sealed_refresh is null then
      delete from app_private.drive_oauth_connections where membership_id=p_membership_id;
      return jsonb_build_object('state','disconnected');
    end if;
    update app_private.drive_oauth_connections set revoking=true where membership_id=p_membership_id;
    return jsonb_build_object('state','revocation_pending','sealed',connection.sealed_refresh,'generation',connection.generation);
  end if;

  if p_action='revoked' then
    delete from app_private.drive_oauth_connections where membership_id=p_membership_id
      and subject_id=p_subject_id and revoking and generation::text=p_guard;
    if not found and connection.membership_id is not null then
      raise exception using errcode='40001', message='command_stale_version';
    end if;
    return jsonb_build_object('state','disconnected');
  end if;

  raise exception using errcode='22023', message='command_validation_failed';
end;
$$;
revoke all on function public.drive_oauth_store(uuid,uuid,text,text,text) from public, anon, authenticated, service_role;
grant execute on function public.drive_oauth_store(uuid,uuid,text,text,text) to service_role;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
values('app_private.drive_oauth_connections','privacy','term',array['membership_id'],
  'select app_private.disposition_key(''app_private.drive_oauth_connections'',array[d.membership_id::text]) target_hash,
    ''privacy'' category,null::uuid root_id,app_private.retention_is_held($1,''privacy'',null::uuid,null::uuid) held,
    encode(sha256(convert_to(to_jsonb(d)::text,''UTF8'')),''hex'') state_hash
    from app_private.drive_oauth_connections d join public.term_memberships m on m.id=d.membership_id where m.term_id=$1',
  app_private.disposition_structure('app_private.drive_oauth_connections'),false);

commit;
