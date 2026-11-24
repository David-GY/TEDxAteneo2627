-- P46 batch1. No real policy/custodian/approval seeded, no export/purge/emergency grant.
create table public.privacy_custodians(
 term_id uuid not null references public.terms(id),membership_id uuid not null references public.term_memberships(id),
 approved_by uuid not null references public.term_memberships(id),approval_reference text not null check(length(btrim(approval_reference))between 1 and 500),
 approved_at timestamptz not null default statement_timestamp(),expires_at timestamptz not null,revoked_at timestamptz,
 primary key(term_id,membership_id),check(membership_id<>approved_by),check(isfinite(expires_at)and expires_at>approved_at)
);
create table public.privacy_notice_approvals(
 term_id uuid not null references public.terms(id),definition_hash text not null check(definition_hash~'^[a-f0-9]{64}$'),
 approved_by uuid not null references public.term_memberships(id),approval_reference text not null check(length(btrim(approval_reference))between 1 and 500),
 approved_at timestamptz not null default statement_timestamp(),expires_at timestamptz not null,revoked_at timestamptz,
 primary key(term_id,definition_hash),check(isfinite(expires_at)and expires_at>approved_at)
);
-- Subject-scoped minimal counter prevents private queue-volume inference and ref reuse.
create table public.privacy_request_counters(
 term_id uuid not null references public.terms(id),subject_id uuid not null references auth.users(id),last_no bigint not null check(last_no between 1 and 9007199254740991),primary key(term_id,subject_id)
);
create table public.privacy_requests(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),subject_id uuid not null references auth.users(id),
 sequence_no bigint not null check(sequence_no between 1 and 9007199254740991),
 reference text generated always as('PRIV-'||lpad(sequence_no::text,greatest(4,length(sequence_no::text)),'0'))stored,
 kind text not null check(kind in('access','correction','export','deletion','question')),message text not null check(length(message)<=2000),
 state text not null default 'received'check(state in('received','identity_check','in_review','referred')),
 version integer not null default 1 check(version>0),created_at timestamptz not null default statement_timestamp(),updated_at timestamptz not null default statement_timestamp(),
 unique(term_id,subject_id,sequence_no),unique(term_id,subject_id,reference)
);
create index privacy_requests_subject on public.privacy_requests(term_id,subject_id,created_at,id);
create table public.privacy_request_reviews(
 id uuid primary key default gen_random_uuid(),request_id uuid not null references public.privacy_requests(id),version integer not null check(version>1),
 state text not null check(state in('identity_check','in_review','referred')),reply text not null check(length(btrim(reply))between 1 and 2000),
 reviewer_id uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),unique(request_id,version)
);
create table public.privacy_events(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),actor_id uuid not null references auth.users(id),object_id uuid,
 category text not null check(category in('notice','request','queue')),
 operation text not null check(operation in('notice_ack','request_create','request_list','request_read','request_review','queue_read')),
 request_key uuid,occurred_at timestamptz not null default statement_timestamp(),unique(actor_id,operation,request_key)
);
create table public.privacy_notice_acknowledgments(
 term_id uuid not null references public.terms(id),subject_id uuid not null references auth.users(id),notice_version_id uuid not null references public.presentation_versions(id),
 acknowledged_at timestamptz not null default statement_timestamp(),primary key(term_id,subject_id,notice_version_id)
);
do $$declare t text;begin foreach t in array array['privacy_custodians','privacy_notice_approvals','privacy_request_counters','privacy_requests','privacy_request_reviews','privacy_events','privacy_notice_acknowledgments']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
end loop;end$$;
create trigger immutable_privacy_review before update or delete on public.privacy_request_reviews for each row execute function app_private.request_history_guard();
create trigger immutable_privacy_event before update or delete on public.privacy_events for each row execute function app_private.request_history_guard();
create trigger immutable_privacy_notice_ack before update or delete on public.privacy_notice_acknowledgments for each row execute function app_private.request_history_guard();

create function app_private.privacy_subject(p_term uuid)returns void language plpgsql stable security definer set search_path='' as $$begin
 if public.current_term_membership(p_term)is not null then perform app_private.request_actor(p_term);return;end if;
 if app_private.current_guest_invitation(p_term)is null or not exists(select 1 from public.terms t join public.organizations o on o.id=t.organization_id where t.id=p_term and t.state in('active','frozen')and o.state='active'and(statement_timestamp()at time zone'Asia/Manila')::date between t.starts_on and t.closes_on)
 then raise exception using errcode='42501',message='command_permission_denied';end if;
end$$;
create function app_private.privacy_custodian_live(p_term uuid,p_membership uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.privacy_custodians c join public.term_memberships approver on approver.id=c.approved_by and approver.term_id=c.term_id and approver.membership_kind='core'and approver.status='active'and approver.joined_at<=statement_timestamp()and approver.ends_at>statement_timestamp()
  join public.members am on am.id=approver.member_id and am.account_state='active'
  where c.term_id=p_term and c.membership_id=p_membership and c.revoked_at is null and c.approved_at<=statement_timestamp()and c.expires_at>statement_timestamp()
   and exists(select 1 from app_private.effective_role_assignments a join public.role_permissions rp on rp.role_id=a.role_id and rp.term_id=a.term_id and rp.allowed_scope=a.scope_type
    where a.term_id=p_term and a.term_membership_id=c.membership_id and rp.capability='workspace.read'and a.scope_type='term'))
$$;
create function app_private.privacy_custodian(p_term uuid)returns boolean language sql stable security definer set search_path='' as $$
 select app_private.privacy_custodian_live(p_term,public.current_term_membership(p_term))
$$;
create function app_private.privacy_notice_approved(p_term uuid,d jsonb,p_author uuid default null)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.privacy_notice_approvals a join public.term_memberships m on m.id=a.approved_by and m.term_id=a.term_id and m.membership_kind='core'and m.status='active'and m.joined_at<=statement_timestamp()and m.ends_at>statement_timestamp()
  join public.members approver on approver.id=m.member_id and approver.account_state='active'
  where a.term_id=p_term and a.definition_hash=encode(sha256(convert_to(d::text,'UTF8')),'hex')and a.revoked_at is null and a.approved_at<=statement_timestamp()and a.expires_at>statement_timestamp()and(p_author is null or a.approved_by<>p_author))
$$;

alter table public.presentation_controls drop constraint presentation_controls_kind_check,add constraint presentation_controls_kind_check check(kind in('site','layout','notification','bulletin','privacy'));
alter table public.presentation_drafts drop constraint presentation_drafts_kind_check,add constraint presentation_drafts_kind_check check(kind in('site','layout','notification','bulletin','privacy'));
alter function app_private.presentation_actor(uuid,text,text,uuid,boolean)rename to presentation_actor_before_privacy;
create function app_private.presentation_actor(p_term uuid,p_kind text,p_target_kind text,p_target uuid,p_write boolean default false)returns public.term_memberships language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 if p_kind is distinct from'privacy'then return app_private.presentation_actor_before_privacy(p_term,p_kind,p_target_kind,p_target,p_write);end if;
 m:=app_private.request_actor(p_term,p_write);
 if p_target_kind is distinct from'term'or p_target is distinct from p_term or not app_private.privacy_custodian(p_term)then raise exception using errcode='42501',message='command_permission_denied';end if;
 return m;
end$$;
alter function app_private.validate_presentation(text,jsonb)rename to validate_presentation_before_privacy;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql immutable set search_path='' as $$declare k text;v jsonb;begin
 if p_kind is distinct from'privacy'then perform app_private.validate_presentation_before_privacy(p_kind,d);return;end if;
 if not coalesce(app_private.definition_keys(d,array['version','title','controller','purposes','requiredFields','optionalFields','recipients','providers','retention','rights','contactName','contactRoute','policyReference']),false)
  or(select count(*)from jsonb_object_keys(d))<>13 or d->'version'is distinct from'1'::jsonb then raise exception using errcode='22023',message='command_validation_failed';end if;
 for k,v in select *from jsonb_each(d-'version')loop
  if not app_private.presentation_text(v,case when k='title'then 200 else 2000 end)then raise exception using errcode='22023',message='command_validation_failed';end if;
 end loop;
 if(d->>'contactRoute')!~'^(https://[a-zA-Z0-9.-]+(/[a-zA-Z0-9/._~-]*)?|mailto:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+[.][a-zA-Z]{2,})$'then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
alter function public.publish_presentation_configuration(uuid,integer,text,text,uuid)set schema app_private;
alter function app_private.publish_presentation_configuration(uuid,integer,text,text,uuid)rename to publish_presentation_before_privacy;
create function public.publish_presentation_configuration(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare d public.presentation_drafts;m public.term_memberships;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();
 if d.kind='privacy'then
  perform app_private.readiness_lock(d.term_id);m:=app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id,true);
  perform app_private.validate_presentation(d.kind,d.definition);
  if not app_private.privacy_notice_approved(d.term_id,d.definition,m.id)then raise exception using errcode='55000',message='privacy_notice_approval_required';end if;
 end if;
 return app_private.publish_presentation_before_privacy(p_draft_id,p_expected_version,p_review_hash,p_reason,p_request_id);
end$$;

create function app_private.current_privacy_notice(p_term uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare v public.presentation_versions;begin
 select pv.*into v from public.presentation_controls c join public.work_items w on w.id=c.work_item_id and w.term_id=c.term_id and w.archived_at is null join public.presentation_versions pv on pv.control_id=c.work_item_id where c.term_id=p_term and c.kind='privacy'and c.target_kind='term'and c.target_id=p_term order by pv.version desc limit 1;
 if not found then return null;end if;
 begin perform app_private.validate_presentation('privacy',v.definition);exception when invalid_parameter_value then return null;end;
 return jsonb_build_object('revisionId',v.id,'version',v.version,'definition',v.definition,'approved',app_private.privacy_notice_approved(p_term,v.definition,(select tm.id from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=p_term and m.auth_user_id=v.actor_id)),
  'acknowledged',exists(select 1 from public.privacy_notice_acknowledgments a where a.term_id=p_term and a.subject_id=auth.uid()and a.notice_version_id=v.id));
end$$;
create function app_private.privacy_intake_available(p_term uuid)returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((app_private.current_privacy_notice(p_term)->>'approved')::boolean,false)and exists(select 1 from public.privacy_custodians c where c.term_id=p_term and app_private.privacy_custodian_live(p_term,c.membership_id))
$$;
create function app_private.privacy_finish(p_term uuid,p_command text,p_key uuid,p_payload jsonb,p_result jsonb,p_object uuid,p_category text,p_operation text)returns jsonb language plpgsql security definer set search_path='' as $$begin
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)select auth.uid(),p_command,p_key,t.organization_id,t.id,encode(sha256(convert_to(p_payload::text,'UTF8')),'hex'),p_result from public.terms t where t.id=p_term;
 insert into public.privacy_events(term_id,actor_id,object_id,category,operation,request_key)values(p_term,auth.uid(),p_object,p_category,p_operation,p_key);
 return p_result;
end$$;

create function public.read_my_privacy(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform app_private.privacy_subject(p_term_id);
 if p_page is null or p_page<1 or p_page>1000000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.privacy_events(term_id,actor_id,category,operation)values(p_term_id,auth.uid(),'queue','request_list');
 return jsonb_build_object('notice',app_private.current_privacy_notice(p_term_id),'intakeAvailable',app_private.privacy_intake_available(p_term_id),'canAdmin',app_private.privacy_custodian(p_term_id),
 'requests',coalesce((select jsonb_agg(to_jsonb(r)order by r."createdAt"desc,r.id)from(select id,reference,kind,state,version,created_at as "createdAt"from public.privacy_requests where term_id=p_term_id and subject_id=auth.uid()order by created_at desc,id limit 20 offset(p_page::bigint-1)*20)r),'[]'),
 'page',p_page,'hasMore',(select count(*)from public.privacy_requests where term_id=p_term_id and subject_id=auth.uid())>p_page::bigint*20);
end$$;
create function public.acknowledge_privacy_notice(p_term_id uuid,p_notice_version_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare n jsonb;payload jsonb;r jsonb;begin
 perform app_private.readiness_lock(p_term_id);perform app_private.privacy_subject(p_term_id);n:=app_private.current_privacy_notice(p_term_id);
 if n is null or n->'approved'is distinct from'true'::jsonb then raise exception using errcode='55000',message='privacy_notice_approval_required';end if;
 payload:=jsonb_build_array(p_term_id,p_notice_version_id);r:=app_private.begin_work_command('acknowledge_privacy_notice',p_request_id,payload);if r is not null then return r;end if;
 if p_notice_version_id is distinct from(n->>'revisionId')::uuid then raise exception using errcode='40001',message='command_stale_version';end if;
 insert into public.privacy_notice_acknowledgments(term_id,subject_id,notice_version_id)values(p_term_id,auth.uid(),p_notice_version_id)on conflict do nothing;
 return app_private.privacy_finish(p_term_id,'acknowledge_privacy_notice',p_request_id,payload,jsonb_build_object('version',(n->>'version')::integer,'acknowledged',true),p_notice_version_id,'notice','notice_ack');
end$$;
create function public.create_privacy_request(p_term_id uuid,p_kind text,p_message text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare payload jsonb;r jsonb;request public.privacy_requests;sequence bigint;begin
 perform app_private.readiness_lock(p_term_id);perform app_private.privacy_subject(p_term_id);
 if not app_private.privacy_intake_available(p_term_id)then raise exception using errcode='55000',message='privacy_intake_unconfigured';end if;
 payload:=jsonb_build_array(p_term_id,p_kind,p_message);r:=app_private.begin_work_command('create_privacy_request',p_request_id,payload);if r is not null then return r;end if;
 if p_kind is null or p_kind not in('access','correction','export','deletion','question')or p_message is null or length(p_message)>2000 or(p_kind in('correction','question')and length(btrim(p_message))=0)then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.privacy_request_counters(term_id,subject_id,last_no)values(p_term_id,auth.uid(),1)on conflict(term_id,subject_id)do update set last_no=privacy_request_counters.last_no+1 returning last_no into sequence;
 insert into public.privacy_requests(term_id,subject_id,sequence_no,kind,message)values(p_term_id,auth.uid(),sequence,p_kind,p_message)returning *into request;
 return app_private.privacy_finish(p_term_id,'create_privacy_request',p_request_id,payload,jsonb_build_object('id',request.id,'reference',request.reference,'version',request.version,'state',request.state),request.id,'request','request_create');
end$$;
create function public.read_privacy_request(p_term_id uuid,p_privacy_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare r public.privacy_requests;begin
 perform app_private.privacy_subject(p_term_id);
 select *into r from public.privacy_requests where id=p_privacy_request_id and term_id=p_term_id;
 if not found or(r.subject_id<>auth.uid()and not app_private.privacy_custodian(p_term_id))then return null;end if;
 insert into public.privacy_events(term_id,actor_id,object_id,category,operation)values(p_term_id,auth.uid(),r.id,'request','request_read');
 return jsonb_build_object('id',r.id,'reference',r.reference,'kind',r.kind,'state',r.state,'version',r.version,'createdAt',r.created_at,'message',r.message,'accountName',coalesce((select m.display_name from public.members m join public.terms t on t.organization_id=m.organization_id where t.id=p_term_id and m.auth_user_id=r.subject_id),'Invited guest'),'canReview',r.subject_id<>auth.uid()and app_private.privacy_custodian(p_term_id),
 'replies',coalesce((select jsonb_agg(jsonb_build_object('version',v.version,'state',v.state,'reply',v.reply,'at',v.created_at)order by v.version)from public.privacy_request_reviews v where v.request_id=r.id),'[]'));
end$$;
create function public.read_privacy_inbox(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform app_private.request_actor(p_term_id);if not app_private.privacy_custodian(p_term_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_page is null or p_page<1 or p_page>1000000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.privacy_events(term_id,actor_id,category,operation)values(p_term_id,auth.uid(),'queue','queue_read');
 return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(r)order by r."createdAt",r.id)from(select q.id,q.reference,q.kind,q.state,q.version,q.created_at as "createdAt",coalesce((select m.display_name from public.members m join public.terms t on t.organization_id=m.organization_id where t.id=p_term_id and m.auth_user_id=q.subject_id),'Invited guest')as "accountName"from public.privacy_requests q where q.term_id=p_term_id order by q.created_at,q.id limit 20 offset(p_page::bigint-1)*20)r),'[]'),
 'page',p_page,'hasMore',(select count(*)from public.privacy_requests where term_id=p_term_id)>p_page::bigint*20);
end$$;
create function public.review_privacy_request(p_term_id uuid,p_privacy_request_id uuid,p_state text,p_reply text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare q public.privacy_requests;payload jsonb;r jsonb;begin
 perform app_private.readiness_lock(p_term_id);perform app_private.request_actor(p_term_id,true);
 if not app_private.privacy_custodian(p_term_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 select *into q from public.privacy_requests where id=p_privacy_request_id and term_id=p_term_id for update;
 if not found or q.subject_id=auth.uid()then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_privacy_request_id,p_state,p_reply,p_expected_version);r:=app_private.begin_work_command('review_privacy_request',p_request_id,payload);if r is not null then return r;end if;
 if p_expected_version is distinct from q.version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_state is null or p_state not in('identity_check','in_review','referred')or not app_private.presentation_text(to_jsonb(p_reply),2000)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if q.state='referred'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 update public.privacy_requests set state=p_state,version=version+1,updated_at=statement_timestamp()where id=q.id returning *into q;
 insert into public.privacy_request_reviews(request_id,version,state,reply,reviewer_id)values(q.id,q.version,q.state,p_reply,auth.uid());
 return app_private.privacy_finish(p_term_id,'review_privacy_request',p_request_id,payload,jsonb_build_object('version',q.version,'state',q.state),q.id,'request','request_review');
end$$;

revoke all on function app_private.privacy_subject(uuid),app_private.privacy_custodian_live(uuid,uuid),app_private.privacy_custodian(uuid),app_private.privacy_notice_approved(uuid,jsonb,uuid),
 app_private.presentation_actor_before_privacy(uuid,text,text,uuid,boolean),app_private.presentation_actor(uuid,text,text,uuid,boolean),app_private.validate_presentation_before_privacy(text,jsonb),app_private.validate_presentation(text,jsonb),
 app_private.publish_presentation_before_privacy(uuid,integer,text,text,uuid),app_private.current_privacy_notice(uuid),app_private.privacy_intake_available(uuid),app_private.privacy_finish(uuid,text,uuid,jsonb,jsonb,uuid,text,text),
 public.publish_presentation_configuration(uuid,integer,text,text,uuid),public.read_my_privacy(uuid,integer),public.acknowledge_privacy_notice(uuid,uuid,uuid),public.create_privacy_request(uuid,text,text,uuid),
 public.read_privacy_request(uuid,uuid),public.read_privacy_inbox(uuid,integer),public.review_privacy_request(uuid,uuid,text,text,integer,uuid)from public,anon,authenticated,service_role;
grant execute on function public.publish_presentation_configuration(uuid,integer,text,text,uuid),public.read_my_privacy(uuid,integer),public.acknowledge_privacy_notice(uuid,uuid,uuid),public.create_privacy_request(uuid,text,text,uuid),
 public.read_privacy_request(uuid,uuid),public.read_privacy_inbox(uuid,integer),public.review_privacy_request(uuid,uuid,text,text,integer,uuid)to authenticated;
