-- P29: real acceptance/external authority remains unseeded institutional configuration.
alter table public.deliverables add work_types text[] not null default array['operations'],add finance_required boolean not null default false,add publicity_required boolean not null default false;
create table public.deliverable_readiness_policies(
 id uuid primary key default gen_random_uuid(),work_item_id uuid not null references public.deliverables(work_item_id),version integer not null check(version>0),
 acceptor_authority_id uuid not null references public.role_assignments(id),acceptor_authority_version integer not null,
 external_required boolean not null,external_authority_id uuid references public.role_assignments(id),external_authority_version integer,
 official_reference text not null check(length(btrim(official_reference))between 1 and 1000),confirmed_by uuid not null references public.term_memberships(id),
 effective_from timestamptz not null,effective_to timestamptz not null,check(effective_to>effective_from),unique(work_item_id,version),unique(id,work_item_id),
 check(not external_required or(external_authority_id is not null and external_authority_version is not null))
);
create table public.deliverable_readiness_events(
 id uuid primary key default gen_random_uuid(),sequence bigint generated always as identity unique,work_item_id uuid not null references public.deliverables(work_item_id),
 kind text not null check(kind in('submitted','accepted','reopened')),policy_id uuid not null,criteria_revision integer not null,fingerprint text not null check(fingerprint~'^[0-9a-f]{64}$'),
 submission_id uuid,actor_id uuid not null references auth.users(id),authority_id uuid references public.role_assignments(id),authority_version integer,
 evidence text not null check(length(btrim(evidence))between 1 and 4000),reason text not null check(length(btrim(reason))between 1 and 2000),recorded_at timestamptz not null default statement_timestamp(),
 unique(id,work_item_id),foreign key(submission_id,work_item_id)references public.deliverable_readiness_events(id,work_item_id),foreign key(policy_id,work_item_id)references public.deliverable_readiness_policies(id,work_item_id)
);
create unique index readiness_accept_submission on public.deliverable_readiness_events(submission_id)where kind='accepted';
create index readiness_events_work on public.deliverable_readiness_events(work_item_id,sequence desc);
create table public.deliverable_scope_exceptions(
 id uuid primary key default gen_random_uuid(),work_item_id uuid not null references public.deliverables(work_item_id),task_id uuid not null references public.tasks(work_item_id),task_version integer not null,
 criteria_revision integer not null,policy_id uuid not null,authority_id uuid not null references public.role_assignments(id),authority_version integer not null,
 actor_id uuid not null references auth.users(id),reason text not null check(length(btrim(reason))between 1 and 2000),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(policy_id,work_item_id)references public.deliverable_readiness_policies(id,work_item_id),unique(work_item_id,task_id,task_version,criteria_revision,policy_id)
);
create table public.deliverable_external_authorizations(
 id uuid primary key default gen_random_uuid(),work_item_id uuid not null references public.deliverables(work_item_id),policy_id uuid not null,criteria_revision integer not null,
 authority_stamp text not null,material_hash text not null check(material_hash~'^[0-9a-f]{64}$'),manifest_id uuid not null,manifest_hash text not null,
 authority_id uuid not null references public.role_assignments(id),authority_version integer not null,actor_id uuid not null references auth.users(id),
 official_reference text not null check(length(btrim(official_reference))between 1 and 1000),reason text not null check(length(btrim(reason))between 1 and 2000),expires_at timestamptz not null check(isfinite(expires_at)),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(manifest_id,work_item_id)references public.asset_manifests(id,work_item_id),foreign key(policy_id,work_item_id)references public.deliverable_readiness_policies(id,work_item_id)
);
do $$declare t text;begin foreach t in array array['deliverable_readiness_policies','deliverable_readiness_events','deliverable_scope_exceptions','deliverable_external_authorizations']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('create trigger immutable_readiness before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);end loop;end$$;

create function app_private.readiness_lock(term uuid)returns void language plpgsql set search_path='' as $$begin
 if current_setting('transaction_isolation')<>'read committed'then raise exception using errcode='40001',message='command_stale_version';end if;
 perform pg_advisory_xact_lock(hashtextextended('deliverable_readiness:'||term::text,0));end$$;
create function app_private.readiness_authority(authority uuid,expected integer,term uuid,unit uuid)returns uuid language sql stable security definer set search_path='' as $$
 select a.term_membership_id from public.role_assignments a join public.roles role on role.id=a.role_id and role.state='active'
 join public.role_permissions rp on rp.role_id=role.id and rp.capability='committee.manage'and rp.allowed_scope='unit'
 join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id
 join public.terms t on t.id=a.term_id and t.state='active'join public.organizations o on o.id=t.organization_id and o.state='active'join public.org_units u on u.id=a.unit_id and u.archived_at is null
 where a.id=authority and a.version=expected and a.term_id=term and a.unit_id=unit and a.scope_type='unit'and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()
 and tm.status='active'and tm.membership_kind='core'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from public.unit_memberships d where d.term_membership_id=tm.id and d.unit_id=unit and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())
 and exists(select 1 from public.role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=tm.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())limit 1
$$;
create function app_private.readiness_policy(w public.work_items)returns public.deliverable_readiness_policies language sql stable security definer set search_path='' as $$
 select p from public.deliverable_readiness_policies p join public.term_memberships confirmer on confirmer.id=p.confirmed_by and confirmer.term_id=w.term_id and confirmer.organization_id=w.organization_id
 where p.work_item_id=w.id and p.version=(select max(version)from public.deliverable_readiness_policies where work_item_id=w.id)and p.effective_from<=statement_timestamp()and p.effective_to>statement_timestamp()
 and app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)is not null
 and exists(select 1 from public.term_memberships tm where tm.id=app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)and tm.member_id<>w.owner_member_id)limit 1
$$;
create function app_private.readiness_material(w public.work_items,d public.deliverables)returns text language sql immutable set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('title',w.title,'summary',w.safe_summary,'owner',w.owner_member_id,'lead',w.lead_unit_id,'classification',w.classification,'dueOn',w.due_on,'dueAt',w.due_at,'body',d.body,'outcome',d.outcome,'criteria',d.acceptance_criteria,'criteriaRevision',d.criteria_revision,'types',d.work_types,'financeRequired',d.finance_required,'publicityRequired',d.publicity_required)::text,'UTF8')),'hex')
$$;
create function app_private.readiness_exception(w public.work_items,d public.deliverables,t public.work_items,p public.deliverable_readiness_policies)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.deliverable_scope_exceptions e join public.tasks task on task.work_item_id=e.task_id where e.work_item_id=w.id and e.task_id=t.id and e.task_version=t.version and e.criteria_revision=d.criteria_revision and e.policy_id=p.id and task.task_type='ordinary'and not exists(select 1 from public.contributions where work_item_id=t.id)and app_private.readiness_authority(e.authority_id,e.authority_version,w.term_id,w.lead_unit_id)is not null)
$$;
create function app_private.readiness_finance_ok(work uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.finance_revisions f join public.requests r on r.current_revision_id=f.request_revision_id join public.work_items w on w.id=r.work_item_id where f.related_deliverable_id=work and r.request_state<>'cancelled'and w.archived_at is null)
 and not exists(select 1 from public.finance_revisions f join public.requests r on r.current_revision_id=f.request_revision_id join public.work_items w on w.id=r.work_item_id left join public.financial_authorizations a on a.finance_revision_id=f.id where f.related_deliverable_id=work and r.request_state<>'cancelled'and w.archived_at is null and(a.id is null or app_private.financial_authorization_state(a)<>'valid'or exists(select 1 from public.budget_entries where authorization_id=a.id and kind='release')or exists(select 1 from public.actual_finance_records ar where ar.request_id=f.request_id and not exists(select 1 from public.actual_finance_events e where e.record_id=ar.id))))
$$;
create function app_private.readiness_publicity_ok(work uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.publicity_reviews p join public.requests r on r.current_revision_id=p.request_revision_id join public.work_items w on w.id=r.work_item_id where p.related_deliverable_id=work and r.request_state<>'cancelled'and w.archived_at is null)
 and not exists(select 1 from public.publicity_reviews p join public.requests r on r.current_revision_id=p.request_revision_id join public.work_items w on w.id=r.work_item_id left join public.publicity_approvals a on a.publicity_review_id=p.id where p.related_deliverable_id=work and r.request_state<>'cancelled'and w.archived_at is null and(a.id is null or app_private.publicity_approval_state(a)<>'approved'or app_private.publicity_finance_state(p)='pending'))
$$;
create function app_private.readiness_authority_stamp(authority uuid)returns text language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('assignment',to_jsonb(a),'role',to_jsonb(r),'permissions',(select jsonb_agg(to_jsonb(p)order by p.id)from public.role_permissions p where p.role_id=r.id),'membership',to_jsonb(tm),'personVersion',to_jsonb(m)->'version','deployments',(select jsonb_agg(to_jsonb(d)order by d.id)from public.unit_memberships d where d.term_membership_id=tm.id),'workspace',(select jsonb_agg(jsonb_build_array(wa.id,wa.version,wr.id,wr.version,wp.id,wp.version)order by wa.id,wp.id)from public.role_assignments wa join public.roles wr on wr.id=wa.role_id join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'where wa.term_membership_id=tm.id))::text,'UTF8')),'hex')from public.role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id join public.members m on m.id=tm.member_id where a.id=authority
$$;
create function app_private.readiness_snapshot(w public.work_items)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d public.deliverables;p public.deliverable_readiness_policies;g jsonb;blocked jsonb:='[]';fingerprint text;material text;fin_required boolean;pub_required boolean;owner_ok boolean;criteria_ok boolean;tasks_ok boolean;contrib_ok boolean;handoff_ok boolean;deps_ok boolean;fin_ok boolean;pub_ok boolean;external_ok boolean;latest public.deliverable_readiness_events;submission public.deliverable_readiness_events;accepted boolean;review boolean;category text;begin
 select *into d from public.deliverables where work_item_id=w.id;p:=app_private.readiness_policy(w);material:=app_private.readiness_material(w,d);
 owner_ok:=exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=w.term_id and tm.member_id=w.owner_member_id and tm.membership_kind='core'and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and m.account_state='active');
 criteria_ok:=nullif(btrim(d.outcome),'')is not null and nullif(btrim(d.acceptance_criteria),'')is not null and(w.due_on is not null or w.due_at is not null)and w.lead_unit_id is not null;
 tasks_ok:=not exists(select 1 from public.work_items tw join public.tasks t on t.work_item_id=tw.id where tw.parent_work_item_id=w.id and(t.workflow_state<>'done'or tw.archived_at is not null)and not app_private.readiness_exception(w,d,tw,p));
 contrib_ok:=not exists(select 1 from public.synergy_agreements a left join public.contributions c on c.agreement_id=a.id left join public.tasks t on t.work_item_id=c.work_item_id left join public.work_items tw on tw.id=t.work_item_id where a.parent_work_item_id=w.id and a.state<>'declined'and(a.state<>'accepted'or a.active_revision is distinct from a.current_revision or c.work_item_id is null or c.active_revision is distinct from a.active_revision or t.workflow_state<>'done'or tw.archived_at is not null or not exists(select 1 from public.handoffs h join public.handoff_receipts receipt on receipt.handoff_id=h.id and receipt.revision=h.current_revision where h.source_task_id=c.work_item_id and h.state='accepted')));
 handoff_ok:=not exists(select 1 from public.handoffs h where exists(select 1 from public.work_items tw where tw.parent_work_item_id=w.id and tw.id in(h.source_task_id,h.next_task_id))and(h.state<>'accepted'or not exists(select 1 from public.handoff_receipts receipt where receipt.handoff_id=h.id and receipt.revision=h.current_revision)));
 deps_ok:=not exists(select 1 from public.work_items tw where tw.parent_work_item_id=w.id and app_private.dependency_blocked(tw.id));
 fin_required:=d.finance_required or d.work_types&&array['cost','budget','expense','reimbursement','fundraising','sales','cost_publicity']or exists(select 1 from public.finance_revisions where related_deliverable_id=w.id);
 pub_required:=d.publicity_required or d.work_types&&array['publicity','cost_publicity']or exists(select 1 from public.publicity_reviews where related_deliverable_id=w.id);
 fin_ok:=not fin_required or app_private.readiness_finance_ok(w.id);
 pub_ok:=not pub_required or app_private.readiness_publicity_ok(w.id);
 fin_ok:=coalesce(fin_ok,false);pub_ok:=coalesce(pub_ok,false);
 external_ok:=p.id is not null and(not p.external_required or exists(select 1 from public.deliverable_external_authorizations e where e.work_item_id=w.id and e.policy_id=p.id and e.criteria_revision=d.criteria_revision and e.material_hash=material and e.authority_stamp=app_private.readiness_authority_stamp(e.authority_id)and e.expires_at>statement_timestamp()and e.authority_id=p.external_authority_id and e.authority_version=p.external_authority_version and app_private.readiness_authority(e.authority_id,e.authority_version,w.term_id,w.lead_unit_id)is not null));
 g:=jsonb_build_object('owner',owner_ok,'criteria',criteria_ok,'tasks',tasks_ok,'contributions',contrib_ok,'handoffs',handoff_ok,'dependencies',deps_ok,'finance',fin_ok,'publicity',pub_ok,'external',external_ok,'policy',p.id is not null,'recordedBlocker',not d.is_blocked);
 select coalesce(jsonb_agg(key order by key),'[]')into blocked from jsonb_each(g)where value='false'::jsonb;
 fingerprint:=encode(sha256(convert_to(jsonb_build_object('material',material,'policy',p.id,'authorityStamp',app_private.readiness_authority_stamp(p.acceptor_authority_id),'gates',g,
 'tasks',(select jsonb_agg(jsonb_build_array(tw.id,tw.version,t.workflow_state,tw.archived_at)order by tw.id)from public.work_items tw join public.tasks t on t.work_item_id=tw.id where tw.parent_work_item_id=w.id),
 'agreements',(select jsonb_agg(to_jsonb(a)order by a.id)from public.synergy_agreements a where a.parent_work_item_id=w.id),
 'dependencies',(select jsonb_agg(jsonb_build_array(dep.id,dep.required,dep.removed_at,pre.version,t.workflow_state)order by dep.id)from public.task_dependencies dep join public.work_items child on child.id=dep.successor_task_id join public.work_items pre on pre.id=dep.predecessor_task_id join public.tasks t on t.work_item_id=pre.id where child.parent_work_item_id=w.id),
 'handoffs',(select jsonb_agg(jsonb_build_array(h.id,h.version,h.current_revision,h.state)order by h.id)from public.handoffs h where exists(select 1 from public.work_items tw where tw.parent_work_item_id=w.id and tw.id in(h.source_task_id,h.next_task_id))),
 'finance',(select jsonb_agg(jsonb_build_array(fr.id,fr.payload_hash,r.request_state,r.current_revision_id,fa.id,app_private.financial_authorization_state(fa))order by fr.id)from public.finance_revisions fr join public.requests r on r.work_item_id=fr.request_id left join public.financial_authorizations fa on fa.finance_revision_id=fr.id where fr.related_deliverable_id=w.id),
 'publicity',(select jsonb_agg(jsonb_build_array(pr.id,pr.payload_hash,r.request_state,r.current_revision_id,pa.id,app_private.publicity_approval_state(pa),app_private.publicity_finance_state(pr))order by pr.id)from public.publicity_reviews pr join public.requests r on r.work_item_id=pr.request_id left join public.publicity_approvals pa on pa.publicity_review_id=pr.id where pr.related_deliverable_id=w.id),
 'exceptions',(select jsonb_agg(e.id order by e.id)from public.deliverable_scope_exceptions e where e.work_item_id=w.id),
 'external',(select jsonb_agg(e.id order by e.id)from public.deliverable_external_authorizations e where e.work_item_id=w.id))::text,'UTF8')),'hex');
 select *into latest from public.deliverable_readiness_events where work_item_id=w.id order by sequence desc limit 1;select *into submission from public.deliverable_readiness_events where id=latest.submission_id;
 accepted:=w.archived_at is null and d.workflow_state='accepted'and latest.kind='accepted'and latest.fingerprint=fingerprint and submission.evidence is not distinct from d.final_evidence and latest.policy_id=p.id and app_private.readiness_authority(latest.authority_id,latest.authority_version,w.term_id,w.lead_unit_id)is not null and jsonb_array_length(blocked)=0;
 accepted:=coalesce(accepted,false);review:=(d.workflow_state='accepted'and not accepted)or(d.workflow_state='submitted'and(latest.kind is distinct from 'submitted'or latest.fingerprint is distinct from fingerprint or latest.criteria_revision is distinct from d.criteria_revision or latest.evidence is distinct from d.final_evidence));
 category:=case when w.archived_at is not null or d.workflow_state='cancelled'then 'cancelled'when accepted then 'accepted'when jsonb_array_length(blocked)>0 then 'blocked'when review then 'in_progress'when d.workflow_state='submitted'then 'ready_for_acceptance'when d.workflow_state in('proposed','draft')then 'not_started'else 'in_progress'end;
 return jsonb_build_object('fingerprint',fingerprint,'materialHash',material,'policyId',p.id,'criteriaRevision',d.criteria_revision,'category',category,'reviewRequired',review,'tasksComplete',not exists(select 1 from public.work_items child join public.tasks task on task.work_item_id=child.id where child.parent_work_item_id=w.id and(task.workflow_state<>'done'or child.archived_at is not null)),'ready',jsonb_array_length(blocked)=0,'gates',g,'blockers',blocked,'financeRequired',fin_required,'publicityRequired',pub_required,'latestKind',latest.kind,'latestId',latest.id,
 'nextAction',case when d.workflow_state='cancelled'then 'Deliverable cancelled; prior records retained.'when accepted then 'Accepted against the current scope and review evidence.'when review then 'Scope or authority changed; the owner must reopen and resubmit for independent acceptance.'when jsonb_array_length(blocked)>0 then 'Resolve the required checks, then submit current evidence.'when d.workflow_state='submitted'then 'Configured independent acceptance reviewer must verify criteria and evidence.'else 'Accountable owner: submit final evidence for acceptance.'end);
end$$;

create function app_private.readiness_serialize()returns trigger language plpgsql security definer set search_path='' as $$
declare row jsonb;term uuid;target uuid;begin
 row:=case when tg_op='DELETE'then to_jsonb(old)else to_jsonb(new)end;term:=(row->>'term_id')::uuid;
 if tg_table_name='terms'then term:=(row->>'id')::uuid;
 elsif tg_table_name in('members','organizations')then
 for term in select id from public.terms where(tg_table_name='organizations'and organization_id=(row->>'id')::uuid)or(tg_table_name='members'and id in(select term_id from public.term_memberships where member_id=(row->>'id')::uuid))order by id loop perform app_private.readiness_lock(term);end loop;
 elsif term is null then
 target:=coalesce((row->>'work_item_id')::uuid,(row->>'request_id')::uuid);select term_id into term from public.work_items where id=target;
 if term is null and row?'agreement_id'then select term_id into term from public.synergy_agreements where id=(row->>'agreement_id')::uuid;end if;
 if term is null and row?'handoff_id'then select term_id into term from public.handoffs where id=(row->>'handoff_id')::uuid;end if;
 if term is null and row?'authorization_id'then select term_id into term from public.financial_authorizations where id=(row->>'authorization_id')::uuid;end if;
 if term is null and row?'record_id'then select term_id into term from public.actual_finance_records where id=(row->>'record_id')::uuid;end if;
 if term is null and row?'publicity_review_id'then select term_id into term from public.publicity_reviews where id=(row->>'publicity_review_id')::uuid;end if;
 if term is null and row?'approval_id'then select w.term_id into term from public.publicity_approvals a join public.work_items w on w.id=a.request_id where a.id=(row->>'approval_id')::uuid;end if;
 if term is null and row?'authority_id'then select term_id into term from public.role_assignments where id=(row->>'authority_id')::uuid;end if;
 end if;
 if term is not null then perform app_private.readiness_lock(term);end if;
 if tg_op='DELETE'then return old;end if;return new;end$$;
create function app_private.readiness_latch()returns trigger language plpgsql set search_path='' as $$begin
 if new.work_types is null or cardinality(new.work_types)not between 1 and 9 or not(new.work_types<@array['operations','cost','budget','expense','reimbursement','fundraising','sales','publicity','cost_publicity'])then raise exception using errcode='22023',message='command_validation_failed';end if;
 new.finance_required:=coalesce(old.finance_required,false)or new.finance_required or new.work_types&&array['cost','budget','expense','reimbursement','fundraising','sales','cost_publicity'];
 new.publicity_required:=coalesce(old.publicity_required,false)or new.publicity_required or new.work_types&&array['publicity','cost_publicity'];
 if new.workflow_state='accepted'and old.workflow_state is distinct from 'accepted'and current_setting('app.readiness_accept',true)is distinct from new.work_item_id::text then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger readiness_protected_types before insert or update on public.deliverables for each row execute function app_private.readiness_latch();
create function app_private.readiness_case_latch()returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.related_deliverable_id is not null then
 update public.deliverables set finance_required=finance_required or tg_table_name='finance_revisions',publicity_required=publicity_required or tg_table_name='publicity_reviews'where work_item_id=new.related_deliverable_id;
 end if;return new;end$$;
create trigger readiness_finance_case after insert on public.finance_revisions for each row execute function app_private.readiness_case_latch();
create trigger readiness_publicity_case after insert on public.publicity_reviews for each row execute function app_private.readiness_case_latch();

create function public.read_deliverable_readiness(p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;d public.deliverables;s jsonb;p public.deliverable_readiness_policies;m uuid;can_edit boolean;can_accept boolean;begin
 select *into w from public.work_items where id=p_work_item_id and kind='deliverable';if w.id is null or not public.can_access_work(w.id,'summary')then return null;end if;
 select *into d from public.deliverables where work_item_id=w.id;s:=app_private.readiness_snapshot(w);p:=app_private.readiness_policy(w);m:=public.current_term_membership(w.term_id);can_edit:=m is not null and public.can_access_work(w.id,'edit')and w.archived_at is null;
 can_accept:=can_edit and m=app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)and exists(select 1 from public.term_memberships where id=m and member_id<>w.owner_member_id);
 can_accept:=coalesce(can_accept,false);
 return(s-array['materialHash','policyId','latestId','latestKind','fingerprint'])||jsonb_build_object('id',w.id,'version',w.version,'submittedEvidence',case when can_edit then d.final_evidence end,'fingerprint',case when can_edit then s->>'fingerprint'end,'canSubmit',can_edit and(s->>'ready')::boolean and exists(select 1 from public.term_memberships where id=m and member_id=w.owner_member_id)and d.workflow_state in('draft','in_progress'),
 'canAccept',can_accept and d.workflow_state='submitted'and not(s->>'reviewRequired')::boolean and(s->>'ready')::boolean,'canReopen',can_edit and(d.workflow_state='accepted'or d.workflow_state='submitted')and(exists(select 1 from public.term_memberships where id=m and member_id=w.owner_member_id)or can_accept),
 'canDeclare',can_edit and exists(select 1 from public.term_memberships where id=m and member_id=w.owner_member_id)or can_accept,'canExcept',can_accept,
 'canVerifyExternal',coalesce(can_edit and p.external_required and m=app_private.readiness_authority(p.external_authority_id,p.external_authority_version,w.term_id,w.lead_unit_id),false),'workTypes',d.work_types,
 'exceptionChoices',case when can_accept then coalesce((select jsonb_agg(jsonb_build_object('id',tw.id,'label',tw.title,'version',tw.version))from public.work_items tw join public.tasks t on t.work_item_id=tw.id where tw.parent_work_item_id=w.id and tw.lead_unit_id=w.lead_unit_id and t.task_type='ordinary'and public.can_access_work(tw.id,'edit')and app_private.task_manager(tw)and not exists(select 1 from public.contributions where work_item_id=tw.id)),'[]')else '[]'::jsonb end,
 'exceptions',case when can_edit then coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'taskId',e.task_id,'reason',e.reason))from public.deliverable_scope_exceptions e join public.work_items tw on tw.id=e.task_id where e.work_item_id=w.id and public.can_access_work(tw.id,'detail')),'[]')else '[]'::jsonb end,
 'history',case when can_edit then coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'criteriaRevision',e.criteria_revision,'at',e.recorded_at)order by e.sequence)from public.deliverable_readiness_events e where e.work_item_id=w.id),'[]')else '[]'::jsonb end);
end$$;

create function app_private.readiness_transition(p_work_item_id uuid,p_kind text,p_evidence text,p_reason text,p_expected_version integer,p_criteria_revision integer,p_fingerprint text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;d public.deliverables;p public.deliverable_readiness_policies;m public.term_memberships;s jsonb;payload jsonb;result jsonb;prior public.deliverable_readiness_events;event uuid;target text;command text;role uuid;role_version integer;begin
 select *into w from public.work_items where id=p_work_item_id and kind='deliverable'for update;m:=app_private.request_actor(w.term_id,true);
 if w.id is null or w.archived_at is not null or not public.can_access_work(w.id,'edit')then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.readiness_lock(w.term_id);m:=app_private.request_actor(w.term_id,true);select *into d from public.deliverables where work_item_id=w.id;p:=app_private.readiness_policy(w);
 if p_kind='accepted'then
 if m.id is distinct from app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)or m.member_id=w.owner_member_id then raise exception using errcode='42501',message='command_permission_denied';end if;role:=p.acceptor_authority_id;role_version:=p.acceptor_authority_version;
 elsif p_kind='submitted'then if m.member_id<>w.owner_member_id then raise exception using errcode='42501',message='command_permission_denied';end if;
 elsif p_kind='reopened'then if m.member_id<>w.owner_member_id and m.id is distinct from app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 else raise exception using errcode='22023',message='command_validation_failed';end if;
 command:=case p_kind when 'accepted'then 'accept_deliverable'when 'submitted'then 'submit_deliverable'else 'reopen_deliverable'end;payload:=jsonb_build_array(p_work_item_id,p_evidence,p_reason,p_expected_version,p_criteria_revision,p_fingerprint);
 result:=app_private.begin_work_command(command,p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or d.criteria_revision is distinct from p_criteria_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 s:=app_private.readiness_snapshot(w);if p_fingerprint is distinct from s->>'fingerprint'then raise exception using errcode='40001',message='command_stale_version';end if;
 if p.id is null or p_reason is null or length(btrim(p_reason))not between 1 and 2000 or p_evidence is null or length(btrim(p_evidence))not between 1 and 4000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select *into prior from public.deliverable_readiness_events where work_item_id=w.id order by sequence desc limit 1;
 if p_kind='submitted'then
 if d.workflow_state not in('draft','in_progress')or not(s->>'ready')::boolean then raise exception using errcode='55000',message='command_dependency_blocked';end if;target:='submitted';
 elsif p_kind='accepted'then
 if d.workflow_state<>'submitted'or prior.kind is distinct from 'submitted'or prior.fingerprint is distinct from s->>'fingerprint'or prior.criteria_revision<>d.criteria_revision or prior.evidence is distinct from d.final_evidence or not(s->>'ready')::boolean then raise exception using errcode='55000',message='command_dependency_blocked';end if;target:='accepted';
 else if d.workflow_state not in('accepted','submitted')then raise exception using errcode='55000',message='command_dependency_blocked';end if;target:='in_progress';end if;
 insert into public.deliverable_readiness_events(work_item_id,kind,policy_id,criteria_revision,fingerprint,submission_id,actor_id,authority_id,authority_version,evidence,reason)values(w.id,p_kind,p.id,d.criteria_revision,s->>'fingerprint',case when p_kind='accepted'then prior.id end,auth.uid(),role,role_version,btrim(p_evidence),p_reason)returning id into event;
 perform set_config('app.readiness_accept',w.id::text,true);update public.work_items set status_id=app_private.deliverable_status(w.organization_id,w.term_id,target)where id=w.id returning *into w;
 update public.deliverables set workflow_state=target,final_evidence=case when p_kind='submitted'then btrim(p_evidence)when p_kind='reopened'then null else final_evidence end where work_item_id=w.id;
 perform app_private.snapshot_deliverable(w,p_reason,case when p_kind='accepted'then p_evidence end);
 return app_private.finish_work_command(w,command,p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version,'eventId',event,'state',target),'["deliverable_readiness","acceptance_evidence"]');end$$;
create function public.submit_deliverable(p_work_item_id uuid,p_evidence text,p_reason text,p_expected_version integer,p_criteria_revision integer,p_fingerprint text,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.readiness_transition(p_work_item_id,'submitted',p_evidence,p_reason,p_expected_version,p_criteria_revision,p_fingerprint,p_request_id)$$;
create function public.accept_deliverable(p_work_item_id uuid,p_evidence text,p_reason text,p_expected_version integer,p_criteria_revision integer,p_fingerprint text,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.readiness_transition(p_work_item_id,'accepted',p_evidence,p_reason,p_expected_version,p_criteria_revision,p_fingerprint,p_request_id)$$;
create function public.reopen_deliverable(p_work_item_id uuid,p_evidence text,p_reason text,p_expected_version integer,p_criteria_revision integer,p_fingerprint text,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.readiness_transition(p_work_item_id,'reopened',p_evidence,p_reason,p_expected_version,p_criteria_revision,p_fingerprint,p_request_id)$$;

create function public.declare_deliverable_work_types(p_work_item_id uuid,p_types text[],p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;m public.term_memberships;payload jsonb;result jsonb;begin
 select *into w from public.work_items where id=p_work_item_id and kind='deliverable'for update;m:=app_private.request_actor(w.term_id,true);perform app_private.readiness_lock(w.term_id);
 if w.archived_at is not null or not public.can_access_work(w.id,'edit')or(m.member_id<>w.owner_member_id and not app_private.manage_deliverable(w.term_id,w.lead_unit_id))then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_types,p_reason,p_expected_version);result:=app_private.begin_work_command('declare_deliverable_work_types',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_types is null or cardinality(p_types)not between 1 and 9 or array_ndims(p_types)<>1 or not(p_types<@array['operations','cost','budget','expense','reimbursement','fundraising','sales','publicity','cost_publicity'])or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.deliverables set work_types=(select array_agg(distinct t order by t)from unnest(work_types||p_types)t)where work_item_id=w.id;
 update public.work_items set title=title where id=w.id returning *into w;perform app_private.snapshot_deliverable(w,p_reason);
 return app_private.finish_work_command(w,'declare_deliverable_work_types',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version),'["protected_work_types"]');end$$;
create function public.record_deliverable_scope_exception(p_work_item_id uuid,p_task_id uuid,p_task_version integer,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;task public.work_items;d public.deliverables;p public.deliverable_readiness_policies;m public.term_memberships;payload jsonb;result jsonb;exception_id uuid;begin
 select *into w from public.work_items where id=p_work_item_id and kind='deliverable'for update;m:=app_private.request_actor(w.term_id,true);perform app_private.readiness_lock(w.term_id);select *into task from public.work_items where id=p_task_id;select *into d from public.deliverables where work_item_id=w.id;p:=app_private.readiness_policy(w);
 if w.archived_at is not null or not public.can_access_work(w.id,'edit')or task.parent_work_item_id is distinct from w.id or task.lead_unit_id is distinct from w.lead_unit_id or not public.can_access_work(task.id,'edit')or not app_private.task_manager(task)or m.id is distinct from app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_task_id,p_task_version,p_reason,p_expected_version);result:=app_private.begin_work_command('record_deliverable_scope_exception',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or task.version is distinct from p_task_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if not exists(select 1 from public.tasks where work_item_id=task.id and task_type='ordinary')or exists(select 1 from public.contributions where work_item_id=task.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.deliverable_scope_exceptions(work_item_id,task_id,task_version,criteria_revision,policy_id,authority_id,authority_version,actor_id,reason)values(w.id,task.id,task.version,d.criteria_revision,p.id,p.acceptor_authority_id,p.acceptor_authority_version,auth.uid(),p_reason)returning id into exception_id;
 update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'record_deliverable_scope_exception',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version,'exceptionId',exception_id),'["ordinary_task_scope_exception"]');end$$;
create function public.verify_deliverable_external(p_work_item_id uuid,p_manifest_id uuid,p_official_reference text,p_expires_at timestamptz,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;d public.deliverables;p public.deliverable_readiness_policies;m public.term_memberships;manifest public.asset_manifests;payload jsonb;result jsonb;authorization_id uuid;begin
 select *into w from public.work_items where id=p_work_item_id and kind='deliverable'for update;m:=app_private.request_actor(w.term_id,true);perform app_private.readiness_lock(w.term_id);select *into d from public.deliverables where work_item_id=w.id;p:=app_private.readiness_policy(w);
 if w.archived_at is not null or not public.can_access_work(w.id,'edit')or not p.external_required or m.member_id=w.owner_member_id or m.id is distinct from app_private.readiness_authority(p.external_authority_id,p.external_authority_version,w.term_id,w.lead_unit_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_manifest_id,p_official_reference,p_expires_at,p_reason,p_expected_version);result:=app_private.begin_work_command('verify_deliverable_external',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into manifest from public.asset_manifests where id=p_manifest_id and work_item_id=w.id;
 if manifest.id is null or not exists(select 1 from public.asset_manifest_items where manifest_id=manifest.id)or exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=manifest.id and(a.state<>'finalized'or a.kind<>'upload'))or p_reason is null or length(btrim(p_reason))not between 1 and 2000 or p_official_reference is null or length(btrim(p_official_reference))not between 1 and 1000 or p_expires_at is null or not isfinite(p_expires_at)or p_expires_at<=statement_timestamp()or(p_expires_at at time zone'Asia/Manila')::date>(select closes_on from public.terms where id=w.term_id)then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.deliverable_external_authorizations(work_item_id,policy_id,criteria_revision,material_hash,authority_stamp,manifest_id,manifest_hash,authority_id,authority_version,actor_id,official_reference,reason,expires_at)values(w.id,p.id,d.criteria_revision,app_private.readiness_material(w,d),app_private.readiness_authority_stamp(p.external_authority_id),manifest.id,manifest.sha256,p.external_authority_id,p.external_authority_version,auth.uid(),p_official_reference,p_reason,p_expires_at)returning id into authorization_id;
 update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'verify_deliverable_external',p_request_id,payload,jsonb_build_object('workItemId',w.id,'version',w.version,'authorizationId',authorization_id),'["external_authorization_evidence"]');end$$;

alter function public.transition_deliverable(uuid,text,text,text,integer,uuid,integer)rename to transition_deliverable_p28;
alter function public.transition_deliverable_p28(uuid,text,text,text,integer,uuid,integer)set schema app_private;
create function public.transition_deliverable(p_work_item_id uuid,p_action text,p_reason text,p_evidence text,p_expected_version integer,p_request_id uuid,p_criteria_revision integer default null)returns jsonb language plpgsql security definer set search_path='' as $$begin
 if p_action in('submit','accept','revise')then raise exception using errcode='55000',message='command_dependency_blocked';end if;return app_private.transition_deliverable_p28(p_work_item_id,p_action,p_reason,p_evidence,p_expected_version,p_request_id,p_criteria_revision);end$$;
alter function public.read_deliverable_authoring(uuid,uuid)rename to read_deliverable_authoring_p28;
alter function public.read_deliverable_authoring_p28(uuid,uuid)set schema app_private;
create function public.read_deliverable_authoring(p_term_id uuid,p_work_item_id uuid default null)returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin result:=app_private.read_deliverable_authoring_p28(p_term_id,p_work_item_id);if result is null then return null;end if;return result||jsonb_build_object('actions',coalesce((select jsonb_agg(a)from jsonb_array_elements_text(result->'actions')a where a not in('submit','accept','revise')),'[]'::jsonb));end$$;
alter function app_private.deliverable_summary(public.work_items,public.deliverables)rename to deliverable_summary_p28;
create function app_private.deliverable_summary(w public.work_items,d public.deliverables)returns jsonb language plpgsql stable security definer set search_path='' as $$declare base jsonb;s jsonb;begin base:=app_private.deliverable_summary_p28(w,d);s:=app_private.readiness_snapshot(w);return base||jsonb_build_object('readiness',s->>'category','reviewRequired',s->'reviewRequired','tasksComplete',s->'tasksComplete','nextAction',s->>'nextAction','blocked',s->>'category'='blocked','blocker',case when s->>'category'='blocked'then 'Required scope or review checks are pending.'end,'gates',jsonb_build_object('finance',case when not(s->>'financeRequired')::boolean then 'not_required'when(s->'gates'->>'finance')::boolean then 'verified'else 'pending'end,'publicity',case when not(s->>'publicityRequired')::boolean then 'not_required'when(s->'gates'->>'publicity')::boolean then 'verified'else 'pending'end,'acceptance',s->>'category'));end$$;

create or replace function public.list_deliverables(p_term_id uuid,p_phase text default null,p_unit_id uuid default null,p_owner_id uuid default null,
  p_blocked boolean default false,p_overdue boolean default false,p_involves_my_unit boolean default false,p_review_pending boolean default false,
  p_page integer default 1,p_page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; begin
  if p_page is null or p_page not between 1 and 10000 or p_page_size is null or p_page_size not between 1 and 50
    or (p_phase is not null and length(p_phase)>80) then raise exception using errcode='22023',message='deliverables_invalid_filter'; end if;
  with base as materialized (
    select w.id,w.owner_member_id,w.owner_display_name,w.lead_unit_id,w.due_at,w.due_on,d.phase_key,d.is_blocked,
      app_private.deliverable_summary(w,d) as summary
    from public.work_items w join public.deliverables d on d.work_item_id=w.id
    where w.term_id=p_term_id and w.archived_at is null and public.can_access_work(w.id,'summary')
  ), filtered as (
    select b.* from base b where (p_phase is null or b.phase_key=p_phase)
      and (p_owner_id is null or b.owner_member_id=p_owner_id)
      and (not coalesce(p_blocked,false) or(b.summary->>'blocked')::boolean)
      and (not coalesce(p_overdue,false) or (b.summary->>'overdue')::boolean)
      and (not coalesce(p_review_pending,false) or b.summary->>'readiness'='ready_for_acceptance'or(b.summary->>'reviewRequired')::boolean or b.summary->'gates'->>'finance'='pending'or b.summary->'gates'->>'publicity'='pending')
      and (p_unit_id is null or b.lead_unit_id=p_unit_id or exists(select 1 from public.deliverable_units du where du.work_item_id=b.id and du.unit_id=p_unit_id))
      and (not coalesce(p_involves_my_unit,false) or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null
        where um.term_membership_id=public.current_term_membership(p_term_id) and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()
          and (um.unit_id=b.lead_unit_id or exists(select 1 from public.deliverable_units du where du.work_item_id=b.id and du.unit_id=um.unit_id))))
  ), page as (select * from filtered order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id limit p_page_size offset (p_page-1)*p_page_size)
  select jsonb_build_object('items',coalesce((select jsonb_agg(summary order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id) from page),'[]'::jsonb),
    'total',(select count(*) from filtered),'page',p_page,'pageSize',p_page_size,
    'options',jsonb_build_object(
      'phases',coalesce((select jsonb_agg(phase_key order by phase_key) from(select distinct phase_key from base where phase_key is not null)x),'[]'::jsonb),
      'owners',coalesce((select jsonb_agg(jsonb_build_object('id',owner_member_id,'name',name) order by name,owner_member_id)
        from(select owner_member_id,min(owner_display_name) as name from base group by owner_member_id)x),'[]'::jsonb),
      'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name) order by u.name,u.id) from public.org_units u where u.term_id=p_term_id and exists(
        select 1 from base b where b.lead_unit_id=u.id or exists(select 1 from public.deliverable_units du where du.work_item_id=b.id and du.unit_id=u.id))),'[]'::jsonb)))
  into result;
  return result;
end $$;

alter function public.read_overview(uuid)rename to read_overview_p28;
alter function public.read_overview_p28(uuid)set schema app_private;
create function public.read_overview(p_term_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare base jsonb;items jsonb;begin base:=app_private.read_overview_p28(p_term_id);if base is null then return null;end if;
 with rows as(select item from jsonb_array_elements(base->'items')item where item->>'source'<>'deliverable'
 union all select jsonb_build_object('id',w.id,'source','deliverable','title',w.title,'owner',w.owner_display_name,'dueOn',w.due_on,'dueAt',w.due_at,'lane',case when w.owner_member_id=(select member_id from public.term_memberships where id=public.current_term_membership(p_term_id))or d.workflow_state='submitted'and(public.read_deliverable_readiness(w.id)->>'canAccept')::boolean then 'actionable'else 'waiting'end,'action',s->>'nextAction','person',case when d.workflow_state='submitted'then 'Configured independent acceptance reviewer'else w.owner_display_name end,'state',s->>'category','committee',u.name,'overdue',coalesce(w.due_at<statement_timestamp(),w.due_on<(statement_timestamp()at time zone'Asia/Manila')::date,false))from public.work_items w join public.deliverables d on d.work_item_id=w.id left join public.org_units u on u.id=w.lead_unit_id cross join lateral(select app_private.readiness_snapshot(w)s)r where w.term_id=p_term_id and w.archived_at is null and public.can_access_work(w.id,'detail')and(w.owner_member_id=(select member_id from public.term_memberships where id=public.current_term_membership(p_term_id))or app_private.manage_deliverable(w.term_id,w.lead_unit_id))and s->>'category'not in('accepted','cancelled'))
 select jsonb_build_object('items',coalesce((select jsonb_agg(item)from(select item from rows order by item->>'lane',item->>'dueAt'nulls last,item->>'dueOn'nulls last,item->>'source',item->>'id'limit 50)page),'[]'),'hasMore',(base->>'hasMore')::boolean or(select count(*)>50 from rows),'refreshedAt',statement_timestamp())into items;return items;end$$;
create trigger serialize_deliverable_readiness before insert or update or delete on public.work_items for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.deliverables for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.tasks for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.task_dependencies for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.synergy_agreements for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.agreement_revisions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.agreement_confirmations for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.contributions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.handoffs for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.handoff_revisions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.handoff_receipts for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.handoff_decisions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.requests for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.finance_revisions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.financial_authorizations for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.financial_authorization_events for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.actual_finance_records for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.actual_finance_events for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.budget_entries for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.publicity_reviews for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.publicity_approvals for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.publicity_approval_events for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.finance_authorization_policies for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.finance_authority_designations for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.publicity_review_policies for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.publicity_authority_designations for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.approval_assignments for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.approval_decisions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.workflow_instances for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.role_assignments for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.role_permissions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.roles for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.unit_memberships for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.term_memberships for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.terms for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.members for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.org_units for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.organizations for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.deliverable_readiness_policies for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.deliverable_scope_exceptions for each row execute function app_private.readiness_serialize();
create trigger serialize_deliverable_readiness before insert or update or delete on public.deliverable_external_authorizations for each row execute function app_private.readiness_serialize();

-- All private helpers and delegated aliases stay off the Data API.
do $$declare signature text;begin for signature in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'and(p.proname like 'readiness_%'or p.proname in('deliverable_summary','deliverable_summary_p28','transition_deliverable_p28','read_deliverable_authoring_p28','read_overview_p28'))loop execute 'revoke all on function '||signature||' from public,anon,authenticated,service_role';end loop;end$$;
revoke all on function public.read_deliverable_readiness(uuid),public.submit_deliverable(uuid,text,text,integer,integer,text,uuid),public.accept_deliverable(uuid,text,text,integer,integer,text,uuid),public.reopen_deliverable(uuid,text,text,integer,integer,text,uuid),public.declare_deliverable_work_types(uuid,text[],text,integer,uuid),public.record_deliverable_scope_exception(uuid,uuid,integer,text,integer,uuid),public.verify_deliverable_external(uuid,uuid,text,timestamptz,text,integer,uuid),public.transition_deliverable(uuid,text,text,text,integer,uuid,integer),public.read_deliverable_authoring(uuid,uuid),public.read_overview(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_deliverable_readiness(uuid),public.submit_deliverable(uuid,text,text,integer,integer,text,uuid),public.accept_deliverable(uuid,text,text,integer,integer,text,uuid),public.reopen_deliverable(uuid,text,text,integer,integer,text,uuid),public.declare_deliverable_work_types(uuid,text[],text,integer,uuid),public.record_deliverable_scope_exception(uuid,uuid,integer,text,integer,uuid),public.verify_deliverable_external(uuid,uuid,text,timestamptz,text,integer,uuid),public.transition_deliverable(uuid,text,text,text,integer,uuid,integer),public.read_deliverable_authoring(uuid,uuid),public.read_overview(uuid)to authenticated;
