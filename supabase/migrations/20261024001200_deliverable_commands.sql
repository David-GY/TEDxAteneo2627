begin;
alter table public.deliverables
  add column workflow_state text not null default 'draft' check(workflow_state in ('proposed','draft','in_progress','submitted','accepted','cancelled')),
  add column criteria_revision integer not null default 1 check(criteria_revision>0),
  add column final_evidence text check(length(final_evidence)<=4000);

create table public.deliverable_revisions (
  id uuid primary key default gen_random_uuid(), work_item_id uuid not null references public.deliverables(work_item_id),
  work_version integer not null, criteria_revision integer not null, workflow_state text not null,
  title text not null, outcome text not null, acceptance_criteria text not null, owner_member_id uuid not null references public.members(id),
  due_on date, due_at timestamptz, reason text not null, final_evidence text, review_evidence text,
  actor_id uuid not null references auth.users(id), recorded_at timestamptz not null default statement_timestamp(),
  unique(work_item_id,work_version)
);
-- P29 will add governed decisions. P09 can only consume trusted, revision-bound non-applicability assessments.
create table public.deliverable_gate_assessments (
  work_item_id uuid not null references public.deliverables(work_item_id), work_version integer not null,
  gate text not null check(gate in ('finance','publicity','contributions')),
  disposition text not null check(disposition='not_applicable'), reason text not null check(length(btrim(reason)) between 1 and 2000),
  assessed_by uuid not null references public.term_memberships(id), assessed_at timestamptz not null default statement_timestamp(),
  primary key(work_item_id,work_version,gate)
);
alter table public.deliverable_revisions enable row level security;
alter table public.deliverable_revisions force row level security;
alter table public.deliverable_gate_assessments enable row level security;
alter table public.deliverable_gate_assessments force row level security;
revoke all on public.deliverable_revisions,public.deliverable_gate_assessments from public,anon,authenticated,service_role;
grant select on public.deliverable_revisions to authenticated;
create policy deliverable_revision_read on public.deliverable_revisions for select to authenticated using(public.can_access_work(work_item_id,'detail'));
create function app_private.deny_deliverable_history() returns trigger language plpgsql set search_path='' as $$begin
  raise exception using errcode='42501',message='work_history_immutable';end$$;
revoke all on function app_private.deny_deliverable_history() from public,anon,authenticated,service_role;
create trigger deliverable_revision_immutable before update or delete on public.deliverable_revisions for each row execute function app_private.deny_deliverable_history();
create trigger deliverable_gate_immutable before update or delete on public.deliverable_gate_assessments for each row execute function app_private.deny_deliverable_history();

create function app_private.manage_deliverable(p_term uuid,p_unit uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select p_unit is not null and public.has_capability(p_term,'committee.manage',p_unit)
$$;
alter function app_private.deliverable_summary(public.work_items,public.deliverables) rename to deliverable_summary_p08;
create function app_private.deliverable_summary(w public.work_items,d public.deliverables) returns jsonb
language sql stable set search_path='' as $$select app_private.deliverable_summary_p08(w,d)||jsonb_build_object('workflowState',d.workflow_state)$$;
revoke all on function app_private.deliverable_summary(public.work_items,public.deliverables) from public,anon,authenticated,service_role;
-- Explicit configured lead-unit authority includes the record, never unrelated units or terms.
create or replace function public.can_access_work(p_work_item_id uuid,p_level text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare w public.work_items; member uuid;begin
  if p_level not in ('summary','detail','edit','owner') or p_level is null then return false;end if;
  select * into w from public.work_items where id=p_work_item_id;
  if not found then return false;end if;
  select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id);
  if member=w.owner_member_id then return true;end if;
  if p_level='owner' then return false;end if;
  if w.kind='deliverable' and app_private.manage_deliverable(w.term_id,w.lead_unit_id) then return true;end if;
  if p_level='summary' and w.classification='ordinary' and public.has_capability(w.term_id,'workspace.read') then return true;end if;
  if public.has_work_capability(w.id,'committee.manage') then return true;end if;
  if p_level<>'edit' and public.has_work_capability(w.id,'workspace.read') then return true;end if;
  return exists(select 1 from public.record_grants g where g.work_item_id=w.id and app_private.work_grant_matches(g)
    and (p_level<>'edit' or (member is not null and g.grant_kind='edit')));
end
$$;
grant execute on function public.can_access_work(uuid,text) to authenticated;

-- Preserve old non-deliverable commands but close the incomplete deliverable path.
alter function public.create_work_item(uuid,text,text,text,text,text,uuid,uuid,integer,uuid) set schema app_private;
create function public.create_work_item(p_term_id uuid,p_kind text,p_title text,p_safe_summary text,p_body text,p_classification text,
  p_lead_unit_id uuid default null,p_parent_id uuid default null,p_expected_parent_version integer default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$begin
  if p_kind='deliverable' then raise exception using errcode='55000',message='command_dependency_blocked'; end if;
  return app_private.create_work_item(p_term_id,p_kind,p_title,p_safe_summary,p_body,p_classification,p_lead_unit_id,p_parent_id,p_expected_parent_version,p_request_id);
end$$;
alter function public.update_work_item(uuid,text,text,text,integer,uuid) set schema app_private;
create function public.update_work_item(p_work_item_id uuid,p_title text,p_safe_summary text,p_body text,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$begin
  if exists(select 1 from public.work_items where id=p_work_item_id and kind='deliverable') then raise exception using errcode='55000',message='command_dependency_blocked'; end if;
  return app_private.update_work_item(p_work_item_id,p_title,p_safe_summary,p_body,p_expected_version,p_request_id);
end$$;
revoke all on function app_private.create_work_item(uuid,text,text,text,text,text,uuid,uuid,integer,uuid),app_private.update_work_item(uuid,text,text,text,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_work_item(uuid,text,text,text,text,text,uuid,uuid,integer,uuid),public.update_work_item(uuid,text,text,text,integer,uuid) to authenticated;

create function app_private.validate_deliverable(p_term uuid,p_data jsonb) returns void
language plpgsql set search_path='' as $$begin
  if p_data is null or jsonb_typeof(p_data)<>'object' or exists(select 1 from jsonb_object_keys(p_data) k where k not in
    ('title','summary','body','ownerId','leadUnitId','phase','outcome','criteria','dueOn','dueAt','classification','reason'))
    or exists(select 1 from jsonb_each(p_data) e where jsonb_typeof(e.value) not in ('string','null'))
    or coalesce(length(btrim(p_data->>'title')),0) not between 1 and 240
    or coalesce(length(p_data->>'summary'),2001)>2000 or coalesce(length(p_data->>'body'),20001)>20000
    or coalesce(length(btrim(p_data->>'phase')),0) not between 1 and 80
    or coalesce(length(btrim(p_data->>'outcome')),0) not between 1 and 4000
    or coalesce(length(btrim(p_data->>'criteria')),0) not between 1 and 8000
    or coalesce(p_data->>'classification','') not in ('ordinary','restricted')
    or num_nonnulls(nullif(p_data->>'dueOn',''),nullif(p_data->>'dueAt',''))<>1
    or coalesce(length(p_data->>'reason'),0)>2000 then
      raise exception using errcode='22023',message='command_validation_failed'; end if;
  if not exists(select 1 from public.members m join public.term_memberships tm on tm.member_id=m.id
    where m.id=(p_data->>'ownerId')::uuid and tm.term_id=p_term and m.account_state='active' and tm.status='active'
      and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp())
    or not exists(select 1 from public.org_units where id=(p_data->>'leadUnitId')::uuid and term_id=p_term and archived_at is null) then
    raise exception using errcode='22023',message='command_validation_failed'; end if;
  perform nullif(p_data->>'dueOn','')::date; perform nullif(p_data->>'dueAt','')::timestamptz;
  if not isfinite(nullif(p_data->>'dueOn','')::date) or not isfinite(nullif(p_data->>'dueAt','')::timestamptz) then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
create function app_private.deliverable_status(p_org uuid,p_term uuid,p_state text) returns uuid
language plpgsql set search_path='' as $$declare status uuid; semantic text;begin
  semantic:=case p_state when 'proposed' then 'draft' when 'draft' then 'draft' when 'in_progress' then 'active' when 'submitted' then 'active' when 'accepted' then 'completed' when 'cancelled' then 'cancelled' end;
  if semantic is null then raise exception using errcode='22023',message='command_validation_failed';end if;
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)
    values(p_org,p_term,'deliverable','p09_'||p_state,semantic,replace(p_state,'_',' ')) on conflict(term_id,resource_kind,stable_key) do nothing;
  select id into status from public.status_definitions where term_id=p_term and resource_kind='deliverable' and stable_key='p09_'||p_state and semantic_category=semantic;
  if status is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  return status;
end$$;
create function app_private.snapshot_deliverable(w public.work_items,p_reason text,p_review text default null) returns void
language sql set search_path='' as $$
  insert into public.deliverable_revisions(work_item_id,work_version,criteria_revision,workflow_state,title,outcome,acceptance_criteria,owner_member_id,due_on,due_at,reason,final_evidence,review_evidence,actor_id)
  select w.id,w.version,d.criteria_revision,d.workflow_state,w.title,coalesce(d.outcome,''),coalesce(d.acceptance_criteria,''),w.owner_member_id,w.due_on,w.due_at,p_reason,d.final_evidence,p_review,auth.uid()
  from public.deliverables d where d.work_item_id=w.id
$$;
create function public.create_deliverable(p_term_id uuid,p_data jsonb,p_propose boolean,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare tm public.term_memberships; w public.work_items; result jsonb; payload jsonb; new_state text; owner_name text;begin
  select * into tm from public.term_memberships where id=public.current_term_membership(p_term_id);
  if not found or not public.has_capability(p_term_id,'workspace.read') or not exists(select 1 from public.terms where id=p_term_id and state='active') then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_data,p_propose);
  result:=app_private.begin_work_command('create_deliverable',p_request_id,payload);
  if result is not null then
    if not public.can_access_work((result->>'workItemId')::uuid,'detail') then raise exception using errcode='42501',message='command_permission_denied';end if;return result;end if;
  perform app_private.validate_deliverable(p_term_id,p_data);
  if p_propose is null or (not p_propose and not app_private.manage_deliverable(p_term_id,(p_data->>'leadUnitId')::uuid))
    or (p_propose and (p_data->>'ownerId')::uuid<>tm.member_id) then raise exception using errcode='42501',message='command_permission_denied';end if;
  new_state:=case when p_propose then 'proposed' else 'draft' end;
  select display_name into owner_name from public.members where id=(p_data->>'ownerId')::uuid;
  insert into public.work_items(organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,status_id,due_on,due_at,original_due_on,original_due_at)
  values(tm.organization_id,p_term_id,'deliverable',btrim(p_data->>'title'),p_data->>'summary',p_data->>'classification',(p_data->>'ownerId')::uuid,owner_name,(p_data->>'leadUnitId')::uuid,
    app_private.deliverable_status(tm.organization_id,p_term_id,new_state),nullif(p_data->>'dueOn','')::date,nullif(p_data->>'dueAt','')::timestamptz,nullif(p_data->>'dueOn','')::date,nullif(p_data->>'dueAt','')::timestamptz) returning * into w;
  insert into public.deliverables(work_item_id,organization_id,term_id,body,phase_key,outcome,acceptance_criteria,workflow_state)
    values(w.id,w.organization_id,w.term_id,p_data->>'body',p_data->>'phase',p_data->>'outcome',p_data->>'criteria',new_state);
  insert into public.record_grants(organization_id,term_id,work_item_id,member_id,grant_kind,expires_at,grantor_id)
    values(w.organization_id,w.term_id,w.id,tm.member_id,'edit',tm.ends_at,tm.id);
  perform app_private.snapshot_deliverable(w,'Created '||new_state);
  return app_private.finish_work_command(w,'create_deliverable',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version),'["created","criteria","owner","deadline"]');
end$$;
create function public.update_deliverable(p_work_item_id uuid,p_data jsonb,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.work_items; d public.deliverables; payload jsonb; result jsonb; manager boolean;begin
  select * into w from public.work_items where id=p_work_item_id and kind='deliverable';
  if not found or not public.can_access_work(w.id,'edit') then raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_work_item_id,p_data,p_expected_version);result:=app_private.begin_work_command('update_deliverable',p_request_id,payload);
  if result is not null then return result;end if;
  select * into w from public.work_items where id=p_work_item_id for update;
  if not public.can_access_work(w.id,'edit') or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
  if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  select * into d from public.deliverables where work_item_id=w.id;
  if d.workflow_state not in ('proposed','draft','in_progress') then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  perform app_private.validate_deliverable(w.term_id,p_data);
  manager:=app_private.manage_deliverable(w.term_id,w.lead_unit_id) and app_private.manage_deliverable(w.term_id,(p_data->>'leadUnitId')::uuid);
  if w.classification<>p_data->>'classification' then raise exception using errcode='22023',message='command_validation_failed';end if;
  if (w.owner_member_id<>(p_data->>'ownerId')::uuid or w.lead_unit_id is distinct from (p_data->>'leadUnitId')::uuid) and not manager then raise exception using errcode='42501',message='command_permission_denied';end if;
  if coalesce(length(btrim(p_data->>'reason')),0)=0 then raise exception using errcode='22023',message='command_validation_failed';end if;
  update public.work_items set title=btrim(p_data->>'title'),safe_summary=p_data->>'summary',classification=p_data->>'classification',owner_member_id=(p_data->>'ownerId')::uuid,
    owner_display_name=(select display_name from public.members where id=(p_data->>'ownerId')::uuid),lead_unit_id=(p_data->>'leadUnitId')::uuid,
    due_on=nullif(p_data->>'dueOn','')::date,due_at=nullif(p_data->>'dueAt','')::timestamptz where id=w.id returning * into w;
  update public.deliverables set body=p_data->>'body',phase_key=p_data->>'phase',outcome=p_data->>'outcome',acceptance_criteria=p_data->>'criteria',
    criteria_revision=criteria_revision+case when outcome is distinct from p_data->>'outcome' or acceptance_criteria is distinct from p_data->>'criteria' then 1 else 0 end,
    final_evidence=null where work_item_id=w.id;
  perform app_private.snapshot_deliverable(w,p_data->>'reason');
  return app_private.finish_work_command(w,'update_deliverable',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version),'["content","criteria","owner","deadline","reason"]');
end$$;
create function public.transition_deliverable(p_work_item_id uuid,p_action text,p_reason text,p_evidence text,p_expected_version integer,p_request_id uuid,p_criteria_revision integer default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.work_items; d public.deliverables; tm public.term_memberships; result jsonb; payload jsonb; target text; manager boolean;begin
  select * into w from public.work_items where id=p_work_item_id and kind='deliverable';
  select * into tm from public.term_memberships where id=public.current_term_membership(w.term_id);
  if w.id is null or tm.id is null or not public.can_access_work(w.id,'edit') then raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_work_item_id,p_action,p_reason,p_evidence,p_expected_version,p_criteria_revision);result:=app_private.begin_work_command('transition_deliverable',p_request_id,payload);
  if result is not null then return result;end if;
  select * into w from public.work_items where id=p_work_item_id for update;
  if not public.can_access_work(w.id,'edit') or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
  if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  select * into d from public.deliverables where work_item_id=w.id;
  manager:=app_private.manage_deliverable(w.term_id,w.lead_unit_id);
  if coalesce(length(btrim(p_reason)),0) not between 1 and 2000 or coalesce(length(p_evidence),0)>4000 then raise exception using errcode='22023',message='command_validation_failed';end if;
  if p_action='approve_proposal' and d.workflow_state='proposed' and manager then target:='draft';
  elsif p_action='start' and d.workflow_state='draft' and (manager or tm.member_id=w.owner_member_id) then target:='in_progress';
  elsif p_action='submit' and d.workflow_state in ('draft','in_progress') and tm.member_id=w.owner_member_id then
    if coalesce(length(btrim(p_evidence)),0)=0 or d.is_blocked then raise exception using errcode='55000',message='command_dependency_blocked';end if;
    perform app_private.validate_deliverable(w.term_id,jsonb_build_object('title',w.title,'summary',w.safe_summary,'body',d.body,'ownerId',w.owner_member_id,'leadUnitId',w.lead_unit_id,'phase',d.phase_key,'outcome',d.outcome,'criteria',d.acceptance_criteria,'dueOn',w.due_on,'dueAt',w.due_at,'classification',w.classification));
    target:='submitted';
  elsif p_action='revise' and d.workflow_state='submitted' and (manager or tm.member_id=w.owner_member_id) then target:='draft';
  elsif p_action='cancel' and d.workflow_state not in ('accepted','cancelled') and manager then target:='cancelled';
  elsif p_action='accept' and d.workflow_state='submitted' and manager and tm.member_id<>w.owner_member_id then
    if p_criteria_revision is distinct from d.criteria_revision or nullif(btrim(p_evidence),'') is null or d.is_blocked or nullif(btrim(d.final_evidence),'') is null or not exists(select 1 from public.members m join public.term_memberships mt on mt.member_id=m.id and mt.term_id=w.term_id
      where m.id=w.owner_member_id and m.account_state='active' and mt.status='active' and mt.joined_at<=statement_timestamp() and mt.ends_at>statement_timestamp())
      or (select count(*) from public.deliverable_gate_assessments g join public.term_memberships assessor on assessor.id=g.assessed_by
        join public.members m on m.id=assessor.member_id
        where g.work_item_id=w.id and g.work_version=w.version and g.disposition='not_applicable' and assessor.term_id=w.term_id and assessor.member_id<>w.owner_member_id
          and assessor.status='active' and m.account_state='active' and assessor.joined_at<=statement_timestamp() and assessor.ends_at>statement_timestamp()
          and exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id and r.state='active'
            join public.role_permissions p on p.role_id=r.id and p.capability='committee.manage' and p.allowed_scope=a.scope_type
            where a.term_membership_id=assessor.id and a.status='active' and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp()
              and ((a.scope_type='unit' and a.unit_id=w.lead_unit_id and exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null
                where um.term_membership_id=assessor.id and um.unit_id=w.lead_unit_id and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())))))<>3 then
      raise exception using errcode='55000',message='command_dependency_blocked';end if;
    target:='accepted';
  else raise exception using errcode='42501',message='command_permission_denied';end if;
  update public.work_items set status_id=app_private.deliverable_status(w.organization_id,w.term_id,target) where id=w.id returning * into w;
  update public.deliverables set workflow_state=target,final_evidence=case when target='submitted' then btrim(p_evidence) when target='draft' then null else final_evidence end where work_item_id=w.id;
  perform app_private.snapshot_deliverable(w,p_reason,case when target='accepted' then p_evidence else null end);
  return app_private.finish_work_command(w,'transition_deliverable',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version),'["state","evidence","reason"]');
end$$;

create function public.read_deliverable_authoring(p_term_id uuid,p_work_item_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare tm public.term_memberships; w public.work_items; d public.deliverables; manager boolean;begin
  select * into tm from public.term_memberships where id=public.current_term_membership(p_term_id);
  if not found or not public.has_capability(p_term_id,'workspace.read') then return null;end if;
  if p_work_item_id is not null then
    select * into w from public.work_items where id=p_work_item_id and term_id=p_term_id and kind='deliverable';
    if not found or not public.can_access_work(w.id,'edit') then return null;end if;
    select * into d from public.deliverables where work_item_id=w.id;
    manager:=app_private.manage_deliverable(w.term_id,w.lead_unit_id);
  end if;
  return jsonb_build_object('memberId',tm.member_id,'version',w.version,'criteriaRevision',d.criteria_revision,'state',d.workflow_state,'manager',coalesce(manager,false),
    'editable',coalesce(d.workflow_state in ('proposed','draft','in_progress') and w.archived_at is null and exists(select 1 from public.terms where id=p_term_id and state='active'),false),
    'actions',case when w.archived_at is not null or not exists(select 1 from public.terms where id=p_term_id and state='active') then '[]'::jsonb else to_jsonb(array_remove(array[
      case when manager and d.workflow_state='proposed' then 'approve_proposal' end,
      case when (manager or tm.member_id=w.owner_member_id) and d.workflow_state='draft' then 'start' end,
      case when tm.member_id=w.owner_member_id and d.workflow_state in ('draft','in_progress') then 'submit' end,
      case when manager and tm.member_id<>w.owner_member_id and d.workflow_state='submitted' then 'accept' end,
      case when (manager or tm.member_id=w.owner_member_id) and d.workflow_state='submitted' then 'revise' end,
      case when manager and d.workflow_state not in ('accepted','cancelled') then 'cancel' end],null)) end,
    'owners',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'name',m.display_name) order by m.display_name,m.id) from public.members m join public.term_memberships mt on mt.member_id=m.id
      where mt.term_id=p_term_id and mt.status='active' and m.account_state='active' and mt.joined_at<=statement_timestamp() and mt.ends_at>statement_timestamp()
        and (m.id=tm.member_id or exists(select 1 from public.org_units u where u.term_id=p_term_id and u.archived_at is null and app_private.manage_deliverable(p_term_id,u.id)))),'[]'::jsonb),
    'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name,'canManage',app_private.manage_deliverable(p_term_id,u.id)) order by u.name,u.id) from public.org_units u where u.term_id=p_term_id and u.archived_at is null),'[]'::jsonb),
    'queue',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'title',q.title)) from public.work_items q join public.deliverables c on c.work_item_id=q.id
      where q.term_id=p_term_id and q.archived_at is null and c.workflow_state not in ('accepted','cancelled') and app_private.manage_deliverable(q.term_id,q.lead_unit_id)
      and not exists(select 1 from public.members m join public.term_memberships mt on mt.member_id=m.id where m.id=q.owner_member_id and m.account_state='active' and mt.term_id=q.term_id and mt.status='active' and mt.joined_at<=statement_timestamp() and mt.ends_at>statement_timestamp())),'[]'::jsonb),
    'data',case when w.id is not null then jsonb_build_object('title',w.title,'summary',w.safe_summary,'body',d.body,'ownerId',w.owner_member_id,'leadUnitId',w.lead_unit_id,'phase',d.phase_key,'outcome',d.outcome,'criteria',d.acceptance_criteria,'dueOn',w.due_on,'dueAt',w.due_at,'classification',w.classification,'reason','') else null end);
end$$;
revoke all on function app_private.manage_deliverable(uuid,uuid),app_private.validate_deliverable(uuid,jsonb),app_private.deliverable_status(uuid,uuid,text),app_private.snapshot_deliverable(public.work_items,text,text),
  public.create_deliverable(uuid,jsonb,boolean,uuid),public.update_deliverable(uuid,jsonb,integer,uuid),public.transition_deliverable(uuid,text,text,text,integer,uuid,integer),public.read_deliverable_authoring(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.create_deliverable(uuid,jsonb,boolean,uuid),public.update_deliverable(uuid,jsonb,integer,uuid),public.transition_deliverable(uuid,text,text,text,integer,uuid,integer),public.read_deliverable_authoring(uuid,uuid) to authenticated;
commit;
