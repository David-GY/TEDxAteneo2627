begin;
-- Trusted provisioning only. No policy/classification or telemetry is enabled by default.
create table app_private.reporting_policies(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),version integer not null check(version>0),
 enabled boolean not null,retention_days integer not null check(retention_days between 7 and 90),salt uuid not null default gen_random_uuid(),
 approval_reference text not null check(length(btrim(approval_reference))between 1 and 240),capture_started_at timestamptz not null default statement_timestamp(),
 unique(term_id,version)
);
create table app_private.reporting_subjects(
 policy_id uuid not null references app_private.reporting_policies(id),member_id uuid not null references public.members(id),
 actor_kind text not null check(actor_kind in('human','test','bot')),primary key(policy_id,member_id)
);
create table app_private.usage_events(
 id uuid primary key default gen_random_uuid(),policy_id uuid not null references app_private.reporting_policies(id),term_id uuid not null references public.terms(id),
 subject_key text not null check(subject_key~'^[0-9a-f]{64}$'),event_type text not null check(event_type in('work_viewed','task_updated','synergy_proposed','synergy_responded','handoff_submitted','handoff_accepted','request_submitted','decision_recorded','onboarding_item_completed','config_published','archive_verified')),
 object_id uuid not null,unit_id uuid, event_key uuid not null,occurred_at timestamptz not null default statement_timestamp(),
 unique(policy_id,subject_key,event_type,event_key)
);
create index usage_event_period on app_private.usage_events(term_id,occurred_at,subject_key);
do $$declare t text;begin foreach t in array array['reporting_policies','reporting_subjects','usage_events']loop
 execute format('alter table app_private.%I enable row level security',t);execute format('alter table app_private.%I force row level security',t);
 execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',t);end loop;end$$;
create trigger immutable_reporting_policy before update or delete on app_private.reporting_policies for each row execute function app_private.request_history_guard();
create trigger immutable_reporting_subject before update or delete on app_private.reporting_subjects for each row execute function app_private.request_history_guard();
create function app_private.usage_history_guard()returns trigger language plpgsql set search_path='' as $$begin
 if tg_op='DELETE'and current_setting('app.usage_retention',true)='approved'then return old;end if;
 raise exception using errcode='55000',message='immutable_usage_history';end$$;
create trigger immutable_usage_events before update or delete on app_private.usage_events for each row execute function app_private.usage_history_guard();
create function app_private.report_week(moment timestamptz)returns date language sql immutable strict set search_path='' as $$select date_trunc('week',moment at time zone'Asia/Manila')::date$$;
create function app_private.capture_usage(work uuid,event text,event_key uuid)returns boolean language plpgsql security definer set search_path='' as $$
declare w public.work_items;m public.term_memberships;p app_private.reporting_policies;begin
 select *into w from public.work_items where id=work;
 select *into m from public.term_memberships where id=public.current_term_membership(w.term_id)and membership_kind='core';if not found then return false;end if;
 select *into p from app_private.reporting_policies where term_id=w.term_id order by version desc limit 1;
 if not coalesce(p.enabled,false)or p.capture_started_at>statement_timestamp()or not exists(select 1 from app_private.reporting_subjects where policy_id=p.id and member_id=m.member_id and actor_kind='human')then return false;end if;
 insert into app_private.usage_events(policy_id,term_id,subject_key,event_type,object_id,unit_id,event_key)
 values(p.id,w.term_id,encode(sha256(convert_to(m.member_id::text||p.salt::text,'UTF8')),'hex'),event,w.id,w.lead_unit_id,event_key)on conflict do nothing;return true;
end$$;
create function app_private.usage_from_audit()returns trigger language plpgsql security definer set search_path='' as $$
declare event text;begin
 event:=case when new.action in('create_task','update_task','assign_task','transition_task')then 'task_updated'
 when new.action='propose_synergy'then 'synergy_proposed'when new.action='respond_to_synergy'then 'synergy_responded'
 when new.action='submit_handoff'then 'handoff_submitted'when new.action='accept_handoff'then 'handoff_accepted'
 when new.action in('submit_request','submit_finance_request','submit_publicity_request')then 'request_submitted'
 when new.action in('transition_request','decide_finance_request','decide_publicity_request','accept_deliverable')then 'decision_recorded'
 when new.action='set_onboarding_progress'then 'onboarding_item_completed'
 when new.action in('publish_configuration','publish_presentation_configuration','publish_process_configuration')then 'config_published'else null end;
 if event is not null then perform app_private.capture_usage(new.work_item_id,event,new.id);end if;return new;
end$$;
create trigger capture_meaningful_actions after insert on public.audit_events for each row execute function app_private.usage_from_audit();
-- Explicit permitted page opening, separate from background detail/scope reads.
create function public.record_work_view(p_work_item_id uuid)returns boolean language plpgsql security definer set search_path='' as $$
declare w public.work_items;begin
 select *into w from public.work_items where id=p_work_item_id and kind in('task','deliverable')and archived_at is null;
 if not found or public.current_term_membership(w.term_id)is null or not public.has_capability(w.term_id,'workspace.read')or not public.can_access_work(w.id,'detail')then raise exception using errcode='42501',message='command_permission_denied';end if;
 return app_private.capture_usage(w.id,'work_viewed',md5(w.id::text||app_private.report_week(statement_timestamp())::text)::uuid);
end$$;
create function public.prune_usage_events(p_term_id uuid)returns integer language plpgsql security definer set search_path='' as $$declare removed integer;begin
 perform set_config('app.usage_retention','approved',true);
 delete from app_private.usage_events where id in(select e.id from app_private.usage_events e join app_private.reporting_policies p on e.policy_id=p.id where e.term_id=p_term_id and e.occurred_at<statement_timestamp()-make_interval(days=>p.retention_days)order by e.occurred_at,e.id limit 5000);
 get diagnostics removed=row_count;return removed;end$$;
create function app_private.report_usage(term uuid,week date,unit uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p app_private.reporting_policies;eligible integer;active integer;start_at timestamptz;end_at timestamptz;begin
 if unit is not null then return jsonb_build_object('state','term_only');end if;
 select *into p from app_private.reporting_policies where term_id=term order by version desc limit 1;
 if not coalesce(p.enabled,false)or p.capture_started_at>statement_timestamp()then return jsonb_build_object('state','unconfigured');end if;
 start_at:=week::timestamp at time zone'Asia/Manila';end_at:=(week+7)::timestamp at time zone'Asia/Manila';
 if end_at<=p.capture_started_at then return jsonb_build_object('state','unconfigured');end if;
 if start_at<statement_timestamp()-make_interval(days=>p.retention_days)then return jsonb_build_object('state','expired');end if;
 if exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=term and tm.membership_kind='core'and tm.status='active'and m.account_state='active'and tm.joined_at<end_at and tm.ends_at>start_at
  and not exists(select 1 from app_private.reporting_subjects s where s.policy_id=p.id and s.member_id=tm.member_id))then return jsonb_build_object('state','unconfigured');end if;
 with cohort as materialized(select distinct tm.member_id,tm.joined_at,tm.ends_at from public.term_memberships tm join public.members m on m.id=tm.member_id join app_private.reporting_subjects s on s.policy_id=p.id and s.member_id=m.id and s.actor_kind='human'
  where tm.term_id=term and tm.membership_kind='core'and tm.status='active'and m.account_state='active'and tm.joined_at<end_at and tm.ends_at>start_at)
 select count(distinct c.member_id)::integer,count(distinct c.member_id)filter(where exists(select 1 from app_private.usage_events e
  where e.term_id=term and e.policy_id=p.id and e.subject_key=encode(sha256(convert_to(c.member_id::text||p.salt::text,'UTF8')),'hex')and e.occurred_at>=greatest(start_at,c.joined_at,p.capture_started_at)and e.occurred_at<least(end_at,c.ends_at)))::integer into eligible,active from cohort c;
 if eligible between 1 and 4 then return jsonb_build_object('state','suppressed');end if;
 return jsonb_build_object('state',case when eligible=0 then 'empty'else 'available'end,'eligible',eligible,'active',active,'required',(eligible*4+4)/5,'percent',case when eligible>0 then round(active::numeric*100/eligible,1)end,
  'targetMet',case when eligible>0 then active*5>=eligible*4 end,'captureStartedAt',p.capture_started_at,'partialWeek',p.capture_started_at>start_at or statement_timestamp()<end_at);
end$$;
create function public.read_reports(p_term_id uuid,p_week date,p_unit_id uuid default null,p_filters jsonb default '{}')returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;view text;after_id uuid;begin
 perform app_private.request_actor(p_term_id);
 if not public.has_capability(p_term_id,'reports.view')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_unit_id is not null and not exists(select 1 from public.org_units where id=p_unit_id and term_id=p_term_id and archived_at is null and public.has_capability(p_term_id,'committee.manage',id))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_week is null or not isfinite(p_week)or extract(isodow from p_week)<>1 or p_week>app_private.report_week(statement_timestamp())or p_week<app_private.report_week(statement_timestamp())-84
  or not coalesce(app_private.definition_keys(p_filters,array['view','after']),false)or(p_filters?'view'and jsonb_typeof(p_filters->'view')<>'string')or(p_filters?'after'and jsonb_typeof(p_filters->'after')not in('string','null'))then raise exception using errcode='22023',message='command_validation_failed';end if;
 view:=coalesce(p_filters->>'view','all');if view not in('all','overdue','blocked','unassigned')then raise exception using errcode='22023',message='command_validation_failed';end if;
 begin after_id:=(p_filters->>'after')::uuid;exception when others then raise exception using errcode='22023',message='command_validation_failed';end;
 with permitted as materialized(
  select w.*,coalesce(t.workflow_state,d.workflow_state)state,t.assignee_id from public.work_items w left join public.tasks t on t.work_item_id=w.id left join public.deliverables d on d.work_item_id=w.id
  where w.term_id=p_term_id and w.kind in('task','deliverable')and w.archived_at is null and w.classification='ordinary'and(p_unit_id is null or w.lead_unit_id=p_unit_id)
   and exists(select 1 from public.org_units u where u.id=w.lead_unit_id and u.term_id=p_term_id and u.archived_at is null and public.has_capability(p_term_id,'committee.manage',u.id))and public.can_access_work(w.id,'detail')
 ),measured as materialized(select p.*,case when kind='deliverable'then public.read_deliverable_readiness(id)end readiness,
  case when state='blocked'then(select min(r.recorded_at)from public.task_revisions r where r.work_item_id=p.id and r.state='blocked'and r.work_version>coalesce((select max(b.work_version)from public.task_revisions b where b.work_item_id=p.id and b.state<>'blocked'),0))end blocked_since,
  coalesce(due_at<statement_timestamp(),due_on<(statement_timestamp()at time zone'Asia/Manila')::date,false)overdue,
  case when original_due_at is null and original_due_on is null then null else coalesce(original_due_at<statement_timestamp(),original_due_on<(statement_timestamp()at time zone'Asia/Manila')::date,false)end original_overdue
  from permitted p),scoped as materialized(select m.*,state not in('done','cancelled')and(state<>'accepted'or coalesce((readiness->>'reviewRequired')::boolean,false))open from measured m),
 filtered as materialized(select *from scoped where view='all'or view='overdue'and overdue and open or view='blocked'and state='blocked'or view='unassigned'and kind='task'and open and assignee_id is null),
 page as(select *from filtered where after_id is null or id>after_id order by id limit 51)
 select jsonb_build_object('asOf',statement_timestamp(),'week',p_week,'weekEnd',p_week+6,'timezone','Asia/Manila','usage',app_private.report_usage(p_term_id,p_week,p_unit_id),
  'units',coalesce((select jsonb_agg(jsonb_build_object('id',id,'label',name)order by name,id)from public.org_units where term_id=p_term_id and archived_at is null and public.has_capability(p_term_id,'committee.manage',id)),'[]'),
  'summary',jsonb_build_object('total',(select count(*)from scoped),'open',(select count(*)from scoped where open),'overdue',(select count(*)from scoped where open and overdue),'originalOverdue',(select count(*)from scoped where open and original_overdue),'blocked',(select count(*)from scoped where state='blocked'),'assignedOpen',(select count(*)from scoped where kind='task'and open and assignee_id is not null),'unassignedOpen',(select count(*)from scoped where kind='task'and open and assignee_id is null),'readyDeliverables',(select count(*)from scoped where kind='deliverable'and(readiness->>'ready')::boolean)),
  'total',(select count(*)from filtered),'items',coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',kind,'title',title,'reference',(select reference_text from public.work_references where work_item_id=p.id),'state',state,'dueOn',due_on,'dueAt',due_at,'originalDueOn',original_due_on,'originalDueAt',original_due_at,'overdue',overdue and open,'originalOverdue',original_overdue and open,'blockedSince',blocked_since,'checksMet',(readiness->>'ready')::boolean,
   'blockedDays',case when blocked_since is not null then round(extract(epoch from(statement_timestamp()-blocked_since))/86400,1)end,
   'href',case kind when 'task'then '/tasks/'else '/deliverables/'end||id||'?term='||p_term_id)order by id)from(select *from page order by id limit 50)p),'[]'),
  'nextAfter',case when(select count(*)from page)>50 then(select id from page order by id offset 49 limit 1)end)into result;
 return result;
end$$;
revoke all on function app_private.usage_history_guard(),app_private.report_week(timestamptz),app_private.capture_usage(uuid,text,uuid),app_private.usage_from_audit(),app_private.report_usage(uuid,date,uuid)from public,anon,authenticated,service_role;
revoke all on function public.record_work_view(uuid),public.read_reports(uuid,date,uuid,jsonb),public.prune_usage_events(uuid)from public,anon,authenticated,service_role;
grant execute on function public.record_work_view(uuid),public.read_reports(uuid,date,uuid,jsonb)to authenticated;
grant execute on function public.prune_usage_events(uuid)to service_role;
commit;
