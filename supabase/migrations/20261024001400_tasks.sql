begin;
alter table public.tasks add column assignee_id uuid,add column assigned_unit_id uuid,
  add column workflow_state text not null default 'todo' check(workflow_state in ('todo','in_progress','blocked','ready_for_review','done','cancelled')),
  add column checklist jsonb not null default '[]'::jsonb check(jsonb_typeof(checklist)='array' and jsonb_array_length(checklist)<=50),
  add column task_type text not null default 'ordinary' check(task_type in ('ordinary','review_required','governed')),
  add column blocked_reason text check(length(blocked_reason)<=2000),add column completion_evidence text check(length(completion_evidence)<=4000),add column assignee_name text check(length(assignee_name)<=200),
  add constraint task_assignee_term foreign key(organization_id,term_id,assignee_id) references public.term_memberships(organization_id,term_id,member_id),
  add constraint task_unit_term foreign key(organization_id,term_id,assigned_unit_id) references public.org_units(organization_id,term_id,id);
create table public.task_collaborators(
  organization_id uuid not null,term_id uuid not null,work_item_id uuid not null,member_id uuid not null,
  primary key(work_item_id,member_id),
  foreign key(organization_id,term_id,work_item_id) references public.work_items(organization_id,term_id,id),
  foreign key(organization_id,term_id,member_id) references public.term_memberships(organization_id,term_id,member_id),
  foreign key(work_item_id) references public.tasks(work_item_id)
);
alter table public.task_collaborators enable row level security;
alter table public.task_collaborators force row level security;
revoke all on public.task_collaborators from public,anon,authenticated,service_role;
grant select on public.task_collaborators to authenticated;
create policy task_collaborators_read on public.task_collaborators for select to authenticated using(public.can_access_work(work_item_id,'detail'));
create index tasks_assignee_scope on public.tasks(term_id,assignee_id,work_item_id);
create index tasks_receiving_scope on public.tasks(term_id,assigned_unit_id,work_item_id);
create index task_collaborators_member_scope on public.task_collaborators(term_id,member_id,work_item_id);
update public.tasks t set assignee_id=w.owner_member_id,assignee_name=w.owner_display_name,assigned_unit_id=w.lead_unit_id from public.work_items w where w.id=t.work_item_id;
create table public.task_revisions(
  work_item_id uuid not null references public.tasks(work_item_id),work_version integer not null,
  state text not null,assignee_id uuid references public.members(id),assignee_name text,assigned_unit_id uuid references public.org_units(id),collaborators jsonb not null,title text not null,due_on date,due_at timestamptz,
  body text not null,checklist jsonb not null,evidence text,reason text not null,actor_id uuid not null references auth.users(id),recorded_at timestamptz not null default statement_timestamp(),
  primary key(work_item_id,work_version)
);
alter table public.task_revisions enable row level security;
alter table public.task_revisions force row level security;
revoke all on public.task_revisions from public,anon,authenticated,service_role;
grant select on public.task_revisions to authenticated;
create policy task_revisions_read on public.task_revisions for select to authenticated using(public.can_access_work(work_item_id,'detail'));
create trigger task_revisions_immutable before update or delete on public.task_revisions for each row execute function app_private.deny_deliverable_history();
create function app_private.task_participant(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.tasks t join public.term_memberships m on m.id=public.current_term_membership(t.term_id)
    where t.work_item_id=p_id and (t.assignee_id=m.member_id or exists(select 1 from public.task_collaborators c where c.work_item_id=p_id and c.member_id=m.member_id))
      and (t.assigned_unit_id is null or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null where um.term_membership_id=m.id and um.unit_id=t.assigned_unit_id and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())))
$$;
create function app_private.task_manager(w public.work_items) returns boolean language sql stable set search_path='' as $$
  select (w.lead_unit_id is not null and public.has_capability(w.term_id,'committee.manage',w.lead_unit_id))
    or exists(select 1 from public.tasks t where t.work_item_id=w.id and t.assigned_unit_id is not null and public.has_capability(w.term_id,'committee.manage',t.assigned_unit_id))
    or public.has_work_capability(w.id,'committee.manage')
$$;
create function app_private.check_task_owner() returns trigger language plpgsql security definer set search_path='' as $$declare item uuid;begin
  if tg_table_name='tasks' then item:=new.work_item_id;else item:=new.id;end if;
  if exists(select 1 from public.work_items w join public.tasks t on t.work_item_id=w.id where w.id=item and w.owner_member_id is distinct from t.assignee_id) then raise exception using errcode='23514',message='task_owner_assignee_required';end if;return null;
end$$;
create constraint trigger task_owner_spine after insert or update on public.work_items deferrable initially deferred for each row execute function app_private.check_task_owner();
create constraint trigger task_assignee_spine after insert or update on public.tasks deferrable initially deferred for each row execute function app_private.check_task_owner();
revoke all on function app_private.check_task_owner() from public,anon,authenticated,service_role;
create or replace function public.can_access_work(p_work_item_id uuid,p_level text) returns boolean
language plpgsql stable security definer set search_path='' as $$declare w public.work_items; member uuid;begin
  if p_level not in ('summary','detail','edit','owner') or p_level is null then return false;end if;
  select * into w from public.work_items where id=p_work_item_id;if not found then return false;end if;
  select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id);
  if member=w.owner_member_id then return true;end if;if p_level='owner' then return false;end if;
  if w.kind='task' and (app_private.task_participant(w.id) or app_private.task_manager(w)) then return true;end if;
  if w.kind='deliverable' and app_private.manage_deliverable(w.term_id,w.lead_unit_id) then return true;end if;
  if p_level='summary' and w.classification='ordinary' and public.has_capability(w.term_id,'workspace.read') then return true;end if;
  if public.has_work_capability(w.id,'committee.manage') then return true;end if;
  if p_level<>'edit' and public.has_work_capability(w.id,'workspace.read') then return true;end if;
  return exists(select 1 from public.record_grants g where g.work_item_id=w.id and app_private.work_grant_matches(g) and (p_level<>'edit' or (member is not null and g.grant_kind='edit')));
end$$;
-- All task writes go through the task contract; keep request/announcement commands unchanged.
create or replace function public.create_work_item(p_term_id uuid,p_kind text,p_title text,p_safe_summary text,p_body text,p_classification text,
  p_lead_unit_id uuid default null,p_parent_id uuid default null,p_expected_parent_version integer default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$begin
  if p_kind in ('deliverable','task') then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  return app_private.create_work_item(p_term_id,p_kind,p_title,p_safe_summary,p_body,p_classification,p_lead_unit_id,p_parent_id,p_expected_parent_version,p_request_id);end$$;
create or replace function public.update_work_item(p_work_item_id uuid,p_title text,p_safe_summary text,p_body text,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$begin
  if exists(select 1 from public.work_items where id=p_work_item_id and kind in ('deliverable','task')) then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  return app_private.update_work_item(p_work_item_id,p_title,p_safe_summary,p_body,p_expected_version,p_request_id);end$$;

create function app_private.check_task_assignment(p_term uuid,p_assignee uuid,p_unit uuid,p_collaborators jsonb,p_actor uuid,p_lead uuid) returns void
language plpgsql set search_path='' as $$declare person uuid;begin
  if jsonb_typeof(p_collaborators) is distinct from 'array' or jsonb_array_length(p_collaborators)>30 then raise exception using errcode='22023',message='command_validation_failed';end if;
  if not (p_assignee=p_actor and p_unit is not distinct from p_lead) and not coalesce(public.has_capability(p_term,'committee.manage',p_unit),false) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  if jsonb_array_length(p_collaborators)>0 and not coalesce(public.has_capability(p_term,'committee.manage',p_unit),false) then raise exception using errcode='42501',message='command_permission_denied';end if;
  for person in select p_assignee union select value::uuid from jsonb_array_elements_text(p_collaborators) loop
    if person is null or not exists(select 1 from public.members m join public.term_memberships mt on mt.member_id=m.id where m.id=person and m.account_state='active' and mt.term_id=p_term and mt.status='active' and mt.joined_at<=statement_timestamp() and mt.ends_at>statement_timestamp())
      or (p_unit is not null and not exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null
        join public.term_memberships mt on mt.id=um.term_membership_id where mt.member_id=person and mt.term_id=p_term and um.unit_id=p_unit and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())) then
      raise exception using errcode='22023',message='command_validation_failed';end if;
  end loop;
end$$;
create function app_private.check_task_fields(p_data jsonb) returns void language plpgsql set search_path='' as $$begin
  if p_data is null or jsonb_typeof(p_data)<>'object' or exists(select 1 from jsonb_object_keys(p_data) k where k not in
    ('title','summary','body','leadUnitId','parentId','dueOn','dueAt','assigneeId','assignedUnitId','collaborators','checklist','taskType','classification','reason'))
    or exists(select 1 from jsonb_each(p_data) e where e.key not in ('collaborators','checklist') and jsonb_typeof(e.value) not in ('string','null'))
    or coalesce(length(btrim(p_data->>'title')),0) not between 1 and 240 or coalesce(length(p_data->>'summary'),2001)>2000 or coalesce(length(p_data->>'body'),20001)>20000
    or num_nonnulls(nullif(p_data->>'dueOn',''),nullif(p_data->>'dueAt',''))>1 or coalesce(length(p_data->>'reason'),0)>2000
    or (nullif(p_data->>'dueOn','') is not null and p_data->>'dueOn'!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
    or (nullif(p_data->>'dueAt','') is not null and p_data->>'dueAt'!~'T.*(Z|[+-][0-9]{2}:[0-9]{2})$')
    or coalesce(p_data->>'taskType','') not in ('ordinary','review_required','governed') or coalesce(p_data->>'classification','') not in ('ordinary','restricted')
    or jsonb_typeof(p_data->'checklist') is distinct from 'array' or jsonb_array_length(p_data->'checklist')>50 then raise exception using errcode='22023',message='command_validation_failed';end if;
  if exists(select 1 from jsonb_array_elements(p_data->'checklist') e where jsonb_typeof(e)<>'object' or (select count(*) from jsonb_object_keys(e))<>3
    or not(e ?& array['id','text','done']) or coalesce(e->>'id','')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or jsonb_typeof(e->'text')<>'string' or length(btrim(e->>'text')) not between 1 and 400 or jsonb_typeof(e->'done')<>'boolean')
    or (select count(*)<>count(distinct e->>'id') from jsonb_array_elements(p_data->'checklist')e)
    or not isfinite(nullif(p_data->>'dueOn','')::date) or not isfinite(nullif(p_data->>'dueAt','')::timestamptz) then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
create function app_private.task_command(p_command text,p_term uuid,p_id uuid,p_data jsonb,p_version integer,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare tm public.term_memberships; w public.work_items; t public.tasks; payload jsonb; result jsonb; manager boolean; state text; actor uuid; status uuid; assigned uuid; unit uuid; collaborators jsonb;begin
  if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>300000
    or exists(select 1 from jsonb_each(p_data)e where e.key not in ('collaborators','checklist') and jsonb_typeof(e.value) not in ('string','null')) then raise exception using errcode='22023',message='command_validation_failed';end if;
  if p_command='create_task' then
    select * into tm from public.term_memberships where id=public.current_term_membership(p_term);
    if not found or not public.has_capability(p_term,'workspace.read') then raise exception using errcode='42501',message='command_permission_denied';end if;
  else
    select * into w from public.work_items where id=p_id and kind='task';
    select * into tm from public.term_memberships where id=public.current_term_membership(w.term_id);
    if w.id is null or tm.id is null or not public.can_access_work(w.id,'edit') then raise exception using errcode='42501',message='command_permission_denied';end if;
    p_term:=w.term_id;
  end if;
  if not exists(select 1 from public.terms term where term.id=p_term and term.state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
  actor:=tm.member_id;payload:=jsonb_build_array(p_term,p_id,p_data,p_version);result:=app_private.begin_work_command(p_command,p_key,payload);
  if result is not null then if not public.can_access_work((result->>'workItemId')::uuid,'detail') then raise exception using errcode='42501',message='command_permission_denied';end if;return result;end if;
  if p_command<>'create_task' then
    select * into w from public.work_items where id=p_id for update;
    if not public.can_access_work(w.id,'edit') or w.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
    if w.version is distinct from p_version then raise exception using errcode='40001',message='command_stale_version';end if;
    select * into t from public.tasks where work_item_id=w.id;manager:=(w.owner_member_id=actor and w.created_by=auth.uid()) or app_private.task_manager(w);
    if t.workflow_state in ('done','cancelled') then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  end if;
  if p_command in ('create_task','update_task') then
    if p_command='update_task' and t.workflow_state='ready_for_review' then raise exception using errcode='55000',message='command_dependency_blocked';end if;
    perform app_private.check_task_fields(p_data);
    if p_command='create_task' then
      unit:=nullif(p_data->>'leadUnitId','')::uuid;assigned:=coalesce(nullif(p_data->>'assigneeId','')::uuid,actor);
      if unit is not null and not exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null
        where um.term_membership_id=tm.id and um.unit_id=unit and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()) then raise exception using errcode='42501',message='command_permission_denied';end if;
      perform app_private.check_task_assignment(p_term,assigned,coalesce(nullif(p_data->>'assignedUnitId','')::uuid,unit),coalesce(p_data->'collaborators','[]'),actor,unit);
      if nullif(p_data->>'parentId','') is not null and not exists(select 1 from public.work_items parent where parent.id=(p_data->>'parentId')::uuid and parent.term_id=p_term and parent.kind='deliverable' and parent.archived_at is null and public.can_access_work(parent.id,'edit')) then raise exception using errcode='42501',message='command_permission_denied';end if;
      insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label) values(tm.organization_id,p_term,'task','p10_todo','draft','To do') on conflict(term_id,resource_kind,stable_key) do nothing;
      select id into status from public.status_definitions where term_id=p_term and resource_kind='task' and stable_key='p10_todo' and semantic_category='draft';
      insert into public.work_items(organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,parent_work_item_id,status_id,due_on,due_at,original_due_on,original_due_at)
      values(tm.organization_id,p_term,'task',btrim(p_data->>'title'),p_data->>'summary',p_data->>'classification',assigned,(select display_name from public.members where id=assigned),unit,nullif(p_data->>'parentId','')::uuid,status,
        nullif(p_data->>'dueOn','')::date,nullif(p_data->>'dueAt','')::timestamptz,nullif(p_data->>'dueOn','')::date,nullif(p_data->>'dueAt','')::timestamptz) returning * into w;
      insert into public.tasks(work_item_id,organization_id,term_id,body,assignee_id,assignee_name,assigned_unit_id,checklist,task_type) values(w.id,w.organization_id,w.term_id,p_data->>'body',assigned,(select display_name from public.members where id=assigned),coalesce(nullif(p_data->>'assignedUnitId','')::uuid,unit),p_data->'checklist',p_data->>'taskType');
      insert into public.task_collaborators select w.organization_id,w.term_id,w.id,value::uuid from jsonb_array_elements_text(coalesce(p_data->'collaborators','[]')) on conflict do nothing;
      insert into public.record_grants(organization_id,term_id,work_item_id,member_id,grant_kind,expires_at,grantor_id) values(w.organization_id,w.term_id,w.id,actor,'read',tm.ends_at,tm.id);
    else
      if (p_data->>'leadUnitId') is distinct from w.lead_unit_id::text or (p_data ? 'parentId' and nullif(p_data->>'parentId','')::uuid is distinct from w.parent_work_item_id)
        or p_data->>'classification'<>w.classification or p_data->>'taskType'<>t.task_type or (p_data->>'assigneeId')::uuid is distinct from t.assignee_id
        or nullif(p_data->>'assignedUnitId','')::uuid is distinct from t.assigned_unit_id or coalesce((select jsonb_agg(value order by value)from jsonb_array_elements_text(coalesce(p_data->'collaborators','[]'))),'[]')<>coalesce((select jsonb_agg(member_id::text order by member_id) from public.task_collaborators where work_item_id=w.id),'[]'::jsonb) then raise exception using errcode='42501',message='command_permission_denied';end if;
      if not manager and (p_data->>'title'<>w.title or p_data->>'summary'<>w.safe_summary or nullif(p_data->>'dueOn','')::date is distinct from w.due_on or nullif(p_data->>'dueAt','')::timestamptz is distinct from w.due_at
        or (select coalesce(jsonb_agg(e-'done' order by e->>'id'),'[]') from jsonb_array_elements(p_data->'checklist')e)<>(select coalesce(jsonb_agg(e-'done' order by e->>'id'),'[]') from jsonb_array_elements(t.checklist)e)) then raise exception using errcode='42501',message='command_permission_denied';end if;
      if coalesce(length(btrim(p_data->>'reason')),0)=0 then raise exception using errcode='22023',message='command_validation_failed';end if;
      update public.work_items set title=btrim(p_data->>'title'),safe_summary=p_data->>'summary',due_on=nullif(p_data->>'dueOn','')::date,due_at=nullif(p_data->>'dueAt','')::timestamptz where id=w.id returning * into w;
      update public.tasks set body=p_data->>'body',checklist=p_data->'checklist',workflow_state=case when workflow_state='ready_for_review' then 'in_progress' else workflow_state end,completion_evidence=null where work_item_id=w.id;
    end if;
  elsif p_command='assign_task' then
    if exists(select 1 from jsonb_object_keys(p_data) k where k not in ('assigneeId','assignedUnitId','collaborators','reason')) or coalesce(length(btrim(p_data->>'reason')),0) not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
    assigned:=(p_data->>'assigneeId')::uuid;unit:=nullif(p_data->>'assignedUnitId','')::uuid;collaborators:=coalesce(p_data->'collaborators','[]');
    -- A self-assignee cannot move a task across units; the receiving scoped manager must explicitly accept.
    if not manager and not public.has_capability(w.term_id,'committee.manage',unit) then raise exception using errcode='42501',message='command_permission_denied';end if;
    perform app_private.check_task_assignment(w.term_id,assigned,unit,collaborators,actor,w.lead_unit_id);
    update public.tasks set assignee_id=assigned,assignee_name=(select display_name from public.members where id=assigned),assigned_unit_id=unit,completion_evidence=null,blocked_reason=null,workflow_state='todo',checklist=coalesce((select jsonb_agg(jsonb_set(e,'{done}','false'::jsonb))from jsonb_array_elements(checklist)e),'[]') where work_item_id=w.id;
    delete from public.task_collaborators where work_item_id=w.id;
    insert into public.task_collaborators select w.organization_id,w.term_id,w.id,value::uuid from jsonb_array_elements_text(collaborators) on conflict do nothing;
    update public.work_items set owner_member_id=assigned,owner_display_name=(select display_name from public.members where id=assigned),status_id=(select id from public.status_definitions where term_id=w.term_id and resource_kind='task' and stable_key='p10_todo' and semantic_category='draft') where id=w.id returning * into w;
  elsif p_command='transition_task' then
    if exists(select 1 from jsonb_object_keys(p_data) k where k not in ('state','reason','evidence')) or coalesce(length(btrim(p_data->>'reason')),0) not between 1 and 2000 or coalesce(length(p_data->>'evidence'),0)>4000 then raise exception using errcode='22023',message='command_validation_failed';end if;
    state:=p_data->>'state';
    if not manager and not app_private.task_participant(w.id) then raise exception using errcode='42501',message='command_permission_denied';end if;
    if state is null or state not in ('todo','in_progress','blocked','ready_for_review','done','cancelled') then raise exception using errcode='22023',message='command_validation_failed';end if;
    if state='cancelled' and not manager then raise exception using errcode='42501',message='command_permission_denied';end if;
    if state='done' then
      if actor is distinct from t.assignee_id and not manager then raise exception using errcode='42501',message='command_permission_denied';end if;
      if nullif(btrim(p_data->>'evidence'),'') is null or exists(select 1 from jsonb_array_elements(t.checklist)e where e->>'done'<>'true') or t.workflow_state='blocked' or t.task_type='governed'
        or (t.task_type='review_required' and (t.workflow_state<>'ready_for_review' or not app_private.task_manager(w) or actor=t.assignee_id)) then raise exception using errcode='55000',message='command_dependency_blocked';end if;
    elsif not manager and not app_private.task_participant(w.id) then raise exception using errcode='42501',message='command_permission_denied';end if;
    insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)
    values(w.organization_id,w.term_id,'task','p10_'||state,case state when 'todo' then 'draft' when 'done' then 'completed' when 'cancelled' then 'cancelled' else 'active' end,replace(state,'_',' ')) on conflict(term_id,resource_kind,stable_key) do nothing;
    select id into status from public.status_definitions where term_id=w.term_id and resource_kind='task' and stable_key='p10_'||state;
    update public.tasks set workflow_state=state,blocked_reason=case when state='blocked' then p_data->>'reason' end,completion_evidence=case when state in ('ready_for_review','done') then p_data->>'evidence' else null end where work_item_id=w.id;
    update public.work_items set status_id=status where id=w.id returning * into w;
  else raise exception using errcode='22023',message='command_validation_failed';end if;
  result:=jsonb_build_object('workItemId',w.id,'version',w.version);
  insert into public.task_revisions(work_item_id,work_version,state,assignee_id,assignee_name,assigned_unit_id,collaborators,title,due_on,due_at,body,checklist,evidence,reason,actor_id)
    select w.id,w.version,workflow_state,assignee_id,assignee_name,assigned_unit_id,coalesce((select jsonb_agg(member_id::text order by member_id)from public.task_collaborators where work_item_id=w.id),'[]'),w.title,w.due_on,w.due_at,body,checklist,completion_evidence,coalesce(p_data->>'reason','Created'),auth.uid() from public.tasks where work_item_id=w.id;
  return app_private.finish_work_command(w,p_command,p_key,payload,result,'["task","reasoned_revision"]');
end$$;
create function public.create_task(p_term_id uuid,p_data jsonb,p_request_id uuid) returns jsonb language sql security definer set search_path='' as $$select app_private.task_command('create_task',p_term_id,null,p_data,null,p_request_id)$$;
create function public.update_task(p_work_item_id uuid,p_data jsonb,p_expected_version integer,p_request_id uuid) returns jsonb language sql security definer set search_path='' as $$select app_private.task_command('update_task',null,p_work_item_id,p_data,p_expected_version,p_request_id)$$;
create function public.assign_task(p_work_item_id uuid,p_data jsonb,p_expected_version integer,p_request_id uuid) returns jsonb language sql security definer set search_path='' as $$select app_private.task_command('assign_task',null,p_work_item_id,p_data,p_expected_version,p_request_id)$$;
create function public.transition_task(p_work_item_id uuid,p_data jsonb,p_expected_version integer,p_request_id uuid) returns jsonb language sql security definer set search_path='' as $$select app_private.task_command('transition_task',null,p_work_item_id,p_data,p_expected_version,p_request_id)$$;
revoke all on function app_private.task_participant(uuid),app_private.task_manager(public.work_items),app_private.check_task_assignment(uuid,uuid,uuid,jsonb,uuid,uuid),app_private.check_task_fields(jsonb),app_private.task_command(text,uuid,uuid,jsonb,integer,uuid),
  public.create_task(uuid,jsonb,uuid),public.update_task(uuid,jsonb,integer,uuid),public.assign_task(uuid,jsonb,integer,uuid),public.transition_task(uuid,jsonb,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_task(uuid,jsonb,uuid),public.update_task(uuid,jsonb,integer,uuid),public.assign_task(uuid,jsonb,integer,uuid),public.transition_task(uuid,jsonb,integer,uuid) to authenticated;
commit;
