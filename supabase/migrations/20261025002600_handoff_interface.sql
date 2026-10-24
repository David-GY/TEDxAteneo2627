begin;
alter function public.read_handoff(uuid)rename to read_handoff_p17;
alter function public.read_handoff_p17(uuid)set schema app_private;
create function public.read_handoff(p_handoff_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select base||jsonb_build_object('senderName',s.display_name,'receiverName',m.display_name,'receiverUnitName',u.name,
 'canRespond',h.state='proposed'and app_private.synergy_actor(h.term_id)=h.receiver_member_id and app_private.handoff_receiver(h),
 'canWithdraw',h.state='proposed'and app_private.handoff_sender(h),
 'canRevise',h.state in('changes_requested','declined','cancelled')and app_private.handoff_sender(h),
 'revisions',coalesce((select jsonb_agg(jsonb_build_object('revision',r.revision,'output',r.output,'criteria',r.criteria,'dueOn',r.due_on,'manifestHash',r.manifest_sha256)order by r.revision)
 from public.handoff_revisions r where r.handoff_id=h.id and(app_private.handoff_sender(h)or r.receiver_member_id=app_private.synergy_actor(h.term_id))),'[]'))
 from public.handoffs h cross join lateral(select app_private.read_handoff_p17(h.id)as base)b
 join public.members s on s.id=h.sender_member_id join public.members m on m.id=h.receiver_member_id join public.org_units u on u.id=h.receiver_unit_id
 where h.id=p_handoff_id and base is not null
$$;
create function public.list_handoffs(p_term_id uuid,p_view text default 'incoming',p_work_item_id uuid default null,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not app_private.handoff_member(p_term_id,app_private.synergy_actor(p_term_id))or not exists(select 1 from public.terms where id=p_term_id and state='active')then return null;end if;
 if p_view is null or p_view not in('incoming','outgoing','work')or p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_view='work'and(p_work_item_id is null or not public.can_access_work(p_work_item_id,'detail')or not exists(select 1 from public.work_items where id=p_work_item_id and term_id=p_term_id))then return null;end if;
 with permitted as materialized(select h.* from public.handoffs h where h.term_id=p_term_id and app_private.handoff_visible(h)
 and(case p_view when 'incoming'then h.receiver_member_id=app_private.synergy_actor(p_term_id)when 'outgoing'then h.sender_member_id=app_private.synergy_actor(p_term_id)else h.source_task_id=p_work_item_id or h.next_task_id=p_work_item_id end)),
 page as(select h.id,public.read_handoff(h.id)as item from permitted h order by h.updated_at desc,h.id limit 20 offset(p_page-1)*20)
 select jsonb_build_object('items',coalesce((select jsonb_agg(item order by id)from page),'[]'),'total',(select count(*)from permitted),'page',p_page,'pageSize',20,'awaitingAcceptance',p_view='work'and exists(select 1 from public.handoffs pending where pending.next_task_id=p_work_item_id and pending.state<>'accepted'))into result;
 return result;
end$$;
create function public.handoff_submission_options(p_source_task_id uuid,p_handoff_id uuid default null)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;h public.handoffs;actor uuid;result jsonb;begin
 select * into w from public.work_items where id=p_source_task_id and kind='task';actor:=app_private.synergy_actor(w.term_id);
 if w.id is null or actor is distinct from w.owner_member_id or not app_private.handoff_member(w.term_id,actor)or not public.can_access_work(w.id,'edit')or w.archived_at is not null
 or not exists(select 1 from public.terms where id=w.term_id and state='active')or not exists(select 1 from public.tasks where work_item_id=w.id and workflow_state='done')then return null;end if;
 if p_handoff_id is not null then select * into h from public.handoffs where id=p_handoff_id;if h.source_task_id is distinct from w.id or not app_private.handoff_sender(h)then return null;end if;end if;
 with allowed as materialized(select n.*,t.assignee_id,t.assignee_name,t.assigned_unit_id from public.work_items n join public.tasks t on t.work_item_id=n.id
 where n.term_id=w.term_id and n.archived_at is null and t.workflow_state='todo'and t.assignee_id<>actor and public.can_access_work(n.id,'detail')
 and exists(select 1 from public.task_dependencies d where d.predecessor_task_id=w.id and d.successor_task_id=n.id and d.removed_at is null and d.required and d.dependency_type='finish_to_start')
 and app_private.handoff_member(w.term_id,t.assignee_id,t.assigned_unit_id)
 and not exists(select 1 from public.handoffs other where other.next_task_id=n.id and other.id is distinct from p_handoff_id)),
 targets as(select 'task:'||n.id as key,n.title||' · '||n.assignee_name||' / '||u.name as name,n.assignee_id as receiver,n.assigned_unit_id as unit,n.id as next_id,n.version from allowed n join public.org_units u on u.id=n.assigned_unit_id and u.archived_at is null
 union all select 'head:'||d.member_id||':'||u.id,d.display_name||' / '||u.name,d.member_id,u.id,null::uuid,null::integer
 from public.read_directory(w.term_id)d join public.org_units u on u.term_id=w.term_id and u.archived_at is null
 where d.member_id<>actor and app_private.synergy_head(w.term_id,u.id,d.member_id)),
 choices as(select * from targets order by name,key limit 50)
 select jsonb_build_object('sourceId',w.id,'sourceVersion',w.version,'canSubmit',p_handoff_id is null or h.state in('changes_requested','declined','cancelled'),
 'manifests',coalesce((select jsonb_agg(item order by created_at desc,id)from(select m.id,m.created_at,jsonb_build_object('id',m.id,'hash',m.sha256,'files',(select jsonb_agg(jsonb_build_object('assetId',a.id,'name',a.filename,'sha256',a.sha256,'size',a.size_bytes,'mime',a.mime_type)order by a.id)from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=m.id))as item
 from public.asset_manifests m where m.work_item_id=w.id and public.can_read_manifest(m.id)and exists(select 1 from public.asset_manifest_items where manifest_id=m.id)
 and not exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=m.id and(a.origin_work_item_id<>w.id or a.kind<>'upload'or a.state<>'finalized'))order by m.created_at desc,m.id limit 20)x),'[]'),
 'targets',coalesce((select jsonb_agg(jsonb_build_object('key',key,'name',name,'receiverId',receiver,'receiverUnitId',unit,'nextTaskId',next_id,'nextVersion',version)order by name,key)from choices),'[]'))into result;return result;
end$$;
revoke all on function app_private.read_handoff_p17(uuid),public.read_handoff(uuid),public.list_handoffs(uuid,text,uuid,integer),public.handoff_submission_options(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_handoff(uuid),public.list_handoffs(uuid,text,uuid,integer),public.handoff_submission_options(uuid,uuid)to authenticated;
create or replace function public.read_overview(p_term_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with actor as(select member_id from public.term_memberships where id=public.current_term_membership(p_term_id)),
 handoff_actions as materialized(
 select h.id,h.next_task_id,r.output as title,s.display_name as owner,r.due_on,null::timestamptz as due_at,
 case when(h.state='proposed'and actor.member_id=h.receiver_member_id)or(h.state in('changes_requested','declined')and app_private.handoff_sender(h))then 'actionable'else 'waiting'end as lane,
 case when h.state='proposed'and actor.member_id=h.receiver_member_id then 'Review package and explicitly accept or request changes'
 when h.state='proposed'then 'Await explicit receiver acceptance'when app_private.handoff_sender(h)then 'Review feedback, revise package and resubmit'else 'Await sender revision or scope resolution'end as action,
 case when h.state='proposed'then m.display_name else s.display_name end as person,h.state,u.name as committee
 from public.handoffs h join public.handoff_revisions r on r.handoff_id=h.id and r.revision=h.current_revision
 join public.members s on s.id=h.sender_member_id join public.members m on m.id=h.receiver_member_id join public.org_units u on u.id=h.receiver_unit_id cross join actor
 where h.term_id=p_term_id and h.state in('proposed','changes_requested','declined')and app_private.handoff_visible(h)
 ), eligible as materialized(
 select id,'handoff'::text as source,title,owner,due_on,due_at,lane,action,person,state,committee from handoff_actions
 union all
 select w.id,'task'::text as source,w.title,w.owner_display_name as owner,w.due_on,w.due_at,
 case when exists(select 1 from public.handoffs pending where pending.next_task_id=w.id and pending.state<>'accepted')or t.workflow_state in('blocked','ready_for_review')then 'waiting' else 'actionable'end as lane,
 case when exists(select 1 from public.handoffs pending where pending.next_task_id=w.id and pending.state<>'accepted')then 'Await an explicitly accepted handoff package'else case t.workflow_state when 'blocked'then 'Follow up the recorded blocker'when 'ready_for_review'then 'Await independent scoped review'else 'Update task progress'end end as action,
 case when exists(select 1 from public.handoffs pending where pending.next_task_id=w.id and pending.state<>'accepted')then 'Package participant not shared here; ask your committee head'when t.workflow_state='ready_for_review'then 'Independent reviewer not yet named' when t.workflow_state='blocked'then 'Contact the task owner about the blocker' else coalesce(t.assignee_name,w.owner_display_name)end as person,
 t.workflow_state as state,u.name as committee
 from public.work_items w join public.tasks t on t.work_item_id=w.id join actor on actor.member_id=t.assignee_id
 left join public.org_units u on u.id=t.assigned_unit_id and u.archived_at is null
 where w.term_id=p_term_id and exists(select 1 from public.terms where id=w.term_id and state='active') and w.archived_at is null and public.can_access_work(w.id,'detail') and t.workflow_state not in('done','cancelled') and not exists(select 1 from handoff_actions ha where ha.next_task_id=w.id)
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
commit;
