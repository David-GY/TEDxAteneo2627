-- P26: empty institutional configuration. No role/policy/designation is seeded.
create table public.finance_authority_designations(
 authority_id uuid primary key references public.role_assignments(id),authority_version integer not null,
 alternate_for_id uuid references public.role_assignments(id),official_reference text not null check(length(btrim(official_reference))between 1 and 1000),
 confirmed_by uuid not null references public.term_memberships(id),effective_from timestamptz not null,effective_to timestamptz not null,check(effective_to>effective_from)
);
create table public.finance_authorization_policies(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,request_type_id uuid not null,workflow_version_id uuid not null,
 version integer not null check(version>0),stage_key text not null,primary_authority_id uuid not null references public.finance_authority_designations(authority_id),
 external_requirement text not null check(external_requirement in('required','not_required')),official_reference text not null check(length(btrim(official_reference))between 1 and 1000),
 confirmed_by uuid not null references public.term_memberships(id),effective_from timestamptz not null,effective_to timestamptz not null,check(effective_to>effective_from),
 unique(request_type_id,workflow_version_id,version),foreign key(organization_id,term_id,request_type_id)references public.request_types(organization_id,term_id,id),
 foreign key(request_type_id,workflow_version_id)references public.workflow_versions(request_type_id,id)
);
alter table public.finance_revisions add unique(id,request_id,request_revision_id,payload_hash);
alter table public.approval_decisions add unique(id,assignment_id,request_id,revision_id);
create table public.finance_review_bindings(assignment_id uuid primary key references public.approval_assignments(id),policy_id uuid not null references public.finance_authorization_policies(id),unique(assignment_id,policy_id));
create table public.financial_authorizations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,request_id uuid not null,
 finance_revision_id uuid not null unique references public.finance_revisions(id),request_revision_id uuid not null,policy_id uuid not null references public.finance_authorization_policies(id),
 assignment_id uuid not null unique references public.approval_assignments(id),decision_id uuid not null unique references public.approval_decisions(id),payload_hash text not null check(payload_hash~'^[0-9a-f]{64}$'),
 requested_total_centavos bigint not null check(requested_total_centavos between 0 and 9007199254740991),ceiling_centavos bigint not null check(ceiling_centavos between 0 and requested_total_centavos),
 purpose text not null,conditions text not null check(length(btrim(conditions))between 1 and 2000),expires_at timestamptz not null,
 external_outcome text not null check(external_outcome in('verified','pending','not_required')),external_manifest_id uuid,recorded_at timestamptz not null default statement_timestamp(),
 foreign key(organization_id,term_id,request_id,request_revision_id)references public.request_revisions(organization_id,term_id,request_id,id),
 foreign key(external_manifest_id,request_id)references public.asset_manifests(id,work_item_id),
 foreign key(finance_revision_id,request_id,request_revision_id,payload_hash)references public.finance_revisions(id,request_id,request_revision_id,payload_hash),
 foreign key(decision_id,assignment_id,request_id,request_revision_id)references public.approval_decisions(id,assignment_id,request_id,revision_id),
 foreign key(assignment_id,policy_id)references public.finance_review_bindings(assignment_id,policy_id),check(isfinite(expires_at))
);
create table public.financial_authorization_events(
 id uuid primary key default gen_random_uuid(),authorization_id uuid not null references public.financial_authorizations(id),
 kind text not null check(kind in('revoked','external_verified')),reason text not null check(length(btrim(reason))between 1 and 2000),
 actor_id uuid not null references auth.users(id),manifest_id uuid references public.asset_manifests(id),recorded_at timestamptz not null default statement_timestamp(),unique(authorization_id,kind)
);
create table public.finance_case_metadata(
 request_id uuid primary key references public.finance_cases(request_id),contact_label text not null check(length(btrim(contact_label))between 1 and 200),updated_at timestamptz not null default statement_timestamp()
);
do $$declare t text;begin foreach t in array array['finance_authority_designations','finance_authorization_policies','financial_authorizations','financial_authorization_events','finance_case_metadata','finance_review_bindings']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 if t<>'finance_case_metadata'then execute format('create trigger immutable_financial_authority before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);end if;
 end loop;end$$;
create index financial_authorizations_scope on public.financial_authorizations(term_id,request_id,request_revision_id);

create function app_private.finance_policy(r public.requests)returns public.finance_authorization_policies language sql stable security definer set search_path='' as $$
 select p from public.finance_authorization_policies p join public.workflow_versions v on v.id=p.workflow_version_id join public.role_assignments primary_role on primary_role.id=p.primary_authority_id join public.term_memberships confirmer on confirmer.id=p.confirmed_by and confirmer.term_id=p.term_id
 where p.request_type_id=r.request_type_id and p.workflow_version_id=r.workflow_version_id and p.term_id=r.term_id
 and primary_role.term_id=r.term_id and primary_role.unit_id=r.receiving_unit_id and primary_role.organization_id=r.organization_id
 and jsonb_array_length(v.definition_json->'stages'->0->'reviewers')=1 and v.definition_json->'stages'->0->'reviewers'->>0=primary_role.term_membership_id::text
 and p.version=(select max(pp.version)from public.finance_authorization_policies pp where pp.request_type_id=r.request_type_id and pp.workflow_version_id=r.workflow_version_id)
 and p.effective_from<=statement_timestamp()and p.effective_to>statement_timestamp()
 -- Only an explicitly confirmed single FIN decision stage is mapped here. Unsupported routing stays paused.
 and jsonb_array_length(v.definition_json->'stages')=1 and v.definition_json->'stages'->0->>'key'=p.stage_key
 and v.definition_json->'stages'->0->>'review'='one'and v.definition_json->'stages'->0->>'outcome'='approved'
 order by p.version desc limit 1
$$;
create function app_private.finance_role(term uuid,member uuid,unit uuid,authority uuid default null)returns uuid language sql stable security definer set search_path='' as $$
 select a.id from public.role_assignments a join public.finance_authority_designations d on d.authority_id=a.id and d.authority_version=a.version
 join public.term_memberships designation_confirmer on designation_confirmer.id=d.confirmed_by and designation_confirmer.term_id=a.term_id and designation_confirmer.organization_id=a.organization_id
 join public.roles role on role.id=a.role_id and role.state='active'join public.role_permissions rp on rp.role_id=role.id and rp.capability='finance.review'and rp.allowed_scope='unit'
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
create function app_private.finance_independent(r public.requests,member uuid,authority uuid default null)returns uuid language plpgsql stable security definer set search_path='' as $$
declare role uuid;p public.finance_authorization_policies;person uuid;begin
 p:=app_private.finance_policy(r);select member_id into person from public.term_memberships where id=member and term_id=r.term_id;
 if p.id is null or person is null or person=(select owner_member_id from public.work_items where id=r.work_item_id)or exists(select 1 from public.finance_revisions where request_revision_id=r.current_revision_id and beneficiary_member_id=person)then return null;end if;
 select d.authority_id into role from public.finance_authority_designations d join public.role_assignments assigned_role on assigned_role.id=d.authority_id where assigned_role.term_membership_id=member and(authority is null or d.authority_id=authority)and(d.authority_id=p.primary_authority_id or d.alternate_for_id=p.primary_authority_id)and app_private.finance_role(r.term_id,member,r.receiving_unit_id,d.authority_id)is not null order by d.authority_id limit 1;
 return role;
end$$;
create function app_private.finance_assignment(r public.requests,member uuid)returns public.approval_assignments language sql stable security definer set search_path='' as $$
 select a from public.approval_assignments a join public.workflow_instances x on x.id=a.instance_id join public.finance_review_bindings binding on binding.assignment_id=a.id and binding.policy_id=(app_private.finance_policy(r)).id
 where a.request_id=r.work_item_id and a.revision_id=r.current_revision_id and a.reviewer_id=member and a.generation=x.generation and a.stage_key=x.current_stage_key
 and a.expires_at>statement_timestamp()and exists(select 1 from public.role_assignments ra where ra.id=a.authority_id and ra.version=a.authority_version)
 and app_private.finance_independent(r,member,a.authority_id)is not null order by a.assigned_at desc limit 1
$$;
create function public.activate_finance_review(p_work_item_id uuid,p_reviewer_id uuid,p_expected_revision integer,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.finance_authorization_policies;x public.workflow_instances;role uuid;payload jsonb;result jsonb;problem text;assignment_id uuid;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_finance_scope(r,m.id);m:=app_private.request_actor(w.term_id,true);
 if w.archived_at is not null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='fin')or(m.member_id<>w.owner_member_id and app_private.finance_role(r.term_id,m.id,r.receiving_unit_id)is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_reviewer_id,p_expected_revision,p_expected_version,p_reason);result:=app_private.begin_work_command('activate_finance_review',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if r.request_state not in('paused','in_review')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select *into x from public.workflow_instances where revision_id=r.current_revision_id for update;p:=app_private.finance_policy(r);role:=app_private.finance_independent(r,p_reviewer_id);
 perform app_private.lock_finance_scope(r,p_reviewer_id);role:=app_private.finance_independent(r,p_reviewer_id);
 if p.id is null or x.current_stage_key<>p.stage_key or not exists(select 1 from public.finance_revisions where request_revision_id=r.current_revision_id)then problem:='confirmed_fin_policy_required';
 elsif not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t))then problem:='routing_unavailable';
 elsif role is null then problem:='official_independent_fin_alternate_required';end if;
 if problem is null then problem:=app_private.finance_entry(r,x);end if;
 if problem is null and x.state='active'and exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation and (app_private.finance_assignment(r,a.reviewer_id)).id=a.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if problem is null then
  update public.workflow_instances set state='active',generation=generation+1,pause_reason=''where id=x.id returning *into x;
  insert into public.approval_assignments(organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at)
  select w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,1,p_reviewer_id,person.display_name,a.id,a.version,least(a.effective_to,tm.ends_at,d.effective_to,p.effective_to)from public.role_assignments a join public.finance_authority_designations d on d.authority_id=a.id join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id where a.id=role returning id into assignment_id;
  insert into public.finance_review_bindings values(assignment_id,p.id);
 else update public.workflow_instances set state='paused',pause_reason=problem where id=x.id returning *into x;end if;
 update public.requests set request_state=case when problem is null then 'in_review'else 'paused'end where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when problem is null then 'in_review'else 'paused'end)where id=w.id returning *into w;
 perform app_private.workflow_event(w,x,case when problem is null then 'activated'else 'paused'end,p_reason);
 return app_private.finish_work_command(w,'activate_finance_review',p_request_id,payload,app_private.workflow_receipt(w,x),'["finance_assignment"]');
end$$;
create function app_private.financial_authorization_state(a public.financial_authorizations)returns text language plpgsql stable security definer set search_path='' as $$
declare r public.requests;p public.finance_authorization_policies;assignment public.approval_assignments;begin
 select *into r from public.requests where work_item_id=a.request_id;p:=app_private.finance_policy(r);select *into assignment from public.approval_assignments where id=a.assignment_id;
 if exists(select 1 from public.financial_authorization_events where authorization_id=a.id and kind='revoked')or exists(select 1 from public.work_items where id=r.work_item_id and archived_at is not null)then return 'revoked';end if;
 if r.current_revision_id<>a.request_revision_id or r.request_state in('revision_draft','needs_revision','cancelled')or p.id is distinct from a.policy_id then return 'superseded';end if;
 if app_private.finance_independent(r,assignment.reviewer_id,assignment.authority_id)is null then return 'revoked';end if;
 if a.expires_at<=statement_timestamp()then return 'expired';end if;
 if a.external_outcome='pending'and not exists(select 1 from public.financial_authorization_events where authorization_id=a.id and kind='external_verified')then return 'pending_external';end if;return 'valid';
end$$;
create function public.decide_finance_request(p_work_item_id uuid,p_expected_revision integer,p_expected_version integer,p_action text,p_reason text,p_ceiling_centavos text,p_conditions text,p_expires_at timestamptz,p_external_outcome text,p_external_manifest_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.finance_authorization_policies;a public.approval_assignments;x public.workflow_instances;f public.finance_revisions;payload jsonb;result jsonb;decision uuid;authorization_id uuid;ceiling bigint;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_finance_scope(r,m.id);a:=app_private.finance_assignment(r,m.id);p:=app_private.finance_policy(r);
 if w.archived_at is not null or a.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform 1 from public.role_assignments where id=a.authority_id for share;perform 1 from public.term_memberships where id=a.reviewer_id for share;
 if app_private.finance_independent(r,m.id,a.authority_id)is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_expected_revision,p_expected_version,p_action,p_reason,p_ceiling_centavos,p_conditions,p_expires_at,p_external_outcome,p_external_manifest_id);result:=app_private.begin_work_command('decide_finance_request',p_request_id,payload);if result is not null then return result;end if;
 select *into x from public.workflow_instances where id=a.instance_id for update;select *into f from public.finance_revisions where request_revision_id=r.current_revision_id;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if app_private.finance_entry(r,x)is not null or r.request_state<>'in_review'or x.state<>'active'or x.current_stage_key<>p.stage_key or f.id is null or not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action is null or p_action not in('approve','reject','request_revision')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='approve'then
  ceiling:=app_private.finance_cents(to_jsonb(p_ceiling_centavos));
  if ceiling>f.requested_total_centavos or p_conditions is null or length(btrim(p_conditions))not between 1 and 2000 or p_expires_at is null or not isfinite(p_expires_at)or p_expires_at<=statement_timestamp()or p_expires_at>((select closes_on+1 from public.terms where id=w.term_id)::timestamp at time zone'Asia/Manila')then raise exception using errcode='22023',message='command_validation_failed';end if;
  if p.external_requirement='not_required'then if p_external_outcome is distinct from 'not_required'or p_external_manifest_id is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
  elsif p_external_outcome is null or p_external_outcome not in('pending','verified')or(p_external_outcome='verified'and(p_external_manifest_id is null or p_external_manifest_id is distinct from f.manifest_id))or(p_external_outcome='pending'and p_external_manifest_id is not null)then raise exception using errcode='22023',message='command_validation_failed';end if;
 elsif p_ceiling_centavos is not null or p_conditions is not null or p_expires_at is not null or p_external_outcome is not null or p_external_manifest_id is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.approval_decisions(assignment_id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,action,reason,payload_hash,evidence_manifest_id)
 values(a.id,w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,p_action,p_reason,f.payload_hash,f.manifest_id)returning id into decision;
 if p_action='approve'then
  insert into public.financial_authorizations(organization_id,term_id,request_id,finance_revision_id,request_revision_id,policy_id,assignment_id,decision_id,payload_hash,requested_total_centavos,ceiling_centavos,purpose,conditions,expires_at,external_outcome,external_manifest_id)
  values(w.organization_id,w.term_id,w.id,f.id,r.current_revision_id,p.id,a.id,decision,f.payload_hash,f.requested_total_centavos,ceiling,f.purpose,p_conditions,p_expires_at,p_external_outcome,p_external_manifest_id)returning id into authorization_id;
 end if;
 update public.workflow_instances set state=case p_action when 'approve'then 'approved'when 'reject'then 'rejected'else 'needs_revision'end,pause_reason=''where id=x.id returning *into x;
 update public.requests set request_state=x.state,revision_resume_stage_key=case when p_action='request_revision'then p.stage_key else revision_resume_stage_key end where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,x.state)where id=w.id returning *into w;perform app_private.workflow_event(w,x,'decided',p_reason);
 return app_private.finish_work_command(w,'decide_finance_request',p_request_id,payload,app_private.workflow_receipt(w,x)||jsonb_build_object('decisionId',decision,'authorizationId',authorization_id),'["finance_decision"]');
end$$;
create function public.change_financial_authorization(p_authorization_id uuid,p_kind text,p_reason text,p_manifest_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.financial_authorizations;r public.requests;w public.work_items;m public.term_memberships;payload jsonb;result jsonb;begin
 select *into a from public.financial_authorizations where id=p_authorization_id;select *into w from public.work_items where id=a.request_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_finance_scope(r,m.id);
 if app_private.finance_independent(r,m.id)is null or w.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_authorization_id,p_kind,p_reason,p_manifest_id,p_expected_version);result:=app_private.begin_work_command('change_financial_authorization',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_kind is null or p_kind not in('revoked','external_verified')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 or(p_kind='revoked'and p_manifest_id is not null)or(p_kind='external_verified'and(a.external_outcome<>'pending'or app_private.financial_authorization_state(a)<>'pending_external'or p_manifest_id is null or p_manifest_id is distinct from(select manifest_id from public.finance_revisions where id=a.finance_revision_id)))then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.financial_authorization_events(authorization_id,kind,reason,actor_id,manifest_id)values(a.id,p_kind,p_reason,auth.uid(),p_manifest_id);
 update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'change_financial_authorization',p_request_id,payload,jsonb_build_object('authorizationId',a.id,'state',app_private.financial_authorization_state(a),'version',w.version),'["financial_authorization_event"]');
end$$;
create function public.update_finance_metadata(p_work_item_id uuid,p_contact_label text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_contact_label,p_expected_version);result:=app_private.begin_work_command('update_finance_metadata',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if not exists(select 1 from public.finance_cases where request_id=w.id)or p_contact_label is null or length(btrim(p_contact_label))not between 1 and 200 then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.finance_case_metadata(request_id,contact_label)values(w.id,p_contact_label)on conflict(request_id)do update set contact_label=excluded.contact_label,updated_at=statement_timestamp();
 update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'update_finance_metadata',p_request_id,payload,app_private.request_receipt(w),'["excluded_finance_contact_metadata"]');
end$$;
create function app_private.finance_entry(r public.requests,x public.workflow_instances)returns text language plpgsql security definer set search_path='' as $$
declare s jsonb;rev public.request_revisions;v jsonb;k text;begin
 if (app_private.finance_policy(r)).id is null or not exists(select 1 from public.finance_revisions where request_revision_id=r.current_revision_id)then return 'typed_authority_module_pending';end if;
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

create function app_private.finance_authorization_json(a public.financial_authorizations)returns jsonb language sql stable security definer set search_path='' as $$
 select case when a.id is not null then jsonb_build_object('id',a.id,'ceilingCentavos',a.ceiling_centavos::text,'requestedCentavos',a.requested_total_centavos::text,'purpose',a.purpose,'conditions',a.conditions,'expiresAt',a.expires_at,'state',app_private.financial_authorization_state(a),'externalOutcome',case when exists(select 1 from public.financial_authorization_events where authorization_id=a.id and kind='external_verified')then 'verified'else a.external_outcome end,'externalRequirement',(select external_requirement from public.finance_authorization_policies where id=a.policy_id))end
$$;
alter function app_private.workflow_assignment_current(public.approval_assignments)rename to workflow_assignment_current_p25;
create function app_private.workflow_assignment_current(a public.approval_assignments)returns boolean language plpgsql stable security definer set search_path='' as $$
declare r public.requests;begin select *into r from public.requests where work_item_id=a.request_id;
 if exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='fin')then return(app_private.finance_assignment(r,a.reviewer_id)).id=a.id;end if;
 return app_private.workflow_assignment_current_p25(a);
end$$;
create function public.read_finance_review(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.finance_authorization_policies;a public.approval_assignments;x public.workflow_instances;can_read boolean;begin
 m:=app_private.request_actor(p_term_id);select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id;select *into r from public.requests where work_item_id=w.id;
 if w.id is null or w.archived_at is not null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='fin')or(m.member_id<>w.owner_member_id and app_private.finance_role(p_term_id,m.id,r.receiving_unit_id)is null)then return null;end if;
 p:=app_private.finance_policy(r);a:=app_private.finance_assignment(r,m.id);select *into x from public.workflow_instances where revision_id=r.current_revision_id;can_read:=m.member_id=w.owner_member_id or a.id is not null;
 return jsonb_build_object('id',w.id,'termId',p_term_id,'version',w.version,'revision',r.current_revision,'trackingId',r.tracking_id,'state',r.request_state,'policyReady',p.id is not null,'externalRequirement',p.external_requirement,
 'finance',case when can_read then public.read_finance_revision(p_term_id,w.id,null)end,'downloadContext',case when can_read then case when m.member_id=w.owner_member_id then w.id else x.review_context_id end end,
 'isOwner',m.member_id=w.owner_member_id,'contactLabel',case when can_read then(select contact_label from public.finance_case_metadata where request_id=w.id)end,'canChangeAuthorization',app_private.finance_independent(r,m.id)is not null,'canDecide',a.id is not null and r.request_state='in_review'and x.state='active'and app_private.finance_entry(r,x)is null,
 'canAssign',r.request_state in('paused','in_review')and(x.state<>'active'or not exists(select 1 from public.approval_assignments aa where aa.instance_id=x.id and aa.generation=x.generation and (app_private.finance_assignment(r,aa.reviewer_id)).id=aa.id)),
 'reviewers',coalesce((select jsonb_agg(jsonb_build_object('id',tm.id,'name',person.display_name)order by person.display_name,tm.id)from public.term_memberships tm join public.members person on person.id=tm.member_id where tm.term_id=p_term_id and app_private.finance_independent(r,tm.id)is not null),'[]'));
end$$;
create function public.list_finance_reviews(p_term_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;rows jsonb;begin
 m:=app_private.request_actor(p_term_id);select coalesce(jsonb_agg(jsonb_build_object('id',q.work_item_id,'trackingId',q.tracking_id,'state',q.request_state)order by q.tracking_id),'[]')into rows from(
 select r.*from public.requests r join public.request_types t on t.id=r.request_type_id join public.work_items w on w.id=r.work_item_id where r.term_id=p_term_id and t.governed_kind='fin'and w.archived_at is null and r.current_revision>0 and app_private.finance_role(p_term_id,m.id,r.receiving_unit_id)is not null order by r.tracking_id limit 100)q;
 return jsonb_build_object('items',rows);
end$$;
alter function public.authorize_asset_download(uuid,uuid,uuid)rename to authorize_asset_download_p25;
alter function public.authorize_asset_download_p25(uuid,uuid,uuid)set schema app_private;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare x public.workflow_instances;r public.requests;m public.term_memberships;a public.assets;payload jsonb;prior jsonb;begin
 select *into x from public.workflow_instances where review_context_id=p_work_item_id;select *into r from public.requests where work_item_id=x.request_id;
 if x.id is null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='fin')then return app_private.authorize_asset_download_p25(p_work_item_id,p_asset_id,p_request_id);end if;
 m:=app_private.request_actor(r.term_id);
 if exists(select 1 from public.work_items where id=r.work_item_id and archived_at is not null)or r.current_revision_id<>x.revision_id or(app_private.finance_assignment(r,m.id)).id is null or app_private.finance_entry(r,x)is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select asset.*into a from public.assets asset join public.asset_manifest_items i on i.asset_id=asset.id join public.finance_revisions f on f.manifest_id=i.manifest_id where f.request_revision_id=x.revision_id and asset.id=p_asset_id and asset.state='finalized';
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_id);prior:=app_private.begin_work_command('download_finance_review',p_request_id,payload);
 if prior is null then
  insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(r.organization_id,r.term_id,auth.uid(),'Current FIN reviewer','download_finance_review',r.work_item_id,r.current_revision,p_request_id,'{"fields":["finance_review_bytes"]}');
  insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'download_finance_review',p_request_id,r.organization_id,r.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),'{}');
 end if;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind',a.kind,'mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256);
end$$;
create or replace function public.read_finance_revision(p_term_id uuid,p_work_item_id uuid,p_revision integer default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;w public.work_items;f public.finance_revisions;result jsonb;r public.requests;assignment public.approval_assignments;begin
 m:=app_private.request_actor(p_term_id);select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id;
 select *into r from public.requests where work_item_id=w.id;assignment:=app_private.finance_assignment(r,m.id);
 if w.id is null or w.archived_at is not null or((w.owner_member_id<>m.member_id or not public.can_access_work(w.id,'detail'))and assignment.id is null)or(w.owner_member_id<>m.member_id and p_revision is not null and p_revision<>r.current_revision)then return null;end if;
 select fr.*into f from public.finance_revisions fr join public.requests current_request on current_request.work_item_id=fr.request_id
 where fr.request_id=w.id and fr.revision_no=coalesce(p_revision,current_request.current_revision);if not found then return null;end if;
 result:=jsonb_build_object('id',f.id,'requestId',w.id,'requestRevisionId',f.request_revision_id,'revision',f.revision_no,'kind',f.case_kind,'currency',f.currency,'purpose',f.purpose,'fundSource',f.fund_source,'beneficiaryMemberId',f.beneficiary_member_id,'relatedDeliverableId',f.related_deliverable_id,'plannedOn',f.planned_on,'termsRisks',f.terms_risks,'requestedTotalCentavos',f.requested_total_centavos::text,
 'pricing',case when f.unit_price_centavos is not null then jsonb_build_object('unitPriceCentavos',f.unit_price_centavos::text,'forecastQuantityMilli',f.forecast_quantity_milli,'forecastRevenueCentavos',f.forecast_revenue_centavos::text,'forecastMarginCentavos',(f.forecast_revenue_centavos::numeric-f.requested_total_centavos)::text)end,
 'lines',(select jsonb_agg(jsonb_build_object('description',l.description,'quantityMilli',l.quantity_milli,'unitAmountCentavos',l.unit_amount_centavos::text,'totalCentavos',l.total_centavos::text)order by l.line_no)from public.finance_lines l where l.finance_revision_id=f.id),
 'manifestId',f.manifest_id,'manifestHash',f.manifest_hash,'payloadHash',f.payload_hash,'hashVersion',f.hash_version,
 'files',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.filename,'sha256',a.sha256,'size',a.size_bytes)order by a.id)from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=f.manifest_id),'[]'));
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)
 values(w.organization_id,w.term_id,auth.uid(),'Current finance participant','read_finance_revision',w.id,f.revision_no,gen_random_uuid(),'{"fields":["restricted_finance_access"]}');return result||jsonb_build_object('authorization',(select app_private.finance_authorization_json(a)from public.financial_authorizations a where a.finance_revision_id=f.id));
end$$;


create or replace function public.begin_request_revision(p_work_item_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;rev public.request_revisions;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version);result:=app_private.begin_work_command('begin_request_revision',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state not in('paused','needs_revision')and not(r.request_state='approved'and exists(select 1 from public.finance_cases where request_id=w.id))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if exists(select 1 from public.request_types where id=r.request_type_id and archived_at is not null)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select * into rev from public.request_revisions where id=r.current_revision_id;
 insert into public.request_drafts(request_id,organization_id,term_id,payload_json,requested_centavos,requested_on,choice_snapshots)
 values(w.id,w.organization_id,w.term_id,coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),(select requested_centavos from public.request_finance_values where revision_id=rev.id),rev.requested_on,rev.choice_snapshots);
 update public.requests set request_state='revision_draft'where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,'revision_draft')where id=w.id returning * into w;
 perform app_private.request_event(w,'revision_started');return app_private.finish_work_command(w,'begin_request_revision',p_request_id,payload,app_private.request_receipt(w),'["request_revision_draft"]');
end$$;


create function app_private.finance_policy_lock()returns trigger language plpgsql set search_path='' as $$begin perform pg_advisory_xact_lock(hashtextextended('finance_policy:'||new.request_type_id::text,0));return new;end$$;
create trigger finance_policy_lock before insert on public.finance_authorization_policies for each row execute function app_private.finance_policy_lock();
create function app_private.lock_finance_scope(r public.requests,member uuid)returns void language plpgsql set search_path='' as $$begin
 if current_setting('transaction_isolation')<>'read committed'then raise exception using errcode='25001',message='command_dependency_blocked';end if;
 perform pg_advisory_xact_lock(hashtextextended('finance_policy:'||r.request_type_id::text,0));
 perform 1 from public.organizations where id=r.organization_id for share;perform 1 from public.terms where id=r.term_id for share;perform 1 from public.org_units where id=r.receiving_unit_id for share;
 perform 1 from public.role_assignments where term_membership_id=member order by id for share;
 perform 1 from public.roles where id in(select role_id from public.role_assignments where term_membership_id=member)order by id for share;
 perform 1 from public.role_permissions where role_id in(select role_id from public.role_assignments where term_membership_id=member)order by role_id,capability for share;
 perform 1 from public.term_memberships where id=member for share;perform 1 from public.members where id in(select member_id from public.term_memberships where id=member)for share;
 perform 1 from public.unit_memberships where term_membership_id=member order by id for share;
end$$;
revoke all on function app_private.finance_policy_lock(),app_private.lock_finance_scope(public.requests,uuid)from public,anon,authenticated,service_role;
create function app_private.financial_authorization_guard()returns trigger language plpgsql set search_path='' as $$begin
 if not exists(select 1 from public.finance_revisions f join public.approval_decisions d on d.id=new.decision_id and d.action='approve'and d.payload_hash=f.payload_hash where f.id=new.finance_revision_id and f.requested_total_centavos=new.requested_total_centavos and f.purpose=new.purpose)then raise exception using errcode='22023',message='command_validation_failed';end if;return new;
end$$;
create trigger financial_authorization_guard before insert on public.financial_authorizations for each row execute function app_private.financial_authorization_guard();
revoke all on function app_private.financial_authorization_guard()from public,anon,authenticated,service_role;
-- Tight grants: institutional provisioning remains a separately approved administrative operation.
revoke all on function app_private.finance_entry(public.requests,public.workflow_instances),app_private.finance_authorization_json(public.financial_authorizations),app_private.workflow_assignment_current(public.approval_assignments),app_private.workflow_assignment_current_p25(public.approval_assignments),app_private.authorize_asset_download_p25(uuid,uuid,uuid)from public,anon,authenticated,service_role;
revoke all on function public.read_finance_review(uuid,uuid),public.list_finance_reviews(uuid),public.authorize_asset_download(uuid,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_finance_review(uuid,uuid),public.list_finance_reviews(uuid),public.authorize_asset_download(uuid,uuid,uuid)to authenticated;
revoke all on function app_private.finance_policy(public.requests),app_private.finance_role(uuid,uuid,uuid,uuid),app_private.finance_independent(public.requests,uuid,uuid),app_private.finance_assignment(public.requests,uuid),app_private.financial_authorization_state(public.financial_authorizations)from public,anon,authenticated,service_role;
revoke all on function public.activate_finance_review(uuid,uuid,integer,integer,text,uuid),public.decide_finance_request(uuid,integer,integer,text,text,text,text,timestamptz,text,uuid,uuid),public.change_financial_authorization(uuid,text,text,uuid,integer,uuid),public.update_finance_metadata(uuid,text,integer,uuid)from public,anon,authenticated,service_role;
grant execute on function public.activate_finance_review(uuid,uuid,integer,integer,text,uuid),public.decide_finance_request(uuid,integer,integer,text,text,text,text,timestamptz,text,uuid,uuid),public.change_financial_authorization(uuid,text,text,uuid,integer,uuid),public.update_finance_metadata(uuid,text,integer,uuid)to authenticated;

create or replace function public.read_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null,p_history_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare base jsonb;kind text;begin base:=app_private.read_request_p24(p_term_id,p_work_item_id,p_revision,p_history_page);if base is null then return null;end if;select t.governed_kind into kind from public.requests r join public.request_types t on t.id=r.request_type_id where r.work_item_id=p_work_item_id;return base||jsonb_build_object('governedKind',kind)||case when kind='fin'and base->>'state'='approved'then jsonb_build_object('canRevise',true,'nextAction','Start a governed revision before changing the authorized plan.')else '{}'::jsonb end;end$$;

create or replace function public.read_finance_gate(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;target uuid;pending boolean:=false;ready boolean:=false;begin
 select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id and kind in('task','deliverable');
 if not found or not public.can_access_work(w.id,'detail')then return null;end if;
 target:=case when w.kind='deliverable'then w.id else w.parent_work_item_id end;
 -- A task link never confers parent or financial-case access, even for this safe projection.
 if w.archived_at is null and target is not null and public.current_term_membership(p_term_id)is not null and public.can_access_work(target,'detail')then
  select exists(select 1 from public.finance_revisions f join public.requests r on r.current_revision_id=f.request_revision_id join public.work_items rw on rw.id=r.work_item_id
  where f.term_id=p_term_id and f.related_deliverable_id=target and r.request_state<>'cancelled'and rw.archived_at is null)into pending;
 end if;
 if pending then select not exists(select 1 from public.finance_revisions fr join public.requests rr on rr.current_revision_id=fr.request_revision_id join public.work_items rw on rw.id=rr.work_item_id left join public.financial_authorizations fa on fa.finance_revision_id=fr.id where fr.term_id=p_term_id and fr.related_deliverable_id=target and rr.request_state<>'cancelled'and rw.archived_at is null and(fa.id is null or app_private.financial_authorization_state(fa)<>'valid'))into ready;end if;
 return jsonb_build_object('state',case when ready then 'authorized'when pending then 'pending'else 'not_verified'end);
end$$;
