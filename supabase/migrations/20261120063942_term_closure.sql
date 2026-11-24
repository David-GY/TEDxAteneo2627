begin;
create table app_private.turnover_approvals(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),
 custodian_id uuid not null references public.term_memberships(id),approved_by uuid not null references public.term_memberships(id),
 evidence_scope text not null check(evidence_scope in('synthetic','operational')),
 approval_reference text not null check(length(btrim(approval_reference)) between 3 and 500),
 freeze_on date not null,expires_at timestamptz not null check(isfinite(expires_at)),
 created_at timestamptz not null default statement_timestamp(),check(custodian_id<>approved_by and expires_at>created_at)
);
create table app_private.turnover_cases(
 id uuid primary key default gen_random_uuid(),term_id uuid not null unique references public.terms(id),
 approval_id uuid not null references app_private.turnover_approvals(id),custodian_id uuid not null references public.term_memberships(id),
 version integer not null default 1 check(version>0),state text not null default 'preparing' check(state in('preparing','frozen','exporting','verified','rehearsal_verified','complete','rehearsal_complete')),
 retention_definition jsonb not null,retention_hash text not null,created_at timestamptz not null default statement_timestamp()
);
create table app_private.turnover_unit_checks(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),case_id uuid not null references app_private.turnover_cases(id),
 unit_id uuid not null references public.org_units(id),owner_id uuid not null references public.term_memberships(id),
 reference text not null check(length(btrim(reference)) between 3 and 500),unique(case_id,unit_id)
);
create table app_private.turnover_obligations(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),case_id uuid not null references app_private.turnover_cases(id),
 work_id uuid not null references public.work_items(id),work_version integer not null,
 resolution text not null check(resolution in('resolved','cancelled','carry')),owner_id uuid not null references public.term_memberships(id),
 successor_id uuid references public.term_memberships(id),reference text not null check(length(btrim(reference)) between 3 and 500),
 unique(case_id,work_id),check((resolution='carry')=(successor_id is not null))
);
create table app_private.turnover_entries(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),case_id uuid not null references app_private.turnover_cases(id),
 source_key text not null references app_private.disposition_sources(source_key),target_hash text not null,category text not null,root_id uuid,
 state_hash text not null,held boolean not null,disposition text not null check(disposition in('archive','dispose','hold','carry')),
 review_on date not null,owner_id uuid not null references public.term_memberships(id),unique(case_id,source_key,target_hash)
);
create table app_private.turnover_runs(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),case_id uuid not null references app_private.turnover_cases(id),
 source_fingerprint text not null,entry_fingerprint text not null,disposition_head text not null,expected_rows integer not null,expected_files integer not null,
 created_at timestamptz not null default statement_timestamp(),unique(case_id,source_fingerprint,entry_fingerprint,disposition_head)
);
create table app_private.turnover_evidence(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),run_id uuid not null references app_private.turnover_runs(id),
 part text not null,artifact_sha256 text not null check(artifact_sha256 ~ '^[a-f0-9]{64}$'),row_count integer not null check(row_count>=0),file_count integer not null check(file_count>=0),
 restored boolean not null default false,operational boolean not null default false,
 reviewed_reference text check(reviewed_reference is null or length(btrim(reviewed_reference)) between 3 and 500),
 created_at timestamptz not null default statement_timestamp(),unique(run_id,part)
);
create table app_private.turnover_failures(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),run_id uuid not null references app_private.turnover_runs(id),
 phase text not null check(phase in('records','files','restore')),reason text not null check(reason in('missing_file','hash_mismatch','source_changed','interrupted','restore_failed')),
 created_at timestamptz not null default statement_timestamp()
);
create table app_private.turnover_transfers(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),case_id uuid not null references app_private.turnover_cases(id),
 successor_id uuid not null references public.term_memberships(id),work_ids uuid[] not null,role_scopes jsonb not null,grant_scopes jsonb not null,
 reference text not null check(length(btrim(reference)) between 3 and 500),accepted_at timestamptz,acceptance_reference text,
 unique(case_id,successor_id),check(cardinality(work_ids) between 1 and 100)
);
create table app_private.turnover_archive_grants(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),transfer_id uuid not null references app_private.turnover_transfers(id),
 work_id uuid not null references public.work_items(id),recipient_id uuid not null references public.term_memberships(id),
 expires_at timestamptz not null check(isfinite(expires_at)),revoked_at timestamptz,unique(transfer_id,work_id)
);
create table app_private.turnover_corrections(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),case_id uuid not null references app_private.turnover_cases(id),
 work_id uuid not null references public.work_items(id),reference text not null check(length(btrim(reference)) between 3 and 500),
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp()
);
create table app_private.turnover_events(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),object_id uuid not null,
 actor_id uuid not null references auth.users(id),operation text not null,version integer not null,created_at timestamptz not null default statement_timestamp()
);
create table app_private.turnover_permits(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),transaction_id bigint not null,
 backend_id integer not null,actor_id uuid not null references auth.users(id),operation text not null check(operation in('freeze','transfer'))
);
do $$declare t text;
begin
 foreach t in array array['turnover_approvals','turnover_cases','turnover_unit_checks','turnover_obligations','turnover_entries','turnover_runs','turnover_evidence',
 'turnover_transfers','turnover_archive_grants','turnover_corrections','turnover_events','turnover_permits','turnover_failures'] loop
  execute format('alter table app_private.%I enable row level security',t);execute format('alter table app_private.%I force row level security',t);
  execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',t);
 end loop;
 foreach t in array array['turnover_approvals','turnover_runs','turnover_evidence','turnover_corrections','turnover_events','turnover_permits','turnover_failures'] loop
  execute format('create trigger immutable_%I before update or delete on app_private.%I for each row execute function app_private.request_history_guard()',t,t);
 end loop;
end $$;

create function app_private.turnover_person(p_member uuid,p_org uuid) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id
  where tm.id=p_member and tm.organization_id=p_org and tm.membership_kind='core' and tm.status='active' and tm.joined_at<=statement_timestamp()
   and tm.ends_at>statement_timestamp() and m.account_state='active' and app_private.is_school_identity(m.auth_user_id)
   and m.normalized_email=app_private.verified_google_email(m.auth_user_id));
$$;
create function app_private.turnover_manager(c app_private.turnover_cases) returns public.term_memberships language plpgsql set search_path='' as $$
declare actor public.term_memberships;
begin
 actor:=app_private.request_actor(c.term_id,false);
 if c.id is null or actor.id<>c.custodian_id or not app_private.privacy_custodian(c.term_id) or not app_private.privacy_strong_session()
  or not exists(select 1 from app_private.turnover_approvals a where a.id=c.approval_id and a.term_id=c.term_id and a.custodian_id=actor.id
   and a.expires_at>statement_timestamp() and app_private.turnover_person(a.approved_by,actor.organization_id)) then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 return actor;
end $$;
create function app_private.turnover_policy(p_term uuid) returns jsonb language sql stable set search_path='' as $$
 select v.definition from public.presentation_controls pc join public.presentation_versions v on v.control_id=pc.work_item_id
  join public.work_items w on w.id=pc.work_item_id and w.archived_at is null
  where pc.term_id=p_term and pc.kind='retention' and app_private.retention_approved(p_term,v.definition,
    (select tm.id from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=p_term and m.auth_user_id=v.actor_id))
  order by v.version desc limit 1;
$$;
create function app_private.turnover_receipt(c app_private.turnover_cases,p_operation text,p_key uuid,p_payload jsonb,p_id uuid default null) returns jsonb
language plpgsql set search_path='' as $$declare result jsonb;
begin
 result:=jsonb_build_object('id',coalesce(p_id,c.id),'version',c.version);
 insert into app_private.turnover_events(term_id,object_id,actor_id,operation,version)values(c.term_id,coalesce(p_id,c.id),auth.uid(),p_operation,c.version);
 insert into public.idempotency_keys(organization_id,term_id,actor_id,client_key,command,payload_hash,result_reference)
  select organization_id,id,auth.uid(),p_key,p_operation,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),result from public.terms where id=c.term_id;
 return result;
end $$;
create function app_private.turnover_fingerprint(p_term uuid) returns text language sql stable set search_path='' as $$
 select encode(sha256(convert_to(coalesce(string_agg(source_key||target_hash||state_hash||held::text,'' order by source_key,target_hash),''),'UTF8')),'hex')
 from app_private.disposition_inventory(p_term) where category<>'security' and source_key<>'public.privacy_events' and source_key not like 'app_private.turnover_%';
$$;
create function app_private.turnover_entry_fingerprint(p_case uuid) returns text language sql stable set search_path='' as $$
 select encode(sha256(convert_to(coalesce(string_agg(source_key||target_hash||state_hash||held::text||disposition||review_on::text,'' order by source_key,target_hash),''),'UTF8')),'hex')
 from app_private.turnover_entries where case_id=p_case;
$$;

-- The fixed row guard also covers service APIs whose old paths predate term freeze.
-- No caller-set GUC bypass exists. Named freeze/transfer commands create a private,
-- transaction/backend/actor-bound permit and append their audit atomically.
create function app_private.turnover_row_term(row_data jsonb,p_table text) returns uuid language plpgsql stable set search_path='' as $$
declare term uuid;work uuid;
begin
 if row_data is null then return null;end if;
 if row_data->>'term_id' is not null then return(row_data->>'term_id')::uuid;end if;
 if p_table='terms' then return(row_data->>'id')::uuid;end if;
 work:=coalesce((row_data->>'work_item_id')::uuid,(row_data->>'origin_work_item_id')::uuid);
 if work is null and row_data->>'asset_id' is not null then select origin_work_item_id into work from public.assets where id=(row_data->>'asset_id')::uuid;end if;
 if work is null and row_data->>'manifest_id' is not null then select work_item_id into work from public.asset_manifests where id=(row_data->>'manifest_id')::uuid;end if;
 if work is not null then select term_id into term from public.work_items where id=work;return term;end if;
 if row_data->>'request_type_id' is not null then select term_id into term from public.request_types where id=(row_data->>'request_type_id')::uuid;return term;end if;
 if row_data->>'instance_id' is not null then select term_id into term from public.workflow_instances where id=(row_data->>'instance_id')::uuid;return term;end if;
 return null;
end $$;
create function app_private.turnover_frozen_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare term uuid;
begin
 for term in select distinct t from unnest(array[app_private.turnover_row_term(case when tg_op<>'INSERT' then to_jsonb(old) end,tg_table_name),
  app_private.turnover_row_term(case when tg_op<>'DELETE' then to_jsonb(new) end,tg_table_name)])t where t is not null loop
  perform app_private.readiness_lock(term);
  if exists(select 1 from public.terms where id=term and state in('frozen','archived')) and not(
   exists(select 1 from app_private.turnover_permits p where p.term_id=term and p.transaction_id=txid_current() and p.backend_id=pg_backend_pid() and p.actor_id=auth.uid())
   and tg_op='UPDATE'and tg_table_schema='public'and(
    tg_table_name='terms'and to_jsonb(old)->>'state'='frozen'and to_jsonb(new)->>'state'='archived'
     and(to_jsonb(old)-array['state','version','updated_at','updated_by'])=(to_jsonb(new)-array['state','version','updated_at','updated_by'])
    or tg_table_name='role_assignments'and to_jsonb(old)->>'status'='active'and to_jsonb(new)->>'status'='revoked'
     and(to_jsonb(old)-array['status','version','updated_at','updated_by'])=(to_jsonb(new)-array['status','version','updated_at','updated_by'])
    or tg_table_name='record_grants'and to_jsonb(old)->>'revoked_at'is null and to_jsonb(new)->>'revoked_at'is not null
     and(to_jsonb(old)-array['revoked_at','version','updated_at','updated_by'])=(to_jsonb(new)-array['revoked_at','version','updated_at','updated_by'])))then
   raise exception using errcode='55000',message='command_term_frozen';end if;
 end loop;
 return case when tg_op='DELETE' then old else new end;
end $$;

-- Existing independently authorized/audited hold handling must remain usable
-- after collection freezes. Change only its active-term actor precondition.
do $$declare f record;definition text;updated text;
begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'and p.proname in('create_legal_hold','release_legal_hold')loop
  definition:=pg_get_functiondef(f.oid);
  updated:=replace(definition,'app_private.request_actor(p_term_id,true)','app_private.request_actor(p_term_id,false)');
  if updated=definition then raise exception 'Expected legal-hold actor boundary changed';end if;
  execute updated;
 end loop;
end $$;
do $$declare t record;
begin
 for t in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind='r' and n.nspname in('public','app_private') and c.relname not like 'turnover_%'
  and c.relname not like 'privacy_%' and c.relname not like '%events' and c.relname not like '%_counters'
  and c.relname not in('idempotency_keys','restricted_access_events','disposition_entries','disposition_heads','legal_holds','legal_hold_events',
   'retention_policy_approvals','announcement_acknowledgments','backup_health_events')
  and exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attname in('term_id','work_item_id','origin_work_item_id','asset_id','manifest_id','request_type_id','instance_id') and a.attnum>0 and not a.attisdropped)
  or c.relkind='r' and n.nspname='public' and c.relname='terms' loop
  execute format('create trigger turnover_freeze_guard before insert or update or delete on %I.%I for each row execute function app_private.turnover_frozen_guard()',t.nspname,t.relname);
 end loop;
end $$;

create function public.prepare_turnover(p_term_id uuid,p_approval_id uuid,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;a app_private.turnover_approvals;c app_private.turnover_cases;policy jsonb;payload jsonb;prior jsonb;
begin
 perform app_private.readiness_lock(p_term_id);actor:=app_private.request_actor(p_term_id,true);
 select *into a from app_private.turnover_approvals where id=p_approval_id and term_id=p_term_id;
 if not app_private.privacy_custodian(p_term_id) or not app_private.privacy_strong_session() or a.custodian_id is distinct from actor.id
  or a.expires_at<=statement_timestamp() or not app_private.turnover_person(a.approved_by,actor.organization_id) then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 -- This first bounded batch is a synthetic rehearsal. The operational adapter,
 -- archived-term custody path and UI acceptance remain explicit P62 work.
 if a.evidence_scope='operational'then raise exception using errcode='55000',message='command_turnover_operational_gate';end if;
 policy:=app_private.turnover_policy(p_term_id);
 if policy is null or app_private.disposition_replay_required(p_term_id) or exists(select 1 from app_private.disposition_inventory(p_term_id)i
  where not exists(select 1 from jsonb_array_elements(policy->'rules')rule where rule->>'category'=i.category)) then
  raise exception using errcode='55000',message='command_turnover_policy_required';end if;
 payload:=jsonb_build_array(p_term_id,p_approval_id);prior:=app_private.begin_work_command('prepare_turnover',p_key,payload);if prior is not null then return prior;end if;
 insert into app_private.turnover_cases(term_id,approval_id,custodian_id,retention_definition,retention_hash)
  values(p_term_id,a.id,actor.id,policy,encode(sha256(convert_to(policy::text,'UTF8')),'hex'))returning*into c;
 return app_private.turnover_receipt(c,'prepare_turnover',p_key,payload);
end $$;

create function public.update_turnover(p_case_id uuid,p_expected_version integer,p_action text,p_values jsonb,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;w public.work_items;payload jsonb;prior jsonb;target uuid;successor public.term_memberships;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;perform app_private.readiness_lock(c.term_id);
 actor:=app_private.turnover_manager(c);select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_expected_version,p_action,p_values);prior:=app_private.begin_work_command('update_turnover',p_key,payload);if prior is not null then return prior;end if;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if jsonb_typeof(p_values) is distinct from 'object' or coalesce(length(btrim(p_values->>'reference')),0) not between 3 and 500 then
  raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action in('unit','obligation','transfer') and c.state<>'preparing' then raise exception using errcode='55000',message='command_term_frozen';end if;
 if p_action='unit' then
  if not exists(select 1 from public.org_units where id=(p_values->>'unit')::uuid and term_id=c.term_id and archived_at is null)
   or not app_private.turnover_person((p_values->>'owner')::uuid,actor.organization_id) then raise exception using errcode='42501',message='command_permission_denied';end if;
  insert into app_private.turnover_unit_checks(term_id,case_id,unit_id,owner_id,reference)values(c.term_id,c.id,(p_values->>'unit')::uuid,(p_values->>'owner')::uuid,p_values->>'reference')
   on conflict(case_id,unit_id)do update set owner_id=excluded.owner_id,reference=excluded.reference;
 elsif p_action='obligation' then
  select*into w from public.work_items where id=(p_values->>'work')::uuid and term_id=c.term_id;
  select*into successor from public.term_memberships where id=(p_values->>'successor')::uuid;
  if w.id is null or w.version is distinct from(p_values->>'workVersion')::integer or not app_private.turnover_person((p_values->>'owner')::uuid,actor.organization_id)
   or not exists(select 1 from public.status_definitions s where s.id=w.status_id and (
    p_values->>'resolution'='resolved' and s.semantic_category='completed' or p_values->>'resolution'='cancelled' and s.semantic_category='cancelled'
    or p_values->>'resolution'='carry' and successor.term_id<>c.term_id and app_private.turnover_person(successor.id,actor.organization_id))) then
   raise exception using errcode='55000',message='command_turnover_obligation_unresolved';end if;
  insert into app_private.turnover_obligations(term_id,case_id,work_id,work_version,resolution,owner_id,successor_id,reference)
   values(c.term_id,c.id,w.id,w.version,p_values->>'resolution',(p_values->>'owner')::uuid,case when p_values->>'resolution'='carry' then successor.id end,p_values->>'reference')
   on conflict(case_id,work_id)do update set work_version=excluded.work_version,resolution=excluded.resolution,owner_id=excluded.owner_id,successor_id=excluded.successor_id,reference=excluded.reference;
 elsif p_action='correction' then
  if c.state='preparing' or not exists(select 1 from public.work_items where id=(p_values->>'work')::uuid and term_id=c.term_id) then
   raise exception using errcode='55000',message='command_turnover_correction_unavailable';end if;
  insert into app_private.turnover_corrections(term_id,case_id,work_id,reference,actor_id)values(c.term_id,c.id,(p_values->>'work')::uuid,p_values->>'reference',auth.uid());
 elsif p_action='transfer' then
  select*into successor from public.term_memberships where id=(p_values->>'successor')::uuid;
  if successor.term_id=c.term_id or not app_private.turnover_person(successor.id,actor.organization_id)
   or jsonb_typeof(p_values->'work')<>'array' or jsonb_array_length(p_values->'work') not between 1 and 100
   or exists(select 1 from jsonb_array_elements_text(p_values->'work')selected(value) where not exists(select 1 from public.work_items candidate
    where candidate.id=selected.value::uuid and candidate.term_id=c.term_id and candidate.classification='ordinary' and app_private.retention_work_category(candidate.id)='operational'
     and candidate.kind in('task','deliverable') and public.can_access_work(candidate.id,'detail')))
   or jsonb_typeof(p_values->'roles')<>'array' or jsonb_typeof(p_values->'grants')<>'array' then
   raise exception using errcode='42501',message='command_permission_denied';end if;
  if exists(select 1 from jsonb_array_elements_text(p_values->'roles')selected(value) where not exists(select 1 from public.role_assignments a where a.id=selected.value::uuid and a.term_id=c.term_id and a.status='active'))
   or exists(select 1 from jsonb_array_elements_text(p_values->'grants')selected(value) where not exists(select 1 from public.record_grants g where g.id=selected.value::uuid and g.term_id=c.term_id and g.revoked_at is null)) then
   raise exception using errcode='40001',message='command_stale_version';end if;
  insert into app_private.turnover_transfers(term_id,case_id,successor_id,work_ids,role_scopes,grant_scopes,reference)
   values(c.term_id,c.id,successor.id,array(select distinct selected.value::uuid from jsonb_array_elements_text(p_values->'work')selected(value)),
    coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'version',a.version))from public.role_assignments a where a.id in(select selected.value::uuid from jsonb_array_elements_text(p_values->'roles')selected(value))),'[]'),
    coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'version',g.version))from public.record_grants g where g.id in(select selected.value::uuid from jsonb_array_elements_text(p_values->'grants')selected(value))),'[]'),p_values->>'reference')
    on conflict(case_id,successor_id)do update set work_ids=excluded.work_ids,role_scopes=excluded.role_scopes,grant_scopes=excluded.grant_scopes,reference=excluded.reference;
 else raise exception using errcode='22023',message='command_validation_failed';end if;
 update app_private.turnover_cases set version=version+1 where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'update_turnover',p_key,payload);
end $$;
create function app_private.turnover_snapshot(c app_private.turnover_cases) returns void language plpgsql set search_path='' as $$
declare policy jsonb;
begin
 policy:=app_private.turnover_policy(c.term_id);
 if policy is null or encode(sha256(convert_to(policy::text,'UTF8')),'hex')<>c.retention_hash then
  raise exception using errcode='55000',message='command_turnover_policy_changed';end if;
 delete from app_private.turnover_entries where case_id=c.id;
 insert into app_private.turnover_entries(term_id,case_id,source_key,target_hash,category,root_id,state_hash,held,disposition,review_on,owner_id)
 select c.term_id,c.id,i.source_key,i.target_hash,i.category,i.root_id,i.state_hash,i.held,
  case when i.held then 'hold' when exists(select 1 from app_private.turnover_obligations o where o.case_id=c.id and o.work_id=i.root_id and o.resolution='carry')then'carry'else'archive'end,
  (statement_timestamp()at time zone'Asia/Manila')::date+(rule->>'days')::integer,c.custodian_id
 from app_private.disposition_inventory(c.term_id)i join lateral(select rule from jsonb_array_elements(policy->'rules')rule where rule->>'category'=i.category)r on true
 where i.source_key not like 'app_private.turnover_%';
end $$;
create function public.freeze_term(p_case_id uuid,p_expected_version integer,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;payload jsonb;prior jsonb;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;perform app_private.readiness_lock(c.term_id);actor:=app_private.turnover_manager(c);
 select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_expected_version);prior:=app_private.begin_work_command('freeze_term',p_key,payload);if prior is not null then return prior;end if;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if c.state<>'preparing' or not exists(select 1 from app_private.turnover_approvals where id=c.approval_id and freeze_on<=(statement_timestamp()at time zone'Asia/Manila')::date)
  or exists(select 1 from public.org_units u where u.term_id=c.term_id and u.archived_at is null and not exists(
   select 1 from app_private.turnover_unit_checks x where x.case_id=c.id and x.unit_id=u.id and app_private.turnover_person(x.owner_id,actor.organization_id)))
  or exists(select 1 from public.work_items w where w.term_id=c.term_id and w.archived_at is null and not exists(
   select 1 from app_private.turnover_obligations o join public.status_definitions s on s.id=w.status_id
   where o.case_id=c.id and o.work_id=w.id and o.work_version=w.version and app_private.turnover_person(o.owner_id,actor.organization_id)
    and(o.resolution='resolved'and s.semantic_category='completed' or o.resolution='cancelled'and s.semantic_category='cancelled'
     or o.resolution='carry'and app_private.turnover_person(o.successor_id,actor.organization_id))))
  or exists(select 1 from public.assets a join public.work_items w on w.id=a.origin_work_item_id where w.term_id=c.term_id and a.kind='upload' and a.state='reserved') then
  raise exception using errcode='55000',message='command_turnover_checklist_incomplete';end if;
 update public.terms set state='frozen',frozen_at=statement_timestamp() where id=c.term_id and state='active';
 if not found then raise exception using errcode='55000',message='command_term_frozen';end if;
 perform app_private.turnover_snapshot(c);
 update app_private.turnover_cases set version=version+1,state='frozen' where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'freeze_term',p_key,payload);
end $$;
create function public.run_archive(p_case_id uuid,p_expected_version integer,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;job app_private.turnover_runs;payload jsonb;prior jsonb;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;perform app_private.readiness_lock(c.term_id);actor:=app_private.turnover_manager(c);
 select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_expected_version);prior:=app_private.begin_work_command('run_archive',p_key,payload);if prior is not null then return prior;end if;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if c.state not in('frozen','exporting','verified','rehearsal_verified') then raise exception using errcode='55000',message='command_turnover_freeze_required';end if;
 select*into job from app_private.turnover_runs where case_id=c.id and source_fingerprint=app_private.turnover_fingerprint(c.term_id)
  and entry_fingerprint=app_private.turnover_entry_fingerprint(c.id)and disposition_head=app_private.backup_disposition_fingerprint(c.term_id)order by created_at desc limit 1;
 if job.id is null then
  perform app_private.turnover_snapshot(c);
  insert into app_private.turnover_runs(term_id,case_id,source_fingerprint,entry_fingerprint,disposition_head,expected_rows,expected_files)
  values(c.term_id,c.id,app_private.turnover_fingerprint(c.term_id),app_private.turnover_entry_fingerprint(c.id),app_private.backup_disposition_fingerprint(c.term_id),
   (select count(*)from app_private.turnover_entries where case_id=c.id),
   (select count(*)from public.assets a join public.work_items w on w.id=a.origin_work_item_id where w.term_id=c.term_id and a.kind='upload'))
  on conflict(case_id,source_fingerprint,entry_fingerprint,disposition_head)do nothing returning*into job;
 if job.id is null then select*into job from app_private.turnover_runs where case_id=c.id and source_fingerprint=app_private.turnover_fingerprint(c.term_id)
  and entry_fingerprint=app_private.turnover_entry_fingerprint(c.id)and disposition_head=app_private.backup_disposition_fingerprint(c.term_id);end if;
 end if;
 update app_private.turnover_cases set version=version+1,state='exporting'where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'run_archive',p_key,payload,job.id);
end $$;

-- Trusted archive runner reads only registered rows named by this exact manifest.
-- This function is never exposed to browser or service-role callers.
create function app_private.turnover_export_rows(p_run uuid,p_source text) returns table(target_hash text,state_hash text,data jsonb)
language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare job app_private.turnover_runs;s app_private.disposition_sources;parts text;schema_name text;table_name text;
begin
 select*into job from app_private.turnover_runs where id=p_run;
 if job.id is null or job.source_fingerprint<>app_private.turnover_fingerprint(job.term_id)
  or job.entry_fingerprint<>app_private.turnover_entry_fingerprint(job.case_id)or job.disposition_head<>app_private.backup_disposition_fingerprint(job.term_id) then
  raise exception using errcode='55000',message='command_turnover_source_changed';end if;
 select*into s from app_private.disposition_sources where source_key=p_source and scope_kind='term' and source_key not like 'app_private.turnover_%';
 if s.source_key is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select string_agg(format('r.%I::text',key),','order by ord)into parts from unnest(s.key_columns)with ordinality keys(key,ord);
 schema_name:=split_part(s.source_key,'.',1);table_name:=split_part(s.source_key,'.',2);
 return query execute format('select e.target_hash,encode(sha256(convert_to(to_jsonb(r)::text,''UTF8'')),''hex''),to_jsonb(r)
  from %I.%I r join app_private.turnover_entries e on e.source_key=$2 and e.case_id=$1
   and e.target_hash=app_private.disposition_key($2,array[%s]) order by e.target_hash',schema_name,table_name,parts)using job.case_id,s.source_key;
end $$;
create function public.verify_turnover_archive(p_case_id uuid,p_run_id uuid,p_expected_version integer,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;job app_private.turnover_runs;proof app_private.turnover_evidence;actor public.term_memberships;payload jsonb;prior jsonb;operational boolean;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;perform app_private.readiness_lock(c.term_id);actor:=app_private.turnover_manager(c);
 select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_run_id,p_expected_version);prior:=app_private.begin_work_command('verify_turnover_archive',p_key,payload);if prior is not null then return prior;end if;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select*into job from app_private.turnover_runs where id=p_run_id and case_id=c.id;
 select*into proof from app_private.turnover_evidence where run_id=job.id and part='complete';
 select evidence_scope='operational'into operational from app_private.turnover_approvals where id=c.approval_id;
 if c.state<>'exporting'or job.id is null or job.source_fingerprint<>app_private.turnover_fingerprint(c.term_id)
  or job.disposition_head<>app_private.backup_disposition_fingerprint(c.term_id)or job.entry_fingerprint<>app_private.turnover_entry_fingerprint(c.id)
  or proof.id is null or proof.row_count<>job.expected_rows or proof.file_count<>job.expected_files or not proof.restored
  or not exists(select 1 from app_private.turnover_evidence where run_id=job.id and part='schema')
  or exists(select distinct category from app_private.turnover_entries e where case_id=c.id and not exists(
   select 1 from app_private.turnover_evidence p where p.run_id=job.id and p.part=e.category))
  or job.expected_rows is distinct from(select sum(row_count)::integer from app_private.turnover_evidence where run_id=job.id and part<>'complete')
  or job.expected_files is distinct from(select sum(file_count)::integer from app_private.turnover_evidence where run_id=job.id and part<>'complete')
  or operational and(not proof.operational or proof.reviewed_reference is null) then
  raise exception using errcode='55000',message='command_turnover_archive_incomplete';end if;
 update app_private.turnover_cases set version=version+1,state=case when operational then'verified'else'rehearsal_verified'end where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'verify_turnover_archive',p_key,payload,job.id);
end $$;
alter table app_private.turnover_transfers add column accepted_run uuid references app_private.turnover_runs(id);

create function public.accept_turnover(p_context_term uuid,p_transfer_id uuid,p_run_id uuid,p_reference text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;c app_private.turnover_cases;t app_private.turnover_transfers;payload jsonb;prior jsonb;
begin
 actor:=app_private.request_actor(p_context_term,false);
 select*into t from app_private.turnover_transfers where id=p_transfer_id;select*into c from app_private.turnover_cases where id=t.case_id;
 perform app_private.readiness_lock(c.term_id);select*into t from app_private.turnover_transfers where id=p_transfer_id for update;
 if t.successor_id is distinct from actor.id or not app_private.privacy_strong_session() or c.state not in('verified','rehearsal_verified')
  or not exists(select 1 from app_private.turnover_runs r join app_private.turnover_evidence e on e.run_id=r.id and e.part='complete' and e.restored
    where r.id=p_run_id and r.case_id=c.id and r.source_fingerprint=app_private.turnover_fingerprint(c.term_id))
  or coalesce(length(btrim(p_reference)),0) not between 3 and 500 then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_context_term,p_transfer_id,p_run_id,p_reference);prior:=app_private.begin_work_command('accept_turnover',p_key,payload);if prior is not null then return prior;end if;
 update app_private.turnover_transfers set accepted_at=statement_timestamp(),accepted_run=p_run_id,acceptance_reference=btrim(p_reference)where id=t.id;
 return app_private.turnover_receipt(c,'accept_turnover',p_key,payload,t.id);
end $$;
create function public.complete_turnover(p_case_id uuid,p_run_id uuid,p_expected_version integer,p_reference text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;t app_private.turnover_transfers;r jsonb;payload jsonb;prior jsonb;job app_private.turnover_runs;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;perform app_private.readiness_lock(c.term_id);actor:=app_private.turnover_manager(c);
 select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_run_id,p_expected_version,p_reference);prior:=app_private.begin_work_command('complete_turnover',p_key,payload);if prior is not null then return prior;end if;
 select*into job from app_private.turnover_runs where id=p_run_id and case_id=c.id;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if c.state not in('verified','rehearsal_verified')or job.id is null or job.source_fingerprint<>app_private.turnover_fingerprint(c.term_id)
  or job.disposition_head<>app_private.backup_disposition_fingerprint(c.term_id)
  or not exists(select 1 from app_private.turnover_transfers where case_id=c.id)
  or exists(select 1 from app_private.turnover_transfers where case_id=c.id and(accepted_at is null or accepted_run is distinct from job.id))
  or coalesce(length(btrim(p_reference)),0)not between 3 and 500 then raise exception using errcode='55000',message='command_turnover_acceptance_required';end if;
 if exists(select 1 from app_private.turnover_obligations o where o.case_id=c.id and o.resolution='carry'and not exists(
  select 1 from app_private.turnover_transfers planned where planned.case_id=c.id and planned.successor_id=o.successor_id
   and planned.accepted_run=job.id and planned.accepted_at is not null and o.work_id=any(planned.work_ids)))then
  raise exception using errcode='55000',message='command_turnover_carry_acceptance_required';end if;
 insert into app_private.turnover_permits(term_id,transaction_id,backend_id,actor_id,operation)values(c.term_id,txid_current(),pg_backend_pid(),auth.uid(),'transfer');
 for t in select*from app_private.turnover_transfers where case_id=c.id loop
  if not app_private.turnover_person(t.successor_id,actor.organization_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
  for r in select*from jsonb_array_elements(t.role_scopes)loop
   update public.role_assignments set status='revoked'where id=(r->>'id')::uuid and term_id=c.term_id and version=(r->>'version')::integer and status='active';
   if not found then raise exception using errcode='40001',message='command_stale_version';end if;
  end loop;
  for r in select*from jsonb_array_elements(t.grant_scopes)loop
   update public.record_grants set revoked_at=statement_timestamp()where id=(r->>'id')::uuid and term_id=c.term_id and version=(r->>'version')::integer and revoked_at is null;
   if not found then raise exception using errcode='40001',message='command_stale_version';end if;
  end loop;
  insert into app_private.turnover_archive_grants(term_id,transfer_id,work_id,recipient_id,expires_at)
   select c.term_id,t.id,ids.work_id,t.successor_id,(select ends_at from public.term_memberships where id=t.successor_id)from unnest(t.work_ids)ids(work_id)
    join public.work_items w on w.id=ids.work_id where w.classification='ordinary'and app_private.retention_work_category(w.id)='operational';
 end loop;
 update public.terms set state='archived'where id=c.term_id;
 update app_private.turnover_cases set version=version+1,state=case when state='verified'then'complete'else'rehearsal_complete'end where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'complete_turnover',p_key,payload);
end $$;
create function app_private.turnover_work_projection(w public.work_items) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',w.id,'title',w.title,'reference',ref.reference_text,'kind',w.kind,'summary',w.safe_summary,
 'sourceTerm',t.label,'owner',w.owner_display_name,'dueOn',w.due_on,'dueAt',w.due_at,
 'body',case when w.kind='task'then(select body from public.tasks where work_item_id=w.id)else(select body from public.deliverables where work_item_id=w.id)end)
 from public.terms t left join public.work_references ref on ref.work_item_id=w.id where t.id=w.term_id;
$$;
create function public.read_turnover(p_term_id uuid,p_case_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;c app_private.turnover_cases;manager boolean:=false;units jsonb:='[]';work jsonb:='[]';people jsonb:='[]';successors jsonb:='[]';
 approvals jsonb:='[]';roles jsonb:='[]';grants jsonb:='[]';transfers jsonb:='[]';runs jsonb:='[]';categories jsonb:='[]';result jsonb;
begin
 actor:=app_private.request_actor(p_term_id,false);
 select x.*into c from app_private.turnover_cases x join public.terms t on t.id=x.term_id and t.organization_id=actor.organization_id
 where(p_case_id is null or x.id=p_case_id)and(x.term_id=p_term_id and x.custodian_id=actor.id and app_private.privacy_custodian(p_term_id)
  or exists(select 1 from app_private.turnover_transfers s where s.case_id=x.id and s.successor_id=actor.id))order by x.created_at desc limit 1;
 manager:=c.id is not null and c.term_id=p_term_id and c.custodian_id=actor.id and app_private.privacy_custodian(p_term_id)and app_private.privacy_strong_session();
 if app_private.privacy_custodian(p_term_id)and app_private.privacy_strong_session() then
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'reference',approval_reference,'scope',evidence_scope)),'[]')into approvals
   from app_private.turnover_approvals where term_id=p_term_id and custodian_id=actor.id and expires_at>statement_timestamp();
 end if;
 if manager then
  select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'name',u.name,'owner',x.owner_id,'checked',x.id is not null)order by u.name),'[]')into units
   from public.org_units u left join app_private.turnover_unit_checks x on x.case_id=c.id and x.unit_id=u.id where u.term_id=c.term_id and u.archived_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'version',w.version,'title',case when public.can_access_work(w.id,'detail')then w.title else'Restricted work'end,
   'reference',ref.reference_text,'unit',(select name from public.org_units where id=w.lead_unit_id),'state',s.semantic_category,'classification',app_private.retention_work_category(w.id),
   'resolution',o.resolution,'recordedVersion',o.work_version,'owner',o.owner_id,'successor',o.successor_id,
   'transferable',w.classification='ordinary'and app_private.retention_work_category(w.id)='operational'and w.kind in('task','deliverable')and public.can_access_work(w.id,'detail'))order by w.id),'[]')into work
   from public.work_items w join public.status_definitions s on s.id=w.status_id left join public.work_references ref on ref.work_item_id=w.id
   left join app_private.turnover_obligations o on o.case_id=c.id and o.work_id=w.id where w.term_id=c.term_id and w.archived_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('id',tm.id,'name',m.display_name)order by m.display_name),'[]')into people from public.term_memberships tm
   join public.members m on m.id=tm.member_id where tm.term_id=c.term_id and app_private.turnover_person(tm.id,actor.organization_id);
  select coalesce(jsonb_agg(jsonb_build_object('id',tm.id,'name',m.display_name,'term',t.label,'termId',t.id)order by t.label,m.display_name),'[]')into successors
   from public.term_memberships tm join public.members m on m.id=tm.member_id join public.terms t on t.id=tm.term_id
   where tm.term_id<>c.term_id and app_private.turnover_person(tm.id,actor.organization_id)and t.state in('draft','active','frozen');
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',m.display_name||' · '||r.name,'version',a.version)order by m.display_name,r.name),'[]')into roles
   from public.role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id
   join public.members m on m.id=tm.member_id where a.term_id=c.term_id and a.status='active';
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',case when w.classification='ordinary'then w.title else'Restricted record scope'end,'version',g.version)order by g.id),'[]')into grants
   from public.record_grants g join public.work_items w on w.id=g.work_item_id where g.term_id=c.term_id and g.revoked_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('category',category,'disposition',disposition,'rows',rows,'reviewOn',review_on)),'[]')into categories
   from(select category,disposition,count(*)rows,min(review_on)review_on from app_private.turnover_entries where case_id=c.id group by category,disposition)q;
 end if;
 if c.id is not null then
  select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'successor',t.successor_id,'name',m.display_name,'term',target.label,
    'reference',t.reference,'accepted',t.accepted_at is not null,'acceptedRun',t.accepted_run,
    'work',case when manager or c.state in('verified','rehearsal_verified','complete','rehearsal_complete')then coalesce((select jsonb_agg(app_private.turnover_work_projection(w))
      from public.work_items w where w.id=any(t.work_ids)and w.classification='ordinary'and app_private.retention_work_category(w.id)='operational'),'[]')else'[]'::jsonb end)
    order by t.id),'[]')into transfers from app_private.turnover_transfers t join public.term_memberships tm on tm.id=t.successor_id
    join public.members m on m.id=tm.member_id join public.terms target on target.id=tm.term_id where t.case_id=c.id and(manager or t.successor_id=actor.id);
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'at',q.created_at,'rows',case when manager then q.expected_rows end,'files',case when manager then q.expected_files end,
   'fingerprint',case when manager then q.source_fingerprint end,'parts',case when manager then(select count(*)from app_private.turnover_evidence where run_id=q.id and part<>'complete')end,
   'failure',case when manager then(select jsonb_build_object('phase',f.phase,'reason',f.reason)from app_private.turnover_failures f where f.run_id=q.id order by f.created_at desc,f.id desc limit 1)end,
   'restored',exists(select 1 from app_private.turnover_evidence where run_id=q.id and part='complete'and restored))order by q.created_at desc,q.id),'[]')into runs
    from(select*from app_private.turnover_runs where case_id=c.id order by created_at desc,id desc limit 10)q;
 end if;
 result:=jsonb_build_object('canManage',manager,'approvals',approvals,'case',case when c.id is not null then jsonb_build_object('id',c.id,'version',c.version,'state',c.state,
  'term',(select label from public.terms where id=c.term_id),'custodian',(select m.display_name from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.id=c.custodian_id),
  'scope',(select evidence_scope from app_private.turnover_approvals where id=c.approval_id))end,
  'units',units,'work',work,'people',people,'successors',successors,'roles',roles,'grants',grants,'categories',categories,'transfers',transfers,'runs',runs,
  'hasArchive',exists(select 1 from app_private.turnover_archive_grants g where g.recipient_id=actor.id and g.revoked_at is null and g.expires_at>statement_timestamp()));
 perform app_private.record_content_read('read_turnover',p_term_id,c.id,c.id is not null);return result;
end $$;
create function public.read_archived_work(p_term_id uuid,p_work_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;items jsonb;detail jsonb;
begin
 actor:=app_private.request_actor(p_term_id,false);
 select coalesce(jsonb_agg(app_private.turnover_work_projection(w)order by w.title,w.id),'[]')into items
  from public.work_items w where w.id in(select g.work_id from app_private.turnover_archive_grants g join public.terms t on t.id=g.term_id and t.organization_id=actor.organization_id
   where g.recipient_id=actor.id and g.revoked_at is null and g.expires_at>statement_timestamp())
   and w.classification='ordinary'and app_private.retention_work_category(w.id)='operational'and(p_work_id is null or w.id=p_work_id);
 if p_work_id is not null then select value into detail from jsonb_array_elements(items)value where value->>'id'=p_work_id::text;end if;
 perform app_private.record_content_read('read_archived_work',p_term_id,case when detail is not null then p_work_id end,jsonb_array_length(items)>0);
 return jsonb_build_object('items',items,'detail',detail);
end $$;

insert into public.restricted_read_endpoints(endpoint,argument_types)values('read_turnover','uuid, uuid'),('read_archived_work','uuid, uuid');
do $$declare t text;f record;
begin
 foreach t in array array['turnover_approvals','turnover_cases','turnover_unit_checks','turnover_obligations','turnover_entries','turnover_runs','turnover_evidence',
  'turnover_transfers','turnover_archive_grants','turnover_corrections','turnover_events','turnover_permits','turnover_failures']loop
  insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
   values('app_private.'||t,'security','term',array['id'],format('select app_private.disposition_key(%L,array[x.id::text])target_hash,''security''category,x.id root_id,
    app_private.retention_is_held($1,''security'',x.id,null)held,encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'')state_hash from app_private.%I x where x.term_id=$1',
    'app_private.'||t,t),app_private.disposition_structure('app_private.'||t),true);
 end loop;
 for f in select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)args from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='app_private'and p.proname like'turnover_%'or n.nspname='public'and p.proname in(
 'prepare_turnover','update_turnover','freeze_term','run_archive','verify_turnover_archive','accept_turnover','complete_turnover','read_turnover','read_archived_work')loop
  execute format('revoke all on function %I.%I(%s)from public,anon,authenticated,service_role',f.nspname,f.proname,f.args);
  if f.nspname='public'then execute format('grant execute on function public.%I(%s)to authenticated',f.proname,f.args);end if;
 end loop;
end $$;
commit;
