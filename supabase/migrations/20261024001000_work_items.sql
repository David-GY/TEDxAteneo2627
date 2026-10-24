begin;

alter table public.term_memberships add constraint term_memberships_member_scope_key unique(organization_id,term_id,member_id);
alter table public.guest_invitations add constraint guest_invitations_scope_key unique(organization_id,term_id,id);

create table public.status_definitions (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, term_id uuid not null,
  resource_kind text not null check(resource_kind in ('deliverable','task','request','announcement')),
  stable_key text not null check(stable_key ~ '^[a-z][a-z0-9_]{0,59}$'),
  semantic_category text not null check(semantic_category in ('draft','active','needs_revision','approved','completed','rejected','cancelled')),
  label text not null check(length(btrim(label)) between 1 and 120),
  unique(organization_id,term_id,id,resource_kind), unique(term_id,resource_kind,stable_key),
  foreign key(organization_id,term_id) references public.terms(organization_id,id)
);
create table public.work_items (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, term_id uuid not null,
  kind text not null check(kind in ('deliverable','task','request','announcement')),
  title text not null check(length(btrim(title)) between 1 and 240),
  safe_summary text not null default '' check(length(safe_summary)<=2000),
  classification text not null check(classification in ('ordinary','restricted')),
  owner_member_id uuid not null, owner_display_name text not null check(length(owner_display_name) between 1 and 200), lead_unit_id uuid, status_id uuid not null,
  parent_work_item_id uuid,
  due_at timestamptz, due_on date, original_due_at timestamptz, original_due_on date,
  archived_at timestamptz,
  unique(organization_id,term_id,id), unique(organization_id,term_id,id,kind),
  foreign key(organization_id,term_id) references public.terms(organization_id,id),
  foreign key(organization_id,term_id,owner_member_id) references public.term_memberships(organization_id,term_id,member_id),
  foreign key(organization_id,term_id,lead_unit_id) references public.org_units(organization_id,term_id,id),
  foreign key(organization_id,term_id,status_id,kind) references public.status_definitions(organization_id,term_id,id,resource_kind),
  foreign key(organization_id,term_id,parent_work_item_id) references public.work_items(organization_id,term_id,id),
  check(parent_work_item_id is distinct from id),
  check(num_nonnulls(due_at,due_on)<=1 and num_nonnulls(original_due_at,original_due_on)<=1)
);
create index work_items_owner on public.work_items(organization_id,term_id,owner_member_id);
create index work_items_unit on public.work_items(organization_id,term_id,lead_unit_id);
create index work_items_parent on public.work_items(organization_id,term_id,parent_work_item_id);
create index work_items_status on public.work_items(organization_id,term_id,status_id,kind);

-- Fixed typed children, deliberately no EAV payload or workflow/finance fields.
do $$ declare child text; child_kind text; begin
  for child,child_kind in select * from (values ('deliverables','deliverable'),('tasks','task'),('requests','request'),('announcements','announcement')) v(t,k) loop
    execute format('create table public.%I (
      work_item_id uuid primary key, organization_id uuid not null, term_id uuid not null,
      kind text not null default %L check(kind=%L),
      body text not null default '''' check(length(body)<=20000),
      foreign key(organization_id,term_id,work_item_id,kind) references public.work_items(organization_id,term_id,id,kind)
    )',child,child_kind,child_kind);
  end loop;
end $$;

create table public.record_grants (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, term_id uuid not null,
  work_item_id uuid not null, member_id uuid, unit_id uuid, guest_invitation_id uuid,
  grant_kind text not null check(grant_kind in ('read','edit')),
  starts_at timestamptz not null default statement_timestamp(), expires_at timestamptz not null,
  revoked_at timestamptz, grantor_id uuid not null,
  check(num_nonnulls(member_id,unit_id,guest_invitation_id)=1), check(starts_at<expires_at),
  check(guest_invitation_id is null or grant_kind='read'),
  foreign key(organization_id,term_id,work_item_id) references public.work_items(organization_id,term_id,id),
  foreign key(organization_id,term_id,member_id) references public.term_memberships(organization_id,term_id,member_id),
  foreign key(organization_id,term_id,unit_id) references public.org_units(organization_id,term_id,id),
  foreign key(organization_id,term_id,guest_invitation_id) references public.guest_invitations(organization_id,term_id,id),
  foreign key(organization_id,term_id,grantor_id) references public.term_memberships(organization_id,term_id,id)
);
create unique index record_grants_member_unique on public.record_grants(work_item_id,member_id,grant_kind) where member_id is not null and revoked_at is null;
create unique index record_grants_unit_unique on public.record_grants(work_item_id,unit_id,grant_kind) where unit_id is not null and revoked_at is null;
create unique index record_grants_guest_unique on public.record_grants(work_item_id,guest_invitation_id,grant_kind) where guest_invitation_id is not null and revoked_at is null;
create index record_grants_member on public.record_grants(organization_id,term_id,member_id);
create index record_grants_unit on public.record_grants(organization_id,term_id,unit_id);
create index record_grants_guest on public.record_grants(organization_id,term_id,guest_invitation_id);
create index record_grants_grantor on public.record_grants(organization_id,term_id,grantor_id);

alter table public.role_assignments add column work_id uuid;
alter table public.role_assignments add foreign key(organization_id,term_id,work_id) references public.work_items(organization_id,term_id,id);
alter table public.role_assignments drop constraint role_assignments_scope_type_check;
alter table public.role_assignments add check(scope_type in ('own','unit','term','work'));
alter table public.role_assignments add check((scope_type='work')=(work_id is not null));
create index role_assignments_work on public.role_assignments(organization_id,term_id,work_id);
alter table public.role_permissions drop constraint role_permissions_allowed_scope_check;
alter table public.role_permissions add check(allowed_scope in ('own','unit','term','work'));
alter table public.role_permissions drop constraint role_permissions_check;
alter table public.role_permissions add check(
  (capability='profile.edit_own' and allowed_scope='own') or
  (capability in ('committee.manage','department.review','finance.review','feedback.review') and allowed_scope='unit') or
  (capability in ('workspace.read','directory.read','reports.view','admin.configure','roles.manage') and allowed_scope='term') or
  (capability='mentoring.view' and allowed_scope='own') or
  (capability in ('workspace.read','committee.manage') and allowed_scope='work')
);

create table public.idempotency_keys (
  actor_id uuid not null references auth.users(id), command text not null, client_key uuid not null,
  organization_id uuid not null, term_id uuid not null,
  payload_hash text not null check(length(payload_hash)=64), result_reference jsonb not null,
  created_at timestamptz not null default statement_timestamp(), expires_at timestamptz,
  primary key(actor_id,command,client_key),
  foreign key(organization_id,term_id) references public.terms(organization_id,id)
);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, term_id uuid not null,
  actor_id uuid not null references auth.users(id), actor_display_name text not null,
  action text not null, work_item_id uuid not null, revision integer not null check(revision>0),
  occurred_at timestamptz not null default statement_timestamp(), request_id uuid not null,
  redacted_diff jsonb not null,
  unique(actor_id,action,request_id),
  foreign key(organization_id,term_id,work_item_id) references public.work_items(organization_id,term_id,id)
);
create index audit_events_work on public.audit_events(organization_id,term_id,work_item_id);
create index audit_events_actor on public.audit_events(actor_id);
create table public.outbox_jobs (
  id uuid primary key default gen_random_uuid(), event_id uuid not null unique references public.audit_events(id),
  work_item_id uuid not null references public.work_items(id), event_type text not null,
  payload jsonb not null, state text not null default 'pending' check(state in ('pending','claimed','delivered','failed')),
  attempts integer not null default 0 check(attempts>=0), next_at timestamptz not null default statement_timestamp()
);
create index outbox_jobs_pending on public.outbox_jobs(next_at,id) where state='pending';
create index outbox_jobs_work on public.outbox_jobs(work_item_id);

do $$ declare t text; begin
  foreach t in array array['status_definitions','work_items','deliverables','tasks','requests','announcements','record_grants','outbox_jobs'] loop
    execute format('alter table public.%I add column created_at timestamptz not null default statement_timestamp(),
      add column created_by uuid references auth.users(id), add column updated_at timestamptz not null default statement_timestamp(),
      add column updated_by uuid references auth.users(id),add column version integer not null default 1 check(version>0)',t);
    execute format('create trigger stamp_work_row before insert or update on public.%I for each row execute function public.stamp_identity_row()',t);
    execute format('create index %I on public.%I(created_by)',t||'_created_by_idx',t);
    execute format('create index %I on public.%I(updated_by)',t||'_updated_by_idx',t);
  end loop;
  foreach t in array array['status_definitions','work_items','deliverables','tasks','requests','announcements','record_grants','audit_events','idempotency_keys','outbox_jobs'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('alter table public.%I force row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  end loop;
end $$;

create function app_private.check_work_child() returns trigger language plpgsql security definer set search_path='' as $$
declare item uuid; row public.work_items; n integer; begin
  if tg_table_name='work_items' then item:=coalesce(new.id,old.id); else item:=coalesce(new.work_item_id,old.work_item_id); end if;
  select * into row from public.work_items where id=item;
  if not found then return null; end if;
  select (select count(*) from public.deliverables where work_item_id=item)+(select count(*) from public.tasks where work_item_id=item)
    +(select count(*) from public.requests where work_item_id=item)+(select count(*) from public.announcements where work_item_id=item) into n;
  if n<>1 then raise exception using errcode='23514',message='work_typed_child_required'; end if;
  return null;
end $$;
do $$ declare t text; begin
  foreach t in array array['work_items','deliverables','tasks','requests','announcements'] loop
    execute format('create constraint trigger work_child_required after insert or update or delete on public.%I
      deferrable initially deferred for each row execute function app_private.check_work_child()',t);
  end loop;
end $$;
create function app_private.protect_work_invariants() returns trigger language plpgsql set search_path='' as $$ begin
  if tg_table_name='audit_events' or tg_table_name='idempotency_keys' then
    raise exception using errcode='42501',message='work_history_immutable';
  elsif tg_table_name='status_definitions' then
    if (new.organization_id,new.term_id,new.resource_kind,new.stable_key,new.semantic_category)
      is distinct from (old.organization_id,old.term_id,old.resource_kind,old.stable_key,old.semantic_category) then
      raise exception using errcode='42501',message='work_status_semantics_immutable'; end if;
  elsif tg_table_name='work_items' then
    if (new.organization_id,new.term_id,new.kind,new.classification,new.parent_work_item_id,new.original_due_at,new.original_due_on)
      is distinct from (old.organization_id,old.term_id,old.kind,old.classification,old.parent_work_item_id,old.original_due_at,old.original_due_on) then
      raise exception using errcode='42501',message='work_identity_immutable'; end if;
  elsif tg_table_name in ('deliverables','tasks','requests','announcements') then
    if (new.work_item_id,new.organization_id,new.term_id,new.kind) is distinct from (old.work_item_id,old.organization_id,old.term_id,old.kind) then
      raise exception using errcode='42501',message='work_child_identity_immutable'; end if;
  end if;
  return new;
end $$;
create trigger audit_immutable before update or delete on public.audit_events for each row execute function app_private.protect_work_invariants();
create trigger idempotency_immutable before update or delete on public.idempotency_keys for each row execute function app_private.protect_work_invariants();
create trigger status_semantics_immutable before update on public.status_definitions for each row execute function app_private.protect_work_invariants();
create trigger work_identity_immutable before update on public.work_items for each row execute function app_private.protect_work_invariants();
do $$ declare t text; begin
  foreach t in array array['deliverables','tasks','requests','announcements'] loop
    execute format('create trigger work_child_identity_immutable before update on public.%I for each row execute function app_private.protect_work_invariants()',t);
  end loop;
end $$;

create function app_private.work_grant_matches(g public.record_grants) returns boolean
language sql stable set search_path='' as $$
  select g.revoked_at is null and g.starts_at<=statement_timestamp() and g.expires_at>statement_timestamp() and (
    (g.member_id is not null and exists(select 1 from public.term_memberships tm
      where tm.id=public.current_term_membership(g.term_id) and tm.member_id=g.member_id)) or
    (g.unit_id is not null and exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id
      where um.term_membership_id=public.current_term_membership(g.term_id) and um.unit_id=g.unit_id
        and um.status='active' and u.archived_at is null and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())) or
    (g.guest_invitation_id is not null and exists(select 1 from public.guest_invitations i
      where i.id=g.guest_invitation_id and i.redeemed_by=auth.uid() and i.email=app_private.verified_google_email(auth.uid())
        and i.revoked_at is null and i.expires_at>statement_timestamp() and g.expires_at<=i.expires_at
        and app_private.active_guest_sponsor(i.sponsor_id)))
  )
$$;
create function public.has_work_capability(p_work_item_id uuid,p_capability text) returns boolean
language sql stable security definer set search_path='' as $$
  select p_capability in ('workspace.read','committee.manage') and exists(
    select 1 from public.work_items w join public.role_assignments a on a.work_id=w.id
    join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope='work' and p.capability=p_capability
    join public.roles r on r.id=a.role_id and r.state='active'
    where w.id=p_work_item_id and a.scope_type='work' and a.term_membership_id=public.current_term_membership(w.term_id)
      and a.status='active' and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp())
$$;
create function public.can_access_work(p_work_item_id uuid,p_level text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare w public.work_items; member uuid; begin
  if p_level not in ('summary','detail','edit','owner') or p_level is null then return false; end if;
  select * into w from public.work_items where id=p_work_item_id;
  if not found then return false; end if;
  select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id);
  if member=w.owner_member_id then return true; end if;
  if p_level='owner' then return false; end if;
  if p_level='summary' and w.classification='ordinary' and public.has_capability(w.term_id,'workspace.read') then return true; end if;
  if public.has_work_capability(w.id,'committee.manage') then return true; end if;
  if p_level<>'edit' and public.has_work_capability(w.id,'workspace.read') then return true; end if;
  return exists(select 1 from public.record_grants g where g.work_item_id=w.id and app_private.work_grant_matches(g)
    and (p_level<>'edit' or (member is not null and g.grant_kind='edit')));
end $$;
create function public.can_read_work_grant(p_grant_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.record_grants g where g.id=p_grant_id
    and public.can_access_work(g.work_item_id,'detail')
    and (public.can_access_work(g.work_item_id,'owner') or app_private.work_grant_matches(g)))
$$;
create function public.read_work_parent(p_work_item_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',parent.id,'kind',parent.kind,'title',parent.title,'safeSummary',parent.safe_summary,'version',parent.version)
  from public.work_items child join public.work_items parent on parent.id=child.parent_work_item_id
  where child.id=p_work_item_id and public.can_access_work(child.id,'detail') and public.can_access_work(parent.id,'summary')
$$;
revoke all on function app_private.work_grant_matches(public.record_grants),app_private.check_work_child(),app_private.protect_work_invariants(),
  public.has_work_capability(uuid,text),public.can_access_work(uuid,text),public.can_read_work_grant(uuid),public.read_work_parent(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.has_work_capability(uuid,text),public.can_access_work(uuid,text),public.can_read_work_grant(uuid),public.read_work_parent(uuid) to authenticated;
grant select(work_id) on public.role_assignments to authenticated;
grant select on public.status_definitions to authenticated;
create policy work_status_read on public.status_definitions for select to authenticated using(
  public.current_term_membership(term_id) is not null or exists(select 1 from public.work_items w where w.status_id=status_definitions.id and public.can_access_work(w.id,'summary'))
);
-- Parent IDs and detail fields are deliberately absent from the exposed summary columns.
grant select(id,organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,status_id,
  due_at,due_on,original_due_at,original_due_on,archived_at,created_at,created_by,updated_at,updated_by,version) on public.work_items to authenticated;
create policy work_summary_read on public.work_items for select to authenticated using(public.can_access_work(id,'summary'));
do $$ declare t text; begin
  foreach t in array array['deliverables','tasks','requests','announcements'] loop
    execute format('grant select on public.%I to authenticated',t);
    execute format('create policy work_detail_read on public.%I for select to authenticated using(public.can_access_work(work_item_id,''detail''))',t);
  end loop;
end $$;
grant select on public.record_grants to authenticated;
create policy work_grant_read on public.record_grants for select to authenticated using(public.can_read_work_grant(id));
grant select on public.audit_events to authenticated;
create policy work_audit_read on public.audit_events for select to authenticated using(public.can_access_work(work_item_id,'detail'));

create function app_private.begin_work_command(p_command text,p_key uuid,p_payload jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare previous public.idempotency_keys; fingerprint text; begin
  if auth.uid() is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  if p_key is null then raise exception using errcode='22023',message='command_validation_failed'; end if;
  -- Serialize identical first requests without locking unrelated records or all actors.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_command||p_key::text,0));
  fingerprint:=encode(sha256(convert_to(p_payload::text,'UTF8')),'hex');
  select * into previous from public.idempotency_keys where actor_id=auth.uid() and command=p_command and client_key=p_key;
  if found then
    if previous.payload_hash<>fingerprint then raise exception using errcode='22023',message='command_idempotency_conflict'; end if;
    return previous.result_reference;
  end if;
  return null;
end $$;
create function app_private.finish_work_command(w public.work_items,p_command text,p_key uuid,p_payload jsonb,p_result jsonb,p_fields jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare event uuid; name text; begin
  select m.display_name into name from public.members m join public.term_memberships tm on tm.member_id=m.id
    where tm.id=public.current_term_membership(w.term_id);
  if name is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)
  values(auth.uid(),p_command,p_key,w.organization_id,w.term_id,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),p_result);
  insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)
  values(w.organization_id,w.term_id,auth.uid(),name,p_command,w.id,w.version,p_key,jsonb_build_object('fields',p_fields)) returning id into event;
  insert into public.outbox_jobs(event_id,work_item_id,event_type,payload)
  values(event,w.id,p_command,jsonb_build_object('eventId',event,'workItemId',w.id,'version',w.version));
  return p_result;
end $$;
create function app_private.require_work_draft(w public.work_items) returns void
language plpgsql set search_path='' as $$ begin
  if not exists(select 1 from public.terms where id=w.term_id and state='active') or w.archived_at is not null then
    raise exception using errcode='42501',message='command_permission_denied'; end if;
  if not exists(select 1 from public.status_definitions s where s.id=w.status_id and s.semantic_category='draft') then
    raise exception using errcode='55000',message='command_dependency_blocked'; end if;
end $$;

create function public.create_work_item(p_term_id uuid,p_kind text,p_title text,p_safe_summary text,p_body text,
  p_classification text,p_lead_unit_id uuid default null,p_parent_id uuid default null,p_expected_parent_version integer default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare tm public.term_memberships; w public.work_items; parent public.work_items; status uuid; result jsonb; payload jsonb; child text; name text;
begin
  select * into tm from public.term_memberships where id=public.current_term_membership(p_term_id);
  if not found or not public.has_capability(p_term_id,'workspace.read') or not exists(select 1 from public.terms where id=p_term_id and state='active') then
    raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_term_id,p_kind,p_title,p_safe_summary,p_body,p_classification,p_lead_unit_id,p_parent_id,p_expected_parent_version);
  result:=app_private.begin_work_command('create_work_item',p_request_id,payload);
  if result is not null then
    if not public.can_access_work((result->>'workItemId')::uuid,'detail') then raise exception using errcode='42501',message='command_permission_denied'; end if;
    return result;
  end if;
  if p_kind is null or p_kind not in ('deliverable','task','request','announcement') or p_title is null or length(btrim(p_title)) not between 1 and 240
    or p_safe_summary is null or length(p_safe_summary)>2000 or p_body is null or length(p_body)>20000
    or p_classification is null or p_classification not in ('ordinary','restricted')
    or (p_parent_id is null and p_expected_parent_version is not null) then
    raise exception using errcode='22023',message='command_validation_failed'; end if;
  if p_lead_unit_id is not null and not exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id
    where um.term_membership_id=tm.id and um.unit_id=p_lead_unit_id and um.term_id=p_term_id and um.status='active' and u.archived_at is null
      and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()) then
    raise exception using errcode='42501',message='command_permission_denied'; end if;
  if p_parent_id is not null then
    select * into parent from public.work_items where id=p_parent_id for update;
    if not found or parent.term_id<>p_term_id or not public.can_access_work(parent.id,'edit') then
      raise exception using errcode='42501',message='command_permission_denied'; end if;
    perform app_private.require_work_draft(parent);
    if parent.version is distinct from p_expected_parent_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  end if;
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)
    values(tm.organization_id,p_term_id,p_kind,'draft','draft','Draft') on conflict(term_id,resource_kind,stable_key) do nothing;
  select id into status from public.status_definitions where term_id=p_term_id and resource_kind=p_kind and stable_key='draft' and semantic_category='draft';
  if status is null then raise exception using errcode='55000',message='command_dependency_blocked'; end if;
  select display_name into name from public.members where id=tm.member_id;
  insert into public.work_items(organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,status_id,parent_work_item_id)
    values(tm.organization_id,p_term_id,p_kind,btrim(p_title),p_safe_summary,p_classification,tm.member_id,name,p_lead_unit_id,status,p_parent_id) returning * into w;
  child:=case p_kind when 'deliverable' then 'deliverables' when 'task' then 'tasks' when 'request' then 'requests' when 'announcement' then 'announcements' end;
  execute format('insert into public.%I(work_item_id,organization_id,term_id,body) values($1,$2,$3,$4)',child) using w.id,w.organization_id,w.term_id,p_body;
  insert into public.record_grants(organization_id,term_id,work_item_id,member_id,grant_kind,expires_at,grantor_id)
    values(w.organization_id,w.term_id,w.id,tm.member_id,'edit',tm.ends_at,tm.id);
  return app_private.finish_work_command(w,'create_work_item',p_request_id,payload,jsonb_build_object('workItemId',w.id,'kind',w.kind,'version',w.version),'["created"]');
end $$;
create function public.update_work_item(p_work_item_id uuid,p_title text,p_safe_summary text,p_body text,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.work_items; result jsonb; payload jsonb; child text; begin
  if not public.can_access_work(p_work_item_id,'edit') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_work_item_id,p_title,p_safe_summary,p_body,p_expected_version);
  result:=app_private.begin_work_command('update_work_item',p_request_id,payload);
  select * into w from public.work_items where id=p_work_item_id for update;
  if not found or not public.can_access_work(w.id,'edit') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  perform app_private.require_work_draft(w);
  if result is not null then return result; end if;
  if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if p_title is null or length(btrim(p_title)) not between 1 and 240 or p_safe_summary is null or length(p_safe_summary)>2000 or p_body is null or length(p_body)>20000 then
    raise exception using errcode='22023',message='command_validation_failed'; end if;
  update public.work_items set title=btrim(p_title),safe_summary=p_safe_summary where id=w.id returning * into w;
  child:=case w.kind when 'deliverable' then 'deliverables' when 'task' then 'tasks' when 'request' then 'requests' when 'announcement' then 'announcements' end;
  execute format('update public.%I set body=$1 where work_item_id=$2',child) using p_body,w.id;
  return app_private.finish_work_command(w,'update_work_item',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version),'["title","safe_summary","body"]');
end $$;
create function public.grant_work_access(p_work_item_id uuid,p_member_id uuid default null,p_unit_id uuid default null,p_guest_invitation_id uuid default null,
  p_grant_kind text default 'read',p_expires_at timestamptz default null,p_expected_version integer default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.work_items; tm public.term_memberships; invitation public.guest_invitations; grant_id uuid; result jsonb; payload jsonb;
begin
  if not public.can_access_work(p_work_item_id,'owner') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_work_item_id,p_member_id,p_unit_id,p_guest_invitation_id,p_grant_kind,p_expires_at at time zone 'UTC',p_expected_version);
  result:=app_private.begin_work_command('grant_work_access',p_request_id,payload);
  select * into w from public.work_items where id=p_work_item_id for update;
  if not found or not public.can_access_work(w.id,'owner') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  perform app_private.require_work_draft(w);
  if result is not null then return result; end if;
  if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if num_nonnulls(p_member_id,p_unit_id,p_guest_invitation_id)<>1 or p_grant_kind is null or p_grant_kind not in ('read','edit') or p_expires_at is null or p_expires_at<=statement_timestamp()
    or p_expires_at>(select (closes_on+1)::timestamp at time zone 'Asia/Manila' from public.terms where id=w.term_id) then
    raise exception using errcode='22023',message='command_validation_failed'; end if;
  select * into tm from public.term_memberships where id=public.current_term_membership(w.term_id);
  if p_member_id is not null and not exists(select 1 from public.term_memberships target join public.members m on m.id=target.member_id
    where target.term_id=w.term_id and target.member_id=p_member_id and target.status='active' and target.membership_kind='core'
      and m.account_state='active' and target.joined_at<=statement_timestamp() and target.ends_at>statement_timestamp()) then
    raise exception using errcode='22023',message='command_validation_failed'; end if;
  if p_unit_id is not null and not exists(select 1 from public.org_units where id=p_unit_id and term_id=w.term_id and archived_at is null) then
    raise exception using errcode='22023',message='command_validation_failed'; end if;
  if p_guest_invitation_id is not null then
    select * into invitation from public.guest_invitations where id=p_guest_invitation_id;
    if not found or invitation.term_id<>w.term_id or invitation.sponsor_id<>tm.id or not app_private.active_guest_sponsor(tm.id)
      or invitation.revoked_at is not null or invitation.expires_at<=statement_timestamp() or p_expires_at>invitation.expires_at then
      raise exception using errcode='42501',message='command_permission_denied'; end if;
    if p_grant_kind<>'read' then raise exception using errcode='55000',message='command_dependency_blocked'; end if;
  end if;
  insert into public.record_grants(organization_id,term_id,work_item_id,member_id,unit_id,guest_invitation_id,grant_kind,expires_at,grantor_id)
    values(w.organization_id,w.term_id,w.id,p_member_id,p_unit_id,p_guest_invitation_id,p_grant_kind,p_expires_at,tm.id) returning id into grant_id;
  update public.work_items set updated_at=statement_timestamp() where id=w.id returning * into w;
  return app_private.finish_work_command(w,'grant_work_access',p_request_id,payload,jsonb_build_object('workItemId',w.id,'grantId',grant_id,'version',w.version),'["record_grants"]');
end $$;
create function public.revoke_work_access(p_grant_id uuid,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.record_grants; w public.work_items; payload jsonb; result jsonb; begin
  select * into g from public.record_grants where id=p_grant_id;
  if not found or not public.can_access_work(g.work_item_id,'owner') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_grant_id,p_expected_version);
  result:=app_private.begin_work_command('revoke_work_access',p_request_id,payload);
  select * into w from public.work_items where id=g.work_item_id for update;
  if not public.can_access_work(w.id,'owner') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  select * into g from public.record_grants where id=p_grant_id for update;
  -- Access withdrawal is allowed for frozen/submitted work, while content edits remain closed.
  if result is not null then return result; end if;
  if w.version is distinct from p_expected_version or g.revoked_at is not null then raise exception using errcode='40001',message='command_stale_version'; end if;
  update public.record_grants set revoked_at=statement_timestamp() where id=g.id;
  update public.work_items set updated_at=statement_timestamp() where id=w.id returning * into w;
  return app_private.finish_work_command(w,'revoke_work_access',p_request_id,payload,jsonb_build_object('workItemId',w.id,'grantId',g.id,'version',w.version),'["record_grants"]');
end $$;
revoke all on function app_private.begin_work_command(text,uuid,jsonb),app_private.finish_work_command(public.work_items,text,uuid,jsonb,jsonb,jsonb),app_private.require_work_draft(public.work_items),
  public.create_work_item(uuid,text,text,text,text,text,uuid,uuid,integer,uuid),public.update_work_item(uuid,text,text,text,integer,uuid),
  public.grant_work_access(uuid,uuid,uuid,uuid,text,timestamptz,integer,uuid),public.revoke_work_access(uuid,integer,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.create_work_item(uuid,text,text,text,text,text,uuid,uuid,integer,uuid),public.update_work_item(uuid,text,text,text,integer,uuid),
  public.grant_work_access(uuid,uuid,uuid,uuid,text,timestamptz,integer,uuid),public.revoke_work_access(uuid,integer,uuid) to authenticated;

-- Invitations still begin with zero records; effective scope comes only from real grants.
create or replace function public.list_guest_invitations(p_term_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'email',i.email,'expiresAt',i.expires_at,
    'redeemedAt',i.redeemed_at,'revokedAt',i.revoked_at,'version',i.version,
    'scopeMode',case when scope.n>0 then 'explicit_records' else 'awaiting_record_attachment' end,
    'sharedRecordCount',scope.n) order by i.created_at desc),'[]'::jsonb)
  from public.guest_invitations i cross join lateral (
    select count(distinct g.work_item_id) as n from public.record_grants g where g.guest_invitation_id=i.id
      and g.revoked_at is null and g.starts_at<=statement_timestamp() and g.expires_at>statement_timestamp()
      and i.revoked_at is null and i.expires_at>statement_timestamp() and public.can_access_work(g.work_item_id,'detail')
  ) scope
  where i.term_id=p_term_id and i.sponsor_id=public.current_term_membership(p_term_id) and app_private.active_guest_sponsor(i.sponsor_id)
$$;
create or replace function public.read_guest_contacts(p_term_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('own',jsonb_build_object('displayName',coalesce(p.display_name,'Invited guest'),
    'verifiedEmail',app_private.verified_google_email(auth.uid()),'contactRoute',p.contact_route,'version',coalesce(p.version,0)),
    'sharedContacts',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'name',x.display_name,'organizationContact',x.normalized_email) order by x.display_name,x.id)
      from (select distinct m.id,m.display_name,m.normalized_email from public.record_grants g
        join public.work_items w on w.id=g.work_item_id join public.members m on m.id=w.owner_member_id
        join public.term_memberships tm on tm.member_id=m.id and tm.term_id=w.term_id
        where w.term_id=p_term_id and g.guest_invitation_id is not null and app_private.work_grant_matches(g)
          and m.account_state='active' and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
          and app_private.is_school_identity(m.auth_user_id) and m.normalized_email=app_private.verified_google_email(m.auth_user_id))x),'[]'::jsonb),
    'scopeMode',case when exists(select 1 from public.record_grants g where g.term_id=p_term_id and g.guest_invitation_id is not null and app_private.work_grant_matches(g))
      then 'explicit_records' else 'awaiting_record_attachment' end)
  from auth.users u left join public.guest_contact_profiles p on p.user_id=u.id
  where u.id=auth.uid() and app_private.current_guest_invitation(p_term_id) is not null
$$;
alter function public.redeem_guest_invitation(text) set schema app_private;
create function public.redeem_guest_invitation(p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; n integer; begin
  result:=app_private.redeem_guest_invitation(p_token);
  select count(distinct g.work_item_id) into n from public.record_grants g join public.guest_invitations i on i.id=g.guest_invitation_id
    where i.token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') and app_private.work_grant_matches(g);
  return result||jsonb_build_object('sharedRecords',n);
end $$;
revoke all on function app_private.redeem_guest_invitation(text),public.redeem_guest_invitation(text) from public,anon,authenticated,service_role;
grant execute on function public.redeem_guest_invitation(text) to authenticated;
commit;
