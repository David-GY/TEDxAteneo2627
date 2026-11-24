-- P39 consumer of source049 publications. No drafts, history or record data.
create function public.read_my_site_presentation(p_term_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare guest boolean:=false; v public.presentation_versions; definition jsonb;
begin
 if public.current_term_membership(p_term_id) is not null and public.has_capability(p_term_id,'workspace.read') then
  perform app_private.request_actor(p_term_id);
 elsif app_private.current_guest_invitation(p_term_id) is not null and exists(
  select 1 from public.terms t join public.organizations o on o.id=t.organization_id
  where t.id=p_term_id and o.state='active' and t.state in('active','frozen')
   and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
 ) then guest:=true;
 else raise exception using errcode='42501',message='command_permission_denied';end if;
 select pv.* into v from public.presentation_versions pv join public.presentation_controls c on c.work_item_id=pv.control_id
 where c.term_id=p_term_id and c.kind='site' and c.target_kind='term' and c.target_id=p_term_id
 order by pv.version desc limit 1;
 if not found then return jsonb_build_object('version',0,'definition',null,'repaired',false);end if;
 begin
  perform app_private.validate_presentation('site',v.definition);
 exception when invalid_parameter_value then
  return jsonb_build_object('version',v.version,'definition',null,'repaired',true);
 end;
 definition:=v.definition;
 -- Common text is intentionally shared guidance. Route-bearing content and wording
 -- are projected to the guest catalog; this never creates a work-item grant.
 if guest then
  definition:=definition||jsonb_build_object(
   'labels',coalesce((select jsonb_object_agg(key,value) from jsonb_each(definition->'labels') where key in('tasks','calendar','resources')),'{}'::jsonb),
   'order',coalesce((select jsonb_agg(value order by ord) from jsonb_array_elements(definition->'order')with ordinality a(value,ord) where value#>>'{}' in('tasks','calendar','resources')),'[]'::jsonb),
   'blocks',coalesce((select jsonb_agg(value order by ord) from jsonb_array_elements(definition->'blocks')with ordinality a(value,ord) where value->>'kind'='text' or value->>'href' in('/tasks','/calendar','/resources')),'[]'::jsonb)
  );
 end if;
 return jsonb_build_object('version',v.version,'definition',definition,'repaired',false);
end$$;
revoke all on function public.read_my_site_presentation(uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_my_site_presentation(uuid) to authenticated;
