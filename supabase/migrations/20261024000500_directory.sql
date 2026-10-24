begin;

-- Read projections only: no broader grants on identity or private profile tables.
create function public.read_people_directory(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.member_id, 'name', d.display_name,
    'contact', case when m.normalized_email like '%@student.ateneo.edu' then m.normalized_email end,
    'units', coalesce((select jsonb_agg(x.name order by x.name) from (
      select distinct u.name from public.unit_memberships um
      join public.org_units u on u.id=um.unit_id and u.archived_at is null
      where um.term_membership_id=tm.id and um.status='active'
        and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()
    ) x),'[]'::jsonb),
    'roles', coalesce((select jsonb_agg(x.name order by x.name) from (
      select distinct r.name from public.role_assignments a join public.roles r on r.id=a.role_id
      where a.term_membership_id=tm.id and a.status='active' and r.state='active'
        and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp()
        and (a.unit_id is null or exists(select 1 from public.unit_memberships um
          join public.org_units u on u.id=um.unit_id and u.archived_at is null
          where um.term_membership_id=tm.id and um.unit_id=a.unit_id and um.status='active'
            and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()))
    ) x),'[]'::jsonb),
    'course', case when p.share_course then p.course end,
    'year', case when p.share_year_level then p.year_level end,
    'phone', case when p.share_phone then p.phone end,
    'externalContact', case when p.share_external_contact then p.external_contact end
  ) order by d.display_name,d.member_id),'[]'::jsonb)
  from public.read_directory(p_term_id) d
  join public.members m on m.id=d.member_id
  join public.term_memberships tm on tm.member_id=d.member_id and tm.term_id=p_term_id
  left join public.private_profiles p on p.member_id=d.member_id
$$;

create function public.read_process_contacts(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'name',u.name,
    'primary', coalesce((select jsonb_agg(jsonb_build_object('id',x.member_id,'name',x.display_name) order by x.display_name,x.member_id)
      from (select distinct d.member_id,d.display_name from public.unit_memberships um
        join public.read_directory(p_term_id) d on d.member_id=(select tm.member_id from public.term_memberships tm where tm.id=um.term_membership_id)
        where um.unit_id=u.id and um.deployment_type='primary_contact' and um.status='active'
          and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()) x),'[]'::jsonb),
    'backup', coalesce((select jsonb_agg(jsonb_build_object('id',x.member_id,'name',x.display_name) order by x.display_name,x.member_id)
      from (select distinct d.member_id,d.display_name from public.unit_memberships um
        join public.read_directory(p_term_id) d on d.member_id=(select tm.member_id from public.term_memberships tm where tm.id=um.term_membership_id)
        where um.unit_id=u.id and um.deployment_type='backup_contact' and um.status='active'
          and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()) x),'[]'::jsonb)
  ) order by u.name,u.id),'[]'::jsonb)
  from public.org_units u where u.term_id=p_term_id and u.archived_at is null
    and public.has_capability(p_term_id,'directory.read')
$$;

revoke all on function public.read_people_directory(uuid),public.read_process_contacts(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_people_directory(uuid),public.read_process_contacts(uuid) to authenticated;
commit;
