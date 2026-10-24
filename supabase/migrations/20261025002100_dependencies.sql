begin;
create table public.task_dependencies(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,
 predecessor_task_id uuid not null references public.tasks(work_item_id),successor_task_id uuid not null references public.tasks(work_item_id),
 dependency_type text not null check(dependency_type in('finish_to_start','informational')),required boolean not null,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),removed_at timestamptz,
 check(predecessor_task_id<>successor_task_id),check(dependency_type<>'informational' or not required),
 foreign key(organization_id,term_id,predecessor_task_id)references public.work_items(organization_id,term_id,id),
 foreign key(organization_id,term_id,successor_task_id)references public.work_items(organization_id,term_id,id)
);
create unique index dependency_live_pair on public.task_dependencies(predecessor_task_id,successor_task_id,dependency_type)where removed_at is null;
create index dependency_successor on public.task_dependencies(successor_task_id)where removed_at is null;
create index dependency_term on public.task_dependencies(term_id,predecessor_task_id)where removed_at is null;
create table public.task_dependency_events(
 id uuid primary key default gen_random_uuid(),dependency_id uuid not null references public.task_dependencies(id),
 operation text not null check(operation in('add','remove','scope_exception')),reason text not null check(length(btrim(reason))between 1 and 2000),
 actor_id uuid not null references auth.users(id),recorded_at timestamptz not null default statement_timestamp()
);
alter table public.task_dependencies enable row level security;
alter table public.task_dependencies force row level security;
alter table public.task_dependency_events enable row level security;
alter table public.task_dependency_events force row level security;
revoke all on public.task_dependencies,public.task_dependency_events from public,anon,authenticated,service_role;
create trigger dependency_events_immutable before update or delete on public.task_dependency_events for each row execute function app_private.deny_deliverable_history();

create function app_private.dependency_lock(p_term uuid)returns void language plpgsql volatile set search_path='' as $$begin
 -- PostgREST's default READ COMMITTED gives each post-lock query a fresh snapshot.
 -- Reject snapshot isolation rather than admitting a cycle from a pre-lock graph snapshot.
 if current_setting('transaction_isolation')<>'read committed' then raise exception using errcode='40001',message='command_stale_version';end if;
 perform pg_advisory_xact_lock(hashtextextended('task_dependencies:'||p_term::text,0));
end$$;
create function app_private.dependency_blocked(p_successor uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.task_dependencies d join public.tasks t on t.work_item_id=d.predecessor_task_id join public.work_items w on w.id=t.work_item_id
 where d.successor_task_id=p_successor and d.removed_at is null and d.required and d.dependency_type='finish_to_start' and(t.workflow_state<>'done' or w.archived_at is not null))
$$;
create function app_private.dependency_manage(w public.work_items)returns boolean language sql stable security definer set search_path='' as $$
 select public.can_access_work(w.id,'edit')and(app_private.task_manager(w)or(w.owner_member_id=app_private.synergy_actor(w.term_id)and w.created_by=auth.uid()))
$$;
create function app_private.dependency_command(p_remove uuid,p_predecessor uuid,p_successor uuid,p_type text,p_required boolean,p_predecessor_version integer,p_successor_version integer,p_reason text,p_scope_exception boolean,p_key uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare pred public.work_items;succ public.work_items;edge public.task_dependencies;payload jsonb;result jsonb;command text;operation text;
begin
 if p_remove is not null then select * into edge from public.task_dependencies where id=p_remove;p_predecessor:=edge.predecessor_task_id;p_successor:=edge.successor_task_id;end if;
 select * into pred from public.work_items where id=p_predecessor and kind='task';select * into succ from public.work_items where id=p_successor and kind='task';
 if pred.id is null or succ.id is null or pred.term_id<>succ.term_id or not app_private.dependency_manage(pred)or not app_private.dependency_manage(succ)then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.dependency_lock(succ.term_id);
 if p_remove is not null and edge.required and(not coalesce(p_scope_exception,false)or not app_private.task_manager(pred)or not app_private.task_manager(succ))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if not exists(select 1 from public.terms where id=succ.term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 command:=case when p_remove is null then 'add_task_dependency'else 'remove_task_dependency'end;
 payload:=jsonb_build_array(p_remove,p_predecessor,p_successor,p_type,p_required,p_predecessor_version,p_successor_version,p_reason,p_scope_exception);
 result:=app_private.begin_work_command(command,p_key,payload);if result is not null then return result;end if;
 perform 1 from public.work_items where id in(pred.id,succ.id)order by id for update;
 select * into pred from public.work_items where id=p_predecessor;select * into succ from public.work_items where id=p_successor;
 if not app_private.dependency_manage(pred)or not app_private.dependency_manage(succ)or(p_remove is null and pred.archived_at is not null)or succ.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 if pred.version is distinct from p_predecessor_version or succ.version is distinct from p_successor_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if coalesce(length(btrim(p_reason)),0)not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_remove is null then
 if p_predecessor=p_successor or p_type is null or p_type not in('finish_to_start','informational')or p_required is null or(p_type='informational'and p_required)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(with recursive reachable(id)as(select p_successor union select d.successor_task_id from public.task_dependencies d join reachable r on d.predecessor_task_id=r.id where d.term_id=succ.term_id and d.removed_at is null)select 1 from reachable where id=p_predecessor)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_required and exists(select 1 from public.tasks where work_item_id=succ.id and workflow_state in('in_progress','ready_for_review','done'))and exists(select 1 from public.tasks where work_item_id=pred.id and workflow_state<>'done')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 insert into public.task_dependencies(organization_id,term_id,predecessor_task_id,successor_task_id,dependency_type,required,created_by)values(succ.organization_id,succ.term_id,pred.id,succ.id,p_type,p_required,auth.uid())returning * into edge;operation:='add';
 else
 if edge.removed_at is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if edge.required and(not coalesce(p_scope_exception,false)or not app_private.task_manager(pred)or not app_private.task_manager(succ))then raise exception using errcode='42501',message='command_permission_denied';end if;
 update public.task_dependencies set removed_at=statement_timestamp()where id=edge.id;operation:=case when edge.required then 'scope_exception'else 'remove'end;
 end if;
 insert into public.task_dependency_events(dependency_id,operation,reason,actor_id)values(edge.id,operation,btrim(p_reason),auth.uid());
 update public.work_items set updated_at=statement_timestamp()where id=succ.id returning * into succ;
 result:=jsonb_build_object('workItemId',succ.id,'version',succ.version,'dependencyId',edge.id);
 return app_private.finish_work_command(succ,command,p_key,payload,result,jsonb_build_array('task_dependency',operation));
end$$;
create function public.add_task_dependency(p_predecessor_id uuid,p_successor_id uuid,p_type text,p_required boolean,p_expected_predecessor_version integer,p_expected_successor_version integer,p_reason text,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.dependency_command(null,p_predecessor_id,p_successor_id,p_type,p_required,p_expected_predecessor_version,p_expected_successor_version,p_reason,false,p_request_id)$$;
create function public.remove_task_dependency(p_dependency_id uuid,p_expected_predecessor_version integer,p_expected_successor_version integer,p_reason text,p_scope_exception boolean,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.dependency_command(p_dependency_id,null,null,null,null,p_expected_predecessor_version,p_expected_successor_version,p_reason,p_scope_exception,p_request_id)$$;

-- Lock before existing row/idempotency locks; preserve all P10/P14 validations and receipts.
alter function app_private.task_command(text,uuid,uuid,jsonb,integer,uuid)rename to task_command_p10;
create function app_private.task_command(p_command text,p_term uuid,p_id uuid,p_data jsonb,p_version integer,p_key uuid)returns jsonb language plpgsql security definer set search_path='' as $$begin
 if p_id is not null then select term_id into p_term from public.work_items where id=p_id and public.can_access_work(id,'edit');end if;
 perform app_private.dependency_lock(p_term);return app_private.task_command_p10(p_command,p_term,p_id,p_data,p_version,p_key);
end$$;
alter function public.respond_to_synergy(uuid,text,integer,integer,uuid,jsonb,text,uuid)rename to respond_to_synergy_p14;
alter function public.respond_to_synergy_p14(uuid,text,integer,integer,uuid,jsonb,text,uuid)set schema app_private;
create function public.respond_to_synergy(p_agreement_id uuid,p_action text,p_expected_version integer,p_expected_revision integer,p_owner_id uuid,p_terms jsonb,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare term uuid;begin
 select term_id into term from public.synergy_agreements a where id=p_agreement_id and app_private.synergy_visible(a);
 perform app_private.dependency_lock(term);return app_private.respond_to_synergy_p14(p_agreement_id,p_action,p_expected_version,p_expected_revision,p_owner_id,p_terms,p_reason,p_request_id);
end$$;
create function app_private.enforce_dependency_state()returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.workflow_state in('in_progress','ready_for_review','done')and app_private.dependency_blocked(new.work_item_id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if old.workflow_state='done'and new.workflow_state<>'done'and exists(select 1 from public.task_dependencies d join public.tasks s on s.work_item_id=d.successor_task_id where d.predecessor_task_id=new.work_item_id and d.removed_at is null and d.required and s.workflow_state in('in_progress','ready_for_review','done'))then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;
end$$;
create trigger task_dependency_state before update on public.tasks for each row execute function app_private.enforce_dependency_state();

create function public.read_task_dependencies(p_successor_id uuid,p_search text default '')returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('workItemId',w.id,'version',w.version,'canManage',app_private.dependency_manage(w),'blocked',app_private.dependency_blocked(w.id),
 'restricted',exists(select 1 from public.task_dependencies d where d.successor_task_id=w.id and d.removed_at is null and not public.can_access_work(d.predecessor_task_id,'detail')),
 'restrictedNextSteps',exists(select 1 from public.task_dependencies d where d.predecessor_task_id=w.id and d.removed_at is null and not public.can_access_work(d.successor_task_id,'detail')),
 'nextSteps',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'state',t.workflow_state,'type',d.dependency_type,'required',d.required)order by d.id)from public.task_dependencies d join public.work_items s on s.id=d.successor_task_id join public.tasks t on t.work_item_id=s.id where d.term_id=w.term_id and d.predecessor_task_id=w.id and d.removed_at is null and public.can_access_work(s.id,'detail')),'[]'),
 'options',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.title,'version',p.version)order by p.title,p.id)from(select candidate.* from public.work_items candidate where candidate.kind='task'and candidate.term_id=w.term_id and candidate.id<>w.id and candidate.archived_at is null and app_private.dependency_manage(w)and app_private.dependency_manage(candidate)and candidate.title ilike '%'||coalesce(p_search,'')||'%' order by candidate.title,candidate.id limit 50)p),'[]'),
 'items',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'predecessorId',p.id,'predecessorVersion',p.version,'title',p.title,'state',t.workflow_state,'archived',p.archived_at is not null,'type',d.dependency_type,'required',d.required,'canRemove',app_private.dependency_manage(p)and app_private.dependency_manage(w)and(not d.required or(app_private.task_manager(p)and app_private.task_manager(w))))order by d.id)from public.task_dependencies d join public.work_items p on p.id=d.predecessor_task_id join public.tasks t on t.work_item_id=p.id where d.successor_task_id=w.id and d.removed_at is null and public.can_access_work(p.id,'detail')),'[]'),
 'history',coalesce((select jsonb_agg(jsonb_build_object('operation',e.operation,'reason',e.reason,'recordedAt',e.recorded_at)order by e.recorded_at,e.id)from public.task_dependency_events e join public.task_dependencies d on d.id=e.dependency_id where d.successor_task_id=w.id and public.can_access_work(d.predecessor_task_id,'detail')),'[]'))
 from public.work_items w where w.id=p_successor_id and w.kind='task'and public.can_access_work(w.id,'detail')and length(coalesce(p_search,''))<=120
$$;
alter function public.read_task(uuid)rename to read_task_p14;
alter function public.read_task_p14(uuid)set schema app_private;
create function public.read_task(p_work_item_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select item||jsonb_build_object('dependencyBlocked',app_private.dependency_blocked(p_work_item_id))from(select app_private.read_task_p14(p_work_item_id)item)s where item is not null
$$;
revoke all on function app_private.dependency_lock(uuid),app_private.dependency_blocked(uuid),app_private.dependency_manage(public.work_items),app_private.dependency_command(uuid,uuid,uuid,text,boolean,integer,integer,text,boolean,uuid),app_private.task_command(text,uuid,uuid,jsonb,integer,uuid),app_private.task_command_p10(text,uuid,uuid,jsonb,integer,uuid),app_private.respond_to_synergy_p14(uuid,text,integer,integer,uuid,jsonb,text,uuid),app_private.enforce_dependency_state(),app_private.read_task_p14(uuid)from public,anon,authenticated,service_role;
revoke all on function public.add_task_dependency(uuid,uuid,text,boolean,integer,integer,text,uuid),public.remove_task_dependency(uuid,integer,integer,text,boolean,uuid),public.read_task_dependencies(uuid,text),public.read_task(uuid),public.respond_to_synergy(uuid,text,integer,integer,uuid,jsonb,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.add_task_dependency(uuid,uuid,text,boolean,integer,integer,text,uuid),public.remove_task_dependency(uuid,integer,integer,text,boolean,uuid),public.read_task_dependencies(uuid,text),public.read_task(uuid),public.respond_to_synergy(uuid,text,integer,integer,uuid,jsonb,text,uuid)to authenticated;
commit;
