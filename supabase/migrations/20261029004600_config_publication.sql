-- P37 prerequisite repair: P35 publication boundary for existing P20/P22 definitions.
-- No generic executable configuration, access provisioning, typed FIN/MCD expansion or live activation.
create table public.configuration_drafts(
 id uuid primary key default gen_random_uuid(),request_type_id uuid not null references public.request_types(id),
 kind text not null check(kind in('form','workflow')),actor_id uuid not null references auth.users(id),
 version integer not null check(version>0),definition jsonb not null check(jsonb_typeof(definition)='object'and octet_length(definition::text)<=100000),
 base_form_version_id uuid not null,base_workflow_version_id uuid not null,rollback_version_id uuid,
 published_version_id uuid,updated_at timestamptz not null default statement_timestamp(),
 unique(request_type_id,kind,actor_id),
 foreign key(request_type_id,base_form_version_id)references public.form_versions(request_type_id,id),
 foreign key(request_type_id,base_workflow_version_id)references public.workflow_versions(request_type_id,id)
);
create table public.configuration_controls(
 request_type_id uuid primary key references public.request_types(id),work_item_id uuid not null unique references public.announcements(work_item_id)
);
create table public.configuration_publications(
 id uuid primary key default gen_random_uuid(),request_type_id uuid not null references public.request_types(id),
 kind text not null check(kind in('form','workflow')),definition_version_id uuid not null unique,
 base_form_version_id uuid not null,base_workflow_version_id uuid not null,rollback_version_id uuid,
 control_id uuid not null references public.configuration_controls(work_item_id),control_version integer not null check(control_version>0),
 actor_id uuid not null references auth.users(id),reason text not null check(length(btrim(reason))between 1 and 2000),
 published_at timestamptz not null default statement_timestamp(),unique(control_id,control_version),
 foreign key(request_type_id,base_form_version_id)references public.form_versions(request_type_id,id),
 foreign key(request_type_id,base_workflow_version_id)references public.workflow_versions(request_type_id,id)
);
create index configuration_drafts_actor on public.configuration_drafts(actor_id,request_type_id);
create index configuration_history_type on public.configuration_publications(request_type_id,published_at desc,id);
do $$declare t text;begin foreach t in array array['configuration_drafts','configuration_controls','configuration_publications']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
end loop;end$$;
create trigger immutable_configuration_publications before update or delete on public.configuration_publications for each row execute function app_private.request_history_guard();
create trigger immutable_configuration_controls before update or delete on public.configuration_controls for each row execute function app_private.request_history_guard();

create function app_private.configuration_actor(p_type uuid,p_write boolean default false)returns public.term_memberships
language plpgsql stable security definer set search_path='' as $$
declare t public.request_types;m public.term_memberships;begin
 select *into t from public.request_types where id=p_type and archived_at is null;
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 m:=app_private.request_actor(t.term_id,p_write);
 if not public.has_capability(t.term_id,'admin.configure')and not(
  t.receiving_unit_id is not null and public.has_capability(t.term_id,'committee.manage',t.receiving_unit_id)
  and exists(select 1 from public.unit_memberships d where d.term_membership_id=m.id and d.unit_id=t.receiving_unit_id
   and d.status='active'and d.deployment_type='head'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())
 )then raise exception using errcode='42501',message='command_permission_denied';end if;
 return m;
end$$;

create function app_private.configuration_draft_receipt(d public.configuration_drafts)returns jsonb
language sql stable set search_path='' as $$select jsonb_build_object('draftId',d.id,'version',d.version)$$;

create function public.read_configurations(p_term_id uuid)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t public.request_types;items jsonb:='[]';begin
 perform app_private.request_actor(p_term_id);
 for t in select *from public.request_types where term_id=p_term_id and archived_at is null order by label,id loop
  begin
   perform app_private.configuration_actor(t.id);
   items:=items||jsonb_build_array(jsonb_build_object('id',t.id,'label',t.label,'governedKind',t.governed_kind));
  exception when insufficient_privilege then null;end;
 end loop;
 return items;
end$$;

create function public.read_configuration(p_type_id uuid)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t public.request_types;m public.term_memberships;begin
 m:=app_private.configuration_actor(p_type_id);
 select *into t from public.request_types where id=p_type_id;
 return jsonb_build_object('typeId',t.id,'typeLabel',t.label,'termId',t.term_id,'governedKind',t.governed_kind,
 'formVersionId',t.form_version_id,'workflowVersionId',t.workflow_version_id,'classification',t.payload_classification,'currentMembershipId',m.id,
 'currentMemberName',(select display_name from public.members where id=m.member_id),
 'serviceLabel',(select name from public.org_units where id=t.receiving_unit_id),
 'reviewers',coalesce((select jsonb_agg(jsonb_build_object('id',tm.id,'name',person.display_name,'role',r.name)order by person.display_name,tm.id)
   from public.term_memberships tm join public.members person on person.id=tm.member_id
   join public.role_assignments a on a.id=app_private.workflow_role(t.term_id,tm.id,t.receiving_unit_id)
   join public.roles r on r.id=a.role_id where tm.term_id=t.term_id),'[]'),
 'formDefinition',(select schema_json from public.form_versions where id=t.form_version_id),
 'workflowDefinition',(select definition_json from public.workflow_versions where id=t.workflow_version_id),
 'drafts',coalesce((select jsonb_agg(jsonb_build_object('draftId',d.id,'kind',d.kind,'version',d.version,'definition',d.definition,
   'baseFormVersionId',d.base_form_version_id,'baseWorkflowVersionId',d.base_workflow_version_id,'rollbackVersionId',d.rollback_version_id,
   'publishedVersionId',d.published_version_id,'updatedAt',d.updated_at)order by d.kind)
   from public.configuration_drafts d where d.request_type_id=t.id and d.actor_id=auth.uid()),'[]'),
 'history',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'kind',h.kind,'definitionVersionId',h.definition_version_id,
   'rollbackVersionId',h.rollback_version_id,'version',h.control_version,'publishedAt',h.published_at,'reason',h.reason,
   'definition',case h.kind when 'form'then(select schema_json from public.form_versions where id=h.definition_version_id)
    else(select definition_json from public.workflow_versions where id=h.definition_version_id)end)order by h.control_version desc)
   from(select *from public.configuration_publications where request_type_id=t.id order by control_version desc limit 50)h),'[]'));
end$$;

create function public.save_configuration_draft(p_type_id uuid,p_kind text,p_definition jsonb,
 p_base_form_version_id uuid,p_base_workflow_version_id uuid,p_expected_version integer,p_request_id uuid,p_rollback_version_id uuid default null)returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;t public.request_types;d public.configuration_drafts;payload jsonb;result jsonb;source jsonb;begin
 m:=app_private.configuration_actor(p_type_id,true);
 select *into t from public.request_types where id=p_type_id;
 perform app_private.readiness_lock(t.term_id);
 m:=app_private.configuration_actor(p_type_id,true);
 select *into t from public.request_types where id=p_type_id for update;
 payload:=jsonb_build_array(p_type_id,p_kind,p_definition,p_base_form_version_id,p_base_workflow_version_id,p_expected_version,p_rollback_version_id);
 result:=app_private.begin_work_command('save_configuration_draft',p_request_id,payload);if result is not null then return result;end if;
 if p_kind is null or p_kind not in('form','workflow')or jsonb_typeof(p_definition)is distinct from 'object'or octet_length(p_definition::text)>100000
  or p_expected_version is null or p_expected_version<0 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if t.form_version_id is distinct from p_base_form_version_id or t.workflow_version_id is distinct from p_base_workflow_version_id
  or p_base_form_version_id is null or p_base_workflow_version_id is null then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_rollback_version_id is not null then
  select case p_kind when 'form'then(select schema_json from public.form_versions where id=p_rollback_version_id and request_type_id=t.id and state='published')
   else(select definition_json from public.workflow_versions where id=p_rollback_version_id and request_type_id=t.id and state='published')end into source;
  if source is null or source is distinct from p_definition then raise exception using errcode='22023',message='command_validation_failed';end if;
 end if;
 select *into d from public.configuration_drafts where request_type_id=t.id and kind=p_kind and actor_id=auth.uid()for update;
 if coalesce(d.version,0)<>p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if d.id is null then
  insert into public.configuration_drafts(request_type_id,kind,actor_id,version,definition,base_form_version_id,base_workflow_version_id,rollback_version_id)
   values(t.id,p_kind,auth.uid(),1,p_definition,p_base_form_version_id,p_base_workflow_version_id,p_rollback_version_id)returning *into d;
 else
  update public.configuration_drafts set version=version+1,definition=p_definition,base_form_version_id=p_base_form_version_id,
   base_workflow_version_id=p_base_workflow_version_id,rollback_version_id=p_rollback_version_id,published_version_id=null,updated_at=statement_timestamp()
   where id=d.id returning *into d;
 end if;
 result:=app_private.configuration_draft_receipt(d);
 -- Private draft saves have a retry receipt but no publication event, copied payload or business outbox.
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)
  values(auth.uid(),'save_configuration_draft',p_request_id,m.organization_id,m.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),result);
 return result;
end$$;

create function app_private.configuration_problem(t public.request_types,d public.configuration_drafts,p_requester uuid default null)returns text
language plpgsql stable security definer set search_path='' as $$
declare form jsonb;workflow jsonb;s jsonb;person text;k text;idx integer:=0;total integer;begin
 -- The installed FIN/MCD adapters require separately confirmed single-stage typed mappings.
 -- A general configuration label never substitutes for those policies or authorizes a migration.
 if t.governed_kind<>'general'then return 'protected_routing_unsupported';end if;
 form:=case d.kind when 'form'then d.definition else(select schema_json from public.form_versions where id=t.form_version_id)end;
 workflow:=case d.kind when 'workflow'then d.definition else(select definition_json from public.workflow_versions where id=t.workflow_version_id)end;
 perform app_private.validate_form_definition(form,t.payload_classification='restricted');
 perform app_private.validate_workflow_definition(workflow);
 if exists(select 1 from jsonb_array_elements(form->'fields')f where f->>'type'='currency'or coalesce(f->>'storage','custom')<>'custom'
  or exists(select 1 from jsonb_array_elements(coalesce(f->'itemFields','[]'))c where c->>'type'='currency'or coalesce(c->>'storage','custom')<>'custom'))
 then return 'protected_fields_unsupported';end if;
 if t.receiving_unit_id is null or not exists(select 1 from public.org_units u where u.id=t.receiving_unit_id and u.term_id=t.term_id and u.archived_at is null and u.review_service)
 then return 'service_unavailable';end if;
 total:=jsonb_array_length(workflow->'stages');
 for s in select value from jsonb_array_elements(workflow->'stages')loop
  idx:=idx+1;
  if s->>'review'not in('one','all')or jsonb_array_length(s->'reviewers')not between 1 and 10
   or(s->>'review'='one'and jsonb_array_length(s->'reviewers')<>1)
   or(select count(distinct value)from jsonb_array_elements_text(s->'reviewers'))<>jsonb_array_length(s->'reviewers')
   or(idx<total and s->>'outcome'<>'pending')or(idx=total and s->>'outcome'not in('approved','rejected','completed','revision'))
  then return 'sequential_review_required';end if;
  for person in select value from jsonb_array_elements_text(s->'reviewers')loop
   if app_private.workflow_role(t.term_id,person::uuid,t.receiving_unit_id)is null then return 'reviewer_unavailable';end if;
   if person::uuid=p_requester then return 'requester_conflict';end if;
  end loop;
  for k in select value from jsonb_array_elements_text(s->'entryFields')loop
   if not exists(select 1 from jsonb_array_elements(form->'fields')f where f->>'key'=k)then return 'field_unavailable';end if;
  end loop;
  if s?'condition'then perform app_private.validate_form_condition(s->'condition',form->'fields');end if;
 end loop;
 return null;
exception when data_exception or integrity_constraint_violation then return 'invalid_definition';
end$$;

create function app_private.configuration_review_hash(t public.request_types,d public.configuration_drafts,p_requester uuid)returns text
language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_array(t.id,t.form_version_id,t.workflow_version_id,t.receiving_unit_id,t.governed_kind,
  t.payload_classification,t.archived_at,d.id,d.version,d.definition,d.base_form_version_id,d.base_workflow_version_id,d.rollback_version_id,p_requester,
  (select coalesce(jsonb_agg(jsonb_build_array(a.id,a.version,a.effective_to)order by a.id),'[]')from public.role_assignments a
   where a.term_id=t.term_id and a.unit_id=t.receiving_unit_id and a.status='active'))::text,'UTF8')),'hex')
$$;

create function public.preview_configuration(p_draft_id uuid,p_requester_id uuid default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d public.configuration_drafts;t public.request_types;m public.term_memberships;problem text;previous jsonb;requester uuid;begin
 select *into d from public.configuration_drafts where id=p_draft_id and actor_id=auth.uid();
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 m:=app_private.configuration_actor(d.request_type_id);
 select *into t from public.request_types where id=d.request_type_id;
 requester:=coalesce(p_requester_id,m.id);
 if requester<>m.id and app_private.workflow_role(t.term_id,requester,t.receiving_unit_id)is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 problem:=app_private.configuration_problem(t,d,requester);
 if t.form_version_id is distinct from d.base_form_version_id or t.workflow_version_id is distinct from d.base_workflow_version_id then problem:='stale_base';end if;
 previous:=case d.kind when 'form'then(select schema_json from public.form_versions where id=t.form_version_id)
  else(select definition_json from public.workflow_versions where id=t.workflow_version_id)end;
 return jsonb_build_object('draftId',d.id,'version',d.version,'valid',problem is null,'problem',problem,'kind',d.kind,
  'reviewHash',app_private.configuration_review_hash(t,d,requester),'requesterId',requester,'previousDefinition',previous,'definition',d.definition,'changed',previous is distinct from d.definition,
  'existingCasesRemainPinned',true,'liveActivationChanged',false);
end$$;

create function public.publish_configuration(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid,p_requester_id uuid default null)returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;d public.configuration_drafts;t public.request_types;w public.work_items;control uuid;status uuid;
 payload jsonb;result jsonb;new_version uuid;n integer;problem text;requester uuid;begin
 select *into d from public.configuration_drafts where id=p_draft_id and actor_id=auth.uid();
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 select *into t from public.request_types where id=d.request_type_id;
 perform app_private.readiness_lock(t.term_id);
 m:=app_private.configuration_actor(t.id,true);
 select *into t from public.request_types where id=d.request_type_id for update;
 select *into d from public.configuration_drafts where id=p_draft_id for update;
 requester:=coalesce(p_requester_id,m.id);
 if requester<>m.id and app_private.workflow_role(t.term_id,requester,t.receiving_unit_id)is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_draft_id,p_expected_version,p_review_hash,p_reason,requester);
 result:=app_private.begin_work_command('publish_configuration',p_request_id,payload);if result is not null then return result;end if;
 if d.version is distinct from p_expected_version or t.form_version_id is distinct from d.base_form_version_id
  or t.workflow_version_id is distinct from d.base_workflow_version_id then raise exception using errcode='40001',message='command_stale_version';end if;
 problem:=app_private.configuration_problem(t,d,requester);
 if problem is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_review_hash is distinct from app_private.configuration_review_hash(t,d,requester)then raise exception using errcode='40001',message='command_stale_version';end if;
 if d.published_version_id is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select work_item_id into control from public.configuration_controls where request_type_id=t.id;
 if control is null then
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)
   values(m.organization_id,m.term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select id into status from public.status_definitions where term_id=m.term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)
   values(m.organization_id,m.term_id,'announcement','Service configuration control','restricted',m.member_id,
   (select display_name from public.members where id=m.member_id),status)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
  insert into public.configuration_controls values(t.id,w.id);
 else update public.work_items set updated_at=statement_timestamp()where id=control returning *into w;end if;
 if d.kind='form'then
  select coalesce(max(version),0)+1 into n from public.form_versions where request_type_id=t.id;
  insert into public.form_versions(request_type_id,version,state,restricted,schema_json,published_at)
   values(t.id,n,'published',t.payload_classification='restricted',d.definition,statement_timestamp())returning id into new_version;
  update public.request_types set form_version_id=new_version where id=t.id;
 else
  select coalesce(max(version),0)+1 into n from public.workflow_versions where request_type_id=t.id;
  insert into public.workflow_versions(request_type_id,version,state,definition_json,published_at)
   values(t.id,n,'published',d.definition,statement_timestamp())returning id into new_version;
  update public.request_types set workflow_version_id=new_version where id=t.id;
 end if;
 insert into public.configuration_publications(request_type_id,kind,definition_version_id,base_form_version_id,base_workflow_version_id,rollback_version_id,
  control_id,control_version,actor_id,reason)values(t.id,d.kind,new_version,d.base_form_version_id,d.base_workflow_version_id,d.rollback_version_id,w.id,w.version,auth.uid(),btrim(p_reason));
 update public.configuration_drafts set published_version_id=new_version where id=d.id;
 result:=jsonb_build_object('draftId',d.id,'version',d.version,'definitionVersionId',new_version,'definitionVersion',n,'controlVersion',w.version);
 return app_private.finish_work_command(w,'publish_configuration',p_request_id,payload,result,'["configuration_version","published_pointer"]');
end$$;

revoke all on function app_private.configuration_actor(uuid,boolean),app_private.configuration_draft_receipt(public.configuration_drafts),
 app_private.configuration_problem(public.request_types,public.configuration_drafts,uuid),app_private.configuration_review_hash(public.request_types,public.configuration_drafts,uuid)
 from public,anon,authenticated,service_role;
revoke all on function public.read_configurations(uuid),public.read_configuration(uuid),public.save_configuration_draft(uuid,text,jsonb,uuid,uuid,integer,uuid,uuid),
 public.preview_configuration(uuid,uuid),public.publish_configuration(uuid,integer,text,text,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_configurations(uuid),public.read_configuration(uuid),public.save_configuration_draft(uuid,text,jsonb,uuid,uuid,integer,uuid,uuid),
 public.preview_configuration(uuid,uuid),public.publish_configuration(uuid,integer,text,text,uuid,uuid)to authenticated;
