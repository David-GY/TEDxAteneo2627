-- P34 publication: immutable role snapshots, explicit provenance and two-party app custody.
create table public.access_control(term_id uuid primary key references public.terms(id),work_item_id uuid not null unique references public.announcements(work_item_id));
create table public.access_role_versions(
 role_id uuid primary key references public.roles(id),term_id uuid not null references public.terms(id),family_id uuid not null,revision integer not null check(revision>0),
 scope_type text not null check(scope_type in('own','unit','term','work')),unit_id uuid references public.org_units(id),work_id uuid references public.work_items(id),
 publisher_id uuid not null references public.term_memberships(id),published_at timestamptz not null default statement_timestamp(),unique(term_id,family_id,revision),
 check((scope_type='unit')=(unit_id is not null)),check((scope_type='work')=(work_id is not null))
);
create table public.access_assignment_sources(
 assignment_id uuid not null references public.role_assignments(id),capability text not null,ceiling_id uuid not null references public.delegation_ceilings(id),
 source_assignment_id uuid not null references public.role_assignments(id),source_assignment_version integer not null,source_role_version integer not null,
 primary key(assignment_id,capability),check(assignment_id<>source_assignment_id)
);
create index access_assignment_sources_source on public.access_assignment_sources(source_assignment_id);
create table public.access_custody_nominations(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),assignment_id uuid not null references public.role_assignments(id),assignment_version integer not null,role_version integer not null,
 nominated_by uuid not null references public.term_memberships(id),nominator_assignment_id uuid not null references public.role_assignments(id),nominator_assignment_version integer not null,
 reference text not null check(length(btrim(reference))between 1 and 1000),created_at timestamptz not null default statement_timestamp(),expires_at timestamptz not null,
 accepted_at timestamptz,acknowledgment text,check(created_at<expires_at)
);
alter table public.verified_app_custodians add column independent_root boolean not null default false;
create table public.access_changes(
 control_id uuid not null references public.access_control(work_item_id),version integer not null,action text not null,target_id uuid not null,actor_id uuid not null references auth.users(id),
 reason text not null,created_at timestamptz not null default statement_timestamp(),primary key(control_id,version)
);
do $$declare t text;begin foreach t in array array['access_control','access_role_versions','access_assignment_sources','access_custody_nominations','access_changes']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;end$$;

create function app_private.access_base_live(p_assignment uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id join public.members m on m.id=tm.member_id join public.terms t on t.id=a.term_id join public.organizations o on o.id=tm.organization_id
 where a.id=p_assignment and a.term_id=tm.term_id and r.term_id=a.term_id and r.state='active'and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()
 and tm.membership_kind='core'and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and m.account_state='active'and app_private.is_school_identity(m.auth_user_id)and app_private.verified_google_email(m.auth_user_id)=m.normalized_email
 and t.state in('active','frozen')and o.state='active'and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and(a.scope_type<>'unit'or exists(select 1 from public.unit_memberships d join public.org_units u on u.id=d.unit_id where d.term_membership_id=tm.id and d.unit_id=a.unit_id and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()and u.archived_at is null))
 and(a.scope_type<>'work'or exists(select 1 from public.work_items w where w.id=a.work_id and w.term_id=a.term_id and w.archived_at is null)))
$$;
create function app_private.access_custody_root(p_assignment uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.verified_app_custodians v join public.role_assignments a on a.id=v.assignment_id join public.roles r on r.id=a.role_id
 where v.assignment_id=p_assignment and v.independent_root and v.assignment_version=a.version and v.role_version=r.version and v.revoked_at is null and v.verified_at<=statement_timestamp()and v.effective_to>statement_timestamp()and a.scope_type='term'and app_private.access_base_live(a.id)
 and v.verified_by<>a.term_membership_id and exists(select 1 from public.term_memberships verifier where verifier.id=v.verified_by and verifier.term_id=a.term_id)
 and(select count(*)from public.role_permissions rp where rp.role_id=a.role_id)=2
 and not exists(select 1 from unnest(array['admin.configure','roles.manage'])cap where not exists(select 1 from public.role_permissions rp where rp.role_id=a.role_id and rp.capability=cap and rp.allowed_scope='term')))
$$;
create function app_private.access_lineage_current(p_assignment uuid,p_path uuid[] default '{}')returns boolean language plpgsql stable security definer set search_path='' as $$
declare a public.role_assignments;s record;begin
 if p_assignment=any(p_path)or cardinality(p_path)>=8 or not app_private.access_base_live(p_assignment)then return false;end if;
 select *into a from public.role_assignments where id=p_assignment;
 if app_private.access_custody_root(a.id)then return true;end if;
 if not exists(select 1 from public.access_assignment_sources where assignment_id=a.id)then return not exists(select 1 from public.access_role_versions where role_id=a.role_id);end if;
 for s in select p.capability,src.ceiling_id,src.source_assignment_id,src.source_assignment_version,src.source_role_version from public.role_permissions p left join public.access_assignment_sources src on src.assignment_id=a.id and src.capability=p.capability where p.role_id=a.role_id and p.allowed_scope=a.scope_type loop
  if s.ceiling_id is null or not exists(select 1 from public.delegation_ceilings c join public.role_assignments source on source.id=c.source_assignment_id join public.roles r on r.id=source.role_id join public.term_memberships grantor on grantor.id=source.term_membership_id
   where c.id=s.ceiling_id and c.term_id=a.term_id and c.grantor_membership_id=a.granted_by and source.term_membership_id=a.granted_by and source.id=s.source_assignment_id and source.version=s.source_assignment_version and r.version=s.source_role_version
   and c.source_assignment_version=source.version and c.source_role_version=r.version and c.capability=s.capability and c.scope_type=a.scope_type and c.unit_id is not distinct from a.unit_id and c.work_id is not distinct from a.work_id
   and c.revoked_at is null and c.starts_at<=statement_timestamp()and c.ends_at>statement_timestamp()and a.effective_from>=c.starts_at and a.effective_to<=c.ends_at and a.effective_to<=source.effective_to and a.effective_to<=grantor.ends_at
   and(c.capability not in('finance.review','feedback.review','mcd.review','roles.manage','admin.configure')or c.sensitive_authorized)
   and exists(select 1 from public.role_permissions rp where rp.role_id=source.role_id and rp.capability=c.capability and rp.allowed_scope=source.scope_type)
   and exists(select 1 from public.term_memberships verifier join public.members vm on vm.id=verifier.member_id where verifier.id=c.approved_by and verifier.term_id=a.term_id and verifier.membership_kind='core'and verifier.status='active'and verifier.ends_at>statement_timestamp()and vm.account_state='active')
  )or not app_private.access_lineage_current(s.source_assignment_id,p_path||p_assignment)then return false;end if;
 end loop;
 return exists(select 1 from public.role_permissions where role_id=a.role_id and allowed_scope=a.scope_type);
end$$;
-- Internal filtered relation. Every authority consumer listed below reads this relation;
-- locking/fingerprint code retains the raw table so invalid rows still invalidate snapshots.
create view app_private.effective_role_assignments as select a.*from public.role_assignments a where app_private.access_lineage_current(a.id);
revoke all on app_private.effective_role_assignments from public,anon,authenticated,service_role;

create function app_private.access_ceiling_for(p_term uuid,p_cap text,p_scope text,p_unit uuid,p_work uuid,p_from timestamptz,p_to timestamptz)returns uuid language sql stable security definer set search_path='' as $$
 select c.id from public.delegation_ceilings c where c.term_id=p_term and c.grantor_membership_id=public.current_term_membership(p_term)and c.capability=p_cap and c.scope_type=p_scope and c.unit_id is not distinct from p_unit and c.work_id is not distinct from p_work
 and app_private.access_ceiling_live(c)and app_private.access_lineage_current(c.source_assignment_id)and(c.capability not in('finance.review','feedback.review','mcd.review','roles.manage','admin.configure')or c.sensitive_authorized)
 and c.starts_at<=p_from and c.ends_at>=p_to and exists(select 1 from public.role_assignments a join public.term_memberships m on m.id=a.term_membership_id where a.id=c.source_assignment_id and a.effective_to>=p_to and m.ends_at>=p_to)
 order by c.id limit 1
$$;
create function app_private.access_fingerprint(p_term uuid,p_action text,p_values jsonb)returns text language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_array(p_term,p_action,p_values,
 (select jsonb_agg(to_jsonb(a)order by a.id)from public.role_assignments a where a.term_id=p_term),
 (select jsonb_agg(jsonb_build_array(r.id,r.version,r.state)order by r.id)from public.roles r where r.term_id=p_term),
 (select jsonb_agg(to_jsonb(c)order by c.id)from public.delegation_ceilings c where c.term_id=p_term),
 (select jsonb_agg(to_jsonb(v)order by v.assignment_id)from public.verified_app_custodians v join public.role_assignments a on a.id=v.assignment_id where a.term_id=p_term),
 (select jsonb_agg(jsonb_build_array(tm.id,tm.version,m.version)order by tm.id)from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=p_term),
 (select jsonb_agg(jsonb_build_array(d.id,d.version)order by d.id)from public.unit_memberships d where d.term_id=p_term),
 (select jsonb_agg(to_jsonb(n)order by n.id)from public.access_custody_nominations n where n.term_id=p_term),
 (select state from public.terms where id=p_term))::text,'UTF8')),'hex')
$$;
create function app_private.access_validate_change(p_term uuid,p_action text,p_values jsonb)returns void language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;a public.role_assignments;r public.roles;rv public.access_role_versions;n public.access_custody_nominations;target uuid;scope text;unit uuid;work uuid;starts timestamptz;ends timestamptz;perm jsonb;perms jsonb;family uuid;begin
 m:=app_private.access_editor(p_term);
 if not exists(select 1 from public.terms where id=p_term and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_action='role_publish'then
  if not app_private.definition_keys(p_values,array['familyId','expectedRoleVersion','name','permissions','scope','unitId','workId'])or not app_private.definition_text(p_values->'name',200)or jsonb_typeof(p_values->'permissions')is distinct from 'array'or jsonb_array_length(p_values->'permissions')not between 1 and 20 then raise exception using errcode='22023',message='command_validation_failed';end if;
  perms:=p_values->'permissions';scope:=p_values->>'scope';unit:=nullif(p_values->>'unitId','')::uuid;work:=nullif(p_values->>'workId','')::uuid;starts:=statement_timestamp();ends:=starts+interval'1 second';family:=nullif(p_values->>'familyId','')::uuid;
  if family is not null then select *into rv from public.access_role_versions where term_id=p_term and family_id=family order by revision desc limit 1;
   if rv.role_id is null or rv.publisher_id<>m.id or rv.scope_type<>scope or rv.unit_id is distinct from unit or rv.work_id is distinct from work then raise exception using errcode='42501',message='command_permission_denied';end if;
   if rv.revision is distinct from(p_values->>'expectedRoleVersion')::integer then raise exception using errcode='40001',message='command_stale_version';end if;end if;
 elsif p_action='assignment_grant'then
  if not app_private.definition_keys(p_values,array['roleId','targetMembershipId','scope','unitId','workId','from','to'])then raise exception using errcode='22023',message='command_validation_failed';end if;
  select *into r from public.roles where id=(p_values->>'roleId')::uuid and term_id=p_term and state='active';if r.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
  target:=(p_values->>'targetMembershipId')::uuid;scope:=p_values->>'scope';unit:=nullif(p_values->>'unitId','')::uuid;work:=nullif(p_values->>'workId','')::uuid;starts:=(p_values->>'from')::timestamptz;ends:=(p_values->>'to')::timestamptz;
  if exists(select 1 from public.access_role_versions v where v.role_id=r.id and(v.scope_type<>scope or v.unit_id is distinct from unit or v.work_id is distinct from work))then raise exception using errcode='42501',message='command_permission_denied';end if;
 elsif p_action in('assignment_revoke','assignment_expiry')then
  if not app_private.definition_keys(p_values,array['assignmentId','assignmentVersion','to'])then raise exception using errcode='22023',message='command_validation_failed';end if;
  select *into a from public.role_assignments where id=(p_values->>'assignmentId')::uuid and term_id=p_term;if a.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
  if a.version is distinct from(p_values->>'assignmentVersion')::integer then raise exception using errcode='40001',message='command_stale_version';end if;
  select *into r from public.roles where id=a.role_id;target:=a.term_membership_id;scope:=a.scope_type;unit:=a.unit_id;work:=a.work_id;starts:=a.effective_from;ends:=case when p_action='assignment_expiry'then(p_values->>'to')::timestamptz else least(a.effective_to,statement_timestamp()+interval'1 second')end;
  -- A dependent replacement does not count; only independent acknowledged custody survives removal.
  if exists(select 1 from public.role_permissions where role_id=a.role_id and capability in('admin.configure','roles.manage'))and not exists(select 1 from public.role_assignments other where other.term_id=p_term and other.term_membership_id<>target and app_private.access_custody_root(other.id))then raise exception using errcode='42501',message='command_verified_replacement_required';end if;
 elsif p_action in('custodian_nominate','custodian_accept')then
  if not app_private.definition_keys(p_values,array['assignmentId','assignmentVersion','nominationId','reference'])or not app_private.definition_text(p_values->'reference',1000)then raise exception using errcode='22023',message='command_validation_failed';end if;
  if p_action='custodian_accept'then
   select *into n from public.access_custody_nominations where id=(p_values->>'nominationId')::uuid and term_id=p_term and accepted_at is null and expires_at>statement_timestamp();
   if n.id is null or n.nominated_by=m.id or not app_private.access_verified_custodian(n.nominator_assignment_id)or not exists(select 1 from public.role_assignments s where s.id=n.nominator_assignment_id and s.version=n.nominator_assignment_version)then raise exception using errcode='42501',message='command_permission_denied';end if;
   select *into a from public.role_assignments where id=n.assignment_id and term_id=p_term and term_membership_id=m.id and version=n.assignment_version;
   if a.id is null or (select version from public.roles where id=a.role_id)<>n.role_version then raise exception using errcode='40001',message='command_stale_version';end if;
  else
   select *into a from public.role_assignments where id=(p_values->>'assignmentId')::uuid and term_id=p_term and version=(p_values->>'assignmentVersion')::integer;
   if a.id is null or a.term_membership_id=m.id or not exists(select 1 from public.role_assignments mine where mine.term_id=p_term and mine.term_membership_id=m.id and app_private.access_verified_custodian(mine.id))then raise exception using errcode='42501',message='command_permission_denied';end if;
  end if;
  if a.scope_type<>'term'or not app_private.access_lineage_current(a.id)or(select count(*)from public.role_permissions where role_id=a.role_id)<>2 or exists(select 1 from unnest(array['admin.configure','roles.manage'])cap where not exists(select 1 from public.role_permissions where role_id=a.role_id and capability=cap and allowed_scope='term'))then raise exception using errcode='42501',message='command_permission_denied';end if;
  return;
 else raise exception using errcode='22023',message='command_validation_failed';end if;
 if scope is null or scope not in('own','unit','work','term')or(scope='unit')is distinct from(unit is not null)or(scope='work')is distinct from(work is not null)or starts is null or ends is null or not isfinite(starts)or not isfinite(ends)or starts>=ends then raise exception using errcode='22023',message='command_validation_failed';end if;
 if unit is not null and not exists(select 1 from public.org_units where id=unit and term_id=p_term and archived_at is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 if work is not null and not exists(select 1 from public.work_items where id=work and term_id=p_term and archived_at is null and public.can_access_work(id,'detail'))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_action<>'role_publish'then
  if target is null or target=m.id or not exists(select 1 from public.term_memberships tm join public.members member on member.id=tm.member_id where tm.id=target and tm.term_id=p_term and tm.membership_kind='core'and tm.status='active'and member.account_state='active'and tm.joined_at<=starts and tm.ends_at>=ends and tm.ends_at>statement_timestamp())then raise exception using errcode='42501',message='command_permission_denied';end if;
  if scope='unit'and not exists(select 1 from public.unit_memberships where term_membership_id=target and unit_id=unit and status='active'and effective_from<=starts and effective_to>=ends)then raise exception using errcode='42501',message='command_permission_denied';end if;
  select jsonb_agg(jsonb_build_object('capability',capability,'scope',allowed_scope))into perms from public.role_permissions where role_id=r.id and allowed_scope=scope;
 end if;
 if perms is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 if(select count(*)from jsonb_array_elements(perms))<>(select count(distinct value->>'capability')from jsonb_array_elements(perms))then raise exception using errcode='22023',message='command_validation_failed';end if;
 for perm in select value from jsonb_array_elements(perms)loop
  if not app_private.definition_keys(perm,array['capability','scope'])or(perm->>'scope')is distinct from scope or not exists(select 1 from jsonb_array_elements(app_private.access_catalog())entry where entry->>'capability'=perm->>'capability'and(entry->'scopes')?scope)then raise exception using errcode='22023',message='command_validation_failed';end if;
  if app_private.access_ceiling_for(p_term,perm->>'capability',scope,unit,work,greatest(starts,statement_timestamp()),ends)is null then raise exception using errcode='42501',message='command_current_grantor_ceiling_required';end if;
 end loop;
end$$;

create function public.preview_access_change(p_term_id uuid,p_action text,p_values jsonb)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;v integer;begin m:=app_private.access_editor(p_term_id);perform app_private.access_validate_change(p_term_id,p_action,p_values);
 select w.version into v from public.access_control c join public.work_items w on w.id=c.work_item_id where c.term_id=p_term_id;
 return jsonb_build_object('version',coalesce(v,0),'fingerprint',app_private.access_fingerprint(p_term_id,p_action,p_values),'action',p_action,'values',p_values,'notice','Review this exact change. Existing role assignments keep their immutable permission snapshot. No authority changes until explicit publication.');end$$;
create function public.publish_access_change(p_term_id uuid,p_action text,p_values jsonb,p_expected_version integer,p_fingerprint text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;w public.work_items;control uuid;status_id_value uuid;v integer;payload jsonb;result jsonb;target uuid;family uuid;revision integer;perm jsonb;ceiling public.delegation_ceilings;a public.role_assignments;n public.access_custody_nominations;source public.role_assignments;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.access_editor(p_term_id);
 if not exists(select 1 from public.terms where id=p_term_id and state='active')or p_expected_version is null or not app_private.definition_text(to_jsonb(p_reason),1000)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_action,p_values,p_expected_version,p_fingerprint,p_reason);result:=app_private.begin_work_command('publish_access_change',p_request_id,payload);if result is not null then return result;end if;
 perform 1 from public.role_assignments where term_id=p_term_id order by id for update;
 perform 1 from public.roles where term_id=p_term_id order by id for update;
 perform 1 from public.term_memberships where term_id=p_term_id order by id for update;
 perform 1 from public.unit_memberships where term_id=p_term_id order by id for update;
 perform 1 from public.delegation_ceilings where term_id=p_term_id order by id for update;
 select work_item_id into control from public.access_control where term_id=p_term_id;
 select version into v from public.work_items where id=control;
 if coalesce(v,0)<>p_expected_version or p_fingerprint is distinct from app_private.access_fingerprint(p_term_id,p_action,p_values)then raise exception using errcode='40001',message='command_stale_version';end if;
 perform app_private.access_validate_change(p_term_id,p_action,p_values);
 if control is null then
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,p_term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select id into status_id_value from public.status_definitions where term_id=p_term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)values(m.organization_id,p_term_id,'announcement','Access control','restricted',m.member_id,(select display_name from public.members where id=m.member_id),status_id_value)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);insert into public.access_control values(p_term_id,w.id);
 else update public.work_items set updated_at=statement_timestamp()where id=control returning *into w;end if;
 if p_action='role_publish'then
  target:=gen_random_uuid();family:=coalesce(nullif(p_values->>'familyId','')::uuid,gen_random_uuid());revision:=coalesce((select max(rev.revision)from public.access_role_versions rev where rev.term_id=p_term_id and rev.family_id=family),0)+1;
  insert into public.roles(id,organization_id,term_id,code,name,privileged)values(target,m.organization_id,p_term_id,'custom_'||replace(target::text,'-',''),btrim(p_values->>'name'),exists(select 1 from jsonb_array_elements(p_values->'permissions')p where p->>'capability'in('finance.review','mcd.review','feedback.review','roles.manage','admin.configure')));
  for perm in select value from jsonb_array_elements(p_values->'permissions')loop insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)values(m.organization_id,p_term_id,target,perm->>'capability',perm->>'scope');end loop;
  insert into public.access_role_versions values(target,p_term_id,family,revision,p_values->>'scope',nullif(p_values->>'unitId','')::uuid,nullif(p_values->>'workId','')::uuid,m.id,statement_timestamp());
  result:=jsonb_build_object('familyId',family,'roleVersion',revision);
 elsif p_action='assignment_grant'then
  insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,work_id,effective_from,effective_to,granted_by)values(m.organization_id,p_term_id,(p_values->>'targetMembershipId')::uuid,(p_values->>'roleId')::uuid,p_values->>'scope',nullif(p_values->>'unitId','')::uuid,nullif(p_values->>'workId','')::uuid,(p_values->>'from')::timestamptz,(p_values->>'to')::timestamptz,m.id)returning *into a;target:=a.id;
  for perm in select jsonb_build_object('capability',capability)from public.role_permissions where role_id=a.role_id and allowed_scope=a.scope_type loop
   select *into ceiling from public.delegation_ceilings where id=app_private.access_ceiling_for(p_term_id,perm->>'capability',a.scope_type,a.unit_id,a.work_id,greatest(a.effective_from,statement_timestamp()),a.effective_to);
   insert into public.access_assignment_sources values(a.id,perm->>'capability',ceiling.id,ceiling.source_assignment_id,ceiling.source_assignment_version,ceiling.source_role_version);end loop;
  result:=jsonb_build_object('assignmentVersion',a.version);
 elsif p_action in('assignment_revoke','assignment_expiry')then
  update public.role_assignments set status=case when p_action='assignment_revoke'then 'revoked'else status end,effective_to=case when p_action='assignment_expiry'then(p_values->>'to')::timestamptz else effective_to end where id=(p_values->>'assignmentId')::uuid returning *into a;target:=a.id;result:=jsonb_build_object('assignmentVersion',a.version);
 elsif p_action='custodian_nominate'then
  select *into a from public.role_assignments where id=(p_values->>'assignmentId')::uuid;
  select *into source from public.role_assignments where term_id=p_term_id and term_membership_id=m.id and app_private.access_verified_custodian(id)order by id limit 1;
  insert into public.access_custody_nominations(term_id,assignment_id,assignment_version,role_version,nominated_by,nominator_assignment_id,nominator_assignment_version,reference,expires_at)values(p_term_id,a.id,a.version,(select version from public.roles where id=a.role_id),m.id,source.id,source.version,btrim(p_values->>'reference'),least(a.effective_to,source.effective_to,statement_timestamp()+interval'1 day'))returning id into target;
 else
  select *into n from public.access_custody_nominations where id=(p_values->>'nominationId')::uuid;select *into a from public.role_assignments where id=n.assignment_id;
  update public.access_custody_nominations set accepted_at=statement_timestamp(),acknowledgment=btrim(p_values->>'reference')where id=n.id;
  insert into public.verified_app_custodians(assignment_id,assignment_version,role_version,verified_by,verification_reference,verified_at,effective_to,independent_root)values(a.id,a.version,n.role_version,n.nominated_by,n.reference,statement_timestamp(),a.effective_to,true)
   on conflict(assignment_id)do update set assignment_version=excluded.assignment_version,role_version=excluded.role_version,verified_by=excluded.verified_by,verification_reference=excluded.verification_reference,verified_at=excluded.verified_at,effective_to=excluded.effective_to,revoked_at=null,independent_root=true;
  for perm in select jsonb_build_object('capability',cap)from unnest(array['admin.configure','roles.manage'])cap loop
   insert into public.delegation_ceilings(term_id,grantor_membership_id,source_assignment_id,source_assignment_version,source_role_version,capability,scope_type,sensitive_authorized,starts_at,ends_at,approved_by,approval_reference)values(p_term_id,a.term_membership_id,a.id,a.version,n.role_version,perm->>'capability','term',true,statement_timestamp(),a.effective_to,n.nominated_by,n.reference);end loop;
  target:=a.id;result:=jsonb_build_object('applicationCustodyConfirmed',true,'providerConsoleOwnershipVerified',false);
 end if;
 insert into public.access_changes values(w.id,w.version,p_action,target,auth.uid(),btrim(p_reason),statement_timestamp());
 return app_private.finish_work_command(w,'publish_access_change',p_request_id,payload,coalesce(result,'{}')||jsonb_build_object('id',target,'version',w.version),'["access_administration"]');
end$$;

create function app_private.access_immutable_role()returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.access_role_versions where role_id in(case when tg_table_name='roles'then(to_jsonb(old)->>'id')::uuid else(to_jsonb(old)->>'role_id')::uuid end,case when tg_table_name='roles'then(to_jsonb(new)->>'id')::uuid else(to_jsonb(new)->>'role_id')::uuid end))then raise exception using errcode='55000',message='command_published_immutable';end if;return case when tg_op='DELETE'then old else new end;end$$;
create trigger access_role_immutable before update or delete on public.roles for each row execute function app_private.access_immutable_role();
create trigger access_permissions_immutable before insert or update or delete on public.role_permissions for each row execute function app_private.access_immutable_role();
create function app_private.access_immutable_history()returns trigger language plpgsql set search_path='' as $$begin raise exception using errcode='55000',message='command_published_immutable';end$$;
create trigger access_role_versions_immutable before update or delete on public.access_role_versions for each row execute function app_private.access_immutable_history();
create trigger access_changes_immutable before update or delete on public.access_changes for each row execute function app_private.access_immutable_history();
create trigger access_sources_immutable before update or delete on public.access_assignment_sources for each row execute function app_private.access_immutable_history();

revoke all on function app_private.access_base_live(uuid),app_private.access_custody_root(uuid),app_private.access_lineage_current(uuid,uuid[]),app_private.access_ceiling_for(uuid,text,text,uuid,uuid,timestamptz,timestamptz),app_private.access_fingerprint(uuid,text,jsonb),app_private.access_validate_change(uuid,text,jsonb),app_private.access_immutable_role(),app_private.access_immutable_history()from public,anon,authenticated,service_role;
revoke all on function public.preview_access_change(uuid,text,jsonb),public.publish_access_change(uuid,text,jsonb,integer,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.preview_access_change(uuid,text,jsonb),public.publish_access_change(uuid,text,jsonb,integer,text,text,uuid)to authenticated;

-- AUTHORITY_CONSUMERS: generated from explicit inventory; 29 current readers, four raw lock/fingerprint exceptions.
-- app_private.access_assignment_live uses current delegation lineage.
create or replace function app_private.access_assignment_live(p_assignment uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from app_private.effective_role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id join public.members m on m.id=tm.member_id join public.terms t on t.id=tm.term_id join public.organizations o on o.id=tm.organization_id where a.id=p_assignment and a.term_id=tm.term_id and r.term_id=a.term_id and r.state='active'and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()and tm.membership_kind='core'and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and m.account_state='active'and t.state in('active','frozen')and o.state='active'and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on and(a.scope_type<>'unit'or exists(select 1 from public.unit_memberships d join public.org_units u on u.id=d.unit_id where d.term_membership_id=tm.id and d.unit_id=a.unit_id and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()and u.archived_at is null))and(a.scope_type<>'work'or exists(select 1 from public.work_items w where w.id=a.work_id and w.term_id=a.term_id and w.archived_at is null)))
$$;

-- app_private.access_ceiling_live uses current delegation lineage.
create or replace function app_private.access_ceiling_live(c public.delegation_ceilings)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships approver where approver.id=c.approved_by and approver.term_id=c.term_id and approver.membership_kind='core')and c.grantor_membership_id=public.current_term_membership(c.term_id)and c.revoked_at is null and c.starts_at<=statement_timestamp()and c.ends_at>statement_timestamp()and exists(select 1 from app_private.effective_role_assignments a join public.roles r on r.id=a.role_id join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope=a.scope_type and p.capability=c.capability where a.id=c.source_assignment_id and a.term_id=c.term_id and a.term_membership_id=c.grantor_membership_id and a.version=c.source_assignment_version and r.version=c.source_role_version and app_private.access_assignment_live(a.id)and(
 (c.scope_type=a.scope_type and c.unit_id is not distinct from a.unit_id and c.work_id is not distinct from a.work_id)or(c.scope_type='work'and c.capability in('workspace.read','committee.manage')and exists(select 1 from public.work_items w where w.id=c.work_id and w.term_id=c.term_id and w.archived_at is null and public.can_access_work(w.id,'detail')and((a.scope_type='term'and c.capability='workspace.read')or(a.scope_type='unit'and w.lead_unit_id=a.unit_id))))))
$$;

-- app_private.access_verified_custodian uses current delegation lineage.
create or replace function app_private.access_verified_custodian(p_assignment uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.verified_app_custodians v join app_private.effective_role_assignments a on a.id=v.assignment_id join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id join public.members m on m.id=tm.member_id where v.assignment_id=p_assignment and a.scope_type='term'and app_private.access_assignment_live(a.id)and v.assignment_version=a.version and v.role_version=r.version and v.revoked_at is null and v.verified_at<=statement_timestamp()and v.effective_to>statement_timestamp()and v.verified_by<>tm.id and exists(select 1 from public.term_memberships verifier where verifier.id=v.verified_by and verifier.term_id=a.term_id and verifier.membership_kind='core')and m.auth_user_id is not null and app_private.verified_google_email(m.auth_user_id)=m.normalized_email and m.normalized_email like '%@student.ateneo.edu'and not exists(select 1 from unnest(array['admin.configure','roles.manage'])cap where not exists(select 1 from public.role_permissions p where p.role_id=r.id and p.capability=cap and p.allowed_scope='term')))
$$;

-- app_private.active_guest_sponsor uses current delegation lineage.
create or replace function app_private.active_guest_sponsor(p_sponsor uuid) returns boolean
language sql stable set search_path='' as $$
  select exists(select 1 from public.term_memberships tm
    join public.members m on m.id=tm.member_id
    join public.terms t on t.id=tm.term_id join public.organizations o on o.id=tm.organization_id
    join app_private.effective_role_assignments a on a.term_membership_id=tm.id
    join public.roles r on r.id=a.role_id
    join public.role_permissions p on p.role_id=r.id and p.capability='roles.manage' and p.allowed_scope='term'
    where tm.id=p_sponsor and tm.membership_kind='core' and tm.status='active'
      and m.account_state='active' and app_private.is_school_identity(m.auth_user_id)
      and m.normalized_email=app_private.verified_google_email(m.auth_user_id)
      and o.state='active' and t.state='active'
      and (statement_timestamp() at time zone 'Asia/Manila')::date between t.starts_on and t.closes_on
      and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
      and a.status='active' and a.scope_type='term' and r.state='active'
      and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp())
$$;

-- app_private.finance_assignment uses current delegation lineage.
create or replace function app_private.finance_assignment(r public.requests,member uuid)returns public.approval_assignments language sql stable security definer set search_path='' as $$
 select a from public.approval_assignments a join public.workflow_instances x on x.id=a.instance_id join public.finance_review_bindings binding on binding.assignment_id=a.id and binding.policy_id=(app_private.finance_policy(r)).id
 where a.request_id=r.work_item_id and a.revision_id=r.current_revision_id and a.reviewer_id=member and a.generation=x.generation and a.stage_key=x.current_stage_key
 and a.expires_at>statement_timestamp()and exists(select 1 from app_private.effective_role_assignments ra where ra.id=a.authority_id and ra.version=a.authority_version)
 and app_private.finance_independent(r,member,a.authority_id)is not null order by a.assigned_at desc limit 1
$$;

-- app_private.finance_independent uses current delegation lineage.
create or replace function app_private.finance_independent(r public.requests,member uuid,authority uuid default null)returns uuid language plpgsql stable security definer set search_path='' as $$
declare role uuid;p public.finance_authorization_policies;person uuid;begin
 p:=app_private.finance_policy(r);select member_id into person from public.term_memberships where id=member and term_id=r.term_id;
 if p.id is null or person is null or person=(select owner_member_id from public.work_items where id=r.work_item_id)or exists(select 1 from public.finance_revisions where request_revision_id=r.current_revision_id and beneficiary_member_id=person)then return null;end if;
 select d.authority_id into role from public.finance_authority_designations d join app_private.effective_role_assignments assigned_role on assigned_role.id=d.authority_id where assigned_role.term_membership_id=member and(authority is null or d.authority_id=authority)and(d.authority_id=p.primary_authority_id or d.alternate_for_id=p.primary_authority_id)and app_private.finance_role(r.term_id,member,r.receiving_unit_id,d.authority_id)is not null order by d.authority_id limit 1;
 return role;
end$$;

-- app_private.finance_policy uses current delegation lineage.
create or replace function app_private.finance_policy(r public.requests)returns public.finance_authorization_policies language sql stable security definer set search_path='' as $$
 select p from public.finance_authorization_policies p join public.workflow_versions v on v.id=p.workflow_version_id join app_private.effective_role_assignments primary_role on primary_role.id=p.primary_authority_id join public.term_memberships confirmer on confirmer.id=p.confirmed_by and confirmer.term_id=p.term_id
 where p.request_type_id=r.request_type_id and p.workflow_version_id=r.workflow_version_id and p.term_id=r.term_id
 and primary_role.term_id=r.term_id and primary_role.unit_id=r.receiving_unit_id and primary_role.organization_id=r.organization_id
 and jsonb_array_length(v.definition_json->'stages'->0->'reviewers')=1 and v.definition_json->'stages'->0->'reviewers'->>0=primary_role.term_membership_id::text
 and p.version=(select max(pp.version)from public.finance_authorization_policies pp where pp.request_type_id=r.request_type_id and pp.workflow_version_id=r.workflow_version_id)
 and p.effective_from<=statement_timestamp()and p.effective_to>statement_timestamp()
 -- Only an explicitly confirmed single FIN decision stage is mapped here. Unsupported routing stays paused.
 and jsonb_array_length(v.definition_json->'stages')=1 and v.definition_json->'stages'->0->>'key'=p.stage_key
 and v.definition_json->'stages'->0->>'review'='one'and v.definition_json->'stages'->0->>'outcome'='approved'
 order by p.version desc limit 1
$$;

-- app_private.finance_role uses current delegation lineage.
create or replace function app_private.finance_role(term uuid,member uuid,unit uuid,authority uuid default null)returns uuid language sql stable security definer set search_path='' as $$
 select a.id from app_private.effective_role_assignments a join public.finance_authority_designations d on d.authority_id=a.id and d.authority_version=a.version
 join public.term_memberships designation_confirmer on designation_confirmer.id=d.confirmed_by and designation_confirmer.term_id=a.term_id and designation_confirmer.organization_id=a.organization_id
 join public.roles role on role.id=a.role_id and role.state='active'join public.role_permissions rp on rp.role_id=role.id and rp.capability='finance.review'and rp.allowed_scope='unit'
 join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id
 join public.terms t on t.id=tm.term_id and t.state='active'join public.organizations o on o.id=t.organization_id and o.state='active'
 join public.org_units u on u.id=a.unit_id and u.archived_at is null and u.review_service
 where a.term_id=term and a.term_membership_id=member and a.unit_id=unit and a.scope_type='unit'and a.status='active'and(authority is null or a.id=authority)
 and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()
 and tm.status='active'and tm.membership_kind='core'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from public.unit_memberships dep where dep.term_membership_id=tm.id and dep.unit_id=unit and dep.status='active'and dep.effective_from<=statement_timestamp()and dep.effective_to>statement_timestamp())
 and exists(select 1 from app_private.effective_role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=tm.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())order by a.id limit 1
$$;

-- app_private.publicity_assignment uses current delegation lineage.
create or replace function app_private.publicity_assignment(r public.requests,member uuid)returns public.approval_assignments language sql stable security definer set search_path='' as $$
 select a from public.approval_assignments a join public.workflow_instances x on x.id=a.instance_id join public.publicity_review_bindings binding on binding.assignment_id=a.id and binding.policy_id=(app_private.publicity_policy(r)).id
 where a.request_id=r.work_item_id and a.revision_id=r.current_revision_id and a.reviewer_id=member and a.generation=x.generation and a.stage_key=x.current_stage_key
 and a.expires_at>statement_timestamp()and exists(select 1 from app_private.effective_role_assignments ra where ra.id=a.authority_id and ra.version=a.authority_version)
 and app_private.publicity_independent(r,member,a.authority_id)is not null order by a.assigned_at desc limit 1
$$;

-- app_private.publicity_independent uses current delegation lineage.
create or replace function app_private.publicity_independent(r public.requests,member uuid,authority uuid default null)returns uuid language plpgsql stable security definer set search_path='' as $$
declare role uuid;p public.publicity_review_policies;person uuid;begin
 p:=app_private.publicity_policy(r);select member_id into person from public.term_memberships where id=member and term_id=r.term_id;
 if p.id is null or person is null or person=(select owner_member_id from public.work_items where id=r.work_item_id)then return null;end if;
 select d.authority_id into role from public.publicity_authority_designations d join app_private.effective_role_assignments assigned_role on assigned_role.id=d.authority_id where assigned_role.term_membership_id=member and(authority is null or d.authority_id=authority)and(d.authority_id=p.primary_authority_id or d.alternate_for_id=p.primary_authority_id)and app_private.publicity_role(r.term_id,member,r.receiving_unit_id,d.authority_id)is not null order by d.authority_id limit 1;
 return role;
end$$;

-- app_private.publicity_policy uses current delegation lineage.
create or replace function app_private.publicity_policy(r public.requests)returns public.publicity_review_policies language sql stable security definer set search_path='' as $$
 select p from public.publicity_review_policies p join public.workflow_versions v on v.id=p.workflow_version_id join app_private.effective_role_assignments primary_role on primary_role.id=p.primary_authority_id join public.term_memberships confirmer on confirmer.id=p.confirmed_by and confirmer.term_id=p.term_id
 where p.request_type_id=r.request_type_id and p.workflow_version_id=r.workflow_version_id and p.term_id=r.term_id
 and primary_role.term_id=r.term_id and primary_role.unit_id=r.receiving_unit_id and primary_role.organization_id=r.organization_id
 and jsonb_array_length(v.definition_json->'stages'->0->'reviewers')=1 and v.definition_json->'stages'->0->'reviewers'->>0=primary_role.term_membership_id::text
 and p.version=(select max(pp.version)from public.publicity_review_policies pp where pp.request_type_id=r.request_type_id and pp.workflow_version_id=r.workflow_version_id)
 and p.effective_from<=statement_timestamp()and p.effective_to>statement_timestamp()
 -- Only an explicitly confirmed single MCD decision stage is mapped here. Unsupported routing stays paused.
 and jsonb_array_length(v.definition_json->'stages')=1 and v.definition_json->'stages'->0->>'key'=p.stage_key
 and v.definition_json->'stages'->0->>'review'='one'and v.definition_json->'stages'->0->>'outcome'='approved'
 order by p.version desc limit 1
$$;

-- app_private.publicity_role uses current delegation lineage.
create or replace function app_private.publicity_role(term uuid,member uuid,unit uuid,authority uuid default null)returns uuid language sql stable security definer set search_path='' as $$
 select a.id from app_private.effective_role_assignments a join public.publicity_authority_designations d on d.authority_id=a.id and d.authority_version=a.version
 join public.term_memberships designation_confirmer on designation_confirmer.id=d.confirmed_by and designation_confirmer.term_id=a.term_id and designation_confirmer.organization_id=a.organization_id
 join public.roles role on role.id=a.role_id and role.state='active'join public.role_permissions rp on rp.role_id=role.id and rp.capability='mcd.review'and rp.allowed_scope='unit'
 join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id
 join public.terms t on t.id=tm.term_id and t.state='active'join public.organizations o on o.id=t.organization_id and o.state='active'
 join public.org_units u on u.id=a.unit_id and u.archived_at is null and u.review_service
 where a.term_id=term and a.term_membership_id=member and a.unit_id=unit and a.scope_type='unit'and a.status='active'and(authority is null or a.id=authority)
 and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()
 and tm.status='active'and tm.membership_kind='core'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from public.unit_memberships dep where dep.term_membership_id=tm.id and dep.unit_id=unit and dep.status='active'and dep.effective_from<=statement_timestamp()and dep.effective_to>statement_timestamp())
 and exists(select 1 from app_private.effective_role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=tm.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())order by a.id limit 1
$$;

-- app_private.readiness_authority uses current delegation lineage.
create or replace function app_private.readiness_authority(authority uuid,expected integer,term uuid,unit uuid)returns uuid language sql stable security definer set search_path='' as $$
 select a.term_membership_id from app_private.effective_role_assignments a join public.roles role on role.id=a.role_id and role.state='active'
 join public.role_permissions rp on rp.role_id=role.id and rp.capability='committee.manage'and rp.allowed_scope='unit'
 join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id
 join public.terms t on t.id=a.term_id and t.state='active'join public.organizations o on o.id=t.organization_id and o.state='active'join public.org_units u on u.id=a.unit_id and u.archived_at is null
 where a.id=authority and a.version=expected and a.term_id=term and a.unit_id=unit and a.scope_type='unit'and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()
 and tm.status='active'and tm.membership_kind='core'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from public.unit_memberships d where d.term_membership_id=tm.id and d.unit_id=unit and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())
 and exists(select 1 from app_private.effective_role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=tm.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())limit 1
$$;

-- app_private.readiness_authority_stamp uses current delegation lineage.
create or replace function app_private.readiness_authority_stamp(authority uuid)returns text language sql stable security definer set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('assignment',to_jsonb(a),'role',to_jsonb(r),'permissions',(select jsonb_agg(to_jsonb(p)order by p.id)from public.role_permissions p where p.role_id=r.id),'membership',to_jsonb(tm),'personVersion',to_jsonb(m)->'version','deployments',(select jsonb_agg(to_jsonb(d)order by d.id)from public.unit_memberships d where d.term_membership_id=tm.id),'workspace',(select jsonb_agg(jsonb_build_array(wa.id,wa.version,wr.id,wr.version,wp.id,wp.version)order by wa.id,wp.id)from app_private.effective_role_assignments wa join public.roles wr on wr.id=wa.role_id join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'where wa.term_membership_id=tm.id))::text,'UTF8')),'hex')from app_private.effective_role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id join public.members m on m.id=tm.member_id where a.id=authority
$$;

-- app_private.synergy_head uses current delegation lineage.
create or replace function app_private.synergy_head(p_term uuid,p_unit uuid,p_member uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id and m.account_state='active'
 join public.org_units u on u.id=p_unit and u.term_id=p_term and u.archived_at is null and u.delivery_committee
 join public.unit_memberships um on um.term_membership_id=tm.id and um.unit_id=u.id and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()
 join app_private.effective_role_assignments a on a.term_membership_id=tm.id and a.scope_type='unit' and a.unit_id=u.id and a.status='active' and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp()
 join public.roles r on r.id=a.role_id and r.state='active' join public.role_permissions p on p.role_id=r.id and p.capability='committee.manage' and p.allowed_scope='unit'
 where tm.term_id=p_term and tm.member_id=p_member and tm.membership_kind='core' and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp())
$$;

-- app_private.workflow_role uses current delegation lineage.
create or replace function app_private.workflow_role(term uuid,member uuid,unit uuid,authority uuid default null)returns uuid language sql security definer set search_path='' as $$
 select a.id from app_private.effective_role_assignments a join public.roles role on role.id=a.role_id and role.state='active'
 join public.role_permissions p on p.role_id=role.id and p.capability='department.review'and p.allowed_scope='unit'
 join public.term_memberships m on m.id=a.term_membership_id join public.members person on person.id=m.member_id
 join public.terms t on t.id=m.term_id and t.state='active'join public.organizations org on org.id=t.organization_id and org.state='active'
 join public.org_units u on u.id=a.unit_id and u.archived_at is null and u.review_service
 where a.term_id=term and a.term_membership_id=member and a.unit_id=unit and a.scope_type='unit'and a.status='active'
 and(authority is null or a.id=authority)and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()
 and m.status='active'and m.membership_kind='core'and m.joined_at<=statement_timestamp()and m.ends_at>statement_timestamp()and person.account_state='active'and person.auth_user_id is not null
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from app_private.effective_role_assignments wa join public.roles wr on wr.id=wa.role_id and wr.state='active'join public.role_permissions wp on wp.role_id=wr.id and wp.capability='workspace.read'and wp.allowed_scope='term'where wa.term_membership_id=m.id and wa.scope_type='term'and wa.status='active'and wa.effective_from<=statement_timestamp()and wa.effective_to>statement_timestamp())
 and exists(select 1 from public.unit_memberships d where d.term_membership_id=m.id and d.unit_id=unit and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())order by a.id limit 1
$$;

-- public.activate_finance_review uses current delegation lineage.
create or replace function public.activate_finance_review(p_work_item_id uuid,p_reviewer_id uuid,p_expected_revision integer,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.finance_authorization_policies;x public.workflow_instances;role uuid;payload jsonb;result jsonb;problem text;assignment_id uuid;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_finance_scope(r,m.id);m:=app_private.request_actor(w.term_id,true);
 if w.archived_at is not null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='fin')or(m.member_id<>w.owner_member_id and app_private.finance_role(r.term_id,m.id,r.receiving_unit_id)is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_reviewer_id,p_expected_revision,p_expected_version,p_reason);result:=app_private.begin_work_command('activate_finance_review',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if r.request_state not in('paused','in_review')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select *into x from public.workflow_instances where revision_id=r.current_revision_id for update;p:=app_private.finance_policy(r);role:=app_private.finance_independent(r,p_reviewer_id);
 perform app_private.lock_finance_scope(r,p_reviewer_id);role:=app_private.finance_independent(r,p_reviewer_id);
 if p.id is null or x.current_stage_key<>p.stage_key or not exists(select 1 from public.finance_revisions where request_revision_id=r.current_revision_id)then problem:='confirmed_fin_policy_required';
 elsif not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t))then problem:='routing_unavailable';
 elsif role is null then problem:='official_independent_fin_alternate_required';end if;
 if problem is null then problem:=app_private.finance_entry(r,x);end if;
 if problem is null and x.state='active'and exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation and (app_private.finance_assignment(r,a.reviewer_id)).id=a.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if problem is null then
  update public.workflow_instances set state='active',generation=generation+1,pause_reason=''where id=x.id returning *into x;
  insert into public.approval_assignments(organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at)
  select w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,1,p_reviewer_id,person.display_name,a.id,a.version,least(a.effective_to,tm.ends_at,d.effective_to,p.effective_to)from app_private.effective_role_assignments a join public.finance_authority_designations d on d.authority_id=a.id join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id where a.id=role returning id into assignment_id;
  insert into public.finance_review_bindings values(assignment_id,p.id);
 else update public.workflow_instances set state='paused',pause_reason=problem where id=x.id returning *into x;end if;
 update public.requests set request_state=case when problem is null then 'in_review'else 'paused'end where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when problem is null then 'in_review'else 'paused'end)where id=w.id returning *into w;
 perform app_private.workflow_event(w,x,case when problem is null then 'activated'else 'paused'end,p_reason);
 return app_private.finish_work_command(w,'activate_finance_review',p_request_id,payload,app_private.workflow_receipt(w,x),'["finance_assignment"]');
end$$;

-- public.activate_publicity_review uses current delegation lineage.
create or replace function public.activate_publicity_review(p_work_item_id uuid,p_reviewer_id uuid,p_expected_revision integer,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.publicity_review_policies;x public.workflow_instances;role uuid;payload jsonb;result jsonb;problem text;assignment_id uuid;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_publicity_scope(r,m.id);m:=app_private.request_actor(w.term_id,true);
 if w.archived_at is not null or not exists(select 1 from public.request_types where id=r.request_type_id and governed_kind='mcd')or(m.member_id<>w.owner_member_id and app_private.publicity_role(r.term_id,m.id,r.receiving_unit_id)is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_reviewer_id,p_expected_revision,p_expected_version,p_reason);result:=app_private.begin_work_command('activate_publicity_review',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if r.request_state not in('paused','in_review')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select *into x from public.workflow_instances where revision_id=r.current_revision_id for update;p:=app_private.publicity_policy(r);role:=app_private.publicity_independent(r,p_reviewer_id);
 perform app_private.lock_publicity_scope(r,p_reviewer_id);role:=app_private.publicity_independent(r,p_reviewer_id);
 if p.id is null or x.current_stage_key<>p.stage_key or not exists(select 1 from public.publicity_reviews where request_revision_id=r.current_revision_id)then problem:='confirmed_fin_policy_required';
 elsif not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t))then problem:='routing_unavailable';
 elsif role is null then problem:='official_independent_fin_alternate_required';end if;
 if problem is null then problem:=app_private.publicity_entry(r,x);end if;
 if problem is null and x.state='active'and exists(select 1 from public.approval_assignments a where a.instance_id=x.id and a.generation=x.generation and (app_private.publicity_assignment(r,a.reviewer_id)).id=a.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if problem is null then
  update public.workflow_instances set state='active',generation=generation+1,pause_reason=''where id=x.id returning *into x;
  insert into public.approval_assignments(organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at)
  select w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,1,p_reviewer_id,person.display_name,a.id,a.version,least(a.effective_to,tm.ends_at,d.effective_to,p.effective_to)from app_private.effective_role_assignments a join public.publicity_authority_designations d on d.authority_id=a.id join public.term_memberships tm on tm.id=a.term_membership_id join public.members person on person.id=tm.member_id where a.id=role returning id into assignment_id;
  insert into public.publicity_review_bindings values(assignment_id,p.id);
 else update public.workflow_instances set state='paused',pause_reason=problem where id=x.id returning *into x;end if;
 update public.requests set request_state=case when problem is null then 'in_review'else 'paused'end where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when problem is null then 'in_review'else 'paused'end)where id=w.id returning *into w;
 perform app_private.workflow_event(w,x,case when problem is null then 'activated'else 'paused'end,p_reason);
 return app_private.finish_work_command(w,'activate_publicity_review',p_request_id,payload,app_private.workflow_receipt(w,x),'["publicity_assignment"]');
end$$;

-- public.activate_request_workflow uses current delegation lineage.
create or replace function public.activate_request_workflow(p_work_item_id uuid,p_expected_revision integer,p_expected_stage text,p_expected_version integer,p_reviewers uuid[],p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;s jsonb;members uuid[];member uuid;authority uuid;ids uuid[]:='{}';problem text;payload jsonb;result jsonb;slot integer:=0;expiry timestamptz;begin
 select * into w from public.work_items where id=p_work_item_id for update;
 m:=app_private.request_actor(w.term_id,true);select * into r from public.requests where work_item_id=w.id;
 if r.request_type_id is null or not coalesce(app_private.workflow_manager(r,m),false)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_expected_revision,p_expected_stage,p_expected_version,p_reviewers,p_reason);result:=app_private.begin_work_command('activate_request_workflow',p_request_id,payload);if result is not null then return result;end if;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision or x.current_stage_key is distinct from p_expected_stage then raise exception using errcode='40001',message='command_stale_version';end if;
 if w.archived_at is not null or r.request_state not in('paused','in_review')or x.state not in('paused','active')or(x.state='active'and app_private.workflow_current(x))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 s:=app_private.workflow_stage(x);problem:=app_private.workflow_entry(r,x);
 members:=coalesce(p_reviewers,array(select value::uuid from jsonb_array_elements_text(s->'reviewers')));
 if array_ndims(members)>1 or cardinality(members)>10 or cardinality(members)<>(select count(distinct a)from unnest(members)a)or array_position(members,null)is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if(s->>'review'='one'and cardinality(members)<>1)or(s->>'review'='all'and(cardinality(members)=0 or cardinality(members)<>jsonb_array_length(s->'reviewers')))then problem:=coalesce(problem,'reviewer_configuration_missing');end if;
 foreach member in array members loop
  authority:=app_private.workflow_role(w.term_id,member,r.receiving_unit_id);
  if authority is null or exists(select 1 from public.term_memberships where id=member and member_id=w.owner_member_id)then problem:=coalesce(problem,'eligible_independent_reviewer_missing');end if;ids:=array_append(ids,authority);
 end loop;
 if problem is null then
  if x.generation>=100 then raise exception using errcode='22023',message='command_quota_limit';end if;
  update public.workflow_instances set state='active',generation=generation+1,pause_reason=''where id=x.id returning * into x;
  foreach member in array members loop slot:=slot+1;
   select least(a.effective_to,tm.ends_at)into expiry from app_private.effective_role_assignments a join public.term_memberships tm on tm.id=a.term_membership_id where a.id=ids[slot];
   insert into public.approval_assignments(organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at)
   select w.organization_id,w.term_id,w.id,x.revision_id,x.id,x.current_stage_key,x.generation,slot,member,p.display_name,a.id,a.version,expiry from app_private.effective_role_assignments a join public.term_memberships tm on tm.id=a.term_membership_id join public.members p on p.id=tm.member_id where a.id=ids[slot];
  end loop;update public.requests set request_state='in_review'where work_item_id=w.id;
 else update public.workflow_instances set state='paused',pause_reason=problem where id=x.id returning * into x;update public.requests set request_state='paused'where work_item_id=w.id;end if;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when problem is null then 'in_review'else 'paused'end)where id=w.id returning * into w;
 perform app_private.workflow_event(w,x,case when problem is not null then 'paused'when x.generation>1 then 'reassigned'else 'activated'end,p_reason);
 return app_private.finish_work_command(w,'activate_request_workflow',p_request_id,payload,app_private.workflow_receipt(w,x),'["workflow_assignment_state"]');
end$$;

-- public.decide_finance_request uses current delegation lineage.
create or replace function public.decide_finance_request(p_work_item_id uuid,p_expected_revision integer,p_expected_version integer,p_action text,p_reason text,p_ceiling_centavos text,p_conditions text,p_expires_at timestamptz,p_external_outcome text,p_external_manifest_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;p public.finance_authorization_policies;a public.approval_assignments;x public.workflow_instances;f public.finance_revisions;payload jsonb;result jsonb;decision uuid;authorization_id uuid;ceiling bigint;begin
 select *into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;perform app_private.lock_finance_scope(r,m.id);a:=app_private.finance_assignment(r,m.id);p:=app_private.finance_policy(r);
 if w.archived_at is not null or a.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform 1 from app_private.effective_role_assignments where id=a.authority_id for share;perform 1 from public.term_memberships where id=a.reviewer_id for share;
 if app_private.finance_independent(r,m.id,a.authority_id)is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_expected_revision,p_expected_version,p_action,p_reason,p_ceiling_centavos,p_conditions,p_expires_at,p_external_outcome,p_external_manifest_id);result:=app_private.begin_work_command('decide_finance_request',p_request_id,payload);if result is not null then return result;end if;
 select *into x from public.workflow_instances where id=a.instance_id for update;select *into f from public.finance_revisions where request_revision_id=r.current_revision_id;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if app_private.finance_entry(r,x)is not null or r.request_state<>'in_review'or x.state<>'active'or x.current_stage_key<>p.stage_key or f.id is null or not exists(select 1 from public.request_types t where t.id=r.request_type_id and app_private.request_route_ready(t))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action is null or p_action not in('approve','reject','request_revision')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='approve'then
  ceiling:=app_private.finance_cents(to_jsonb(p_ceiling_centavos));
  if ceiling>f.requested_total_centavos or p_conditions is null or length(btrim(p_conditions))not between 1 and 2000 or p_expires_at is null or not isfinite(p_expires_at)or p_expires_at<=statement_timestamp()or p_expires_at>((select closes_on+1 from public.terms where id=w.term_id)::timestamp at time zone'Asia/Manila')then raise exception using errcode='22023',message='command_validation_failed';end if;
  if p.external_requirement='not_required'then if p_external_outcome is distinct from 'not_required'or p_external_manifest_id is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
  elsif p_external_outcome is null or p_external_outcome not in('pending','verified')or(p_external_outcome='verified'and(p_external_manifest_id is null or p_external_manifest_id is distinct from f.manifest_id))or(p_external_outcome='pending'and p_external_manifest_id is not null)then raise exception using errcode='22023',message='command_validation_failed';end if;
 elsif p_ceiling_centavos is not null or p_conditions is not null or p_expires_at is not null or p_external_outcome is not null or p_external_manifest_id is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.approval_decisions(assignment_id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,action,reason,payload_hash,evidence_manifest_id)
 values(a.id,w.organization_id,w.term_id,w.id,r.current_revision_id,x.id,x.current_stage_key,x.generation,p_action,p_reason,f.payload_hash,f.manifest_id)returning id into decision;
 if p_action='approve'then
  insert into public.financial_authorizations(organization_id,term_id,request_id,finance_revision_id,request_revision_id,policy_id,assignment_id,decision_id,payload_hash,requested_total_centavos,ceiling_centavos,purpose,conditions,expires_at,external_outcome,external_manifest_id)
  values(w.organization_id,w.term_id,w.id,f.id,r.current_revision_id,p.id,a.id,decision,f.payload_hash,f.requested_total_centavos,ceiling,f.purpose,p_conditions,p_expires_at,p_external_outcome,p_external_manifest_id)returning id into authorization_id;
 end if;
 update public.workflow_instances set state=case p_action when 'approve'then 'approved'when 'reject'then 'rejected'else 'needs_revision'end,pause_reason=''where id=x.id returning *into x;
 update public.requests set request_state=x.state,revision_resume_stage_key=case when p_action='request_revision'then p.stage_key else revision_resume_stage_key end where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,x.state)where id=w.id returning *into w;perform app_private.workflow_event(w,x,'decided',p_reason);
 return app_private.finish_work_command(w,'decide_finance_request',p_request_id,payload,app_private.workflow_receipt(w,x)||jsonb_build_object('decisionId',decision,'authorizationId',authorization_id),'["finance_decision"]');
end$$;

-- public.explain_access uses current delegation lineage.
create or replace function public.explain_access(p_term_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('membership_id', public.current_term_membership(p_term_id),
    'grants', coalesce((select jsonb_agg(jsonb_build_object(
      'role_id', a.role_id, 'capability', p.capability, 'scope', a.scope_type,
      'unit_id', a.unit_id, 'expires_at', a.effective_to) order by a.id, p.capability)
      from app_private.effective_role_assignments a join public.role_permissions p on p.role_id = a.role_id
      join public.roles r on r.id = a.role_id and r.state = 'active'
      where a.term_membership_id = public.current_term_membership(p_term_id)
        and a.status = 'active' and a.effective_from <= statement_timestamp() and a.effective_to > statement_timestamp()
        and p.allowed_scope = a.scope_type and public.has_capability(p_term_id, p.capability, a.unit_id)), '[]'::jsonb))
$$;

-- public.explain_my_access uses current delegation lineage.
create or replace function public.explain_my_access(p_term_id uuid,p_work_id uuid default null)returns jsonb language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin m:=app_private.request_actor(p_term_id);return jsonb_build_object('memberId',m.member_id,'grants',coalesce((select jsonb_agg(jsonb_build_object('assignmentId',a.id,'role',r.name,'scope',a.scope_type,'unitId',a.unit_id,'workId',a.work_id,'capability',p.capability,'expiresAt',least(a.effective_to,m.ends_at))order by a.id,p.capability)from app_private.effective_role_assignments a join public.roles r on r.id=a.role_id join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope=a.scope_type where a.term_id=p_term_id and a.term_membership_id=m.id and app_private.access_assignment_live(a.id)),'[]'),
 'requestedRecordReadable',case when p_work_id is null then null else exists(select 1 from public.work_items w where w.id=p_work_id and w.term_id=p_term_id and public.can_access_work(w.id,'detail'))end,
 'constraints',jsonb_build_array('Current roster, account, role, dates and scope apply.','FIN/MCD/feedback require their separate current designation, case assignment, evidence and independence.','An app role does not grant provider-console ownership.','Emergency access is closed here: recorded approval, reason, expiry and custodian notification require a separately verified path.','No real-user impersonation or sensitive read-all endpoint exists.'));end$$;

-- public.has_capability uses current delegation lineage.
create or replace function public.has_capability(p_term_id uuid, p_capability text, p_unit_id uuid default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from app_private.effective_role_assignments a
    join public.roles r on r.id = a.role_id and r.term_id = a.term_id and r.organization_id = a.organization_id
    join public.role_permissions p on p.role_id = r.id and p.term_id = a.term_id and p.organization_id = a.organization_id
    join public.term_memberships tm on tm.id = a.term_membership_id
    where a.term_membership_id = public.current_term_membership(p_term_id)
      and a.term_id = p_term_id and tm.membership_kind = 'core'
      and a.status = 'active' and r.state = 'active'
      and a.effective_from <= statement_timestamp() and a.effective_to > statement_timestamp()
      and p.capability = p_capability and p.allowed_scope = a.scope_type
      and ((a.scope_type in ('term', 'own') and p_unit_id is null) or
        (a.scope_type = 'unit' and a.unit_id = p_unit_id and exists (
          select 1 from public.unit_memberships d join public.org_units u on u.id = d.unit_id
          where d.term_membership_id = tm.id and d.unit_id = a.unit_id and d.term_id = a.term_id
            and d.organization_id = a.organization_id and d.status = 'active' and u.archived_at is null
            and d.effective_from <= statement_timestamp() and d.effective_to > statement_timestamp()
        )))
  )
$$;

-- public.has_work_capability uses current delegation lineage.
create or replace function public.has_work_capability(p_work_item_id uuid,p_capability text) returns boolean
language sql stable security definer set search_path='' as $$
  select p_capability in ('workspace.read','committee.manage') and exists(
    select 1 from public.work_items w join app_private.effective_role_assignments a on a.work_id=w.id
    join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope='work' and p.capability=p_capability
    join public.roles r on r.id=a.role_id and r.state='active'
    where w.id=p_work_item_id and a.scope_type='work' and a.term_membership_id=public.current_term_membership(w.term_id)
      and a.status='active' and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp())
$$;

-- public.preflight_access_change uses current delegation lineage.
create or replace function public.preflight_access_change(p_term_id uuid,p_values jsonb)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;recipient public.term_memberships;a public.role_assignments;p record;c public.delegation_ceilings;cap text;scope text;unit uuid;work uuid;starts timestamptz;ends timestamptz;target uuid;constraints jsonb:='[]';covered boolean:=false;eligible boolean:=true;begin
 m:=app_private.access_editor(p_term_id);
 if not app_private.definition_keys(p_values,array['action','targetMembershipId','capability','scope','unitId','workId','from','to','assignmentId'])or(p_values->>'action')is null or(p_values->>'action')not in('grant','revoke')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_values->>'action'='revoke'then
 select *into a from app_private.effective_role_assignments where id=(p_values->>'assignmentId')::uuid and term_id=p_term_id;if not found then return jsonb_build_object('withinCeiling',false,'mutationAvailable',false,'constraints',jsonb_build_array('current_target_assignment_required'));end if;target:=a.term_membership_id;scope:=a.scope_type;unit:=a.unit_id;work:=a.work_id;starts:=statement_timestamp();ends:=a.effective_to;
 if scope='term'and exists(select 1 from public.role_permissions rp where rp.role_id=a.role_id and rp.allowed_scope='term'and rp.capability in('admin.configure','roles.manage'))and not exists(select 1 from public.verified_app_custodians v join app_private.effective_role_assignments other on other.id=v.assignment_id where other.term_id=p_term_id and other.term_membership_id<>target and app_private.access_verified_custodian(other.id))then constraints:=constraints||jsonb_build_array('verified_custodian_replacement_required');end if;
 else
 target:=(p_values->>'targetMembershipId')::uuid;cap:=p_values->>'capability';scope:=p_values->>'scope';unit:=nullif(p_values->>'unitId','')::uuid;work:=nullif(p_values->>'workId','')::uuid;starts:=(p_values->>'from')::timestamptz;ends:=(p_values->>'to')::timestamptz;
 if target is null or starts is null or ends is null or not isfinite(starts)or not isfinite(ends)or starts>=ends or not exists(select 1 from jsonb_array_elements(app_private.access_catalog())x where x->>'capability'=cap and(x->'scopes')?scope)or(scope='unit')is distinct from(unit is not null)or(scope='work')is distinct from(work is not null)then raise exception using errcode='22023',message='command_validation_failed';end if;
 end if;
 if target=m.id then constraints:=constraints||jsonb_build_array('no_self_privilege_change');end if;
 select *into recipient from public.term_memberships where id=target and term_id=p_term_id and membership_kind='core'and status='active'and joined_at<=statement_timestamp()and ends_at>statement_timestamp();
 if recipient.id is null or not exists(select 1 from public.members where id=recipient.member_id and account_state='active')then constraints:=constraints||jsonb_build_array('active_recipient_required');end if;
 if not exists(select 1 from public.terms where id=p_term_id and state='active')then constraints:=constraints||jsonb_build_array('active_term_required');end if;
 if unit is not null and not exists(select 1 from public.org_units where id=unit and term_id=p_term_id and archived_at is null)then constraints:=constraints||jsonb_build_array('current_unit_required');end if;
 if work is not null and not exists(select 1 from public.work_items w where w.id=work and w.term_id=p_term_id and w.archived_at is null and public.can_access_work(w.id,'detail'))then constraints:=constraints||jsonb_build_array('independent_record_access_required');end if;
 for p in select rp.capability from public.role_permissions rp where p_values->>'action'='revoke'and rp.role_id=a.role_id and rp.allowed_scope=scope union all select cap where p_values->>'action'='grant'loop
 covered:=false;for c in select *from public.delegation_ceilings ceiling where ceiling.term_id=p_term_id and ceiling.grantor_membership_id=m.id and ceiling.capability=p.capability and ceiling.scope_type=scope and ceiling.unit_id is not distinct from unit and ceiling.work_id is not distinct from work loop
 if app_private.access_ceiling_live(c)and(p.capability not in('finance.review','mcd.review','feedback.review','admin.configure','roles.manage')or c.sensitive_authorized)and(p_values->>'action'='revoke'or(starts>=c.starts_at and ends<=c.ends_at and starts>=recipient.joined_at and ends<=recipient.ends_at and ends<=(select effective_to from app_private.effective_role_assignments where id=c.source_assignment_id)and ends<=(select ends_at from public.term_memberships where id=m.id)and(scope<>'unit'or exists(select 1 from public.unit_memberships dep where dep.term_membership_id=recipient.id and dep.unit_id=unit and dep.status='active'and dep.effective_from<=starts and dep.effective_to>=ends))and not exists(select 1 from app_private.effective_role_assignments src where src.id=c.source_assignment_id and src.scope_type='unit'and not exists(select 1 from public.unit_memberships dep where dep.term_membership_id=m.id and dep.unit_id=src.unit_id and dep.status='active'and dep.effective_from<=starts and dep.effective_to>=ends))))then covered:=true;exit;end if;end loop;
 if not covered then eligible:=false;end if;end loop;
 if not eligible or covered is not true then constraints:=constraints||jsonb_build_array('current_grantor_ceiling_required');end if;
 return jsonb_build_object('withinCeiling',constraints='[]'::jsonb,'mutationAvailable',false,'constraints',constraints,'notice','Validation only. Use the separately reviewed explicit publication path; this check changes no authority.');end$$;

-- public.preview_organization_change uses current delegation lineage.
create or replace function public.preview_organization_change(p_term_id uuid,p_action text,p_values jsonb)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;u public.org_units;target public.org_units;tm public.term_memberships;dep public.unit_memberships;w public.work_items;d public.deliverables;change_id uuid;unit uuid;member uuid;allowed text[];blocked boolean:=false;obligations jsonb:='[]';row public.work_items;reviewers jsonb;deltas jsonb;v integer;previous jsonb:='{}';changes jsonb;begin
 m:=app_private.organization_actor(p_term_id);allowed:=case p_action when 'unit_save'then array['id','code','name','delivery','review']when 'unit_archive'then array['id']when 'unit_merge'then array['id','targetId']when 'roster_add'then array['email','name','joinedAt','endsAt']when 'roster_edit'then array['id','name','status','joinedAt','endsAt']when 'deployment_save'then array['id','memberId','unitId','type','from','to','state']when 'work_reassign'then array['id','unitId','ownerId','workVersion']else null end;
 if allowed is null or not app_private.definition_keys(p_values,allowed)then raise exception using errcode='22023',message='command_validation_failed';end if;
 change_id:=nullif(p_values->>'id','')::uuid;
 if p_action like 'unit_%'and change_id is not null then select *into u from public.org_units where org_units.id=change_id and term_id=p_term_id and archived_at is null;if not found then raise exception using errcode='42501',message='command_permission_denied';end if;unit:=u.id;end if;
 if p_action='unit_save'then
 if not app_private.definition_text(p_values->'name',200)or not app_private.definition_text(p_values->'code',40)or(p_values->>'code')!~'^[A-Z][A-Z0-9_-]{0,39}$'or jsonb_typeof(p_values->'delivery')is distinct from 'boolean'or jsonb_typeof(p_values->'review')is distinct from 'boolean'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if change_id is not null and((u.delivery_committee and not(p_values->>'delivery')::boolean)or(u.review_service and not(p_values->>'review')::boolean))then blocked:=exists(select 1 from app_private.organization_obligations(p_term_id,unit))or exists(select 1 from public.request_types rt where rt.term_id=p_term_id and rt.receiving_unit_id=unit and rt.live_enabled and rt.archived_at is null);end if;
 elsif p_action in('unit_archive','unit_merge')then
 if unit is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 blocked:=exists(select 1 from app_private.organization_obligations(p_term_id,unit))or exists(select 1 from public.request_types t where t.term_id=p_term_id and t.receiving_unit_id=unit and t.live_enabled and t.archived_at is null);
 if p_action='unit_merge'then select *into target from public.org_units where org_units.id=(p_values->>'targetId')::uuid and term_id=p_term_id and archived_at is null and org_units.id<>unit;if not found then raise exception using errcode='22023',message='command_validation_failed';end if;end if;
 elsif p_action in('roster_add','roster_edit')then
 if not app_private.definition_text(p_values->'name',200)or(p_values->>'joinedAt')is null or(p_values->>'endsAt')is null or not isfinite((p_values->>'joinedAt')::timestamptz)or not isfinite((p_values->>'endsAt')::timestamptz)or(p_values->>'joinedAt')::timestamptz>=(p_values->>'endsAt')::timestamptz then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='roster_add'then if jsonb_typeof(p_values->'email')is distinct from 'string'or lower(btrim(p_values->>'email'))!~'^[^[:space:]@]+@student[.]ateneo[.]edu$'then raise exception using errcode='22023',message='command_validation_failed';end if;
 else select *into tm from public.term_memberships where term_memberships.id=change_id and term_id=p_term_id and membership_kind='core';if not found or(p_values->>'status')is null or(p_values->>'status')not in('active','suspended')then raise exception using errcode='22023',message='command_validation_failed';end if;member:=tm.id;
 if(p_values->>'status')<>'active'or(p_values->>'joinedAt')::timestamptz>statement_timestamp()or(p_values->>'endsAt')::timestamptz<=statement_timestamp()or(p_values->>'endsAt')::timestamptz<tm.ends_at or(p_values->>'joinedAt')::timestamptz>tm.joined_at then
 blocked:=exists(select 1 from app_private.organization_obligations(p_term_id,null,member))or member=m.id or exists(select 1 from app_private.effective_role_assignments a join public.role_permissions p on p.role_id=a.role_id where a.term_membership_id=member and a.status='active'and a.effective_to>statement_timestamp()and p.capability in('admin.configure','roles.manage'))or exists(select 1 from public.request_types t where t.term_id=p_term_id and t.live_enabled and t.archived_at is null and member in(t.primary_contact_id,t.backup_contact_id));end if;end if;
 elsif p_action='deployment_save'then
 unit:=(p_values->>'unitId')::uuid;member:=(p_values->>'memberId')::uuid;select *into tm from public.term_memberships where term_memberships.id=member and term_id=p_term_id and membership_kind='core'and status='active'and joined_at<=statement_timestamp()and ends_at>statement_timestamp();
 if not found or not exists(select 1 from public.members where members.id=tm.member_id and account_state='active')or not exists(select 1 from public.org_units where org_units.id=unit and term_id=p_term_id and archived_at is null)or(p_values->>'type')is null or(p_values->>'type')not in('member','head','associate','primary_contact','backup_contact')or(p_values->>'state')is null or(p_values->>'state')not in('active','revoked')or(p_values->>'from')is null or(p_values->>'to')is null or not isfinite((p_values->>'from')::timestamptz)or not isfinite((p_values->>'to')::timestamptz)or(p_values->>'from')::timestamptz>=(p_values->>'to')::timestamptz or(p_values->>'from')::timestamptz<tm.joined_at or(p_values->>'to')::timestamptz>tm.ends_at then raise exception using errcode='22023',message='command_validation_failed';end if;
 if change_id is not null then select *into dep from public.unit_memberships where unit_memberships.id=change_id and term_id=p_term_id;if not found or(dep.term_membership_id,dep.unit_id,dep.deployment_type)is distinct from(member,unit,p_values->>'type')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_values->>'state'='revoked'or(p_values->>'from')::timestamptz>statement_timestamp()or(p_values->>'to')::timestamptz<dep.effective_to then blocked:=exists(select 1 from app_private.organization_obligations(p_term_id,unit,member))or exists(select 1 from public.request_types t where t.term_id=p_term_id and t.live_enabled and t.archived_at is null and member in(t.primary_contact_id,t.backup_contact_id));end if;end if;
 elsif p_action='work_reassign'then
 select *into w from public.work_items where work_items.id=change_id and term_id=p_term_id and kind='deliverable'and classification='ordinary'and archived_at is null;
 if not found or not public.can_access_work(w.id,'edit')then raise exception using errcode='42501',message='command_permission_denied';end if;
 unit:=w.lead_unit_id;select *into d from public.deliverables where work_item_id=w.id;select *into target from public.org_units where org_units.id=(p_values->>'unitId')::uuid and term_id=p_term_id and archived_at is null;
 if target.id is null or not app_private.manage_deliverable(p_term_id,unit)or not app_private.manage_deliverable(p_term_id,target.id)or not exists(select 1 from public.term_memberships mm join public.members person on person.id=mm.member_id where mm.term_id=p_term_id and mm.member_id=(p_values->>'ownerId')::uuid and mm.status='active'and mm.membership_kind='core'and mm.joined_at<=statement_timestamp()and mm.ends_at>statement_timestamp()and person.account_state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if w.version is distinct from(p_values->>'workVersion')::integer then raise exception using errcode='40001',message='command_stale_version';end if;
 blocked:=d.workflow_state not in('proposed','draft','in_progress')or d.finance_required or d.publicity_required or d.work_types<>array['operations']or exists(select 1 from public.finance_revisions where related_deliverable_id=w.id)or exists(select 1 from public.publicity_reviews where related_deliverable_id=w.id)or exists(select 1 from public.work_items where parent_work_item_id=w.id)or exists(select 1 from public.synergy_agreements where parent_work_item_id=w.id);
 end if;
 if unit is not null or member is not null then for row in select *from app_private.organization_obligations(p_term_id,unit,member)loop if public.can_access_work(row.id,'detail')then obligations:=obligations||jsonb_build_array(jsonb_build_object('id',row.id,'title',case when row.classification='ordinary'then row.title else 'Restricted work — resolve in its own authorized workflow'end,'href',case row.kind when 'deliverable'then '/deliverables/'when 'task'then '/tasks/'else null end||row.id));end if;end loop;end if;
 select coalesce(jsonb_agg(jsonb_build_object('memberId',a.term_membership_id,'name',person.display_name,'capability',p.capability,'unitId',a.unit_id)order by a.id,p.capability),'[]')into reviewers from app_private.effective_role_assignments a join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope=a.scope_type join public.roles role on role.id=a.role_id and role.state='active'join public.term_memberships mm on mm.id=a.term_membership_id join public.members person on person.id=mm.member_id where a.term_id=p_term_id and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()and(unit is null or a.unit_id=unit)and(member is null or a.term_membership_id=member);
 deltas:=jsonb_build_object('transferredRoles',0,'transferredRecordGrants',0,'transferredDeployments',0,'affectedUnitId',unit,'targetUnitId',target.id,'targetOwnerId',p_values->>'ownerId','potentialExistingCapabilities',reviewers,'targetCapabilities',coalesce((select jsonb_agg(jsonb_build_object('memberId',a.term_membership_id,'capability',rp.capability,'unitId',a.unit_id))from app_private.effective_role_assignments a join public.role_permissions rp on rp.role_id=a.role_id and rp.allowed_scope=a.scope_type join public.roles rr on rr.id=a.role_id and rr.state='active'where a.term_id=p_term_id and a.unit_id=coalesce(target.id,unit)and a.status='active'and a.effective_from<=statement_timestamp()and a.effective_to>statement_timestamp()and(member is null or a.term_membership_id=member)),'[]'),'message',case when p_action='unit_merge'then 'Source unit deployments/capabilities cease to be effective. No target deployment, role, sensitive case or record grant is copied.'when p_action='deployment_save'then 'Dated deployment may activate existing roles in this exact unit. No new role assignment is created.'when p_action='work_reassign'then 'Only this permitted ordinary deliverable changes current owner/routing; target-unit existing scope may become effective. Old record grants remain unchanged.'else 'No roles or record grants are created or transferred.'end);
 previous:=case when p_action like 'unit_%'then jsonb_build_object('code',u.code,'name',u.name,'delivery',u.delivery_committee,'review',u.review_service,'targetId',null)when p_action='roster_edit'then jsonb_build_object('name',(select display_name from public.members where id=tm.member_id),'status',tm.status,'joinedAt',tm.joined_at,'endsAt',tm.ends_at)when p_action='deployment_save'then jsonb_build_object('memberId',dep.term_membership_id,'unitId',dep.unit_id,'type',dep.deployment_type,'state',dep.status,'from',dep.effective_from,'to',dep.effective_to)when p_action='work_reassign'then jsonb_build_object('unitId',w.lead_unit_id,'ownerId',w.owner_member_id,'workVersion',w.version)else '{}'::jsonb end;
 select coalesce(jsonb_agg(jsonb_build_object('field',e.key,'before',previous->e.key,'after',e.value)order by e.key),'[]')into changes from jsonb_each(p_values)e where e.key<>'id'and previous->e.key is distinct from e.value;
 select coalesce(wi.version,0)into v from public.organization_control c join public.work_items wi on wi.id=c.work_item_id where c.term_id=p_term_id;
 return jsonb_build_object('changes',changes,'version',coalesce(v,0),'fingerprint',app_private.organization_fingerprint(p_term_id,p_action,p_values),'blocked',blocked,'message',case when blocked then 'Blocked: resolve active ownership, reviewer/service contacts or protected scope through the authorized workflow before publishing this change.'else 'Review the explicit access effect, then publish this structural change.'end,'openWork',obligations,'activeReviewers',reviewers,'accessDelta',deltas);
 end$$;

-- public.read_people_directory uses current delegation lineage.
create or replace function public.read_people_directory(p_term_id uuid) returns jsonb
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
      select distinct r.name from app_private.effective_role_assignments a join public.roles r on r.id=a.role_id
      where a.term_membership_id=tm.id and a.status='active' and r.state='active'
        and a.effective_from<=statement_timestamp() and a.effective_to>statement_timestamp()
        and (a.unit_id is null or exists(select 1 from public.unit_memberships um
          join public.org_units u on u.id=um.unit_id and u.archived_at is null
          where um.term_membership_id=tm.id and um.unit_id=a.unit_id and um.status='active'
            and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp()))
    ) x),'[]'::jsonb),
    'skills',case when p.share_skills then p.skills end,
    'pronunciation',case when p.share_pronunciation then p.pronunciation end,
    'affiliation',case when p.share_affiliation then tm.affiliation_tag end,
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

-- public.transition_request uses current delegation lineage.
create or replace function public.transition_request(p_work_item_id uuid,p_assignment_id uuid,p_expected_revision integer,p_expected_stage text,p_expected_version integer,p_action text,p_reason text,p_evidence_manifest_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;a public.approval_assignments;rev public.request_revisions;s jsonb;payload jsonb;result jsonb;decision uuid;votes integer;needed integer;next jsonb;outcome text;resume text;begin
 select * into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);
 select * into r from public.requests where work_item_id=w.id;select * into a from public.approval_assignments where id=p_assignment_id and request_id=w.id;
 if a.id is null or a.reviewer_id<>m.id or m.member_id=w.owner_member_id or not app_private.workflow_assignment_current(a)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_assignment_id,p_expected_revision,p_expected_stage,p_expected_version,p_action,p_reason,p_evidence_manifest_id);result:=app_private.begin_work_command('transition_request',p_request_id,payload);if result is not null then return result;end if;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;select * into rev from public.request_revisions where id=x.revision_id;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision or x.current_stage_key is distinct from p_expected_stage or a.revision_id<>r.current_revision_id or a.stage_key<>x.current_stage_key or a.generation<>x.generation then raise exception using errcode='40001',message='command_stale_version';end if;
 perform 1 from public.terms where id=w.term_id for share;perform 1 from public.org_units where id=r.receiving_unit_id for share;
 perform 1 from app_private.effective_role_assignments where id in(select authority_id from public.approval_assignments where instance_id=x.id and generation=x.generation)order by id for share;
 perform 1 from public.term_memberships where id in(select reviewer_id from public.approval_assignments where instance_id=x.id and generation=x.generation)order by id for share;
 perform 1 from public.members where id in(select member_id from public.term_memberships where id in(select reviewer_id from public.approval_assignments where instance_id=x.id and generation=x.generation))order by id for share;
 if r.request_state<>'in_review'or w.archived_at is not null or not app_private.workflow_current(x)or app_private.workflow_entry(r,x)is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action is null or p_action not in('approve','reject','request_revision')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 s:=app_private.workflow_stage(x);
 if(p_evidence_manifest_id is not null and p_evidence_manifest_id is distinct from rev.manifest_id)or(coalesce((s->>'externalEvidenceRequired')::boolean,false)and p_evidence_manifest_id is null)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action='request_revision'then
  resume:=s->>'revisionStage';if resume is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;outcome:='needs_revision';
 end if;
 insert into public.approval_decisions(assignment_id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,action,reason,payload_hash,evidence_manifest_id)
 values(a.id,w.organization_id,w.term_id,w.id,rev.id,x.id,x.current_stage_key,x.generation,p_action,p_reason,encode(sha256(convert_to(jsonb_build_array(rev.id,rev.form_version_id,rev.workflow_version_id,rev.manifest_hash,coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),(select requested_centavos from public.request_finance_values where revision_id=rev.id))::text,'UTF8')),'hex'),p_evidence_manifest_id)returning id into decision;
 if p_action='reject'then outcome:='rejected';
 elsif p_action='approve'and outcome is null then
  select count(*)into votes from public.approval_decisions d where d.instance_id=x.id and d.generation=x.generation and d.action='approve';
  needed:=case when s->>'review'='one'then 1 else(select count(*)from public.approval_assignments where instance_id=x.id and generation=x.generation)end;
  if votes>=needed then
   if s->>'outcome'='pending'then
    select v.definition_json->'stages'->st.ordinality::int into next from public.workflow_versions v cross join lateral jsonb_array_elements(v.definition_json->'stages')with ordinality st(value,ordinality)where v.id=x.workflow_version_id and st.value->>'key'=x.current_stage_key;
    if next is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
    update public.workflow_instances set current_stage_key=next->>'key',state='paused',pause_reason='assignment_required'where id=x.id returning * into x;outcome:='paused';
   else outcome:=s->>'outcome';if outcome='revision'then resume:=s->>'revisionStage';if resume is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;outcome:='needs_revision';end if;end if;
  end if;
 end if;
 if outcome in('approved','rejected','completed','needs_revision')then
  insert into public.request_workflow_outcomes(request_id,revision_id,organization_id,term_id,decision_id,category)values(w.id,rev.id,w.organization_id,w.term_id,decision,case when outcome='needs_revision'then outcome else 'general_'||outcome end);
  update public.workflow_instances set state=outcome,pause_reason=''where id=x.id returning * into x;
 end if;
 if outcome is not null then update public.requests set request_state=outcome,revision_resume_stage_key=case when outcome='needs_revision'then resume else revision_resume_stage_key end where work_item_id=w.id;end if;
 update public.work_items set status_id=app_private.request_status(w.term_id,coalesce(outcome,'in_review'))where id=w.id returning * into w;
 perform app_private.workflow_event(w,x,'decided',p_reason);
 return app_private.finish_work_command(w,'transition_request',p_request_id,payload,app_private.workflow_receipt(w,x)||jsonb_build_object('decisionId',decision),'["workflow_decision","safe_general_outcome"]');
end$$;

-- public.triage_request uses current delegation lineage.
create or replace function public.triage_request(p_work_item_id uuid,p_expected_revision integer,p_expected_version integer,p_action text,p_note text,p_accepted_on date,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;payload jsonb;result jsonb;begin
 select * into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select * into r from public.requests where work_item_id=w.id;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;
 if not(coalesce(app_private.workflow_manager(r,m),false)or(p_action='note'and coalesce(app_private.workflow_member(r,x,m,true),false)))then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform 1 from app_private.effective_role_assignments where term_membership_id=m.id order by id for share;
 perform 1 from public.unit_memberships where term_membership_id=m.id and unit_id=r.receiving_unit_id order by id for share;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;
 if not(coalesce(app_private.workflow_manager(r,m),false)or(p_action='note'and coalesce(app_private.workflow_member(r,x,m,true),false)))then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_expected_revision,p_expected_version,p_action,p_note,p_accepted_on);result:=app_private.begin_work_command('triage_request',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version or r.current_revision is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
 if w.archived_at is not null or r.request_state not in('paused','in_review','needs_revision','approved')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action is null or p_action not in('note','accepted_date','completed')or p_note is null or length(btrim(p_note))not between 1 and 2000 or p_note~'[[:cntrl:]]'or(p_action<>'accepted_date'and p_accepted_on is not null)or(p_action='accepted_date'and(p_accepted_on is null or not(p_accepted_on between '0001-01-01'and'9999-12-31')))then raise exception using errcode='22023',message='command_validation_failed';end if;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;
 if p_action<>'note'and not app_private.workflow_hooks_ready(r)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action='completed'then
  if r.request_state<>'approved'or x.state<>'approved'or not exists(select 1 from public.request_workflow_outcomes where revision_id=x.revision_id and category='general_approved')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  update public.requests set request_state='completed'where work_item_id=w.id;update public.workflow_instances set state='completed'where id=x.id returning * into x;
 elsif p_action='accepted_date'then update public.requests set accepted_on=p_accepted_on where work_item_id=w.id;end if;
 if(select count(*)from public.request_triage_events where request_id=w.id)>=1000 then raise exception using errcode='22023',message='command_quota_limit';end if;
 insert into public.request_triage_events(organization_id,term_id,request_id,revision_id,kind,note,accepted_on,actor_name)select w.organization_id,w.term_id,w.id,x.revision_id,p_action,btrim(p_note),p_accepted_on,display_name from public.members where id=m.member_id;
 update public.work_items set status_id=app_private.request_status(w.term_id,case when p_action='completed'then 'completed'else r.request_state end)where id=w.id returning * into w;
 return app_private.finish_work_command(w,'triage_request',p_request_id,payload,app_private.workflow_receipt(w,x),'["operational_triage"]');
end$$;
-- ACCESS_READ_MODEL
alter function public.read_access_admin(uuid) rename to read_access_inspection;
alter function public.read_access_inspection(uuid) set schema app_private;
revoke all on function app_private.read_access_inspection(uuid)from public,anon,authenticated,service_role;
create function public.read_access_admin(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;begin m:=app_private.access_editor(p_term_id);
 return app_private.read_access_inspection(p_term_id)||jsonb_build_object('mutationAvailable',true,
 'controlVersion',coalesce((select w.version from public.access_control c join public.work_items w on w.id=c.work_item_id where c.term_id=p_term_id),0),
 'roleVersions',coalesce((select jsonb_agg(jsonb_build_object('id',v.role_id,'familyId',v.family_id,'revision',v.revision,'scope',v.scope_type,'unitId',v.unit_id,'workId',v.work_id,'mine',v.publisher_id=m.id)order by v.revision)from public.access_role_versions v where v.term_id=p_term_id and(v.publisher_id=m.id or exists(select 1 from public.role_assignments own where own.role_id=v.role_id and own.term_membership_id=m.id))and(v.work_id is null or public.can_access_work(v.work_id,'detail'))),'[]'),
 'assignments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'version',a.version,'membershipId',a.term_membership_id,'roleId',a.role_id,'scope',a.scope_type,'unitId',a.unit_id,'workId',a.work_id,'from',a.effective_from,'to',a.effective_to,'state',a.status,'effective',app_private.access_lineage_current(a.id),'custodian',app_private.access_verified_custodian(a.id))order by a.id)
 from public.role_assignments a where a.term_id=p_term_id and(a.work_id is null or public.can_access_work(a.work_id,'detail'))and(a.term_membership_id=m.id or(exists(select 1 from public.role_permissions p where p.role_id=a.role_id and p.allowed_scope=a.scope_type)and not exists(select 1 from public.role_permissions p where p.role_id=a.role_id and p.allowed_scope=a.scope_type and app_private.access_ceiling_for(p_term_id,p.capability,a.scope_type,a.unit_id,a.work_id,statement_timestamp(),statement_timestamp()+interval'1 second')is null)))),'[]'),
 'nominations',coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'assignmentId',n.assignment_id,'candidateId',a.term_membership_id,'expiresAt',n.expires_at,'accepted',n.accepted_at is not null)order by n.created_at desc)from public.access_custody_nominations n join public.role_assignments a on a.id=n.assignment_id where n.term_id=p_term_id and(n.nominated_by=m.id or a.term_membership_id=m.id)),'[]'),
 'history',coalesce((select jsonb_agg(jsonb_build_object('version',h.version,'action',h.action,'targetId',h.target_id,'at',h.created_at,'reason',h.reason)order by h.version desc)from public.access_changes h join public.access_control c on c.work_item_id=h.control_id where c.term_id=p_term_id and h.actor_id=auth.uid()),'[]'),
 'notice','Explicit publication requires a fresh reviewed change and current independent ceiling. Custody confirmation records application acknowledgment only; provider ownership and institutional approval remain separate.');
end$$;
revoke all on function public.read_access_admin(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_access_admin(uuid)to authenticated;
