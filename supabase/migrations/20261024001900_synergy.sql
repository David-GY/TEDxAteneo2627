begin;
create table public.synergy_agreements(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,parent_work_item_id uuid not null references public.deliverables(work_item_id),
 requester_unit_id uuid not null,receiver_unit_id uuid not null,requester_member_id uuid not null,
 version integer not null default 1,current_revision integer not null default 1,active_revision integer,
 state text not null default 'proposed' check(state in('proposed','countered','accepted','declined')),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),updated_at timestamptz not null default statement_timestamp(),
 check(requester_unit_id<>receiver_unit_id),check(version>0 and current_revision>0),unique(organization_id,term_id,id),
 foreign key(organization_id,term_id,parent_work_item_id)references public.work_items(organization_id,term_id,id),
 foreign key(organization_id,term_id,requester_unit_id)references public.org_units(organization_id,term_id,id),
 foreign key(organization_id,term_id,receiver_unit_id)references public.org_units(organization_id,term_id,id),
 foreign key(organization_id,term_id,requester_member_id)references public.term_memberships(organization_id,term_id,member_id)
);
create table public.agreement_revisions(
 agreement_id uuid not null references public.synergy_agreements(id),revision integer not null,parent_version integer not null,
 output text not null check(length(btrim(output))between 1 and 240),criteria text not null check(length(btrim(criteria))between 1 and 8000),
 effort_band text not null check(effort_band in('small','medium','large')),due_on date not null check(isfinite(due_on)),
 owner_candidate_id uuid references public.members(id),proposer_side text not null check(proposer_side in('requester','receiver')),
 proposer_member_id uuid not null references public.members(id),actor_id uuid not null references auth.users(id),reason text not null check(length(btrim(reason))between 1 and 2000),recorded_at timestamptz not null default statement_timestamp(),
 primary key(agreement_id,revision)
);
alter table public.synergy_agreements add constraint synergy_current_revision foreign key(id,current_revision)references public.agreement_revisions(agreement_id,revision)deferrable initially deferred,
 add constraint synergy_active_revision foreign key(id,active_revision)references public.agreement_revisions(agreement_id,revision)deferrable initially deferred;
create table public.agreement_confirmations(
 id uuid primary key default gen_random_uuid(),agreement_id uuid not null,revision integer not null,agreement_version integer not null,
 side text not null check(side in('requester','receiver')),decision text not null check(decision in('propose','counter','accept','decline')),
 member_id uuid not null references public.members(id),actor_id uuid not null references auth.users(id),selected_owner_id uuid references public.members(id),
 reason text not null check(length(btrim(reason))between 1 and 2000),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(agreement_id,revision)references public.agreement_revisions(agreement_id,revision),unique(agreement_id,revision,side,decision)
);
create table public.agreement_revision_sources(agreement_id uuid not null,revision integer not null,manifest_id uuid not null references public.asset_manifests(id),primary key(agreement_id,revision,manifest_id),foreign key(agreement_id,revision)references public.agreement_revisions(agreement_id,revision));
create table public.contributions(
 work_item_id uuid primary key references public.tasks(work_item_id),organization_id uuid not null,term_id uuid not null,
 agreement_id uuid not null unique references public.synergy_agreements(id),active_revision integer not null,parent_work_item_id uuid not null references public.deliverables(work_item_id),
 requester_unit_id uuid not null,receiver_unit_id uuid not null,owner_member_id uuid not null,owner_name text not null,
 created_at timestamptz not null default statement_timestamp(),updated_at timestamptz not null default statement_timestamp(),
 foreign key(agreement_id,active_revision)references public.agreement_revisions(agreement_id,revision),
 foreign key(organization_id,term_id,work_item_id)references public.work_items(organization_id,term_id,id),
 foreign key(organization_id,term_id,parent_work_item_id)references public.work_items(organization_id,term_id,id),
 foreign key(organization_id,term_id,requester_unit_id)references public.org_units(organization_id,term_id,id),
 foreign key(organization_id,term_id,receiver_unit_id)references public.org_units(organization_id,term_id,id),
 foreign key(organization_id,term_id,owner_member_id)references public.term_memberships(organization_id,term_id,member_id)
);
create index synergy_parent on public.synergy_agreements(parent_work_item_id,id);
create index synergy_requester on public.synergy_agreements(term_id,requester_unit_id,state,id);
create index synergy_receiver on public.synergy_agreements(term_id,receiver_unit_id,state,id);
create index synergy_sources_manifest on public.agreement_revision_sources(manifest_id);
create index contributions_parent on public.contributions(parent_work_item_id,work_item_id);
do $$declare t text;begin foreach t in array array['synergy_agreements','agreement_revisions','agreement_confirmations','agreement_revision_sources','contributions']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 end loop;foreach t in array array['agreement_revisions','agreement_confirmations','agreement_revision_sources']loop execute format('create trigger synergy_history_immutable before update or delete on public.%I for each row execute function app_private.deny_deliverable_history()',t);end loop;end$$;
-- No raw negotiation SELECT grant: receiving heads get only the explicit safe RPC projection.
grant select(work_item_id,requester_unit_id,receiver_unit_id,owner_member_id,owner_name,active_revision,created_at,updated_at)on public.contributions to authenticated;
create policy contribution_read on public.contributions for select to authenticated using(public.can_access_work(work_item_id,'detail'));

create function app_private.synergy_head(p_term uuid,p_unit uuid,p_member uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id and m.account_state='active'
 join public.org_units u on u.id=p_unit and u.term_id=p_term and u.archived_at is null and u.delivery_committee
 join public.unit_memberships um on um.term_membership_id=tm.id and um.unit_id=u.id and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()
 join public.role_assignments a on a.term_membership_id=tm.id and a.scope_type='unit' and a.unit_id=u.id and a.status='active' and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp()
 join public.roles r on r.id=a.role_id and r.state='active' join public.role_permissions p on p.role_id=r.id and p.capability='committee.manage' and p.allowed_scope='unit'
 where tm.term_id=p_term and tm.member_id=p_member and tm.membership_kind='core' and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp())
$$;
create function app_private.synergy_actor(p_term uuid)returns uuid language sql stable set search_path='' as $$select member_id from public.term_memberships where id=public.current_term_membership(p_term)$$;
create function app_private.synergy_visible(a public.synergy_agreements)returns boolean language sql stable set search_path='' as $$
 select app_private.synergy_head(a.term_id,a.requester_unit_id,app_private.synergy_actor(a.term_id))or app_private.synergy_head(a.term_id,a.receiver_unit_id,app_private.synergy_actor(a.term_id))
$$;
create function app_private.synergy_owner(p_term uuid,p_unit uuid,p_owner uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id and m.account_state='active' join public.unit_memberships um on um.term_membership_id=tm.id
 join public.org_units u on u.id=um.unit_id and u.archived_at is null and u.delivery_committee where tm.term_id=p_term and tm.member_id=p_owner and tm.membership_kind='core' and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp() and um.unit_id=p_unit and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())
$$;
create function app_private.check_synergy_terms(p_terms jsonb,p_counter boolean)returns void language plpgsql set search_path='' as $$begin
 if p_terms is null or jsonb_typeof(p_terms)<>'object' or octet_length(p_terms::text)>20000 or exists(select 1 from jsonb_object_keys(p_terms)k where k not in('output','criteria','effort','dueOn','reason','sourceManifestIds'))
 or exists(select 1 from jsonb_each(p_terms)e where e.key<>'sourceManifestIds' and jsonb_typeof(e.value)<>'string')
 or coalesce(length(btrim(p_terms->>'output')),0)not between 1 and 240 or coalesce(length(btrim(p_terms->>'criteria')),0)not between 1 and 8000
 or p_terms->>'effort' is null or p_terms->>'effort'not in('small','medium','large')or coalesce(length(btrim(p_terms->>'reason')),0)not between 1 and 2000
 or coalesce(p_terms->>'dueOn','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or not isfinite((p_terms->>'dueOn')::date)
 or(p_terms?'sourceManifestIds' and(jsonb_typeof(p_terms->'sourceManifestIds')<>'array' or jsonb_array_length(p_terms->'sourceManifestIds')>20))then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_counter and p_terms?'sourceManifestIds' then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
create function app_private.synergy_revision(a public.synergy_agreements,w public.work_items,p_terms jsonb,p_side text,p_actor uuid,p_owner uuid,p_inherit integer default null)returns void language plpgsql set search_path='' as $$declare mid uuid;begin
 insert into public.agreement_revisions(agreement_id,revision,parent_version,output,criteria,effort_band,due_on,owner_candidate_id,proposer_side,proposer_member_id,actor_id,reason)
 values(a.id,a.current_revision,w.version,btrim(p_terms->>'output'),btrim(p_terms->>'criteria'),p_terms->>'effort',(p_terms->>'dueOn')::date,p_owner,p_side,p_actor,auth.uid(),p_terms->>'reason');
 if p_inherit is not null then insert into public.agreement_revision_sources select a.id,a.current_revision,manifest_id from public.agreement_revision_sources where agreement_id=a.id and revision=p_inherit;
 else for mid in select value::uuid from jsonb_array_elements_text(coalesce(p_terms->'sourceManifestIds','[]'))loop
 if not exists(select 1 from public.asset_manifests m where m.id=mid and m.work_item_id=w.id and public.can_read_manifest(m.id))then raise exception using errcode='42501',message='command_permission_denied';end if;
 insert into public.agreement_revision_sources values(a.id,a.current_revision,mid)on conflict do nothing;end loop;end if;
end$$;
create function app_private.synergy_duplicate(p_parent uuid,p_receiver uuid,p_except uuid,p_output text)returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from public.synergy_agreements s join public.agreement_revisions r on r.agreement_id=s.id and r.revision=s.current_revision
 where s.parent_work_item_id=p_parent and s.receiver_unit_id=p_receiver and s.id is distinct from p_except and ((s.state<>'declined'and lower(r.output)=lower(btrim(p_output)))
 or exists(select 1 from public.contributions c join public.agreement_revisions old on old.agreement_id=c.agreement_id and old.revision=c.active_revision where c.agreement_id=s.id and lower(old.output)=lower(btrim(p_output)))))
$$;
create function public.propose_synergy(p_parent_id uuid,p_receiver_unit_id uuid,p_terms jsonb,p_expected_parent_version integer,p_request_id uuid,p_agreement_id uuid default null,p_expected_agreement_version integer default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.synergy_agreements;actor uuid;payload jsonb;result jsonb;begin
 select * into w from public.work_items where id=p_parent_id and kind='deliverable';actor:=app_private.synergy_actor(w.term_id);
 if w.id is null or not public.can_access_work(w.id,'edit')or not app_private.synergy_head(w.term_id,w.lead_unit_id,actor)or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_parent_id,p_receiver_unit_id,p_terms,p_expected_parent_version,p_agreement_id,p_expected_agreement_version);result:=app_private.begin_work_command('propose_synergy',p_request_id,payload);
 if result is not null then if not exists(select 1 from public.synergy_agreements s where s.id=(result->>'agreementId')::uuid and app_private.synergy_visible(s))then raise exception using errcode='42501',message='command_permission_denied';end if;return result;end if;
 select * into w from public.work_items where id=p_parent_id for update;
 if not public.can_access_work(w.id,'edit')or not app_private.synergy_head(w.term_id,w.lead_unit_id,actor)or w.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 if w.version is distinct from p_expected_parent_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if exists(select 1 from public.deliverables where work_item_id=w.id and workflow_state not in('draft','in_progress'))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_receiver_unit_id is null or p_receiver_unit_id=w.lead_unit_id or not exists(select 1 from public.org_units u where u.id=p_receiver_unit_id and u.organization_id=w.organization_id and u.term_id=w.term_id and u.archived_at is null and u.delivery_committee)then raise exception using errcode='22023',message='command_validation_failed';end if;
 perform app_private.check_synergy_terms(p_terms,false);
 if (p_agreement_id is null)<>(p_expected_agreement_version is null)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if app_private.synergy_duplicate(w.id,p_receiver_unit_id,p_agreement_id,p_terms->>'output')then raise exception using errcode='23505',message='command_conflict';end if;
 -- Negotiation is a material scope change: invalidate version-bound parent gate evidence.
 update public.work_items set updated_at=statement_timestamp()where id=w.id returning * into w;
 perform app_private.snapshot_deliverable(w,'Committee contribution negotiation changed',null);
 if p_agreement_id is null then
 insert into public.synergy_agreements(organization_id,term_id,parent_work_item_id,requester_unit_id,receiver_unit_id,requester_member_id,created_by)values(w.organization_id,w.term_id,w.id,w.lead_unit_id,p_receiver_unit_id,actor,auth.uid())returning * into a;
 else select * into a from public.synergy_agreements where id=p_agreement_id for update;
 if not found or a.parent_work_item_id<>w.id or a.receiver_unit_id<>p_receiver_unit_id or a.requester_unit_id<>w.lead_unit_id then raise exception using errcode='42501',message='command_permission_denied';end if;
 if a.version is distinct from p_expected_agreement_version then raise exception using errcode='40001',message='command_stale_version';end if;
 update public.synergy_agreements set version=version+1,current_revision=current_revision+1,state='proposed',updated_at=statement_timestamp()where id=a.id returning * into a;end if;
 perform app_private.synergy_revision(a,w,p_terms,'requester',actor,null);
 insert into public.agreement_confirmations(agreement_id,revision,agreement_version,side,decision,member_id,actor_id,reason)values(a.id,a.current_revision,a.version,'requester','propose',actor,auth.uid(),p_terms->>'reason');
 result:=app_private.finish_work_command(w,'propose_synergy',p_request_id,payload,jsonb_build_object('agreementId',a.id,'version',a.version,'revision',a.current_revision,'state',a.state),'["synergy_proposal"]');
 update public.outbox_jobs j set payload=j.payload||jsonb_build_object('agreementId',a.id,'revision',a.current_revision)where j.event_id=(select id from public.audit_events where actor_id=auth.uid()and action='propose_synergy'and request_id=p_request_id);
 return result;
end$$;

create function app_private.activate_synergy(a public.synergy_agreements,r public.agreement_revisions,p_owner uuid)returns uuid language plpgsql set search_path='' as $$
declare c public.contributions;w public.work_items;sid uuid;name text;expires timestamptz;begin
 select display_name into name from public.members where id=p_owner;
 select * into c from public.contributions where agreement_id=a.id for update;
 insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(a.organization_id,a.term_id,'task','p10_todo','draft','To do')on conflict(term_id,resource_kind,stable_key)do nothing;
 select id into sid from public.status_definitions where term_id=a.term_id and resource_kind='task' and stable_key='p10_todo' and semantic_category='draft';
 if c.work_item_id is null then
 insert into public.work_items(organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,parent_work_item_id,status_id,due_on,original_due_on)
 values(a.organization_id,a.term_id,'task',r.output,'Agreed committee contribution','restricted',p_owner,name,a.requester_unit_id,a.parent_work_item_id,sid,r.due_on,r.due_on)returning * into w;
 insert into public.tasks(work_item_id,organization_id,term_id,body,assignee_id,assignee_name,assigned_unit_id,task_type)values(w.id,a.organization_id,a.term_id,'Agreed criteria are retained in the contribution contract.',p_owner,name,a.receiver_unit_id,'ordinary');
 insert into public.contributions(work_item_id,organization_id,term_id,agreement_id,active_revision,parent_work_item_id,requester_unit_id,receiver_unit_id,owner_member_id,owner_name)values(w.id,a.organization_id,a.term_id,a.id,r.revision,a.parent_work_item_id,a.requester_unit_id,a.receiver_unit_id,p_owner,name);
 select ends_at into expires from public.term_memberships where id=public.current_term_membership(a.term_id);
 insert into public.record_grants(organization_id,term_id,work_item_id,unit_id,grant_kind,expires_at,grantor_id)values(a.organization_id,a.term_id,w.id,a.requester_unit_id,'read',expires,public.current_term_membership(a.term_id)),(a.organization_id,a.term_id,w.id,a.receiver_unit_id,'read',expires,public.current_term_membership(a.term_id));
 else
 update public.contributions set active_revision=r.revision,owner_member_id=p_owner,owner_name=name,updated_at=statement_timestamp()where work_item_id=c.work_item_id;
 update public.work_items set title=r.output,owner_member_id=p_owner,owner_display_name=name,due_on=r.due_on,due_at=null,status_id=sid where id=c.work_item_id returning * into w;
 update public.tasks set assignee_id=p_owner,assignee_name=name,assigned_unit_id=a.receiver_unit_id,workflow_state='todo',blocked_reason=null,completion_evidence=null,checklist=(select coalesce(jsonb_agg(e||'{"done":false}'::jsonb),'[]')from jsonb_array_elements(checklist)e)where work_item_id=w.id;
 end if;
 insert into public.task_revisions(work_item_id,work_version,state,assignee_id,assignee_name,assigned_unit_id,collaborators,title,due_on,due_at,body,checklist,evidence,reason,actor_id)
 select w.id,w.version,t.workflow_state,t.assignee_id,t.assignee_name,t.assigned_unit_id,coalesce((select jsonb_agg(member_id::text order by member_id)from public.task_collaborators where work_item_id=w.id),'[]'),w.title,w.due_on,w.due_at,t.body,t.checklist,t.completion_evidence,'Agreed committee contribution revision '||r.revision,auth.uid()from public.tasks t where t.work_item_id=w.id;
 return w.id;
end$$;
create function public.respond_to_synergy(p_agreement_id uuid,p_action text,p_expected_version integer,p_expected_revision integer,p_owner_id uuid,p_terms jsonb,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.synergy_agreements;r public.agreement_revisions;w public.work_items;actor uuid;side text;payload jsonb;result jsonb;owner uuid;task uuid;prior integer;begin
 select * into a from public.synergy_agreements where id=p_agreement_id;
 if not found or not app_private.synergy_visible(a)then raise exception using errcode='42501',message='command_permission_denied';end if;
 actor:=app_private.synergy_actor(a.term_id);select * into w from public.work_items where id=a.parent_work_item_id;
 if not exists(select 1 from public.terms where id=a.term_id and state='active')or w.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select * into r from public.agreement_revisions where agreement_id=a.id and revision=p_expected_revision;
 if not found then raise exception using errcode='40001',message='command_stale_version';end if;
 side:=case when r.proposer_side='receiver' then 'requester' else 'receiver'end;
 if not app_private.synergy_head(a.term_id,case side when 'requester'then a.requester_unit_id else a.receiver_unit_id end,actor)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(a.id,p_action,p_expected_version,p_expected_revision,p_owner_id,p_terms,p_reason);result:=app_private.begin_work_command('respond_to_synergy',p_request_id,payload);
 if result is not null then return result;end if;
 -- Lock parent first, matching proposal ordering; the agreement lock serializes competing accepts.
 select * into w from public.work_items where id=a.parent_work_item_id for update;
 select * into a from public.synergy_agreements where id=p_agreement_id for update;
 if a.version is distinct from p_expected_version or a.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if a.state not in('proposed','countered')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select * into r from public.agreement_revisions where agreement_id=a.id and revision=a.current_revision;
 if r.parent_version<>w.version or w.lead_unit_id is distinct from a.requester_unit_id then raise exception using errcode='40001',message='command_stale_version';end if;
 side:=case when a.state='countered' then 'requester' else 'receiver'end;
 if not app_private.synergy_head(a.term_id,case side when 'requester'then a.requester_unit_id else a.receiver_unit_id end,actor)or actor=r.proposer_member_id then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_action is null or p_action not in('accept','decline','counter')or coalesce(length(btrim(p_reason)),0)not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='counter' then
 if side<>'receiver'then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.check_synergy_terms(p_terms,true);
 if app_private.synergy_duplicate(w.id,a.receiver_unit_id,a.id,p_terms->>'output')then raise exception using errcode='23505',message='command_conflict';end if;
 if not app_private.synergy_owner(a.term_id,a.receiver_unit_id,p_owner_id)then raise exception using errcode='22023',message='command_validation_failed';end if;
 prior:=a.current_revision;update public.synergy_agreements set version=version+1,current_revision=current_revision+1,state='countered',updated_at=statement_timestamp()where id=a.id returning * into a;
 perform app_private.synergy_revision(a,w,p_terms,'receiver',actor,p_owner_id,prior);
 insert into public.agreement_confirmations(agreement_id,revision,agreement_version,side,decision,member_id,actor_id,selected_owner_id,reason)values(a.id,a.current_revision,a.version,'receiver','counter',actor,auth.uid(),p_owner_id,p_reason);
 else
 if p_terms is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='accept' then
 if not app_private.synergy_head(a.term_id,case side when 'receiver'then a.requester_unit_id else a.receiver_unit_id end,r.proposer_member_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 owner:=case when side='receiver'then p_owner_id else r.owner_candidate_id end;
 if side='requester' and p_owner_id is not null and p_owner_id<>owner then raise exception using errcode='22023',message='command_validation_failed';end if;
 if not app_private.synergy_owner(a.term_id,a.receiver_unit_id,owner)then raise exception using errcode='22023',message='command_validation_failed';end if;
 task:=app_private.activate_synergy(a,r,owner);
 update public.work_items set updated_at=statement_timestamp()where id=w.id returning * into w;
 perform app_private.snapshot_deliverable(w,'Committee contribution agreement activated',null);
 end if;
 update public.synergy_agreements set version=version+1,state=case when p_action='accept'then 'accepted'else'declined'end,active_revision=case when p_action='accept'then current_revision else active_revision end,updated_at=statement_timestamp()where id=a.id returning * into a;
 insert into public.agreement_confirmations(agreement_id,revision,agreement_version,side,decision,member_id,actor_id,selected_owner_id,reason)values(a.id,a.current_revision,a.version,side,p_action,actor,auth.uid(),owner,p_reason);
 end if;
 result:=app_private.finish_work_command(w,'respond_to_synergy',p_request_id,payload,jsonb_build_object('agreementId',a.id,'version',a.version,'revision',a.current_revision,'state',a.state,'contributionId',task),'["synergy_response"]');
 update public.outbox_jobs j set payload=j.payload||jsonb_build_object('agreementId',a.id,'revision',a.current_revision,'contributionId',task)where j.event_id=(select id from public.audit_events where actor_id=auth.uid()and action='respond_to_synergy'and request_id=p_request_id);
 return result;
end$$;

create function app_private.protect_contribution_terms()returns trigger language plpgsql security definer set search_path='' as $$declare c public.contributions;r public.agreement_revisions;id uuid;begin
 id:=coalesce((to_jsonb(new)->>'work_item_id')::uuid,(to_jsonb(new)->>'id')::uuid);select * into c from public.contributions where work_item_id=id;if not found then return new;end if;
 select * into r from public.agreement_revisions where agreement_id=c.agreement_id and revision=c.active_revision;
 if tg_table_name='work_items' then if new.title<>r.output or new.owner_member_id<>c.owner_member_id or new.due_on is distinct from r.due_on or new.due_at is not null or new.lead_unit_id is distinct from c.requester_unit_id then raise exception using errcode='42501',message='command_permission_denied';end if;
 else if new.assignee_id is distinct from c.owner_member_id or new.assigned_unit_id is distinct from c.receiver_unit_id or new.task_type<>'ordinary' then raise exception using errcode='42501',message='command_permission_denied';end if;end if;return new;
end$$;
create trigger contribution_work_terms before update on public.work_items for each row execute function app_private.protect_contribution_terms();
create trigger contribution_task_terms before update on public.tasks for each row execute function app_private.protect_contribution_terms();
create function app_private.check_contribution_link()returns trigger language plpgsql security definer set search_path='' as $$declare c public.contributions;a public.synergy_agreements;r public.agreement_revisions;wid uuid;begin
 if tg_table_name='synergy_agreements'then select * into a from public.synergy_agreements where id=(to_jsonb(new)->>'id')::uuid;select * into c from public.contributions where agreement_id=a.id;
 else wid:=coalesce((to_jsonb(new)->>'work_item_id')::uuid,(to_jsonb(new)->>'id')::uuid);select * into c from public.contributions where work_item_id=wid;if not found then return null;end if;select * into a from public.synergy_agreements where id=c.agreement_id;end if;
 if a.active_revision is null and c.work_item_id is null then return null;end if;
 select * into r from public.agreement_revisions where agreement_id=a.id and revision=a.active_revision;
 if c.work_item_id is null or c.active_revision is distinct from a.active_revision or c.parent_work_item_id<>a.parent_work_item_id or c.organization_id<>a.organization_id or c.term_id<>a.term_id or c.requester_unit_id<>a.requester_unit_id or c.receiver_unit_id<>a.receiver_unit_id
 or(a.state='accepted'and a.active_revision<>a.current_revision)
 or not exists(select 1 from public.work_items w join public.tasks t on t.work_item_id=w.id where w.id=c.work_item_id and w.organization_id=c.organization_id and w.term_id=c.term_id and w.parent_work_item_id=a.parent_work_item_id and w.title=r.output and w.owner_member_id=c.owner_member_id and t.assignee_id=c.owner_member_id and t.assigned_unit_id=c.receiver_unit_id and w.due_on=r.due_on and w.due_at is null)
 or not exists(select 1 from public.agreement_confirmations req join public.agreement_confirmations rec on rec.agreement_id=req.agreement_id and rec.revision=req.revision where req.agreement_id=a.id and req.revision=a.active_revision and req.side='requester'and req.decision in('propose','accept')and rec.side='receiver'and rec.decision in('accept','counter')and req.member_id<>rec.member_id and rec.selected_owner_id=c.owner_member_id)
 then raise exception using errcode='23514',message='contribution_canonical_link_required';end if;return null;
end$$;
do $$declare t text;begin foreach t in array array['synergy_agreements','contributions','tasks','work_items']loop execute format('create constraint trigger contribution_canonical_link after insert or update on public.%I deferrable initially deferred for each row execute function app_private.check_contribution_link()',t);end loop;end$$;
create function app_private.synergy_parent_gate()returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.workflow_state='accepted'and old.workflow_state<>'accepted'and(exists(select 1 from public.contributions where parent_work_item_id=new.work_item_id)or exists(select 1 from public.synergy_agreements where parent_work_item_id=new.work_item_id and state in('proposed','countered')))then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;
end$$;
create trigger synergy_acceptance_gate before update on public.deliverables for each row execute function app_private.synergy_parent_gate();
-- Existing task editors must identify locked negotiated metadata without exposing the parent agreement.
alter function public.read_task(uuid)rename to read_task_p10;
alter function public.read_task_p10(uuid)set schema app_private;
revoke all on function app_private.read_task_p10(uuid)from public,anon,authenticated,service_role;
create function public.read_task(p_work_item_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select item||jsonb_build_object('contributionId',(select work_item_id from public.contributions where work_item_id=p_work_item_id))from(select app_private.read_task_p10(p_work_item_id)as item)s where item is not null
$$;
revoke all on function public.read_task(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_task(uuid)to authenticated;
create function public.read_synergy(p_agreement_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',a.id,'version',a.version,'revision',a.current_revision,'activeRevision',a.active_revision,'state',a.state,'requesterUnitId',a.requester_unit_id,'receiverUnitId',a.receiver_unit_id,
 'requesterName',(select display_name from public.members where id=a.requester_member_id),'parentId',case when public.can_access_work(a.parent_work_item_id,'summary')then a.parent_work_item_id end,
 'terms',jsonb_build_object('output',r.output,'criteria',r.criteria,'effort',r.effort_band,'dueOn',r.due_on,'ownerId',coalesce(r.owner_candidate_id,(select selected_owner_id from public.agreement_confirmations where agreement_id=a.id and revision=a.current_revision and side='receiver'and decision='accept'))),
 'sources',coalesce((select jsonb_agg(s.manifest_id order by s.manifest_id)from public.agreement_revision_sources s where s.agreement_id=a.id and s.revision=a.current_revision and public.can_read_manifest(s.manifest_id)),'[]'),
 'contributionId',(select c.work_item_id from public.contributions c where c.agreement_id=a.id and public.can_access_work(c.work_item_id,'detail')),
 'revisions',coalesce((select jsonb_agg(jsonb_build_object('revision',h.revision,'output',h.output,'criteria',h.criteria,'effort',h.effort_band,'dueOn',h.due_on,'ownerId',h.owner_candidate_id,'side',h.proposer_side,'reason',h.reason,'recordedAt',h.recorded_at)order by h.revision)from public.agreement_revisions h where h.agreement_id=a.id),'[]'),
 'confirmations',coalesce((select jsonb_agg(jsonb_build_object('revision',h.revision,'side',h.side,'decision',h.decision,'memberId',h.member_id,'ownerId',h.selected_owner_id,'reason',h.reason,'recordedAt',h.recorded_at)order by h.agreement_version,h.id)from public.agreement_confirmations h where h.agreement_id=a.id),'[]'))
 from public.synergy_agreements a join public.agreement_revisions r on r.agreement_id=a.id and r.revision=a.current_revision where a.id=p_agreement_id and app_private.synergy_visible(a)
$$;
create function public.read_contribution(p_work_item_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c.work_item_id,'agreementId',c.agreement_id,'revision',c.active_revision,'ownerId',c.owner_member_id,'ownerName',c.owner_name,'requesterUnitId',c.requester_unit_id,'receiverUnitId',c.receiver_unit_id,
 'parentId',case when public.can_access_work(c.parent_work_item_id,'summary')then c.parent_work_item_id end,'output',r.output,'criteria',r.criteria,'effort',r.effort_band,'dueOn',r.due_on,'task',public.read_task(c.work_item_id))
 from public.contributions c join public.agreement_revisions r on r.agreement_id=c.agreement_id and r.revision=c.active_revision where c.work_item_id=p_work_item_id and public.can_access_work(c.work_item_id,'detail')
$$;
revoke all on function app_private.synergy_head(uuid,uuid,uuid),app_private.synergy_actor(uuid),app_private.synergy_visible(public.synergy_agreements),app_private.synergy_owner(uuid,uuid,uuid),app_private.check_synergy_terms(jsonb,boolean),app_private.synergy_revision(public.synergy_agreements,public.work_items,jsonb,text,uuid,uuid,integer),app_private.activate_synergy(public.synergy_agreements,public.agreement_revisions,uuid),app_private.protect_contribution_terms()from public,anon,authenticated,service_role;
revoke all on function app_private.check_contribution_link(),app_private.synergy_parent_gate()from public,anon,authenticated,service_role;
revoke all on function app_private.synergy_duplicate(uuid,uuid,uuid,text)from public,anon,authenticated,service_role;
revoke all on function public.propose_synergy(uuid,uuid,jsonb,integer,uuid,uuid,integer),public.respond_to_synergy(uuid,text,integer,integer,uuid,jsonb,text,uuid),public.read_synergy(uuid),public.read_contribution(uuid)from public,anon,authenticated,service_role;
grant execute on function public.propose_synergy(uuid,uuid,jsonb,integer,uuid,uuid,integer),public.respond_to_synergy(uuid,text,integer,integer,uuid,jsonb,text,uuid),public.read_synergy(uuid),public.read_contribution(uuid)to authenticated;
commit;
