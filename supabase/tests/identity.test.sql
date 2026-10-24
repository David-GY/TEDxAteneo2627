-- Portable SQL assertions with TAP output, run as local database owner after seed.
-- Temporary grants/policies/fixtures below are rolled back; never deployed as migrations.
begin;
select '1..3' as tap;
create function pg_temp.expect_failure(statement text, expected_state text) returns void
language plpgsql as $$
declare observed text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics observed = returned_sqlstate;
    if observed = expected_state then return; end if;
    raise exception 'Expected SQLSTATE %, got %: %', expected_state, observed, sqlerrm;
  end;
  raise exception 'Expected SQLSTATE %, statement unexpectedly succeeded: %', expected_state, statement;
end;
$$;
grant execute on function pg_temp.expect_failure(text, text) to anon, authenticated;

do $$
begin
  perform pg_temp.expect_failure($q$update public.unit_memberships set unit_id = '44444444-4444-4444-8444-444444444444' where id = '99999999-9999-4999-8999-999999999991'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.unit_memberships set term_membership_id = '66666666-6666-4666-8666-666666666663' where id = '99999999-9999-4999-8999-999999999991'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.unit_memberships set approved_by = '66666666-6666-4666-8666-666666666663' where id = '99999999-9999-4999-8999-999999999991'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.role_assignments set term_membership_id = '66666666-6666-4666-8666-666666666663' where id = '77777777-7777-4777-8777-777777777771'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.role_assignments set unit_id = '44444444-4444-4444-8444-444444444444' where id = '77777777-7777-4777-8777-777777777772'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.role_assignments set granted_by = '66666666-6666-4666-8666-666666666663' where id = '77777777-7777-4777-8777-777777777771'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.roles set term_id = '22222222-2222-4222-8222-222222222222' where id = '55555555-5555-4555-8555-555555555551'$q$, '23503');
  perform pg_temp.expect_failure($q$insert into public.members (organization_id, email, display_name) values ('11111111-1111-4111-8111-111111111111', '  FICTIONAL.ALEX@EXAMPLE.INVALID  ', 'Duplicate fictional identity')$q$, '23505');
  perform pg_temp.expect_failure($q$update public.term_memberships set organization_id = gen_random_uuid() where id = '66666666-6666-4666-8666-666666666661'$q$, '23503');
  perform pg_temp.expect_failure($q$update public.unit_memberships set effective_to = effective_from$q$, '23514');
  perform pg_temp.expect_failure($q$update public.role_assignments set effective_to = effective_from$q$, '23514');
  perform pg_temp.expect_failure($q$update public.role_assignments set scope_type = 'work'$q$, '23514');
  perform pg_temp.expect_failure($q$update public.role_assignments set scope_type = 'unit', unit_id = null$q$, '23514');
  perform pg_temp.expect_failure($q$update public.role_permissions set capability = 'arbitrary.execute'$q$, '23514');
  perform pg_temp.expect_failure($q$update public.role_permissions set allowed_scope = 'term' where capability = 'department.review'$q$, '23514');
  perform pg_temp.expect_failure($q$update public.members set auth_user_id = gen_random_uuid() where id = '33333333-3333-4333-8333-333333333331'$q$, '23503');
end;
$$;
select 'ok 1 - P02_A1: cross-term/organization references, duplicate normalized identities, invalid dates and scopes rejected' as tap;

do $$
declare before_grants jsonb; after_grants jsonb; tag text;
begin
  select jsonb_build_object('assignments', (select jsonb_agg(to_jsonb(a) order by id) from public.role_assignments a),
    'permissions', (select jsonb_agg(to_jsonb(p) order by id) from public.role_permissions p),
    'deployments', (select jsonb_agg(to_jsonb(d) order by id) from public.unit_memberships d)) into before_grants;
  foreach tag in array array['MEAn', 'non-MEAn', null] loop
    update public.term_memberships set affiliation_tag = tag where id = '66666666-6666-4666-8666-666666666661';
    select jsonb_build_object('assignments', (select jsonb_agg(to_jsonb(a) order by id) from public.role_assignments a),
      'permissions', (select jsonb_agg(to_jsonb(p) order by id) from public.role_permissions p),
      'deployments', (select jsonb_agg(to_jsonb(d) order by id) from public.unit_memberships d)) into after_grants;
    if before_grants is distinct from after_grants then raise exception 'Affiliation changed grants'; end if;
  end loop;
  if not exists (select 1 from public.org_units where delivery_committee and review_service) then
    raise exception 'Delivery and service flags cannot coexist';
  end if;
end;
$$;
select 'ok 2 - P02_A2: nullable affiliation changes neither assignments, permissions nor deployments' as tap;

do $$
declare t text; r text;
begin
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r') <> 10 then raise exception 'Expected ten foundation tables'; end if;
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r' loop
    if not (select relrowsecurity and relforcerowsecurity from pg_class where oid = ('public.' || t)::regclass) then
      raise exception 'RLS not enabled/forced: %', t;
    end if;
    if exists (select 1 from pg_policies where schemaname = 'public' and tablename = t) then raise exception 'Unexpected policy: %', t; end if;
    foreach r in array array['anon', 'authenticated', 'service_role'] loop
      if has_table_privilege(r, 'public.' || t, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
        or has_any_column_privilege(r, 'public.' || t, 'SELECT,INSERT,UPDATE,REFERENCES') then
        raise exception 'Unexpected table/column exposure: % %', r, t;
      end if;
    end loop;
  end loop;
  if has_schema_privilege('anon', 'public', 'CREATE') or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Unexpected schema CREATE';
  end if;
  if has_function_privilege('authenticated', 'public.protect_member_identity()', 'EXECUTE')
    or has_function_privilege('anon', 'public.stamp_identity_row()', 'EXECUTE') then raise exception 'Unexpected helper exposure'; end if;
end;
$$;

create table public.p02_acl_probe(id integer);
create function public.p02_acl_probe() returns integer language sql as 'select 1';
do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated', 'service_role'] loop
    if has_table_privilege(r, 'public.p02_acl_probe', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
      or has_function_privilege(r, 'public.p02_acl_probe()', 'EXECUTE') then
      raise exception 'Unsafe default privileges for new objects: %', r;
    end if;
  end loop;
end;
$$;
drop table public.p02_acl_probe;
drop function public.p02_acl_probe();

set local role anon;
do $$
declare t text;
begin
  foreach t in array array['organizations','terms','members','term_memberships','private_profiles',
      'org_units','unit_memberships','roles','role_permissions','role_assignments'] loop
    perform pg_temp.expect_failure(format('select * from public.%I', t), '42501');
  end loop;
end;
$$;
reset role;

-- Prove RLS itself still denies rows even if a later migration accidentally grants SELECT.
grant select on all tables in schema public to authenticated;
grant insert on public.organizations to authenticated;
set local role authenticated;
do $$
declare t text; visible_rows bigint;
begin
  foreach t in array array['organizations','terms','members','term_memberships','private_profiles',
      'org_units','unit_memberships','roles','role_permissions','role_assignments'] loop
    execute format('select count(*) from public.%I', t) into visible_rows;
    if visible_rows <> 0 then raise exception 'RLS leak: %', t; end if;
  end loop;
  perform pg_temp.expect_failure($q$insert into public.organizations(slug, name) values ('untrusted', 'Untrusted')$q$, '42501');
end;
$$;
reset role;

-- A deliberately permissive temporary policy must not allow identity reassignment.
insert into auth.users(id) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
do $$ begin
  perform set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', true);
  perform set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}', true);
end; $$;
grant insert, update on public.members to authenticated;
create policy test_only_member_identity on public.members for all to authenticated using (true) with check (true);
create policy test_only_org_stamp on public.organizations for all to authenticated using (true) with check (true);
set local role authenticated;
do $$
begin
  perform pg_temp.expect_failure($q$insert into public.members(organization_id, email, display_name) values ('11111111-1111-4111-8111-111111111111', 'untrusted@example.invalid', 'Untrusted roster insert')$q$, '42501');
  perform pg_temp.expect_failure($q$update public.members set auth_user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' where id = '33333333-3333-4333-8333-333333333331'$q$, '42501');
  perform pg_temp.expect_failure($q$update public.members set email = 'changed@example.invalid' where id = '33333333-3333-4333-8333-333333333331'$q$, '42501');
  update public.members set display_name = 'Fictional changed label', created_by = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', updated_by = null, version = 900
    where id = '33333333-3333-4333-8333-333333333331';
  if not exists (select 1 from public.members where id = '33333333-3333-4333-8333-333333333331'
      and created_by is null and updated_by = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and version = 2) then
    raise exception 'Actor/version stamp accepted caller identity';
  end if;
  insert into public.organizations(slug, name, created_by, updated_by, version, created_at)
    values ('test-only-stamp', 'Temporary stamp test', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', null, 900, '2000-01-01Z');
  if not exists (select 1 from public.organizations where slug = 'test-only-stamp'
      and created_by = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and updated_by = created_by
      and version = 1 and created_at > '2000-01-01Z') then
    raise exception 'Insert stamp accepted caller identity/timestamp/version';
  end if;
end;
$$;
reset role;
select 'ok 3 - P02_A3: fresh seed present, grants/RLS deny access, identity linkage and stamps server controlled' as tap;
rollback;
