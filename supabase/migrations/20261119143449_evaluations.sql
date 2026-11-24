begin;

create table app_private.feedback_rounds (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id),
  unit_id uuid not null references public.org_units(id),
  custodian_id uuid not null references public.term_memberships(id),
  authority_id uuid not null references public.role_assignments(id),
  authority_version integer not null check(authority_version>0),
  label text not null check(length(btrim(label)) between 1 and 160),
  purpose text not null check(length(btrim(purpose)) between 1 and 2000),
  template jsonb not null,
  policy_hash text not null check(policy_hash ~ '^[a-f0-9]{64}$'),
  retention_rule jsonb not null,
  opens_at timestamptz not null check(isfinite(opens_at)),
  closes_at timestamptz not null check(isfinite(closes_at) and closes_at>opens_at),
  release_after timestamptz not null check(isfinite(release_after) and release_after>=closes_at),
  appeal_until timestamptz not null check(isfinite(appeal_until) and appeal_until>=release_after),
  release_policy text not null default 'independent_summary' check(release_policy='independent_summary'),
  created_at timestamptz not null default statement_timestamp(),
  unique(term_id,id)
);
create table app_private.evaluation_cases (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  round_id uuid not null,
  subject_id uuid not null references public.term_memberships(id),
  version integer not null default 1 check(version>0),
  foreign key(term_id,round_id) references app_private.feedback_rounds(term_id,id),
  unique(round_id,subject_id),
  unique(term_id,id),
  unique(term_id,id,subject_id)
);
create table app_private.evaluation_assignments (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  case_id uuid not null,
  membership_id uuid not null references public.term_memberships(id),
  kind text not null check(kind in ('author','reviewer','releaser')),
  authority_id uuid references public.role_assignments(id),
  authority_version integer,
  starts_at timestamptz not null check(isfinite(starts_at)),
  ends_at timestamptz not null check(isfinite(ends_at) and ends_at>starts_at),
  revoked_at timestamptz,
  conflict_at timestamptz,
  version integer not null default 1 check(version>0),
  foreign key(term_id,case_id) references app_private.evaluation_cases(term_id,id),
  check((kind='author')=(authority_id is null and authority_version is null)),
  unique(case_id,membership_id,kind)
);
create table app_private.feedback_submissions (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  case_id uuid not null,
  author_id uuid not null references public.term_memberships(id),
  assignment_id uuid not null references app_private.evaluation_assignments(id),
  revision integer not null default 1 check(revision>0),
  state text not null check(state in ('submitted','withdrawn')),
  foreign key(term_id,case_id) references app_private.evaluation_cases(term_id,id),
  unique(case_id,author_id),
  unique(term_id,id)
);
create table app_private.feedback_revisions (
  submission_id uuid not null,
  term_id uuid not null,
  revision integer not null check(revision>0),
  state text not null check(state in ('submitted','withdrawn')),
  answers jsonb,
  amended_from integer,
  submitted_at timestamptz not null default clock_timestamp(),
  primary key(submission_id,revision),
  foreign key(term_id,submission_id) references app_private.feedback_submissions(term_id,id),
  check((state='withdrawn')=(answers is null)),
  check(amended_from is null and revision=1 or amended_from=revision-1)
);
create table app_private.evaluation_reviewer_notes (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  case_id uuid not null,
  author_id uuid not null references public.term_memberships(id),
  assignment_id uuid not null references app_private.evaluation_assignments(id),
  case_version integer not null check(case_version>0),
  body text not null check(length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default clock_timestamp(),
  foreign key(term_id,case_id) references app_private.evaluation_cases(term_id,id)
);
create table app_private.evaluation_release_drafts (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  case_id uuid not null,
  subject_id uuid not null references public.term_memberships(id),
  case_version integer not null check(case_version>0),
  source_hash text not null check(source_hash ~ '^[a-f0-9]{64}$'),
  summary text not null check(length(btrim(summary)) between 1 and 6000),
  prepared_by uuid not null references public.term_memberships(id),
  assignment_id uuid not null references app_private.evaluation_assignments(id),
  created_at timestamptz not null default clock_timestamp(),
  foreign key(term_id,case_id,subject_id) references app_private.evaluation_cases(term_id,id,subject_id)
);
create table app_private.evaluation_releases (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  case_id uuid not null,
  subject_id uuid not null references public.term_memberships(id),
  draft_id uuid not null unique references app_private.evaluation_release_drafts(id),
  case_version integer not null check(case_version>0),
  source_hash text not null check(source_hash ~ '^[a-f0-9]{64}$'),
  summary text not null check(length(btrim(summary)) between 1 and 6000),
  released_by uuid not null references public.term_memberships(id),
  assignment_id uuid not null references app_private.evaluation_assignments(id),
  released_at timestamptz not null default clock_timestamp(),
  foreign key(term_id,case_id,subject_id) references app_private.evaluation_cases(term_id,id,subject_id),
  unique(case_id,case_version)
);
create table app_private.evaluation_export_grants (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  case_id uuid not null,
  membership_id uuid not null references public.term_memberships(id),
  case_version integer not null,
  approved_by uuid not null references public.term_memberships(id),
  purpose_reference text not null check(length(btrim(purpose_reference)) between 3 and 500),
  expires_at timestamptz not null check(isfinite(expires_at)),
  revoked_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  foreign key(term_id,case_id) references app_private.evaluation_cases(term_id,id),
  check(membership_id<>approved_by and expires_at>created_at)
);
create table app_private.evaluation_events (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id),
  object_id uuid not null,
  actor_id uuid not null references auth.users(id),
  operation text not null check(operation in ('create_feedback_round','create_evaluation_case','assign_evaluation_participant',
    'end_evaluation_assignment','submit_evaluation','append_evaluation_note','prepare_evaluation_release',
    'publish_evaluation_release','grant_evaluation_export','revoke_evaluation_export')),
  version integer not null check(version>0),
  occurred_at timestamptz not null default clock_timestamp()
);

create index evaluation_cases_subject on app_private.evaluation_cases(term_id,subject_id);
create index evaluation_assignments_member on app_private.evaluation_assignments(term_id,membership_id,case_id);
create index feedback_submissions_case on app_private.feedback_submissions(case_id);
create index evaluation_notes_case on app_private.evaluation_reviewer_notes(case_id,created_at);
create index evaluation_drafts_case on app_private.evaluation_release_drafts(case_id,case_version);
create index evaluation_releases_subject on app_private.evaluation_releases(term_id,subject_id,case_id);
create index evaluation_export_member on app_private.evaluation_export_grants(term_id,membership_id,case_id);

do $$declare relation text;
begin
  foreach relation in array array['feedback_rounds','evaluation_cases','evaluation_assignments','feedback_submissions',
    'feedback_revisions','evaluation_reviewer_notes','evaluation_release_drafts','evaluation_releases','evaluation_export_grants','evaluation_events'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
  end loop;
  foreach relation in array array['feedback_rounds','feedback_revisions','evaluation_reviewer_notes',
    'evaluation_release_drafts','evaluation_releases','evaluation_events'] loop
    execute format('create trigger immutable_%I before update or delete on app_private.%I for each row execute function app_private.request_history_guard()',relation,relation);
  end loop;
end;
$$;

create function app_private.evaluation_policy_ready(p_term uuid) returns boolean language sql stable set search_path='' as $$
  select app_private.sensitive_category_ready(p_term,'prism') and not app_private.disposition_replay_required(p_term)
    and exists(select 1 from public.privacy_sensitive_categories c
      cross join lateral (
        select v.definition,v.actor_id from public.presentation_controls pc join public.presentation_versions v on v.control_id=pc.work_item_id
        join public.work_items w on w.id=pc.work_item_id and w.archived_at is null
        where pc.term_id=p_term and pc.kind='retention' order by v.version desc limit 1
      ) published
      where c.term_id=p_term and c.category='prism' and app_private.learning_member(p_term,c.owner_membership_id)
        and app_private.privacy_custodian_live(p_term,c.owner_membership_id)
        and app_private.retention_approved(p_term,published.definition,(select tm.id from public.term_memberships tm
          join public.members m on m.id=tm.member_id where tm.term_id=p_term and m.auth_user_id=published.actor_id))
        and exists(select 1 from jsonb_array_elements(published.definition->'rules') rule where rule=c.retention_definition->'rules'->0));
$$;
create function app_private.evaluation_actor(p_term uuid,p_write boolean default false) returns public.term_memberships
language plpgsql set search_path='' as $$
declare actor public.term_memberships;
begin
  actor:=app_private.request_actor(p_term,p_write);
  if p_write then perform app_private.readiness_lock(p_term); end if;
  if not app_private.evaluation_policy_ready(p_term) then
    raise exception using errcode='55000',message='command_evaluation_policy_unavailable';
  end if;
  return actor;
end;
$$;
create function app_private.evaluation_authority(p_term uuid,p_unit uuid,p_member uuid,p_authority uuid) returns boolean
language sql stable set search_path='' as $$
  select app_private.learning_member(p_term,p_member) and exists(
    select 1 from app_private.effective_role_assignments a join public.role_permissions cap on cap.role_id=a.role_id
    where a.id=p_authority and a.term_id=p_term and a.term_membership_id=p_member and a.scope_type='unit'
      and a.unit_id=p_unit and cap.capability='feedback.review' and cap.allowed_scope='unit'
      and app_private.access_assignment_live(a.id));
$$;
create function app_private.evaluation_round_live(r app_private.feedback_rounds) returns boolean language sql stable set search_path='' as $$
  select coalesce(app_private.evaluation_policy_ready(r.term_id)
    and r.policy_hash=app_private.sensitive_category_hash(r.term_id,'prism')
    and app_private.privacy_custodian_live(r.term_id,r.custodian_id)
    and app_private.evaluation_authority(r.term_id,r.unit_id,r.custodian_id,r.authority_id)
    and exists(select 1 from public.role_assignments a where a.id=r.authority_id and a.version=r.authority_version),false);
$$;
create function app_private.evaluation_is_custodian(r app_private.feedback_rounds,actor public.term_memberships)
returns boolean language sql stable set search_path='' as $$
  select coalesce(r.custodian_id=actor.id and app_private.privacy_strong_session() and app_private.evaluation_round_live(r),false);
$$;
create function app_private.evaluation_conflicted(c app_private.evaluation_cases,p_member uuid) returns boolean
language sql stable set search_path='' as $$
  select coalesce(c.subject_id=p_member or exists(
    select 1 from app_private.evaluation_assignments a where a.case_id=c.id and a.membership_id=p_member and a.kind='author')
    or exists(select 1 from app_private.mentorships m where m.term_id=c.term_id and m.mentee_id=c.subject_id
      and m.mentor_id=p_member and app_private.mentorship_live(m)),true);
$$;
create function app_private.evaluation_assignment_live(a app_private.evaluation_assignments,c app_private.evaluation_cases,
  r app_private.feedback_rounds) returns boolean language sql stable set search_path='' as $$
  select coalesce(a.case_id=c.id and a.term_id=c.term_id and r.id=c.round_id
    and a.revoked_at is null and a.conflict_at is null and a.starts_at<=statement_timestamp() and a.ends_at>statement_timestamp()
    and app_private.learning_member(a.term_id,a.membership_id) and app_private.evaluation_round_live(r)
    and (case when a.kind='author' then a.membership_id<>c.subject_id else
      not app_private.evaluation_conflicted(c,a.membership_id) and a.membership_id<>r.custodian_id
      and app_private.evaluation_authority(a.term_id,r.unit_id,a.membership_id,a.authority_id)
      and exists(select 1 from public.role_assignments role where role.id=a.authority_id and role.version=a.authority_version) end),false);
$$;
create function app_private.evaluation_review_assignment(c app_private.evaluation_cases,actor public.term_memberships,p_kind text)
returns app_private.evaluation_assignments language sql stable set search_path='' as $$
  select a.* from app_private.evaluation_assignments a join app_private.feedback_rounds r on r.id=c.round_id
    where a.case_id=c.id and a.membership_id=actor.id and (p_kind is null or a.kind=p_kind)
      and a.kind in ('reviewer','releaser') and app_private.privacy_strong_session()
      and app_private.evaluation_assignment_live(a,c,r) order by a.id limit 1;
$$;
create function app_private.evaluation_source_hash(c app_private.evaluation_cases) returns text
language sql stable set search_path='' as $$
  select encode(sha256(convert_to(coalesce((select jsonb_agg(jsonb_build_array(s.id,s.revision,s.state,a.version,a.revoked_at,a.conflict_at)
      order by s.id) from app_private.feedback_submissions s join app_private.evaluation_assignments a on a.id=s.assignment_id
    where s.case_id=c.id),'[]'::jsonb)::text,'UTF8')),'hex');
$$;
create function app_private.evaluation_receipt(actor public.term_memberships,p_command text,p_key uuid,p_payload jsonb,
  p_id uuid,p_version integer) returns jsonb language plpgsql set search_path='' as $$
declare result jsonb:=jsonb_build_object('id',p_id,'version',p_version);
begin
  insert into app_private.evaluation_events(term_id,object_id,actor_id,operation,version)
    values(actor.term_id,p_id,auth.uid(),p_command,p_version);
  insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)
    values(auth.uid(),p_command,p_key,actor.organization_id,actor.term_id,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),result);
  return result;
end;
$$;
create function app_private.validate_evaluation_template(template jsonb) returns void language plpgsql immutable set search_path='' as $$
declare field jsonb;
begin
  if jsonb_typeof(template) is distinct from 'array' or jsonb_array_length(template) not between 1 and 12
    or (select count(distinct f->>'key') from jsonb_array_elements(template)f)<>jsonb_array_length(template) then
    raise exception using errcode='22023',message='command_evaluation_template_invalid';
  end if;
  for field in select * from jsonb_array_elements(template) loop
    if not coalesce(app_private.definition_keys(field,array['key','label','required','maxLength']),false)
      or (select count(*) from jsonb_object_keys(field))<>4 or (field->>'key') !~ '^[a-z][a-z0-9_]{0,39}$'
      or not coalesce(app_private.presentation_text(field->'label',200),false)
      or jsonb_typeof(field->'required') is distinct from 'boolean'
      or jsonb_typeof(field->'maxLength') is distinct from 'number'
      or (field->>'maxLength') !~ '^[1-9][0-9]{0,3}$' or (field->>'maxLength')::integer>4000 then
      raise exception using errcode='22023',message='command_evaluation_template_invalid';
    end if;
  end loop;
end;
$$;

create function public.append_evaluation_note(p_term_id uuid,p_case_id uuid,p_expected_version integer,p_body text,p_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; a app_private.evaluation_assignments;
  n app_private.evaluation_reviewer_notes; payload jsonb; prior jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id for update;
  a:=app_private.evaluation_review_assignment(c,actor,null);
  if a.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_case_id,p_expected_version,p_body);
  prior:=app_private.begin_work_command('append_evaluation_note',p_key,payload);if prior is not null then return prior;end if;
  if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  if coalesce(length(btrim(p_body)),0) not between 1 and 4000 then
    raise exception using errcode='22023',message='command_validation_failed';end if;
  update app_private.evaluation_cases set version=version+1 where id=c.id returning * into c;
  insert into app_private.evaluation_reviewer_notes(term_id,case_id,author_id,assignment_id,case_version,body)
    values(p_term_id,c.id,actor.id,a.id,c.version,btrim(p_body)) returning * into n;
  return app_private.evaluation_receipt(actor,'append_evaluation_note',p_key,payload,n.id,c.version);
end;
$$;
create function public.prepare_evaluation_release(p_term_id uuid,p_case_id uuid,p_expected_version integer,
  p_subject_id uuid,p_summary text,p_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; a app_private.evaluation_assignments;
  d app_private.evaluation_release_drafts; payload jsonb; prior jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id for update;
  a:=app_private.evaluation_review_assignment(c,actor,'reviewer');
  if a.id is null or c.subject_id is distinct from p_subject_id then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_case_id,p_expected_version,p_subject_id,p_summary);
  prior:=app_private.begin_work_command('prepare_evaluation_release',p_key,payload);if prior is not null then return prior;end if;
  if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  if coalesce(length(btrim(p_summary)),0) not between 1 and 6000 then
    raise exception using errcode='22023',message='command_validation_failed';end if;
  if not exists(select 1 from app_private.feedback_submissions s where s.case_id=c.id and s.state='submitted') then
    raise exception using errcode='55000',message='command_evaluation_feedback_required';end if;
  insert into app_private.evaluation_release_drafts(term_id,case_id,subject_id,case_version,source_hash,summary,prepared_by,assignment_id)
    values(p_term_id,c.id,c.subject_id,c.version,app_private.evaluation_source_hash(c),btrim(p_summary),actor.id,a.id) returning * into d;
  return app_private.evaluation_receipt(actor,'prepare_evaluation_release',p_key,payload,d.id,d.case_version);
end;
$$;
create function public.publish_evaluation_release(p_term_id uuid,p_draft_id uuid,p_expected_version integer,
  p_subject_id uuid,p_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; r app_private.feedback_rounds; a app_private.evaluation_assignments;
  preparing app_private.evaluation_assignments; d app_private.evaluation_release_drafts; release app_private.evaluation_releases;
  payload jsonb; prior jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into d from app_private.evaluation_release_drafts where id=p_draft_id and term_id=p_term_id;
  select * into c from app_private.evaluation_cases where id=d.case_id for update;
  select * into r from app_private.feedback_rounds where id=c.round_id;
  a:=app_private.evaluation_review_assignment(c,actor,'releaser');
  select * into preparing from app_private.evaluation_assignments where id=d.assignment_id;
  if a.id is null or actor.id=d.prepared_by or c.subject_id is distinct from p_subject_id or d.subject_id is distinct from c.subject_id
    or not app_private.evaluation_assignment_live(preparing,c,r) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_draft_id,p_expected_version,p_subject_id);
  prior:=app_private.begin_work_command('publish_evaluation_release',p_key,payload);if prior is not null then return prior;end if;
  if c.version is distinct from p_expected_version or d.case_version<>c.version or d.source_hash<>app_private.evaluation_source_hash(c) then
    raise exception using errcode='40001',message='command_evaluation_release_stale';end if;
  if statement_timestamp()<r.release_after or statement_timestamp()>r.appeal_until
    or not exists(select 1 from app_private.feedback_submissions s join app_private.evaluation_assignments author on author.id=s.assignment_id
      where s.case_id=c.id and s.state='submitted' and app_private.evaluation_assignment_live(author,c,r)) then
    raise exception using errcode='55000',message='command_evaluation_release_not_ready';end if;
  insert into app_private.evaluation_releases(term_id,case_id,subject_id,draft_id,case_version,source_hash,summary,released_by,assignment_id)
    values(p_term_id,c.id,c.subject_id,d.id,c.version,d.source_hash,d.summary,actor.id,a.id) returning * into release;
  return app_private.evaluation_receipt(actor,'publish_evaluation_release',p_key,payload,release.id,release.case_version);
end;
$$;

create function public.grant_evaluation_export(p_term_id uuid,p_case_id uuid,p_expected_version integer,p_member_id uuid,
  p_expires_at timestamptz,p_purpose_reference text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; r app_private.feedback_rounds;
  gr app_private.evaluation_export_grants; payload jsonb; prior jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id for update;
  select * into r from app_private.feedback_rounds where id=c.round_id;
  if not app_private.evaluation_is_custodian(r,actor) or p_member_id in (c.subject_id,actor.id)
    or not exists(select 1 from app_private.evaluation_assignments a where a.case_id=c.id and a.membership_id=p_member_id
      and app_private.evaluation_assignment_live(a,c,r)) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_case_id,p_expected_version,p_member_id,p_expires_at,p_purpose_reference);
  prior:=app_private.begin_work_command('grant_evaluation_export',p_key,payload);if prior is not null then return prior;end if;
  if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  if p_expires_at is null or not isfinite(p_expires_at) or p_expires_at<=statement_timestamp() or p_expires_at>r.appeal_until
    or coalesce(length(btrim(p_purpose_reference)),0) not between 3 and 500 then
    raise exception using errcode='22023',message='command_validation_failed';end if;
  insert into app_private.evaluation_export_grants(term_id,case_id,membership_id,case_version,approved_by,purpose_reference,expires_at)
    values(p_term_id,c.id,p_member_id,c.version,actor.id,btrim(p_purpose_reference),p_expires_at) returning * into gr;
  return app_private.evaluation_receipt(actor,'grant_evaluation_export',p_key,payload,gr.id,gr.case_version);
end;
$$;
create function public.revoke_evaluation_export(p_term_id uuid,p_grant_id uuid,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; gr app_private.evaluation_export_grants; r app_private.feedback_rounds; payload jsonb; prior jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);perform app_private.readiness_lock(p_term_id);
  select * into gr from app_private.evaluation_export_grants where id=p_grant_id and term_id=p_term_id for update;
  select rd.* into r from app_private.feedback_rounds rd join app_private.evaluation_cases c on c.round_id=rd.id where c.id=gr.case_id;
  if gr.id is null or not app_private.evaluation_is_custodian(r,actor) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_grant_id);
  prior:=app_private.begin_work_command('revoke_evaluation_export',p_key,payload);if prior is not null then return prior;end if;
  update app_private.evaluation_export_grants set revoked_at=statement_timestamp() where id=gr.id;
  return app_private.evaluation_receipt(actor,'revoke_evaluation_export',p_key,payload,gr.id,gr.case_version);
end;
$$;

create function app_private.evaluation_release_current(e app_private.evaluation_releases,c app_private.evaluation_cases,
  r app_private.feedback_rounds) returns boolean language sql stable set search_path='' as $$
  select coalesce(e.subject_id=c.subject_id and e.case_version=c.version and e.source_hash=app_private.evaluation_source_hash(c)
    and app_private.evaluation_round_live(r)
    and exists(select 1 from app_private.evaluation_assignments a where a.id=e.assignment_id and app_private.evaluation_assignment_live(a,c,r))
    and exists(select 1 from app_private.evaluation_release_drafts d join app_private.evaluation_assignments a on a.id=d.assignment_id
      where d.id=e.draft_id and app_private.evaluation_assignment_live(a,c,r)),false);
$$;
create function app_private.evaluation_raw_view(c app_private.evaluation_cases,actor public.term_memberships) returns jsonb
language plpgsql stable set search_path='' as $$
declare r app_private.feedback_rounds; reviewer boolean; author boolean; result jsonb;
begin
  select * into r from app_private.feedback_rounds where id=c.round_id;
  reviewer:=(app_private.evaluation_review_assignment(c,actor,null)).id is not null;
  author:=exists(select 1 from app_private.evaluation_assignments a where a.case_id=c.id and a.membership_id=actor.id
    and a.kind='author' and app_private.evaluation_assignment_live(a,c,r));
  if not (reviewer or author) then return null;end if;
  select jsonb_build_object('caseId',c.id,'version',c.version,'round',r.label,'purpose',r.purpose,'subjectId',c.subject_id,
    'subject',(select m.display_name from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.id=c.subject_id),
    'template',r.template,'closesAt',r.closes_at,'appealUntil',r.appeal_until,'releaseAfter',r.release_after,
    'reviewer',reviewer,'canPrepare',(app_private.evaluation_review_assignment(c,actor,'reviewer')).id is not null,
    'canRelease',(app_private.evaluation_review_assignment(c,actor,'releaser')).id is not null,
    'submissions',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'revision',s.revision,'state',s.state,
      'author',(select m.display_name from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.id=s.author_id),
      'own',s.author_id=actor.id,'answers',current.answers,'at',current.submitted_at,
      'history',case when s.author_id=actor.id then (select jsonb_agg(jsonb_build_object('revision',v.revision,'state',v.state,
        'answers',v.answers,'at',v.submitted_at)order by v.revision) from app_private.feedback_revisions v where v.submission_id=s.id) end)
      order by s.id) from app_private.feedback_submissions s join app_private.feedback_revisions current
        on current.submission_id=s.id and current.revision=s.revision
      join app_private.evaluation_assignments assignment on assignment.id=s.assignment_id
      where s.case_id=c.id and ((s.author_id=actor.id and author) or reviewer and s.state='submitted'
        and app_private.evaluation_assignment_live(assignment,c,r))),'[]'::jsonb),
    'notes',case when reviewer then coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'body',n.body,'author',m.display_name,
      'at',n.created_at) order by n.created_at,n.id) from app_private.evaluation_reviewer_notes n
      join public.term_memberships tm on tm.id=n.author_id join public.members m on m.id=tm.member_id where n.case_id=c.id),'[]'::jsonb) else '[]'::jsonb end,
    'releaseDrafts',case when reviewer then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'subjectId',d.subject_id,
      'summary',d.summary,'version',d.case_version,'own',d.prepared_by=actor.id,
      'current',d.case_version=c.version and d.source_hash=app_private.evaluation_source_hash(c)) order by d.created_at desc,d.id)
      from app_private.evaluation_release_drafts d where d.case_id=c.id),'[]'::jsonb) else '[]'::jsonb end) into result;
  return result;
end;
$$;
create function public.read_evaluation_record(p_term_id uuid,p_case_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; result jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,false);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id;
  result:=app_private.evaluation_raw_view(c,actor);
  perform app_private.record_content_read('read_evaluation_record',p_term_id,case when result is not null then c.id end,result is not null);
  return result;
end;
$$;
create function public.export_evaluation_record(p_term_id uuid,p_grant_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; gr app_private.evaluation_export_grants; result jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,false);
  select * into gr from app_private.evaluation_export_grants where id=p_grant_id and term_id=p_term_id
    and membership_id=actor.id and revoked_at is null and expires_at>statement_timestamp();
  select * into c from app_private.evaluation_cases where id=gr.case_id and version=gr.case_version;
  if c.id is not null then result:=app_private.evaluation_raw_view(c,actor);end if;
  perform app_private.record_content_read('export_evaluation_record',p_term_id,case when result is not null then c.id end,result is not null);
  return result;
end;
$$;
create function public.read_evaluation_summary(p_term_id uuid,p_case_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; r app_private.feedback_rounds; e app_private.evaluation_releases;
begin
  actor:=app_private.evaluation_actor(p_term_id,false);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id and subject_id=actor.id;
  if c.id is null then perform app_private.record_content_read('read_evaluation_summary',p_term_id,null,false);return null;end if;
  select * into r from app_private.feedback_rounds where id=c.round_id;
  select * into e from app_private.evaluation_releases where case_id=c.id order by released_at desc,id desc limit 1;
  perform app_private.record_content_read('read_evaluation_summary',p_term_id,c.id,true);
  return jsonb_build_object('caseId',c.id,'round',r.label,'purpose',r.purpose,'state',
    case when e.id is null then 'awaiting_release' when app_private.evaluation_release_current(e,c,r) then 'released' else 'awaiting_updated_summary' end,
    'summary',case when app_private.evaluation_release_current(e,c,r) then e.summary end,
    'releasedAt',case when app_private.evaluation_release_current(e,c,r) then e.released_at end);
end;
$$;
create function public.read_evaluation_workspace(p_term_id uuid,p_page integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; ready boolean; cases jsonb; latest public.privacy_sensitive_categories; notes text;
begin
  actor:=app_private.request_actor(p_term_id,false);
  ready:=app_private.evaluation_policy_ready(p_term_id);
  if p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
  notes:='Authors are identified to authorized PRISM reviewers. Database operators can access stored records for custody and recovery. Downloaded copies follow separate custody and retention controls.';
  if not ready then
    perform app_private.record_content_read('read_evaluation_workspace',p_term_id,null,false);
    return jsonb_build_object('enabled',false,'cases','[]'::jsonb,'hasMore',false,
      'setup','An approved PRISM custodian, purpose and basis, matching published retention rule and reviewer authority are required.',
      'anonymity',notes);
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'version',case when c.subject_id=actor.id then 1 else c.version end,'round',r.label,'purpose',r.purpose,
    'subject',case when c.subject_id=actor.id then null else subject.display_name end,
    'asSubject',c.subject_id=actor.id,'asAuthor',exists(select 1 from app_private.evaluation_assignments a where a.case_id=c.id
      and a.membership_id=actor.id and a.kind='author' and app_private.evaluation_assignment_live(a,c,r)),
    'asReviewer',(app_private.evaluation_review_assignment(c,actor,null)).id is not null,
    'asCustodian',app_private.evaluation_is_custodian(r,actor),
    'authorState',(select s.state from app_private.feedback_submissions s where s.case_id=c.id and s.author_id=actor.id),
    'subjectState',case when c.subject_id=actor.id then case when exists(select 1 from app_private.evaluation_releases e where e.case_id=c.id
      and app_private.evaluation_release_current(e,c,r)) then 'released' else 'awaiting_release' end end,
    'closesAt',r.closes_at,'releaseAfter',r.release_after,'retention',r.retention_rule,
    'reviewRequired',true,'releasePolicy','independent_summary') order by r.created_at desc,c.id),'[]'::jsonb) into cases
  from (select c.* from app_private.evaluation_cases c join app_private.feedback_rounds r on r.id=c.round_id
    where c.term_id=p_term_id and app_private.evaluation_round_live(r) and (c.subject_id=actor.id or app_private.evaluation_is_custodian(r,actor)
      or exists(select 1 from app_private.evaluation_assignments a where a.case_id=c.id and a.membership_id=actor.id
        and app_private.evaluation_assignment_live(a,c,r) and (a.kind='author' or app_private.privacy_strong_session())))
    order by r.created_at desc,c.id limit 31 offset (p_page-1)*30) c
  join app_private.feedback_rounds r on r.id=c.round_id join public.term_memberships tm on tm.id=c.subject_id
  join public.members subject on subject.id=tm.member_id;
  perform app_private.record_content_read('read_evaluation_workspace',p_term_id,null,jsonb_array_length(cases)>0);
  return jsonb_build_object('enabled',true,'setup',null,'anonymity',notes,'hasMore',jsonb_array_length(cases)>30,
    'cases',case when jsonb_array_length(cases)>30 then cases-30 else cases end);
end;
$$;

create function public.create_feedback_round(p_term_id uuid,p_unit_id uuid,p_authority_id uuid,p_label text,p_purpose text,
  p_template jsonb,p_opens_at timestamptz,p_closes_at timestamptz,p_release_after timestamptz,p_appeal_until timestamptz,p_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; r app_private.feedback_rounds; policy public.privacy_sensitive_categories; payload jsonb; prior jsonb; t public.terms;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into policy from public.privacy_sensitive_categories where term_id=p_term_id and category='prism';
  if policy.owner_membership_id<>actor.id or not app_private.privacy_strong_session()
    or not app_private.evaluation_authority(p_term_id,p_unit_id,actor.id,p_authority_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_unit_id,p_authority_id,p_label,p_purpose,p_template,p_opens_at,p_closes_at,p_release_after,p_appeal_until);
  prior:=app_private.begin_work_command('create_feedback_round',p_key,payload);if prior is not null then return prior;end if;
  perform app_private.validate_evaluation_template(p_template);
  select * into t from public.terms where id=p_term_id;
  if coalesce(length(btrim(p_label)),0) not between 1 and 160 or coalesce(length(btrim(p_purpose)),0) not between 1 and 2000
    or p_opens_at is null or p_closes_at is null or p_release_after is null or p_appeal_until is null
    or not (isfinite(p_opens_at) and isfinite(p_closes_at) and isfinite(p_release_after) and isfinite(p_appeal_until))
    or p_closes_at<=greatest(p_opens_at,statement_timestamp()) or p_release_after<p_closes_at or p_appeal_until<p_release_after
    or (p_opens_at at time zone 'Asia/Manila')::date<t.starts_on
    or (p_appeal_until at time zone 'Asia/Manila')::date>t.closes_on then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  insert into app_private.feedback_rounds(term_id,unit_id,custodian_id,authority_id,authority_version,label,purpose,template,
    policy_hash,retention_rule,opens_at,closes_at,release_after,appeal_until)
    select p_term_id,p_unit_id,actor.id,p_authority_id,a.version,btrim(p_label),btrim(p_purpose),p_template,
      app_private.sensitive_category_hash(p_term_id,'prism'),policy.retention_definition->'rules'->0,
      p_opens_at,p_closes_at,p_release_after,p_appeal_until from public.role_assignments a where a.id=p_authority_id returning * into r;
  return app_private.evaluation_receipt(actor,'create_feedback_round',p_key,payload,r.id,1);
end;
$$;
create function public.create_evaluation_case(p_term_id uuid,p_round_id uuid,p_subject_id uuid,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; r app_private.feedback_rounds; c app_private.evaluation_cases; payload jsonb; prior jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into r from app_private.feedback_rounds where id=p_round_id and term_id=p_term_id for update;
  if not app_private.evaluation_is_custodian(r,actor) or actor.id=p_subject_id or not app_private.learning_member(p_term_id,p_subject_id)
    or statement_timestamp()>=r.closes_at then raise exception using errcode='42501',message='command_permission_denied';end if;
  payload:=jsonb_build_array(p_term_id,p_round_id,p_subject_id);
  prior:=app_private.begin_work_command('create_evaluation_case',p_key,payload);if prior is not null then return prior;end if;
  insert into app_private.evaluation_cases(term_id,round_id,subject_id) values(p_term_id,r.id,p_subject_id) returning * into c;
  return app_private.evaluation_receipt(actor,'create_evaluation_case',p_key,payload,c.id,c.version);
end;
$$;

create function public.assign_evaluation_participant(p_term_id uuid,p_case_id uuid,p_expected_version integer,p_member_id uuid,
  p_kind text,p_starts_at timestamptz,p_ends_at timestamptz,p_key uuid,p_authority_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; r app_private.feedback_rounds; a app_private.evaluation_assignments;
  payload jsonb; prior jsonb; authority_version integer;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id for update;
  select * into r from app_private.feedback_rounds where id=c.round_id;
  if not app_private.evaluation_is_custodian(r,actor) or p_member_id in (c.subject_id,r.custodian_id)
    or not app_private.learning_member(p_term_id,p_member_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_case_id,p_expected_version,p_member_id,p_kind,p_starts_at,p_ends_at,p_authority_id);
  prior:=app_private.begin_work_command('assign_evaluation_participant',p_key,payload);if prior is not null then return prior;end if;
  if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  if p_kind is null or p_kind not in ('author','reviewer','releaser') or p_starts_at is null or p_ends_at is null
    or not isfinite(p_starts_at) or not isfinite(p_ends_at) or p_ends_at<=greatest(p_starts_at,statement_timestamp())
    or p_starts_at<r.opens_at or p_ends_at>r.appeal_until
    or (p_kind='author' and (p_authority_id is not null or exists(select 1 from app_private.evaluation_assignments x
      where x.case_id=c.id and x.membership_id=p_member_id and x.kind<>'author')))
    or (p_kind<>'author' and (app_private.evaluation_conflicted(c,p_member_id)
      or not app_private.evaluation_authority(p_term_id,r.unit_id,p_member_id,p_authority_id))) then
    raise exception using errcode='42501',message='command_evaluation_assignment_conflict';
  end if;
  select version into authority_version from public.role_assignments where id=p_authority_id;
  insert into app_private.evaluation_assignments(term_id,case_id,membership_id,kind,authority_id,authority_version,starts_at,ends_at)
    values(p_term_id,c.id,p_member_id,p_kind,p_authority_id,authority_version,p_starts_at,p_ends_at)
    on conflict(case_id,membership_id,kind) do update set authority_id=excluded.authority_id,authority_version=excluded.authority_version,
      starts_at=excluded.starts_at,ends_at=excluded.ends_at,revoked_at=null,conflict_at=null,version=app_private.evaluation_assignments.version+1
    returning * into a;
  update app_private.evaluation_cases set version=version+1 where id=c.id;
  return app_private.evaluation_receipt(actor,'assign_evaluation_participant',p_key,payload,a.id,a.version);
end;
$$;
create function public.end_evaluation_assignment(p_term_id uuid,p_assignment_id uuid,p_expected_version integer,p_conflicted boolean,p_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; r app_private.feedback_rounds; a app_private.evaluation_assignments;
  payload jsonb; prior jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);perform app_private.readiness_lock(p_term_id);
  select * into a from app_private.evaluation_assignments where id=p_assignment_id and term_id=p_term_id;
  select * into c from app_private.evaluation_cases where id=a.case_id for update;
  select * into r from app_private.feedback_rounds where id=c.round_id;
  if a.id is null or not (a.membership_id=actor.id or app_private.evaluation_is_custodian(r,actor)) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  select * into a from app_private.evaluation_assignments where id=p_assignment_id for update;
  payload:=jsonb_build_array(p_term_id,p_assignment_id,p_expected_version,p_conflicted);
  prior:=app_private.begin_work_command('end_evaluation_assignment',p_key,payload);if prior is not null then return prior;end if;
  if a.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  if p_conflicted is null then raise exception using errcode='22023',message='command_validation_failed';end if;
  update app_private.evaluation_assignments set revoked_at=statement_timestamp(),
    conflict_at=case when p_conflicted then statement_timestamp() else conflict_at end,version=version+1 where id=a.id returning * into a;
  update app_private.evaluation_cases set version=version+1 where id=c.id;
  return app_private.evaluation_receipt(actor,'end_evaluation_assignment',p_key,payload,a.id,a.version);
end;
$$;

create function public.submit_evaluation(p_term_id uuid,p_case_id uuid,p_expected_revision integer,p_action text,p_key uuid,
  p_answers jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; c app_private.evaluation_cases; r app_private.feedback_rounds;
  a app_private.evaluation_assignments; s app_private.feedback_submissions; payload jsonb; prior jsonb; field jsonb; answer jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,true);
  select * into c from app_private.evaluation_cases where id=p_case_id and term_id=p_term_id for update;
  select * into r from app_private.feedback_rounds where id=c.round_id;
  select * into a from app_private.evaluation_assignments where case_id=c.id and membership_id=actor.id and kind='author';
  if not app_private.evaluation_assignment_live(a,c,r) then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  select * into s from app_private.feedback_submissions where case_id=c.id and author_id=actor.id for update;
  payload:=jsonb_build_array(p_term_id,p_case_id,p_expected_revision,p_action,p_answers);
  prior:=app_private.begin_work_command('submit_evaluation',p_key,payload);if prior is not null then return prior;end if;
  if coalesce(s.revision,0) is distinct from p_expected_revision then raise exception using errcode='40001',message='command_stale_version';end if;
  if p_action is null or p_action not in ('submit','withdraw') or statement_timestamp()<r.opens_at
    or (p_action='submit' and statement_timestamp()>=case when s.id is null then r.closes_at else r.appeal_until end)
    or (p_action='withdraw' and (s.id is null or s.state='withdrawn' or p_answers is not null)) then
    raise exception using errcode='55000',message='command_evaluation_submission_closed';end if;
  if p_action='submit' then
    if jsonb_typeof(p_answers) is distinct from 'object' or octet_length(p_answers::text)>50000
      or exists(select 1 from jsonb_object_keys(p_answers) k where not exists(select 1 from jsonb_array_elements(r.template) f where f->>'key'=k))
      then raise exception using errcode='22023',message='command_validation_failed';end if;
    for field in select * from jsonb_array_elements(r.template) loop
      answer:=p_answers->(field->>'key');
      if ((field->>'required')::boolean and (answer is null or jsonb_typeof(answer)<>'string' or length(btrim(answer#>>'{}'))=0))
        or (answer is not null and (jsonb_typeof(answer)<>'string' or length(answer#>>'{}')>(field->>'maxLength')::integer)) then
        raise exception using errcode='22023',message='command_validation_failed';end if;
    end loop;
  end if;
  if s.id is null then
    insert into app_private.feedback_submissions(term_id,case_id,author_id,assignment_id,state)
      values(p_term_id,c.id,actor.id,a.id,'submitted') returning * into s;
  else
    update app_private.feedback_submissions set revision=revision+1,state=case when p_action='withdraw' then 'withdrawn' else 'submitted' end
      where id=s.id returning * into s;
  end if;
  insert into app_private.feedback_revisions(submission_id,term_id,revision,state,answers,amended_from)
    values(s.id,p_term_id,s.revision,s.state,p_answers,case when s.revision>1 then s.revision-1 end);
  update app_private.evaluation_cases set version=version+1 where id=c.id;
  return app_private.evaluation_receipt(actor,'submit_evaluation',p_key,payload,s.id,s.revision);
end;
$$;

create function public.read_evaluation_setup(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; policy public.privacy_sensitive_categories; people jsonb; roles jsonb; rounds jsonb;
begin
  actor:=app_private.evaluation_actor(p_term_id,false);
  select * into policy from public.privacy_sensitive_categories where term_id=p_term_id and category='prism';
  if actor.id<>policy.owner_membership_id or not app_private.privacy_strong_session() then
    raise exception using errcode='42501',message='command_permission_denied';end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',tm.id,'name',m.display_name)order by m.display_name,tm.id),'[]'::jsonb) into people
    from public.term_memberships tm join public.members m on m.id=tm.member_id
    where tm.term_id=p_term_id and app_private.learning_member(p_term_id,tm.id);
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'memberId',a.term_membership_id,'unitId',a.unit_id,'unit',u.name)
    order by a.term_membership_id,u.name,a.id),'[]'::jsonb) into roles
    from app_private.effective_role_assignments a join public.org_units u on u.id=a.unit_id
    where a.term_id=p_term_id and app_private.evaluation_authority(p_term_id,a.unit_id,a.term_membership_id,a.id);
  select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'label',r.label,'purpose',r.purpose,'unitId',r.unit_id,
    'opensAt',r.opens_at,'closesAt',r.closes_at,'releaseAfter',r.release_after,'appealUntil',r.appeal_until,
    'template',r.template,'retention',r.retention_rule,
    'cases',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'version',c.version,'subjectId',c.subject_id,
      'assignments',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'version',a.version,'memberId',a.membership_id,
        'kind',a.kind,'active',app_private.evaluation_assignment_live(a,c,r),'startsAt',a.starts_at,'endsAt',a.ends_at,
        'conflicted',a.conflict_at is not null) order by a.kind,a.id)from app_private.evaluation_assignments a where a.case_id=c.id),'[]'::jsonb),
      'exports',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'memberId',g.membership_id,'version',g.case_version,
        'expiresAt',g.expires_at,'revoked',g.revoked_at is not null)order by g.created_at,g.id)
        from app_private.evaluation_export_grants g where g.case_id=c.id),'[]'::jsonb))
      order by c.id)from app_private.evaluation_cases c where c.round_id=r.id),'[]'::jsonb))order by r.created_at desc,r.id),'[]'::jsonb)
    into rounds from app_private.feedback_rounds r where r.term_id=p_term_id and app_private.evaluation_is_custodian(r,actor);
  perform app_private.record_content_read('read_evaluation_setup',p_term_id,null,true);
  return jsonb_build_object('people',people,'authorities',roles,'rounds',rounds);
end;
$$;

alter function app_private.retention_inventory(uuid) rename to retention_inventory_before_evaluations;
create function app_private.retention_inventory(p_term uuid)
returns table(id uuid,category text,kind text,parent_id uuid) language sql stable security definer set search_path='' as $$
  select * from app_private.retention_inventory_before_evaluations(p_term)
  union all select r.id,'prism','record',null::uuid from app_private.feedback_rounds r where r.term_id=p_term
  union all select c.id,'prism','record',c.round_id from app_private.evaluation_cases c where c.term_id=p_term
  union all select s.id,'prism','record',s.case_id from app_private.feedback_submissions s where s.term_id=p_term
  union all select n.id,'prism','record',n.case_id from app_private.evaluation_reviewer_notes n where n.term_id=p_term
  union all select e.id,'prism','record',e.case_id from app_private.evaluation_releases e where e.term_id=p_term;
$$;

-- Walk only the fixed evaluation ancestry for holds on cases and rounds.
create function app_private.evaluation_hold(p_term uuid,p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from app_private.evaluation_cases c
    where c.term_id=p_term and (c.id=p_id or exists(select 1 from app_private.feedback_submissions s where s.id=p_id and s.case_id=c.id))
      and app_private.retention_is_held(p_term,'prism',c.id,c.round_id));
$$;

create function app_private.evaluation_retention_round(p_term uuid,p_id uuid) returns app_private.feedback_rounds
language sql stable set search_path='' as $$
  select r.* from app_private.feedback_rounds r where r.term_id=p_term and (
    r.id=p_id or exists(select 1 from app_private.evaluation_cases c where c.round_id=r.id and (
      c.id=p_id or exists(select 1 from app_private.feedback_submissions s where s.case_id=c.id and s.id=p_id)
      or exists(select 1 from app_private.evaluation_reviewer_notes n where n.case_id=c.id and n.id=p_id)
      or exists(select 1 from app_private.evaluation_releases e where e.case_id=c.id and e.id=p_id))))
  limit 1;
$$;
alter function public.read_retention_review(uuid,integer) rename to read_retention_before_evaluations;
alter function public.read_retention_before_evaluations(uuid,integer) set schema app_private;
create function public.read_retention_review(p_term_id uuid,p_page integer default 1) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; item jsonb; items jsonb:='[]'::jsonb; r app_private.feedback_rounds; review_on date; allowed boolean; held boolean;
begin
  result:=app_private.read_retention_before_evaluations(p_term_id,p_page);
  for item in select * from jsonb_array_elements(result->'items') loop
    if item->>'category'='prism' then
      r:=app_private.evaluation_retention_round(p_term_id,(item->>'id')::uuid);
      if r.id is not null then
        allowed:=(result->>'policyApproved')::boolean and exists(
          select 1 from jsonb_array_elements(result->'definition'->'rules') rule where rule=r.retention_rule);
        review_on:=(r.appeal_until at time zone 'Asia/Manila')::date+(r.retention_rule->>'days')::integer;
        held:=app_private.retention_is_held(p_term_id,'prism',(item->>'id')::uuid,r.id)
          or app_private.evaluation_hold(p_term_id,(item->>'id')::uuid);
        item:=item||jsonb_build_object('reviewOn',to_char(review_on,'YYYY-MM-DD'),'action',
          case when held then 'held' when not allowed then 'blocked_policy'
            when (statement_timestamp() at time zone 'Asia/Manila')::date<review_on then 'not_due'
            else r.retention_rule->>'action' end);
      end if;
    end if;
    items:=items||jsonb_build_array(item);
  end loop;
  return result||jsonb_build_object('items',items);
end;
$$;

insert into public.restricted_read_endpoints(endpoint,argument_types) values
  ('read_evaluation_workspace','uuid, integer'),('read_evaluation_setup','uuid'),('read_evaluation_record','uuid, uuid'),
  ('read_evaluation_summary','uuid, uuid'),('export_evaluation_record','uuid, uuid');

revoke all on function app_private.retention_inventory_before_evaluations(uuid),app_private.retention_inventory(uuid),
  app_private.evaluation_hold(uuid,uuid),app_private.read_retention_before_evaluations(uuid,integer),
  public.read_retention_review(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function public.read_retention_review(uuid,integer) to authenticated;
do $$declare f record;
begin
  for f in select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app_private' and (p.proname like 'evaluation_%' or p.proname='validate_evaluation_template')
      or n.nspname='public' and p.proname in ('create_feedback_round','create_evaluation_case','assign_evaluation_participant',
        'end_evaluation_assignment','submit_evaluation','append_evaluation_note','prepare_evaluation_release',
        'publish_evaluation_release','grant_evaluation_export','revoke_evaluation_export','read_evaluation_workspace',
        'read_evaluation_setup','read_evaluation_record','read_evaluation_summary','export_evaluation_record')
  loop
    execute format('revoke all on function %I.%I(%s) from public,anon,authenticated,service_role',f.nspname,f.proname,f.args);
    if f.nspname='public' then execute format('grant execute on function public.%I(%s) to authenticated',f.proname,f.args);end if;
  end loop;
end;
$$;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,'prism','term',array['id'],
  format('select app_private.disposition_key(%L,array[x.id::text]) target_hash,''prism'' category,%s root_id,
    (app_private.retention_is_held($1,''prism'',x.id,%s) or app_private.evaluation_hold($1,%s)) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x where x.term_id=$1',
    'app_private.'||source,root_expr,root_expr,root_expr,source),
  app_private.disposition_structure('app_private.'||source),false
from (values
  ('feedback_rounds','x.id'),('evaluation_cases','x.id'),('evaluation_assignments','x.case_id'),
  ('feedback_submissions','x.case_id'),('evaluation_reviewer_notes','x.case_id'),
  ('evaluation_release_drafts','x.case_id'),('evaluation_releases','x.case_id'),('evaluation_export_grants','x.case_id')
) definitions(source,root_expr);
insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
values('app_private.feedback_revisions','prism','term',array['submission_id','revision'],
  $query$select app_private.disposition_key('app_private.feedback_revisions',array[x.submission_id::text,x.revision::text]) target_hash,
    'prism' category,s.case_id root_id,
    (app_private.retention_is_held($1,'prism',x.submission_id,s.case_id) or app_private.evaluation_hold($1,s.case_id)) held,
    encode(sha256(convert_to(to_jsonb(x)::text,'UTF8')),'hex') state_hash
    from app_private.feedback_revisions x join app_private.feedback_submissions s on s.id=x.submission_id where x.term_id=$1$query$,
  app_private.disposition_structure('app_private.feedback_revisions'),false),
('app_private.evaluation_events','security','term',array['id'],
  $query$select app_private.disposition_key('app_private.evaluation_events',array[x.id::text]) target_hash,'security' category,
    x.object_id root_id,app_private.retention_is_held($1,'security',x.id,x.object_id) held,
    encode(sha256(convert_to(to_jsonb(x)::text,'UTF8')),'hex') state_hash
    from app_private.evaluation_events x where x.term_id=$1$query$,
  app_private.disposition_structure('app_private.evaluation_events'),true);
commit;
