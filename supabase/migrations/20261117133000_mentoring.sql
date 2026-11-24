begin;

-- Learning uses the existing retention category and has no emergency access path.
alter table public.privacy_sensitive_categories drop constraint privacy_sensitive_categories_category_check,
  alter column max_emergency_minutes drop not null,
  add constraint privacy_sensitive_categories_category_check check(category in ('finance','prism','learning')),
  add constraint privacy_sensitive_categories_emergency_category check((category='learning')=(max_emergency_minutes is null));
update app_private.disposition_sources set structure_hash=app_private.disposition_structure(source_key)
  where source_key='public.privacy_sensitive_categories';

create table app_private.mentorships (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id),
  mentee_id uuid not null references public.term_memberships(id),
  mentor_id uuid not null references public.term_memberships(id),
  approved_by uuid not null references public.term_memberships(id),
  starts_at timestamptz not null check(isfinite(starts_at)),
  ends_at timestamptz not null check(isfinite(ends_at) and ends_at>starts_at),
  approval_reference text not null check(length(btrim(approval_reference)) between 3 and 500),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check(version>0),
  check(mentee_id<>mentor_id and approved_by not in (mentee_id,mentor_id)),
  unique(term_id,id),
  unique(term_id,mentee_id,id)
);
create index mentorships_mentee on app_private.mentorships(term_id,mentee_id,ends_at);
create index mentorships_mentor on app_private.mentorships(term_id,mentor_id,ends_at);

create table app_private.learning_goals (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id),
  owner_id uuid not null references public.term_memberships(id),
  title text not null check(length(btrim(title)) between 1 and 160 and title !~ '[[:cntrl:]]'),
  category text not null check(category in ('personal','skills','collaboration','role')),
  target text check(length(btrim(target)) between 1 and 1000),
  progress integer not null check(progress between 0 and 100),
  shared_with uuid,
  updated_at timestamptz not null default statement_timestamp(),
  version integer not null default 1 check(version>0),
  foreign key(term_id,owner_id,shared_with) references app_private.mentorships(term_id,mentee_id,id)
);
create index learning_goals_owner on app_private.learning_goals(term_id,owner_id);
create index learning_goals_shared on app_private.learning_goals(shared_with) where shared_with is not null;

create table app_private.learning_checkins (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  mentorship_id uuid not null,
  title text check(length(btrim(title)) between 1 and 160 and title !~ '[[:cntrl:]]'),
  starts_at timestamptz not null check(isfinite(starts_at)),
  ends_at timestamptz not null check(isfinite(ends_at) and ends_at>starts_at and ends_at-starts_at<=interval '2 hours'),
  state text not null default 'scheduled' check(state in ('scheduled','completed','cancelled','missed')),
  version integer not null default 1 check(version>0),
  updated_at timestamptz not null default statement_timestamp(),
  foreign key(term_id,mentorship_id) references app_private.mentorships(term_id,id),
  unique(term_id,id)
);
create index learning_checkins_mentorship on app_private.learning_checkins(mentorship_id,starts_at);

create table app_private.learning_notes (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null,
  checkin_id uuid not null,
  author_id uuid not null references public.term_memberships(id),
  author_name text not null,
  body text check(length(btrim(body)) between 1 and 2000),
  next_action text check(length(btrim(next_action)) between 1 and 1000),
  recorded_at timestamptz not null default clock_timestamp(),
  foreign key(term_id,checkin_id) references app_private.learning_checkins(term_id,id),
  check(body is not null or next_action is not null)
);
create index learning_notes_checkin on app_private.learning_notes(checkin_id,recorded_at);

create table app_private.learning_events (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.terms(id),
  object_id uuid not null,
  actor_id uuid not null references auth.users(id),
  operation text not null check(operation in ('approve_mentorship','respond_mentorship','save_learning_goal',
    'share_learning_goal','save_learning_checkin','append_learning_note')),
  version integer not null check(version>0),
  recorded_at timestamptz not null default clock_timestamp()
);

do $$declare relation text;
begin
  foreach relation in array array['mentorships','learning_goals','learning_checkins','learning_notes','learning_events'] loop
    execute format('alter table app_private.%I enable row level security',relation);
    execute format('alter table app_private.%I force row level security',relation);
    execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',relation);
  end loop;
end $$;
create trigger immutable_learning_notes before update or delete on app_private.learning_notes
  for each row execute function app_private.request_history_guard();
create trigger immutable_learning_events before update or delete on app_private.learning_events
  for each row execute function app_private.request_history_guard();

create function app_private.learning_ready(p_term uuid) returns boolean language sql stable set search_path='' as $$
  select app_private.sensitive_category_ready(p_term,'learning') and not app_private.disposition_replay_required(p_term)
    and exists(select 1 from public.privacy_sensitive_categories category
      cross join lateral (
        select v.definition,v.actor_id from public.presentation_controls c join public.presentation_versions v on v.control_id=c.work_item_id
        join public.work_items w on w.id=c.work_item_id and w.archived_at is null
        where c.term_id=p_term and c.kind='retention' order by v.version desc limit 1
      ) published
      where category.term_id=p_term and category.category='learning'
        and app_private.retention_approved(p_term,published.definition,(select tm.id from public.term_memberships tm
          join public.members m on m.id=tm.member_id where tm.term_id=p_term and m.auth_user_id=published.actor_id))
        and exists(select 1 from jsonb_array_elements(published.definition->'rules') rule
          where rule=category.retention_definition->'rules'->0));
$$;

create function app_private.learning_actor(p_term uuid,p_write boolean default false) returns public.term_memberships
language plpgsql set search_path='' as $$
declare actor public.term_memberships;
begin
  actor:=app_private.request_actor(p_term,p_write);
  if p_write then perform app_private.readiness_lock(p_term); end if;
  if not app_private.learning_ready(p_term) then
    raise exception using errcode='55000',message='command_learning_unavailable';
  end if;
  return actor;
end;
$$;

create function app_private.learning_member(p_term uuid,p_member uuid) returns boolean language sql stable set search_path='' as $$
  select exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id
    where tm.term_id=p_term and tm.id=p_member and tm.membership_kind='core' and tm.status='active'
      and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
      and m.account_state='active' and m.auth_user_id is not null
      and exists(select 1 from app_private.effective_role_assignments a join public.role_permissions p on p.role_id=a.role_id
        where a.term_membership_id=tm.id and a.scope_type='term' and p.allowed_scope='term' and p.capability='workspace.read'
          and app_private.access_assignment_live(a.id)));
$$;

create function app_private.learning_mentor(p_term uuid,p_member uuid) returns boolean language sql stable set search_path='' as $$
  select app_private.learning_member(p_term,p_member) and exists(
    select 1 from app_private.effective_role_assignments a join public.role_permissions p on p.role_id=a.role_id
    where a.term_membership_id=p_member and a.term_id=p_term and a.scope_type='own'
      and p.capability='mentoring.view' and p.allowed_scope='own' and app_private.access_assignment_live(a.id));
$$;

create function app_private.learning_coordinator(actor public.term_memberships) returns boolean
language sql stable set search_path='' as $$
  select app_private.privacy_strong_session() and exists(select 1 from public.privacy_sensitive_categories c
    where c.term_id=actor.term_id and c.category='learning' and c.owner_membership_id=actor.id);
$$;

create function app_private.mentorship_available(m app_private.mentorships) returns boolean
language sql stable set search_path='' as $$
  select coalesce(m.revoked_at is null and m.ends_at>statement_timestamp()
    and app_private.learning_mentor(m.term_id,m.mentor_id) and app_private.learning_member(m.term_id,m.mentee_id),false);
$$;

create function app_private.mentorship_live(m app_private.mentorships) returns boolean
language sql stable set search_path='' as $$
  select coalesce(m.accepted_at is not null and m.starts_at<=statement_timestamp() and app_private.mentorship_available(m),false);
$$;

create function app_private.learning_receipt(actor public.term_memberships,p_command text,p_key uuid,p_payload jsonb,
  p_object uuid,p_version integer) returns jsonb language plpgsql set search_path='' as $$
declare result jsonb:=jsonb_build_object('id',p_object,'version',p_version);
begin
  insert into app_private.learning_events(term_id,object_id,actor_id,operation,version)
    values(actor.term_id,p_object,auth.uid(),p_command,p_version);
  insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)
    values(auth.uid(),p_command,p_key,actor.organization_id,actor.term_id,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),result);
  return result;
end;
$$;

create function public.approve_mentorship(p_term_id uuid,p_mentee_id uuid,p_mentor_id uuid,p_starts_at timestamptz,p_ends_at timestamptz,
  p_approval_reference text,p_key uuid,p_previous_id uuid default null,p_expected_version integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; m app_private.mentorships; t public.terms; payload jsonb; prior jsonb;
begin
  actor:=app_private.learning_actor(p_term_id,true);
  if not app_private.learning_coordinator(actor) or actor.id in (p_mentee_id,p_mentor_id)
    or p_mentee_id=p_mentor_id or not app_private.learning_member(p_term_id,p_mentee_id)
    or not app_private.learning_mentor(p_term_id,p_mentor_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_mentee_id,p_mentor_id,p_starts_at,p_ends_at,p_approval_reference,p_previous_id,p_expected_version);
  prior:=app_private.begin_work_command('approve_mentorship',p_key,payload);
  if prior is not null then return prior; end if;
  select * into t from public.terms where id=p_term_id;
  if p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at)
    or p_ends_at<=greatest(p_starts_at,statement_timestamp()) or (p_starts_at at time zone 'Asia/Manila')::date<t.starts_on
    or ((p_ends_at-interval '1 microsecond') at time zone 'Asia/Manila')::date>t.closes_on
    or coalesce(length(btrim(p_approval_reference)),0) not between 3 and 500 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  if p_previous_id is not null then
    select * into m from app_private.mentorships where term_id=p_term_id and id=p_previous_id and mentee_id=p_mentee_id for update;
    if m.id is null or actor.id=m.mentor_id then raise exception using errcode='42501',message='command_permission_denied'; end if;
    if p_expected_version is distinct from m.version then raise exception using errcode='40001',message='command_stale_version'; end if;
    if m.revoked_at is null then
      update app_private.mentorships set revoked_at=statement_timestamp(),version=version+1 where id=m.id returning * into m;
      insert into app_private.learning_events(term_id,object_id,actor_id,operation,version)
        values(p_term_id,m.id,auth.uid(),'respond_mentorship',m.version);
    end if;
  elsif p_expected_version is not null then raise exception using errcode='22023',message='command_validation_failed'; end if;
  if exists(select 1 from app_private.mentorships r where r.term_id=p_term_id and r.mentee_id=p_mentee_id
    and r.mentor_id=p_mentor_id and r.revoked_at is null and tstzrange(r.starts_at,r.ends_at,'[)')&&tstzrange(p_starts_at,p_ends_at,'[)')) then
    raise exception using errcode='23505',message='command_mentorship_overlap';
  end if;
  insert into app_private.mentorships(term_id,mentee_id,mentor_id,approved_by,starts_at,ends_at,approval_reference)
    values(p_term_id,p_mentee_id,p_mentor_id,actor.id,p_starts_at,p_ends_at,btrim(p_approval_reference)) returning * into m;
  return app_private.learning_receipt(actor,'approve_mentorship',p_key,payload,m.id,m.version);
end;
$$;

create function public.respond_mentorship(p_term_id uuid,p_mentorship_id uuid,p_expected_version integer,p_accept boolean,p_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; m app_private.mentorships; payload jsonb; prior jsonb;
begin
  if p_accept then actor:=app_private.learning_actor(p_term_id,true);
  else actor:=app_private.request_actor(p_term_id,false);perform app_private.readiness_lock(p_term_id);end if;
  select * into m from app_private.mentorships where term_id=p_term_id and id=p_mentorship_id for update;
  if m.id is null or p_accept is null
    or (p_accept and actor.id<>m.mentee_id)
    or (not p_accept and actor.id not in (m.mentee_id,m.mentor_id) and not app_private.learning_coordinator(actor)) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_mentorship_id,p_expected_version,p_accept);
  prior:=app_private.begin_work_command('respond_mentorship',p_key,payload);
  if prior is not null then return prior; end if;
  if p_expected_version is distinct from m.version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if m.revoked_at is not null or (p_accept and (m.accepted_at is not null or not app_private.mentorship_available(m))) then
    raise exception using errcode='55000',message='command_mentorship_changed';
  end if;
  update app_private.mentorships set accepted_at=case when p_accept then statement_timestamp() else accepted_at end,
    revoked_at=case when p_accept then null else statement_timestamp() end,version=version+1
    where id=m.id returning * into m;
  return app_private.learning_receipt(actor,'respond_mentorship',p_key,payload,m.id,m.version);
end;
$$;

create function public.save_learning_goal(p_term_id uuid,p_expected_version integer,p_title text,p_category text,p_progress integer,
  p_key uuid,p_goal_id uuid default null,p_target text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; g app_private.learning_goals; payload jsonb; prior jsonb;
begin
  actor:=app_private.learning_actor(p_term_id,true);
  if p_goal_id is not null then
    select * into g from app_private.learning_goals where id=p_goal_id and term_id=p_term_id and owner_id=actor.id for update;
    if g.id is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  end if;
  payload:=jsonb_build_array(p_term_id,p_goal_id,p_expected_version,p_title,p_category,p_progress,p_target);
  prior:=app_private.begin_work_command('save_learning_goal',p_key,payload);
  if prior is not null then return prior; end if;
  if coalesce(g.version,0) is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if coalesce(length(btrim(p_title)),0) not between 1 and 160 or p_title ~ '[[:cntrl:]]'
    or p_category is null or p_category not in ('personal','skills','collaboration','role')
    or p_progress is null or p_progress not between 0 and 100 or length(btrim(p_target))>1000 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  if g.id is null then
    insert into app_private.learning_goals(term_id,owner_id,title,category,target,progress)
      values(p_term_id,actor.id,btrim(p_title),p_category,nullif(btrim(p_target),''),p_progress) returning * into g;
  else
    update app_private.learning_goals set title=btrim(p_title),category=p_category,target=nullif(btrim(p_target),''),
      progress=p_progress,version=version+1,updated_at=statement_timestamp() where id=g.id returning * into g;
  end if;
  return app_private.learning_receipt(actor,'save_learning_goal',p_key,payload,g.id,g.version);
end;
$$;

create function public.share_learning_goal(p_term_id uuid,p_goal_id uuid,p_expected_version integer,p_key uuid,
  p_mentorship_id uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; g app_private.learning_goals; m app_private.mentorships; payload jsonb; prior jsonb;
begin
  if p_mentorship_id is not null then actor:=app_private.learning_actor(p_term_id,true);
  else actor:=app_private.request_actor(p_term_id,false);perform app_private.readiness_lock(p_term_id);end if;
  select * into g from app_private.learning_goals where id=p_goal_id and term_id=p_term_id and owner_id=actor.id for update;
  if g.id is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  payload:=jsonb_build_array(p_term_id,p_goal_id,p_expected_version,p_mentorship_id);
  prior:=app_private.begin_work_command('share_learning_goal',p_key,payload);
  if prior is not null then return prior; end if;
  if p_expected_version is distinct from g.version then raise exception using errcode='40001',message='command_stale_version'; end if;
  if p_mentorship_id is not null then
    select * into m from app_private.mentorships where id=p_mentorship_id and term_id=p_term_id and mentee_id=actor.id;
    if not app_private.mentorship_live(m) then raise exception using errcode='42501',message='command_permission_denied'; end if;
  end if;
  update app_private.learning_goals set shared_with=p_mentorship_id,version=version+1,updated_at=statement_timestamp()
    where id=g.id returning * into g;
  return app_private.learning_receipt(actor,'share_learning_goal',p_key,payload,g.id,g.version);
end;
$$;

create function public.save_learning_checkin(p_term_id uuid,p_mentorship_id uuid,p_expected_version integer,
  p_action text,p_key uuid,p_checkin_id uuid default null,p_starts_at timestamptz default null,p_ends_at timestamptz default null,
  p_title text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; m app_private.mentorships; c app_private.learning_checkins; payload jsonb; prior jsonb;
begin
  actor:=app_private.learning_actor(p_term_id,true);
  select * into m from app_private.mentorships where id=p_mentorship_id and term_id=p_term_id;
  if not app_private.mentorship_live(m) or actor.id not in (m.mentor_id,m.mentee_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  if p_checkin_id is not null then
    select * into c from app_private.learning_checkins where id=p_checkin_id and term_id=p_term_id and mentorship_id=m.id for update;
    if c.id is null then raise exception using errcode='42501',message='command_permission_denied'; end if;
  end if;
  payload:=jsonb_build_array(p_term_id,p_mentorship_id,p_expected_version,p_action,p_checkin_id,p_starts_at,p_ends_at,p_title);
  prior:=app_private.begin_work_command('save_learning_checkin',p_key,payload);
  if prior is not null then return prior; end if;
  if p_expected_version is distinct from coalesce(c.version,0) then
    raise exception using errcode='40001',message='command_stale_version';
  end if;
  if p_action='schedule' then
    if p_starts_at is null or p_ends_at is null or not isfinite(p_starts_at) or not isfinite(p_ends_at)
      or p_starts_at<=statement_timestamp() or p_starts_at<m.starts_at or p_ends_at>m.ends_at
      or p_ends_at<=p_starts_at or p_ends_at-p_starts_at>interval '2 hours'
      or length(btrim(p_title))>160 or p_title ~ '[[:cntrl:]]' then
      raise exception using errcode='22023',message='command_learning_time_invalid';
    end if;
    if c.id is null then
      insert into app_private.learning_checkins(term_id,mentorship_id,title,starts_at,ends_at)
        values(p_term_id,m.id,nullif(btrim(p_title),''),p_starts_at,p_ends_at) returning * into c;
    elsif c.state='scheduled' and c.starts_at>statement_timestamp() then
      update app_private.learning_checkins set title=nullif(btrim(p_title),''),starts_at=p_starts_at,ends_at=p_ends_at,
        version=version+1,updated_at=statement_timestamp() where id=c.id returning * into c;
    else raise exception using errcode='55000',message='command_learning_checkin_changed'; end if;
  else
    if c.id is null or c.state<>'scheduled' or p_action is null or p_action not in ('completed','cancelled','missed')
      or p_starts_at is not null or p_ends_at is not null or p_title is not null
      or (p_action='completed' and c.starts_at>statement_timestamp())
      or (p_action='missed' and c.ends_at>statement_timestamp()) then
      raise exception using errcode='55000',message='command_learning_checkin_changed';
    end if;
    update app_private.learning_checkins set state=p_action,version=version+1,updated_at=statement_timestamp()
      where id=c.id returning * into c;
  end if;
  return app_private.learning_receipt(actor,'save_learning_checkin',p_key,payload,c.id,c.version);
end;
$$;

create function public.append_learning_note(p_term_id uuid,p_checkin_id uuid,p_expected_version integer,p_key uuid,
  p_body text default null,p_next_action text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; m app_private.mentorships; c app_private.learning_checkins; payload jsonb; prior jsonb;
begin
  actor:=app_private.learning_actor(p_term_id,true);
  select * into c from app_private.learning_checkins where id=p_checkin_id and term_id=p_term_id for update;
  select * into m from app_private.mentorships where id=c.mentorship_id;
  if not app_private.mentorship_live(m) or actor.id not in (m.mentee_id,m.mentor_id) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  payload:=jsonb_build_array(p_term_id,p_checkin_id,p_expected_version,p_body,p_next_action);
  prior:=app_private.begin_work_command('append_learning_note',p_key,payload);
  if prior is not null then return prior; end if;
  if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  if c.state='cancelled' then raise exception using errcode='55000',message='command_learning_checkin_changed';end if;
  if (nullif(btrim(p_body),'') is null and nullif(btrim(p_next_action),'') is null)
    or length(btrim(p_body))>2000 or length(btrim(p_next_action))>1000 then
    raise exception using errcode='22023',message='command_validation_failed';
  end if;
  insert into app_private.learning_notes(term_id,checkin_id,author_id,author_name,body,next_action)
    select p_term_id,c.id,actor.id,member.display_name,nullif(btrim(p_body),''),nullif(btrim(p_next_action),'')
    from public.members member where member.id=actor.member_id;
  update app_private.learning_checkins set version=version+1,updated_at=statement_timestamp()
    where id=c.id returning * into c;
  return app_private.learning_receipt(actor,'append_learning_note',p_key,payload,c.id,c.version);
end;
$$;

create function app_private.learning_relationship_view(r app_private.mentorships) returns jsonb
language sql stable set search_path='' as $$
  select jsonb_build_object('id',r.id,'version',r.version,'mentor',mentor.display_name,'mentee',mentee.display_name,
    'startsAt',r.starts_at,'endsAt',r.ends_at,'state',case when not app_private.mentorship_available(r) then 'ended'
      when r.accepted_at is null then 'offered' when r.starts_at>statement_timestamp() then 'upcoming' else 'active' end)
  from public.term_memberships mt join public.members mentor on mentor.id=mt.member_id
  cross join public.term_memberships me join public.members mentee on mentee.id=me.member_id
  where mt.id=r.mentor_id and me.id=r.mentee_id;
$$;

create function public.read_learning_entry(p_term_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare enabled boolean;
begin
  perform app_private.request_actor(p_term_id,false);
  enabled:=app_private.learning_ready(p_term_id);
  perform app_private.record_content_read('read_learning_entry',p_term_id,null,enabled);
  return enabled;
end;
$$;

create function public.read_learning_workspace(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; t public.terms; goals jsonb; checkins jsonb; relationships jsonb;
begin
  actor:=app_private.request_actor(p_term_id,false);
  if not app_private.learning_ready(p_term_id) then
    perform app_private.record_content_read('read_learning_workspace',p_term_id,null,false);
    return null;
  end if;
  select * into t from public.terms where id=p_term_id;
  select coalesce(jsonb_agg(app_private.learning_relationship_view(r)||jsonb_build_object('asMentor',r.mentor_id=actor.id)
    order by r.starts_at desc,r.id),'[]'::jsonb) into relationships from app_private.mentorships r
    where r.term_id=p_term_id and (r.mentee_id=actor.id or r.mentor_id=actor.id and app_private.mentorship_live(r));
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'title',g.title,'category',g.category,'target',g.target,
    'progress',g.progress,'version',g.version,'own',g.owner_id=actor.id,
    'sharedWith',case when app_private.mentorship_live(r) then r.id end,
    'hasSharingRecord',g.owner_id=actor.id and g.shared_with is not null,
    'learner',case when g.owner_id<>actor.id then learner.display_name end)
    order by g.updated_at desc,g.id),'[]'::jsonb) into goals
  from app_private.learning_goals g left join app_private.mentorships r on r.id=g.shared_with
  join public.term_memberships m on m.id=g.owner_id join public.members learner on learner.id=m.member_id
  where g.term_id=p_term_id and (g.owner_id=actor.id or r.mentor_id=actor.id and app_private.mentorship_live(r));
  select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'relationship',r.id,'title',c.title,'startsAt',c.starts_at,'endsAt',c.ends_at,
    'state',case when c.state='scheduled' and not app_private.mentorship_live(r) then 'ended' else c.state end,
    'version',c.version,'canAct',t.state='active' and app_private.mentorship_live(r),
    'canExport',c.state='scheduled' and c.ends_at>statement_timestamp() and app_private.mentorship_live(r),
    'notes',coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'author',n.author_name,'body',n.body,
      'nextAction',n.next_action,'at',n.recorded_at)order by n.recorded_at,n.id)
      from app_private.learning_notes n where n.checkin_id=c.id),'[]'::jsonb))
    order by (c.state='scheduled' and app_private.mentorship_live(r) and c.ends_at>statement_timestamp()) desc,c.starts_at,c.id),'[]'::jsonb)
    into checkins from app_private.learning_checkins c join app_private.mentorships r on r.id=c.mentorship_id
    where c.term_id=p_term_id and (r.mentee_id=actor.id or r.mentor_id=actor.id and app_private.mentorship_live(r));
  perform app_private.record_content_read('read_learning_workspace',p_term_id,null,true);
  return jsonb_build_object('termLabel',t.label,'editable',t.state='active',
    'canManage',t.state='active' and app_private.learning_coordinator(actor),
    'relationships',relationships,'goals',goals,'checkins',checkins);
end;
$$;

create function public.read_mentoring_assignments(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; people jsonb; relationships jsonb;
begin
  actor:=app_private.learning_actor(p_term_id,false);
  if not app_private.learning_coordinator(actor) then raise exception using errcode='42501',message='command_permission_denied';end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',person.display_name,
      'mentor',app_private.learning_mentor(p_term_id,m.id))order by person.display_name,m.id),'[]'::jsonb)
    into people from public.term_memberships m join public.members person on person.id=m.member_id
    where m.term_id=p_term_id and m.id<>actor.id and app_private.learning_member(p_term_id,m.id);
  select coalesce(jsonb_agg(app_private.learning_relationship_view(r)||jsonb_build_object('menteeId',r.mentee_id,
      'mentorId',r.mentor_id,'revoked',r.revoked_at is not null) order by r.starts_at desc,r.id),'[]'::jsonb)
    into relationships from app_private.mentorships r where r.term_id=p_term_id;
  perform app_private.record_content_read('read_mentoring_assignments',p_term_id,null,true);
  return jsonb_build_object('people',people,'assignments',relationships);
end;
$$;

-- This projection is reachable only through a deliberate single-calendar export
-- action. The data has no names, captions, notes, contacts or appointment links.
create function public.export_learning_checkin(p_term_id uuid,p_checkin_id uuid,p_expected_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; m app_private.mentorships; c app_private.learning_checkins;
begin
  actor:=app_private.learning_actor(p_term_id,false);
  select * into c from app_private.learning_checkins where id=p_checkin_id and term_id=p_term_id;
  select * into m from app_private.mentorships where id=c.mentorship_id;
  if not app_private.mentorship_live(m) or actor.id not in (m.mentee_id,m.mentor_id) then
    perform app_private.record_content_read('export_learning_checkin',p_term_id,null,false);return null;
  end if;
  if c.version is distinct from p_expected_version or c.state<>'scheduled' or c.ends_at<=statement_timestamp() then
    raise exception using errcode='40001',message='command_stale_version';
  end if;
  perform app_private.record_content_read('export_learning_checkin',p_term_id,c.id,true);
  return jsonb_build_object('uid',md5('private-learning-calendar:'||actor.id::text||':'||c.id::text)::uuid,
    'version',c.version,'startsAt',c.starts_at,'endsAt',c.ends_at,'updatedAt',c.updated_at);
end;
$$;

create function public.export_learning_record(p_term_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships; goals jsonb; notes jsonb;
begin
  actor:=app_private.learning_actor(p_term_id,false);
  select coalesce(jsonb_agg(jsonb_build_object('title',g.title,'category',g.category,'target',g.target,
    'progress',g.progress,'updatedAt',g.updated_at)order by g.updated_at,g.id),'[]'::jsonb)
    into goals from app_private.learning_goals g where g.term_id=p_term_id and g.owner_id=actor.id;
  select coalesce(jsonb_agg(jsonb_build_object('body',n.body,'nextAction',n.next_action,'recordedAt',n.recorded_at,
    'checkinStartsAt',c.starts_at)order by n.recorded_at,n.id),'[]'::jsonb) into notes
    from app_private.learning_notes n join app_private.learning_checkins c on c.id=n.checkin_id
    join app_private.mentorships r on r.id=c.mentorship_id
    where n.term_id=p_term_id and n.author_id=actor.id and
      (r.mentee_id=actor.id or r.mentor_id=actor.id and app_private.mentorship_live(r));
  perform app_private.record_content_read('export_learning_record',p_term_id,null,true);
  return jsonb_build_object('exportedAt',statement_timestamp(),'goals',goals,'authoredNotes',notes);
end;
$$;

alter function app_private.retention_inventory(uuid) rename to retention_inventory_before_learning;
create function app_private.retention_inventory(p_term uuid)
returns table(id uuid,category text,kind text,parent_id uuid) language sql stable security definer set search_path='' as $$
  select * from app_private.retention_inventory_before_learning(p_term)
  union all select m.id,'learning','record',null::uuid from app_private.mentorships m where m.term_id=p_term
  union all select g.id,'learning','record',null::uuid from app_private.learning_goals g where g.term_id=p_term
  union all select c.id,'learning','record',c.mentorship_id from app_private.learning_checkins c where c.term_id=p_term
  union all select n.id,'learning','record',n.checkin_id from app_private.learning_notes n where n.term_id=p_term;
$$;

alter function app_private.retention_is_held(uuid,text,uuid,uuid) rename to retention_is_held_before_learning;
create function app_private.retention_is_held(p_term uuid,p_category text,p_id uuid,p_parent uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select app_private.retention_is_held_before_learning(p_term,p_category,p_id,p_parent)
    or (p_category='learning' and exists(select 1 from app_private.learning_checkins c
      where c.term_id=p_term and c.id=p_parent
        and app_private.retention_is_held_before_learning(p_term,'learning',c.mentorship_id,null)));
$$;

insert into public.restricted_read_endpoints(endpoint,argument_types) values
  ('read_learning_entry','uuid'),('read_learning_workspace','uuid'),('read_mentoring_assignments','uuid'),
  ('export_learning_checkin','uuid, uuid, integer'),('export_learning_record','uuid');

revoke all on function app_private.learning_ready(uuid),app_private.learning_actor(uuid,boolean),app_private.learning_member(uuid,uuid),
  app_private.learning_mentor(uuid,uuid),app_private.learning_coordinator(public.term_memberships),
  app_private.mentorship_available(app_private.mentorships),app_private.mentorship_live(app_private.mentorships),
  app_private.learning_receipt(public.term_memberships,text,uuid,jsonb,uuid,integer),
  app_private.learning_relationship_view(app_private.mentorships),app_private.retention_inventory_before_learning(uuid),
  app_private.retention_inventory(uuid),app_private.retention_is_held(uuid,text,uuid,uuid),
  app_private.retention_is_held_before_learning(uuid,text,uuid,uuid),
  public.approve_mentorship(uuid,uuid,uuid,timestamptz,timestamptz,text,uuid,uuid,integer),
  public.respond_mentorship(uuid,uuid,integer,boolean,uuid),public.save_learning_goal(uuid,integer,text,text,integer,uuid,uuid,text),
  public.share_learning_goal(uuid,uuid,integer,uuid,uuid),
  public.save_learning_checkin(uuid,uuid,integer,text,uuid,uuid,timestamptz,timestamptz,text),
  public.append_learning_note(uuid,uuid,integer,uuid,text,text),public.read_learning_entry(uuid),
  public.read_learning_workspace(uuid),public.read_mentoring_assignments(uuid),public.export_learning_checkin(uuid,uuid,integer),
  public.export_learning_record(uuid) from public,anon,authenticated,service_role;
grant execute on function public.approve_mentorship(uuid,uuid,uuid,timestamptz,timestamptz,text,uuid,uuid,integer),
  public.respond_mentorship(uuid,uuid,integer,boolean,uuid),public.save_learning_goal(uuid,integer,text,text,integer,uuid,uuid,text),
  public.share_learning_goal(uuid,uuid,integer,uuid,uuid),
  public.save_learning_checkin(uuid,uuid,integer,text,uuid,uuid,timestamptz,timestamptz,text),
  public.append_learning_note(uuid,uuid,integer,uuid,text,text),public.read_learning_entry(uuid),
  public.read_learning_workspace(uuid),public.read_mentoring_assignments(uuid),public.export_learning_checkin(uuid,uuid,integer),
  public.export_learning_record(uuid) to authenticated;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
select 'app_private.'||source,category,'term',array['id'],
  format('select app_private.disposition_key(%L,array[x.id::text]) target_hash,%L category,%s root_id,
    app_private.retention_is_held($1,%L,x.id,%s) held,
    encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'') state_hash from app_private.%I x where x.term_id=$1',
    'app_private.'||source,category,root_expr,category,root_expr,source),
  app_private.disposition_structure('app_private.'||source),preserve
from (values
  ('mentorships','learning','x.id',false),('learning_goals','learning','x.id',false),
  ('learning_checkins','learning','x.mentorship_id',false),('learning_notes','learning','x.checkin_id',false),
  ('learning_events','security','x.object_id',true)
) definitions(source,category,root_expr,preserve);

commit;
