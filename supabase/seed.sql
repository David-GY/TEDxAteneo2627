-- FICTIONAL LOCAL FIXTURES ONLY. Run only with the in-memory harness or verified `db reset --local`.
-- This is not the official organization roster, committee structure, or approver authority.
begin;
insert into public.organizations (id, slug, name) values
('11111111-1111-4111-8111-111111111111', 'fictional-local-workspace', 'Fictional local test organization')
on conflict (id) do nothing;

insert into public.terms (id, organization_id, label, event_date, starts_on, closes_on, state) values
('22222222-2222-4222-8222-222222222221', '11111111-1111-4111-8111-111111111111', 'Fictional local term A', '2027-04-17', '2026-10-01', '2027-06-30', 'active'),
('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111', 'Fictional local term B', '2028-04-17', '2027-10-01', '2028-06-30', 'draft')
on conflict (id) do nothing;

insert into public.members (id, organization_id, email, display_name) values
('33333333-3333-4333-8333-333333333331', '11111111-1111-4111-8111-111111111111', 'fictional.alex@example.invalid', 'Fictional Alex'),
('33333333-3333-4333-8333-333333333332', '11111111-1111-4111-8111-111111111111', 'fictional.river@example.invalid', 'Fictional River')
on conflict (id) do nothing;

insert into public.term_memberships (id, organization_id, term_id, member_id, status, joined_at, ends_at, affiliation_tag) values
('66666666-6666-4666-8666-666666666661', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '33333333-3333-4333-8333-333333333331', 'active', '2026-10-01Z', '2027-07-01Z', null),
('66666666-6666-4666-8666-666666666662', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '33333333-3333-4333-8333-333333333332', 'active', '2026-10-01Z', '2027-07-01Z', 'MEAn'),
('66666666-6666-4666-8666-666666666663', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', '33333333-3333-4333-8333-333333333331', 'pending', '2027-10-01Z', '2028-07-01Z', null)
on conflict (id) do nothing;

insert into public.private_profiles (member_id, organization_id) values
('33333333-3333-4333-8333-333333333331', '11111111-1111-4111-8111-111111111111')
on conflict (member_id) do nothing;

insert into public.org_units (id, organization_id, term_id, code, name, delivery_committee, review_service) values
('44444444-4444-4444-8444-444444444441', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', 'LOCAL_DELIVERY', 'Fictional delivery test unit', true, false),
('44444444-4444-4444-8444-444444444442', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', 'LOCAL_DUAL', 'Fictional dual-purpose test unit', true, true),
('44444444-4444-4444-8444-444444444443', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', 'LOCAL_SERVICE', 'Fictional service test unit', false, true),
('44444444-4444-4444-8444-444444444444', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'OTHER_TERM', 'Fictional unit in term B', true, false)
on conflict (id) do nothing;

insert into public.roles (id, organization_id, term_id, code, name, privileged) values
('55555555-5555-4555-8555-555555555551', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', 'local_reader', 'Fictional reader role', false),
('55555555-5555-4555-8555-555555555552', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', 'local_service_reviewer', 'Fictional service review role', true)
on conflict (id) do nothing;

insert into public.role_permissions (id, organization_id, term_id, role_id, capability, allowed_scope) values
('88888888-8888-4888-8888-888888888881', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '55555555-5555-4555-8555-555555555551', 'workspace.read', 'term'),
('88888888-8888-4888-8888-888888888882', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '55555555-5555-4555-8555-555555555551', 'directory.read', 'term'),
('88888888-8888-4888-8888-888888888883', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '55555555-5555-4555-8555-555555555552', 'department.review', 'unit')
on conflict (id) do nothing;

insert into public.unit_memberships (id, organization_id, term_id, term_membership_id, unit_id, deployment_type, effective_from, effective_to, approved_by) values
('99999999-9999-4999-8999-999999999991', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '66666666-6666-4666-8666-666666666661', '44444444-4444-4444-8444-444444444441', 'member', '2026-10-01Z', '2027-07-01Z', '66666666-6666-4666-8666-666666666662'),
('99999999-9999-4999-8999-999999999992', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '66666666-6666-4666-8666-666666666662', '44444444-4444-4444-8444-444444444442', 'head', '2026-10-01Z', '2027-07-01Z', '66666666-6666-4666-8666-666666666661')
on conflict (id) do nothing;

insert into public.role_assignments (id, organization_id, term_id, term_membership_id, role_id, scope_type, unit_id, effective_from, effective_to, granted_by) values
('77777777-7777-4777-8777-777777777771', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '66666666-6666-4666-8666-666666666661', '55555555-5555-4555-8555-555555555551', 'term', null, '2026-10-01Z', '2027-07-01Z', '66666666-6666-4666-8666-666666666662'),
('77777777-7777-4777-8777-777777777772', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222221', '66666666-6666-4666-8666-666666666662', '55555555-5555-4555-8555-555555555552', 'unit', '44444444-4444-4444-8444-444444444442', '2026-10-01Z', '2027-07-01Z', '66666666-6666-4666-8666-666666666661')
on conflict (id) do nothing;
commit;

-- P08 fictional shared output. Guard preserves historical P02–P07 harness boundaries.
do $$
declare org uuid:='11111111-1111-4111-8111-111111111111'; term uuid:='22222222-2222-4222-8222-222222222221';
  item uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'; draft uuid:='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
begin
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name='deliverables' and column_name='outcome') then
    insert into public.status_definitions(id,organization_id,term_id,resource_kind,stable_key,semantic_category,label)
      values(draft,org,term,'deliverable','draft','draft','Draft') on conflict(term_id,resource_kind,stable_key) do nothing;
    select id into draft from public.status_definitions where term_id=term and resource_kind='deliverable' and stable_key='draft';
    insert into public.work_items(id,organization_id,term_id,kind,title,safe_summary,classification,owner_member_id,owner_display_name,lead_unit_id,status_id,due_on,original_due_on)
    values(item,org,term,'deliverable','Fictional speaker reveal package','Synthetic local example: one output involving two fictional units.','ordinary',
      '33333333-3333-4333-8333-333333333331','Fictional Alex','44444444-4444-4444-8444-444444444441',draft,'2027-04-10','2027-04-10') on conflict(id) do nothing;
    insert into public.deliverables(work_item_id,organization_id,term_id,phase_key,outcome,acceptance_criteria,body)
    values(item,org,term,'Fictional preparation','Fictional approved-format speaker announcement package.','Fictional criteria: confirm supplied content, accessible rendition and required reviews.','Synthetic participant-only example; no real speaker or approval evidence.') on conflict(work_item_id) do nothing;
    insert into public.deliverable_units(organization_id,term_id,work_item_id,unit_id)
    values(org,term,item,'44444444-4444-4444-8444-444444444442') on conflict do nothing;
  end if;
end $$;
