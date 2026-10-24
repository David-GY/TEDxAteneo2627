begin;
-- A form reads exactly one independently permitted core record, never a timeline page.
create function public.read_work_schedule(p_work_item_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',w.id,'version',w.version,'plannedStartOn',w.planned_start_on,'dueOn',w.due_on,'dueAt',w.due_at,
 'canSchedule',app_private.schedule_authorized(w) and (
 (w.kind='task' and exists(select 1 from public.tasks where work_item_id=w.id and workflow_state in ('todo','in_progress','blocked')))
 or(w.kind='deliverable' and exists(select 1 from public.deliverables where work_item_id=w.id and workflow_state in ('proposed','draft','in_progress')))))
 from public.work_items w where w.id=p_work_item_id and w.kind in ('task','deliverable')
 and exists(select 1 from public.term_memberships where id=public.current_term_membership(w.term_id) and membership_kind='core')
 and exists(select 1 from public.terms where id=w.term_id and state='active') and public.can_access_work(w.id,'detail')
$$;
revoke all on function public.read_work_schedule(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_work_schedule(uuid) to authenticated;
commit;
