begin;
alter table public.deliverables
  add column phase_key text check(phase_key is null or length(btrim(phase_key)) between 1 and 80),
  add column outcome text check(outcome is null or length(outcome)<=4000),
  add column acceptance_criteria text check(acceptance_criteria is null or length(acceptance_criteria)<=8000),
  add column is_blocked boolean not null default false,
  add column safe_blocker_summary text check(safe_blocker_summary is null or length(safe_blocker_summary)<=1000),
  add constraint deliverables_scope_key unique(organization_id,term_id,work_item_id),
  add check(is_blocked or safe_blocker_summary is null);
create table public.deliverable_units (
  organization_id uuid not null, term_id uuid not null, work_item_id uuid not null, unit_id uuid not null,
  primary key(work_item_id,unit_id),
  foreign key(organization_id,term_id,work_item_id) references public.deliverables(organization_id,term_id,work_item_id),
  foreign key(organization_id,term_id,unit_id) references public.org_units(organization_id,term_id,id)
);
create index deliverable_units_unit on public.deliverable_units(organization_id,term_id,unit_id);
alter table public.deliverable_units enable row level security;
alter table public.deliverable_units force row level security;
revoke all on public.deliverable_units from public,anon,authenticated,service_role;
grant select on public.deliverable_units to authenticated;
create policy deliverable_units_read on public.deliverable_units for select to authenticated using(public.can_access_work(work_item_id,'summary'));
comment on table public.deliverable_units is 'Planning involvement only, not an accepted agreement or assignment. P10 adds real contributions.';

create function app_private.deliverable_summary(w public.work_items,d public.deliverables) returns jsonb
language sql stable set search_path='' as $$
  select jsonb_build_object('id',w.id,'termId',w.term_id,'title',w.title,'summary',w.safe_summary,
    'owner',jsonb_build_object('id',w.owner_member_id,'name',w.owner_display_name,
      'active',exists(select 1 from public.members m join public.term_memberships tm on tm.member_id=m.id and tm.term_id=w.term_id
        where m.id=w.owner_member_id and m.account_state='active' and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp())),
    'leadUnit',(select jsonb_build_object('id',id,'name',name) from public.org_units where id=w.lead_unit_id),
    'supportingUnits',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name) order by u.name,u.id)
      from public.deliverable_units du join public.org_units u on u.id=du.unit_id where du.work_item_id=w.id and u.id is distinct from w.lead_unit_id),'[]'::jsonb),
    'phase',d.phase_key,'dueAt',w.due_at,'dueOn',w.due_on,'originalDueAt',w.original_due_at,'originalDueOn',w.original_due_on,
    'overdue',coalesce(w.due_at<statement_timestamp(),w.due_on<(statement_timestamp() at time zone 'Asia/Manila')::date,false),
    'blocked',d.is_blocked,'blocker',d.safe_blocker_summary,
    'readiness',case when d.is_blocked then 'blocked_provisional' else 'pending_gate_verification' end,
    'nextAction',case when not exists(select 1 from public.members m join public.term_memberships tm on tm.member_id=m.id and tm.term_id=w.term_id
      where m.id=w.owner_member_id and m.account_state='active' and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp())
      then 'Confirm a new accountable owner.' when d.is_blocked then 'Ask the owner to resolve the recorded blocker.' else 'Confirm acceptance criteria and required reviews with the owner.' end,
    'gates',jsonb_build_object('finance','pending_assessment','publicity','pending_assessment','acceptance','pending_definition'),
    'updatedAt',greatest(w.updated_at,d.updated_at),'archivedAt',w.archived_at,'version',w.version)
$$;
create function public.list_deliverables(p_term_id uuid,p_phase text default null,p_unit_id uuid default null,p_owner_id uuid default null,
  p_blocked boolean default false,p_overdue boolean default false,p_involves_my_unit boolean default false,p_review_pending boolean default false,
  p_page integer default 1,p_page_size integer default 20) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; begin
  if p_page is null or p_page not between 1 and 10000 or p_page_size is null or p_page_size not between 1 and 50
    or (p_phase is not null and length(p_phase)>80) then raise exception using errcode='22023',message='deliverables_invalid_filter'; end if;
  with base as materialized (
    select w.id,w.owner_member_id,w.owner_display_name,w.lead_unit_id,w.due_at,w.due_on,d.phase_key,d.is_blocked,
      app_private.deliverable_summary(w,d) as summary
    from public.work_items w join public.deliverables d on d.work_item_id=w.id
    where w.term_id=p_term_id and w.archived_at is null and public.can_access_work(w.id,'summary')
  ), filtered as (
    select b.* from base b where (p_phase is null or b.phase_key=p_phase)
      and (p_owner_id is null or b.owner_member_id=p_owner_id)
      and (not coalesce(p_blocked,false) or b.is_blocked)
      and (not coalesce(p_overdue,false) or (b.summary->>'overdue')::boolean)
      and (not coalesce(p_review_pending,false) or b.summary->'gates'->>'acceptance'='pending_definition')
      and (p_unit_id is null or b.lead_unit_id=p_unit_id or exists(select 1 from public.deliverable_units du where du.work_item_id=b.id and du.unit_id=p_unit_id))
      and (not coalesce(p_involves_my_unit,false) or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null
        where um.term_membership_id=public.current_term_membership(p_term_id) and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()
          and (um.unit_id=b.lead_unit_id or exists(select 1 from public.deliverable_units du where du.work_item_id=b.id and du.unit_id=um.unit_id))))
  ), page as (select * from filtered order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id limit p_page_size offset (p_page-1)*p_page_size)
  select jsonb_build_object('items',coalesce((select jsonb_agg(summary order by coalesce(due_at,(due_on+1)::timestamp at time zone 'Asia/Manila') nulls last,id) from page),'[]'::jsonb),
    'total',(select count(*) from filtered),'page',p_page,'pageSize',p_page_size,
    'options',jsonb_build_object(
      'phases',coalesce((select jsonb_agg(phase_key order by phase_key) from(select distinct phase_key from base where phase_key is not null)x),'[]'::jsonb),
      'owners',coalesce((select jsonb_agg(jsonb_build_object('id',owner_member_id,'name',name) order by name,owner_member_id)
        from(select owner_member_id,min(owner_display_name) as name from base group by owner_member_id)x),'[]'::jsonb),
      'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name) order by u.name,u.id) from public.org_units u where u.term_id=p_term_id and exists(
        select 1 from base b where b.lead_unit_id=u.id or exists(select 1 from public.deliverable_units du where du.work_item_id=b.id and du.unit_id=u.id))),'[]'::jsonb)))
  into result;
  return result;
end $$;
create function public.read_deliverable(p_work_item_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select app_private.deliverable_summary(w,d)||jsonb_build_object('details',case when public.can_access_work(w.id,'detail')
    then jsonb_build_object('outcome',d.outcome,'acceptanceCriteria',d.acceptance_criteria,'body',d.body) else null end)
  from public.work_items w join public.deliverables d on d.work_item_id=w.id
  where w.id=p_work_item_id and public.can_access_work(w.id,'summary')
$$;
revoke all on function app_private.deliverable_summary(public.work_items,public.deliverables),
  public.list_deliverables(uuid,text,uuid,uuid,boolean,boolean,boolean,boolean,integer,integer),public.read_deliverable(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.list_deliverables(uuid,text,uuid,uuid,boolean,boolean,boolean,boolean,integer,integer),public.read_deliverable(uuid) to authenticated;
commit;
