-- P22 general service reviews. Protected financial/publicity authority remains uninstalled.
alter table public.requests drop constraint requests_request_state_check;
alter table public.requests add check(request_state in('draft','revision_draft','paused','in_review','needs_revision','approved','rejected','completed','cancelled')),
 add column revision_resume_stage_key text;
alter table public.workflow_instances drop constraint workflow_instances_state_check;
alter table public.workflow_instances add check(state in('paused','active','needs_revision','approved','rejected','completed','superseded','cancelled')),
 add column generation integer not null default 0 check(generation between 0 and 100),add column review_context_id uuid not null default gen_random_uuid() unique;
alter table public.role_assignments add unique(organization_id,term_id,id);
create table public.approval_assignments(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,request_id uuid not null,revision_id uuid not null,instance_id uuid not null,
 stage_key text not null,generation integer not null check(generation>0),slot integer not null check(slot between 1 and 10),reviewer_id uuid not null,reviewer_name text not null,
 authority_id uuid not null,authority_version integer not null,expires_at timestamptz not null,assigned_at timestamptz not null default statement_timestamp(),
 unique(instance_id,generation,slot),unique(instance_id,generation,reviewer_id),unique(id,request_id,revision_id,instance_id,stage_key,generation),
 foreign key(organization_id,term_id,request_id,revision_id,instance_id) references public.workflow_instances(organization_id,term_id,request_id,revision_id,id),
 foreign key(organization_id,term_id,reviewer_id) references public.term_memberships(organization_id,term_id,id),
 foreign key(organization_id,term_id,authority_id) references public.role_assignments(organization_id,term_id,id)
);
create index approval_assignment_reviewer on public.approval_assignments(organization_id,term_id,reviewer_id);
create index approval_assignment_authority on public.approval_assignments(organization_id,term_id,authority_id);
create table public.approval_decisions(
 id uuid primary key default gen_random_uuid(),assignment_id uuid not null unique,organization_id uuid not null,term_id uuid not null,request_id uuid not null,revision_id uuid not null,instance_id uuid not null,
 stage_key text not null,generation integer not null,action text not null check(action in('approve','reject','request_revision')),reason text not null check(length(btrim(reason))between 1 and 2000),
 payload_hash text not null check(payload_hash~'^[0-9a-f]{64}$'),evidence_manifest_id uuid,decided_at timestamptz not null default statement_timestamp(),
 foreign key(assignment_id,request_id,revision_id,instance_id,stage_key,generation) references public.approval_assignments(id,request_id,revision_id,instance_id,stage_key,generation),
 foreign key(organization_id,term_id,request_id,revision_id) references public.request_revisions(organization_id,term_id,request_id,id),
 foreign key(evidence_manifest_id,request_id) references public.asset_manifests(id,work_item_id)
);
create index approval_decision_scope on public.approval_decisions(organization_id,term_id,request_id,revision_id);
create index approval_decision_evidence on public.approval_decisions(evidence_manifest_id,request_id);
create table public.request_workflow_outcomes(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,revision_id uuid not null,organization_id uuid not null,term_id uuid not null,decision_id uuid not null unique references public.approval_decisions(id),
 category text not null check(category in('general_approved','general_rejected','general_completed','needs_revision')),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(organization_id,term_id,request_id,revision_id) references public.request_revisions(organization_id,term_id,request_id,id)
);
create table public.request_workflow_events(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,revision_id uuid not null,organization_id uuid not null,term_id uuid not null,stage_key text not null,generation integer not null,
 action text not null check(action in('activated','reassigned','paused','decided')),actor_name text not null,reason text not null,recorded_at timestamptz not null default statement_timestamp(),
 foreign key(organization_id,term_id,request_id,revision_id) references public.request_revisions(organization_id,term_id,request_id,id)
);
create index workflow_outcome_scope on public.request_workflow_outcomes(organization_id,term_id,request_id,revision_id);
create index workflow_event_scope on public.request_workflow_events(organization_id,term_id,request_id,revision_id);
do $$declare t text;begin foreach t in array array['approval_assignments','approval_decisions','request_workflow_outcomes','request_workflow_events']loop
 execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 execute format('create trigger immutable_workflow_history before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);
end loop;end$$;

create function app_private.workflow_role(term uuid,member uuid,unit uuid,authority uuid default null)returns uuid language sql security definer set search_path='' as $$
 select a.id from public.role_assignments a join public.roles role on role.id=a.role_id and role.state='active'
 join public.role_permissions p on p.role_id=role.id and p.capability='department.review'and p.allowed_scope='unit'
 join public.term_memberships m on m.id=a.term_membership_id join public.members person on person.id=m.member_id
 join public.terms t on t.id=m.term_id and t.state='active'join public.organizations org on org.id=t.organization_id and org.state='active'
 join public.org_units u on u.id=a.unit_id and u.archived_at is null and u.review_service
 where a.term_id=term and a.term_membership_id=member and a.unit_id=unit and a.scope_type='unit'and a.status='active'
 and(authority is null or a.id=authority)and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()
 and m.status='active'and m.membership_kind='core'and m.joined_at<=statement_timestamp()and m.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from public.role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=m.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())
 and exists(select 1 from public.unit_memberships d where d.term_membership_id=m.id and d.unit_id=unit and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())order by a.id limit 1
$$;
create function app_private.workflow_manager(r public.requests,m public.term_memberships)returns boolean language sql security definer set search_path='' as $$
 select m.member_id<>(select owner_member_id from public.work_items where id=r.work_item_id)
 and app_private.workflow_role(r.term_id,m.id,r.receiving_unit_id)is not null
 and exists(select 1 from public.unit_memberships d where d.term_membership_id=m.id and d.unit_id=r.receiving_unit_id and d.deployment_type='head'and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())
$$;
create function app_private.workflow_assignment_current(a public.approval_assignments)returns boolean language sql security definer set search_path='' as $$
 select a.expires_at>statement_timestamp()and exists(select 1 from public.role_assignments role where role.id=a.authority_id and role.version=a.authority_version)
 and app_private.workflow_role(a.term_id,a.reviewer_id,(select receiving_unit_id from public.requests where work_item_id=a.request_id),a.authority_id)is not null
 and not exists(select 1 from public.work_items w join public.term_memberships m on m.member_id=w.owner_member_id and m.term_id=w.term_id where w.id=a.request_id and m.id=a.reviewer_id)
$$;
create function app_private.workflow_hooks_ready(r public.requests)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.request_types t where t.id=r.request_type_id and t.governed_kind='general')
 and not exists(select 1 from public.request_finance_values f where f.request_id=r.work_item_id)
 and not exists(select 1 from public.form_versions f cross join lateral jsonb_array_elements((f.schema_json->'fields')||coalesce((select jsonb_agg(child)from jsonb_array_elements(f.schema_json->'fields')parent cross join lateral jsonb_array_elements(coalesce(parent->'itemFields','[]'))child),'[]'))field where f.id=r.form_version_id and(coalesce(field->>'storage','custom')<>'custom' or field->>'type'='currency'))
$$;
create function app_private.workflow_stage(x public.workflow_instances)returns jsonb language sql stable security definer set search_path='' as $$
 select s.value from public.workflow_versions v cross join lateral jsonb_array_elements(v.definition_json->'stages')s where v.id=x.workflow_version_id and s.value->>'key'=x.current_stage_key
$$;
create function app_private.workflow_entry(r public.requests,x public.workflow_instances)returns text language plpgsql security definer set search_path='' as $$
declare s jsonb;rev public.request_revisions;v jsonb;k text;begin
 if not app_private.workflow_hooks_ready(r)then return 'typed_authority_module_pending';end if;
 if not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t)and t.receiving_unit_id=r.receiving_unit_id)then return 'routing_unavailable';end if;
 s:=app_private.workflow_stage(x);if s is null or s->>'review'not in('one','all')then return 'review_configuration_missing';end if;
 if s->>'outcome'='pending'and not exists(select 1 from public.workflow_versions v cross join lateral jsonb_array_elements(v.definition_json->'stages')with ordinality st(value,ordinality)where v.id=x.workflow_version_id and st.value->>'key'=x.current_stage_key and st.ordinality<jsonb_array_length(v.definition_json->'stages'))then return 'terminal_configuration_missing';end if;
 select * into rev from public.request_revisions where id=x.revision_id;
 v:=coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id));
 for k in select value from jsonb_array_elements_text(s->'entryFields')loop if not(v?k)or v->k in('null'::jsonb,'""'::jsonb,'[]'::jsonb)then return 'required_fields_missing';end if;end loop;
 if(coalesce((s->>'requiredManifest')::boolean,false)or coalesce((s->>'externalEvidenceRequired')::boolean,false))and rev.manifest_id is null then return 'required_documents_missing';end if;
 if s?'condition'then perform app_private.validate_form_condition(s->'condition',(select schema_json->'fields'from public.form_versions where id=r.form_version_id));if not app_private.form_condition(s->'condition',v)then return 'entry_condition_not_met';end if;end if;
 return null;
end$$;
create function app_private.workflow_current(x public.workflow_instances)returns boolean language sql security definer set search_path='' as $$
 select x.state='active'and exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation)
 and not exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation and not app_private.workflow_assignment_current(a))
$$;
create function app_private.workflow_receipt(w public.work_items,x public.workflow_instances)returns jsonb language sql stable set search_path='' as $$
 select app_private.request_receipt(w)||jsonb_build_object('instanceId',x.id,'stageKey',x.current_stage_key,'generation',x.generation,'workflowState',x.state,'pauseReason',case when x.state='paused'then x.pause_reason end)
$$;
create function app_private.workflow_event(w public.work_items,x public.workflow_instances,action text,reason text)returns void language sql set search_path='' as $$
 insert into public.request_workflow_events(request_id,revision_id,organization_id,term_id,stage_key,generation,action,actor_name,reason)
 select w.id,x.revision_id,w.organization_id,w.term_id,x.current_stage_key,x.generation,action,m.display_name,reason from public.members m where m.auth_user_id=auth.uid()and m.organization_id=w.organization_id
$$;
create function public.activate_request_workflow(p_work_item_id uuid,p_expected_revision integer,p_expected_stage text,p_expected_version integer,p_reviewers uuid[],p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;s jsonb;members uuid[];member uuid;authority uuid;ids uuid[]:='{}';problem text;payload jsonb;result jsonb;slot integer:=0;expiry timestamptz;begin
 select * into w from public.work_items where id=p_work_item_id for update;
 m:=app_private.request_actor(w.term_id,true);select * into r from public.requests where work_item_id=w.id;
 if r.request_type_id is null or not coalesce(app_private.workflow_manager(r,m),false)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_expected_revision,p_expected_stage,p_expected_version,p_reviewers,p_reason);result:=app_private.begin_work_command('activate_request_workflow',p_request_id,payload);if result is not null then return result;end if;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision or x.current_stage_key is distinct from p_expected_stage then raise exception using errcode='40001',message='command_stale_version';end if;
 if w.archived_at is not null or r.request_state not in('paused','in_review')or x.state not in('paused','active')or(x.state='active'and app_private.workflow_current(x))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 s:=app_private.workflow_stage(x);problem:=app_private.workflow_entry(r,x);
 members:=coalesce(p_reviewers,array(select value::uuid from jsonb_array_elements_text(s->'reviewers')));
 if array_ndims(members)>1 or cardinality(members)>10 or cardinality(members)<>(select count(distinct a)from unnest(members)a)or array_position(members,null)is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if(s->>'review'='one'and cardinality(members)<>1)or(s->>'review'='all'and(cardinality(members)=0 or cardinality(members)<>jsonb_array_length(s->'reviewers')))then problem:=coalesce(problem,'reviewer_configuration_missing');end if;
 foreach member in array members loop
  authority:=app_private.workflow_role(w.term_id,member,r.receiving_unit_id);
  if authority is null or exists(select 1 from public.term_memberships where id=member and member_id=w.owner_member_id)then problem:=coalesce(problem,'eligible_independent_reviewer_missing');end if;ids:=array_append(ids,authority);
 end loop;
 if problem is null then
  if x.generation>=100 then raise exception using errcode='22023',message='command_quota_limit';end if;
  update public.workflow_instances set state='active',generation=generation+1,pause_reason=''where id=x.id returning * into x;
  foreach member in array members loop slot:=slot+1;
   select least(a.effective_to,tm.ends_at)into expiry from public.role_assignments a join public.term_memberships tm on tm.id=a.term_membership_id where a.id=ids[slot];
   insert into public.approval_assignments(organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at)
   select w.organization_id,w.term_id,w.id,x.revision_id,x.id,x.current_stage_key,x.generation,slot,member,p.display_name,a.id,a.version,expiry from public.role_assignments a join public.term_memberships tm on tm.id=a.term_membership_id join public.members p on p.id=tm.member_id where a.id=ids[slot];
  end loop;update public.requests set request_state='in_review'where work_item_id=w.id;
 else update public.workflow_instances set state='paused',pause_reason=problem where id=x.id returning * into x;update public.requests set request_state='paused'where work_item_id=w.id;end if;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when problem is null then 'in_review'else 'paused'end)where id=w.id returning * into w;
 perform app_private.workflow_event(w,x,case when problem is not null then 'paused'when x.generation>1 then 'reassigned'else 'activated'end,p_reason);
 return app_private.finish_work_command(w,'activate_request_workflow',p_request_id,payload,app_private.workflow_receipt(w,x),'["workflow_assignment_state"]');
end$$;

create function app_private.workflow_member(r public.requests,x public.workflow_instances,m public.term_memberships,current_stage boolean default false)returns boolean language sql security definer set search_path='' as $$
 select m.member_id<>(select owner_member_id from public.work_items where id=r.work_item_id)and exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.reviewer_id=m.id and app_private.workflow_assignment_current(a)and(not current_stage or(a.generation=x.generation and a.stage_key=x.current_stage_key and app_private.workflow_current(x))))
$$;
create function public.read_request_workflow(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;rev public.request_revisions;owner boolean;manager boolean;participant boolean;can_read boolean;problem text;begin
 if not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id)and membership_kind='core')or not public.has_capability(p_term_id,'workspace.read')then return null;end if;
 m:=app_private.request_actor(p_term_id);select * into w from public.work_items where id=p_work_item_id and term_id=p_term_id;select * into r from public.requests where work_item_id=w.id;select * into x from public.workflow_instances where revision_id=r.current_revision_id;
 if x.id is null then return null;end if;owner:=m.member_id=w.owner_member_id;manager:=coalesce(app_private.workflow_manager(r,m),false);participant:=coalesce(app_private.workflow_member(r,x,m),false);
 if not(owner or manager or participant)then return null;end if;
 can_read:=owner or(app_private.workflow_member(r,x,m,true)and app_private.workflow_hooks_ready(r));
 select * into rev from public.request_revisions where id=x.revision_id;problem:=app_private.workflow_entry(r,x);
 if x.state='active'and not app_private.workflow_current(x)then problem:='current_authority_lost';end if;
 return app_private.workflow_receipt(w,x)||jsonb_build_object('effectivePaused',x.state='paused'or(x.state='active'and problem is not null),'effectivePauseReason',coalesce(problem,nullif(x.pause_reason,'')),
 'canManage',manager,'canAct',app_private.workflow_member(r,x,m,true)and problem is null and not exists(select 1 from public.approval_decisions d join public.approval_assignments a on a.id=d.assignment_id where d.instance_id=x.id and d.generation=x.generation and a.reviewer_id=m.id),'trackingId',r.tracking_id,'reviewMode',app_private.workflow_stage(x)->>'review',
 'assignments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.reviewer_name,'expiresAt',a.expires_at,'current',app_private.workflow_assignment_current(a),'isMe',a.reviewer_id=m.id)order by a.slot)from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation),'[]'),
 'decisions',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'stageKey',d.stage_key,'generation',d.generation,'action',d.action,'name',a.reviewer_name,'reason',case when owner or can_read or a.reviewer_id=m.id then d.reason end,'at',d.decided_at)order by d.decided_at,d.id)from public.approval_decisions d join public.approval_assignments a on a.id=d.assignment_id where d.instance_id=x.id),'[]'),
 'package',case when can_read then jsonb_build_object('title',rev.title_snapshot,'classification',r.payload_classification,'form',(select schema_json from public.form_versions where id=rev.form_version_id),'values',coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),'snapshots',rev.choice_snapshots,'requestedCentavos',(select requested_centavos from public.request_finance_values where revision_id=rev.id),
 'manifestHash',rev.manifest_hash,'downloadContext',case when owner then w.id else x.review_context_id end,'files',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.filename,'sha256',a.sha256,'size',a.size_bytes)order by a.id)from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=rev.manifest_id),'[]'))end);
end$$;

alter function public.authorize_asset_download(uuid,uuid,uuid)rename to authorize_asset_download_p21;
alter function public.authorize_asset_download_p21(uuid,uuid,uuid)set schema app_private;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare x public.workflow_instances;r public.requests;m public.term_memberships;a public.assets;payload jsonb;prior jsonb;begin
 select * into x from public.workflow_instances where review_context_id=p_work_item_id;
 if not found then return app_private.authorize_asset_download_p21(p_work_item_id,p_asset_id,p_request_id);end if;
 m:=app_private.request_actor(x.term_id);select * into r from public.requests where work_item_id=x.request_id;
 if x.revision_id is distinct from r.current_revision_id or not app_private.workflow_hooks_ready(r)or not app_private.workflow_member(r,x,m,true)or app_private.workflow_entry(r,x)is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select asset.*into a from public.assets asset join public.asset_manifest_items item on item.asset_id=asset.id join public.request_revisions rev on rev.manifest_id=item.manifest_id where rev.id=x.revision_id and asset.id=p_asset_id and asset.state='finalized';
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_id);prior:=app_private.begin_work_command('authorize_review_asset',p_request_id,payload);
 if prior is null then
  insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(x.organization_id,x.term_id,auth.uid(),'Authorized request reviewer','review_asset_download',x.request_id,r.current_revision,p_request_id,'{"fields":["review_package_access"]}');
  insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'authorize_review_asset',p_request_id,x.organization_id,x.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),'{}');
 end if;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind',a.kind,'mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256);
end$$;
create function public.transition_request(p_work_item_id uuid,p_assignment_id uuid,p_expected_revision integer,p_expected_stage text,p_expected_version integer,p_action text,p_reason text,p_evidence_manifest_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;a public.approval_assignments;rev public.request_revisions;s jsonb;payload jsonb;result jsonb;decision uuid;votes integer;needed integer;next jsonb;outcome text;resume text;begin
 select * into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);
 select * into r from public.requests where work_item_id=w.id;select * into a from public.approval_assignments where id=p_assignment_id and request_id=w.id;
 if a.id is null or a.reviewer_id<>m.id or m.member_id=w.owner_member_id or not app_private.workflow_assignment_current(a)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_assignment_id,p_expected_revision,p_expected_stage,p_expected_version,p_action,p_reason,p_evidence_manifest_id);result:=app_private.begin_work_command('transition_request',p_request_id,payload);if result is not null then return result;end if;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;select * into rev from public.request_revisions where id=x.revision_id;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision or x.current_stage_key is distinct from p_expected_stage or a.revision_id<>r.current_revision_id or a.stage_key<>x.current_stage_key or a.generation<>x.generation then raise exception using errcode='40001',message='command_stale_version';end if;
 perform 1 from public.terms where id=w.term_id for share;perform 1 from public.org_units where id=r.receiving_unit_id for share;
 perform 1 from public.role_assignments where id in(select authority_id from public.approval_assignments where instance_id=x.id and generation=x.generation)order by id for share;
 perform 1 from public.term_memberships where id in(select reviewer_id from public.approval_assignments where instance_id=x.id and generation=x.generation)order by id for share;
 perform 1 from public.members where id in(select member_id from public.term_memberships where id in(select reviewer_id from public.approval_assignments where instance_id=x.id and generation=x.generation))order by id for share;
 if r.request_state<>'in_review'or w.archived_at is not null or not app_private.workflow_current(x)or app_private.workflow_entry(r,x)is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action is null or p_action not in('approve','reject','request_revision')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 s:=app_private.workflow_stage(x);
 if(p_evidence_manifest_id is not null and p_evidence_manifest_id is distinct from rev.manifest_id)or(coalesce((s->>'externalEvidenceRequired')::boolean,false)and p_evidence_manifest_id is null)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='request_revision'then
  resume:=s->>'revisionStage';if resume is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;outcome:='needs_revision';
 end if;
 insert into public.approval_decisions(assignment_id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,action,reason,payload_hash,evidence_manifest_id)
 values(a.id,w.organization_id,w.term_id,w.id,rev.id,x.id,x.current_stage_key,x.generation,p_action,p_reason,encode(sha256(convert_to(jsonb_build_array(rev.id,rev.form_version_id,rev.workflow_version_id,rev.manifest_hash,coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),(select requested_centavos from public.request_finance_values where revision_id=rev.id))::text,'UTF8')),'hex'),p_evidence_manifest_id)returning id into decision;
 if p_action='reject'then outcome:='rejected';
 elsif p_action='approve'and outcome is null then
  select count(*)into votes from public.approval_decisions d where d.instance_id=x.id and d.generation=x.generation and d.action='approve';
  needed:=case when s->>'review'='one'then 1 else(select count(*)from public.approval_assignments where instance_id=x.id and generation=x.generation)end;
  if votes>=needed then
   if s->>'outcome'='pending'then
    select v.definition_json->'stages'->st.ordinality::int into next from public.workflow_versions v cross join lateral jsonb_array_elements(v.definition_json->'stages')with ordinality st(value,ordinality)where v.id=x.workflow_version_id and st.value->>'key'=x.current_stage_key;
    if next is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
    update public.workflow_instances set current_stage_key=next->>'key',state='paused',pause_reason='assignment_required'where id=x.id returning * into x;outcome:='paused';
   else outcome:=s->>'outcome';if outcome='revision'then resume:=s->>'revisionStage';if resume is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;outcome:='needs_revision';end if;end if;
  end if;
 end if;
 if outcome in('approved','rejected','completed','needs_revision')then
  insert into public.request_workflow_outcomes(request_id,revision_id,organization_id,term_id,decision_id,category)values(w.id,rev.id,w.organization_id,w.term_id,decision,case when outcome='needs_revision'then outcome else 'general_'||outcome end);
  update public.workflow_instances set state=outcome,pause_reason=''where id=x.id returning * into x;
 end if;
 if outcome is not null then update public.requests set request_state=outcome,revision_resume_stage_key=case when outcome='needs_revision'then resume else revision_resume_stage_key end where work_item_id=w.id;end if;
 update public.work_items set status_id=app_private.request_status(w.term_id,coalesce(outcome,'in_review'))where id=w.id returning * into w;
 perform app_private.workflow_event(w,x,'decided',p_reason);
 return app_private.finish_work_command(w,'transition_request',p_request_id,payload,app_private.workflow_receipt(w,x)||jsonb_build_object('decisionId',decision),'["workflow_decision","safe_general_outcome"]');
end$$;

create or replace function app_private.submit_request_revision(p_work_item_id uuid,p_values jsonb,p_requested_centavos bigint,p_requested_on date,p_title text,p_expected_version integer,p_request_id uuid,revision boolean)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;validated jsonb;payload jsonb;result jsonb;counter public.tracking_counters;namespace text;prefix text;seq bigint;tracking text;files uuid[];size integer;entries jsonb;manifest uuid;manifest_hash text;rid uuid;instance uuid;stage jsonb;member text;command text:=case when revision then 'revise_request'else 'submit_request'end;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_values,p_requested_centavos,p_requested_on,p_title,p_expected_version);result:=app_private.begin_work_command(command,p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state<>(case when revision then 'revision_draft'else 'draft'end) then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select * into t from public.request_types where id=r.request_type_id for share;
 perform 1 from public.org_units where id=r.receiving_unit_id and archived_at is null and review_service for share;
 if not found then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if not app_private.request_route_ready(t)or t.receiving_unit_id is distinct from r.receiving_unit_id then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_title is null or length(btrim(p_title,E' \t\r\n'))not between 1 and 240 or p_title~'[[:cntrl:]]'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if r.current_revision>=100 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if p_requested_on is not null and not(p_requested_on between '0001-01-01'and'9999-12-31')then raise exception using errcode='22023',message='command_validation_failed';end if;
 validated:=app_private.validate_request_values(r,p_values,p_requested_centavos,true);
 files:=app_private.request_file_ids((select schema_json->'fields'from public.form_versions where id=r.form_version_id),validated->'values');
 if cardinality(files)>20 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if exists(select 1 from public.assets where id=any(files)and(origin_work_item_id<>w.id or state<>'finalized'))or(select count(*)from public.assets where id=any(files))<>cardinality(files)then raise exception using errcode='42501',message='command_permission_denied';end if;
 entries:='[]';if cardinality(files)>0 then
  select sum(size_bytes)::int,jsonb_agg(jsonb_build_object('assetId',id,'sha256',sha256,'size',size_bytes,'mime',mime_type,'classification',classification,'source',source_snapshot)order by id)into size,entries from public.assets where id=any(files);
  if size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
  insert into public.asset_manifests(work_item_id,work_version,entries,sha256,size_bytes,created_by)values(w.id,w.version,entries,encode(sha256(convert_to(entries::text,'UTF8')),'hex'),size,auth.uid())returning id into manifest;
  insert into public.asset_manifest_items(manifest_id,asset_id)select manifest,unnest(files);
 end if;manifest_hash:=encode(sha256(convert_to(entries::text,'UTF8')),'hex');
 if not revision then
  namespace:=case t.governed_kind when 'fin'then 'FIN'when 'mcd'then 'MCD'else 'service:'||r.receiving_unit_id::text end;
  prefix:=case t.governed_kind when 'fin'then 'FIN'when 'mcd'then 'MCD'else(select code from public.org_units where id=r.receiving_unit_id)end;
  if t.governed_kind='general'and prefix in('FIN','MCD')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  -- One row-level atomic allocator shared by every type using this service namespace.
  insert into public.tracking_counters(organization_id,term_id,namespace_key,prefix,next_value)values(w.organization_id,w.term_id,namespace,prefix,2)
   on conflict(term_id,namespace_key)do update set next_value=public.tracking_counters.next_value+1 returning * into counter;
  seq:=counter.next_value-1;tracking:=counter.prefix||'-'||lpad(seq::text,greatest(3,length(seq::text)),'0');
 else tracking:=r.tracking_id;end if;
 insert into public.request_revisions(request_id,organization_id,term_id,revision_no,form_version_id,workflow_version_id,title_snapshot,ordinary_payload_json,payload_classification,choice_snapshots,manifest_id,manifest_hash,requested_on,submitted_by)
 values(w.id,w.organization_id,w.term_id,r.current_revision+1,r.form_version_id,r.workflow_version_id,btrim(p_title),case when r.payload_classification='ordinary'then validated->'values'end,r.payload_classification,validated->'snapshots',manifest,manifest_hash,p_requested_on,auth.uid())returning id into rid;
 if r.payload_classification='restricted'then insert into public.restricted_request_payloads values(rid,w.id,w.organization_id,w.term_id,validated->'values');end if;
 if p_requested_centavos is not null then insert into public.request_finance_values values(rid,w.id,w.organization_id,w.term_id,p_requested_centavos);end if;
 if revision then update public.workflow_instances set state='superseded'where request_id=w.id and state in('paused','active','needs_revision');end if;
 select coalesce((select value from jsonb_array_elements(v.definition_json->'stages')where value->>'key'=r.revision_resume_stage_key),v.definition_json->'stages'->0)into stage from public.workflow_versions v where v.id=r.workflow_version_id;
 insert into public.workflow_instances(request_id,revision_id,organization_id,term_id,workflow_version_id,current_stage_key)values(w.id,rid,w.organization_id,w.term_id,r.workflow_version_id,stage->>'key')returning id into instance;
 if jsonb_array_length(stage->'reviewers')=0 then
  insert into public.request_assignment_shells(instance_id,request_id,revision_id,organization_id,term_id,stage_key,review_mode)values(instance,w.id,rid,w.organization_id,w.term_id,stage->>'key',stage->>'review');
 else for member in select value from jsonb_array_elements_text(stage->'reviewers')loop
  -- A configured name is only a paused slot, never an active authority grant.
  insert into public.request_assignment_shells(instance_id,request_id,revision_id,organization_id,term_id,stage_key,review_mode,configured_member_id)
  values(instance,w.id,rid,w.organization_id,w.term_id,stage->>'key',stage->>'review',case when exists(select 1 from public.term_memberships where id=member::uuid and term_id=w.term_id and status='active')then member::uuid end);
 end loop;end if;
 update public.requests set current_revision=current_revision+1,current_revision_id=rid,request_state='paused',tracking_counter_id=case when revision then tracking_counter_id else counter.id end,tracking_prefix_snapshot=case when revision then tracking_prefix_snapshot else counter.prefix end,sequence_no=case when revision then sequence_no else seq end,tracking_id=tracking,original_requested_on=case when revision then original_requested_on else p_requested_on end where work_item_id=w.id;
 delete from public.request_drafts where request_id=w.id;
 update public.work_items set title=btrim(p_title),status_id=app_private.request_status(w.term_id,'paused')where id=w.id returning * into w;
 perform app_private.request_event(w,case when revision then 'revised'else 'submitted'end);
 return app_private.finish_work_command(w,command,p_request_id,payload,app_private.request_receipt(w),'["immutable_request_revision","tracking","paused_assignment_shell"]');
end$$;

create or replace function public.begin_request_revision(p_work_item_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;rev public.request_revisions;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version);result:=app_private.begin_work_command('begin_request_revision',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state not in('paused','needs_revision')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if exists(select 1 from public.request_types where id=r.request_type_id and archived_at is not null)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select * into rev from public.request_revisions where id=r.current_revision_id;
 insert into public.request_drafts(request_id,organization_id,term_id,payload_json,requested_centavos,requested_on,choice_snapshots)
 values(w.id,w.organization_id,w.term_id,coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),(select requested_centavos from public.request_finance_values where revision_id=rev.id),rev.requested_on,rev.choice_snapshots);
 update public.requests set request_state='revision_draft'where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,'revision_draft')where id=w.id returning * into w;
 perform app_private.request_event(w,'revision_started');return app_private.finish_work_command(w,'begin_request_revision',p_request_id,payload,app_private.request_receipt(w),'["request_revision_draft"]');
end$$;

create or replace function public.cancel_request(p_work_item_id uuid,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version,p_reason);result:=app_private.begin_work_command('cancel_request',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state not in('draft','revision_draft','paused','in_review','needs_revision')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.requests set request_state='cancelled'where work_item_id=w.id;
 update public.workflow_instances set state='cancelled'where request_id=w.id and state in('paused','active','needs_revision');
 update public.work_items set status_id=app_private.request_status(w.term_id,'cancelled')where id=w.id returning * into w;
 perform app_private.request_event(w,'cancelled',p_reason);return app_private.finish_work_command(w,'cancel_request',p_request_id,payload,app_private.request_receipt(w),'["request_cancelled"]');
end$$;


create or replace function public.read_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null,p_history_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;f public.form_versions;wf public.workflow_versions;selected public.request_revisions;d public.request_drafts;editable boolean;begin
 if not app_private.request_readable(p_term_id,p_work_item_id)then return null;end if;
 if p_history_page is null or p_history_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select * into w from public.work_items where id=p_work_item_id;select * into r from public.requests where work_item_id=w.id;
 select * into t from public.request_types where id=r.request_type_id;select * into f from public.form_versions where id=r.form_version_id;select * into wf from public.workflow_versions where id=r.workflow_version_id;
 select * into selected from public.request_revisions where request_id=w.id and revision_no=coalesce(p_revision,r.current_revision);
 if p_revision is not null and selected.id is null then return null;end if;
 select * into d from public.request_drafts where request_id=w.id;
 editable:=r.request_state in('draft','revision_draft')and t.archived_at is null and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active');
 return jsonb_build_object('id',w.id,'termId',w.term_id,'title',w.title,'version',w.version,'typeId',r.request_type_id,'typeLabel',r.type_label,'serviceLabel',r.service_label,
 'state',r.request_state,'revision',r.current_revision,'trackingId',r.tracking_id,'originalRequestedOn',r.original_requested_on,'acceptedOn',r.accepted_on,
 'formVersionId',f.id,'formVersion',f.version,'workflowVersionId',wf.id,'workflowVersion',wf.version,'form',f.schema_json,'classification',r.payload_classification,
 'canEdit',editable,'canSubmit',editable and app_private.request_route_ready(t)and t.receiving_unit_id is not distinct from r.receiving_unit_id,
 'canRevise',r.request_state in('paused','needs_revision')and t.archived_at is null and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'),
 'canCancel',r.request_state in('draft','revision_draft','paused','in_review','needs_revision')and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'),
 'nextAction',case when r.request_state='in_review'then case when exists(select 1 from public.workflow_instances wi where wi.revision_id=r.current_revision_id and app_private.workflow_current(wi))then 'Assigned reviewers are considering this revision. No financial or publicity clearance is implied.'else 'Review is paused because current authority changed. Await authorized reassignment.'end when r.request_state='needs_revision'then 'Reviewers requested changes. Start a revision draft; prior evidence stays immutable.'when r.request_state in('approved','rejected','completed')then 'General service outcome recorded: '||r.request_state||'. This is not FIN or MCD clearance.'when r.request_state='cancelled'then 'Cancelled. Saved content and any issued tracking ID are retained.'when not editable and r.request_state in('draft','revision_draft')then 'Draft retained. This service or term is archived or unavailable.'when editable and t.receiving_unit_id is distinct from r.receiving_unit_id then 'Service routing changed since this draft began. Keep this saved draft and start a new draft from the current service; routing is never changed automatically.'when editable and not app_private.request_route_ready(t)then 'Draft can be saved. Active receiving service, contacts and confirmed routing are required before submission.'when editable then 'Save incomplete work or submit the current form. Submission is not FIN, MCD or school approval.'else 'Submitted and paused. Authorized reviewer assignment and decision processing are not configured. This status does not authorize costs or publicity.'end,
 'draft',case when d.request_id is not null then jsonb_build_object('values',d.payload_json,'snapshots',d.choice_snapshots,'requestedCentavos',d.requested_centavos,'requestedOn',d.requested_on)end,
 'selected',case when selected.id is not null then jsonb_build_object('revision',selected.revision_no,'title',selected.title_snapshot,'values',coalesce(selected.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=selected.id)),
 'snapshots',selected.choice_snapshots,'requestedCentavos',(select requested_centavos from public.request_finance_values where revision_id=selected.id),'requestedOn',selected.requested_on,'submittedAt',selected.submitted_at,'manifestHash',selected.manifest_hash,
 'files',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.filename,'size',a.size_bytes,'mime',a.mime_type,'sha256',a.sha256)order by a.id)from public.asset_manifest_items mi join public.assets a on a.id=mi.asset_id where mi.manifest_id=selected.manifest_id),'[]'))end,
 'revisionHeaders',coalesce((select jsonb_agg(jsonb_build_object('revision',h.revision_no,'title',h.title_snapshot,'requestedOn',h.requested_on,'submittedAt',h.submitted_at)order by h.revision_no desc)from public.request_revisions h where h.request_id=w.id),'[]'),
 'history',jsonb_build_object('page',p_history_page,'pageSize',25,'total',(select count(*)from public.request_events where request_id=w.id),'items',coalesce((select jsonb_agg(jsonb_build_object('action',e.action,'revision',e.revision_no,'actor',e.actor_name,'reason',e.reason,'at',e.recorded_at)order by e.recorded_at desc,e.id desc)from(select * from public.request_events where request_id=w.id order by recorded_at desc,id desc limit 25 offset(p_history_page-1)*25)e),'[]')));
end$$;

create or replace function app_private.request_status(term uuid,p_state text) returns uuid language plpgsql set search_path='' as $$declare id uuid;begin
 insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)
 select organization_id,term,'request','tracked_'||p_state,case when p_state in('draft','revision_draft')then 'draft' when p_state in('approved','rejected','completed','needs_revision','cancelled')then p_state else 'active'end,case when p_state='paused'then 'Submitted · paused'else initcap(replace(p_state,'_',' '))end from public.terms where terms.id=term on conflict(term_id,resource_kind,stable_key)do nothing;
 select s.id into id from public.status_definitions s where s.term_id=term and resource_kind='request' and stable_key='tracked_'||p_state;return id;end$$;

create function app_private.workflow_condition_shape(c jsonb,depth integer default 1)returns void language plpgsql immutable set search_path='' as $$declare v jsonb;begin
 if depth>4 or octet_length(c::text)>8000 or not coalesce(app_private.definition_keys(c,array['op','conditions','field','value']),false)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if c->>'op'in('and','or')then
  if not app_private.definition_keys(c,array['op','conditions'])or jsonb_typeof(c->'conditions')is distinct from 'array'or jsonb_array_length(c->'conditions')not between 1 and 5 then raise exception using errcode='22023',message='command_validation_failed';end if;
  for v in select value from jsonb_array_elements(c->'conditions')loop perform app_private.workflow_condition_shape(v,depth+1);end loop;
 else
  if coalesce(c->>'op','')not in('eq','in','gt','gte','lt','lte')or not(c?'field'and c?'value')or c?'conditions'or coalesce(c->>'field','')!~'^[a-z][a-z0-9_]{0,59}$'then raise exception using errcode='22023',message='command_validation_failed';end if;
  if c->>'op'='in'and(jsonb_typeof(c->'value')is distinct from 'array'or jsonb_array_length(c->'value')not between 1 and 50)then raise exception using errcode='22023',message='command_validation_failed';end if;
  for v in select value from jsonb_array_elements(case when c->>'op'='in'then c->'value'else jsonb_build_array(c->'value')end)loop if jsonb_typeof(v)not in('string','number','boolean')then raise exception using errcode='22023',message='command_validation_failed';end if;end loop;
 end if;
end$$;

create or replace function app_private.validate_workflow_definition(s jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare f jsonb; keys text[]:='{}'; k text;
begin
 if not coalesce(app_private.definition_keys(s,array['schemaVersion','stages']),false) or s->'schemaVersion' is distinct from '1'::jsonb or jsonb_typeof(s->'stages') is distinct from 'array' or jsonb_array_length(s->'stages') not between 1 and 12 or octet_length(s::text)>20000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 for f in select value from jsonb_array_elements(s->'stages') loop
  k:=f->>'key';if not coalesce(app_private.definition_keys(f,array['key','label','review','reviewers','outcome','revisionStage','entryFields','reminderDays','condition','requiredManifest','externalEvidenceRequired']),false) or k is null or k!~'^[a-z][a-z0-9_]{0,59}$' or k=any(keys) or not coalesce(app_private.definition_text(f->'label',200),false)
   or coalesce(f->>'review','') not in('none','one','all') or jsonb_typeof(f->'reviewers') is distinct from 'array' or jsonb_array_length(f->'reviewers')>10
   or coalesce(f->>'outcome','') not in('pending','revision','approved','rejected','completed') or jsonb_typeof(f->'entryFields') is distinct from 'array' or jsonb_array_length(f->'entryFields')>50
   or jsonb_typeof(f->'reminderDays') is distinct from 'number' or (f->>'reminderDays')::numeric not between 1 and 365 or trunc((f->>'reminderDays')::numeric)<>(f->>'reminderDays')::numeric then raise exception using errcode='22023',message='command_validation_failed';end if;
  if exists(select 1 from jsonb_array_elements_text(f->'reviewers') r where r!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') or exists(select 1 from jsonb_array_elements_text(f->'entryFields') r where r!~'^[a-z][a-z0-9_]{0,59}$') then raise exception using errcode='22023',message='command_validation_failed';end if;
  if f?'condition'then perform app_private.workflow_condition_shape(f->'condition');end if;
  if(f?'requiredManifest'and jsonb_typeof(f->'requiredManifest')<>'boolean')or(f?'externalEvidenceRequired'and jsonb_typeof(f->'externalEvidenceRequired')<>'boolean')then raise exception using errcode='22023',message='command_validation_failed';end if;
  keys:=array_append(keys,k);
 end loop;
 for f in select value from jsonb_array_elements(s->'stages') loop
  if f?'revisionStage' and not coalesce((f->>'revisionStage')=any(keys),false) then raise exception using errcode='22023',message='command_validation_failed';end if;
 end loop;
end$$;


revoke all on function public.activate_request_workflow(uuid,integer,text,integer,uuid[],text,uuid),public.transition_request(uuid,uuid,integer,text,integer,text,text,uuid,uuid),public.read_request_workflow(uuid,uuid),public.authorize_asset_download(uuid,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.activate_request_workflow(uuid,integer,text,integer,uuid[],text,uuid),public.transition_request(uuid,uuid,integer,text,integer,text,text,uuid,uuid),public.read_request_workflow(uuid,uuid),public.authorize_asset_download(uuid,uuid,uuid)to authenticated;
revoke all on function app_private.workflow_role(uuid,uuid,uuid,uuid),app_private.workflow_manager(public.requests,public.term_memberships),app_private.workflow_assignment_current(public.approval_assignments),app_private.workflow_hooks_ready(public.requests),app_private.workflow_stage(public.workflow_instances),app_private.workflow_entry(public.requests,public.workflow_instances),app_private.workflow_current(public.workflow_instances),app_private.workflow_receipt(public.work_items,public.workflow_instances),app_private.workflow_event(public.work_items,public.workflow_instances,text,text),app_private.workflow_member(public.requests,public.workflow_instances,public.term_memberships,boolean),app_private.authorize_asset_download_p21(uuid,uuid,uuid)from public,anon,authenticated,service_role;
revoke all on function app_private.workflow_condition_shape(jsonb,integer)from public,anon,authenticated,service_role;
