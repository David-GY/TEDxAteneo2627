alter table public.requests drop constraint requests_accepted_on_check;
alter table public.requests add check(accepted_on is null or accepted_on between '0001-01-01'and'9999-12-31');
-- P23 operational triage, independent of protected FIN/MCD authority.
create table public.request_triage_events(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,request_id uuid not null,revision_id uuid not null,
 kind text not null check(kind in('note','accepted_date','completed')),note text not null check(length(btrim(note))between 1 and 2000),
 accepted_on date,actor_name text not null,recorded_at timestamptz not null default statement_timestamp(),
 foreign key(organization_id,term_id,request_id,revision_id)references public.request_revisions(organization_id,term_id,request_id,id),
 check(accepted_on is null or accepted_on between '0001-01-01'and'9999-12-31')
);
create index request_triage_scope on public.request_triage_events(organization_id,term_id,request_id,recorded_at);
alter table public.request_triage_events enable row level security;
revoke all on public.request_triage_events from public,anon,authenticated,service_role;
create trigger immutable_triage_history before update or delete on public.request_triage_events for each row execute function app_private.request_history_guard();

alter function public.read_request_workflow(uuid,uuid)rename to read_request_workflow_p22;
alter function public.read_request_workflow_p22(uuid,uuid)set schema app_private;
create function public.read_request_workflow(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare base jsonb;r public.requests;x public.workflow_instances;m public.term_memberships;s jsonb;manage boolean;package boolean;begin
 base:=app_private.read_request_workflow_p22(p_term_id,p_work_item_id);if base is null then return null;end if;
 select * into r from public.requests where work_item_id=p_work_item_id;select * into x from public.workflow_instances where revision_id=r.current_revision_id;
 m:=app_private.request_actor(p_term_id);s:=app_private.workflow_stage(x);manage:=(base->>'canManage')::boolean;package:=base->'package'<>'null'::jsonb;
 return base||jsonb_build_object('trackingId',r.tracking_id,'typeLabel',r.type_label,'serviceLabel',r.service_label,
 'requestedOn',(select requested_on from public.request_revisions where id=r.current_revision_id),'originalRequestedOn',r.original_requested_on,'acceptedOn',r.accepted_on,
 'stageLabel',s->>'label','stageOutcome',s->>'outcome','requiredSlots',case when s->>'review'='one'then 1 else jsonb_array_length(s->'reviewers')end,
 'canAssign',manage and r.request_state in('paused','in_review')and(x.state='paused'or not app_private.workflow_current(x)),
 'canNote',(manage or app_private.workflow_member(r,x,m,true))and r.request_state in('paused','in_review','needs_revision','approved'),
 'canTriage',manage and r.request_state in('paused','in_review','needs_revision','approved'),
 'canComplete',manage and r.request_state='approved'and app_private.workflow_hooks_ready(r)and exists(select 1 from public.request_workflow_outcomes where revision_id=x.revision_id and category='general_approved'),
 'actions',case when(base->>'canAct')::boolean then jsonb_build_array('approve','reject')||case when s?'revisionStage'then '["request_revision"]'::jsonb else '[]'::jsonb end else '[]'::jsonb end,
 'externalEvidenceRequired',coalesce((s->>'externalEvidenceRequired')::boolean,false),
 'manifestId',case when package then(select manifest_id from public.request_revisions where id=x.revision_id)end,
 'reviewerChoices',case when manage then coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'name',v.display_name)order by v.display_name,v.id)from(
 select tm.id,person.display_name from public.term_memberships tm join public.members person on person.id=tm.member_id
 where tm.term_id=p_term_id and tm.member_id<>(select owner_member_id from public.work_items where id=r.work_item_id)
 and app_private.workflow_role(p_term_id,tm.id,r.receiving_unit_id)is not null order by person.display_name,tm.id limit 100)v),'[]')else '[]'::jsonb end,
 'triageHistory',case when manage or package then coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'note',e.note,'acceptedOn',e.accepted_on,'name',e.actor_name,'at',e.recorded_at)order by e.recorded_at desc,e.id desc)from(select * from public.request_triage_events where request_id=r.work_item_id order by recorded_at desc,id desc limit 100)e),'[]')else '[]'::jsonb end);
end$$;

create function app_private.review_inbox_rows(term uuid)returns setof jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;r public.requests;x public.workflow_instances;rev public.request_revisions;w public.work_items;manager boolean;assigned boolean;waiting boolean;s jsonb;problem text;begin
 m:=app_private.request_actor(term);
 for r in select * from public.requests where term_id=term and request_type_id is not null and request_state in('paused','in_review','needs_revision','approved')loop
  select * into w from public.work_items where id=r.work_item_id;if w.archived_at is not null then continue;end if;
  select * into x from public.workflow_instances where revision_id=r.current_revision_id;
  manager:=coalesce(app_private.workflow_manager(r,m),false);assigned:=coalesce(app_private.workflow_member(r,x,m,true),false);
  if not(manager or assigned)then continue;end if;
  select * into rev from public.request_revisions where id=x.revision_id;s:=app_private.workflow_stage(x);
  problem:=app_private.workflow_entry(r,x);waiting:=x.state='paused'or(x.state='active'and(not app_private.workflow_current(x)or problem is not null));
  return next jsonb_build_object('id',w.id,'termId',term,'trackingId',r.tracking_id,'title',case when assigned then rev.title_snapshot else r.type_label end,
   'serviceLabel',r.service_label,'owner',(select display_name from public.members where id=w.owner_member_id),'state',r.request_state,'stageLabel',s->>'label',
   'requestedOn',rev.requested_on,'acceptedOn',r.accepted_on,'submittedAt',rev.submitted_at,
   'lane',case when r.request_state='needs_revision'then 'revision'when waiting then 'unassigned'else 'assigned'end,
   'aging',rev.submitted_at+make_interval(days=>(s->>'reminderDays')::integer)<=statement_timestamp(),
   'actionable',manager and(waiting or r.request_state='approved')or assigned and problem is null and not exists(select 1 from public.approval_decisions d join public.approval_assignments a on a.id=d.assignment_id where d.instance_id=x.id and d.generation=x.generation and a.reviewer_id=m.id),
   'nextAction',case when r.request_state='needs_revision'then 'Waiting for requester revision'when r.request_state='approved'then 'Record operational completion'when waiting and problem is not null then 'Resolve paused prerequisites with the service head'when waiting then 'Assign current independent reviewers'when assigned then 'Review this exact revision'else 'Waiting for assigned reviewers'end);
 end loop;
end$$;
create function public.list_review_inbox(p_term_id uuid,p_view text default 'all',p_page integer default 1)returns jsonb language plpgsql security definer set search_path='' as $$
declare rows jsonb;filtered jsonb;begin
 if p_view is null or p_view not in('all','unassigned','assigned','aging','revision')or p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if public.current_term_membership(p_term_id)is null or not public.has_capability(p_term_id,'workspace.read')then return null;end if;
 select coalesce(jsonb_agg(v),'[]')into rows from app_private.review_inbox_rows(p_term_id)v;
 select coalesce(jsonb_agg(v order by v->>'submittedAt',v->>'id'),'[]')into filtered from jsonb_array_elements(rows)v where p_view='all'or v->>'lane'=p_view or(p_view='aging'and(v->>'aging')::boolean);
 return jsonb_build_object('page',p_page,'total',jsonb_array_length(filtered),'counts',jsonb_build_object('all',jsonb_array_length(rows),
 'unassigned',(select count(*)from jsonb_array_elements(rows)v where v->>'lane'='unassigned'),'assigned',(select count(*)from jsonb_array_elements(rows)v where v->>'lane'='assigned'),
 'aging',(select count(*)from jsonb_array_elements(rows)v where(v->>'aging')::boolean),'revision',(select count(*)from jsonb_array_elements(rows)v where v->>'lane'='revision')),
 'items',coalesce((select jsonb_agg(v order by ord)from jsonb_array_elements(filtered)with ordinality f(v,ord)where ord>(p_page-1)*20 and ord<=p_page*20),'[]'));
end$$;

create function public.triage_request(p_work_item_id uuid,p_expected_revision integer,p_expected_version integer,p_action text,p_note text,p_accepted_on date,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;x public.workflow_instances;m public.term_memberships;payload jsonb;result jsonb;begin
 select * into w from public.work_items where id=p_work_item_id for update;m:=app_private.request_actor(w.term_id,true);select * into r from public.requests where work_item_id=w.id;
 select * into x from public.workflow_instances where revision_id=r.current_revision_id for update;
 if not(coalesce(app_private.workflow_manager(r,m),false)or(p_action='note'and coalesce(app_private.workflow_member(r,x,m,true),false)))then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform 1 from public.role_assignments where term_membership_id=m.id order by id for share;
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

alter function public.read_overview(uuid)rename to read_overview_p22;
alter function public.read_overview_p22(uuid)set schema app_private;
create function public.read_overview(p_term_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare base jsonb;rows jsonb;items jsonb;m public.term_memberships;begin
 base:=app_private.read_overview_p22(p_term_id);if not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id)and membership_kind='core')then return base;end if;m:=app_private.request_actor(p_term_id);
 select coalesce(jsonb_agg(jsonb_build_object('id',v->>'id','termId',p_term_id,'source','review','title',(v->>'trackingId')||' · '||(v->>'title'),'owner',v->>'owner','dueOn',v->>'acceptedOn','requestedOn',v->>'requestedOn','dueAt',null,'lane','actionable','action',v->>'nextAction','person','You','state',v->>'state','committee',v->>'serviceLabel','overdue',coalesce((v->>'acceptedOn')::date<(statement_timestamp()at time zone'Asia/Manila')::date,false))),'[]')into rows from app_private.review_inbox_rows(p_term_id)v where(v->>'actionable')::boolean;
 rows:=rows||coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'termId',p_term_id,'source','request','title',r.tracking_id||' · '||w.title,'owner','You','dueOn',r.accepted_on,'requestedOn',rev.requested_on,'dueAt',null,'lane','actionable','action','Revise the submitted request','person','You','state',r.request_state,'committee',r.service_label,'overdue',coalesce(r.accepted_on<(statement_timestamp()at time zone'Asia/Manila')::date,false)))from public.requests r join public.work_items w on w.id=r.work_item_id join public.request_revisions rev on rev.id=r.current_revision_id where r.term_id=p_term_id and r.request_state='needs_revision'and w.owner_member_id=m.member_id and app_private.request_readable(p_term_id,w.id)),'[]');
 rows:=rows||coalesce(base->'items','[]');
 select coalesce(jsonb_agg(v order by ord),'[]')into items from jsonb_array_elements(rows)with ordinality f(v,ord)where ord<=50;
 return base||jsonb_build_object('items',items,'hasMore',coalesce((base->>'hasMore')::boolean,false)or jsonb_array_length(rows)>50);
end$$;
revoke all on function public.read_request_workflow(uuid,uuid),public.list_review_inbox(uuid,text,integer),public.triage_request(uuid,integer,integer,text,text,date,uuid),public.read_overview(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_request_workflow(uuid,uuid),public.list_review_inbox(uuid,text,integer),public.triage_request(uuid,integer,integer,text,text,date,uuid),public.read_overview(uuid)to authenticated;
revoke all on function app_private.read_request_workflow_p22(uuid,uuid),app_private.review_inbox_rows(uuid),app_private.read_overview_p22(uuid)from public,anon,authenticated,service_role;
