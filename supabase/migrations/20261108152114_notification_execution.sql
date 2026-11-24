-- P41 local execution boundary. No cron, trigger, live cadence or external transport.
-- Only an explicit service call selects an immutable proposal version and bounded window.
create table public.notification_digests(
 id uuid primary key default gen_random_uuid(),recipient_id uuid not null references public.term_memberships(id),
 logical_day date not null,created_at timestamptz not null default statement_timestamp(),unique(recipient_id,logical_day)
);
create table public.notification_rule_reservations(
 job_id uuid primary key references public.outbox_jobs(id),work_item_id uuid not null references public.work_items(id),
 recipient_id uuid not null references public.term_memberships(id),rule_version_id uuid not null references public.presentation_versions(id),
 deadline text not null,logical_day date not null,event text not null check(event in('before_due','due','overdue')),
 scheduled_at timestamptz not null,optional_at timestamptz not null,
 channel text not null check(channel in('in_app','email','telegram')),mode text not null check(mode in('immediate','digest','mute')),
 digest_id uuid references public.notification_digests(id),created_at timestamptz not null default statement_timestamp(),
 unique(work_item_id,deadline,logical_day)
);
do $$declare t text;begin foreach t in array array['notification_digests','notification_rule_reservations']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 execute format('create trigger immutable_notification_reservation before update or delete on public.%I for each row execute function app_private.deny_deliverable_history()',t);
end loop;end$$;

-- Deliberately narrower than arbitrary recipient impersonation: the closed audience is the
-- current task/deliverable owner. Reuse P30's owner routing and P14/P16 owner access branch.
create function app_private.notification_assignee(w public.work_items)returns uuid language sql stable security definer set search_path='' as $$
 select tm.id from public.term_memberships tm join public.members m on m.id=tm.member_id
 join public.terms t on t.id=tm.term_id join public.organizations o on o.id=t.organization_id
 where tm.term_id=w.term_id and tm.member_id=w.owner_member_id and tm.membership_kind='core'
 and app_private.comment_member_eligible(w,m.id) and app_private.is_school_identity(m.auth_user_id)
 and app_private.verified_google_email(m.auth_user_id)=m.normalized_email
 and t.state in('active','frozen')and o.state='active'
 and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on
 and exists(select 1 from app_private.effective_role_assignments a join public.role_permissions p on p.role_id=a.role_id and p.allowed_scope=a.scope_type
 where a.term_membership_id=tm.id and a.term_id=w.term_id and a.scope_type in('own','term')and p.capability='workspace.read'and app_private.access_assignment_live(a.id))
$$;
create function app_private.notification_pending(w public.work_items)returns boolean language sql stable security definer set search_path='' as $$
 select w.archived_at is null and w.kind in('task','deliverable')and coalesce(w.due_on,(w.due_at at time zone'Asia/Manila')::date)is not null
 and exists(select 1 from public.tasks where work_item_id=w.id and workflow_state not in('done','cancelled')union all select 1 from public.deliverables where work_item_id=w.id and workflow_state not in('accepted','cancelled'))
$$;
create function public.preview_notification_recipients(p_draft_id uuid,p_expected_version integer,p_after uuid default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d public.presentation_drafts;items jsonb;cursor uuid;current_version integer;begin
 select *into d from public.presentation_drafts where id=p_draft_id and kind='notification'and actor_id=auth.uid();
 if d.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id);
 if d.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select coalesce(max(v.version),0)into current_version from public.presentation_controls c join public.presentation_versions v on v.control_id=c.work_item_id
 where c.term_id=d.term_id and c.kind='notification'and c.target_kind='term'and c.target_id=d.term_id;
 if d.published_version_id is not null or d.base_version<>current_version then raise exception using errcode='40001',message='command_stale_version';end if;
 perform app_private.validate_presentation('notification',d.definition);
 with allowed as materialized(select w.*,app_private.notification_assignee(w)recipient from public.work_items w
 where w.term_id=d.term_id and(p_after is null or w.id>p_after)and app_private.notification_pending(w)and public.can_access_work(w.id,'detail')),
 page as materialized(select *from allowed where recipient is not null order by id limit 21),shown as(select *from page order by id limit 20)
 select coalesce((select jsonb_agg(jsonb_build_object('workId',s.id,'name',m.display_name,'title',s.title,
 'href',case s.kind when 'task'then '/tasks/'else '/deliverables/'end||s.id,'dueOn',coalesce(s.due_on,(s.due_at at time zone'Asia/Manila')::date),
 'action',case s.kind when 'task'then 'Open task and update progress'else 'Open deliverable and check submission'end)order by s.id)
 from shown s join public.term_memberships tm on tm.id=s.recipient join public.members m on m.id=tm.member_id),'[]'),
 case when(select count(*)from page)>20 then(select id from shown order by id desc limit 1)end into items,cursor;
 return jsonb_build_object('items',items,'nextAfter',cursor,'sends',false,'externalAvailable',false,
 'template','You have an update. Open your workspace to check the current permitted action.');
end$$;

create function public.reserve_notification_window(p_term_id uuid,p_rule_version_id uuid,p_from timestamptz,p_to timestamptz,p_after uuid default null,p_limit integer default 100)returns jsonb
language plpgsql security definer set search_path='' set timezone='UTC' as $$
<<execution>>
declare rule jsonb;w public.work_items;recipient uuid;due date;day date;delta integer;event text;deadline text;key text;job uuid;digest uuid;
 at timestamptz;optional_at timestamptz;h integer;qs integer;qe integer;mode text;n integer:=0;cursor uuid;seen integer:=0;begin
 if p_from is null or p_to is null or not isfinite(p_from)or not isfinite(p_to)or p_to<=p_from or p_to-p_from>interval'31 days'or p_limit is null or p_limit not between 1 and 100 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select v.definition into rule from public.presentation_versions v join public.presentation_controls c on c.work_item_id=v.control_id
 where v.id=p_rule_version_id and c.term_id=p_term_id and c.kind='notification'and c.target_kind='term'and c.target_id=p_term_id;
 if rule is null or not exists(select 1 from public.terms where id=p_term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.validate_presentation('notification',rule);
 perform pg_advisory_xact_lock(hashtextextended('notification-window:'||p_term_id,0));
 h:=(rule->>'hour')::integer;qs:=(rule->>'quietStart')::integer;qe:=(rule->>'quietEnd')::integer;
 for w in select wi.*from public.work_items wi where wi.term_id=p_term_id and(p_after is null or wi.id>p_after)and app_private.notification_pending(wi)order by wi.id limit p_limit loop
 cursor:=w.id;seen:=seen+1;recipient:=app_private.notification_assignee(w);if recipient is null then continue;end if;
 due:=coalesce(w.due_on,(w.due_at at time zone'Asia/Manila')::date);deadline:=coalesce(w.due_on::text,w.due_at::text);
 select case when pref.mode='mute'or rule->>'mode'='mute'then 'mute'when pref.mode='digest'or rule->>'mode'='digest'then 'digest'else 'immediate'end into mode from public.notification_preferences pref where pref.membership_id=recipient;
 mode:=coalesce(mode,rule->>'mode');
 for day in select generate_series((p_from at time zone'Asia/Manila')::date,(p_to at time zone'Asia/Manila')::date,interval'1 day')::date loop
 delta:=day-due;event:=case when delta=-(rule->>'beforeDays')::integer then 'before_due'when delta=0 and(rule->>'dueDay')::boolean then 'due'when delta>0 and(delta-1)%(rule->>'overdueEveryDays')::integer=0 then 'overdue'end;
 at:=(day+make_time(h,0,0))at time zone'Asia/Manila';if event is null or at<p_from or at>=p_to then continue;end if;
 key:=w.id::text||':'||deadline||':'||day::text;
 if exists(select 1 from public.notification_rule_reservations r where r.work_item_id=w.id and r.deadline=execution.deadline and r.logical_day=day)then continue;end if;
 optional_at:=at;
 if rule->>'channel'<>'in_app'and(case when qs>qe then h>=qs or h<qe else h>=qs and h<qe end)then optional_at:=((day+case when qs>qe and h>=qs then 1 else 0 end)+make_time(qe,0,0))at time zone'Asia/Manila';end if;
 digest:=null;if mode='digest'then insert into public.notification_digests(recipient_id,logical_day)values(recipient,day)on conflict(recipient_id,logical_day)do nothing;select id into digest from public.notification_digests where recipient_id=recipient and logical_day=day;end if;
 insert into public.outbox_jobs(work_item_id,event_type,payload,reminder_key,next_at)values(w.id,case when event='overdue'then 'work_overdue'else 'work_due'end,jsonb_build_object('workItemId',w.id),key,at)on conflict(reminder_key)do nothing;
 select id into job from public.outbox_jobs where reminder_key=key;
 insert into public.notification_rule_reservations(job_id,work_item_id,recipient_id,rule_version_id,deadline,logical_day,event,scheduled_at,optional_at,channel,mode,digest_id)
 values(job,w.id,recipient,p_rule_version_id,deadline,day,event,at,optional_at,rule->>'channel',mode,digest)on conflict do nothing;
 n:=n+1;
 end loop;end loop;
 return jsonb_build_object('reserved',n,'nextAfter',case when seen=p_limit then cursor end,'externalAdapters','disabled');
end$$;

alter function app_private.notification_deliver(public.outbox_jobs)rename to notification_deliver_before_rules;
create function app_private.notification_deliver(j public.outbox_jobs)returns integer language plpgsql set search_path='' set timezone='UTC' as $$
declare r public.notification_rule_reservations;w public.work_items;n integer:=0;begin
 select *into r from public.notification_rule_reservations where job_id=j.id;
 if r.job_id is null then return app_private.notification_deliver_before_rules(j);end if;
 select *into w from public.work_items where id=r.work_item_id;
 -- Current owner/scope/deadline and pending status, not the earlier reservation, control delivery.
 if not app_private.notification_pending(w)or app_private.notification_assignee(w)is distinct from r.recipient_id
 or coalesce(w.due_on::text,w.due_at::text)is distinct from r.deadline then return 0;end if;
 insert into public.notifications(job_id,recipient_id,target_kind,target_id)values(j.id,r.recipient_id,w.kind,w.id)on conflict(job_id,recipient_id)do nothing;
 get diagnostics n=row_count;return n;
end$$;

-- P30 and configurable jobs share the same canonical deadline representation even
-- when independently invoked service sessions use different timezone settings.
alter function public.enqueue_notification_reminders(integer) set timezone='UTC';
alter function app_private.notification_row(public.notifications)rename to notification_row_before_rules;
alter function app_private.notification_row_before_rules(public.notifications)set timezone='UTC';
create function app_private.notification_row(n public.notifications)returns jsonb language plpgsql stable security definer set search_path='' set timezone='UTC' as $$
declare r public.notification_rule_reservations;w public.work_items;begin
 select *into r from public.notification_rule_reservations where job_id=n.job_id;
 if r.job_id is not null then
 select *into w from public.work_items where id=r.work_item_id;
 if not app_private.notification_pending(w)or app_private.notification_assignee(w)is distinct from n.recipient_id
 or coalesce(w.due_on::text,w.due_at::text)is distinct from r.deadline then return null;end if;
 end if;
 return app_private.notification_row_before_rules(n);
end$$;

create function app_private.notification_action(r jsonb)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;detail jsonb;action text;can_act boolean:=false;begin
 if r->>'href'not like '/tasks/%'and r->>'href'not like '/deliverables/%'then return '{}'::jsonb;end if;
 select *into w from public.work_items where id=split_part(r->>'href','/',3)::uuid;
 if not public.can_access_work(w.id,'detail')then return '{}'::jsonb;end if;
 if w.kind='task'then
 detail:=public.read_task(w.id);
 action:=case when detail->'progressActions'?'in_progress'then case when detail->>'state'='blocked'then 'Open task and resume work'else 'Open task and start work'end
 when detail->'progressActions'?'ready_for_review'then 'Open task and send for review'
 when detail->'progressActions'?'done'then case when detail->>'taskType'='review_required'then 'Open task and accept evidence'else 'Open task and complete work'end
 when detail->>'blockedReason'is not null or coalesce((detail->>'dependencyBlocked')::boolean,false)then 'Open task and check blockers'else 'Open task and check progress'end;
 can_act:=jsonb_array_length(coalesce(detail->'progressActions','[]'))>0;
 else
 detail:=public.read_deliverable_readiness(w.id);
 action:=case when(detail->>'canSubmit')::boolean then 'Open deliverable and send for review'when(detail->>'canAccept')::boolean then 'Open deliverable and accept submission'
 when coalesce((detail->>'canReopen')::boolean,false)and coalesce((detail->>'reviewRequired')::boolean,false)then 'Open deliverable and reopen review'else 'Open deliverable and check readiness'end;
 can_act:=coalesce((detail->>'canSubmit')::boolean,false)or coalesce((detail->>'canAccept')::boolean,false)
 or(coalesce((detail->>'canReopen')::boolean,false)and coalesce((detail->>'reviewRequired')::boolean,false));
 end if;
 return jsonb_build_object('subject',w.title,'owner',w.owner_display_name,'dueOn',coalesce(w.due_on,(w.due_at at time zone'Asia/Manila')::date),'reference',app_private.work_reference(w.id)->>'value','action',action,'actionable',can_act);
end$$;

-- One current permitted action per destination. Raw P30 reads/history stay compatible.
create function app_private.notification_groups(p_term uuid)returns setof jsonb language sql stable security definer set search_path='' as $$
 with allowed as materialized(select n.job_id,app_private.notification_row(n)r from public.notifications n where n.recipient_id=public.current_term_membership(p_term)),
 ranked as(select r,max((select d.logical_day from public.notification_rule_reservations item join public.notification_digests d on d.id=item.digest_id where item.job_id=allowed.job_id))over(partition by r->>'href')digest_day,row_number()over(partition by r->>'href'order by(r->>'at')::timestamptz desc,r->>'id'desc)rank,
 count(*)over(partition by r->>'href')updates,sum((r->>'version')::integer)over(partition by r->>'href')v,
 encode(sha256(convert_to((jsonb_agg(jsonb_build_array(r->>'id',r->>'version'))over(partition by r->>'href'order by r->>'id'rows between unbounded preceding and unbounded following))::text,'UTF8')),'hex')snapshot,
 bool_and((r->>'read')::boolean)over(partition by r->>'href')seen from allowed where r is not null)
 select r||jsonb_build_object('version',v,'read',seen,'count',updates,'snapshot',snapshot,
 'digestDay',digest_day,
 'action',case when(r->>'actionable')::boolean then
 case when r->>'href'like '/tasks/%'then 'Open task and update progress'when r->>'href'like '/deliverables/%'then 'Open deliverable and check submission'
 when r->>'href'like '/working-together/handoffs/%'then 'Open handoff and review response'when r->>'href'like '/working-together/%'then 'Open agreement and review response'
 else 'Open request and review current decision'end else 'Open current update'end)||app_private.notification_action(r)from ranked where rank=1
$$;
create function public.read_notification_groups(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare base jsonb;rows jsonb;total integer;unread integer;begin
 base:=public.read_notifications(p_term_id,p_page);
 with allowed as materialized(select r from app_private.notification_groups(p_term_id)r),page as(select r from allowed order by(r->>'at')::timestamptz desc,r->>'id'desc offset(p_page-1)*20 limit 20)
 select coalesce((select jsonb_agg(r order by(r->>'at')::timestamptz desc,r->>'id'desc)from page),'[]'),(select count(*)from allowed),(select count(*)from allowed where not(r->>'read')::boolean)into rows,total,unread;
 return base||jsonb_build_object('items',rows,'unread',unread,'hasMore',p_page*20<total);
end$$;
create function public.set_notification_group_read(p_notification_id uuid,p_read boolean,p_expected_version integer,p_request_id uuid,p_expected_snapshot text)returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.notifications;term uuid;row jsonb;href text;ids uuid[];v integer;payload jsonb;result jsonb;begin
 select *into item from public.notifications where id=p_notification_id;row:=app_private.notification_row(item);
 if row is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select term_id into term from public.term_memberships where id=item.recipient_id;
 if not public.has_capability(term,'workspace.read')then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform pg_advisory_xact_lock(hashtextextended('notification-group:'||item.recipient_id||':'||(row->>'href'),0));
 href:=row->>'href';
 -- Lock the currently allowed group in a stable order before checking its aggregate version.
 perform 1 from public.notifications n where n.recipient_id=item.recipient_id and app_private.notification_row(n)->>'href'=href order by n.id for update;
 payload:=jsonb_build_array(p_notification_id,p_read,p_expected_version,p_expected_snapshot);result:=app_private.begin_work_command('set_notification_group_read',p_request_id,payload);if result is not null then return result;end if;
 select array_agg(n.id),sum(n.version)::integer into ids,v from public.notifications n where n.recipient_id=item.recipient_id and app_private.notification_row(n)->>'href'=href;
 if v is distinct from p_expected_version or p_expected_snapshot is distinct from(select g->>'snapshot'from app_private.notification_groups(term)g where g->>'href'=href)then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_read is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.notifications set read_at=case when p_read then statement_timestamp()end,version=version+1 where id=any(ids);
 return app_private.notification_receipt(term,'set_notification_group_read',p_request_id,payload,jsonb_build_object('id',item.id,'version',v+cardinality(ids),'read',p_read));
end$$;
do $$declare f text;begin for f in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'and p.proname like 'notification_%'loop execute 'revoke all on function '||f||' from public,anon,authenticated,service_role';end loop;end$$;
revoke all on function public.preview_notification_recipients(uuid,integer,uuid),public.reserve_notification_window(uuid,uuid,timestamptz,timestamptz,uuid,integer),public.read_notification_groups(uuid,integer),public.set_notification_group_read(uuid,boolean,integer,uuid,text)from public,anon,authenticated,service_role;
grant execute on function public.preview_notification_recipients(uuid,integer,uuid),public.read_notification_groups(uuid,integer),public.set_notification_group_read(uuid,boolean,integer,uuid,text)to authenticated;
grant execute on function public.reserve_notification_window(uuid,uuid,timestamptz,timestamptz,uuid,integer)to service_role;
