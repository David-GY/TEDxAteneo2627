begin;
-- Source-specific metadata access is narrower than report permission. No new
-- data entitlement, raw history grant, arbitrary query or export is introduced.
create function app_private.report_operations(term uuid,week date,unit uuid)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;queue jsonb;reviews jsonb;handoffs jsonb;
 start_at timestamptz:=week::timestamp at time zone'Asia/Manila';
 end_at timestamptz:=(week+7)::timestamp at time zone'Asia/Manila';
begin
 m:=app_private.request_actor(term);
 if not public.has_capability(term,'reports.view')then raise exception using errcode='42501',message='command_permission_denied';end if;
 with permitted as materialized(
  select r.*,rev.submitted_at,rev.title_snapshot,x.id instance_id,x.state instance_state,x.generation,x.current_stage_key,
   app_private.workflow_member(r,x,m,true) package_allowed,
   x.state='paused'or not app_private.workflow_current(x) waiting_assignment,
   app_private.workflow_entry(r,x)is not null prerequisite_blocked
  from public.requests r join public.work_items w on w.id=r.work_item_id
  join public.request_types t on t.id=r.request_type_id and t.governed_kind='general'
  join public.request_revisions rev on rev.id=r.current_revision_id
  join public.workflow_instances x on x.revision_id=rev.id
  join public.org_units u on u.id=r.receiving_unit_id and u.archived_at is null
  -- Typed request spines are always restricted; the frozen payload classification
  -- and the existing workflow metadata entitlement define this projection.
  where r.term_id=term and w.archived_at is null
   and r.payload_classification='ordinary'and rev.payload_classification='ordinary'
   and(unit is null or r.receiving_unit_id=unit)
   and public.has_capability(term,'committee.manage',r.receiving_unit_id)
   and app_private.workflow_manager(r,m)
 ),pending as materialized(
  select p.*,case when waiting_assignment then 'unassigned'when prerequisite_blocked then 'prerequisites'else 'assigned'end lane,
   case when submitted_at<=statement_timestamp()then round(extract(epoch from(statement_timestamp()-submitted_at))/86400,1)end age_days
  from permitted p where request_state in('paused','in_review')
 ),decisions as materialized(
  select d.id,round(extract(epoch from(d.decided_at-a.assigned_at))/86400,6) days
  from permitted p join public.approval_assignments a on a.request_id=p.work_item_id
  join public.request_revisions rev on rev.id=a.revision_id and rev.payload_classification='ordinary'
  join public.approval_decisions d on d.assignment_id=a.id and d.revision_id=a.revision_id and d.instance_id=a.instance_id and d.generation=a.generation and d.stage_key=a.stage_key
  where d.decided_at>=start_at and d.decided_at<end_at and d.decided_at<=statement_timestamp()and d.decided_at>=a.assigned_at
 )
 select jsonb_build_object('total',(select count(*)from pending),'unassigned',(select count(*)from pending where lane='unassigned'),
  'assigned',(select count(*)from pending where lane='assigned'),'prerequisites',(select count(*)from pending where lane='prerequisites'),
  'oldestDays',(select max(age_days)from pending),'unknownAge',(select count(*)from pending where age_days is null),
  'items',coalesce((select jsonb_agg(jsonb_build_object('id',work_item_id,'title',case when package_allowed then title_snapshot else type_label end,
   'reference',tracking_id,'href','/reviews/'||term||'/'||work_item_id,'revision',current_revision,'state',request_state,'lane',lane,'since',submitted_at,'ageDays',age_days)
   order by submitted_at,work_item_id)from(select *from pending order by submitted_at,work_item_id limit 20)p),'[]')),
  jsonb_build_object('samples',(select count(*)from decisions),'medianDays',(select round((percentile_cont(0.5)within group(order by days))::numeric,1)from decisions),
   'p90Days',(select round((percentile_cont(0.9)within group(order by days))::numeric,1)from decisions))
 into queue,reviews;
 with permitted as materialized(
  select h.*,w.title,(select reference_text from public.work_references where work_item_id=w.id)reference,
   r.recorded_at,r.receiver_member_id revision_receiver,r.receiver_unit_id revision_unit
  from public.handoffs h join public.work_items w on w.id=h.source_task_id
  join public.handoff_revisions r on r.handoff_id=h.id and r.revision=h.current_revision
  where h.term_id=term and w.classification='ordinary'and w.archived_at is null
   and public.can_access_work(w.id,'detail')and app_private.handoff_visible(h)
   and(h.next_task_id is null or exists(select 1 from public.work_items n where n.id=h.next_task_id and n.classification='ordinary'and n.archived_at is null and public.can_access_work(n.id,'detail')))
   and exists(select 1 from public.org_units u where u.id in(w.lead_unit_id,h.receiver_unit_id)and u.archived_at is null
    and(unit is null or u.id=unit)and public.has_capability(term,'committee.manage',u.id))
 ),responses as materialized(
  select h.id,r.revision,r.recorded_at,min(d.recorded_at)responded_at
  from permitted h join public.handoff_revisions r on r.handoff_id=h.id and r.receiver_member_id=h.receiver_member_id and r.receiver_unit_id=h.receiver_unit_id
  join public.handoff_decisions d on d.handoff_id=r.handoff_id and d.revision=r.revision and d.member_id=r.receiver_member_id and d.action in('accept','decline','changes_requested')
  where d.recorded_at>=r.recorded_at and d.recorded_at<=statement_timestamp()group by h.id,r.revision,r.recorded_at
 ),accepted as materialized(
  select h.id,r.revision,r.recorded_at,a.accepted_at from permitted h
  join public.handoff_revisions r on r.handoff_id=h.id and r.receiver_member_id=h.receiver_member_id and r.receiver_unit_id=h.receiver_unit_id
  join public.handoff_receipts a on a.handoff_id=r.handoff_id and a.revision=r.revision and a.receiver_member_id=r.receiver_member_id
  where a.accepted_at>=r.recorded_at and a.accepted_at<=statement_timestamp()
 ),response_samples as(select extract(epoch from(responded_at-recorded_at))/86400 days from responses where responded_at>=start_at and responded_at<end_at),
 acceptance_samples as(select extract(epoch from(accepted_at-recorded_at))/86400 days from accepted where accepted_at>=start_at and accepted_at<end_at)
 select jsonb_build_object('total',(select count(*)from permitted),'pending',(select count(*)from permitted where state='proposed'),
  'responseSamples',(select count(*)from response_samples),'medianResponseDays',(select round((percentile_cont(0.5)within group(order by days))::numeric,1)from response_samples),
  'p90ResponseDays',(select round((percentile_cont(0.9)within group(order by days))::numeric,1)from response_samples),
  'acceptanceSamples',(select count(*)from acceptance_samples),'medianAcceptanceDays',(select round((percentile_cont(0.5)within group(order by days))::numeric,1)from acceptance_samples),
  'p90AcceptanceDays',(select round((percentile_cont(0.9)within group(order by days))::numeric,1)from acceptance_samples),
  'items',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'reference',p.reference,'href','/working-together/handoffs/'||p.id||'?term='||term,
   'revision',p.current_revision,'state',p.state,'since',p.recorded_at,'ageDays',case when p.state='proposed'and p.recorded_at<=statement_timestamp()then round(extract(epoch from(statement_timestamp()-p.recorded_at))/86400,1)end)
   order by p.recorded_at,p.id)from(select *from permitted order by recorded_at,id limit 20)p),'[]'))into handoffs;
 return jsonb_build_object('queue',queue,'reviews',reviews,'handoffs',handoffs);
end$$;

alter function public.read_reports(uuid,date,uuid,jsonb)rename to read_reports_foundation;
alter function public.read_reports_foundation(uuid,date,uuid,jsonb)set schema app_private;
create function public.read_reports(p_term_id uuid,p_week date,p_unit_id uuid default null,p_filters jsonb default '{}')returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;workload jsonb;items jsonb;today date:=(statement_timestamp()at time zone'Asia/Manila')::date;
begin
 -- The existing gate also validates the closed period, unit, filters and cursor.
 result:=app_private.read_reports_foundation(p_term_id,p_week,p_unit_id,p_filters);
 with scoped as materialized(
  select w.*,t.assignee_id,c.work_item_id contribution_id,r.effort_band
  from public.work_items w join public.tasks t on t.work_item_id=w.id
  left join public.contributions c on c.work_item_id=w.id
  left join public.agreement_revisions r on r.agreement_id=c.agreement_id and r.revision=c.active_revision
  where w.term_id=p_term_id and w.archived_at is null and w.classification='ordinary'and t.workflow_state not in('done','cancelled')
   and(p_unit_id is null or w.lead_unit_id=p_unit_id)and public.can_access_work(w.id,'detail')
   and exists(select 1 from public.org_units u where u.id=w.lead_unit_id and u.archived_at is null and public.has_capability(p_term_id,'committee.manage',u.id))
 )select jsonb_build_object('totalOpen',count(*),'assignedOpen',count(*)filter(where assignee_id is not null),'unassignedOpen',count(*)filter(where assignee_id is null),
  'dueInSevenDays',count(*)filter(where coalesce((due_at at time zone'Asia/Manila')::date,due_on)>=today and coalesce((due_at at time zone'Asia/Manila')::date,due_on)<today+7),
  'dueSelectedWeek',count(*)filter(where coalesce((due_at at time zone'Asia/Manila')::date,due_on)>=p_week and coalesce((due_at at time zone'Asia/Manila')::date,due_on)<p_week+7),
  'undatedOpen',count(*)filter(where due_on is null and due_at is null),
  'effort',jsonb_build_object('small',count(*)filter(where effort_band='small'),'medium',count(*)filter(where effort_band='medium'),'large',count(*)filter(where effort_band='large'),'notRecorded',count(*)filter(where effort_band is null)))into workload from scoped;
 select coalesce(jsonb_agg(v||jsonb_build_object('declaredEffort',(select r.effort_band from public.contributions c join public.agreement_revisions r on r.agreement_id=c.agreement_id and r.revision=c.active_revision where c.work_item_id=(v->>'id')::uuid))order by ord),'[]')into items from jsonb_array_elements(result->'items')with ordinality f(v,ord);
 return result||jsonb_build_object('items',items,'workload',workload,'operations',app_private.report_operations(p_term_id,p_week,p_unit_id));
end$$;
revoke all on function app_private.read_reports_foundation(uuid,date,uuid,jsonb),app_private.report_operations(uuid,date,uuid)from public,anon,authenticated,service_role;
revoke all on function public.read_reports(uuid,date,uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.read_reports(uuid,date,uuid,jsonb)to authenticated;

-- Own checklist progress has no work-item spine. Derive term/actor on the server
-- and capture only actual new completions, in the same command transaction.
create function app_private.capture_term_usage(p_term uuid,p_event text,p_object uuid,p_unit uuid,p_key uuid)returns boolean
language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;p app_private.reporting_policies;begin
 select *into m from public.term_memberships where id=public.current_term_membership(p_term)and membership_kind='core';
 if not found or not public.has_capability(p_term,'workspace.read')then return false;end if;
 select *into p from app_private.reporting_policies where term_id=p_term order by version desc limit 1;
 if not coalesce(p.enabled,false)or p.capture_started_at>statement_timestamp()or not exists(select 1 from app_private.reporting_subjects where policy_id=p.id and member_id=m.member_id and actor_kind='human')then return false;end if;
 insert into app_private.usage_events(policy_id,term_id,subject_key,event_type,object_id,unit_id,event_key)
 values(p.id,p_term,encode(sha256(convert_to(m.member_id::text||p.salt::text,'UTF8')),'hex'),p_event,p_object,p_unit,p_key)on conflict do nothing;return true;
end$$;
create or replace function app_private.capture_usage(work uuid,event text,event_key uuid)returns boolean
language plpgsql security definer set search_path='' as $$declare w public.work_items;begin
 select *into w from public.work_items where id=work;if not found then return false;end if;
 return app_private.capture_term_usage(w.term_id,event,w.id,w.lead_unit_id,event_key);
end$$;
create or replace function app_private.usage_from_audit()returns trigger language plpgsql security definer set search_path='' as $$
declare event text;begin
 event:=case when new.action in('create_task','update_task','assign_task','transition_task')then 'task_updated'
 when new.action='propose_synergy'then 'synergy_proposed'when new.action='respond_to_synergy'then 'synergy_responded'
 when new.action='submit_handoff'then 'handoff_submitted'when new.action='accept_handoff'then 'handoff_accepted'
 when new.action in('submit_request','submit_finance_request','submit_publicity_request')then 'request_submitted'
 when new.action in('transition_request','decide_finance_request','decide_publicity_request','accept_deliverable')then 'decision_recorded'
 when new.action in('publish_configuration','publish_presentation_configuration','publish_process_change')then 'config_published'
 when new.action='save_resource'and exists(select 1 from public.resource_versions r where r.resource_id=new.work_item_id and r.version=new.revision and r.published)then 'config_published'
 else null end;
 if event is not null then perform app_private.capture_usage(new.work_item_id,event,new.id);end if;return new;
end$$;
alter function public.set_onboarding_progress(uuid,text,integer,text,integer,uuid)rename to set_onboarding_progress_without_usage;
alter function public.set_onboarding_progress_without_usage(uuid,text,integer,text,integer,uuid)set schema app_private;
create function public.set_onboarding_progress(p_term_id uuid,p_item text,p_revision integer,p_state text,p_expected_version integer,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;already_done boolean;retry boolean;begin
 perform app_private.readiness_lock(p_term_id);
 select exists(select 1 from public.idempotency_keys where actor_id=auth.uid()and command='set_onboarding_progress'and client_key=p_request_id)into retry;
 select exists(select 1 from public.onboarding_progress where term_membership_id=public.current_term_membership(p_term_id)and item=p_item and revision=p_revision and state='done')into already_done;
 -- This command retains all original current-authority, item, expected-version
 -- and exact-key/payload checks; no unchecked client event endpoint is added.
 result:=app_private.set_onboarding_progress_without_usage(p_term_id,p_item,p_revision,p_state,p_expected_version,p_request_id);
 if p_state='done'and not retry and not already_done then
  perform app_private.capture_term_usage(p_term_id,'onboarding_item_completed',md5(p_term_id::text||':'||p_item||':'||p_revision::text)::uuid,null,p_request_id);
 end if;
 return result;
end$$;
revoke all on function app_private.capture_term_usage(uuid,text,uuid,uuid,uuid),app_private.set_onboarding_progress_without_usage(uuid,text,integer,text,integer,uuid)from public,anon,authenticated,service_role;
revoke all on function public.set_onboarding_progress(uuid,text,integer,text,integer,uuid)from public,anon,authenticated,service_role;
grant execute on function public.set_onboarding_progress(uuid,text,integer,text,integer,uuid)to authenticated;
-- Elapsed current-week eligibility excludes scheduled future joins. Prior-week
-- history still uses recorded intervals under the currently approved roster state.
create or replace function app_private.report_usage(term uuid,week date,unit uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p app_private.reporting_policies;eligible integer;active integer;start_at timestamptz;end_at timestamptz;begin
 if unit is not null then return jsonb_build_object('state','term_only');end if;
 select *into p from app_private.reporting_policies where term_id=term order by version desc limit 1;
 if not coalesce(p.enabled,false)or p.capture_started_at>statement_timestamp()then return jsonb_build_object('state','unconfigured');end if;
 start_at:=week::timestamp at time zone'Asia/Manila';end_at:=(week+7)::timestamp at time zone'Asia/Manila';
 if end_at<=p.capture_started_at then return jsonb_build_object('state','unconfigured');end if;
 if start_at<statement_timestamp()-make_interval(days=>p.retention_days)then return jsonb_build_object('state','expired');end if;
 if exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=term and tm.membership_kind='core'and tm.status='active'and m.account_state='active'and tm.joined_at<least(end_at,statement_timestamp()) and tm.ends_at>start_at
  and not exists(select 1 from app_private.reporting_subjects s where s.policy_id=p.id and s.member_id=tm.member_id))then return jsonb_build_object('state','unconfigured');end if;
 with cohort as materialized(select distinct tm.member_id,tm.joined_at,tm.ends_at from public.term_memberships tm join public.members m on m.id=tm.member_id join app_private.reporting_subjects s on s.policy_id=p.id and s.member_id=m.id and s.actor_kind='human'
  where tm.term_id=term and tm.membership_kind='core'and tm.status='active'and m.account_state='active'and tm.joined_at<least(end_at,statement_timestamp()) and tm.ends_at>start_at)
 select count(distinct c.member_id)::integer,count(distinct c.member_id)filter(where exists(select 1 from app_private.usage_events e
  where e.term_id=term and e.policy_id=p.id and e.subject_key=encode(sha256(convert_to(c.member_id::text||p.salt::text,'UTF8')),'hex')and e.occurred_at>=greatest(start_at,c.joined_at,p.capture_started_at)and e.occurred_at<least(end_at,c.ends_at)))::integer into eligible,active from cohort c;
 if eligible between 1 and 4 then return jsonb_build_object('state','suppressed');end if;
 return jsonb_build_object('state',case when eligible=0 then 'empty'else 'available'end,'eligible',eligible,'active',active,'required',(eligible*4+4)/5,'percent',case when eligible>0 then round(active::numeric*100/eligible,1)end,
  'targetMet',case when eligible>0 then active*5>=eligible*4 end,'captureStartedAt',p.capture_started_at,'partialWeek',p.capture_started_at>start_at or statement_timestamp()<end_at);
end$$;

commit;
