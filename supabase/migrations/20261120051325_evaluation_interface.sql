begin;

-- Trusted provisioning records the actual independent privacy/UAT decision.
-- No client command creates an approval, and fixtures never provision hosted data.
create table app_private.evaluation_launch_approvals(
  id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),
  category_hash text not null check(category_hash ~ '^[a-f0-9]{64}$'),
  custodian_id uuid not null references public.term_memberships(id),
  approved_by uuid not null references public.term_memberships(id),
  approval_reference text not null check(length(btrim(approval_reference)) between 3 and 500),
  uat_reference text not null check(length(btrim(uat_reference)) between 3 and 500),
  complaints_url text not null check(length(complaints_url) between 11 and 1008 and complaints_url ~ '^https://[^[:space:]]+$'),
  expires_at timestamptz not null check(isfinite(expires_at)),
  created_at timestamptz not null default statement_timestamp(),
  check(custodian_id<>approved_by and expires_at>created_at)
);
create table app_private.evaluation_cohort_reports(
  id uuid primary key default gen_random_uuid(),term_id uuid not null unique references public.terms(id),
  published_by uuid not null references public.term_memberships(id),
  published_at timestamptz not null default statement_timestamp(),
  cohort text not null default '5 or more' check(cohort='5 or more')
);
do $$declare relation text;
begin
  foreach relation in array array['evaluation_launch_approvals','evaluation_cohort_reports'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
    execute format('create trigger immutable_%I before update or delete on app_private.%I for each row execute function app_private.request_history_guard()',relation,relation);
  end loop;
end $$;

alter function app_private.evaluation_policy_ready(uuid) rename to evaluation_policy_before_interface;
create function app_private.evaluation_policy_ready(p_term uuid) returns boolean language sql stable set search_path='' as $$
  select app_private.evaluation_policy_before_interface(p_term) and exists(
    select 1 from app_private.evaluation_launch_approvals a join public.privacy_sensitive_categories c
      on c.term_id=a.term_id and c.category='prism' and c.owner_membership_id=a.custodian_id
    where a.term_id=p_term and a.category_hash=app_private.sensitive_category_hash(p_term,'prism')
      and a.expires_at>statement_timestamp() and app_private.learning_member(p_term,a.approved_by));
$$;

create function public.read_evaluation_help(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; result jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);
  if app_private.evaluation_policy_ready(p_term_id) then
    select jsonb_build_object('complaintsUrl',a.complaints_url) into result
      from app_private.evaluation_launch_approvals a
      where a.term_id=p_term_id and a.category_hash=app_private.sensitive_category_hash(p_term_id,'prism')
        and a.expires_at>statement_timestamp() order by a.created_at desc,a.id desc limit 1;
  end if;
  perform app_private.record_content_read('read_evaluation_help',p_term_id,null,result is not null);
  return result;
end $$;

create function public.read_evaluation_exports(p_term_id uuid,p_case_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; result jsonb:='[]'::jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,false);
  select * into c from app_private.evaluation_cases where term_id=p_term_id and id=p_case_id;
  if app_private.evaluation_raw_view(c,actor) is not null then
    select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'version',g.case_version,'expiresAt',g.expires_at)
      order by g.created_at,g.id),'[]'::jsonb) into result
      from app_private.evaluation_export_grants g where g.term_id=p_term_id and g.case_id=c.id and g.case_version=c.version
        and g.membership_id=actor.id and g.revoked_at is null and g.expires_at>statement_timestamp();
  end if;
  perform app_private.record_content_read('read_evaluation_exports',p_term_id,case when result<>'[]'::jsonb then c.id end,result<>'[]'::jsonb);
  return result;
end $$;

alter function app_private.evaluation_raw_view(app_private.evaluation_cases,public.term_memberships) rename to evaluation_raw_before_interface;
create function app_private.evaluation_raw_view(c app_private.evaluation_cases,actor public.term_memberships) returns jsonb
language plpgsql stable set search_path='' as $$
declare result jsonb; drafts jsonb;
begin
  result:=app_private.evaluation_raw_before_interface(c,actor);
  if result is null then return null;end if;
  select coalesce(jsonb_agg(d||jsonb_build_object('published',exists(select 1 from app_private.evaluation_releases e
    where e.draft_id=(d->>'id')::uuid))),'[]'::jsonb) into drafts from jsonb_array_elements(result->'releaseDrafts') d;
  return result||jsonb_build_object('releaseDrafts',drafts,
    'retention',(select r.retention_rule from app_private.feedback_rounds r where r.id=c.round_id));
end $$;
revoke all on function app_private.evaluation_raw_before_interface(app_private.evaluation_cases,public.term_memberships),
  app_private.evaluation_raw_view(app_private.evaluation_cases,public.term_memberships) from public,anon,authenticated,service_role;

-- One term-wide publication, never a series of overlapping filtered measurements.
-- Reports contain only the lower bound of a released-subject cohort, no exact total,
-- complement, response count, score, narrative, unit, person or source identifiers.
create function app_private.evaluation_cohort_state(p_term uuid) returns text language sql stable set search_path='' as $$
  select case when not exists(select 1 from app_private.feedback_rounds r where r.term_id=p_term)
    or exists(select 1 from app_private.feedback_rounds r where r.term_id=p_term
      and (r.closes_at>statement_timestamp() or r.release_after>statement_timestamp())) then 'not_ready'
    when (select count(distinct c.subject_id) from app_private.evaluation_cases c
      join app_private.feedback_rounds r on r.id=c.round_id
      where c.term_id=p_term and exists(select 1 from app_private.evaluation_releases e
        where e.case_id=c.id and app_private.evaluation_release_current(e,c,r)))<5 then 'suppressed'
    else 'ready' end;
$$;
create function public.read_evaluation_report(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; report app_private.evaluation_cohort_reports; result jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,false);
  if not app_private.privacy_strong_session() or not exists(select 1 from public.privacy_sensitive_categories c
    where c.term_id=p_term_id and c.category='prism' and c.owner_membership_id=actor.id) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  select * into report from app_private.evaluation_cohort_reports where term_id=p_term_id;
  result:=case when report.id is not null then jsonb_build_object('state','published','cohort',report.cohort,'at',report.published_at)
    else jsonb_build_object('state',app_private.evaluation_cohort_state(p_term_id),'cohort',null,'at',null) end;
  perform app_private.record_content_read('read_evaluation_report',p_term_id,null,true);
  return result;
end $$;
create function public.publish_evaluation_report(p_term_id uuid,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; report app_private.evaluation_cohort_reports; payload jsonb; prior jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  if not app_private.privacy_strong_session() or not exists(select 1 from public.privacy_sensitive_categories c
    where c.term_id=p_term_id and c.category='prism' and c.owner_membership_id=actor.id) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id);
  prior:=app_private.begin_work_command('publish_evaluation_report',p_key,payload);if prior is not null then return prior;end if;
  if exists(select 1 from app_private.evaluation_cohort_reports where term_id=p_term_id) then
    raise exception using errcode='55000',message='command_evaluation_report_frozen';end if;
  if app_private.evaluation_cohort_state(p_term_id)<>'ready' then
    raise exception using errcode='55000',message='command_evaluation_report_suppressed';end if;
  insert into app_private.evaluation_cohort_reports(term_id,published_by) values(p_term_id,actor.id) returning * into report;
  return app_private.evaluation_receipt(actor,'publish_evaluation_report',p_key,payload,report.id,1);
end $$;
alter table app_private.evaluation_events drop constraint evaluation_events_operation_check,
  add constraint evaluation_events_operation_check check(operation in ('create_feedback_round','create_evaluation_case','assign_evaluation_participant',
    'end_evaluation_assignment','submit_evaluation','append_evaluation_note','prepare_evaluation_release',
    'publish_evaluation_release','grant_evaluation_export','revoke_evaluation_export','publish_evaluation_report'));
update app_private.disposition_sources set structure_hash=app_private.disposition_structure(source_key)
  where source_key='app_private.evaluation_events';

insert into public.restricted_read_endpoints(endpoint,argument_types) values
  ('read_evaluation_help','uuid'),('read_evaluation_exports','uuid, uuid'),('read_evaluation_report','uuid');
revoke all on function app_private.evaluation_policy_before_interface(uuid),app_private.evaluation_policy_ready(uuid),
  app_private.evaluation_cohort_state(uuid),public.read_evaluation_help(uuid),public.read_evaluation_exports(uuid,uuid),
  public.read_evaluation_report(uuid),public.publish_evaluation_report(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_evaluation_help(uuid),public.read_evaluation_exports(uuid,uuid),
  public.read_evaluation_report(uuid),public.publish_evaluation_report(uuid,uuid) to authenticated;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,category,'term',array['id'],format(
  'select app_private.disposition_key(%L,array[x.id::text]) target_hash,%L category,x.id root_id,
    app_private.retention_is_held($1,%L,x.id,null) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x where x.term_id=$1',
    'app_private.'||source,category,category,source),app_private.disposition_structure('app_private.'||source),preserve
from(values('evaluation_launch_approvals','security',true),('evaluation_cohort_reports','prism',false)) entries(source,category,preserve);
alter function app_private.retention_inventory(uuid) rename to retention_inventory_before_evaluation_interface;
create function app_private.retention_inventory(p_term uuid) returns table(id uuid,category text,kind text,parent_id uuid)
language sql stable security definer set search_path='' as $$
  select * from app_private.retention_inventory_before_evaluation_interface(p_term)
  union all select r.id,'prism','record',null::uuid from app_private.evaluation_cohort_reports r where r.term_id=p_term;
$$;
revoke all on function app_private.retention_inventory_before_evaluation_interface(uuid),app_private.retention_inventory(uuid)
  from public,anon,authenticated,service_role;
commit;
