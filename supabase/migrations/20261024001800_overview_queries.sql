begin;
create function public.read_overview(p_term_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with actor as(select member_id from public.term_memberships where id=public.current_term_membership(p_term_id)),
 eligible as materialized(
 select w.id,'task'::text as source,w.title,w.owner_display_name as owner,w.due_on,w.due_at,
 case when t.workflow_state in('blocked','ready_for_review')then 'waiting' else 'actionable'end as lane,
 case t.workflow_state when 'blocked'then 'Follow up the recorded blocker' when 'ready_for_review'then 'Await independent scoped review' else 'Update task progress'end as action,
 case when t.workflow_state='ready_for_review'then 'Independent reviewer not yet named' when t.workflow_state='blocked'then 'Contact the task owner about the blocker' else coalesce(t.assignee_name,w.owner_display_name)end as person,
 t.workflow_state as state,u.name as committee
 from public.work_items w join public.tasks t on t.work_item_id=w.id join actor on actor.member_id=t.assignee_id
 left join public.org_units u on u.id=t.assigned_unit_id and u.archived_at is null
 where w.term_id=p_term_id and exists(select 1 from public.terms where id=w.term_id and state='active') and w.archived_at is null and public.can_access_work(w.id,'detail') and t.workflow_state not in('done','cancelled')
 union all
 select w.id,'deliverable',w.title,w.owner_display_name,w.due_on,w.due_at,
 case when d.is_blocked or d.workflow_state in('submitted','proposed')then 'waiting' else 'actionable'end,
 case when d.is_blocked then 'Follow up the recorded blocker' when d.workflow_state='submitted'then 'Await independent acceptance review' when d.workflow_state='proposed'then 'Await scoped head adoption' else 'Advance outcome and acceptance criteria'end,
 case when d.workflow_state in('submitted','proposed')then 'Scoped reviewer not yet named' else w.owner_display_name end,
 d.workflow_state,u.name
 from public.work_items w join public.deliverables d on d.work_item_id=w.id join actor on actor.member_id=w.owner_member_id
 left join public.org_units u on u.id=w.lead_unit_id and u.archived_at is null
 where w.term_id=p_term_id and exists(select 1 from public.terms where id=w.term_id and state='active') and w.archived_at is null and public.can_access_work(w.id,'detail') and d.workflow_state not in('accepted','cancelled')
 ), page as(select *,coalesce(due_at<statement_timestamp(),due_on<(statement_timestamp()at time zone'Asia/Manila')::date,false) as overdue
 from eligible order by lane,coalesce(due_at,(due_on+1)::timestamp at time zone'Asia/Manila')nulls last,source,id limit 50),
 rows as(select jsonb_build_object('id',id,'source',source,'title',title,'owner',owner,'dueOn',due_on,'dueAt',due_at,'lane',lane,'action',action,'person',person,'state',state,'committee',committee,'overdue',overdue)as item,lane,due_on,due_at,source,id from page)
 select jsonb_build_object('items',coalesce((select jsonb_agg(item order by lane,coalesce(due_at,(due_on+1)::timestamp at time zone'Asia/Manila')nulls last,source,id)from rows),'[]'),'hasMore',(select count(*)>50 from eligible),'refreshedAt',statement_timestamp())
$$;
revoke all on function public.read_overview(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_overview(uuid) to authenticated;
commit;
