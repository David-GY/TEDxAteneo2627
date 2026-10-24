begin;
-- P10 foundation only: ownership is not an assignment or an accepted cross-unit agreement.
create function public.read_owned_tasks(p_term_id uuid,p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare member uuid; result jsonb;begin
  if p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
  select member_id into member from public.term_memberships where id=public.current_term_membership(p_term_id);
  with permitted as materialized (
    select w.id,w.title,w.safe_summary,w.due_on,w.due_at,s.semantic_category,
      coalesce(w.due_at<statement_timestamp(),w.due_on<(statement_timestamp() at time zone 'Asia/Manila')::date,false) as overdue
    from public.work_items w join public.tasks t on t.work_item_id=w.id join public.status_definitions s on s.id=w.status_id
    where w.term_id=p_term_id and w.owner_member_id=member and w.archived_at is null
      and public.has_capability(p_term_id,'workspace.read') and public.can_access_work(w.id,'summary')
  ), page as (select * from permitted order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id limit 20 offset (p_page-1)*20)
  select jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object('id',id,'title',title,'summary',safe_summary,'dueOn',due_on,'dueAt',due_at,'category',semantic_category,'overdue',overdue)
    order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id) from page),'[]'::jsonb),'total',(select count(*) from permitted),'page',p_page) into result;
  return result;
end$$;
revoke all on function public.read_owned_tasks(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.read_owned_tasks(uuid,integer) to authenticated;
commit;
