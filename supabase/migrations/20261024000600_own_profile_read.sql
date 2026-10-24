begin;

-- The editor reads private values through a distinct owner-only projection.
-- No caller-supplied member ID and no broad directory capability requirement.
create function public.read_own_profile(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'memberId', tm.member_id, 'displayName', m.display_name,
    'version', coalesce(p.version,0),
    'course', p.course, 'yearLevel', p.year_level,
    'phone', p.phone, 'externalContact', p.external_contact,
    'shareCourse', coalesce(p.share_course,false),
    'shareYearLevel', coalesce(p.share_year_level,false),
    'sharePhone', coalesce(p.share_phone,false),
    'shareExternalContact', coalesce(p.share_external_contact,false)
  ) from public.term_memberships tm
  join public.members m on m.id=tm.member_id and m.organization_id=tm.organization_id
  left join public.private_profiles p on p.member_id=tm.member_id and p.organization_id=tm.organization_id
  where tm.id=public.current_term_membership(p_term_id)
    and tm.membership_kind='core'
$$;

revoke all on function public.read_own_profile(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_own_profile(uuid) to authenticated;
commit;
