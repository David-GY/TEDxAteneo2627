begin;
-- Extend the existing authorized detail projection; do not expose private parent/case metadata.
alter function public.read_task(uuid) rename to read_task_p35;
alter function public.read_task_p35(uuid) set schema app_private;
create function public.read_task(p_work_item_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; w public.work_items; t public.tasks; parent jsonb; fin text:='pending_assessment'; pub text:='pending_assessment'; actions jsonb:='[]'; actor uuid;
begin
 result:=app_private.read_task_p35(p_work_item_id);
 if result is null then return null; end if;
 select * into w from public.work_items where id=p_work_item_id;
 select * into t from public.tasks where work_item_id=w.id;
 select member_id into actor from public.term_memberships where id=public.current_term_membership(w.term_id);
 -- Conservative action suggestions only. Existing commands still recheck every guard and payload.
 if (result->>'canEdit')::boolean and t.workflow_state not in('done','cancelled') and ((result->>'canManage')::boolean or app_private.task_participant(w.id)) then
  if t.workflow_state in('todo','blocked') and not app_private.dependency_blocked(w.id) then actions:=actions||'"in_progress"'::jsonb;end if;
  if t.workflow_state<>'todo' then actions:=actions||'"todo"'::jsonb;end if;
  if t.workflow_state<>'blocked' then actions:=actions||'"blocked"'::jsonb;end if;
  if t.task_type='review_required' and t.workflow_state<>'ready_for_review' and not app_private.dependency_blocked(w.id) then actions:=actions||'"ready_for_review"'::jsonb;end if;
  if t.workflow_state<>'blocked' and not app_private.dependency_blocked(w.id) and not exists(select 1 from jsonb_array_elements(t.checklist)c where c->>'done'<>'true') and
   (t.task_type='ordinary' or(t.task_type='review_required' and t.workflow_state='ready_for_review' and app_private.task_manager(w) and actor is distinct from t.assignee_id)) then actions:=actions||'"done"'::jsonb;end if;
  if (result->>'canManage')::boolean then actions:=actions||'"cancelled"'::jsonb;end if;
 end if;
 if result->>'taskType'<>'governed' then
  if w.parent_work_item_id is null then fin:='not_required';pub:='not_required';
  elsif public.can_access_work(w.parent_work_item_id,'summary') then
   parent:=public.read_deliverable_readiness(w.parent_work_item_id);
   if parent is not null then
    fin:=case when not(parent->>'financeRequired')::boolean then 'not_required' when(parent->'gates'->>'finance')::boolean then 'verified' else 'pending' end;
    pub:=case when not(parent->>'publicityRequired')::boolean then 'not_required' when(parent->'gates'->>'publicity')::boolean then 'verified' else 'pending' end;
   end if;
  end if;
 end if;
 return result||jsonb_build_object('reviewGates',jsonb_build_object('finance',fin,'publicity',pub),'progressActions',actions);
end $$;
revoke all on function app_private.read_task_p35(uuid) from public,anon,authenticated,service_role;
revoke all on function public.read_task(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_task(uuid) to authenticated;
commit;
