begin;
create table app_private.turnover_object_corrections(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),custody_id uuid not null references app_private.turnover_custody(id),
 object_id uuid not null,category text not null check(category='prism'),reference text not null check(length(btrim(reference))between 3 and 500),
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp()
);
alter table app_private.turnover_object_corrections enable row level security;
alter table app_private.turnover_object_corrections force row level security;
revoke all on app_private.turnover_object_corrections from public,anon,authenticated,service_role;
create trigger immutable_turnover_object_corrections before update or delete on app_private.turnover_object_corrections for each row execute function app_private.request_history_guard();
create function app_private.turnover_custody_root(p_term uuid,p_category text,p_id uuid)returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from public.work_items w where w.id=p_id and w.term_id=p_term and app_private.retention_work_category(w.id)=p_category)
 or p_category='prism'and(exists(select 1 from app_private.evaluation_cases where id=p_id and term_id=p_term)
 or exists(select 1 from app_private.feedback_rounds where id=p_id and term_id=p_term))
$$;
revoke all on function app_private.turnover_custody_root(uuid,text,uuid)from public,anon,authenticated,service_role;
create or replace function public.propose_turnover_custody(p_case_id uuid,p_expected_version integer,p_recipient uuid,p_category text,
 p_work_ids uuid[],p_authority uuid,p_expires_at timestamptz,p_reference text,p_key uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;n app_private.turnover_custody;payload jsonb;prior jsonb;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;perform app_private.readiness_lock(c.term_id);actor:=app_private.turnover_manager(c);
 select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_expected_version,p_recipient,p_category,p_work_ids,p_authority,p_expires_at,p_reference);
 prior:=app_private.begin_work_command('propose_turnover_custody',p_key,payload);if prior is not null then return prior;end if;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if c.state not in('preparing','frozen') or p_category is null or p_category not in('operational','finance','restricted','prism')
  or p_work_ids is null or cardinality(p_work_ids) not between 1 and 100 or array_position(p_work_ids,null)is not null
  or p_expires_at is null or not isfinite(p_expires_at)or p_expires_at<=statement_timestamp()
  or coalesce(length(btrim(p_reference)),0)not between 3 and 500 then
  raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from unnest(p_work_ids)w(id)where not app_private.turnover_custody_root(c.term_id,p_category,w.id))
  or exists(select 1 from public.term_memberships where id=p_recipient and member_id=actor.member_id)then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 n.term_id:=c.term_id;n.case_id:=c.id;n.recipient_id:=p_recipient;n.category:=p_category;n.work_ids:=p_work_ids;
 n.authority_id:=p_authority;n.expires_at:=p_expires_at;
 select a.version,r.version into n.authority_version,n.role_version from public.role_assignments a join public.roles r on r.id=a.role_id where a.id=p_authority;
 select pc.approved_at into n.custody_approved_at from public.privacy_custodians pc join public.term_memberships tm on tm.term_id=pc.term_id and tm.id=pc.membership_id where tm.id=p_recipient;
 if not coalesce(app_private.turnover_custody_live(n),false)then raise exception using errcode='42501',message='command_permission_denied';end if;
 insert into app_private.turnover_custody(term_id,case_id,recipient_id,category,work_ids,authority_id,authority_version,role_version,custody_approved_at,expires_at,reference)
 values(n.term_id,n.case_id,n.recipient_id,n.category,n.work_ids,n.authority_id,n.authority_version,n.role_version,n.custody_approved_at,n.expires_at,p_reference)
 on conflict(case_id,recipient_id,category)do update set work_ids=excluded.work_ids,authority_id=excluded.authority_id,
 authority_version=excluded.authority_version,role_version=excluded.role_version,custody_approved_at=excluded.custody_approved_at,
 expires_at=excluded.expires_at,reference=excluded.reference,version=turnover_custody.version+1 returning*into n;
 update app_private.turnover_cases set version=version+1 where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'propose_turnover_custody',p_key,payload,n.id);
end $$;

create or replace function public.act_archived_custody(p_context_term uuid,p_custody_id uuid,p_expected_version integer,p_action text,p_values jsonb,p_reference text,p_key uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare n app_private.turnover_custody;c app_private.turnover_cases;h public.legal_holds;payload jsonb;prior jsonb;object_id uuid;review_at timestamptz;
begin
 n:=app_private.turnover_custody_actor(p_context_term,p_custody_id);perform app_private.readiness_lock(n.term_id);
 n:=app_private.turnover_custody_actor(p_context_term,p_custody_id);select*into n from app_private.turnover_custody where id=n.id for update;
 select*into c from app_private.turnover_cases where id=n.case_id;
 payload:=jsonb_build_array(p_context_term,p_custody_id,p_expected_version,p_action,p_values,p_reference);
 prior:=app_private.begin_work_command('act_archived_custody',p_key,payload);if prior is not null then return prior;end if;
 if n.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if coalesce(length(btrim(p_reference)),0)not between 3 and 500 or p_action is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_action in('hold','correction')then
  object_id:=(p_values->>'work')::uuid;
  if object_id is null or not(object_id=any(n.work_ids))then raise exception using errcode='42501',message='command_permission_denied';end if;
  if p_action='hold'then
   review_at:=(p_values->>'reviewAt')::timestamptz;
   if review_at is null or not isfinite(review_at)or review_at<=statement_timestamp()then raise exception using errcode='22023',message='command_validation_failed';end if;
   insert into public.legal_holds(term_id,category,object_id,reason,owner_id,review_at)values(n.term_id,n.category,object_id,p_reference,auth.uid(),review_at)returning*into h;
   insert into public.legal_hold_events(hold_id,actor_id,operation,version)values(h.id,auth.uid(),'create',h.version);
  else
   if n.category='prism'then
    insert into app_private.turnover_object_corrections(term_id,custody_id,object_id,category,reference,actor_id)values(n.term_id,n.id,object_id,n.category,p_reference,auth.uid());
   else insert into app_private.turnover_corrections(term_id,case_id,work_id,reference,actor_id)values(n.term_id,n.case_id,object_id,p_reference,auth.uid());end if;
  end if;
 elsif p_action='release_hold'then
  select*into h from public.legal_holds where id=(p_values->>'hold')::uuid for update;
  if h.id is null or h.term_id<>n.term_id or h.category is distinct from n.category or h.object_id is null or not(h.object_id=any(n.work_ids))then
   raise exception using errcode='42501',message='command_permission_denied';end if;
  if h.version is distinct from(p_values->>'holdVersion')::integer then raise exception using errcode='40001',message='command_stale_version';end if;
  if h.released_at is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
  update public.legal_holds set released_at=statement_timestamp(),released_by=auth.uid(),release_reason=p_reference,version=version+1 where id=h.id returning*into h;
  insert into public.legal_hold_events(hold_id,actor_id,operation,version)values(h.id,auth.uid(),'release',h.version);
 else raise exception using errcode='22023',message='command_validation_failed';end if;
 update app_private.turnover_custody set version=version+1 where id=n.id returning*into n;
 c.version:=n.version;
 return app_private.turnover_receipt(c,'act_archived_custody',p_key,payload,coalesce(h.id,n.id));
end $$;

-- Setup is metadata only and is restricted to the designated strong custodian.
create function public.read_turnover_setup(p_term_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;choices jsonb;roots jsonb;
begin
 actor:=app_private.request_actor(p_term_id,false);
 if not app_private.privacy_custodian(p_term_id)or not app_private.privacy_strong_session()then raise exception using errcode='42501',message='command_permission_denied';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'recipient',tm.id,'name',m.display_name||' · '||t.label||' · '||r.name,
  'category',case rp.capability when'finance.review'then'finance'when'feedback.review'then'prism'else'restricted'end,
  'expiresAt',least(a.effective_to,pc.expires_at,tm.ends_at))order by tm.id,a.id),'[]')into choices
 from app_private.effective_role_assignments a join public.roles r on r.id=a.role_id
 join public.role_permissions rp on rp.role_id=r.id and rp.allowed_scope=a.scope_type and rp.capability in('workspace.read','finance.review','feedback.review')
 join public.term_memberships tm on tm.id=a.term_membership_id and tm.term_id<>p_term_id and tm.member_id<>actor.member_id
 join public.terms t on t.id=tm.term_id and t.organization_id=actor.organization_id
 join public.members m on m.id=tm.member_id
 join public.privacy_custodians pc on pc.membership_id=tm.id and pc.term_id=tm.term_id
 where app_private.turnover_person(tm.id,actor.organization_id)and app_private.privacy_custodian_live(tm.term_id,tm.id);
 select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'reference','PRISM custody item '||q.n,'category','prism')),'[]')into roots
 from(select id,row_number()over(order by id)n from(select id from app_private.feedback_rounds where term_id=p_term_id
 union all select id from app_private.evaluation_cases where term_id=p_term_id)r)q;
 insert into app_private.turnover_events(term_id,object_id,actor_id,operation,version)values(p_term_id,p_term_id,auth.uid(),'turnover_setup_read',1);
 return jsonb_build_object('authorities',choices,'privateRoots',roots);
end $$;
revoke all on function public.read_turnover_setup(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_turnover_setup(uuid)to authenticated;

create function app_private.turnover_lock_custody(n app_private.turnover_custody)returns void language plpgsql set search_path='' as $$
begin
 perform app_private.readiness_lock((select term_id from public.term_memberships where id=n.recipient_id));
 perform 1 from public.term_memberships where id=n.recipient_id for share;
 perform 1 from public.privacy_custodians pc join public.term_memberships tm on tm.id=n.recipient_id and tm.term_id=pc.term_id and tm.id=pc.membership_id for share of pc;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.id=n.authority_id for share of a,r;
end $$;
revoke all on function app_private.turnover_lock_custody(app_private.turnover_custody)from public,anon,authenticated,service_role;

create or replace function public.accept_turnover_custody(p_context_term uuid,p_custody_id uuid,p_run_id uuid,p_reference text,p_key uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;n app_private.turnover_custody;c app_private.turnover_cases;payload jsonb;prior jsonb;
begin
 actor:=app_private.request_actor(p_context_term,false);
 select*into n from app_private.turnover_custody where id=p_custody_id;select*into c from app_private.turnover_cases where id=n.case_id;
 perform app_private.readiness_lock(c.term_id);select*into n from app_private.turnover_custody where id=p_custody_id for update;
 perform app_private.turnover_lock_custody(n);
 if n.recipient_id is distinct from actor.id or not app_private.privacy_strong_session()or not coalesce(app_private.turnover_custody_live(n),false)then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_context_term,p_custody_id,p_run_id,p_reference);
 prior:=app_private.begin_work_command('accept_turnover_custody',p_key,payload);if prior is not null then return prior;end if;
 if c.state not in('verified','rehearsal_verified') or coalesce(length(btrim(p_reference)),0)not between 3 and 500
  or not exists(select 1 from app_private.turnover_runs r join app_private.turnover_evidence e on e.run_id=r.id and e.part='complete'and e.restored
   where r.id=p_run_id and r.case_id=c.id and r.source_fingerprint=app_private.turnover_fingerprint(c.term_id)
    and r.disposition_head=app_private.backup_disposition_fingerprint(c.term_id)and r.entry_fingerprint=app_private.turnover_entry_fingerprint(c.id))then
  raise exception using errcode='55000',message='command_turnover_archive_incomplete';end if;
 update app_private.turnover_custody set accepted_at=statement_timestamp(),accepted_run=p_run_id,acceptance_reference=p_reference,version=version+1 where id=n.id;
 return app_private.turnover_receipt(c,'accept_turnover_custody',p_key,payload,n.id);
end $$;


create or replace function app_private.turnover_custody_actor(p_context_term uuid,p_custody_id uuid)returns app_private.turnover_custody
language plpgsql set search_path='' as $$
declare actor public.term_memberships;n app_private.turnover_custody;
begin
 actor:=app_private.request_actor(p_context_term,false);select*into n from app_private.turnover_custody where id=p_custody_id;
 perform app_private.turnover_lock_custody(n);
 if n.recipient_id is distinct from actor.id or not app_private.privacy_strong_session()or not coalesce(app_private.turnover_custody_live(n),false)
  or n.accepted_at is null or not exists(select 1 from app_private.turnover_cases c where c.id=n.case_id and c.state in('complete','rehearsal_complete'))then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 return n;
end $$;


create or replace function public.complete_turnover(p_case_id uuid,p_run_id uuid,p_expected_version integer,p_reference text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;t app_private.turnover_transfers;r jsonb;payload jsonb;prior jsonb;job app_private.turnover_runs;nom app_private.turnover_custody;
begin
 select*into c from app_private.turnover_cases where id=p_case_id;
 payload:=jsonb_build_array(p_case_id,p_run_id,p_expected_version,p_reference);
 -- A completed old term authorizes only the exact existing receipt, never a new action.
 if c.state in('complete','rehearsal_complete')then
  if not app_private.privacy_strong_session()or not exists(select 1 from public.term_memberships tm join public.members m on m.id=tm.member_id
   where tm.id=c.custodian_id and m.auth_user_id=auth.uid()and app_private.turnover_person(tm.id,tm.organization_id))then
   raise exception using errcode='42501',message='command_permission_denied';end if;
  prior:=app_private.begin_work_command('complete_turnover',p_key,payload);
  if prior is not null then return prior;end if;
  raise exception using errcode='42501',message='command_permission_denied';
 end if;
 perform app_private.readiness_lock(c.term_id);actor:=app_private.turnover_manager(c);
 select*into c from app_private.turnover_cases where id=p_case_id for update;
 payload:=jsonb_build_array(p_case_id,p_run_id,p_expected_version,p_reference);prior:=app_private.begin_work_command('complete_turnover',p_key,payload);if prior is not null then return prior;end if;
 select*into job from app_private.turnover_runs where id=p_run_id and case_id=c.id;
 if c.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if c.state not in('verified','rehearsal_verified')or job.id is null or job.source_fingerprint<>app_private.turnover_fingerprint(c.term_id)
  or job.disposition_head<>app_private.backup_disposition_fingerprint(c.term_id)or job.entry_fingerprint<>app_private.turnover_entry_fingerprint(c.id)
  or not exists(select 1 from app_private.turnover_transfers where case_id=c.id)
  or exists(select 1 from app_private.turnover_transfers where case_id=c.id and(accepted_at is null or accepted_run is distinct from job.id))
  or coalesce(length(btrim(p_reference)),0)not between 3 and 500 then raise exception using errcode='55000',message='command_turnover_acceptance_required';end if;
 for nom in select*from app_private.turnover_custody where case_id=c.id order by id loop perform app_private.turnover_lock_custody(nom);end loop;
 if exists(select 1 from(select id from app_private.feedback_rounds where term_id=c.term_id union all select id from app_private.evaluation_cases where term_id=c.term_id)root
  where not exists(select 1 from app_private.turnover_custody n where n.case_id=c.id and n.category='prism'and root.id=any(n.work_ids)
   and n.accepted_run=job.id and n.accepted_at is not null and app_private.turnover_custody_live(n)))then
  raise exception using errcode='55000',message='command_turnover_carry_acceptance_required';end if;
 if exists(select 1 from app_private.turnover_obligations o where o.case_id=c.id and o.resolution='carry'and not exists(
  select 1 from app_private.turnover_transfers planned where planned.case_id=c.id and planned.successor_id=o.successor_id
   and planned.accepted_run=job.id and planned.accepted_at is not null and o.work_id=any(planned.work_ids))
  and not exists(select 1 from app_private.turnover_custody n where n.case_id=c.id and n.recipient_id=o.successor_id
   and n.category=app_private.retention_work_category(o.work_id)and o.work_id=any(n.work_ids)
   and n.accepted_run=job.id and n.accepted_at is not null and app_private.turnover_custody_live(n)))then
  raise exception using errcode='55000',message='command_turnover_carry_acceptance_required';end if;
 if exists(select 1 from app_private.turnover_custody n where n.case_id=c.id and(n.accepted_at is null or n.accepted_run is distinct from job.id
  or not app_private.turnover_custody_live(n)))then raise exception using errcode='55000',message='command_turnover_carry_acceptance_required';end if;
 insert into app_private.turnover_permits(term_id,transaction_id,backend_id,actor_id,operation)values(c.term_id,txid_current(),pg_backend_pid(),auth.uid(),'transfer');
 for t in select*from app_private.turnover_transfers where case_id=c.id loop
  if not app_private.turnover_person(t.successor_id,actor.organization_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
  for r in select*from jsonb_array_elements(t.role_scopes)loop
   update public.role_assignments set status='revoked'where id=(r->>'id')::uuid and term_id=c.term_id and version=(r->>'version')::integer and status='active';
   if not found then raise exception using errcode='40001',message='command_stale_version';end if;
  end loop;
  for r in select*from jsonb_array_elements(t.grant_scopes)loop
   update public.record_grants set revoked_at=statement_timestamp()where id=(r->>'id')::uuid and term_id=c.term_id and version=(r->>'version')::integer and revoked_at is null;
   if not found then raise exception using errcode='40001',message='command_stale_version';end if;
  end loop;
  insert into app_private.turnover_archive_grants(term_id,transfer_id,work_id,recipient_id,expires_at)
   select c.term_id,t.id,ids.work_id,t.successor_id,(select ends_at from public.term_memberships where id=t.successor_id)from unnest(t.work_ids)ids(work_id)
    join public.work_items w on w.id=ids.work_id where w.classification='ordinary'and app_private.retention_work_category(w.id)='operational';
 end loop;
 update public.terms set state='archived'where id=c.term_id;
 update app_private.turnover_cases set version=version+1,state=case when state='verified'then'complete'else'rehearsal_complete'end where id=c.id returning*into c;
 return app_private.turnover_receipt(c,'complete_turnover',p_key,payload);
end $$;


create or replace function public.read_turnover(p_term_id uuid,p_case_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;c app_private.turnover_cases;manager boolean:=false;units jsonb:='[]';work jsonb:='[]';people jsonb:='[]';successors jsonb:='[]';
 approvals jsonb:='[]';roles jsonb:='[]';grants jsonb:='[]';transfers jsonb:='[]';runs jsonb:='[]';categories jsonb:='[]';result jsonb;
begin
 actor:=app_private.request_actor(p_term_id,false);
 select x.*into c from app_private.turnover_cases x join public.terms t on t.id=x.term_id and t.organization_id=actor.organization_id
 where(p_case_id is null or x.id=p_case_id)and(x.term_id=p_term_id and x.custodian_id=actor.id and app_private.privacy_custodian(p_term_id)
  or exists(select 1 from app_private.turnover_transfers s where s.case_id=x.id and s.successor_id=actor.id)or exists(select 1 from app_private.turnover_custody n where n.case_id=x.id and n.recipient_id=actor.id and app_private.turnover_custody_live(n)))order by x.created_at desc limit 1;
 manager:=c.id is not null and c.term_id=p_term_id and c.custodian_id=actor.id and app_private.privacy_custodian(p_term_id)and app_private.privacy_strong_session();
 if app_private.privacy_custodian(p_term_id)and app_private.privacy_strong_session() then
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'reference',approval_reference,'scope',evidence_scope)),'[]')into approvals
   from app_private.turnover_approvals where term_id=p_term_id and custodian_id=actor.id and expires_at>statement_timestamp();
 end if;
 if manager then
  select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'name',u.name,'owner',x.owner_id,'checked',x.id is not null)order by u.name),'[]')into units
   from public.org_units u left join app_private.turnover_unit_checks x on x.case_id=c.id and x.unit_id=u.id where u.term_id=c.term_id and u.archived_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'version',w.version,'title',case when public.can_access_work(w.id,'detail')then w.title else'Restricted work'end,
   'reference',ref.reference_text,'unit',(select name from public.org_units where id=w.lead_unit_id),'state',s.semantic_category,'classification',app_private.retention_work_category(w.id),
   'resolution',o.resolution,'recordedVersion',o.work_version,'owner',o.owner_id,'successor',o.successor_id,
   'transferable',w.classification='ordinary'and app_private.retention_work_category(w.id)='operational'and w.kind in('task','deliverable')and public.can_access_work(w.id,'detail'))order by w.id),'[]')into work
   from public.work_items w join public.status_definitions s on s.id=w.status_id left join public.work_references ref on ref.work_item_id=w.id
   left join app_private.turnover_obligations o on o.case_id=c.id and o.work_id=w.id where w.term_id=c.term_id and w.archived_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('id',tm.id,'name',m.display_name)order by m.display_name),'[]')into people from public.term_memberships tm
   join public.members m on m.id=tm.member_id where tm.term_id=c.term_id and app_private.turnover_person(tm.id,actor.organization_id);
  select coalesce(jsonb_agg(jsonb_build_object('id',tm.id,'name',m.display_name,'term',t.label,'termId',t.id)order by t.label,m.display_name),'[]')into successors
   from public.term_memberships tm join public.members m on m.id=tm.member_id join public.terms t on t.id=tm.term_id
   where tm.term_id<>c.term_id and app_private.turnover_person(tm.id,actor.organization_id)and t.state in('draft','active','frozen');
  select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'name',m.display_name||' · '||r.name,'version',a.version)order by m.display_name,r.name),'[]')into roles
   from public.role_assignments a join public.roles r on r.id=a.role_id join public.term_memberships tm on tm.id=a.term_membership_id
   join public.members m on m.id=tm.member_id where a.term_id=c.term_id and a.status='active';
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',case when w.classification='ordinary'then w.title else'Restricted record scope'end,'version',g.version)order by g.id),'[]')into grants
   from public.record_grants g join public.work_items w on w.id=g.work_item_id where g.term_id=c.term_id and g.revoked_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('category',category,'disposition',disposition,'rows',rows,'reviewOn',review_on)),'[]')into categories
   from(select category,disposition,count(*)rows,min(review_on)review_on from app_private.turnover_entries where case_id=c.id group by category,disposition)q;
 end if;
 if c.id is not null then
  select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'successor',t.successor_id,'name',m.display_name,'term',target.label,
    'reference',t.reference,'accepted',t.accepted_at is not null,'acceptedRun',t.accepted_run,
    'work',case when manager or c.state in('verified','rehearsal_verified','complete','rehearsal_complete')then coalesce((select jsonb_agg(app_private.turnover_work_projection(w))
      from public.work_items w where w.id=any(t.work_ids)and w.classification='ordinary'and app_private.retention_work_category(w.id)='operational'),'[]')else'[]'::jsonb end)
    order by t.id),'[]')into transfers from app_private.turnover_transfers t join public.term_memberships tm on tm.id=t.successor_id
    join public.members m on m.id=tm.member_id join public.terms target on target.id=tm.term_id where t.case_id=c.id and(manager or t.successor_id=actor.id);
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'at',q.created_at,'rows',case when manager then q.expected_rows end,'files',case when manager then q.expected_files end,
   'fingerprint',case when manager then q.source_fingerprint end,'parts',case when manager then(select count(*)from app_private.turnover_evidence where run_id=q.id and part<>'complete')end,
   'failure',case when manager then(select jsonb_build_object('phase',f.phase,'reason',f.reason)from app_private.turnover_failures f where f.run_id=q.id order by f.created_at desc,f.id desc limit 1)end,
   'restored',exists(select 1 from app_private.turnover_evidence where run_id=q.id and part='complete'and restored))order by q.created_at desc,q.id),'[]')into runs
    from(select*from app_private.turnover_runs where case_id=c.id order by created_at desc,id desc limit 10)q;
 end if;
 result:=jsonb_build_object('canManage',manager,'approvals',approvals,'case',case when c.id is not null then jsonb_build_object('id',c.id,'version',c.version,'state',c.state,
  'term',(select label from public.terms where id=c.term_id),'custodian',(select m.display_name from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.id=c.custodian_id),
  'scope',(select evidence_scope from app_private.turnover_approvals where id=c.approval_id))end,
  'units',units,'work',work,'people',people,'successors',successors,'roles',roles,'grants',grants,'categories',categories,'transfers',transfers,'runs',runs,
  'custody',coalesce((select jsonb_agg(jsonb_build_object('id',n.id,'recipient',n.recipient_id,'category',n.category,'version',n.version,
   'name',m.display_name,'reference',n.reference,'expiresAt',n.expires_at,'accepted',n.accepted_at is not null,'acceptedRun',n.accepted_run,
   'qualified',app_private.turnover_custody_live(n),'records',(select jsonb_agg(jsonb_build_object('id',w.id,'reference',coalesce(ref.reference_text,case when n.category='prism'then'PRISM custody record '||w.ordinality::text when n.category='finance'then'Unnumbered finance record'else'Unnumbered custody record'end))order by w.id)
    from unnest(n.work_ids)with ordinality w(id,ordinality)left join public.work_references ref on ref.work_item_id=w.id))order by n.id)
   from app_private.turnover_custody n join public.term_memberships tm on tm.id=n.recipient_id join public.members m on m.id=tm.member_id
   where n.case_id=c.id and(manager or n.recipient_id=actor.id and app_private.turnover_custody_live(n))),'[]'),
  'hasArchive',exists(select 1 from app_private.turnover_archive_grants g where g.recipient_id=actor.id and g.revoked_at is null and g.expires_at>statement_timestamp()));
 perform app_private.record_content_read('read_turnover',p_term_id,c.id,c.id is not null);return result;
end $$;


insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
 values('app_private.turnover_object_corrections','security','term',array['id'],
 'select app_private.disposition_key(''app_private.turnover_object_corrections'',array[x.id::text])target_hash,''security''category,x.id root_id,
 app_private.retention_is_held($1,''security'',x.id,null)held,encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'')state_hash from app_private.turnover_object_corrections x where x.term_id=$1',
 app_private.disposition_structure('app_private.turnover_object_corrections'),true);
insert into public.restricted_read_endpoints(endpoint,argument_types)values('read_turnover_setup','uuid');
create or replace function public.prepare_turnover(p_term_id uuid,p_approval_id uuid,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;a app_private.turnover_approvals;c app_private.turnover_cases;policy jsonb;payload jsonb;prior jsonb;
begin
 perform app_private.readiness_lock(p_term_id);actor:=app_private.request_actor(p_term_id,true);
 select *into a from app_private.turnover_approvals where id=p_approval_id and term_id=p_term_id;
 if not app_private.privacy_custodian(p_term_id) or not app_private.privacy_strong_session() or a.custodian_id is distinct from actor.id
  or a.expires_at<=statement_timestamp() or not app_private.turnover_person(a.approved_by,actor.organization_id) then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 -- This first bounded batch is a synthetic rehearsal. The operational adapter,
 -- archived-term custody path and UI acceptance remain explicit P62 work.
 if a.evidence_scope='operational'and((public.read_backup_health(p_term_id)->>'backupStatus')is distinct from'verified'or(public.read_backup_health(p_term_id)->>'restoreStatus')is distinct from'verified')then raise exception using errcode='55000',message='command_turnover_operational_gate';end if;
 policy:=app_private.turnover_policy(p_term_id);
 if policy is null or app_private.disposition_replay_required(p_term_id) or exists(select 1 from app_private.disposition_inventory(p_term_id)i
  where not exists(select 1 from jsonb_array_elements(policy->'rules')rule where rule->>'category'=i.category)) then
  raise exception using errcode='55000',message='command_turnover_policy_required';end if;
 payload:=jsonb_build_array(p_term_id,p_approval_id);prior:=app_private.begin_work_command('prepare_turnover',p_key,payload);if prior is not null then return prior;end if;
 insert into app_private.turnover_cases(term_id,approval_id,custodian_id,retention_definition,retention_hash)
  values(p_term_id,a.id,actor.id,policy,encode(sha256(convert_to(policy::text,'UTF8')),'hex'))returning*into c;
 return app_private.turnover_receipt(c,'prepare_turnover',p_key,payload);
end $$;


commit;
