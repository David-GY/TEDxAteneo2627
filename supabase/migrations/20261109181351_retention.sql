-- P46 local planning only. No policy defaults, job scheduler or deletion executor.
create table public.retention_policy_approvals(
 term_id uuid not null references public.terms(id),definition_hash text not null check(definition_hash~'^[a-f0-9]{64}$'),
 approved_by uuid not null references public.term_memberships(id),approval_reference text not null check(length(btrim(approval_reference))between 1 and 500),
 approved_at timestamptz not null default statement_timestamp(),expires_at timestamptz not null,revoked_at timestamptz,
 primary key(term_id,definition_hash),check(isfinite(expires_at)and expires_at>approved_at)
);
create table public.legal_holds(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),
 category text check(category in('operational','finance','restricted','profile','guest','security','privacy','prism','learning','backup')),
 object_id uuid,reason text not null check(length(btrim(reason))between 1 and 2000),
 owner_id uuid not null references auth.users(id),review_at timestamptz not null check(isfinite(review_at)),
 version integer not null default 1 check(version>0),created_at timestamptz not null default statement_timestamp(),
 released_at timestamptz,released_by uuid references auth.users(id),release_reason text,
 check(object_id is null or category is not null),check((released_at is null and released_by is null and release_reason is null)or(released_at is not null and released_by is not null and length(btrim(release_reason))between 1 and 2000))
);
create index legal_holds_scope on public.legal_holds(term_id,category,object_id)where released_at is null;
create table public.legal_hold_events(
 id uuid primary key default gen_random_uuid(),hold_id uuid not null references public.legal_holds(id),
 actor_id uuid not null references auth.users(id),operation text not null check(operation in('create','release')),
 version integer not null,occurred_at timestamptz not null default statement_timestamp(),unique(hold_id,version)
);
do $$declare t text;begin foreach t in array array['retention_policy_approvals','legal_holds','legal_hold_events']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
end loop;end$$;
create trigger immutable_legal_hold_events before update or delete on public.legal_hold_events for each row execute function app_private.request_history_guard();
alter table public.privacy_events drop constraint privacy_events_category_check,drop constraint privacy_events_operation_check,
 add constraint privacy_events_category_check check(category in('notice','request','queue','retention')),
 add constraint privacy_events_operation_check check(operation in('notice_ack','request_create','request_list','request_read','request_review','queue_read','retention_read','hold_create','hold_release'));

-- Retention configuration uses the delivered publication adapter, including private
-- drafts, review hashes, exact retries, immutable history and versioned restoration.
alter table public.presentation_controls drop constraint presentation_controls_kind_check,add constraint presentation_controls_kind_check check(kind in('site','layout','notification','bulletin','privacy','retention'));
alter table public.presentation_drafts drop constraint presentation_drafts_kind_check,add constraint presentation_drafts_kind_check check(kind in('site','layout','notification','bulletin','privacy','retention'));
alter function app_private.presentation_actor(uuid,text,text,uuid,boolean)rename to presentation_actor_before_retention;
create function app_private.presentation_actor(p_term uuid,p_kind text,p_target_kind text,p_target uuid,p_write boolean default false)returns public.term_memberships language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 if p_kind is distinct from'retention'then return app_private.presentation_actor_before_retention(p_term,p_kind,p_target_kind,p_target,p_write);end if;
 m:=app_private.request_actor(p_term,p_write);
 if p_target_kind is distinct from'term'or p_target is distinct from p_term or not app_private.privacy_custodian(p_term)then raise exception using errcode='42501',message='command_permission_denied';end if;return m;
end$$;
alter function app_private.validate_presentation(text,jsonb)rename to validate_presentation_before_retention;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql immutable set search_path='' as $$declare r jsonb;begin
 if p_kind is distinct from'retention'then perform app_private.validate_presentation_before_retention(p_kind,d);return;end if;
 if not coalesce(app_private.definition_keys(d,array['version','rules']),false)or(select count(*)from jsonb_object_keys(d))<>2 or d->'version'is distinct from'1'::jsonb or jsonb_typeof(d->'rules')is distinct from'array'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if jsonb_array_length(d->'rules')not between 1 and 10 or(select count(distinct v->>'category')from jsonb_array_elements(d->'rules')v)<>jsonb_array_length(d->'rules')then raise exception using errcode='22023',message='command_validation_failed';end if;
 for r in select *from jsonb_array_elements(d->'rules')loop
  if not coalesce(app_private.definition_keys(r,array['category','owner','basis','days','action']),false)or(select count(*)from jsonb_object_keys(r))<>5
   or coalesce(r->>'category','')not in('operational','finance','restricted','profile','guest','security','privacy','prism','learning','backup')
   or not coalesce(app_private.presentation_text(r->'owner',200),false)or not coalesce(app_private.presentation_text(r->'basis',2000),false)
   or jsonb_typeof(r->'days')is distinct from'number'or(r->>'days')!~'^[0-9]{1,6}$'or(r->>'days')::integer not between 0 and 365000
   or coalesce(r->>'action','')not in('archive_review','review_disposal')then raise exception using errcode='22023',message='command_validation_failed';end if;
 end loop;
end$$;
create function app_private.retention_approved(p_term uuid,d jsonb,p_author uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.retention_policy_approvals a join public.term_memberships m on m.id=a.approved_by and m.term_id=a.term_id and m.membership_kind='core'and m.status='active'and m.joined_at<=statement_timestamp()and m.ends_at>statement_timestamp()
  join public.members approver on approver.id=m.member_id and approver.account_state='active'
  where a.term_id=p_term and a.definition_hash=encode(sha256(convert_to(d::text,'UTF8')),'hex')and a.revoked_at is null and a.approved_at<=statement_timestamp()and a.expires_at>statement_timestamp()and a.approved_by<>p_author)
$$;
alter function public.publish_presentation_configuration(uuid,integer,text,text,uuid)set schema app_private;
alter function app_private.publish_presentation_configuration(uuid,integer,text,text,uuid)rename to publish_presentation_before_retention;
create function public.publish_presentation_configuration(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare d public.presentation_drafts;m public.term_memberships;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();
 if d.kind='retention'then
  perform app_private.readiness_lock(d.term_id);m:=app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id,true);perform app_private.validate_presentation(d.kind,d.definition);
  if not app_private.retention_approved(d.term_id,d.definition,m.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 end if;
 return app_private.publish_presentation_before_retention(p_draft_id,p_expected_version,p_review_hash,p_reason,p_request_id);
end$$;

-- Bounded root inventory, NOT a full purge manifest. Child revisions, copies,
-- provider objects and backup generations need their separate inventory/replay.
-- No filenames, paths, payloads, titles, profile fields or hashes are returned.
create function app_private.retention_work_category(p_id uuid)returns text language sql stable security definer set search_path='' as $$
 select case when exists(select 1 from public.finance_cases where request_id=w.id)or exists(select 1 from public.request_finance_values where request_id=w.id)then'finance'
  when w.classification='restricted'then'restricted'else'operational'end from public.work_items w where w.id=p_id
$$;
create function app_private.retention_inventory(p_term uuid)returns table(id uuid,category text,kind text,parent_id uuid)language sql stable security definer set search_path='' as $$
 select w.id,app_private.retention_work_category(w.id),'record'::text,null::uuid from public.work_items w where w.term_id=p_term
 union all select a.id,case when a.classification='restricted'and app_private.retention_work_category(a.origin_work_item_id)='operational'then'restricted'else app_private.retention_work_category(a.origin_work_item_id)end,'file'::text,a.origin_work_item_id from public.assets a join public.work_items w on w.id=a.origin_work_item_id where w.term_id=p_term
 union all select p.member_id,'profile','record',null::uuid from public.private_profiles p where exists(select 1 from public.term_memberships m where m.term_id=p_term and m.member_id=p.member_id and m.organization_id=p.organization_id)
 union all select g.id,'guest','record',null::uuid from public.guest_invitations g where g.term_id=p_term
 union all select q.id,'privacy','record',null::uuid from public.privacy_requests q where q.term_id=p_term
 union all select e.id,'security','record',null::uuid from public.audit_events e where e.term_id=p_term
$$;
create function app_private.retention_is_held(p_term uuid,p_category text,p_id uuid,p_parent uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.legal_holds h where h.term_id=p_term and h.released_at is null and(h.category is null or h.category=p_category)and(h.object_id is null or h.object_id=p_id or h.object_id=p_parent))
 or exists(select 1 from public.assets a join public.work_items w on w.id=a.origin_work_item_id join public.legal_holds h on h.term_id=w.term_id and h.released_at is null
  and(h.category is null or h.category=app_private.retention_work_category(w.id))and(h.object_id is null or h.object_id=w.id or h.object_id=a.id)where a.id=p_id)
 -- Shared files inherit any hold on any linked record/category, not just origin.
 or exists(select 1 from public.asset_links l join public.work_items w on w.id=l.work_item_id join public.legal_holds h on h.term_id=w.term_id and h.released_at is null
  and(h.category is null or h.category=app_private.retention_work_category(w.id))and(h.object_id is null or h.object_id=w.id or h.object_id=l.asset_id)where l.asset_id=p_id)
$$;
create function public.read_retention_review(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql security definer set search_path='' as $$declare pv public.presentation_versions;approved boolean:=false;items jsonb;holds jsonb;counts jsonb;t public.terms;begin
 perform app_private.request_actor(p_term_id);if not app_private.privacy_custodian(p_term_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_page is null or p_page<1 or p_page>1000000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select v.*into pv from public.presentation_controls c join public.presentation_versions v on v.control_id=c.work_item_id join public.work_items w on w.id=c.work_item_id and w.archived_at is null where c.term_id=p_term_id and c.kind='retention'order by v.version desc limit 1;
 if found then approved:=app_private.retention_approved(p_term_id,pv.definition,(select tm.id from public.term_memberships tm join public.members m on m.id=tm.member_id where tm.term_id=p_term_id and m.auth_user_id=pv.actor_id));end if;
 select *into t from public.terms where id=p_term_id;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'category',i.category,'kind',i.kind,'action',case when app_private.retention_is_held(p_term_id,i.category,i.id,i.parent_id)then'held'when not approved or r.rule is null then'blocked_policy'
   when t.state not in('frozen','archived')or(statement_timestamp()at time zone'Asia/Manila')::date<t.closes_on+(r.rule->>'days')::integer then'not_due'
   -- Shared profiles and cross-scope files require a separate dependency review.
   when i.category='profile'or(i.kind='file'and exists(select 1 from public.asset_links l join public.work_items w on w.id=l.work_item_id where l.asset_id=i.id and(w.term_id<>p_term_id or app_private.retention_work_category(w.id)<>i.category)))then'blocked_dependencies'
   else r.rule->>'action'end,'reviewOn',case when r.rule is not null then to_char(t.closes_on+(r.rule->>'days')::integer,'YYYY-MM-DD')else null end)order by i.category,i.kind,i.id),'[]')into items
 from(select *from app_private.retention_inventory(p_term_id)order by category,kind,id limit 50 offset(p_page::bigint-1)*50)i left join lateral(select value rule from jsonb_array_elements(coalesce(pv.definition->'rules','[]'))where value->>'category'=i.category)r on true;
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'category',h.category,'objectId',h.object_id,'reason',h.reason,'reviewAt',h.review_at,'overdue',h.review_at<=statement_timestamp(),'version',h.version)order by h.created_at,h.id),'[]')into holds from public.legal_holds h where h.term_id=p_term_id and h.released_at is null;
 select coalesce(jsonb_agg(to_jsonb(c)order by c.category),'[]')into counts from(select category,count(*)::integer records,count(*)filter(where kind='file')::integer files from app_private.retention_inventory(p_term_id)group by category)c;
 insert into public.privacy_events(term_id,actor_id,category,operation)values(p_term_id,auth.uid(),'retention','retention_read');
 return jsonb_build_object('policyApproved',approved,'version',coalesce(pv.version,0),'definition',pv.definition,'items',items,'holds',holds,'counts',counts,'page',p_page,'hasMore',(select count(*)from app_private.retention_inventory(p_term_id))>p_page::bigint*50,'coverage','root_records_and_registered_assets_only','executesDeletion',false);
end$$;
create function public.create_legal_hold(p_term_id uuid,p_category text,p_object_id uuid,p_reason text,p_review_at timestamptz,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare payload jsonb;r jsonb;h public.legal_holds;begin
 perform app_private.readiness_lock(p_term_id);perform app_private.request_actor(p_term_id,true);if not app_private.privacy_custodian(p_term_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_category,p_object_id,p_reason,p_review_at);r:=app_private.begin_work_command('create_legal_hold',p_request_id,payload);if r is not null then return r;end if;
 if(p_category is not null and p_category not in('operational','finance','restricted','profile','guest','security','privacy','prism','learning','backup'))or(p_object_id is not null and(p_category is null or not exists(select 1 from app_private.retention_inventory(p_term_id)i where i.id=p_object_id and i.category=p_category)))
  or not coalesce(app_private.presentation_text(to_jsonb(p_reason),2000),false)or p_review_at is null or not isfinite(p_review_at)or p_review_at<=statement_timestamp()then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.legal_holds(term_id,category,object_id,reason,owner_id,review_at)values(p_term_id,p_category,p_object_id,p_reason,auth.uid(),p_review_at)returning *into h;
 insert into public.legal_hold_events(hold_id,actor_id,operation,version)values(h.id,auth.uid(),'create',h.version);
 return app_private.privacy_finish(p_term_id,'create_legal_hold',p_request_id,payload,jsonb_build_object('id',h.id,'version',h.version),h.id,'retention','hold_create');
end$$;
create function public.release_legal_hold(p_term_id uuid,p_hold_id uuid,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$declare payload jsonb;r jsonb;h public.legal_holds;begin
 perform app_private.readiness_lock(p_term_id);perform app_private.request_actor(p_term_id,true);if not app_private.privacy_custodian(p_term_id)then raise exception using errcode='42501',message='command_permission_denied';end if;
 select *into h from public.legal_holds where id=p_hold_id and term_id=p_term_id for update;if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_hold_id,p_reason,p_expected_version);r:=app_private.begin_work_command('release_legal_hold',p_request_id,payload);if r is not null then return r;end if;
 if p_expected_version is distinct from h.version then raise exception using errcode='40001',message='command_stale_version';end if;
 if h.released_at is not null or not coalesce(app_private.presentation_text(to_jsonb(p_reason),2000),false)then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.legal_holds set released_at=statement_timestamp(),released_by=auth.uid(),release_reason=p_reason,version=version+1 where id=h.id returning *into h;
 insert into public.legal_hold_events(hold_id,actor_id,operation,version)values(h.id,auth.uid(),'release',h.version);
 return app_private.privacy_finish(p_term_id,'release_legal_hold',p_request_id,payload,jsonb_build_object('id',h.id,'version',h.version),h.id,'retention','hold_release');
end$$;
revoke all on function app_private.presentation_actor_before_retention(uuid,text,text,uuid,boolean),app_private.presentation_actor(uuid,text,text,uuid,boolean),app_private.validate_presentation_before_retention(text,jsonb),app_private.validate_presentation(text,jsonb),app_private.retention_approved(uuid,jsonb,uuid),app_private.publish_presentation_before_retention(uuid,integer,text,text,uuid),app_private.retention_work_category(uuid),app_private.retention_inventory(uuid),app_private.retention_is_held(uuid,text,uuid,uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid),public.read_retention_review(uuid,integer),public.create_legal_hold(uuid,text,uuid,text,timestamptz,uuid),public.release_legal_hold(uuid,uuid,text,integer,uuid)from public,anon,authenticated,service_role;
grant execute on function public.publish_presentation_configuration(uuid,integer,text,text,uuid),public.read_retention_review(uuid,integer),public.create_legal_hold(uuid,text,uuid,text,timestamptz,uuid),public.release_legal_hold(uuid,uuid,text,integer,uuid)to authenticated;
