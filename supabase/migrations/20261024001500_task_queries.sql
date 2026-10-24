begin;
create function public.read_task(p_work_item_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',w.id,'version',w.version,'updatedAt',greatest(w.updated_at,t.updated_at),'archivedAt',w.archived_at,'title',w.title,'summary',w.safe_summary,'body',t.body,'ownerId',w.owner_member_id,'ownerName',w.owner_display_name,
 'leadUnitId',w.lead_unit_id,'parentId',case when public.can_access_work(w.parent_work_item_id,'summary') then w.parent_work_item_id end,'dueOn',w.due_on,'dueAt',w.due_at,'originalDueOn',w.original_due_on,'originalDueAt',w.original_due_at,
 'classification',w.classification,'assigneeId',t.assignee_id,'assigneeName',t.assignee_name,'assignedUnitId',t.assigned_unit_id,'collaborators',coalesce((select jsonb_agg(member_id::text order by member_id) from public.task_collaborators where work_item_id=w.id),'[]'),
 'checklist',t.checklist,'state',t.workflow_state,'taskType',t.task_type,'blockedReason',t.blocked_reason,'evidence',t.completion_evidence,
 'overdue',t.workflow_state not in ('done','cancelled') and coalesce(w.due_at<statement_timestamp(),w.due_on<(statement_timestamp() at time zone 'Asia/Manila')::date,false),
 'canManage',exists(select 1 from public.term_memberships tm where tm.id=public.current_term_membership(w.term_id) and ((tm.member_id=w.owner_member_id and w.created_by=auth.uid()) or app_private.task_manager(w))),
 'canEdit',public.current_term_membership(w.term_id) is not null and public.can_access_work(w.id,'edit') and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'))
 from public.work_items w join public.tasks t on t.work_item_id=w.id where w.id=p_work_item_id and public.can_access_work(w.id,'detail')
$$;
create function public.read_tasks(p_term_id uuid,p_view text default 'assigned',p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$declare member uuid;result jsonb;begin
 if p_view not in ('assigned','created','watching','overdue','unit') or p_view is null or p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select member_id into member from public.term_memberships where id=public.current_term_membership(p_term_id);
 with permitted as materialized(select w.id,w.due_on,w.due_at,public.read_task(w.id)-array['body','checklist','evidence','parentId'] as item from public.work_items w join public.tasks t on t.work_item_id=w.id
 where w.term_id=p_term_id and w.archived_at is null and member is not null and public.can_access_work(w.id,'detail') and
 case p_view when 'assigned' then t.assignee_id=member when 'created' then w.created_by=auth.uid()
 when 'watching' then exists(select 1 from public.task_collaborators c where c.work_item_id=w.id and c.member_id=member) or exists(select 1 from public.record_grants g where g.work_item_id=w.id and app_private.work_grant_matches(g))
 when 'unit' then app_private.task_manager(w) else t.workflow_state not in ('done','cancelled') and (t.assignee_id=member or w.owner_member_id=member or app_private.task_participant(w.id)) and coalesce(w.due_at<statement_timestamp(),w.due_on<(statement_timestamp() at time zone 'Asia/Manila')::date,false) end),
 page as(select * from permitted order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id limit 20 offset(p_page-1)*20)
 select jsonb_build_object('items',coalesce((select jsonb_agg(item order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id)from page),'[]'),'total',(select count(*)from permitted),'page',p_page)into result;return result;end$$;
create function public.task_options(p_term_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('actorId',m.member_id,'members',coalesce((select jsonb_agg(jsonb_build_object('id',person.id,'name',person.display_name) order by person.display_name,person.id)
 from public.members person join public.term_memberships mt on mt.member_id=person.id where mt.term_id=p_term_id and mt.status='active' and person.account_state='active' and mt.joined_at<=statement_timestamp() and mt.ends_at>statement_timestamp() and (person.id=m.member_id or public.has_capability(p_term_id,'directory.read'))),'[]'),
 'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name,'canManage',public.has_capability(p_term_id,'committee.manage',u.id))order by u.name,u.id)from public.org_units u where u.term_id=p_term_id and u.archived_at is null),'[]'))
 from public.term_memberships m where m.id=public.current_term_membership(p_term_id) and public.has_capability(p_term_id,'workspace.read')
$$;
revoke all on function public.read_task(uuid),public.read_tasks(uuid,text,integer),public.task_options(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_task(uuid),public.read_tasks(uuid,text,integer),public.task_options(uuid) to authenticated;
commit;
