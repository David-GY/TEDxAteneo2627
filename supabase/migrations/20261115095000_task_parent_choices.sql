begin;

alter function public.task_options(uuid) rename to task_options_before_parents;
revoke execute on function public.task_options_before_parents(uuid) from authenticated;
alter function public.task_options_before_parents(uuid) set schema app_private;

create function public.task_options(p_term_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select options.value || jsonb_build_object('parents', coalesce((
   select jsonb_agg(jsonb_build_object('id', w.id, 'name', w.title,
     'reference', app_private.work_reference(w.id)) order by w.title, w.id)
   from public.work_items w
   where w.term_id = p_term_id and w.kind = 'deliverable' and w.archived_at is null
     and public.can_access_work(w.id, 'edit')
 ), '[]'::jsonb))
 from (select app_private.task_options_before_parents(p_term_id) as value) options
 where options.value is not null
$$;

revoke all on function public.task_options(uuid) from public, anon, authenticated, service_role;
grant execute on function public.task_options(uuid) to authenticated;

commit;
