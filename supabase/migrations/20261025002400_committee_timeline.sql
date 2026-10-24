begin;
create function public.read_committee_timeline(p_term_id uuid,p_filters jsonb default '{}',p_page integer default 1,p_page_size integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;day_from date;day_to date;owner_id uuid;units uuid[];size integer;begin
 if not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id) and membership_kind='core')
 or not exists(select 1 from public.terms where id=p_term_id and state='active') then return null;end if;
 if p_filters is null or jsonb_typeof(p_filters)<>'object'
 or exists(select 1 from jsonb_object_keys(p_filters)k where k not in ('units','owner','phase','type','blocked','overdue','from','to','includeUnscheduled'))
 or exists(select 1 from jsonb_each(p_filters)e where (e.key in ('owner','phase','type','from','to') and jsonb_typeof(e.value)<>'string') or(e.key in ('blocked','overdue','includeUnscheduled') and jsonb_typeof(e.value)<>'boolean'))
 or p_page is null or p_page not between 1 and 10000 or p_page_size is null or p_page_size<1
 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_filters ? 'units' then
 if jsonb_typeof(p_filters->'units')<>'array' then raise exception using errcode='22023',message='command_validation_failed';end if;
 if jsonb_array_length(p_filters->'units')>20 or exists(select 1 from jsonb_array_elements(p_filters->'units')e where jsonb_typeof(e)<>'string') then raise exception using errcode='22023',message='command_validation_failed';end if;
 select array_agg(value::uuid)into units from jsonb_array_elements_text(p_filters->'units');end if;
 owner_id:=(p_filters->>'owner')::uuid;
 if length(p_filters->>'phase')>80 or (p_filters ? 'type' and p_filters->>'type' not in ('task','deliverable','contribution'))
 or exists(select 1 from jsonb_each_text(p_filters)e where e.key in ('from','to') and e.value!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
 then raise exception using errcode='22023',message='command_validation_failed';end if;
 day_from:=(p_filters->>'from')::date;day_to:=(p_filters->>'to')::date;
 if day_from>day_to or not isfinite(day_from) or not isfinite(day_to) then raise exception using errcode='22023',message='command_validation_failed';end if;
 size:=least(p_page_size,100);
 with authorized as materialized(
 select w.* from public.work_items w where w.term_id=p_term_id and w.kind in ('task','deliverable') and w.archived_at is null and public.can_access_work(w.id,'detail')
 ),rows as materialized(
 select w.id,w.owner_member_id,w.owner_display_name,w.version,w.title,
 case when c.work_item_id is not null then 'contribution' else w.kind end as type,
 coalesce(d.workflow_state,t.workflow_state) as status,d.phase_key as phase,
 w.planned_start_on,coalesce(w.due_on,(w.due_at at time zone 'Asia/Manila')::date) as end_on,
 w.due_on,w.due_at,w.original_due_on,w.original_due_at,
 coalesce(d.is_blocked,t.workflow_state='blocked',false) or (w.kind='task' and (app_private.dependency_blocked(w.id) or exists(select 1 from public.handoffs h where h.next_task_id=w.id and h.state<>'accepted'))) as blocked,
 coalesce(d.workflow_state not in ('accepted','cancelled'),t.workflow_state not in ('done','cancelled'),false)
 and coalesce(w.due_at<statement_timestamp(),w.due_on<(statement_timestamp() at time zone 'Asia/Manila')::date,false) as overdue,
 case when u.id is not null then jsonb_build_object('id',u.id,'name',u.name) end as primary_unit,
 coalesce((select jsonb_agg(jsonb_build_object('id',pu.id,'name',pu.name)order by pu.name,pu.id)from public.org_units pu
 where pu.term_id=w.term_id and pu.archived_at is null and (pu.id=w.lead_unit_id or pu.id=t.assigned_unit_id or pu.id=c.receiver_unit_id or pu.id=c.requester_unit_id
 or exists(select 1 from public.deliverable_units du where du.work_item_id=w.id and du.unit_id=pu.id))),'[]') as participants
 from authorized w left join public.tasks t on t.work_item_id=w.id left join public.deliverables d on d.work_item_id=w.id
 left join public.contributions c on c.work_item_id=w.id
 left join public.org_units u on u.id=coalesce(c.receiver_unit_id,t.assigned_unit_id,w.lead_unit_id) and u.archived_at is null
 ),filtered as materialized(
 select r.* from rows r where (owner_id is null or r.owner_member_id=owner_id)
 and (units is null or exists(select 1 from jsonb_array_elements(r.participants)e where(e->>'id')::uuid=any(units)))
 and (not(p_filters ? 'phase')or r.phase=p_filters->>'phase') and(not(p_filters ? 'type')or r.type=p_filters->>'type')
 and(not coalesce((p_filters->>'blocked')::boolean,false)or r.blocked)and(not coalesce((p_filters->>'overdue')::boolean,false)or r.overdue)
 and(case when r.end_on is null then coalesce((p_filters->>'includeUnscheduled')::boolean,true)
 else (day_from is null or r.end_on>=day_from)and(day_to is null or coalesce(r.planned_start_on,r.end_on)<=day_to)end)
 ),loaded as materialized(select * from filtered order by end_on nulls last,id limit size offset(p_page-1)*size)
 select jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object(
 'id',r.id,'type',r.type,'title',r.title,'version',r.version,'owner',jsonb_build_object('id',r.owner_member_id,'name',r.owner_display_name),
 'primaryUnit',r.primary_unit,'participatingUnits',r.participants,'phase',r.phase,'status',r.status,
 'plannedStartOn',r.planned_start_on,'dueOn',r.due_on,'dueAt',r.due_at,'endOn',r.end_on,'originalDueOn',r.original_due_on,'originalDueAt',r.original_due_at,
 'blocked',r.blocked,'overdue',r.overdue,'href',case when r.type='deliverable' then '/deliverables/' else '/tasks/' end||r.id::text
 )order by r.end_on nulls last,r.id)from loaded r),'[]'),
 'total',(select count(*)from filtered),'page',p_page,'pageSize',size,
 'options',jsonb_build_object('units',coalesce((select jsonb_agg(value order by value->>'name',value->>'id')from(select distinct e.value from rows r cross join lateral jsonb_array_elements(r.participants)e)x),'[]'),
 'owners',coalesce((select jsonb_agg(jsonb_build_object('id',owner_member_id,'name',owner_display_name)order by owner_display_name,owner_member_id)from(select distinct owner_member_id,owner_display_name from rows)x),'[]'),
 'phases',coalesce((select jsonb_agg(phase order by phase)from(select distinct phase from rows where phase is not null)x),'[]')),
 'dependencies',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'predecessorId',e.predecessor_task_id,'successorId',e.successor_task_id,'type',e.dependency_type,'required',e.required)order by e.id)
 from public.task_dependencies e where e.term_id=p_term_id and e.removed_at is null and e.predecessor_task_id in(select id from loaded) and e.successor_task_id in(select id from loaded)),'[]')) into result;
 return result;
end$$;
revoke all on function public.read_committee_timeline(uuid,jsonb,integer,integer) from public,anon,authenticated,service_role;
grant execute on function public.read_committee_timeline(uuid,jsonb,integer,integer) to authenticated;
commit;
