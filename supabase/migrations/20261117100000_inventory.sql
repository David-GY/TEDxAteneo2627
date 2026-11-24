begin;

create table app_private.inventory_policies (
  term_id uuid primary key references public.terms(id),
  unit_id uuid not null references public.org_units(id),
  finance_type_id uuid references public.request_types(id),
  approved_by uuid not null references public.term_memberships(id),
  approval_reference text not null check(length(btrim(approval_reference)) between 3 and 500),
  approved_at timestamptz not null check(isfinite(approved_at)),
  expires_at timestamptz not null check(isfinite(expires_at) and expires_at>approved_at)
);

create table app_private.inventory_items (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references app_private.inventory_policies(term_id),
  label text not null check(length(btrim(label)) between 1 and 160 and label !~ '[[:cntrl:]]'),
  location text not null check(length(btrim(location)) between 1 and 160 and location !~ '[[:cntrl:]]'),
  kind text not null check(kind in ('returnable','consumable')),
  custodian_id uuid not null references public.term_memberships(id),
  version integer not null default 1 check(version>0),
  unique(term_id,id)
);
create unique index inventory_item_name_location on app_private.inventory_items(term_id,lower(label),lower(location));

create table app_private.inventory_counters (
  term_id uuid primary key references app_private.inventory_policies(term_id),
  last_number bigint not null check(last_number>0)
);

create table app_private.inventory_loans (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  item_id uuid not null,
  borrower_id uuid not null references public.term_memberships(id),
  reference text not null check(reference ~ '^BOR-[0-9]{3,19}$'),
  quantity integer not null check(quantity between 1 and 100000),
  starts_on date not null check(isfinite(starts_on)),
  due_on date not null check(isfinite(due_on) and due_on>=starts_on),
  related_work_id uuid references public.work_items(id),
  version integer not null default 1 check(version>0),
  created_at timestamptz not null default statement_timestamp(),
  foreign key(term_id,item_id) references app_private.inventory_items(term_id,id),
  unique(term_id,reference),
  unique(term_id,item_id,id)
);
create index inventory_loans_borrower on app_private.inventory_loans(term_id,borrower_id,created_at desc);

create table app_private.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  item_id uuid not null,
  loan_id uuid,
  version integer not null check(version>0),
  action text not null check(action in ('opening','reserve','issue','consume','return','damage','loss','cancel','reassign')),
  quantity integer not null check(quantity between 0 and 100000),
  condition text check(condition in ('usable','worn','damaged','missing')),
  note text check(length(btrim(note)) between 1 and 2000),
  evidence_manifest_id uuid references public.asset_manifests(id),
  prior_custodian_id uuid references public.term_memberships(id),
  next_custodian_id uuid references public.term_memberships(id),
  actor_id uuid not null references auth.users(id),
  recorded_at timestamptz not null default clock_timestamp(),
  foreign key(term_id,item_id) references app_private.inventory_items(term_id,id),
  foreign key(term_id,item_id,loan_id) references app_private.inventory_loans(term_id,item_id,id),
  check((loan_id is null)=(action in ('opening','reassign'))),
  check((action in ('opening','reassign')) or quantity>0),
  check((action in ('damage','loss'))=(evidence_manifest_id is not null)),
  check(action not in ('damage','loss','cancel','reassign') or note is not null),
  check((action='reassign')=(prior_custodian_id is not null and next_custodian_id is not null))
);
create unique index inventory_loan_event_version on app_private.inventory_movements(loan_id,version) where loan_id is not null;
create unique index inventory_item_event_version on app_private.inventory_movements(item_id,version) where loan_id is null;
create index inventory_movements_item on app_private.inventory_movements(item_id,action);

create table app_private.inventory_finance_followups (
  request_id uuid primary key references public.requests(work_item_id),
  term_id uuid not null,
  item_id uuid not null,
  loan_id uuid,
  incident_id uuid unique references app_private.inventory_movements(id),
  actor_id uuid not null references auth.users(id),
  recorded_at timestamptz not null default clock_timestamp(),
  foreign key(term_id,item_id) references app_private.inventory_items(term_id,id),
  foreign key(term_id,item_id,loan_id) references app_private.inventory_loans(term_id,item_id,id),
  check((loan_id is null)=(incident_id is null))
);
create index inventory_finance_loan on app_private.inventory_finance_followups(loan_id);

do $$declare relation text;
begin
  foreach relation in array array['inventory_policies','inventory_items','inventory_counters','inventory_loans',
    'inventory_movements','inventory_finance_followups'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
  end loop;
end $$;
create trigger immutable_inventory_movements before update or delete on app_private.inventory_movements
  for each row execute function app_private.request_history_guard();
create trigger immutable_inventory_finance_followup before update or delete on app_private.inventory_finance_followups
  for each row execute function app_private.request_history_guard();

create function app_private.current_inventory_policy(p_term uuid) returns app_private.inventory_policies
language sql stable set search_path='' as $$
  select p.* from app_private.inventory_policies p
  join public.org_units u on u.id=p.unit_id and u.term_id=p.term_id and u.archived_at is null
  join public.term_memberships m on m.id=p.approved_by and m.term_id=p.term_id and m.membership_kind='core'
  join public.members a on a.id=m.member_id and a.account_state='active'
  where p.term_id=p_term and p.approved_at<=statement_timestamp() and p.expires_at>statement_timestamp()
    and m.status='active' and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp();
$$;

create function app_private.inventory_custodian(p_term uuid,p_unit uuid,p_membership uuid) returns boolean
language sql stable set search_path='' as $$
  select exists(
    select 1 from public.unit_memberships d
    join app_private.effective_role_assignments a on a.term_membership_id=d.term_membership_id
      and a.term_id=d.term_id and a.unit_id=d.unit_id and a.scope_type='unit'
    join public.role_permissions cap on cap.role_id=a.role_id and cap.capability='committee.manage' and cap.allowed_scope='unit'
    where d.term_id=p_term and d.unit_id=p_unit and d.term_membership_id=p_membership and d.deployment_type='head'
      and d.status='active' and d.effective_from<=statement_timestamp() and d.effective_to>statement_timestamp()
      and app_private.access_assignment_live(a.id)
  );
$$;

create function app_private.inventory_write_policy(p_term uuid) returns app_private.inventory_policies
language plpgsql set search_path='' as $$
declare policy app_private.inventory_policies;
begin
  perform app_private.readiness_lock(p_term);
  if app_private.disposition_replay_required(p_term) then
    raise exception using errcode='55000',message='privacy_restore_replay_required';
  end if;
  policy:=app_private.current_inventory_policy(p_term);
  if policy.term_id is null then raise exception using errcode='55000',message='command_inventory_unavailable'; end if;
  return policy;
end;
$$;

create function app_private.inventory_receipt(actor public.term_memberships,p_action text,p_key uuid,p_payload jsonb,p_result jsonb)
returns jsonb language plpgsql set search_path='' as $$
begin
  insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)
  values(auth.uid(),p_action,p_key,actor.organization_id,actor.term_id,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),p_result);
  return p_result;
end;
$$;

create function app_private.inventory_available(p_item uuid) returns bigint
language sql stable set search_path='' as $$
  select coalesce(sum(case action when 'opening' then quantity when 'reserve' then -quantity
    when 'cancel' then quantity when 'return' then quantity else 0 end),0)
  from app_private.inventory_movements where item_id=p_item;
$$;

create function app_private.inventory_loan_totals(p_loan uuid)
returns table(issued integer,consumed integer,returned integer,damaged integer,lost integer,released integer)
language sql stable set search_path='' as $$
  select coalesce(sum(quantity) filter(where action='issue'),0)::integer,
    coalesce(sum(quantity) filter(where action='consume'),0)::integer,
    coalesce(sum(quantity) filter(where action='return'),0)::integer,
    coalesce(sum(quantity) filter(where action='damage'),0)::integer,
    coalesce(sum(quantity) filter(where action='loss'),0)::integer,
    coalesce(sum(quantity) filter(where action='cancel'),0)::integer
  from app_private.inventory_movements where loan_id=p_loan;
$$;

create function public.register_inventory_item(p_term_id uuid,p_label text,p_location text,p_kind text,p_opening_quantity integer,
  p_custodian_id uuid,p_condition text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; item app_private.inventory_items; payload jsonb; prior jsonb;
begin
  actor:=app_private.request_actor(p_term_id,true);
  policy:=app_private.inventory_write_policy(p_term_id);
  if not app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id)
    or not app_private.inventory_custodian(p_term_id,policy.unit_id,p_custodian_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_label,p_location,p_kind,p_opening_quantity,p_custodian_id,p_condition);
  prior:=app_private.begin_work_command('register_inventory_item',p_key,payload);
  if prior is not null then return prior; end if;
  if coalesce(length(btrim(p_label)),0) not between 1 and 160 or coalesce(length(btrim(p_location)),0) not between 1 and 160
    or p_label ~ '[[:cntrl:]]' or p_location ~ '[[:cntrl:]]'
    or p_kind is null or p_kind not in ('returnable','consumable') or p_condition is null or p_condition not in ('usable','worn')
    or p_opening_quantity is null or p_opening_quantity not between 0 and 100000 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  insert into app_private.inventory_items(term_id,label,location,kind,custodian_id)
    values(p_term_id,btrim(p_label),btrim(p_location),p_kind,p_custodian_id) returning * into item;
  insert into app_private.inventory_movements(term_id,item_id,version,action,quantity,condition,actor_id)
    values(p_term_id,item.id,item.version,'opening',p_opening_quantity,p_condition,auth.uid());
  return app_private.inventory_receipt(actor,'register_inventory_item',p_key,payload,
    jsonb_build_object('itemId',item.id,'version',item.version));
end;
$$;

create function public.reserve_inventory(p_term_id uuid,p_item_id uuid,p_expected_version integer,p_quantity integer,
  p_starts_on date,p_due_on date,p_key uuid,p_related_work_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; item app_private.inventory_items;
  loan app_private.inventory_loans; t public.terms; serial bigint; payload jsonb; prior jsonb;
begin
  actor:=app_private.request_actor(p_term_id,true);
  policy:=app_private.inventory_write_policy(p_term_id);
  select * into item from app_private.inventory_items where id=p_item_id and term_id=p_term_id for update;
  if item.id is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_term_id,p_item_id,p_expected_version,p_quantity,p_starts_on,p_due_on,p_related_work_id);
  prior:=app_private.begin_work_command('reserve_inventory',p_key,payload);
  if prior is not null then return prior; end if;
  if item.custodian_id=actor.id or not app_private.inventory_custodian(p_term_id,policy.unit_id,item.custodian_id) then
    raise exception using errcode='55000',message='command_inventory_custodian_unavailable';
  end if;
  select * into t from public.terms where id=p_term_id;
  if p_quantity is null or p_quantity not between 1 and 100000 or p_starts_on is null or p_due_on is null
    or not isfinite(p_starts_on) or not isfinite(p_due_on)
    or p_starts_on<greatest(t.starts_on,(statement_timestamp() at time zone 'Asia/Manila')::date)
    or p_due_on<p_starts_on or p_due_on>t.closes_on or (item.kind='consumable' and p_due_on<>p_starts_on) then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  if p_related_work_id is not null and not exists(select 1 from public.work_items w
    where w.id=p_related_work_id and w.term_id=p_term_id and w.kind in ('task','deliverable') and w.archived_at is null
      and public.can_access_work(w.id,'detail')) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  if app_private.inventory_available(item.id)<p_quantity then
    raise exception using errcode='23P01',message='command_inventory_shortage';
  end if;
  if item.version is distinct from p_expected_version then
    raise exception using errcode='40001',message='command_stale_version';
  end if;
  insert into app_private.inventory_counters(term_id,last_number) values(p_term_id,1)
    on conflict(term_id) do update set last_number=app_private.inventory_counters.last_number+1
    returning last_number into serial;
  insert into app_private.inventory_loans(term_id,item_id,borrower_id,reference,quantity,starts_on,due_on,related_work_id)
    values(p_term_id,item.id,actor.id,'BOR-'||lpad(serial::text,greatest(3,length(serial::text)),'0'),
      p_quantity,p_starts_on,p_due_on,p_related_work_id) returning * into loan;
  insert into app_private.inventory_movements(term_id,item_id,loan_id,version,action,quantity,actor_id)
    values(p_term_id,item.id,loan.id,loan.version,'reserve',p_quantity,auth.uid());
  update app_private.inventory_items set version=version+1 where id=item.id;
  return app_private.inventory_receipt(actor,'reserve_inventory',p_key,payload,
    jsonb_build_object('loanId',loan.id,'reference',loan.reference,'version',loan.version));
end;
$$;

create function public.record_inventory_movement(p_term_id uuid,p_loan_id uuid,p_expected_version integer,p_action text,
  p_quantity integer,p_key uuid,p_condition text default null,p_note text default null,p_evidence_manifest_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; item app_private.inventory_items;
  loan app_private.inventory_loans; totals record; payload jsonb; prior jsonb; actual_action text; can_handle boolean;
begin
  actor:=app_private.request_actor(p_term_id,true);
  policy:=app_private.inventory_write_policy(p_term_id);
  select * into loan from app_private.inventory_loans where id=p_loan_id and term_id=p_term_id;
  select * into item from app_private.inventory_items where id=loan.item_id for update;
  select * into loan from app_private.inventory_loans where id=p_loan_id and term_id=p_term_id for update;
  can_handle:=coalesce(item.custodian_id=actor.id and app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id),false);
  if loan.id is null or not (can_handle or (loan.borrower_id=actor.id and p_action='cancel')) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_loan_id,p_expected_version,p_action,p_quantity,p_condition,p_note,p_evidence_manifest_id);
  prior:=app_private.begin_work_command('record_inventory_movement',p_key,payload);
  if prior is not null then return prior; end if;
  if loan.version is distinct from p_expected_version then
    raise exception using errcode='40001',message='command_stale_version';
  end if;
  if p_action is null or p_action not in ('issue','return','damage','loss','cancel')
    or p_quantity is null or p_quantity not between 1 and loan.quantity
    or (p_note is not null and length(btrim(p_note)) not between 1 and 2000)
    or (p_action in ('damage','loss','cancel') and p_note is null)
    or (p_action in ('issue','return') and (p_condition is null or p_condition not in ('usable','worn')))
    or (p_action in ('damage','loss','cancel') and p_condition is not null)
    or ((p_action in ('damage','loss'))<>(p_evidence_manifest_id is not null)) then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  select * into totals from app_private.inventory_loan_totals(loan.id);
  if p_action in ('issue','cancel') then
    if totals.issued+totals.released+totals.consumed<>0 or p_quantity<>loan.quantity then
      raise exception using errcode='55000',message='command_inventory_state_changed';
    end if;
    if p_action='issue' and ((statement_timestamp() at time zone 'Asia/Manila')::date not between loan.starts_on and loan.due_on
      or not exists(select 1 from public.term_memberships m join public.members b on b.id=m.member_id
        where m.id=loan.borrower_id and m.term_id=loan.term_id and m.status='active' and m.membership_kind='core'
          and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp() and b.account_state='active')) then
      raise exception using errcode='55000',message='command_inventory_pickup_unavailable';
    end if;
  elsif p_quantity>totals.issued-totals.returned-totals.damaged-totals.lost then
    raise exception using errcode='55000',message='command_inventory_state_changed';
  end if;
  if p_evidence_manifest_id is not null and not exists(
    select 1 from public.asset_manifests m join public.work_items w on w.id=m.work_item_id
    where m.id=p_evidence_manifest_id and w.term_id=p_term_id and w.archived_at is null and w.kind in ('task','deliverable')
      and public.can_read_manifest(m.id)
      and exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id
        where i.manifest_id=m.id and a.origin_work_item_id=w.id and a.state='finalized')
      and not exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id
        where i.manifest_id=m.id and (a.origin_work_item_id<>w.id or a.state<>'finalized'))
  ) then raise exception using errcode='42501',message='command_permission_denied'; end if;
  actual_action:=case when p_action='issue' and item.kind='consumable' then 'consume' else p_action end;
  update app_private.inventory_loans set version=version+1 where id=loan.id returning * into loan;
  insert into app_private.inventory_movements(term_id,item_id,loan_id,version,action,quantity,condition,note,evidence_manifest_id,actor_id)
    values(p_term_id,item.id,loan.id,loan.version,actual_action,p_quantity,
      case p_action when 'damage' then 'damaged' when 'loss' then 'missing' else p_condition end,
      btrim(p_note),p_evidence_manifest_id,auth.uid());
  update app_private.inventory_items set version=version+1 where id=item.id;
  return app_private.inventory_receipt(actor,'record_inventory_movement',p_key,payload,
    jsonb_build_object('loanId',loan.id,'reference',loan.reference,'version',loan.version));
end;
$$;

create function public.reassign_inventory_custodian(p_term_id uuid,p_item_id uuid,p_expected_version integer,
  p_custodian_id uuid,p_reason text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; item app_private.inventory_items;
  before_id uuid; payload jsonb; prior jsonb;
begin
  actor:=app_private.request_actor(p_term_id,true);
  policy:=app_private.inventory_write_policy(p_term_id);
  if not app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id)
    or not app_private.inventory_custodian(p_term_id,policy.unit_id,p_custodian_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  select * into item from app_private.inventory_items where id=p_item_id and term_id=p_term_id for update;
  if item.id is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_term_id,p_item_id,p_expected_version,p_custodian_id,p_reason);
  prior:=app_private.begin_work_command('reassign_inventory_custodian',p_key,payload);
  if prior is not null then return prior; end if;
  if item.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if coalesce(length(btrim(p_reason)),0) not between 1 and 2000 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  if item.custodian_id=p_custodian_id or (item.custodian_id<>actor.id
    and app_private.inventory_custodian(p_term_id,policy.unit_id,item.custodian_id)) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  before_id:=item.custodian_id;
  update app_private.inventory_items set custodian_id=p_custodian_id,version=version+1 where id=item.id returning * into item;
  insert into app_private.inventory_movements(term_id,item_id,version,action,quantity,note,prior_custodian_id,next_custodian_id,actor_id)
    values(p_term_id,item.id,item.version,'reassign',0,btrim(p_reason),before_id,p_custodian_id,auth.uid());
  return app_private.inventory_receipt(actor,'reassign_inventory_custodian',p_key,payload,
    jsonb_build_object('itemId',item.id,'version',item.version));
end;
$$;

create function public.start_inventory_finance(p_term_id uuid,p_item_id uuid,p_expected_version integer,
  p_key uuid,p_incident_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; item app_private.inventory_items;
  incident app_private.inventory_movements; finance public.request_types; title text; payload jsonb; result jsonb;
begin
  actor:=app_private.request_actor(p_term_id,true);
  policy:=app_private.inventory_write_policy(p_term_id);
  select * into item from app_private.inventory_items where id=p_item_id and term_id=p_term_id for update;
  if item.id is null or item.custodian_id<>actor.id or not app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_item_id,p_expected_version,p_incident_id);
  result:=app_private.begin_work_command('start_inventory_finance',p_key,payload);
  if result is not null then return result; end if;
  if item.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  select * into finance from public.request_types where id=policy.finance_type_id and term_id=p_term_id and governed_kind='fin' for share;
  if finance.id is null or not app_private.request_route_ready(finance) then
    raise exception using errcode='55000',message='command_inventory_finance_unavailable';
  end if;
  title:='Inventory purchase · '||item.label;
  if p_incident_id is not null then
    select * into incident from app_private.inventory_movements
      where id=p_incident_id and item_id=item.id and term_id=p_term_id and action in ('damage','loss');
    if incident.id is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
    if exists(select 1 from app_private.inventory_finance_followups f where f.incident_id=incident.id) then
      raise exception using errcode='55000',message='command_inventory_finance_exists';
    end if;
    select 'Inventory replacement · '||reference into title from app_private.inventory_loans where id=incident.loan_id;
  end if;
  result:=public.create_request_draft(p_term_id,finance.id,finance.form_version_id,finance.workflow_version_id,title,
    md5('inventory-finance-draft:'||p_key::text)::uuid);
  insert into app_private.inventory_finance_followups(request_id,term_id,item_id,loan_id,incident_id,actor_id)
    values((result->>'requestId')::uuid,p_term_id,item.id,incident.loan_id,incident.id,auth.uid());
  return app_private.inventory_receipt(actor,'start_inventory_finance',p_key,payload,
    jsonb_build_object('financeRequestId',result->>'requestId','version',result->'version'));
end;
$$;

create function app_private.inventory_loan_view(loan app_private.inventory_loans,p_custodian boolean,p_finance boolean)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('id',loan.id,'itemId',loan.item_id,'item',item.label,'kind',item.kind,'location',item.location,
    'reference',loan.reference,'version',loan.version,'quantity',loan.quantity,'startsOn',loan.starts_on,'dueOn',loan.due_on,
    'state',case when balance.released>0 then 'cancelled' when balance.consumed>0 then 'complete'
      when balance.issued=0 then 'reserved'
      when balance.issued=balance.returned+balance.damaged+balance.lost then 'complete'
      when balance.returned+balance.damaged+balance.lost>0 then 'partial' else 'issued' end,
    'outstanding',balance.issued-balance.returned-balance.damaged-balance.lost,
    'returned',balance.returned,'damaged',balance.damaged,'lost',balance.lost,'consumed',balance.consumed,
    'borrower',member.display_name,'borrowerActive',coalesce(b.status='active' and b.membership_kind='core'
      and b.joined_at<=statement_timestamp() and b.ends_at>statement_timestamp() and member.account_state='active',false),
    'custodian',p_custodian,'canStartFinance',p_finance,
    'relatedWork',case when work.id is not null and work.archived_at is null and public.can_access_work(work.id,'detail')
      then jsonb_build_object('id',work.id,'label',work.title,'kind',work.kind) end,
    'history',coalesce((select jsonb_agg(jsonb_build_object('action',e.action,'quantity',e.quantity,
      'condition',e.condition,'note',e.note,'at',e.recorded_at,'version',e.version,
      'evidence',e.evidence_manifest_id is not null,'incidentId',case when p_custodian and e.action in ('damage','loss') then e.id end,
      'financeStarted',f.request_id is not null,'financeRequestId',case when f.actor_id=auth.uid() then f.request_id end)
      order by e.version desc) from (
        select * from app_private.inventory_movements where loan_id=loan.id order by version desc limit 100
      ) e left join app_private.inventory_finance_followups f on f.incident_id=e.id),'[]'::jsonb))
  from app_private.inventory_items item join public.term_memberships b on b.id=loan.borrower_id
  join public.members member on member.id=b.member_id
  left join public.work_items work on work.id=loan.related_work_id
  cross join lateral app_private.inventory_loan_totals(loan.id) balance
  where item.id=loan.item_id;
$$;

create function public.read_inventory_entry(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; enabled boolean;
  checkout jsonb; due_return jsonb; today date:=(statement_timestamp() at time zone 'Asia/Manila')::date;
begin
  actor:=app_private.request_actor(p_term_id,false);
  policy:=app_private.current_inventory_policy(p_term_id);
  enabled:=policy.term_id is not null and not app_private.disposition_replay_required(p_term_id);
  if enabled and app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id)
    and exists(select 1 from public.terms where id=p_term_id and state='active') then
    select jsonb_build_object('id',l.id,'item',i.label,'reference',l.reference) into checkout
    from app_private.inventory_loans l join app_private.inventory_items i on i.id=l.item_id
    join public.term_memberships b on b.id=l.borrower_id and b.membership_kind='core'
    join public.members member on member.id=b.member_id and member.account_state='active'
    cross join lateral app_private.inventory_loan_totals(l.id) totals
    where l.term_id=p_term_id and i.custodian_id=actor.id and today between l.starts_on and l.due_on
      and b.status='active' and b.joined_at<=statement_timestamp() and b.ends_at>statement_timestamp()
      and totals.issued+totals.consumed+totals.released=0
    order by l.due_on,l.created_at,l.id limit 1;
    select jsonb_build_object('id',l.id,'item',i.label,'reference',l.reference) into due_return
    from app_private.inventory_loans l join app_private.inventory_items i on i.id=l.item_id
    cross join lateral app_private.inventory_loan_totals(l.id) totals
    where l.term_id=p_term_id and i.custodian_id=actor.id and totals.issued>totals.returned+totals.damaged+totals.lost
    order by l.due_on,l.created_at desc,l.id limit 1;
  end if;
  perform app_private.record_content_read('read_inventory_entry',p_term_id,null,enabled);
  return jsonb_build_object('enabled',enabled,'checkout',checkout,'dueReturn',due_return);
end;
$$;

create function public.read_inventory_workspace(p_term_id uuid,p_loan_id uuid default null,
  p_item_page integer default 1,p_loan_page integer default 1,p_item_query text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; t public.terms;
  steward boolean; finance_ready boolean; items jsonb; loans jsonb; assignees jsonb; work_choices jsonb;
  more_items boolean; more_loans boolean;
begin
  actor:=app_private.request_actor(p_term_id,false);
  if p_item_page is null or p_item_page not between 1 and 10000 or p_loan_page is null or p_loan_page not between 1 and 10000
    or length(p_item_query)>160 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  policy:=app_private.current_inventory_policy(p_term_id);
  if policy.term_id is null or app_private.disposition_replay_required(p_term_id) then
    perform app_private.record_content_read('read_inventory_workspace',p_term_id,null,false);
    return null;
  end if;
  select * into t from public.terms where id=p_term_id;
  steward:=t.state='active' and app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id);
  finance_ready:=exists(select 1 from public.request_types f where f.id=policy.finance_type_id and f.term_id=p_term_id
    and f.governed_kind='fin' and app_private.request_route_ready(f));
  select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'name',i.label,'location',i.location,'kind',i.kind,
    'version',i.version,'available',app_private.inventory_available(i.id),'custodian',case when current_custodian then name end,
    'custodianId',case when steward then i.custodian_id end,'canReserve',t.state='active' and current_custodian and i.custodian_id<>actor.id,
    'canReassign',steward and (not current_custodian or i.custodian_id=actor.id),
    'canStartFinance',finance_ready and steward and i.custodian_id=actor.id,'needsCustodian',not current_custodian)
      order by steward and not i.current_custodian desc,i.label,i.id),'[]'::jsonb)
    into items from (
      select stock.*,person.display_name name,app_private.inventory_custodian(p_term_id,policy.unit_id,stock.custodian_id) current_custodian
      from app_private.inventory_items stock join public.term_memberships m on m.id=stock.custodian_id
      join public.members person on person.id=m.member_id where stock.term_id=p_term_id
      and (p_loan_id is null or stock.id=(select item_id from app_private.inventory_loans b where b.id=p_loan_id and b.term_id=p_term_id))
      and (p_loan_id is not null or nullif(btrim(p_item_query),'') is null
        or strpos(lower(stock.label),lower(btrim(p_item_query)))>0
        or strpos(lower(stock.location),lower(btrim(p_item_query)))>0)
      order by steward and not app_private.inventory_custodian(p_term_id,policy.unit_id,stock.custodian_id) desc,stock.label,stock.id
      limit 41 offset(case when p_loan_id is null then (p_item_page-1)*40 else 0 end)
    ) i;
  select coalesce(jsonb_agg(app_private.inventory_loan_view(
      l.loan,steward and l.custodian_id=actor.id,finance_ready and steward and l.custodian_id=actor.id)
    order by l.created_at desc,l.id),'[]'::jsonb)
  into loans from(
    select b as loan,i.custodian_id,b.created_at,b.id
    from app_private.inventory_loans b join app_private.inventory_items i on i.id=b.item_id
    where b.term_id=p_term_id and (b.borrower_id=actor.id or steward and i.custodian_id=actor.id)
      and (p_loan_id is null or b.id=p_loan_id)
    order by b.created_at desc,b.id limit 31 offset(case when p_loan_id is null then (p_loan_page-1)*30 else 0 end)
  ) l;
  if p_loan_id is not null and jsonb_array_length(loans)=0 then
    perform app_private.record_content_read('read_inventory_workspace',p_term_id,null,false);
    return null;
  end if;
  more_items:=jsonb_array_length(items)>40;
  more_loans:=jsonb_array_length(loans)>30;
  if more_items then items:=items-40; end if;
  if more_loans then loans:=loans-30; end if;
  if steward then
    select jsonb_agg(jsonb_build_object('id',m.id,'name',person.display_name) order by person.display_name,m.id) into assignees
    from public.term_memberships m join public.members person on person.id=m.member_id
    where m.term_id=p_term_id and app_private.inventory_custodian(p_term_id,policy.unit_id,m.id);
  end if;
  select jsonb_agg(jsonb_build_object('id',w.id,'label',w.title,'kind',w.kind) order by w.title,w.id) into work_choices
    from (select id,title,kind from public.work_items where term_id=p_term_id and kind in ('task','deliverable') and archived_at is null
      and public.can_access_work(id,'detail') order by updated_at desc,id limit 50) w;
  perform app_private.record_content_read('read_inventory_workspace',p_term_id,p_loan_id,true);
  return jsonb_build_object('termLabel',t.label,'steward',steward,'editable',t.state='active','actorId',actor.id,
    'items',items,'loans',loans,'custodians',coalesce(assignees,'[]'::jsonb),'work',coalesce(work_choices,'[]'::jsonb),
    'moreItems',more_items,'moreLoans',more_loans);
end;
$$;

create function public.read_inventory_evidence(p_term_id uuid,p_loan_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy app_private.inventory_policies; item app_private.inventory_items; result jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);
  policy:=app_private.current_inventory_policy(p_term_id);
  select i.* into item from app_private.inventory_items i join app_private.inventory_loans l on l.item_id=i.id
    where l.id=p_loan_id and l.term_id=p_term_id;
  if policy.term_id is null or item.id is null or item.custodian_id<>actor.id
    or not app_private.inventory_custodian(p_term_id,policy.unit_id,actor.id) or app_private.disposition_replay_required(p_term_id) then
    perform app_private.record_content_read('read_inventory_evidence',p_term_id,null,false);
    return null;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'work',e.title,'kind',e.kind,'workId',e.work_id,
    'files',e.files,'at',e.created_at) order by e.created_at desc,e.id),'[]'::jsonb) into result
  from (select m.id,w.id as work_id,w.title,w.kind,m.created_at,array_agg(a.filename order by a.filename,a.id) files
    from public.asset_manifests m join public.work_items w on w.id=m.work_item_id
    join public.asset_manifest_items i on i.manifest_id=m.id join public.assets a on a.id=i.asset_id
    where w.term_id=p_term_id and w.kind in ('task','deliverable') and w.archived_at is null and public.can_read_manifest(m.id)
    group by m.id,w.id having bool_and(a.state='finalized' and a.origin_work_item_id=w.id)
    order by m.created_at desc,m.id limit 100) e;
  perform app_private.record_content_read('read_inventory_evidence',p_term_id,p_loan_id,true);
  return result;
end;
$$;

insert into public.restricted_read_endpoints(endpoint,argument_types) values
  ('read_inventory_entry','uuid'),('read_inventory_workspace','uuid, uuid, integer, integer, text'),('read_inventory_evidence','uuid, uuid');

revoke all on function app_private.current_inventory_policy(uuid),app_private.inventory_custodian(uuid,uuid,uuid),
  app_private.inventory_write_policy(uuid),app_private.inventory_receipt(public.term_memberships,text,uuid,jsonb,jsonb),
  app_private.inventory_available(uuid),app_private.inventory_loan_totals(uuid),app_private.inventory_loan_view(app_private.inventory_loans,boolean,boolean),
  public.register_inventory_item(uuid,text,text,text,integer,uuid,text,uuid),
  public.reserve_inventory(uuid,uuid,integer,integer,date,date,uuid,uuid),
  public.record_inventory_movement(uuid,uuid,integer,text,integer,uuid,text,text,uuid),
  public.reassign_inventory_custodian(uuid,uuid,integer,uuid,text,uuid),public.start_inventory_finance(uuid,uuid,integer,uuid,uuid),
  public.read_inventory_entry(uuid),public.read_inventory_workspace(uuid,uuid,integer,integer,text),public.read_inventory_evidence(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.register_inventory_item(uuid,text,text,text,integer,uuid,text,uuid),
  public.reserve_inventory(uuid,uuid,integer,integer,date,date,uuid,uuid),
  public.record_inventory_movement(uuid,uuid,integer,text,integer,uuid,text,text,uuid),
  public.reassign_inventory_custodian(uuid,uuid,integer,uuid,text,uuid),public.start_inventory_finance(uuid,uuid,integer,uuid,uuid),
  public.read_inventory_entry(uuid),public.read_inventory_workspace(uuid,uuid,integer,integer,text),public.read_inventory_evidence(uuid,uuid) to authenticated;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,category,'term',keys,
  format('select app_private.disposition_key(%L,%s) target_hash,%L category,%s root_id,
    app_private.retention_is_held($1,%L,null::uuid,%s) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x where x.term_id=$1',
    'app_private.'||source,key_expr,category,root_expr,category,root_expr,source),
  app_private.disposition_structure('app_private.'||source),false
from (values
  ('inventory_policies','security',array['term_id'],'array[x.term_id::text]','null::uuid'),
  ('inventory_counters','operational',array['term_id'],'array[x.term_id::text]','null::uuid'),
  ('inventory_items','operational',array['id'],'array[x.id::text]','x.id'),
  ('inventory_loans','restricted',array['id'],'array[x.id::text]','x.id'),
  ('inventory_movements','restricted',array['id'],'array[x.id::text]','coalesce(x.loan_id,x.item_id)'),
  ('inventory_finance_followups','restricted',array['request_id'],'array[x.request_id::text]','coalesce(x.loan_id,x.item_id)')
) definitions(source,category,keys,key_expr,root_expr);

commit;
