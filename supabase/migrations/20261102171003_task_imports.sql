begin;
-- Private bounded import drafts, append-only input history, permanent source
-- bindings and immutable commit receipts. No raw client/table or service access.
create table app_private.task_import_sessions(
 id uuid primary key references public.announcements(work_item_id),term_id uuid not null references public.terms(id),unit_id uuid not null references public.org_units(id),
 actor_id uuid not null references auth.users(id),list_name text not null check(length(btrim(list_name))between 1 and 80),list_key text not null,
 version integer not null check(version>0),state text not null check(state in('draft','committed')),updated_at timestamptz not null default statement_timestamp()
);
create index task_import_owner on app_private.task_import_sessions(actor_id,term_id,updated_at desc,id);
create table app_private.task_import_revisions(
 session_id uuid not null references app_private.task_import_sessions(id),version integer not null,input jsonb not null,recorded_at timestamptz not null default statement_timestamp(),primary key(session_id,version)
);
create table app_private.task_import_bindings(
 term_id uuid not null references public.terms(id),unit_id uuid not null references public.org_units(id),list_key text not null,source_key text not null,
 work_item_id uuid not null references public.tasks(work_item_id),session_id uuid not null references app_private.task_import_sessions(id),created_at timestamptz not null default statement_timestamp(),
 primary key(term_id,unit_id,list_key,source_key),unique(term_id,unit_id,list_key,work_item_id)
);
create table app_private.task_import_commits(
 session_id uuid primary key references app_private.task_import_sessions(id),review_hash text not null,result jsonb not null,committed_at timestamptz not null default statement_timestamp()
);
do $$declare t text;begin foreach t in array array['task_import_sessions','task_import_revisions','task_import_bindings','task_import_commits']loop
 execute format('alter table app_private.%I enable row level security',t);execute format('alter table app_private.%I force row level security',t);
 execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',t);
 if t<>'task_import_sessions'then execute format('create trigger immutable_task_import_history before update or delete on app_private.%I for each row execute function app_private.request_history_guard()',t);end if;
end loop;end$$;
create function app_private.task_import_control_guard()returns trigger language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from app_private.task_import_sessions where id=old.id)then
  if tg_op='DELETE'or current_setting('app.task_import_write',true)is distinct from 'approved'then raise exception using errcode='42501',message='command_permission_denied';end if;
  if(new.title,new.safe_summary,new.owner_member_id,new.owner_display_name,new.lead_unit_id,new.status_id,new.archived_at)is distinct from(old.title,old.safe_summary,old.owner_member_id,old.owner_display_name,old.lead_unit_id,old.status_id,old.archived_at)then raise exception using errcode='42501',message='command_permission_denied';end if;
 end if;if tg_op='DELETE'then return old;end if;return new;
end$$;
create trigger task_import_control_guard before update or delete on public.work_items for each row execute function app_private.task_import_control_guard();
create function app_private.task_import_announcement_guard()returns trigger language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from app_private.task_import_sessions where id=old.work_item_id)then raise exception using errcode='42501',message='command_permission_denied';end if;if tg_op='DELETE'then return old;end if;return new;
end$$;
create trigger task_import_announcement_guard before update or delete on public.announcements for each row execute function app_private.task_import_announcement_guard();
create function app_private.task_import_actor(term uuid,unit uuid default null)returns public.term_memberships
language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 m:=app_private.request_actor(term,true);
 if not public.has_capability(term,'admin.configure')or not public.has_capability(term,'roles.manage')or(unit is not null and(
  not public.has_capability(term,'committee.manage',unit)or not exists(select 1 from public.org_units u join public.unit_memberships d on d.unit_id=u.id
   where u.id=unit and u.term_id=term and u.archived_at is null and d.term_membership_id=m.id and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())
 ))then raise exception using errcode='42501',message='command_permission_denied';end if;return m;
end$$;
create function app_private.task_import_session(id uuid)returns app_private.task_import_sessions
language plpgsql stable security definer set search_path='' as $$declare d app_private.task_import_sessions;begin
 select *into d from app_private.task_import_sessions s where s.id=task_import_session.id and s.actor_id=auth.uid();
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.task_import_actor(d.term_id,d.unit_id);return d;
end$$;
create function app_private.task_import_schema(input jsonb)returns void language plpgsql immutable set search_path='' as $$begin
 if not coalesce(app_private.definition_keys(input,array['header','mapping','rows']),false)or not(input?&array['header','mapping','rows'])or octet_length(input::text)>200000
  or jsonb_typeof(input->'header')<>'array'or jsonb_typeof(input->'mapping')<>'object'or jsonb_typeof(input->'rows')<>'array'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if jsonb_array_length(input->'header')not between 2 and 32 or jsonb_array_length(input->'rows')not between 1 and 50
  or exists(select 1 from jsonb_array_elements(input->'header')h where jsonb_typeof(h)<>'string'or length(btrim(h#>>'{}'))not between 1 and 120)
  or(select count(*)<>count(distinct lower(btrim(h)))from jsonb_array_elements_text(input->'header')h)
  or exists(select 1 from jsonb_array_elements_text(input->'header')h where lower(h)~'(^|[^a-z])(roles?|admin|permissions?|capabilit(y|ies)|privileges?|amount|cost|centavos|financial|money)([^a-z]|$)')
  or not app_private.definition_keys(input->'mapping',array['source_key','title','assignee','committee','due_on','reference'])
  or exists(select 1 from jsonb_each(input->'mapping')e where jsonb_typeof(e.value)<>'string'or e.value<>'""'and not exists(select 1 from jsonb_array_elements(input->'header')h where h=e.value))
  or(select count(*)<>count(distinct value)from jsonb_each_text(input->'mapping')where value<>'')
  or coalesce(input->'mapping'->>'source_key','')=''or coalesce(input->'mapping'->>'title','')=''
  then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from jsonb_array_elements(input->'rows')r where jsonb_typeof(r)<>'array')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from jsonb_array_elements(input->'rows')r cross join lateral jsonb_array_elements(r)c where jsonb_typeof(c)<>'string'or length(c#>>'{}')>2000)then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
create function app_private.task_import_plan(d app_private.task_import_sessions)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare input jsonb;row jsonb;v jsonb;rows jsonb:='[]';errors jsonb;cols jsonb;idx integer;record integer:=1;field text;source text;target uuid;bound uuid;
 w public.work_items;t public.tasks;m public.term_memberships;assignee uuid;assignee_name text;unit_name text;due date;before_value jsonb;after_value jsonb;operation text;matches integer;
begin
 m:=app_private.task_import_actor(d.term_id,d.unit_id);select name into unit_name from public.org_units where id=d.unit_id;
 select r.input into input from app_private.task_import_revisions r where r.session_id=d.id and r.version=d.version;
 perform app_private.task_import_schema(input);
 for row in select value from jsonb_array_elements(input->'rows')loop
  record:=record+1;v:='{}';errors:='[]';target:=null;bound:=null;w:=null;t:=null;before_value:=null;operation:='create';
  foreach field in array array['source_key','title','assignee','committee','due_on','reference']loop
   source:=input->'mapping'->>field;select ord::integer-1 into idx from jsonb_array_elements_text(input->'header')with ordinality h(name,ord)where h.name=source;
   v:=v||jsonb_build_object(field,coalesce(row->>idx,''));
  end loop;
  if jsonb_array_length(row)<>jsonb_array_length(input->'header')then errors:=errors||'"Repair the cell count for this CSV record."'::jsonb;end if;
  if v->>'source_key'!~'^[a-zA-Z0-9][a-zA-Z0-9._:-]{0,99}$'then errors:=errors||'"Enter a stable source key of 1–100 letters, digits, dots, colons, hyphens or underscores."'::jsonb;end if;
  if length(btrim(v->>'title'))not between 1 and 240 then errors:=errors||'"Enter a task title of 1–240 characters."'::jsonb;end if;
  if v->>'committee'<>''and lower(btrim(v->>'committee'))<>lower(unit_name)and not exists(select 1 from public.unit_aliases a where a.unit_id=d.unit_id and a.term_id=d.term_id and lower(a.alias)=lower(btrim(v->>'committee')))then errors:=errors||'"Committee must match the selected permitted committee."'::jsonb;end if;
  due:=null;
  if v->>'due_on'<>''then begin
   if v->>'due_on'!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise invalid_datetime_format;end if;
   due:=(v->>'due_on')::date;if not isfinite(due)or due::text<>v->>'due_on'then raise invalid_datetime_format;end if;
   exception when datetime_field_overflow or invalid_datetime_format then errors:=errors||'"Use a real YYYY-MM-DD due date."'::jsonb;due:=null;end;
  end if;
  select b.work_item_id into bound from app_private.task_import_bindings b where b.term_id=d.term_id and b.unit_id=d.unit_id and b.list_key=d.list_key and b.source_key=v->>'source_key';
  if v->>'reference'<>''then
   select wr.work_item_id into target from public.work_references wr join public.work_items tw on tw.id=wr.work_item_id join public.tasks tt on tt.work_item_id=tw.id
   where wr.term_id=d.term_id and wr.kind='task'and wr.reference_text=v->>'reference'and tw.lead_unit_id=d.unit_id and tw.classification='ordinary'and tw.archived_at is null and tt.task_type='ordinary'and public.can_access_work(tw.id,'edit');
  else target:=bound;end if;
  if (v->>'reference'<>''and target is null)or(bound is not null and target is distinct from bound)then
   errors:='["Reference or source row is unavailable in this scope."]';target:=null;
  end if;
  if target is not null then
   select tw.*into w from public.work_items tw join public.tasks tt on tt.work_item_id=tw.id where tw.id=target and tw.term_id=d.term_id and tw.lead_unit_id=d.unit_id and tw.classification='ordinary'and tw.archived_at is null and tt.task_type='ordinary'and public.can_access_work(tw.id,'edit');
   if not found then errors:='["Reference or source row is unavailable in this scope."]';target:=null;else select *into t from public.tasks where work_item_id=target;end if;
  end if;
  assignee:=coalesce(t.assignee_id,m.member_id);assignee_name:=coalesce(t.assignee_name,(select display_name from public.members where id=m.member_id));
  if v->>'assignee'<>''then
   select count(*),(array_agg(person.member_id))[1]into matches,assignee from public.read_directory(d.term_id)person
   where lower(btrim(person.display_name))=lower(btrim(v->>'assignee'))and exists(select 1 from public.term_memberships tm join public.unit_memberships um on um.term_membership_id=tm.id where tm.member_id=person.member_id and tm.term_id=d.term_id and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and um.unit_id=d.unit_id and um.status='active'and um.effective_from<=statement_timestamp()and um.effective_to>statement_timestamp());
   if matches<>1 then errors:=errors||'"Choose one unambiguous permitted person in this committee."'::jsonb;else select display_name into assignee_name from public.members where id=assignee;end if;
  end if;
  if target is not null then
   if exists(select 1 from app_private.task_import_bindings b where b.term_id=d.term_id and b.unit_id=d.unit_id and b.list_key=d.list_key and b.work_item_id=target and b.source_key<>v->>'source_key')then errors:=errors||'"Keep the original source key for this task."'::jsonb;end if;
   if assignee=t.assignee_id then assignee_name:=t.assignee_name;end if;
   before_value:=jsonb_build_object('title',w.title,'assignee',t.assignee_name,'dueOn',w.due_on,'dueAt',w.due_at);
   if v->>'due_on'=''then due:=w.due_on;end if;
   if assignee is distinct from t.assignee_id then errors:=errors||'"Change the assigned person on the task page; imports never reset progress."'::jsonb;end if;
   if v->>'due_on'<>''and w.due_at is not null then errors:=errors||'"Change timed deadlines on the task page."'::jsonb;end if;
  end if;
  after_value:=jsonb_build_object('title',btrim(v->>'title'),'assignee',assignee_name,'dueOn',due,'dueAt',w.due_at);
  if target is not null then
   operation:=case when before_value=after_value then 'unchanged'else 'update'end;
   if operation='update'and(t.workflow_state<>'todo'or t.completion_evidence is not null)then errors:=errors||'"Only untouched To do tasks can be updated here; use the task page for work in progress."'::jsonb;end if;
  end if;
  if (select count(*)from jsonb_array_elements(input->'rows')r where r->>((select ord::integer-1 from jsonb_array_elements_text(input->'header')with ordinality h(name,ord)where name=input->'mapping'->>'source_key'))=v->>'source_key')>1 then errors:=errors||'"Duplicate source key; repair every matching record."'::jsonb;end if;
  rows:=rows||jsonb_build_object('record',record,'sourceKey',v->>'source_key','operation',operation,'targetId',target,'reference',case when target is not null then(select reference_text from public.work_references where work_item_id=target)end,'expectedWorkVersion',w.version,'assigneeId',assignee,'before',before_value,'after',after_value,'errors',errors);
 end loop;
 -- Two distinct source keys may not point at the same existing task in one file.
 if(select count(*)<>count(distinct r->>'targetId')from jsonb_array_elements(rows)r where r->>'targetId'is not null)then
  select jsonb_agg(r||jsonb_build_object('errors',(r->'errors')||'["Map each existing task only once per file."]'))into rows from jsonb_array_elements(rows)r;
 end if;
 cols:=jsonb_build_object('draftId',d.id,'version',d.version,'listName',d.list_name,'unitName',unit_name,'rows',rows,'valid',not exists(select 1 from jsonb_array_elements(rows)r where jsonb_array_length(r->'errors')>0));
 return cols||jsonb_build_object('reviewHash',encode(sha256(convert_to(cols::text,'UTF8')),'hex'));
end$$;
create function public.save_task_import(p_term_id uuid,p_unit_id uuid,p_list_name text,p_input jsonb,p_draft_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$declare m public.term_memberships;d app_private.task_import_sessions;w public.work_items;payload jsonb;result jsonb;status uuid;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.task_import_actor(p_term_id,p_unit_id);perform set_config('app.task_import_write','approved',true);
 if p_unit_id is null or p_list_name is null or length(btrim(p_list_name))not between 1 and 80 or p_expected_version is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 perform app_private.task_import_schema(p_input);
 if p_draft_id is not null then d:=app_private.task_import_session(p_draft_id);if d.term_id<>p_term_id or d.unit_id<>p_unit_id or d.list_key<>lower(btrim(p_list_name))then raise exception using errcode='42501',message='command_permission_denied';end if;end if;
 payload:=jsonb_build_array(p_term_id,p_unit_id,p_list_name,p_input,p_draft_id,p_expected_version);result:=app_private.begin_work_command('save_task_import',p_request_id,payload);if result is not null then perform app_private.task_import_session((result->>'draftId')::uuid);return result;end if;
 if p_draft_id is null then
  if p_expected_version<>0 then raise exception using errcode='40001',message='command_stale_version';end if;
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,p_term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select id into status from public.status_definitions where term_id=p_term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,lead_unit_id,status_id)values(m.organization_id,p_term_id,'announcement','CSV import control','restricted',m.member_id,(select display_name from public.members where id=m.member_id),p_unit_id,status)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
  insert into app_private.task_import_sessions values(w.id,p_term_id,p_unit_id,auth.uid(),btrim(p_list_name),lower(btrim(p_list_name)),1,'draft',statement_timestamp())returning *into d;
 else
  if d.state<>'draft'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  if d.version<>p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  update public.work_items set updated_at=statement_timestamp()where id=d.id returning *into w;
  update app_private.task_import_sessions set version=version+1,updated_at=statement_timestamp()where id=d.id returning *into d;
 end if;
 insert into app_private.task_import_revisions values(d.id,d.version,p_input,statement_timestamp());
 return app_private.finish_work_command(w,'save_task_import',p_request_id,payload,jsonb_build_object('draftId',d.id,'version',d.version,'state',d.state),'["private_task_import_draft"]');
end$$;
create function public.read_task_import(p_term_id uuid,p_draft_id uuid default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$declare d app_private.task_import_sessions;begin
 perform app_private.task_import_actor(p_term_id);
 if p_draft_id is not null then d:=app_private.task_import_session(p_draft_id);if d.term_id<>p_term_id then raise exception using errcode='42501',message='command_permission_denied';end if;
  if exists(select 1 from app_private.task_import_commits c cross join lateral jsonb_array_elements(c.result->'items')r where c.session_id=d.id and not exists(select 1 from public.work_items tw where tw.id=(r->>'workItemId')::uuid and tw.term_id=d.term_id and tw.lead_unit_id=d.unit_id and tw.classification='ordinary'and tw.archived_at is null and public.can_access_work(tw.id,'detail')))then raise exception using errcode='42501',message='command_permission_denied';end if;
 end if;
 return jsonb_build_object('units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name)order by u.name,u.id)from public.org_units u where u.term_id=p_term_id and u.archived_at is null and public.has_capability(p_term_id,'committee.manage',u.id)and exists(select 1 from public.unit_memberships um where um.unit_id=u.id and um.term_membership_id=public.current_term_membership(p_term_id)and um.status='active'and um.effective_from<=statement_timestamp()and um.effective_to>statement_timestamp())),'[]'),
 'drafts',coalesce((select jsonb_agg(jsonb_build_object('draftId',s.id,'listName',s.list_name,'version',s.version,'state',s.state)order by s.updated_at desc,s.id)from(select *from app_private.task_import_sessions s where s.term_id=p_term_id and s.actor_id=auth.uid()and public.has_capability(p_term_id,'committee.manage',s.unit_id)order by s.updated_at desc,s.id limit 20)s),'[]'),
 'draft',case when d.id is not null then jsonb_build_object('draftId',d.id,'version',d.version,'unitId',d.unit_id,'listName',d.list_name,'state',d.state,'input',(select r.input from app_private.task_import_revisions r where r.session_id=d.id order by r.version desc limit 1),'receipt',(select c.result from app_private.task_import_commits c where c.session_id=d.id))end);
end$$;
create function public.preview_task_import(p_draft_id uuid,p_expected_version integer)returns jsonb
language plpgsql stable security definer set search_path='' as $$declare d app_private.task_import_sessions;begin
 d:=app_private.task_import_session(p_draft_id);
 if d.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if d.state<>'draft'then raise exception using errcode='55000',message='command_dependency_blocked';end if;return app_private.task_import_plan(d);
end$$;
create function public.commit_task_import(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare d app_private.task_import_sessions;w public.work_items;t public.tasks;plan jsonb;row jsonb;payload jsonb;result jsonb;receipt jsonb;items jsonb:='[]';task_data jsonb;target uuid;child_key uuid;created integer:=0;updated integer:=0;unchanged integer:=0;collaborators jsonb;
begin
 d:=app_private.task_import_session(p_draft_id);perform app_private.readiness_lock(d.term_id);perform app_private.dependency_lock(d.term_id);d:=app_private.task_import_session(p_draft_id);
 payload:=jsonb_build_array(p_draft_id,p_expected_version,p_review_hash);result:=app_private.begin_work_command('commit_task_import',p_request_id,payload);
 if result is not null then
  if exists(select 1 from jsonb_array_elements(result->'items')r where not exists(select 1 from public.work_items tw where tw.id=(r->>'workItemId')::uuid and tw.term_id=d.term_id and tw.lead_unit_id=d.unit_id and tw.classification='ordinary'and tw.archived_at is null and public.can_access_work(tw.id,'detail')))then raise exception using errcode='42501',message='command_permission_denied';end if;return result;
 end if;
 if d.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if d.state<>'draft'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 -- Term graph/ready lock serializes namespace bindings; work locks use UUID order.
 perform 1 from public.work_items where id in(select b.work_item_id from app_private.task_import_bindings b where b.term_id=d.term_id and b.unit_id=d.unit_id and b.list_key=d.list_key)order by id for update;
 plan:=app_private.task_import_plan(d);
 perform 1 from public.work_items where id in(select(r->>'targetId')::uuid from jsonb_array_elements(plan->'rows')r where r->>'targetId'is not null)order by id for update;
 plan:=app_private.task_import_plan(d);
 if not(plan->>'valid')::boolean then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_review_hash is distinct from plan->>'reviewHash'then raise exception using errcode='40001',message='command_stale_preview';end if;
 for row in select value from jsonb_array_elements(plan->'rows')loop
  target:=(row->>'targetId')::uuid;child_key:=md5(p_request_id::text||':'||(row->>'record'))::uuid;
  if row->>'operation'='create'then
   task_data:=jsonb_build_object('title',row->'after'->>'title','summary','','body','','classification','ordinary','taskType','ordinary','leadUnitId',d.unit_id,'assigneeId',row->>'assigneeId','assignedUnitId',d.unit_id,'collaborators','[]'::jsonb,'checklist','[]'::jsonb,'dueOn',row->'after'->'dueOn','dueAt',null,'parentId',null,'reason','Reviewed CSV task import');
   receipt:=public.create_task(d.term_id,task_data,child_key);target:=(receipt->>'workItemId')::uuid;created:=created+1;
  elsif row->>'operation'='update'then
   select *into w from public.work_items where id=target for update;select *into t from public.tasks where work_item_id=target;
   select coalesce(jsonb_agg(member_id::text order by member_id),'[]')into collaborators from public.task_collaborators where work_item_id=target;
   task_data:=jsonb_build_object('title',row->'after'->>'title','summary',w.safe_summary,'body',t.body,'classification',w.classification,'taskType',t.task_type,'leadUnitId',w.lead_unit_id,'assigneeId',t.assignee_id,'assignedUnitId',t.assigned_unit_id,'collaborators',collaborators,'checklist',t.checklist,'dueOn',row->'after'->'dueOn','dueAt',w.due_at,'parentId',w.parent_work_item_id,'reason','Reviewed CSV task import');
   receipt:=public.update_task(target,task_data,(row->>'expectedWorkVersion')::integer,child_key);updated:=updated+1;
  else unchanged:=unchanged+1;end if;
  insert into app_private.task_import_bindings values(d.term_id,d.unit_id,d.list_key,row->>'sourceKey',target,d.id,statement_timestamp())on conflict(term_id,unit_id,list_key,source_key)do nothing;
  items:=items||jsonb_build_object('sourceKey',row->>'sourceKey','workItemId',target,'title',(select title from public.work_items where id=target),'reference',(select reference_text from public.work_references where work_item_id=target),'version',(select version from public.work_items where id=target),'action',row->>'operation','href','/tasks/'||target||'?term='||d.term_id);
 end loop;
 perform set_config('app.task_import_write','approved',true);
 update public.work_items set updated_at=statement_timestamp()where id=d.id returning *into w;
 update app_private.task_import_sessions set version=version+1,state='committed',updated_at=statement_timestamp()where id=d.id returning *into d;
 result:=jsonb_build_object('draftId',d.id,'version',d.version,'state','committed','items',items,'created',created,'updated',updated,'unchanged',unchanged);
 insert into app_private.task_import_commits values(d.id,p_review_hash,result,statement_timestamp());
 return app_private.finish_work_command(w,'commit_task_import',p_request_id,payload,result,'["task_import_commit"]');
end$$;
revoke all on function app_private.task_import_control_guard(),app_private.task_import_announcement_guard(),app_private.task_import_actor(uuid,uuid),app_private.task_import_session(uuid),app_private.task_import_schema(jsonb),app_private.task_import_plan(app_private.task_import_sessions)from public,anon,authenticated,service_role;
revoke all on function public.save_task_import(uuid,uuid,text,jsonb,uuid,integer,uuid),public.read_task_import(uuid,uuid),public.preview_task_import(uuid,integer),public.commit_task_import(uuid,integer,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.save_task_import(uuid,uuid,text,jsonb,uuid,integer,uuid),public.read_task_import(uuid,uuid),public.preview_task_import(uuid,integer),public.commit_task_import(uuid,integer,text,uuid)to authenticated;
commit;
