begin;
-- Specific roots, metadata custody only. This is never a raw-record grant.
create table app_private.turnover_custody(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),
 case_id uuid not null references app_private.turnover_cases(id),recipient_id uuid not null references public.term_memberships(id),
 category text not null check(category in('operational','finance','restricted','prism')),
 work_ids uuid[] not null check(cardinality(work_ids) between 1 and 100),
 authority_id uuid not null references public.role_assignments(id),authority_version integer not null,role_version integer not null,
 custody_approved_at timestamptz not null,expires_at timestamptz not null check(isfinite(expires_at)),
 reference text not null check(length(btrim(reference)) between 3 and 500),
 accepted_at timestamptz,accepted_run uuid references app_private.turnover_runs(id),acceptance_reference text,
 version integer not null default 1 check(version>0),unique(case_id,recipient_id,category)
);
alter table app_private.turnover_custody enable row level security;
alter table app_private.turnover_custody force row level security;
revoke all on app_private.turnover_custody from public,anon,authenticated,service_role;

create function app_private.turnover_custody_live(n app_private.turnover_custody)returns boolean
language sql stable security definer set search_path='' as $$
 select n.expires_at>statement_timestamp() and exists(
  select 1 from app_private.turnover_cases c join public.terms old_term on old_term.id=c.term_id
  join public.term_memberships recipient on recipient.id=n.recipient_id and recipient.term_id<>c.term_id
  join public.privacy_custodians pc on pc.term_id=recipient.term_id and pc.membership_id=recipient.id
  join app_private.effective_role_assignments a on a.id=n.authority_id and a.term_membership_id=recipient.id
  join public.roles r on r.id=a.role_id
  join public.role_permissions rp on rp.role_id=r.id and rp.term_id=a.term_id and rp.allowed_scope=a.scope_type
  where c.id=n.case_id and c.term_id=n.term_id and recipient.organization_id=old_term.organization_id
   and app_private.turnover_person(recipient.id,old_term.organization_id)
   and app_private.privacy_custodian_live(recipient.term_id,recipient.id)
   and pc.approved_at=n.custody_approved_at and pc.expires_at>=n.expires_at
   and a.version=n.authority_version and r.version=n.role_version and a.effective_to>=n.expires_at
   and recipient.ends_at>=n.expires_at
   and rp.capability=case n.category when'finance'then'finance.review'when'prism'then'feedback.review'else'workspace.read'end
 );
$$;

create function public.propose_turnover_custody(p_case_id uuid,p_expected_version integer,p_recipient uuid,p_category text,
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
 if exists(select 1 from unnest(p_work_ids)w(id)where not exists(select 1 from public.work_items x
   where x.id=w.id and x.term_id=c.term_id and app_private.retention_work_category(x.id)=p_category))
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

create function public.accept_turnover_custody(p_context_term uuid,p_custody_id uuid,p_run_id uuid,p_reference text,p_key uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.term_memberships;n app_private.turnover_custody;c app_private.turnover_cases;payload jsonb;prior jsonb;
begin
 actor:=app_private.request_actor(p_context_term,false);
 select*into n from app_private.turnover_custody where id=p_custody_id;select*into c from app_private.turnover_cases where id=n.case_id;
 perform app_private.readiness_lock(c.term_id);select*into n from app_private.turnover_custody where id=p_custody_id for update;
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

-- Selected outgoing scopes cannot occur in two recipients' plans.
create function app_private.turnover_transfer_overlap()returns trigger language plpgsql set search_path='' as $$
begin
 if exists(select 1 from app_private.turnover_transfers other where other.case_id=new.case_id and other.id<>new.id and other.successor_id<>new.successor_id
  and(exists(select 1 from jsonb_array_elements(other.role_scopes)a(value)join jsonb_array_elements(new.role_scopes)b(value)on a.value->>'id'=b.value->>'id')
   or exists(select 1 from jsonb_array_elements(other.grant_scopes)a(value)join jsonb_array_elements(new.grant_scopes)b(value)on a.value->>'id'=b.value->>'id')))then
  raise exception using errcode='22023',message='command_turnover_scope_overlap';end if;
 return new;
end $$;
create trigger turnover_transfer_overlap before insert or update on app_private.turnover_transfers for each row execute function app_private.turnover_transfer_overlap();

create function app_private.turnover_custody_actor(p_context_term uuid,p_custody_id uuid)returns app_private.turnover_custody
language plpgsql set search_path='' as $$
declare actor public.term_memberships;n app_private.turnover_custody;
begin
 actor:=app_private.request_actor(p_context_term,false);select*into n from app_private.turnover_custody where id=p_custody_id;
 if n.recipient_id is distinct from actor.id or not app_private.privacy_strong_session()or not coalesce(app_private.turnover_custody_live(n),false)
  or n.accepted_at is null or not exists(select 1 from app_private.turnover_cases c where c.id=n.case_id and c.state in('complete','rehearsal_complete'))then
  raise exception using errcode='42501',message='command_permission_denied';end if;
 return n;
end $$;

create function public.read_archived_custody(p_context_term uuid,p_custody_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare n app_private.turnover_custody;holds jsonb;
begin
 n:=app_private.turnover_custody_actor(p_context_term,p_custody_id);
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'objectId',h.object_id,'reviewAt',h.review_at,'overdue',h.review_at<=statement_timestamp(),'version',h.version)order by h.id),'[]')into holds
  from public.legal_holds h where h.term_id=n.term_id and h.category=n.category and h.object_id=any(n.work_ids)and h.released_at is null;
 insert into app_private.turnover_events(term_id,object_id,actor_id,operation,version)values(n.term_id,n.id,auth.uid(),'archived_custody_read',n.version);
 return jsonb_build_object('id',n.id,'version',n.version,'category',n.category,'workIds',n.work_ids,'expiresAt',n.expires_at,'holds',holds);
end $$;

create function public.act_archived_custody(p_context_term uuid,p_custody_id uuid,p_expected_version integer,p_action text,p_values jsonb,p_reference text,p_key uuid)returns jsonb
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
   insert into app_private.turnover_corrections(term_id,case_id,work_id,reference,actor_id)values(n.term_id,n.case_id,object_id,p_reference,auth.uid());
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

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
 values('app_private.turnover_custody','security','term',array['id'],
 'select app_private.disposition_key(''app_private.turnover_custody'',array[x.id::text])target_hash,''security''category,x.id root_id,
 app_private.retention_is_held($1,''security'',x.id,null)held,encode(sha256(convert_to(to_jsonb(x)::text,''UTF8'')),''hex'')state_hash from app_private.turnover_custody x where x.term_id=$1',
 app_private.disposition_structure('app_private.turnover_custody'),true);
-- Function privileges are closed explicitly below after the replaced command.

create or replace function public.complete_turnover(p_case_id uuid,p_run_id uuid,p_expected_version integer,p_reference text,p_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c app_private.turnover_cases;actor public.term_memberships;t app_private.turnover_transfers;r jsonb;payload jsonb;prior jsonb;job app_private.turnover_runs;
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
   'qualified',app_private.turnover_custody_live(n),'records',(select jsonb_agg(jsonb_build_object('id',w.id,'reference',ref.reference_text)order by w.id)
    from public.work_items w left join public.work_references ref on ref.work_item_id=w.id where w.id=any(n.work_ids)))order by n.id)
   from app_private.turnover_custody n join public.term_memberships tm on tm.id=n.recipient_id join public.members m on m.id=tm.member_id
   where n.case_id=c.id and(manager or n.recipient_id=actor.id and app_private.turnover_custody_live(n))),'[]'),
  'hasArchive',exists(select 1 from app_private.turnover_archive_grants g where g.recipient_id=actor.id and g.revoked_at is null and g.expires_at>statement_timestamp()));
 perform app_private.record_content_read('read_turnover',p_term_id,c.id,c.id is not null);return result;
end $$;

create function app_private.turnover_archive_page(p_term uuid,p_work uuid,p_page integer)returns jsonb
language plpgsql set search_path='' as $$
declare actor public.term_memberships;items jsonb;detail jsonb;more boolean;
begin
 actor:=app_private.request_actor(p_term,false);
 if p_page is null or p_page not between 1 and 1000000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 with permitted as(
  select w.* from public.work_items w where w.classification='ordinary'and app_private.retention_work_category(w.id)='operational'
   and(p_work is null or w.id=p_work)and exists(select 1 from app_private.turnover_archive_grants g
    join public.terms t on t.id=g.term_id and t.organization_id=actor.organization_id and t.state='archived'
    where g.work_id=w.id and g.recipient_id=actor.id and g.revoked_at is null and g.expires_at>statement_timestamp())
  order by w.title,w.id limit 51 offset(case when p_work is null then(p_page::bigint-1)*50 else 0 end)
 ),numbered as(select p.*,row_number()over(order by title,id)n from permitted p)
 select coalesce(jsonb_agg(app_private.turnover_work_projection(w)-'body'order by w.title,w.id)filter(where x.n<=50),'[]'),
  bool_or(x.n>50),max(app_private.turnover_work_projection(w)::text)filter(where p_work is not null)
 into items,more,detail from numbered x join public.work_items w on w.id=x.id;
 perform app_private.record_content_read('read_archived_work',p_term,case when detail is not null then p_work end,jsonb_array_length(items)>0);
 return jsonb_build_object('items',items,'detail',detail,'page',p_page,'hasMore',coalesce(more,false));
end $$;
create or replace function public.read_archived_work(p_term_id uuid,p_work_id uuid default null)returns jsonb
language sql security definer set search_path='' as $$ select app_private.turnover_archive_page(p_term_id,p_work_id,1) $$;
create function public.read_archived_work_page(p_term_id uuid,p_page integer default 1)returns jsonb
language sql security definer set search_path='' as $$ select app_private.turnover_archive_page(p_term_id,null,p_page) $$;

insert into public.restricted_read_endpoints(endpoint,argument_types)values('read_archived_custody','uuid, uuid'),('read_archived_work_page','uuid, integer');
do $$declare f record;
begin
 for f in select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)args from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='app_private'and p.proname in('turnover_custody_live','turnover_custody_actor','turnover_transfer_overlap','turnover_archive_page')
 or n.nspname='public'and p.proname in('propose_turnover_custody','accept_turnover_custody','read_archived_custody','act_archived_custody','read_archived_work_page')loop
  execute format('revoke all on function %I.%I(%s)from public,anon,authenticated,service_role',f.nspname,f.proname,f.args);
  if f.nspname='public'then execute format('grant execute on function public.%I(%s)to authenticated',f.proname,f.args);end if;
 end loop;
end $$;
commit;
