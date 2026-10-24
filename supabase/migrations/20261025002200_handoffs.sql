begin;
create table public.handoffs(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,
 source_task_id uuid not null references public.tasks(work_item_id),next_task_id uuid references public.tasks(work_item_id),
 sender_member_id uuid not null references public.members(id),receiver_member_id uuid not null references public.members(id),receiver_unit_id uuid not null,
 version integer not null default 1,current_revision integer not null default 1,
 state text not null default 'proposed'check(state in('proposed','changes_requested','declined','cancelled','accepted')),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),updated_at timestamptz not null default statement_timestamp(),
 check(version>0 and current_revision>0),check(sender_member_id<>receiver_member_id),check(source_task_id is distinct from next_task_id),
 foreign key(organization_id,term_id,source_task_id)references public.work_items(organization_id,term_id,id),
 foreign key(organization_id,term_id,next_task_id)references public.work_items(organization_id,term_id,id),
 foreign key(organization_id,term_id,receiver_unit_id)references public.org_units(organization_id,term_id,id)
);
-- The bounded first handoff model has one agreed incoming package per canonical next task.
create unique index handoff_next_task on public.handoffs(next_task_id)where next_task_id is not null;
create index handoff_source on public.handoffs(source_task_id,id);
create index handoff_receiver on public.handoffs(term_id,receiver_member_id,state,id);
create table public.handoff_revisions(
 id uuid not null unique default gen_random_uuid(),handoff_id uuid not null references public.handoffs(id),revision integer not null,
 source_version integer not null,next_version integer,receiver_member_id uuid not null references public.members(id),receiver_unit_id uuid not null references public.org_units(id),
 manifest_id uuid not null references public.asset_manifests(id),manifest_sha256 text not null check(manifest_sha256~'^[0-9a-f]{64}$'),files jsonb not null,
 output text not null check(length(btrim(output))between 1 and 240),criteria text not null check(length(btrim(criteria))between 1 and 8000),due_on date not null check(isfinite(due_on)),
 next_terms jsonb,reason text not null check(length(btrim(reason))between 1 and 2000),created_by uuid not null references auth.users(id),recorded_at timestamptz not null default statement_timestamp(),
 primary key(handoff_id,revision)
);
alter table public.handoffs add constraint handoff_current_revision foreign key(id,current_revision)references public.handoff_revisions(handoff_id,revision)deferrable initially deferred;
create table public.handoff_decisions(
 id uuid primary key default gen_random_uuid(),handoff_id uuid not null,revision integer not null,handoff_version integer not null,
 action text not null check(action in('proposed','accept','decline','changes_requested','cancel')),member_id uuid not null references public.members(id),
 reason text not null check(length(btrim(reason))between 1 and 2000),actor_id uuid not null references auth.users(id),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(handoff_id,revision)references public.handoff_revisions(handoff_id,revision),unique(handoff_id,handoff_version)
);
create table public.handoff_receipts(
 id uuid primary key default gen_random_uuid(),handoff_id uuid not null unique,revision integer not null,receiver_member_id uuid not null references public.members(id),
 manifest_id uuid not null references public.asset_manifests(id),manifest_sha256 text not null,criteria text not null,next_task_id uuid references public.tasks(work_item_id),next_version integer,
 notes text not null check(length(btrim(notes))between 1 and 2000),actor_id uuid not null references auth.users(id),accepted_at timestamptz not null default statement_timestamp(),
 foreign key(handoff_id,revision)references public.handoff_revisions(handoff_id,revision)
);
do $$declare t text;begin foreach t in array array['handoffs','handoff_revisions','handoff_decisions','handoff_receipts']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 if t<>'handoffs'then execute format('create trigger handoff_history_immutable before update or delete on public.%I for each row execute function app_private.deny_deliverable_history()',t);end if;
end loop;end$$;
create function app_private.handoff_member(p_term uuid,p_member uuid,p_unit uuid default null)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id and m.account_state='active'where tm.term_id=p_term and tm.member_id=p_member and tm.membership_kind='core'and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()
 and(p_unit is null or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null where um.term_membership_id=tm.id and um.unit_id=p_unit and um.status='active'and um.effective_from<=statement_timestamp()and um.effective_to>statement_timestamp())))
$$;
create function app_private.handoff_receiver(h public.handoffs)returns boolean language sql stable security definer set search_path='' as $$
 select app_private.handoff_member(h.term_id,h.receiver_member_id,h.receiver_unit_id)and case when h.next_task_id is null then app_private.synergy_head(h.term_id,h.receiver_unit_id,h.receiver_member_id)
 else exists(select 1 from public.tasks t where t.work_item_id=h.next_task_id and t.assignee_id=h.receiver_member_id and t.assigned_unit_id=h.receiver_unit_id)end
$$;
create function app_private.handoff_visible(h public.handoffs)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.terms where id=h.term_id and state='active')and app_private.handoff_member(h.term_id,app_private.synergy_actor(h.term_id))and
 ((app_private.synergy_actor(h.term_id)=h.sender_member_id and public.can_access_work(h.source_task_id,'detail'))or(app_private.synergy_actor(h.term_id)=h.receiver_member_id and h.state<>'cancelled'and app_private.handoff_receiver(h)))
$$;
create function app_private.handoff_sender(h public.handoffs)returns boolean language sql stable security definer set search_path='' as $$
 select app_private.synergy_actor(h.term_id)=h.sender_member_id and app_private.handoff_member(h.term_id,h.sender_member_id)and public.can_access_work(h.source_task_id,'edit')and exists(select 1 from public.work_items where id=h.source_task_id and owner_member_id=h.sender_member_id and archived_at is null)
$$;
create function app_private.finish_handoff(w public.work_items,p_command text,p_key uuid,p_payload jsonb,p_result jsonb,p_fields jsonb)returns jsonb language plpgsql set search_path='' as $$begin
 perform app_private.finish_work_command(w,p_command,p_key,p_payload,p_result,p_fields);
 update public.outbox_jobs j set payload=j.payload||jsonb_build_object('handoffId',p_result->'handoffId','revision',p_result->'revision','state',p_result->'state','receiptId',p_result->'receiptId')where j.event_id=(select id from public.audit_events where actor_id=auth.uid()and action=p_command and request_id=p_key);
 return p_result;
end$$;
create function public.submit_handoff(p_source_task_id uuid,p_receiver_member_id uuid,p_receiver_unit_id uuid,p_manifest_id uuid,p_terms jsonb,p_next_task_id uuid,p_expected_source_version integer,p_expected_next_version integer,p_request_id uuid,p_handoff_id uuid default null,p_expected_handoff_version integer default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare source public.work_items;next_work public.work_items;h public.handoffs;m public.asset_manifests;actor uuid;payload jsonb;result jsonb;files jsonb;next_terms jsonb;
begin
 select * into source from public.work_items where id=p_source_task_id and kind='task';actor:=app_private.synergy_actor(source.term_id);
 if source.id is null or actor is distinct from source.owner_member_id or not app_private.handoff_member(source.term_id,actor)or not public.can_access_work(source.id,'edit')then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.dependency_lock(source.term_id);
 if not exists(select 1 from public.terms where id=source.term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_next_task_id is not null and not public.can_access_work(p_next_task_id,'detail')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_handoff_id is not null then select * into h from public.handoffs where id=p_handoff_id;if not found or not app_private.handoff_sender(h)or h.source_task_id<>p_source_task_id or h.next_task_id is distinct from p_next_task_id then raise exception using errcode='42501',message='command_permission_denied';end if;end if;
 payload:=jsonb_build_array(p_source_task_id,p_receiver_member_id,p_receiver_unit_id,p_manifest_id,p_terms,p_next_task_id,p_expected_source_version,p_expected_next_version,p_handoff_id,p_expected_handoff_version);
 result:=app_private.begin_work_command('submit_handoff',p_request_id,payload);if result is not null then select * into h from public.handoffs where id=(result->>'handoffId')::uuid;if not app_private.handoff_sender(h)then raise exception using errcode='42501',message='command_permission_denied';end if;return result;end if;
 perform 1 from public.work_items where id in(p_source_task_id,p_next_task_id)order by id for update;
 select * into source from public.work_items where id=p_source_task_id;
 if source.owner_member_id is distinct from actor or not public.can_access_work(source.id,'edit')or source.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 if source.version is distinct from p_expected_source_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if not exists(select 1 from public.tasks where work_item_id=source.id and workflow_state='done')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_terms is null or jsonb_typeof(p_terms)<>'object'or octet_length(p_terms::text)>14000 or exists(select 1 from jsonb_object_keys(p_terms)k where k not in('output','criteria','dueOn','reason'))or exists(select 1 from jsonb_each(p_terms)e where jsonb_typeof(e.value)<>'string')
 or coalesce(length(btrim(p_terms->>'output')),0)not between 1 and 240 or coalesce(length(btrim(p_terms->>'criteria')),0)not between 1 and 8000 or coalesce(length(btrim(p_terms->>'reason')),0)not between 1 and 2000 or coalesce(p_terms->>'dueOn','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or not isfinite((p_terms->>'dueOn')::date)
 or(p_handoff_id is null)<>(p_expected_handoff_version is null)or p_receiver_member_id=actor or not app_private.handoff_member(source.term_id,p_receiver_member_id,p_receiver_unit_id)then raise exception using errcode='22023',message='command_validation_failed';end if;
 select * into m from public.asset_manifests where id=p_manifest_id and work_item_id=source.id;
 if m.id is null or not public.can_read_manifest(m.id)or not exists(select 1 from public.asset_manifest_items where manifest_id=m.id)or exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=m.id and(a.origin_work_item_id<>source.id or a.state<>'finalized'or a.kind<>'upload'))then raise exception using errcode='42501',message='command_permission_denied';end if;
 select jsonb_agg(jsonb_build_object('assetId',a.id,'name',a.filename,'sha256',a.sha256,'size',a.size_bytes,'mime',a.mime_type)order by a.id)into files from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=m.id;
 if p_next_task_id is not null then
 select * into next_work from public.work_items where id=p_next_task_id and kind='task'and term_id=source.term_id;
 if next_work.id is null or next_work.id=source.id or next_work.archived_at is not null or not public.can_access_work(next_work.id,'detail')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if next_work.version is distinct from p_expected_next_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if not exists(select 1 from public.tasks where work_item_id=next_work.id and assignee_id=p_receiver_member_id and assigned_unit_id=p_receiver_unit_id and workflow_state='todo')or not exists(select 1 from public.task_dependencies where predecessor_task_id=source.id and successor_task_id=next_work.id and dependency_type='finish_to_start'and required and removed_at is null)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 next_terms:=jsonb_build_object('taskId',next_work.id,'ownerId',next_work.owner_member_id,'receiverUnitId',p_receiver_unit_id,'dueOn',next_work.due_on,'dueAt',next_work.due_at);
 elsif p_expected_next_version is not null or not app_private.synergy_head(source.term_id,p_receiver_unit_id,p_receiver_member_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_handoff_id is null then
 insert into public.handoffs(organization_id,term_id,source_task_id,next_task_id,sender_member_id,receiver_member_id,receiver_unit_id,created_by)values(source.organization_id,source.term_id,source.id,p_next_task_id,actor,p_receiver_member_id,p_receiver_unit_id,auth.uid())returning * into h;
 else
 select * into h from public.handoffs where id=p_handoff_id for update;
 if h.version is distinct from p_expected_handoff_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if h.state not in('changes_requested','declined','cancelled')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 update public.handoffs set current_revision=current_revision+1,version=version+1,state='proposed',receiver_member_id=p_receiver_member_id,receiver_unit_id=p_receiver_unit_id,updated_at=statement_timestamp()where id=h.id returning * into h;
 end if;
 update public.work_items set updated_at=statement_timestamp()where id=source.id returning * into source;
 insert into public.handoff_revisions(handoff_id,revision,source_version,next_version,receiver_member_id,receiver_unit_id,manifest_id,manifest_sha256,files,output,criteria,due_on,next_terms,reason,created_by)
 values(h.id,h.current_revision,source.version,next_work.version,p_receiver_member_id,p_receiver_unit_id,m.id,m.sha256,files,btrim(p_terms->>'output'),btrim(p_terms->>'criteria'),(p_terms->>'dueOn')::date,next_terms,p_terms->>'reason',auth.uid());
 insert into public.handoff_decisions(handoff_id,revision,handoff_version,action,member_id,reason,actor_id)values(h.id,h.current_revision,h.version,'proposed',actor,p_terms->>'reason',auth.uid());
 return app_private.finish_handoff(source,'submit_handoff',p_request_id,payload,jsonb_build_object('handoffId',h.id,'version',h.version,'revision',h.current_revision,'state',h.state,'receiptId',null,'nextTaskId',null),'["handoff_offered"]');
end$$;
create function app_private.handoff_response(p_command text,p_handoff_id uuid,p_action text,p_expected_version integer,p_expected_revision integer,p_reason text,p_key uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare h public.handoffs;r public.handoff_revisions;source public.work_items;next_work public.work_items;actor uuid;payload jsonb;result jsonb;receipt public.handoff_receipts;next_result jsonb;expiry timestamptz;
begin
 select * into h from public.handoffs where id=p_handoff_id;actor:=app_private.synergy_actor(h.term_id);
 if h.id is null or not app_private.handoff_visible(h)or(p_action='cancel'and not app_private.handoff_sender(h))or(p_action<>'cancel'and(actor is distinct from h.receiver_member_id or not app_private.handoff_receiver(h)))then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.dependency_lock(h.term_id);
 payload:=jsonb_build_array(p_handoff_id,p_action,p_expected_version,p_expected_revision,p_reason);result:=app_private.begin_work_command(p_command,p_key,payload);if result is not null then return result;end if;
 perform 1 from public.work_items where id in(h.source_task_id,h.next_task_id)order by id for update;
 select * into h from public.handoffs where id=p_handoff_id for update;
 if not app_private.handoff_visible(h)or(p_action='cancel'and not app_private.handoff_sender(h))or(p_action<>'cancel'and(actor is distinct from h.receiver_member_id or not app_private.handoff_receiver(h)))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if h.version is distinct from p_expected_version or h.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_action is null or p_action not in('accept','decline','changes_requested','cancel')or coalesce(length(btrim(p_reason)),0)not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if h.state<>'proposed'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select * into source from public.work_items where id=h.source_task_id;
 select * into r from public.handoff_revisions where handoff_id=h.id and revision=h.current_revision;
 if p_action='accept' then
 if source.version<>r.source_version or source.owner_member_id<>h.sender_member_id or source.archived_at is not null or not app_private.handoff_member(h.term_id,h.sender_member_id)then raise exception using errcode='40001',message='command_stale_version';end if;
 if not exists(select 1 from public.tasks where work_item_id=source.id and workflow_state='done')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if h.next_task_id is not null then
 select * into next_work from public.work_items where id=h.next_task_id;
 if next_work.version is distinct from r.next_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if next_work.archived_at is not null or not public.can_access_work(next_work.id,'edit')or not app_private.task_participant(next_work.id)or not exists(select 1 from public.tasks where work_item_id=next_work.id and workflow_state='todo')or not exists(select 1 from public.task_dependencies where predecessor_task_id=source.id and successor_task_id=next_work.id and dependency_type='finish_to_start'and required and removed_at is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 end if;
 end if;
 update public.handoffs set version=version+1,state=case p_action when 'accept'then 'accepted'when 'cancel'then 'cancelled'when 'decline'then 'declined'else 'changes_requested'end,updated_at=statement_timestamp()where id=h.id returning * into h;
 if p_action='accept'then
 if h.next_task_id is not null then
 next_result:=public.transition_task(h.next_task_id,jsonb_build_object('state','in_progress','reason','Explicit immutable handoff acceptance'),r.next_version,gen_random_uuid());
 select least((select ends_at from public.term_memberships where term_id=h.term_id and member_id=h.sender_member_id),(select ends_at from public.term_memberships where term_id=h.term_id and member_id=h.receiver_member_id),(select(closes_on+1)::timestamp at time zone'Asia/Manila'from public.terms where id=h.term_id))into expiry;
 insert into public.record_grants(organization_id,term_id,work_item_id,member_id,grant_kind,expires_at,grantor_id)values(h.organization_id,h.term_id,h.next_task_id,h.sender_member_id,'read',expiry,public.current_term_membership(h.term_id)),(h.organization_id,h.term_id,h.next_task_id,h.receiver_member_id,'read',expiry,public.current_term_membership(h.term_id));
 end if;
 insert into public.handoff_receipts(handoff_id,revision,receiver_member_id,manifest_id,manifest_sha256,criteria,next_task_id,next_version,notes,actor_id)values(h.id,r.revision,h.receiver_member_id,r.manifest_id,r.manifest_sha256,r.criteria,h.next_task_id,(next_result->>'version')::int,p_reason,auth.uid())returning * into receipt;
 end if;
 insert into public.handoff_decisions(handoff_id,revision,handoff_version,action,member_id,reason,actor_id)values(h.id,r.revision,h.version,p_action,actor,p_reason,auth.uid());
 update public.work_items set updated_at=statement_timestamp()where id=source.id returning * into source;
 return app_private.finish_handoff(source,p_command,p_key,payload,jsonb_build_object('handoffId',h.id,'version',h.version,'revision',h.current_revision,'state',h.state,'receiptId',receipt.id,'nextTaskId',case when p_action='accept'then h.next_task_id end),jsonb_build_array('handoff_response',p_action));
end$$;
create function public.respond_to_handoff(p_handoff_id uuid,p_action text,p_expected_version integer,p_expected_revision integer,p_reason text,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.handoff_response('respond_to_handoff',p_handoff_id,p_action,p_expected_version,p_expected_revision,p_reason,p_request_id)$$;
create function public.accept_handoff(p_handoff_id uuid,p_expected_version integer,p_expected_revision integer,p_notes text,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.handoff_response('accept_handoff',p_handoff_id,'accept',p_expected_version,p_expected_revision,p_notes,p_request_id)$$;
create function app_private.handoff_gate()returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.workflow_state in('in_progress','ready_for_review','done')and exists(select 1 from public.handoffs where next_task_id=new.work_item_id and state<>'accepted')then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;
end$$;
create trigger pending_handoff_gate before update on public.tasks for each row execute function app_private.handoff_gate();
create function app_private.protect_accepted_handoff()returns trigger language plpgsql set search_path='' as $$begin if old.state='accepted'then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger accepted_handoff_immutable before update or delete on public.handoffs for each row execute function app_private.protect_accepted_handoff();
create function app_private.handoff_integrity()returns trigger language plpgsql security definer set search_path='' as $$declare h public.handoffs;begin
 select * into h from public.handoffs where id=case when tg_table_name='handoffs'then(to_jsonb(new)->>'id')::uuid else(to_jsonb(new)->>'handoff_id')::uuid end;
 if(h.state='accepted')is distinct from exists(select 1 from public.handoff_receipts x join public.handoff_revisions r on r.handoff_id=x.handoff_id and r.revision=x.revision where x.handoff_id=h.id and x.revision=h.current_revision and x.receiver_member_id=h.receiver_member_id and x.manifest_id=r.manifest_id and x.manifest_sha256=r.manifest_sha256 and x.criteria=r.criteria and x.next_task_id is not distinct from h.next_task_id and((h.next_task_id is null and x.next_version is null)or exists(select 1 from public.work_items w join public.tasks t on t.work_item_id=w.id where w.id=h.next_task_id and w.version>=x.next_version and t.workflow_state<>'todo')))then raise exception using errcode='23514',message='handoff_receipt_required';end if;return null;
end$$;
create constraint trigger handoff_receipt_integrity after insert or update on public.handoffs deferrable initially deferred for each row execute function app_private.handoff_integrity();
create constraint trigger receipt_handoff_integrity after insert on public.handoff_receipts deferrable initially deferred for each row execute function app_private.handoff_integrity();
create function public.read_handoff(p_handoff_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',h.id,'version',h.version,'revision',h.current_revision,'state',h.state,'senderId',h.sender_member_id,'receiverId',h.receiver_member_id,'receiverUnitId',h.receiver_unit_id,
 'sourceTaskId',case when public.can_access_work(h.source_task_id,'detail')then h.source_task_id end,'nextTaskId',case when public.can_access_work(h.next_task_id,'detail')then h.next_task_id end,
 'package',jsonb_build_object('downloadContext',r.id,'manifestHash',r.manifest_sha256,'files',r.files,'output',r.output,'criteria',r.criteria,'dueOn',r.due_on,'nextTerms',case when public.can_access_work(h.next_task_id,'detail')then r.next_terms end),
 'receipt',(select jsonb_build_object('id',x.id,'revision',x.revision,'notes',x.notes,'acceptedAt',x.accepted_at)from public.handoff_receipts x where x.handoff_id=h.id),
 'history',coalesce((select jsonb_agg(jsonb_build_object('revision',d.revision,'action',d.action,'reason',d.reason,'recordedAt',d.recorded_at)order by d.handoff_version)from public.handoff_decisions d join public.handoff_revisions old on old.handoff_id=d.handoff_id and old.revision=d.revision where d.handoff_id=h.id and(app_private.handoff_sender(h)or old.receiver_member_id=app_private.synergy_actor(h.term_id))),'[]'))
 from public.handoffs h join public.handoff_revisions r on r.handoff_id=h.id and r.revision=h.current_revision where h.id=p_handoff_id and app_private.handoff_visible(h)
$$;
-- A package revision is an explicit narrow file-download context, never source/parent access.
alter function public.authorize_asset_download(uuid,uuid,uuid)rename to authorize_asset_download_p12;
alter function public.authorize_asset_download_p12(uuid,uuid,uuid)set schema app_private;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.handoff_revisions;h public.handoffs;a public.assets;w public.work_items;payload jsonb;result jsonb;
begin
 select * into r from public.handoff_revisions where id=p_work_item_id;
 if not found then return app_private.authorize_asset_download_p12(p_work_item_id,p_asset_id,p_request_id);end if;
 select * into h from public.handoffs where id=r.handoff_id;
 if not app_private.handoff_visible(h)or not app_private.handoff_member(h.term_id,h.sender_member_id)or not exists(select 1 from public.work_items where id=h.source_task_id and owner_member_id=h.sender_member_id and archived_at is null)or r.revision<>h.current_revision or h.state not in('proposed','accepted')then raise exception using errcode='42501',message='command_permission_denied';end if;
 select a0.* into a from public.assets a0 join public.asset_manifest_items i on i.asset_id=a0.id where i.manifest_id=r.manifest_id and a0.id=p_asset_id and a0.state='finalized'and a0.kind='upload'and a0.origin_work_item_id=h.source_task_id;
 if a.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select * into w from public.work_items where id=h.source_task_id;payload:=jsonb_build_array(r.id,a.id);result:=app_private.begin_work_command('handoff_asset_download',p_request_id,payload);
 if result is null then perform app_private.finish_work_command(w,'handoff_asset_download',p_request_id,payload,'{}','["handoff_asset_access"]');end if;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind','upload','mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256,'url',null);
end$$;
revoke all on function app_private.handoff_member(uuid,uuid,uuid),app_private.handoff_receiver(public.handoffs),app_private.handoff_visible(public.handoffs),app_private.handoff_sender(public.handoffs),app_private.handoff_response(text,uuid,text,integer,integer,text,uuid),app_private.handoff_gate(),app_private.protect_accepted_handoff(),app_private.handoff_integrity(),app_private.authorize_asset_download_p12(uuid,uuid,uuid)from public,anon,authenticated,service_role;
revoke all on function app_private.finish_handoff(public.work_items,text,uuid,jsonb,jsonb,jsonb)from public,anon,authenticated,service_role;
revoke all on function public.submit_handoff(uuid,uuid,uuid,uuid,jsonb,uuid,integer,integer,uuid,uuid,integer),public.respond_to_handoff(uuid,text,integer,integer,text,uuid),public.accept_handoff(uuid,integer,integer,text,uuid),public.read_handoff(uuid),public.authorize_asset_download(uuid,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.submit_handoff(uuid,uuid,uuid,uuid,jsonb,uuid,integer,integer,uuid,uuid,integer),public.respond_to_handoff(uuid,text,integer,integer,text,uuid),public.accept_handoff(uuid,integer,integer,text,uuid),public.read_handoff(uuid),public.authorize_asset_download(uuid,uuid,uuid)to authenticated;
commit;
