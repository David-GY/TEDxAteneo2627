-- P30: no external adapters, secrets, policy or schedule provisioned.
alter table public.outbox_jobs alter event_id drop not null;
alter table public.outbox_jobs add lease_token uuid,add lease_until timestamptz,add last_error text check(last_error in('dispatch_failed','lease_expired')),add delivered_at timestamptz,add dispatch_version integer not null default 1,add reminder_key text unique;
alter table public.outbox_jobs add check(event_id is not null or reminder_key is not null);
create index outbox_jobs_leases on public.outbox_jobs(lease_until,id)where state='claimed';
create table public.notifications(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references public.outbox_jobs(id),recipient_id uuid not null references public.term_memberships(id),
 target_kind text not null check(target_kind in('task','deliverable','request','agreement','handoff','mention')),target_id uuid not null,
 read_at timestamptz,version integer not null default 1,created_at timestamptz not null default statement_timestamp(),unique(job_id,recipient_id)
);
create index notifications_recipient on public.notifications(recipient_id,created_at desc,id);
create table public.notification_preferences(
 membership_id uuid primary key references public.term_memberships(id),mode text not null default 'immediate'check(mode in('immediate','digest','mute')),version integer not null default 1,
 updated_at timestamptz not null default statement_timestamp()
);
alter table public.notifications enable row level security;alter table public.notifications force row level security;
alter table public.notification_preferences enable row level security;alter table public.notification_preferences force row level security;
revoke all on public.notifications,public.notification_preferences,public.outbox_jobs from public,anon,authenticated,service_role;

-- Stored rows are opaque routing references. Only the actual caller's existing scope can project them.
create function app_private.notification_row(n public.notifications)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;j public.outbox_jobs;a public.synergy_agreements;h public.handoffs;c public.comments;req public.requests;instance public.workflow_instances;r jsonb;href text;actionable boolean:=false;label text;state text;begin
 select *into j from public.outbox_jobs where id=n.job_id;select *into w from public.work_items where id=case when n.target_kind='task'then n.target_id else j.work_item_id end;
 if n.recipient_id is distinct from public.current_term_membership(w.term_id)then return null;end if;
 if j.reminder_key is not null and j.reminder_key not like w.id::text||':'||coalesce(w.due_on::text,w.due_at::text,'no_deadline')||':%'then return null;end if;
 if n.target_kind='agreement'then select *into a from public.synergy_agreements where id=n.target_id;if a.id is null or not app_private.synergy_visible(a)then return null;end if;href:='/working-together/'||a.id;state:=a.state;r:=public.read_synergy(a.id);actionable:=jsonb_array_length(coalesce(r->'interface'->'actions','[]'))>0;label:='Committee agreement update';
 elsif n.target_kind='handoff'then select *into h from public.handoffs where id=n.target_id;if h.id is null or not app_private.handoff_visible(h)then return null;end if;href:='/working-together/handoffs/'||h.id;state:=h.state;actionable:=(h.state='proposed'and app_private.handoff_receiver(h))or(h.state='changes_requested'and app_private.handoff_sender(h));label:='Handoff update';
 elsif n.target_kind='request'then
 r:=public.read_request_workflow(w.term_id,w.id);if r is null then return null;end if;state:=r->>'state';
 if exists(select 1 from public.work_items x join public.term_memberships tm on tm.member_id=x.owner_member_id and tm.term_id=x.term_id where x.id=w.id and tm.id=n.recipient_id)then
 r:=public.read_request(w.term_id,w.id);if r is null then return null;end if;state:=r->>'state';actionable:=state in('needs_revision','revision_draft','draft');href:=case r->>'governedKind'when 'fin'then '/finance/'when 'mcd'then '/publicity/'else '/requests/'end||w.term_id||'/'||w.id;
 else
 actionable:=coalesce((r->>'canAct')::boolean,false)or jsonb_array_length(coalesce(r->'actions','[]'))>0;
 select *into req from public.requests where work_item_id=w.id;select *into instance from public.workflow_instances where revision_id=req.current_revision_id;
 if exists(select 1 from public.finance_cases where request_id=w.id)then actionable:=(app_private.finance_assignment(req,n.recipient_id)).id is not null and req.request_state='in_review'and instance.state='active'and app_private.finance_entry(req,instance)is null;
 elsif exists(select 1 from public.publicity_reviews where request_id=w.id)then actionable:=(app_private.publicity_assignment(req,n.recipient_id)).id is not null and req.request_state='in_review'and instance.state='active'and app_private.publicity_entry(req,instance)is null;end if;

 href:=case when exists(select 1 from public.finance_cases where request_id=w.id)then '/finance/reviews/'when exists(select 1 from public.publicity_reviews where request_id=w.id)then '/publicity/'else '/reviews/'end||w.term_id||'/'||w.id;
 end if;label:='Restricted request update';
 else
 if not public.can_access_work(w.id,'detail')or w.archived_at is not null then return null;end if;
 if n.target_kind='mention'then select *into c from public.comments where id=n.target_id and work_item_id=w.id;if c.state is distinct from 'published'or not exists(select 1 from public.comment_revisions cr join public.term_memberships tm on tm.member_id=any(cr.mentions)where cr.comment_id=c.id and cr.revision=c.version and tm.id=n.recipient_id)then return null;end if;label:='You were mentioned in permitted work';end if;
 if w.kind='task'then select workflow_state into state from public.tasks where work_item_id=w.id;actionable:=state not in('done','cancelled');href:='/tasks/'||w.id;label:=coalesce(label,'Task assignment or progress update');
 elsif w.kind='deliverable'then r:=public.read_deliverable_readiness(w.id);state:=r->>'category';actionable:=coalesce((r->>'canSubmit')::boolean,false)or coalesce((r->>'canAccept')::boolean,false)or(coalesce((r->>'canReopen')::boolean,false)and coalesce((r->>'reviewRequired')::boolean,false));href:='/deliverables/'||w.id;label:=coalesce(label,'Deliverable review update');
 else return null;end if;
 end if;
 if j.event_type='work_due'then label:='Work due reminder';elsif j.event_type='work_overdue'then label:='Overdue work reminder';end if;
 return jsonb_build_object('id',n.id,'version',n.version,'label',label,'href',href,'actionable',coalesce(actionable,false),'state',coalesce(state,'updated'),'read',n.read_at is not null,'at',n.created_at);
end$$;

create function public.read_notifications(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m uuid;rows jsonb;total integer;unread integer;pref public.notification_preferences;begin
 m:=public.current_term_membership(p_term_id);if m is null or not public.has_capability(p_term_id,'workspace.read')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 with visible as(select n.created_at,n.id,app_private.notification_row(n)r from public.notifications n where n.recipient_id=m),allowed as(select *from visible where r is not null),page as(select *from allowed order by created_at desc,id desc offset(p_page-1)*20 limit 20)
 select coalesce((select jsonb_agg(r order by created_at desc,id desc)from page),'[]'),(select count(*)from allowed),(select count(*)from allowed where not(r->>'read')::boolean)into rows,total,unread;
 select *into pref from public.notification_preferences where membership_id=m;
 return jsonb_build_object('items',rows,'unread',unread,'hasMore',p_page*20<total,'preference',jsonb_build_object('mode',coalesce(pref.mode,'immediate'),'version',coalesce(pref.version,0)),'canManage',public.has_capability(p_term_id,'admin.configure'));
end$$;
create function app_private.notification_receipt(term uuid,command text,key uuid,payload jsonb,result jsonb)returns jsonb language plpgsql set search_path='' as $$begin
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)select auth.uid(),command,key,organization_id,id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),result from public.terms where id=term;return result;end$$;
create function public.set_notification_read(p_notification_id uuid,p_read boolean,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare n public.notifications;term uuid;payload jsonb;result jsonb;begin
 select *into n from public.notifications where id=p_notification_id for update;if n.id is null or app_private.notification_row(n)is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select term_id into term from public.term_memberships where id=n.recipient_id;payload:=jsonb_build_array(p_notification_id,p_read,p_expected_version);result:=app_private.begin_work_command('set_notification_read',p_request_id,payload);if result is not null then return result;end if;
 if n.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;if p_read is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.notifications set read_at=case when p_read then statement_timestamp()end,version=version+1 where id=n.id returning *into n;
 return app_private.notification_receipt(term,'set_notification_read',p_request_id,payload,jsonb_build_object('id',n.id,'version',n.version,'read',p_read));end$$;
create function public.set_notification_preference(p_term_id uuid,p_mode text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare m uuid;v integer;payload jsonb;result jsonb;begin
 m:=public.current_term_membership(p_term_id);if m is null or not public.has_capability(p_term_id,'workspace.read')then raise exception using errcode='42501',message='command_permission_denied';end if;perform pg_advisory_xact_lock(hashtextextended('notification_preference:'||m,0));
 payload:=jsonb_build_array(p_term_id,p_mode,p_expected_version);result:=app_private.begin_work_command('set_notification_preference',p_request_id,payload);if result is not null then return result;end if;
 select coalesce((select version from public.notification_preferences where membership_id=m),0)into v;if v is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;if p_mode is null or p_mode not in('immediate','digest','mute')then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.notification_preferences(membership_id,mode)values(m,p_mode)on conflict(membership_id)do update set mode=excluded.mode,version=notification_preferences.version+1,updated_at=statement_timestamp()returning version into v;
 return app_private.notification_receipt(p_term_id,'set_notification_preference',p_request_id,payload,jsonb_build_object('version',v,'mode',p_mode));end$$;

-- Lease ownership is separate from delivery, so a crashed worker leaves recoverable committed state.
create function public.claim_notification_jobs(p_limit integer default 20)returns jsonb language plpgsql security definer set search_path='' as $$declare j public.outbox_jobs;rows jsonb:='[]';begin
 if p_limit is null or p_limit not between 1 and 20 then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.outbox_jobs set state='failed',last_error='lease_expired',lease_token=null,lease_until=null,dispatch_version=dispatch_version+1 where id in(select id from public.outbox_jobs where state='claimed'and lease_until<=statement_timestamp()and attempts>=5 order by lease_until,id for update skip locked limit p_limit);
 for j in select *from public.outbox_jobs where(state='pending'and next_at<=statement_timestamp()or state='claimed'and lease_until<=statement_timestamp())and attempts<5 order by next_at,id for update skip locked limit p_limit loop
 update public.outbox_jobs set state='claimed',attempts=attempts+1,lease_token=gen_random_uuid(),lease_until=statement_timestamp()+interval'60 seconds',dispatch_version=dispatch_version+1 where id=j.id returning *into j;
 rows:=rows||jsonb_build_array(jsonb_build_object('id',j.id,'lease',j.lease_token));end loop;return rows;end$$;
create function app_private.notification_deliver(j public.outbox_jobs)returns integer language plpgsql set search_path='' as $$
declare w public.work_items;kind text;target uuid;a public.synergy_agreements;h public.handoffs;recipient public.term_memberships;matches boolean;recipient_kind text;recipient_target uuid;count integer:=0;begin
 select *into w from public.work_items where id=j.work_item_id;
 if j.event_type='comment_mentions'then kind:='mention';target:=(j.payload->>'commentId')::uuid;
 elsif j.payload?'agreementId'then kind:='agreement';target:=(j.payload->>'agreementId')::uuid;select *into a from public.synergy_agreements where id=target;
 elsif j.payload?'handoffId'then kind:='handoff';target:=(j.payload->>'handoffId')::uuid;select *into h from public.handoffs where id=target;
 elsif w.kind='task'and j.event_type in('create_task','update_task','assign_task','transition_task','work_due','work_overdue')then kind:='task';target:=w.id;
 elsif w.kind='deliverable'and j.event_type in('create_deliverable','update_deliverable','submit_deliverable','accept_deliverable','reopen_deliverable','declare_deliverable_work_types','work_due','work_overdue')then kind:='deliverable';target:=w.id;
 elsif w.kind='request'and j.event_type in('submit_request','revise_request','activate_request_workflow','transition_request','begin_request_revision','cancel_request','triage_request','submit_finance_request','activate_finance_review','decide_finance_request','change_financial_authorization','submit_publicity_request','activate_publicity_review','decide_publicity_request','revoke_publicity_approval')then kind:='request';target:=w.id;
 else return 0;end if;
 for recipient in select tm.*from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=w.term_id and tm.status='active'and tm.membership_kind='core'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and m.account_state='active'loop
 matches:=case kind
 when 'mention'then exists(select 1 from public.comments c join public.comment_revisions r on r.comment_id=c.id and r.revision=c.version where c.id=target and c.state='published'and recipient.member_id=any(r.mentions))
 when 'agreement'then app_private.synergy_head(w.term_id,a.requester_unit_id,recipient.member_id)or app_private.synergy_head(w.term_id,a.receiver_unit_id,recipient.member_id)or exists(select 1 from public.contributions c join public.work_items child on child.id=c.work_item_id where c.agreement_id=a.id and child.owner_member_id=recipient.member_id)
 when 'handoff'then recipient.member_id in(h.sender_member_id,h.receiver_member_id)
 when 'request'then recipient.member_id=w.owner_member_id or exists(select 1 from public.approval_assignments ass join public.workflow_instances x on x.id=ass.instance_id where ass.request_id=w.id and ass.reviewer_id=recipient.id and ass.generation=x.generation and app_private.workflow_assignment_current(ass))or exists(select 1 from public.requests r where r.work_item_id=w.id and app_private.synergy_head(w.term_id,r.receiving_unit_id,recipient.member_id))
 else recipient.member_id=w.owner_member_id or(kind='deliverable'and exists(select 1 from public.deliverable_readiness_policies p where p.work_item_id=w.id and app_private.readiness_authority(p.acceptor_authority_id,p.acceptor_authority_version,w.term_id,w.lead_unit_id)=recipient.id))end;
 if matches then recipient_kind:=kind;recipient_target:=target;
 if kind='agreement'and not app_private.synergy_head(w.term_id,a.requester_unit_id,recipient.member_id)and not app_private.synergy_head(w.term_id,a.receiver_unit_id,recipient.member_id)then select c.work_item_id into recipient_target from public.contributions c join public.work_items child on child.id=c.work_item_id where c.agreement_id=a.id and child.owner_member_id=recipient.member_id;recipient_kind:='task';end if;
 insert into public.notifications(job_id,recipient_id,target_kind,target_id)values(j.id,recipient.id,recipient_kind,recipient_target)on conflict(job_id,recipient_id)do nothing;get diagnostics count=row_count;end if;
 end loop;return count;end$$;
create function public.deliver_notification_job(p_job_id uuid,p_lease uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare j public.outbox_jobs;begin
 select *into j from public.outbox_jobs where id=p_job_id for update;
 if j.id is null or j.state<>'claimed'or j.lease_token is distinct from p_lease or j.lease_until<=statement_timestamp()then return jsonb_build_object('state','stale_lease');end if;
 begin
 perform app_private.notification_deliver(j);
 update public.outbox_jobs set state='delivered',delivered_at=statement_timestamp(),lease_token=null,lease_until=null,last_error=null,dispatch_version=dispatch_version+1 where id=j.id;
 exception when others then
 update public.outbox_jobs set state=case when attempts>=5 then 'failed'else 'pending'end,last_error='dispatch_failed',next_at=statement_timestamp()+make_interval(secs=>least(3600,30*(2^greatest(attempts-1,0))::integer)),lease_token=null,lease_until=null,dispatch_version=dispatch_version+1 where id=j.id;
 end;return(select jsonb_build_object('state',state)from public.outbox_jobs where id=j.id);end$$;
create function public.read_notification_failures(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 if not public.has_capability(p_term_id,'admin.configure')then raise exception using errcode='42501',message='command_permission_denied';end if;
 return jsonb_build_object('items',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'version',q.dispatch_version,'state',q.state,'attempts',q.attempts,'code',q.last_error,'nextAt',q.next_at)order by q.next_at,q.id)from(select j.*from public.outbox_jobs j join public.work_items w on w.id=j.work_item_id where w.term_id=p_term_id and j.state in('failed','pending','claimed')and j.attempts>0 order by j.next_at,j.id limit 50)q),'[]'));end$$;
create function public.retry_notification_job(p_term_id uuid,p_job_id uuid,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare j public.outbox_jobs;w public.work_items;payload jsonb;result jsonb;begin
 if not public.has_capability(p_term_id,'admin.configure')then raise exception using errcode='42501',message='command_permission_denied';end if;
 select *into j from public.outbox_jobs where id=p_job_id for update;select *into w from public.work_items where id=j.work_item_id;if w.term_id is distinct from p_term_id then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_job_id,p_expected_version,p_reason);result:=app_private.begin_work_command('retry_notification_job',p_request_id,payload);if result is not null then return result;end if;
 if j.dispatch_version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;if j.state<>'failed'or p_reason is null or length(btrim(p_reason))not between 1 and 1000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.outbox_jobs set state='pending',attempts=0,next_at=statement_timestamp(),last_error=null,dispatch_version=dispatch_version+1 where id=j.id returning *into j;
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(w.organization_id,w.term_id,auth.uid(),'Authorized notification custodian','retry_notification_job',w.id,w.version,p_request_id,'{"fields":["queue_retry"]}');
 return app_private.notification_receipt(p_term_id,'retry_notification_job',p_request_id,payload,jsonb_build_object('id',j.id,'version',j.dispatch_version));end$$;

-- Bounded fixed in-app reminder skeleton; configurable policies/external quiet-time delivery are later work.
create function public.enqueue_notification_reminders(p_limit integer default 100)returns integer language plpgsql security definer set search_path='' as $$
declare w public.work_items;day date:=(statement_timestamp()at time zone'Asia/Manila')::date;due date;event text;key text;n integer:=0;added integer;begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception using errcode='22023',message='command_validation_failed';end if;
 for w in select wi.*from public.work_items wi left join public.tasks t on t.work_item_id=wi.id left join public.deliverables d on d.work_item_id=wi.id where wi.archived_at is null and wi.kind in('task','deliverable')and coalesce(t.workflow_state,d.workflow_state)not in('done','accepted','cancelled')and(coalesce(wi.due_on,(wi.due_at at time zone'Asia/Manila')::date)<=day or coalesce(wi.due_on,(wi.due_at at time zone'Asia/Manila')::date)=day+2) and not exists(select 1 from public.outbox_jobs j where j.reminder_key=wi.id::text||':'||coalesce(wi.due_on::text,wi.due_at::text)||':'||day::text)order by wi.id limit p_limit loop
 due:=coalesce(w.due_on,(w.due_at at time zone'Asia/Manila')::date);if due not in(day,day+2)and due>=day then continue;end if;event:=case when due<day then 'work_overdue'else 'work_due'end;key:=w.id::text||':'||coalesce(w.due_on::text,w.due_at::text)||':'||day::text;
 insert into public.outbox_jobs(work_item_id,event_type,payload,reminder_key)values(w.id,event,jsonb_build_object('workItemId',w.id),key)on conflict(reminder_key)do nothing;get diagnostics added=row_count;n:=n+added;end loop;return n;end$$;

do $$declare f text;begin for f in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'and p.proname like 'notification_%'loop execute 'revoke all on function '||f||' from public,anon,authenticated,service_role';end loop;end$$;
revoke all on function public.read_notifications(uuid,integer),public.set_notification_read(uuid,boolean,integer,uuid),public.set_notification_preference(uuid,text,integer,uuid),public.read_notification_failures(uuid),public.retry_notification_job(uuid,uuid,integer,text,uuid),public.claim_notification_jobs(integer),public.deliver_notification_job(uuid,uuid),public.enqueue_notification_reminders(integer)from public,anon,authenticated,service_role;
grant execute on function public.read_notifications(uuid,integer),public.set_notification_read(uuid,boolean,integer,uuid),public.set_notification_preference(uuid,text,integer,uuid),public.read_notification_failures(uuid),public.retry_notification_job(uuid,uuid,integer,text,uuid)to authenticated;
grant execute on function public.claim_notification_jobs(integer),public.deliver_notification_job(uuid,uuid),public.enqueue_notification_reminders(integer)to service_role;
