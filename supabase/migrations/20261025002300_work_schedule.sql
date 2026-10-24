begin;
-- No historical start is inferred. All deadline-writing paths share this invariant.
alter table public.work_items add column planned_start_on date;
alter table public.work_items add constraint work_schedule_calendar_range check(
 planned_start_on is null or (
 planned_start_on between date '0001-01-01' and date '9999-12-31'
 and planned_start_on<=coalesce(due_on,(due_at at time zone 'Asia/Manila')::date,planned_start_on))
);

create function app_private.schedule_authorized(w public.work_items) returns boolean
language sql stable security definer set search_path='' as $$
 select w.archived_at is null
 and exists(select 1 from public.terms where id=w.term_id and state='active')
 and exists(select 1 from public.term_memberships where id=public.current_term_membership(w.term_id) and membership_kind='core')
 and public.can_access_work(w.id,'edit')
 -- P14 has no negotiated planned-start field yet. Never silently amend its work.
 and not exists(select 1 from public.contributions where work_item_id=w.id)
 and (w.kind='deliverable' or (w.kind='task' and (
 app_private.task_manager(w) or (w.owner_member_id=app_private.synergy_actor(w.term_id) and w.created_by=auth.uid()))))
$$;

create function public.update_work_schedule(p_work_item_id uuid,p_planned_start_on date,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.work_items;payload jsonb;result jsonb;begin
 select * into w from public.work_items where id=p_work_item_id;
 if not found or not app_private.schedule_authorized(w) then raise exception using errcode='42501',message='command_permission_denied';end if;
 -- Same lock order as graph, agreement and handoff commands; reject old snapshots.
 perform app_private.dependency_lock(w.term_id);
 payload:=jsonb_build_array(p_work_item_id,p_planned_start_on,p_expected_version);
 result:=app_private.begin_work_command('update_work_schedule',p_request_id,payload);
 if result is not null then return result;end if;
 select * into w from public.work_items where id=p_work_item_id for update;
 if not app_private.schedule_authorized(w) then raise exception using errcode='42501',message='command_permission_denied';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if (w.kind='task' and not exists(select 1 from public.tasks where work_item_id=w.id and workflow_state in ('todo','in_progress','blocked')))
 or (w.kind='deliverable' and not exists(select 1 from public.deliverables where work_item_id=w.id and workflow_state in ('proposed','draft','in_progress')))
 then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.planned_start_on is not distinct from p_planned_start_on then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.work_items set planned_start_on=p_planned_start_on where id=w.id returning * into w;
 return app_private.finish_work_command(w,'update_work_schedule',p_request_id,payload,
 jsonb_build_object('workItemId',w.id,'version',w.version),'["planned_start_on"]');
end$$;
revoke all on function app_private.schedule_authorized(public.work_items),public.update_work_schedule(uuid,date,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function public.update_work_schedule(uuid,date,integer,uuid) to authenticated;
commit;
