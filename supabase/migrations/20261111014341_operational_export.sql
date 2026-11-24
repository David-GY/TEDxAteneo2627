begin;

insert into public.restricted_read_endpoints(endpoint, argument_types)
values ('export_operational_work', 'uuid, text');

create function public.export_operational_work(p_term_id uuid, p_kind text)
returns jsonb
language plpgsql security definer
set search_path = ''
set timezone = 'UTC'
as $$
declare
  rows jsonb;
  row_count integer;
  references_ready boolean;
  term_label text;
begin
  perform app_private.request_actor(p_term_id);
  if p_kind is null or p_kind not in ('task', 'deliverable') then
    raise exception using errcode = '22023', message = 'command_validation_failed';
  end if;

  -- Apply the normal detail/summary boundary before resolving reference values
  -- or counting rows. Keep the download bounded without silent truncation.
  with permitted as materialized (
    select w.id, w.title, w.due_on, w.due_at, w.original_due_on, w.original_due_at
    from public.work_items w
    where w.term_id = p_term_id and w.kind = p_kind
      and w.archived_at is null and w.classification = 'ordinary'
      and public.can_access_work(w.id, case when p_kind = 'task' then 'detail' else 'summary' end)
      and (p_kind = 'deliverable' or exists (
        select 1 from public.tasks t where t.work_item_id = w.id and t.task_type = 'ordinary'
      ))
      and (w.parent_work_item_id is null or exists (
        select 1 from public.work_items parent
        where parent.id = w.parent_work_item_id and parent.kind in ('task', 'deliverable')
          and parent.classification = 'ordinary' and public.can_access_work(parent.id, 'summary')
      ))
    order by w.id
    limit 2001
  )
  select count(*)::integer, coalesce(bool_and(r.reference_text is not null), true),
    coalesce(jsonb_agg(jsonb_build_object(
      'id', w.id, 'reference', r.reference_text, 'title', w.title,
      'dueOn', w.due_on, 'dueAt', w.due_at,
      'originalDueOn', w.original_due_on, 'originalDueAt', w.original_due_at
    ) order by r.sequence_no, w.id), '[]'::jsonb)
  into row_count, references_ready, rows
  from permitted w
  left join public.work_references r on r.work_item_id = w.id and r.term_id = p_term_id and r.kind = p_kind;

  if row_count > 2000 then
    raise exception using errcode = '54000', message = 'operational_export_limit';
  end if;
  if not references_ready then
    raise exception using errcode = '55000', message = 'work_reference_backfill_pending';
  end if;
  select label into strict term_label from public.terms where id = p_term_id;
  perform app_private.record_content_read('export_operational_work', p_term_id, null, row_count > 0);
  return jsonb_build_object('termId', p_term_id, 'termLabel', term_label, 'kind', p_kind, 'rows', rows);
end;
$$;

revoke all on function public.export_operational_work(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.export_operational_work(uuid, text) to authenticated;

commit;
