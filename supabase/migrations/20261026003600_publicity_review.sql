-- Explicit privileged unit-scoped MCD capability; no grants are seeded.
alter table public.role_permissions drop constraint role_permissions_capability_check,drop constraint role_permissions_check;
alter table public.role_permissions add check(capability in('workspace.read','directory.read','profile.edit_own','committee.manage','department.review','finance.review','mcd.review','feedback.review','mentoring.view','reports.view','admin.configure','roles.manage')),
 add check((capability='profile.edit_own'and allowed_scope='own')or(capability in('committee.manage','department.review','finance.review','mcd.review','feedback.review')and allowed_scope='unit')or(capability in('workspace.read','directory.read','reports.view','admin.configure','roles.manage')and allowed_scope='term')or(capability='mentoring.view'and allowed_scope='own'));
alter table public.role_permissions alter column privileged set expression as(capability in('committee.manage','department.review','finance.review','mcd.review','feedback.review','admin.configure','roles.manage'));
-- P28: no institutional MCD designation/policy is seeded.
create table public.publicity_authority_designations(
 authority_id uuid primary key references public.role_assignments(id),authority_version integer not null,alternate_for_id uuid references public.role_assignments(id),official_reference text not null check(length(btrim(official_reference))between 1 and 1000),confirmed_by uuid not null references public.term_memberships(id),effective_from timestamptz not null,effective_to timestamptz not null,check(effective_to>effective_from));
create table public.publicity_review_policies(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,request_type_id uuid not null,workflow_version_id uuid not null,version integer not null check(version>0),stage_key text not null,primary_authority_id uuid not null references public.publicity_authority_designations(authority_id),official_reference text not null check(length(btrim(official_reference))between 1 and 1000),confirmed_by uuid not null references public.term_memberships(id),effective_from timestamptz not null,effective_to timestamptz not null,check(effective_to>effective_from),unique(request_type_id,workflow_version_id,version),foreign key(organization_id,term_id,request_type_id)references public.request_types(organization_id,term_id,id),foreign key(request_type_id,workflow_version_id)references public.workflow_versions(request_type_id,id));
create table public.publicity_review_bindings(assignment_id uuid primary key references public.approval_assignments(id),policy_id uuid not null references public.publicity_review_policies(id),unique(assignment_id,policy_id));
create table public.publicity_reviews(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,term_id uuid not null,request_revision_id uuid not null unique,revision_no integer not null,
 manifest_id uuid not null,manifest_hash text not null check(manifest_hash~'^[0-9a-f]{64}$'),payload jsonb not null,payload_hash text not null check(payload_hash~'^[0-9a-f]{64}$'),related_deliverable_id uuid not null references public.deliverables(work_item_id),finance_revision_id uuid references public.finance_revisions(id),submitted_by uuid not null references auth.users(id),
 foreign key(request_id,request_revision_id,revision_no)references public.request_revisions(request_id,id,revision_no),foreign key(manifest_id,request_id)references public.asset_manifests(id,work_item_id),unique(id,request_id,request_revision_id,payload_hash));
create index publicity_reviews_work on public.publicity_reviews(term_id,request_id,revision_no);
create table public.publicity_approvals(
 id uuid primary key default gen_random_uuid(),publicity_review_id uuid not null unique,request_id uuid not null,request_revision_id uuid not null,payload_hash text not null,
 decision_id uuid not null unique,assignment_id uuid not null unique,policy_id uuid not null,conditions text not null check(length(btrim(conditions))between 1 and 2000),expires_at timestamptz not null check(isfinite(expires_at)),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(publicity_review_id,request_id,request_revision_id,payload_hash)references public.publicity_reviews(id,request_id,request_revision_id,payload_hash),foreign key(decision_id,assignment_id,request_id,request_revision_id)references public.approval_decisions(id,assignment_id,request_id,revision_id),foreign key(assignment_id,policy_id)references public.publicity_review_bindings(assignment_id,policy_id));
create table public.publicity_approval_events(id uuid primary key default gen_random_uuid(),approval_id uuid not null unique references public.publicity_approvals(id),reason text not null check(length(btrim(reason))between 1 and 2000),actor_id uuid not null references auth.users(id),recorded_at timestamptz not null default statement_timestamp());
do $$declare t text;begin foreach t in array array['publicity_authority_designations','publicity_review_policies','publicity_review_bindings','publicity_reviews','publicity_approvals','publicity_approval_events']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('create trigger immutable_publicity_review before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);end loop;end$$;

create function app_private.publicity_policy(r public.requests)returns public.publicity_review_policies language sql stable security definer set search_path='' as $$
 select p from public.publicity_review_policies p join public.workflow_versions v on v.id=p.workflow_version_id join public.role_assignments primary_role on primary_role.id=p.primary_authority_id join public.term_memberships confirmer on confirmer.id=p.confirmed_by and confirmer.term_id=p.term_id
 where p.request_type_id=r.request_type_id and p.workflow_version_id=r.workflow_version_id and p.term_id=r.term_id
 and primary_role.term_id=r.term_id and primary_role.unit_id=r.receiving_unit_id and primary_role.organization_id=r.organization_id
 and jsonb_array_length(v.definition_json->'stages'->0->'reviewers')=1 and v.definition_json->'stages'->0->'reviewers'->>0=primary_role.term_membership_id::text
 and p.version=(select max(pp.version)from public.publicity_review_policies pp where pp.request_type_id=r.request_type_id and pp.workflow_version_id=r.workflow_version_id)
 and p.effective_from<=statement_timestamp()and p.effective_to>statement_timestamp()
 -- Only an explicitly confirmed single MCD decision stage is mapped here. Unsupported routing stays paused.
 and jsonb_array_length(v.definition_json->'stages')=1 and v.definition_json->'stages'->0->>'key'=p.stage_key
 and v.definition_json->'stages'->0->>'review'='one'and v.definition_json->'stages'->0->>'outcome'='approved'
 order by p.version desc limit 1
$$;

create function app_private.publicity_role(term uuid,member uuid,unit uuid,authority uuid default null)returns uuid language sql stable security definer set search_path='' as $$
 select a.id from public.role_assignments a join public.publicity_authority_designations d on d.authority_id=a.id and d.authority_version=a.version
 join public.term_memberships designation_confirmer on designation_confirmer.id=d.confirmed_by and designation_confirmer.term_id=a.term_id and designation_confirmer.organization_id=a.organization_id
 join public.roles role on role.id=a.role_id and role.state='active'join public.role_permissions rp on rp.role_id=role.id and rp.capability='mcd.review'and rp.allowed_scope='unit'
 join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id
 join public.terms t on t.id=tm.term_id and t.state='active'join public.organizations o on o.id=t.organization_id and o.state='active'
 join public.org_units u on u.id=a.unit_id and u.archived_at is null and u.review_service
 where a.term_id=term and a.term_membership_id=member and a.unit_id=unit and a.scope_type='unit'and a.status='active'and(authority is null or a.id=authority)
 and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()
 and tm.status='active'and tm.membership_kind='core'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from public.unit_memberships dep where dep.term_membership_id=tm.id and dep.unit_id=unit and dep.status='active'and dep.effective_from<=statement_timestamp()and dep.effective_to>statement_timestamp())
 and exists(select 1 from public.role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=tm.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())order by a.id limit 1
$$;

create function app_private.publicity_independent(r public.requests,member uuid,authority uuid default null)returns uuid language plpgsql stable security definer set search_path='' as $$
declare role uuid;p public.publicity_review_policies;person uuid;begin
 p:=app_private.publicity_policy(r);select member_id into person from public.term_memberships where id=member and term_id=r.term_id;
 if p.id is null or person is null or person=(select owner_member_id from public.work_items where id=r.work_item_id)then return null;end if;
 select d.authority_id into role from public.publicity_authority_designations d join public.role_assignments assigned_role on assigned_role.id=d.authority_id where assigned_role.term_membership_id=member and(authority is null or d.authority_id=authority)and(d.authority_id=p.primary_authority_id or d.alternate_for_id=p.primary_authority_id)and app_private.publicity_role(r.term_id,member,r.receiving_unit_id,d.authority_id)is not null order by d.authority_id limit 1;
 return role;
end$$;

create function app_private.publicity_assignment(r public.requests,member uuid)returns public.approval_assignments language sql stable security definer set search_path='' as $$
 select a from public.approval_assignments a join public.workflow_instances x on x.id=a.instance_id join public.publicity_review_bindings binding on binding.assignment_id=a.id and binding.policy_id=(app_private.publicity_policy(r)).id
 where a.request_id=r.work_item_id and a.revision_id=r.current_revision_id and a.reviewer_id=member and a.generation=x.generation and a.stage_key=x.current_stage_key
 and a.expires_at>statement_timestamp()and exists(select 1 from public.role_assignments ra where ra.id=a.authority_id and ra.version=a.authority_version)
 and app_private.publicity_independent(r,member,a.authority_id)is not null order by a.assigned_at desc limit 1
$$;

create function app_private.publicity_entry(r public.requests,x public.workflow_instances)returns text language plpgsql security definer set search_path='' as $$
declare s jsonb;rev public.request_revisions;v jsonb;k text;begin
 if (app_private.publicity_policy(r)).id is null or not exists(select 1 from public.publicity_reviews where request_revision_id=r.current_revision_id)then return 'typed_authority_module_pending';end if;
 if not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t)and t.receiving_unit_id=r.receiving_unit_id)then return 'routing_unavailable';end if;
 s:=app_private.workflow_stage(x);if s is null or s->>'review'not in('one','all')then return 'review_configuration_missing';end if;
 if s->>'outcome'='pending'and not exists(select 1 from public.workflow_versions v cross join lateral jsonb_array_elements(v.definition_json->'stages')with ordinality st(value,ordinality)where v.id=x.workflow_version_id and st.value->>'key'=x.current_stage_key and st.ordinality<jsonb_array_length(v.definition_json->'stages'))then return 'terminal_configuration_missing';end if;
 select * into rev from public.request_revisions where id=x.revision_id;
 v:=coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id));
 for k in select value from jsonb_array_elements_text(s->'entryFields')loop if not(v?k)or v->k in('null'::jsonb,'""'::jsonb,'[]'::jsonb)then return 'required_fields_missing';end if;end loop;
 if(coalesce((s->>'requiredManifest')::boolean,false)or coalesce((s->>'externalEvidenceRequired')::boolean,false))and not exists(select 1 from public.publicity_reviews where request_revision_id=x.revision_id and manifest_id is not null) then return 'required_documents_missing';end if;
 if s?'condition'then perform app_private.validate_form_condition(s->'condition',(select schema_json->'fields'from public.form_versions where id=r.form_version_id));if not app_private.form_condition(s->'condition',v)then return 'entry_condition_not_met';end if;end if;
 return null;
end$$;

create function app_private.lock_publicity_scope(r public.requests,member uuid)returns void language plpgsql set search_path='' as $$begin
 if current_setting('transaction_isolation')<>'read committed'then raise exception using errcode='25001',message='command_dependency_blocked';end if;
 perform pg_advisory_xact_lock(hashtextextended('publicity_policy:'||r.request_type_id::text,0));
 perform 1 from public.organizations where id=r.organization_id for share;perform 1 from public.terms where id=r.term_id for share;perform 1 from public.org_units where id=r.receiving_unit_id for share;
 perform 1 from public.role_assignments where term_membership_id=member order by id for share;
 perform 1 from public.roles where id in(select role_id from public.role_assignments where term_membership_id=member)order by id for share;
 perform 1 from public.role_permissions where role_id in(select role_id from public.role_assignments where term_membership_id=member)order by role_id,capability for share;
 perform 1 from public.term_memberships where id=member for share;perform 1 from public.members where id in(select member_id from public.term_memberships where id=member)for share;
 perform 1 from public.unit_memberships where term_membership_id=member order by id for share;
end$$;

create function app_private.publicity_policy_lock()returns trigger language plpgsql set search_path='' as $$begin perform pg_advisory_xact_lock(hashtextextended('publicity_policy:'||new.request_type_id::text,0));return new;end$$;

create function public.activate_publicity_review(p_work_item_id uuid,p_reviewer_id uuid,p_expected_revision integer,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.publicity_review_policies;x public.workflow_instances;role uuid;payload jsonb;result jsonb;problem text;assignment_id uuid;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_publicity_scope(r,m.id);m:=app_private.request_actor(w.term_id,true);
 if w.archived_at is not null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='mcd')or(m.member_id<>w.owner_member_id and app_private.publicity_role(r.term_id,m.id,r.receiving_unit_id)is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_reviewer_id,p_expected_revision,p_expected_version,p_reason);result:=app_private.begin_work_command('activate_publicity_review',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if r.request_state not in('paused','in_review')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select *into x from public.workflow_instances where revision_id=r.current_revision_id for update;p:=app_private.publicity_policy(r);role:=app_private.publicity_independent(r,p_reviewer_id);
 perform app_private.lock_publicity_scope(r,p_reviewer_id);role:=app_private.publicity_independent(r,p_reviewer_id);
 if p.id is null or x.current_stage_key<>p.stage_key or not exists(select 1 from public.publicity_reviews where request_revision_id=r.current_revision_id)then problem:='confirmed_fin_policy_required';
 elsif not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t))then problem:='routing_unavailable';
 elsif role is null then problem:='official_independent_fin_alternate_required';end if;
 if problem is null then problem:=app_private.publicity_entry(r,x);end if;
 if problem is null and x.state='active'and exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation and (app_private.publicity_assignment(r,a.reviewer_id)).id=a.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if problem is null then
  update public.workflow_instances set state='active',generation=generation+1,pause_reason=''where id=x.id returning *into x;
  insert into public.approval_assignments(organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at)
  select w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,1,p_reviewer_id,person.display_name,a.id,a.version,least(a.effective_to,tm.ends_at,d.effective_to,p.effective_to)from public.role_assignments a join public.publicity_authority_designations d on d.authority_id=a.id join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id where a.id=role returning id into assignment_id;
  insert into public.publicity_review_bindings values(assignment_id,p.id);
 else update public.workflow_instances set state='paused',pause_reason=problem where id=x.id returning *into x;end if;
 update public.requests set request_state=case when problem is null then 'in_review'else 'paused'end where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when problem is null then 'in_review'else 'paused'end)where id=w.id returning *into w;
 perform app_private.workflow_event(w,x,case when problem is null then 'activated'else 'paused'end,p_reason);
 return app_private.finish_work_command(w,'activate_publicity_review',p_request_id,payload,app_private.workflow_receipt(w,x),'["publicity_assignment"]');
end$$;

create trigger publicity_policy_lock before insert on public.publicity_review_policies for each row execute function app_private.publicity_policy_lock();

create function public.submit_publicity_request(p_work_item_id uuid,p_values jsonb,p_requested_on date,p_title text,p_payload jsonb,p_expected_version integer,p_request_id uuid,p_revision boolean default false)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;v jsonb:=p_payload;manifest public.asset_manifests;rev public.request_revisions;payload jsonb;result jsonb;pub_id uuid;publish_at timestamptz;k text;begin
 w:=app_private.request_owned(p_work_item_id,true);select *into r from public.requests where work_item_id=w.id;
 if p_revision is null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='mcd')or r.payload_classification<>'restricted'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 payload:=jsonb_build_array(p_work_item_id,p_values,p_requested_on,p_title,p_payload,p_expected_version,p_revision);result:=app_private.begin_work_command('submit_publicity_request',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if jsonb_typeof(v)is distinct from 'object'or octet_length(v::text)>40000 or app_private.definition_keys(v,array['caption','credits','channel','intendedUse','intendedAt','identity','checklist','evidenceMode','sourceUrl','manifestId','relatedDeliverableId','costBearing','financeRevisionId'])is distinct from true then raise exception using errcode='22023',message='command_validation_failed';end if;
 foreach k in array array['caption','credits','channel','intendedUse','identity']loop if app_private.definition_text(v->k,case when k='caption'then 20000 when k in('channel','identity')then 240 else 2000 end)is distinct from true or length(btrim(v->>k))=0 then raise exception using errcode='22023',message='command_validation_failed';end if;end loop;
 foreach k in array array['manifestId','relatedDeliverableId']loop if coalesce(v->>k,'')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'then raise exception using errcode='22023',message='command_validation_failed';end if;end loop;
 if(v->>'financeRevisionId'is not null and(v->>'financeRevisionId')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')or jsonb_typeof(v->'costBearing')is distinct from 'boolean'or v->'checklist'is distinct from '{"finalRendition":true,"copy":true,"credits":true,"identity":true,"use":true}'::jsonb or coalesce(v->>'evidenceMode','')not in('app_snapshot','exported_source')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if v->>'sourceUrl'is not null and v->>'sourceUrl'<>''and(v->>'sourceUrl')!~'^https://(drive\.google\.com/file/d/[A-Za-z0-9_-]+/(view|edit)|docs\.google\.com/(document|spreadsheets|presentation)/d/[A-Za-z0-9_-]+/(edit|view)|www\.canva\.com/design/[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)?/(edit|view))$'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if v->>'evidenceMode'='exported_source'and coalesce(v->>'sourceUrl','')=''then raise exception using errcode='22023',message='command_validation_failed';end if;
 begin publish_at:=(v->>'intendedAt')::timestamptz;exception when others then raise exception using errcode='22023',message='command_validation_failed';end;
 if publish_at is null or not isfinite(publish_at)or not exists(select 1 from public.terms where id=w.term_id and(publish_at at time zone'Asia/Manila')::date between starts_on and closes_on)then raise exception using errcode='22023',message='command_validation_failed';end if;
 select *into manifest from public.asset_manifests where id=(v->>'manifestId')::uuid and work_item_id=w.id;
 if manifest.id is null or not exists(select 1 from public.asset_manifest_items where manifest_id=manifest.id)or exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=manifest.id and(a.origin_work_item_id<>w.id or a.state<>'finalized'or a.kind<>'upload'or a.mime_type not in('application/pdf','image/png','image/jpeg')))then raise exception using errcode='22023',message='command_validation_failed';end if;
 if not exists(select 1 from public.work_items where id=(v->>'relatedDeliverableId')::uuid and kind='deliverable'and term_id=w.term_id and archived_at is null and public.can_access_work(id,'detail'))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if v->>'financeRevisionId'is not null and not exists(select 1 from public.finance_revisions f join public.work_items fw on fw.id=f.request_id where f.id=(v->>'financeRevisionId')::uuid and f.term_id=w.term_id and fw.owner_member_id=w.owner_member_id and public.can_access_work(fw.id,'detail'))then raise exception using errcode='42501',message='command_permission_denied';end if;
 v:=v||jsonb_build_object('intendedAt',publish_at,'sourceUrl',nullif(v->>'sourceUrl',''));
 result:=app_private.submit_request_revision(w.id,p_values,null,p_requested_on,p_title,p_expected_version,p_request_id,p_revision);select *into r from public.requests where work_item_id=w.id;select *into rev from public.request_revisions where id=r.current_revision_id;
 insert into public.publicity_reviews(request_id,term_id,request_revision_id,revision_no,manifest_id,manifest_hash,payload,payload_hash,related_deliverable_id,finance_revision_id,submitted_by)
 values(w.id,w.term_id,rev.id,rev.revision_no,manifest.id,manifest.sha256,v,encode(sha256(convert_to(jsonb_build_object('hashVersion','sha256-jsonb-v1','revisionId',rev.id,'envelopeManifestHash',rev.manifest_hash,'finalManifestHash',manifest.sha256,'payload',v)::text,'UTF8')),'hex'),(v->>'relatedDeliverableId')::uuid,(v->>'financeRevisionId')::uuid,auth.uid())returning id into pub_id;
 select *into w from public.work_items where id=w.id;return app_private.finish_work_command(w,'submit_publicity_request',p_request_id,payload,result||jsonb_build_object('publicityReviewId',pub_id),'["final_publicity_revision"]');end$$;

create function app_private.publicity_approval_state(a public.publicity_approvals)returns text language plpgsql stable security definer set search_path='' as $$declare r public.requests;assignment public.approval_assignments;begin
 select *into r from public.requests where work_item_id=a.request_id;select *into assignment from public.approval_assignments where id=a.assignment_id;
 if exists(select 1 from public.publicity_approval_events where approval_id=a.id)or exists(select 1 from public.work_items where id=a.request_id and archived_at is not null)then return 'revoked';end if;
 if r.current_revision_id<>a.request_revision_id or r.request_state in('revision_draft','needs_revision','cancelled')or(app_private.publicity_policy(r)).id is distinct from a.policy_id then return 'superseded';end if;
 if app_private.publicity_independent(r,assignment.reviewer_id,assignment.authority_id)is null then return 'revoked';end if;
 if a.expires_at<=statement_timestamp()then return 'expired';end if;return 'approved';end$$;
create function app_private.publicity_finance_state(p public.publicity_reviews)returns text language plpgsql stable security definer set search_path='' as $$declare f public.finance_revisions;a public.financial_authorizations;required boolean;begin
 required:=coalesce((p.payload->>'costBearing')::boolean,true)or p.finance_revision_id is not null or exists(select 1 from public.finance_revisions fr join public.requests r on r.current_revision_id=fr.request_revision_id join public.work_items w on w.id=fr.request_id where fr.related_deliverable_id=p.related_deliverable_id and r.request_state<>'cancelled'and w.archived_at is null);
 if not required then return 'not_required';end if;
 select fr.*into f from public.finance_revisions fr join public.requests r on r.current_revision_id=fr.request_revision_id join public.work_items fw on fw.id=fr.request_id join public.work_items pw on pw.id=p.request_id where fr.id=p.finance_revision_id and fr.related_deliverable_id=p.related_deliverable_id and fr.purpose=p.payload->>'intendedUse'and fw.owner_member_id=pw.owner_member_id and fw.archived_at is null;
 if f.id is null then return 'pending';end if;select *into a from public.financial_authorizations where finance_revision_id=f.id;
 if a.id is null or app_private.financial_authorization_state(a)<>'valid'or exists(select 1 from public.budget_entries where authorization_id=a.id and kind='release')or exists(select 1 from public.actual_finance_records ar where ar.request_id=f.request_id and not exists(select 1 from public.actual_finance_events e where e.record_id=ar.id))then return 'pending';end if;
 if exists(select 1 from public.finance_revisions fr join public.requests rr on rr.current_revision_id=fr.request_revision_id join public.work_items wi on wi.id=rr.work_item_id left join public.financial_authorizations fa on fa.finance_revision_id=fr.id where fr.related_deliverable_id=p.related_deliverable_id and rr.request_state<>'cancelled'and wi.archived_at is null and(fa.id is null or app_private.financial_authorization_state(fa)<>'valid'or exists(select 1 from public.actual_finance_records ar where ar.request_id=fr.request_id and not exists(select 1 from public.actual_finance_events e where e.record_id=ar.id))))then return 'pending';end if;return 'authorized';end$$;
create function public.decide_publicity_request(p_work_item_id uuid,p_expected_revision integer,p_expected_version integer,p_action text,p_reason text,p_conditions text,p_expires_at timestamptz,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;assignment public.approval_assignments;policy public.publicity_review_policies;x public.workflow_instances;pub public.publicity_reviews;payload jsonb;result jsonb;decision uuid;approval uuid;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_publicity_scope(r,m.id);assignment:=app_private.publicity_assignment(r,m.id);policy:=app_private.publicity_policy(r);
 if w.archived_at is not null or assignment.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_expected_revision,p_expected_version,p_action,p_reason,p_conditions,p_expires_at);result:=app_private.begin_work_command('decide_publicity_request',p_request_id,payload);if result is not null then return result;end if;
 select *into x from public.workflow_instances where revision_id=r.current_revision_id for update;select *into pub from public.publicity_reviews where request_revision_id=r.current_revision_id;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if r.request_state<>'in_review'or x.state<>'active'or pub.id is null or app_private.publicity_entry(r,x)is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action is null or p_action not in('approve','reject','request_revision')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='approve'then
 if p_conditions is null or length(btrim(p_conditions))not between 1 and 2000 or p_expires_at is null or not isfinite(p_expires_at)or p_expires_at<=statement_timestamp()or(p_expires_at at time zone'Asia/Manila')::date>(select closes_on from public.terms where id=w.term_id)or p_expires_at<(pub.payload->>'intendedAt')::timestamptz then raise exception using errcode='22023',message='command_validation_failed';end if;
 elsif p_conditions is not null or p_expires_at is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.approval_decisions(assignment_id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,action,reason,payload_hash,evidence_manifest_id)values(assignment.id,w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,p_action,p_reason,pub.payload_hash,pub.manifest_id)returning id into decision;
 if p_action='approve'then insert into public.publicity_approvals(publicity_review_id,request_id,request_revision_id,payload_hash,decision_id,assignment_id,policy_id,conditions,expires_at)values(pub.id,w.id,r.current_revision_id,pub.payload_hash,decision,assignment.id,policy.id,p_conditions,p_expires_at)returning id into approval;end if;
 update public.workflow_instances set state=case p_action when 'approve'then 'approved'when 'reject'then 'rejected'else 'needs_revision'end,pause_reason=''where id=x.id returning *into x;
 update public.requests set request_state=x.state,revision_resume_stage_key=case when p_action='request_revision'then policy.stage_key else revision_resume_stage_key end where work_item_id=w.id;update public.work_items set status_id=app_private.request_status(w.term_id,x.state)where id=w.id returning *into w;perform app_private.workflow_event(w,x,'decided',p_reason);
 return app_private.finish_work_command(w,'decide_publicity_request',p_request_id,payload,app_private.workflow_receipt(w,x)||jsonb_build_object('decisionId',decision,'approvalId',approval),'["publicity_decision"]');end$$;
create function public.revoke_publicity_approval(p_approval_id uuid,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare a public.publicity_approvals;w public.work_items;r public.requests;m public.term_memberships;payload jsonb;result jsonb;begin
 select *into a from public.publicity_approvals where id=p_approval_id;select *into w from public.work_items where id=a.request_id for update;select *into r from public.requests where work_item_id=w.id;m:=app_private.request_actor(w.term_id,true);perform app_private.lock_publicity_scope(r,m.id);
 if w.archived_at is not null or(app_private.publicity_assignment(r,m.id)).id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_approval_id,p_reason,p_expected_version);result:=app_private.begin_work_command('revoke_publicity_approval',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.publicity_approval_events(approval_id,reason,actor_id)values(a.id,p_reason,auth.uid());update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'revoke_publicity_approval',p_request_id,payload,jsonb_build_object('approvalId',a.id,'version',w.version),'["publicity_revocation"]');end$$;

create function public.read_publicity_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;pub public.publicity_reviews;policy public.publicity_review_policies;assignment public.approval_assignments;x public.workflow_instances;owner boolean;can_read boolean;approval public.publicity_approvals;begin
 m:=app_private.request_actor(p_term_id);select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id;select *into r from public.requests where work_item_id=w.id;
 if w.id is null or w.archived_at is not null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='mcd')then return null;end if;
 owner:=m.member_id=w.owner_member_id;assignment:=app_private.publicity_assignment(r,m.id);policy:=app_private.publicity_policy(r);
 if not owner and assignment.id is null then return null;end if;
 if not owner and p_revision is not null and p_revision<>r.current_revision then return null;end if;
 select *into pub from public.publicity_reviews where request_id=w.id and revision_no=coalesce(p_revision,r.current_revision);select *into x from public.workflow_instances where revision_id=r.current_revision_id;select *into approval from public.publicity_approvals where publicity_review_id=pub.id;can_read:=owner or assignment.id is not null;
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(w.organization_id,w.term_id,auth.uid(),'Current publicity participant','read_publicity_request',w.id,w.version,gen_random_uuid(),'{"fields":["final_publicity_access"]}');
 return jsonb_build_object('id',w.id,'termId',w.term_id,'version',w.version,'typeId',r.request_type_id,'revision',r.current_revision,'selectedRevision',pub.revision_no,'trackingId',r.tracking_id,'state',r.request_state,'isOwner',owner,'policyReady',policy.id is not null,
 'canAssign',owner and r.request_state in('paused','in_review')and(x.state<>'active'or not exists(select 1 from public.approval_assignments aa where aa.instance_id=x.id and aa.generation=x.generation and(app_private.publicity_assignment(r,aa.reviewer_id)).id=aa.id)),
 'canDecide',assignment.id is not null and r.request_state='in_review'and x.state='active'and app_private.publicity_entry(r,x)is null,'canRevoke',assignment.id is not null and approval.id is not null,
 'downloadContext',case when assignment.id is not null then x.review_context_id else w.id end,
 'reviewers',case when owner then coalesce((select jsonb_agg(jsonb_build_object('id',tm.id,'name',person.display_name))from public.term_memberships tm join public.members person on person.id=tm.member_id where tm.term_id=w.term_id and app_private.publicity_independent(r,tm.id)is not null),'[]')else '[]'::jsonb end,
 'publication',case when pub.id is not null and can_read then jsonb_build_object('id',pub.id,'payload',case when owner then pub.payload else pub.payload-'financeRevisionId'end,'payloadHash',pub.payload_hash,'manifestHash',pub.manifest_hash,'financeState',app_private.publicity_finance_state(pub),'files',coalesce((select jsonb_agg(jsonb_build_object('id',asset.id,'name',asset.filename,'sha256',asset.sha256,'size',asset.size_bytes))from public.asset_manifest_items i join public.assets asset on asset.id=i.asset_id where i.manifest_id=pub.manifest_id),'[]'),'approval',case when approval.id is not null then jsonb_build_object('id',approval.id,'state',app_private.publicity_approval_state(approval),'conditions',approval.conditions,'expiresAt',approval.expires_at)end)end,
 'history',case when owner then coalesce((select jsonb_agg(revision_no order by revision_no desc)from public.publicity_reviews where request_id=w.id),'[]')else '[]'::jsonb end);
end$$;
create function public.publicity_options(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 m:=app_private.request_actor(p_term_id);
 return jsonb_build_object('types',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',label,'formVersionId',form_version_id,'workflowVersionId',workflow_version_id,'ready',app_private.request_route_ready(t)))from public.request_types t where term_id=p_term_id and governed_kind='mcd'and archived_at is null),'[]'),
 'deliverables',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',title))from(select id,title from public.work_items where term_id=p_term_id and kind='deliverable'and archived_at is null and public.can_access_work(id,'detail')order by title,id limit 100)d),'[]'),
 'financePlans',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',tracking_id))from(select f.id,r.tracking_id from public.finance_revisions f join public.requests r on r.current_revision_id=f.request_revision_id join public.work_items w on w.id=r.work_item_id where f.term_id=p_term_id and w.owner_member_id=m.member_id and w.archived_at is null and r.request_state<>'cancelled'and public.can_access_work(w.id,'detail')order by r.tracking_id limit 100)f),'[]'),
 'cases',coalesce((select jsonb_agg(jsonb_build_object('id',work_item_id,'trackingId',tracking_id,'state',request_state))from(select r.*from public.requests r join public.request_types t on t.id=r.request_type_id join public.work_items w on w.id=r.work_item_id where r.term_id=p_term_id and t.governed_kind='mcd'and w.archived_at is null and(w.owner_member_id=m.member_id or(app_private.publicity_assignment(r,m.id)).id is not null)order by w.updated_at desc,w.id limit 100)r),'[]'));
end$$;
create function public.read_publicity_gate(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare w public.work_items;target uuid;pending boolean;begin
 select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id and kind in('task','deliverable')and archived_at is null;
 if w.id is null or not public.can_access_work(w.id,'detail')then return null;end if;target:=case when w.kind='deliverable'then w.id else w.parent_work_item_id end;
 if target is null or not public.can_access_work(target,'detail')then return '{"state":"not_verified"}';end if;
 if not exists(select 1 from public.publicity_reviews p join public.requests r on r.current_revision_id=p.request_revision_id join public.work_items wi on wi.id=r.work_item_id where p.related_deliverable_id=target and p.term_id=p_term_id and wi.archived_at is null and r.request_state<>'cancelled')then return '{"state":"not_verified"}';end if;
 select exists(select 1 from public.publicity_reviews p join public.requests r on r.current_revision_id=p.request_revision_id join public.work_items wi on wi.id=r.work_item_id left join public.publicity_approvals a on a.publicity_review_id=p.id where p.related_deliverable_id=target and p.term_id=p_term_id and wi.archived_at is null and r.request_state<>'cancelled'and(a.id is null or app_private.publicity_approval_state(a)<>'approved'or app_private.publicity_finance_state(p)='pending'))into pending;
 return jsonb_build_object('state',case when pending then 'pending'else 'reviewed'end);end$$;

alter function app_private.workflow_assignment_current(public.approval_assignments)rename to workflow_assignment_current_p27;
create function app_private.workflow_assignment_current(a public.approval_assignments)returns boolean language plpgsql stable security definer set search_path='' as $$declare r public.requests;begin select *into r from public.requests where work_item_id=a.request_id;
 if exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='mcd')then return(app_private.publicity_assignment(r,a.reviewer_id)).id=a.id;end if;return app_private.workflow_assignment_current_p27(a);end$$;
alter function public.authorize_asset_download(uuid,uuid,uuid)rename to authorize_asset_download_p27;
alter function public.authorize_asset_download_p27(uuid,uuid,uuid)set schema app_private;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare x public.workflow_instances;r public.requests;m public.term_memberships;a public.assets;payload jsonb;prior jsonb;begin
 select *into x from public.workflow_instances where review_context_id=p_work_item_id;select *into r from public.requests where work_item_id=x.request_id;
 if x.id is null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='mcd')then return app_private.authorize_asset_download_p27(p_work_item_id,p_asset_id,p_request_id);end if;
 m:=app_private.request_actor(r.term_id);if r.current_revision_id<>x.revision_id or(app_private.publicity_assignment(r,m.id)).id is null or exists(select 1 from public.work_items where id=r.work_item_id and archived_at is not null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 select asset.*into a from public.assets asset join public.asset_manifest_items i on i.asset_id=asset.id join public.publicity_reviews p on p.manifest_id=i.manifest_id where p.request_revision_id=r.current_revision_id and asset.id=p_asset_id and asset.state='finalized';if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_id);prior:=app_private.begin_work_command('download_publicity_review',p_request_id,payload);
 if prior is null then insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(r.organization_id,r.term_id,auth.uid(),'Current MCD reviewer','download_publicity_review',r.work_item_id,r.current_revision,p_request_id,'{"fields":["final_publicity_bytes"]}');insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'download_publicity_review',p_request_id,r.organization_id,r.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),'{}');end if;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind',a.kind,'mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256);end$$;

create function app_private.publicity_approval_guard()returns trigger language plpgsql set search_path='' as $$begin
 if not exists(select 1 from public.publicity_reviews p join public.approval_decisions d on d.id=new.decision_id and d.action='approve'and d.payload_hash=p.payload_hash and d.evidence_manifest_id=p.manifest_id where p.id=new.publicity_review_id)then raise exception using errcode='22023',message='command_validation_failed';end if;return new;end$$;
create trigger publicity_approval_guard before insert on public.publicity_approvals for each row execute function app_private.publicity_approval_guard();

create or replace function public.begin_request_revision(p_work_item_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;rev public.request_revisions;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version);result:=app_private.begin_work_command('begin_request_revision',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state not in('paused','needs_revision')and not(r.request_state='approved'and (exists(select 1 from public.finance_cases where request_id=w.id)or exists(select 1 from public.publicity_reviews where request_id=w.id)))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if exists(select 1 from public.request_types where id=r.request_type_id and archived_at is not null)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select * into rev from public.request_revisions where id=r.current_revision_id;
 insert into public.request_drafts(request_id,organization_id,term_id,payload_json,requested_centavos,requested_on,choice_snapshots)
 values(w.id,w.organization_id,w.term_id,coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),(select requested_centavos from public.request_finance_values where revision_id=rev.id),rev.requested_on,rev.choice_snapshots);
 update public.requests set request_state='revision_draft'where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,'revision_draft')where id=w.id returning * into w;
 perform app_private.request_event(w,'revision_started');return app_private.finish_work_command(w,'begin_request_revision',p_request_id,payload,app_private.request_receipt(w),'["request_revision_draft"]');
end$$;


alter function public.read_request(uuid,uuid,integer,integer)rename to read_request_p27;
alter function public.read_request_p27(uuid,uuid,integer,integer)set schema app_private;
create function public.read_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null,p_history_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin result:=app_private.read_request_p27(p_term_id,p_work_item_id,p_revision,p_history_page);if result is null then return null;end if;if result->>'governedKind'='mcd'and result->>'state'='approved'and exists(select 1 from public.publicity_reviews where request_id=p_work_item_id)then return result||'{"canRevise":true}';end if;return result;end$$;
do $$declare signature text;begin for signature in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','app_private')and(p.proname like '%publicity%'or p.proname in('workflow_assignment_current','workflow_assignment_current_p27','authorize_asset_download_p27','read_request_p27'))loop execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';end loop;end$$;
revoke all on function public.read_request(uuid,uuid,integer,integer),public.authorize_asset_download(uuid,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.submit_publicity_request(uuid,jsonb,date,text,jsonb,integer,uuid,boolean),public.activate_publicity_review(uuid,uuid,integer,integer,text,uuid),public.decide_publicity_request(uuid,integer,integer,text,text,text,timestamptz,uuid),public.revoke_publicity_approval(uuid,text,integer,uuid),public.read_publicity_request(uuid,uuid,integer),public.publicity_options(uuid),public.read_publicity_gate(uuid,uuid),public.read_request(uuid,uuid,integer,integer),public.authorize_asset_download(uuid,uuid,uuid)to authenticated;
