-- P21: requester lifecycle and immutable packages; P22 alone will execute decisions.
alter table public.requests add column request_type_id uuid,add column form_version_id uuid,add column workflow_version_id uuid,
 add column receiving_unit_id uuid,add column type_label text,add column service_label text,
 add column payload_classification text check(payload_classification in('ordinary','restricted')),
 add column request_state text not null default 'draft' check(request_state in('draft','revision_draft','paused','cancelled')),
 add column current_revision integer not null default 0 check(current_revision>=0),add column current_revision_id uuid,
 add column tracking_counter_id uuid,add column tracking_prefix_snapshot text,add column sequence_no bigint,add column tracking_id text,
 add column original_requested_on date,add column accepted_on date check(accepted_on is null),
 add unique(organization_id,term_id,work_item_id),add unique(work_item_id,form_version_id,workflow_version_id),
 add foreign key(organization_id,term_id,request_type_id) references public.request_types(organization_id,term_id,id),
 add foreign key(request_type_id,form_version_id) references public.form_versions(request_type_id,id),
 add foreign key(request_type_id,workflow_version_id) references public.workflow_versions(request_type_id,id),
 add foreign key(organization_id,term_id,receiving_unit_id) references public.org_units(organization_id,term_id,id),
 add check(request_type_id is null or(form_version_id is not null and workflow_version_id is not null and type_label is not null and payload_classification is not null and body=''));
create index requests_type_idx on public.requests(organization_id,term_id,request_type_id);
create index requests_receiver_idx on public.requests(organization_id,term_id,receiving_unit_id);
create table public.tracking_counters(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,namespace_key text not null,
 prefix text not null check(prefix~'^[A-Z][A-Z0-9_-]{0,39}$'),next_value bigint not null check(next_value between 1 and 9007199254740991),
 unique(term_id,namespace_key),unique(term_id,prefix),unique(organization_id,term_id,id),unique(id,term_id,prefix),
 foreign key(organization_id,term_id) references public.terms(organization_id,id)
);
alter table public.requests add foreign key(organization_id,term_id,tracking_counter_id) references public.tracking_counters(organization_id,term_id,id),
 add foreign key(tracking_counter_id,term_id,tracking_prefix_snapshot) references public.tracking_counters(id,term_id,prefix),add unique(term_id,tracking_counter_id,sequence_no),add unique(term_id,tracking_id),
 add check((tracking_id is null and tracking_counter_id is null and tracking_prefix_snapshot is null and sequence_no is null and current_revision=0 and current_revision_id is null)
 or(tracking_id=tracking_prefix_snapshot||'-'||lpad(sequence_no::text,greatest(3,length(sequence_no::text)),'0') and sequence_no>0 and tracking_counter_id is not null and current_revision>0 and current_revision_id is not null));
create table public.request_drafts(
 request_id uuid primary key,organization_id uuid not null,term_id uuid not null,
 choice_snapshots jsonb not null default '{}',payload_json jsonb not null default '{}' check(jsonb_typeof(payload_json)='object' and octet_length(payload_json::text)<=100000),
 requested_centavos bigint check(requested_centavos between 0 and 9007199254740991),requested_on date check(requested_on between '0001-01-01' and '9999-12-31'),
 foreign key(organization_id,term_id,request_id) references public.requests(organization_id,term_id,work_item_id)
);
alter table public.asset_manifests add unique(id,work_item_id);
create table public.request_revisions(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,organization_id uuid not null,term_id uuid not null,revision_no integer not null check(revision_no>0),
 form_version_id uuid not null,workflow_version_id uuid not null,title_snapshot text not null,ordinary_payload_json jsonb,
 choice_snapshots jsonb not null,payload_classification text not null check(payload_classification in('ordinary','restricted')),
 manifest_id uuid,manifest_hash text not null check(manifest_hash~'^[0-9a-f]{64}$'),requested_on date,
 submitted_at timestamptz not null default statement_timestamp(),submitted_by uuid not null references auth.users(id),
 unique(request_id,revision_no),unique(request_id,id),unique(request_id,id,revision_no),unique(request_id,id,workflow_version_id),unique(organization_id,term_id,request_id,id),
 foreign key(organization_id,term_id,request_id) references public.requests(organization_id,term_id,work_item_id),
 foreign key(request_id,form_version_id,workflow_version_id) references public.requests(work_item_id,form_version_id,workflow_version_id),
 foreign key(manifest_id,request_id) references public.asset_manifests(id,work_item_id),
 check((payload_classification='ordinary' and ordinary_payload_json is not null and jsonb_typeof(ordinary_payload_json)='object') or(payload_classification='restricted' and ordinary_payload_json is null))
);
alter table public.requests add foreign key(work_item_id,current_revision_id,current_revision) references public.request_revisions(request_id,id,revision_no);
create table public.restricted_request_payloads(
 revision_id uuid primary key,request_id uuid not null,organization_id uuid not null,term_id uuid not null,payload_json jsonb not null check(jsonb_typeof(payload_json)='object'),
 foreign key(organization_id,term_id,request_id,revision_id) references public.request_revisions(organization_id,term_id,request_id,id)
);
create table public.request_finance_values(
 revision_id uuid primary key,request_id uuid not null,organization_id uuid not null,term_id uuid not null,
 requested_centavos bigint not null check(requested_centavos between 0 and 9007199254740991),
 foreign key(organization_id,term_id,request_id,revision_id) references public.request_revisions(organization_id,term_id,request_id,id)
);
create table public.workflow_instances(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,revision_id uuid not null unique,organization_id uuid not null,term_id uuid not null,
 workflow_version_id uuid not null,current_stage_key text not null,state text not null default 'paused' check(state in('paused','superseded','cancelled')),
 pause_reason text not null default 'decision_engine_pending',
 unique(organization_id,term_id,request_id,revision_id,id),
 foreign key(organization_id,term_id,request_id,revision_id) references public.request_revisions(organization_id,term_id,request_id,id),
 foreign key(workflow_version_id) references public.workflow_versions(id),foreign key(request_id,revision_id,workflow_version_id) references public.request_revisions(request_id,id,workflow_version_id)
);
create table public.request_assignment_shells(
 id uuid primary key default gen_random_uuid(),instance_id uuid not null,request_id uuid not null,revision_id uuid not null,organization_id uuid not null,term_id uuid not null,
 stage_key text not null,review_mode text not null check(review_mode in('none','one','all')),configured_member_id uuid,state text not null default 'paused' check(state='paused'),
 foreign key(organization_id,term_id,request_id,revision_id,instance_id) references public.workflow_instances(organization_id,term_id,request_id,revision_id,id),
 foreign key(organization_id,term_id,configured_member_id) references public.term_memberships(organization_id,term_id,id)
);
create index request_shell_member_idx on public.request_assignment_shells(organization_id,term_id,configured_member_id);
create table public.request_events(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,organization_id uuid not null,term_id uuid not null,revision_no integer not null,
 action text not null check(action in('draft_created','draft_saved','submitted','revision_started','revised','cancelled')),
 actor_name text not null,reason text not null default '' check(length(reason)<=2000),recorded_at timestamptz not null default statement_timestamp(),
 foreign key(organization_id,term_id,request_id) references public.requests(organization_id,term_id,work_item_id)
);
create index request_revisions_scope_idx on public.request_revisions(organization_id,term_id,request_id,submitted_at);
create index request_manifest_idx on public.request_revisions(manifest_id,request_id);
create index request_workflow_version_idx on public.workflow_instances(workflow_version_id);
create index request_workflow_scope_idx on public.workflow_instances(organization_id,term_id,request_id);
create index request_payload_scope_idx on public.restricted_request_payloads(organization_id,term_id,request_id);
create index request_finance_scope_idx on public.request_finance_values(organization_id,term_id,request_id);
create index request_events_scope_idx on public.request_events(organization_id,term_id,request_id,recorded_at);

create function app_private.request_history_guard() returns trigger language plpgsql set search_path='' as $$begin raise exception using errcode='55000',message='command_submitted_immutable';end$$;
do $$declare t text;begin
 foreach t in array array['request_revisions','restricted_request_payloads','request_finance_values','request_assignment_shells','request_events'] loop
  execute format('create trigger immutable_request_history before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);
 end loop;
 foreach t in array array['tracking_counters','request_drafts','request_revisions','restricted_request_payloads','request_finance_values','workflow_instances','request_assignment_shells','request_events'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 end loop;
end$$;
create function app_private.request_counter_guard() returns trigger language plpgsql set search_path='' as $$begin
 if tg_op='DELETE' or new.id<>old.id or new.organization_id<>old.organization_id or new.term_id<>old.term_id or new.namespace_key<>old.namespace_key or new.prefix<>old.prefix or new.next_value<>old.next_value+1 then raise exception using errcode='55000',message='command_tracking_immutable';end if;return new;end$$;
create trigger request_counter_guard before update or delete on public.tracking_counters for each row execute function app_private.request_counter_guard();
create function app_private.request_spine_guard() returns trigger language plpgsql set search_path='' as $$begin
 if tg_op='DELETE' then if old.request_type_id is not null then raise exception using errcode='55000',message='command_submitted_immutable';end if;return old;end if;
 if tg_op='UPDATE' and old.request_type_id is not null and (new.request_type_id is distinct from old.request_type_id or new.form_version_id<>old.form_version_id or new.workflow_version_id<>old.workflow_version_id or new.receiving_unit_id is distinct from old.receiving_unit_id or new.payload_classification<>old.payload_classification or new.type_label<>old.type_label or new.service_label is distinct from old.service_label or old.tracking_id is not null and (new.tracking_id is distinct from old.tracking_id or new.tracking_counter_id is distinct from old.tracking_counter_id or new.sequence_no is distinct from old.sequence_no or new.tracking_prefix_snapshot is distinct from old.tracking_prefix_snapshot or new.original_requested_on is distinct from old.original_requested_on)) then raise exception using errcode='55000',message='command_submitted_immutable';end if;
 return new;end$$;
create trigger request_spine_guard before update or delete on public.requests for each row execute function app_private.request_spine_guard();
-- Generic grants cannot widen tracked request access; P22 must define reviewer access explicitly.
create or replace function public.can_access_work(p_work_item_id uuid,p_level text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;member uuid;begin
 if p_level is null or p_level not in('summary','detail','edit','owner') then return false;end if;
 select * into w from public.work_items where id=p_work_item_id;if not found then return false;end if;
 select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id);
 if w.kind='request' and exists(select 1 from public.requests where work_item_id=w.id and request_type_id is not null) then
  return member=w.owner_member_id and exists(select 1 from public.term_memberships where id=public.current_term_membership(w.term_id) and membership_kind='core')
   and(p_level<>'edit' or exists(select 1 from public.requests where work_item_id=w.id and request_state in('draft','revision_draft')));
 end if;
 if member=w.owner_member_id then return true;end if;if p_level='owner' then return false;end if;
 if w.kind='task' and(app_private.task_participant(w.id)or app_private.task_manager(w))then return true;end if;
 if w.kind='deliverable' and app_private.manage_deliverable(w.term_id,w.lead_unit_id)then return true;end if;
 if p_level='summary' and w.classification='ordinary' and public.has_capability(w.term_id,'workspace.read')then return true;end if;
 if public.has_work_capability(w.id,'committee.manage')then return true;end if;
 if p_level<>'edit' and public.has_work_capability(w.id,'workspace.read')then return true;end if;
 return exists(select 1 from public.record_grants g where g.work_item_id=w.id and app_private.work_grant_matches(g)and(p_level<>'edit' or(member is not null and g.grant_kind='edit')));
end$$;
create function app_private.request_no_generic_grant() returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.requests where work_item_id=new.work_item_id and request_type_id is not null)then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger request_no_generic_grant before insert or update on public.record_grants for each row execute function app_private.request_no_generic_grant();
create or replace function public.update_work_item(p_work_item_id uuid,p_title text,p_safe_summary text,p_body text,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from public.work_items where id=p_work_item_id and(kind in('deliverable','task')or(kind='request'and exists(select 1 from public.requests where work_item_id=p_work_item_id and request_type_id is not null))))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 return app_private.update_work_item(p_work_item_id,p_title,p_safe_summary,p_body,p_expected_version,p_request_id);end$$;

create function app_private.request_route_ready(t public.request_types) returns boolean language sql stable security definer set search_path='' as $$
 select t.live_enabled and t.authority_confirmed and t.archived_at is null and exists(select 1 from public.terms where id=t.term_id and state='active')
 and exists(select 1 from public.org_units where id=t.receiving_unit_id and term_id=t.term_id and archived_at is null and review_service)
 and app_private.request_contact_active(t,t.primary_contact_id) and app_private.request_contact_active(t,t.backup_contact_id)
$$;
create function app_private.request_actor(term uuid,write_access boolean default false) returns public.term_memberships language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 select * into m from public.term_memberships where id=public.current_term_membership(term) and membership_kind='core';
 if not found or not public.has_capability(term,'workspace.read') or(write_access and not exists(select 1 from public.terms where id=term and state='active'))then raise exception using errcode='42501',message='command_permission_denied';end if;return m;end$$;
create function app_private.request_owned(id uuid,write_access boolean default false) returns public.work_items language plpgsql security definer set search_path='' as $$declare w public.work_items;m public.term_memberships;begin
 select * into w from public.work_items where work_items.id=request_owned.id for update;
 if not found or w.kind<>'request' then raise exception using errcode='42501',message='command_permission_denied';end if;
 m:=app_private.request_actor(w.term_id,write_access);
 if w.owner_member_id<>m.member_id or not exists(select 1 from public.requests where work_item_id=w.id and request_type_id is not null)or(write_access and w.archived_at is not null)then raise exception using errcode='42501',message='command_permission_denied';end if;return w;end$$;
create function app_private.request_status(term uuid,p_state text) returns uuid language plpgsql set search_path='' as $$declare id uuid;begin
 insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)
 select organization_id,term,'request','tracked_'||p_state,case when p_state in('draft','revision_draft')then 'draft' when p_state='cancelled'then 'cancelled'else 'active'end,case when p_state='paused'then 'Submitted · paused'else initcap(replace(p_state,'_',' '))end from public.terms where terms.id=term on conflict(term_id,resource_kind,stable_key)do nothing;
 select s.id into id from public.status_definitions s where s.term_id=term and resource_kind='request' and stable_key='tracked_'||p_state;return id;end$$;
create function app_private.request_receipt(w public.work_items) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('requestId',w.id,'termId',w.term_id,'version',w.version,'state',r.request_state,'revision',r.current_revision,'trackingId',r.tracking_id)from public.requests r where r.work_item_id=w.id
$$;
create function app_private.request_event(w public.work_items,action text,reason text default '') returns void language sql set search_path='' as $$
 insert into public.request_events(request_id,organization_id,term_id,revision_no,action,actor_name,reason)
 select w.id,w.organization_id,w.term_id,r.current_revision,action,w.owner_display_name,reason from public.requests r where r.work_item_id=w.id
$$;
create function app_private.optional_request_fields(fields jsonb)returns jsonb language plpgsql immutable set search_path='' as $$declare f jsonb;out jsonb:='[]';begin
 for f in select value from jsonb_array_elements(fields)loop f:=(f-'requiredWhen')||'{"required":false}';if f->>'type'='line_items'then f:=jsonb_set(f,'{itemFields}',app_private.optional_request_fields(f->'itemFields'));end if;out:=out||jsonb_build_array(f);end loop;return out;end$$;
create function app_private.validate_request_values(r public.requests,v jsonb,cents bigint,complete boolean)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare f public.form_versions;options jsonb;fields jsonb;result jsonb;begin
 select * into f from public.form_versions where id=r.form_version_id and request_type_id=r.request_type_id and state='published';
 options:=public.request_form_options(r.term_id,r.request_type_id,r.work_item_id);
 if options is null or f.id is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 perform app_private.validate_form_definition(f.schema_json,r.payload_classification='restricted');
 if jsonb_typeof(v)is distinct from 'object' or octet_length(v::text)>100000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 fields:=case when complete then f.schema_json->'fields'else app_private.optional_request_fields(f.schema_json->'fields')end;
 result:=app_private.validate_form_fields(fields,v,options,cents);
 if result->'errors'<>'{}'::jsonb or(cents is not null and not exists(select 1 from jsonb_array_elements(fields)field where field->>'key'='requested_centavos'and field->>'type'='currency'and field->>'storage'='finance'and(not(field?'visibleWhen')or app_private.form_condition(field->'visibleWhen',result->'values'))))then raise exception using errcode='22023',message='command_validation_failed';end if;return result;
end$$;
create function public.create_request_draft(p_term_id uuid,p_type_id uuid,p_form_version_id uuid,p_workflow_version_id uuid,p_title text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;t public.request_types;w public.work_items;payload jsonb;result jsonb;name text;begin
 m:=app_private.request_actor(p_term_id,true);payload:=jsonb_build_array(p_term_id,p_type_id,p_form_version_id,p_workflow_version_id,p_title);
 result:=app_private.begin_work_command('create_request_draft',p_request_id,payload);
 if result is not null then w:=app_private.request_owned((result->>'requestId')::uuid);return result;end if;
 select * into t from public.request_types where id=p_type_id and term_id=p_term_id for share;
 if not found or t.archived_at is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if t.form_version_id is distinct from p_form_version_id or t.workflow_version_id is distinct from p_workflow_version_id then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_title is null or length(btrim(p_title,E' \t\r\n'))not between 1 and 240 or p_title~'[[:cntrl:]]'then raise exception using errcode='22023',message='command_validation_failed';end if;
 select display_name into name from public.members where id=m.member_id;
 insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)
 values(m.organization_id,p_term_id,'request',btrim(p_title),'restricted',m.member_id,name,app_private.request_status(p_term_id,'draft'))returning * into w;
 insert into public.requests(work_item_id,organization_id,term_id,request_type_id,form_version_id,workflow_version_id,receiving_unit_id,type_label,service_label,payload_classification)
 values(w.id,w.organization_id,w.term_id,t.id,t.form_version_id,t.workflow_version_id,t.receiving_unit_id,t.label,(select u.name from public.org_units u where u.id=t.receiving_unit_id),t.payload_classification);
 insert into public.request_drafts(request_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
 perform app_private.request_event(w,'draft_created');return app_private.finish_work_command(w,'create_request_draft',p_request_id,payload,app_private.request_receipt(w),'["request_draft_created"]');
end$$;
create function public.save_request_draft(p_work_item_id uuid,p_values jsonb,p_requested_centavos bigint,p_requested_on date,p_title text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;payload jsonb;result jsonb;validated jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_values,p_requested_centavos,p_requested_on,p_title,p_expected_version);result:=app_private.begin_work_command('save_request_draft',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state not in('draft','revision_draft')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_title is null or length(btrim(p_title,E' \t\r\n'))not between 1 and 240 or p_title~'[[:cntrl:]]'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_requested_on is not null and not(p_requested_on between '0001-01-01'and'9999-12-31')then raise exception using errcode='22023',message='command_validation_failed';end if;
 validated:=app_private.validate_request_values(r,p_values,p_requested_centavos,false);
 update public.request_drafts set payload_json=validated->'values',choice_snapshots=validated->'snapshots',requested_centavos=p_requested_centavos,requested_on=p_requested_on where request_id=w.id;
 update public.work_items set title=btrim(p_title)where id=w.id returning * into w;
 perform app_private.request_event(w,'draft_saved');return app_private.finish_work_command(w,'save_request_draft',p_request_id,payload,app_private.request_receipt(w),'["request_draft_saved"]');
end$$;

create function app_private.request_file_ids(fields jsonb,v jsonb)returns uuid[]language plpgsql immutable set search_path='' as $$declare f jsonb;x jsonb;ids uuid[]:='{}';begin
 for f in select value from jsonb_array_elements(fields)loop
  if f->>'type'='file'and v?(f->>'key')then ids:=ids||array(select value::uuid from jsonb_array_elements_text(v->(f->>'key')));
  elsif f->>'type'='line_items'and v?(f->>'key')then for x in select value from jsonb_array_elements(v->(f->>'key'))loop ids:=ids||app_private.request_file_ids(f->'itemFields',x);end loop;end if;
 end loop;return array(select distinct id from unnest(ids)id order by id);end$$;
create function app_private.submit_request_revision(p_work_item_id uuid,p_values jsonb,p_requested_centavos bigint,p_requested_on date,p_title text,p_expected_version integer,p_request_id uuid,revision boolean)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;validated jsonb;payload jsonb;result jsonb;counter public.tracking_counters;namespace text;prefix text;seq bigint;tracking text;files uuid[];size integer;entries jsonb;manifest uuid;manifest_hash text;rid uuid;instance uuid;stage jsonb;member text;command text:=case when revision then 'revise_request'else 'submit_request'end;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_values,p_requested_centavos,p_requested_on,p_title,p_expected_version);result:=app_private.begin_work_command(command,p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state<>(case when revision then 'revision_draft'else 'draft'end) then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select * into t from public.request_types where id=r.request_type_id for share;
 perform 1 from public.org_units where id=r.receiving_unit_id and archived_at is null and review_service for share;
 if not found then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if not app_private.request_route_ready(t)or t.receiving_unit_id is distinct from r.receiving_unit_id then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_title is null or length(btrim(p_title,E' \t\r\n'))not between 1 and 240 or p_title~'[[:cntrl:]]'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if r.current_revision>=100 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if p_requested_on is not null and not(p_requested_on between '0001-01-01'and'9999-12-31')then raise exception using errcode='22023',message='command_validation_failed';end if;
 validated:=app_private.validate_request_values(r,p_values,p_requested_centavos,true);
 files:=app_private.request_file_ids((select schema_json->'fields'from public.form_versions where id=r.form_version_id),validated->'values');
 if cardinality(files)>20 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if exists(select 1 from public.assets where id=any(files)and(origin_work_item_id<>w.id or state<>'finalized'))or(select count(*)from public.assets where id=any(files))<>cardinality(files)then raise exception using errcode='42501',message='command_permission_denied';end if;
 entries:='[]';if cardinality(files)>0 then
  select sum(size_bytes)::int,jsonb_agg(jsonb_build_object('assetId',id,'sha256',sha256,'size',size_bytes,'mime',mime_type,'classification',classification,'source',source_snapshot)order by id)into size,entries from public.assets where id=any(files);
  if size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
  insert into public.asset_manifests(work_item_id,work_version,entries,sha256,size_bytes,created_by)values(w.id,w.version,entries,encode(sha256(convert_to(entries::text,'UTF8')),'hex'),size,auth.uid())returning id into manifest;
  insert into public.asset_manifest_items(manifest_id,asset_id)select manifest,unnest(files);
 end if;manifest_hash:=encode(sha256(convert_to(entries::text,'UTF8')),'hex');
 if not revision then
  namespace:=case t.governed_kind when 'fin'then 'FIN'when 'mcd'then 'MCD'else 'service:'||r.receiving_unit_id::text end;
  prefix:=case t.governed_kind when 'fin'then 'FIN'when 'mcd'then 'MCD'else(select code from public.org_units where id=r.receiving_unit_id)end;
  if t.governed_kind='general'and prefix in('FIN','MCD')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  -- One row-level atomic allocator shared by every type using this service namespace.
  insert into public.tracking_counters(organization_id,term_id,namespace_key,prefix,next_value)values(w.organization_id,w.term_id,namespace,prefix,2)
   on conflict(term_id,namespace_key)do update set next_value=public.tracking_counters.next_value+1 returning * into counter;
  seq:=counter.next_value-1;tracking:=counter.prefix||'-'||lpad(seq::text,greatest(3,length(seq::text)),'0');
 else tracking:=r.tracking_id;end if;
 insert into public.request_revisions(request_id,organization_id,term_id,revision_no,form_version_id,workflow_version_id,title_snapshot,ordinary_payload_json,payload_classification,choice_snapshots,manifest_id,manifest_hash,requested_on,submitted_by)
 values(w.id,w.organization_id,w.term_id,r.current_revision+1,r.form_version_id,r.workflow_version_id,btrim(p_title),case when r.payload_classification='ordinary'then validated->'values'end,r.payload_classification,validated->'snapshots',manifest,manifest_hash,p_requested_on,auth.uid())returning id into rid;
 if r.payload_classification='restricted'then insert into public.restricted_request_payloads values(rid,w.id,w.organization_id,w.term_id,validated->'values');end if;
 if p_requested_centavos is not null then insert into public.request_finance_values values(rid,w.id,w.organization_id,w.term_id,p_requested_centavos);end if;
 if revision then update public.workflow_instances set state='superseded'where request_id=w.id and state='paused';end if;
 select definition_json->'stages'->0 into stage from public.workflow_versions where id=r.workflow_version_id;
 insert into public.workflow_instances(request_id,revision_id,organization_id,term_id,workflow_version_id,current_stage_key)values(w.id,rid,w.organization_id,w.term_id,r.workflow_version_id,stage->>'key')returning id into instance;
 if jsonb_array_length(stage->'reviewers')=0 then
  insert into public.request_assignment_shells(instance_id,request_id,revision_id,organization_id,term_id,stage_key,review_mode)values(instance,w.id,rid,w.organization_id,w.term_id,stage->>'key',stage->>'review');
 else for member in select value from jsonb_array_elements_text(stage->'reviewers')loop
  -- A configured name is only a paused slot, never an active authority grant.
  insert into public.request_assignment_shells(instance_id,request_id,revision_id,organization_id,term_id,stage_key,review_mode,configured_member_id)
  values(instance,w.id,rid,w.organization_id,w.term_id,stage->>'key',stage->>'review',case when exists(select 1 from public.term_memberships where id=member::uuid and term_id=w.term_id and status='active')then member::uuid end);
 end loop;end if;
 update public.requests set current_revision=current_revision+1,current_revision_id=rid,request_state='paused',tracking_counter_id=case when revision then tracking_counter_id else counter.id end,tracking_prefix_snapshot=case when revision then tracking_prefix_snapshot else counter.prefix end,sequence_no=case when revision then sequence_no else seq end,tracking_id=tracking,original_requested_on=case when revision then original_requested_on else p_requested_on end where work_item_id=w.id;
 delete from public.request_drafts where request_id=w.id;
 update public.work_items set title=btrim(p_title),status_id=app_private.request_status(w.term_id,'paused')where id=w.id returning * into w;
 perform app_private.request_event(w,case when revision then 'revised'else 'submitted'end);
 return app_private.finish_work_command(w,command,p_request_id,payload,app_private.request_receipt(w),'["immutable_request_revision","tracking","paused_assignment_shell"]');
end$$;
create function public.submit_request(p_work_item_id uuid,p_values jsonb,p_requested_centavos bigint,p_requested_on date,p_title text,p_expected_version integer,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.submit_request_revision(p_work_item_id,p_values,p_requested_centavos,p_requested_on,p_title,p_expected_version,p_request_id,false)$$;
create function public.revise_request(p_work_item_id uuid,p_values jsonb,p_requested_centavos bigint,p_requested_on date,p_title text,p_expected_version integer,p_request_id uuid)returns jsonb language sql security definer set search_path='' as $$select app_private.submit_request_revision(p_work_item_id,p_values,p_requested_centavos,p_requested_on,p_title,p_expected_version,p_request_id,true)$$;
create function public.begin_request_revision(p_work_item_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;rev public.request_revisions;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version);result:=app_private.begin_work_command('begin_request_revision',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state<>'paused'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if exists(select 1 from public.request_types where id=r.request_type_id and archived_at is not null)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select * into rev from public.request_revisions where id=r.current_revision_id;
 insert into public.request_drafts(request_id,organization_id,term_id,payload_json,requested_centavos,requested_on,choice_snapshots)
 values(w.id,w.organization_id,w.term_id,coalesce(rev.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=rev.id)),(select requested_centavos from public.request_finance_values where revision_id=rev.id),rev.requested_on,rev.choice_snapshots);
 update public.requests set request_state='revision_draft'where work_item_id=w.id;
 update public.work_items set status_id=app_private.request_status(w.term_id,'revision_draft')where id=w.id returning * into w;
 perform app_private.request_event(w,'revision_started');return app_private.finish_work_command(w,'begin_request_revision',p_request_id,payload,app_private.request_receipt(w),'["request_revision_draft"]');
end$$;
create function public.cancel_request(p_work_item_id uuid,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version,p_reason);result:=app_private.begin_work_command('cancel_request',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state='cancelled'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.requests set request_state='cancelled'where work_item_id=w.id;
 update public.workflow_instances set state='cancelled'where request_id=w.id and state='paused';
 update public.work_items set status_id=app_private.request_status(w.term_id,'cancelled')where id=w.id returning * into w;
 perform app_private.request_event(w,'cancelled',p_reason);return app_private.finish_work_command(w,'cancel_request',p_request_id,payload,app_private.request_receipt(w),'["request_cancelled"]');
end$$;

create function app_private.request_readable(term uuid,id uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.work_items w join public.requests r on r.work_item_id=w.id join public.term_memberships m on m.id=public.current_term_membership(w.term_id)
 where w.id=request_readable.id and w.term_id=term and r.request_type_id is not null and m.member_id=w.owner_member_id and m.membership_kind='core'and public.has_capability(term,'workspace.read'))
$$;
create function public.read_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null,p_history_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;f public.form_versions;wf public.workflow_versions;selected public.request_revisions;d public.request_drafts;editable boolean;begin
 if not app_private.request_readable(p_term_id,p_work_item_id)then return null;end if;
 if p_history_page is null or p_history_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select * into w from public.work_items where id=p_work_item_id;select * into r from public.requests where work_item_id=w.id;
 select * into t from public.request_types where id=r.request_type_id;select * into f from public.form_versions where id=r.form_version_id;select * into wf from public.workflow_versions where id=r.workflow_version_id;
 select * into selected from public.request_revisions where request_id=w.id and revision_no=coalesce(p_revision,r.current_revision);
 if p_revision is not null and selected.id is null then return null;end if;
 select * into d from public.request_drafts where request_id=w.id;
 editable:=r.request_state in('draft','revision_draft')and t.archived_at is null and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active');
 return jsonb_build_object('id',w.id,'termId',w.term_id,'title',w.title,'version',w.version,'typeId',r.request_type_id,'typeLabel',r.type_label,'serviceLabel',r.service_label,
 'state',r.request_state,'revision',r.current_revision,'trackingId',r.tracking_id,'originalRequestedOn',r.original_requested_on,'acceptedOn',r.accepted_on,
 'formVersionId',f.id,'formVersion',f.version,'workflowVersionId',wf.id,'workflowVersion',wf.version,'form',f.schema_json,'classification',r.payload_classification,
 'canEdit',editable,'canSubmit',editable and app_private.request_route_ready(t)and t.receiving_unit_id is not distinct from r.receiving_unit_id,
 'canRevise',r.request_state='paused'and t.archived_at is null and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'),
 'canCancel',r.request_state<>'cancelled'and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'),
 'nextAction',case when r.request_state='cancelled'then 'Cancelled. Saved content and any issued tracking ID are retained.'when not editable and r.request_state in('draft','revision_draft')then 'Draft retained. This service or term is archived or unavailable.'when editable and t.receiving_unit_id is distinct from r.receiving_unit_id then 'Service routing changed since this draft began. Keep this saved draft and start a new draft from the current service; routing is never changed automatically.'when editable and not app_private.request_route_ready(t)then 'Draft can be saved. Active receiving service, contacts and confirmed routing are required before submission.'when editable then 'Save incomplete work or submit the current form. Submission is not FIN, MCD or school approval.'else 'Submitted and paused. Authorized reviewer assignment and decision processing are not configured. This status does not authorize costs or publicity.'end,
 'draft',case when d.request_id is not null then jsonb_build_object('values',d.payload_json,'snapshots',d.choice_snapshots,'requestedCentavos',d.requested_centavos,'requestedOn',d.requested_on)end,
 'selected',case when selected.id is not null then jsonb_build_object('revision',selected.revision_no,'title',selected.title_snapshot,'values',coalesce(selected.ordinary_payload_json,(select payload_json from public.restricted_request_payloads where revision_id=selected.id)),
 'snapshots',selected.choice_snapshots,'requestedCentavos',(select requested_centavos from public.request_finance_values where revision_id=selected.id),'requestedOn',selected.requested_on,'submittedAt',selected.submitted_at,'manifestHash',selected.manifest_hash,
 'files',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.filename,'size',a.size_bytes,'mime',a.mime_type,'sha256',a.sha256)order by a.id)from public.asset_manifest_items mi join public.assets a on a.id=mi.asset_id where mi.manifest_id=selected.manifest_id),'[]'))end,
 'revisionHeaders',coalesce((select jsonb_agg(jsonb_build_object('revision',h.revision_no,'title',h.title_snapshot,'requestedOn',h.requested_on,'submittedAt',h.submitted_at)order by h.revision_no desc)from public.request_revisions h where h.request_id=w.id),'[]'),
 'history',jsonb_build_object('page',p_history_page,'pageSize',25,'total',(select count(*)from public.request_events where request_id=w.id),'items',coalesce((select jsonb_agg(jsonb_build_object('action',e.action,'revision',e.revision_no,'actor',e.actor_name,'reason',e.reason,'at',e.recorded_at)order by e.recorded_at desc,e.id desc)from(select * from public.request_events where request_id=w.id order by recorded_at desc,id desc limit 25 offset(p_history_page-1)*25)e),'[]')));
end$$;
create function public.list_my_requests(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 if not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id)and membership_kind='core')or not public.has_capability(p_term_id,'workspace.read')then return null;end if;
 if p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 m:=app_private.request_actor(p_term_id);
 return jsonb_build_object('page',p_page,'pageSize',20,'total',(select count(*)from public.requests r join public.work_items w on w.id=r.work_item_id where r.term_id=p_term_id and r.request_type_id is not null and w.owner_member_id=m.member_id),
 'items',coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'termId',w.term_id,'title',w.title,'state',r.request_state,'trackingId',r.tracking_id,'typeLabel',r.type_label,'revision',r.current_revision,'requestedOn',coalesce(d.requested_on,rv.requested_on),'acceptedOn',r.accepted_on,'updatedAt',w.updated_at)order by w.updated_at desc,w.id)
 from(select wi.* from public.work_items wi join public.requests rq on rq.work_item_id=wi.id where wi.term_id=p_term_id and rq.request_type_id is not null and wi.owner_member_id=m.member_id order by wi.updated_at desc,wi.id limit 20 offset(p_page-1)*20)w
 join public.requests r on r.work_item_id=w.id left join public.request_drafts d on d.request_id=w.id left join public.request_revisions rv on rv.id=r.current_revision_id),'[]'));
end$$;

-- Extend the existing file seam only for requester-owned editable drafts, preserving other work.
create or replace function app_private.file_work(p_id uuid,p_version integer)returns public.work_items language plpgsql set search_path='' as $$declare w public.work_items;begin
 select * into w from public.work_items where id=p_id for update;
 if not found or not(w.kind in('task','deliverable')or(w.kind='request'and exists(select 1 from public.requests where work_item_id=w.id and request_type_id is not null and request_state in('draft','revision_draft'))))or not public.can_access_work(w.id,'edit')or public.current_term_membership(w.term_id)is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if w.version is distinct from p_version then raise exception using errcode='40001',message='command_stale_version';end if;return w;end$$;
create or replace function public.read_files(p_work_item_id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('workVersion',w.version,'canEdit',public.current_term_membership(w.term_id)is not null and public.can_access_work(w.id,'edit')and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'),
 'assets',coalesce((select jsonb_agg(to_jsonb(a)-array['object_path','created_by','expires_at']order by a.created_at,a.id)from public.asset_links l join public.assets a on a.id=l.asset_id where l.work_item_id=w.id and public.can_access_work(a.origin_work_item_id,'detail')and a.state<>'reserved'),'[]'),
 'manifests',coalesce((select jsonb_agg(to_jsonb(m)-'created_by'order by m.created_at,m.id)from public.asset_manifests m where m.work_item_id=w.id and public.can_read_manifest(m.id)),'[]'))
 from public.work_items w where w.id=p_work_item_id and(w.kind in('task','deliverable')or exists(select 1 from public.requests where work_item_id=w.id and request_type_id is not null))and public.can_access_work(w.id,'detail')
$$;
revoke all on function public.create_request_draft(uuid,uuid,uuid,uuid,text,uuid),public.save_request_draft(uuid,jsonb,bigint,date,text,integer,uuid),public.submit_request(uuid,jsonb,bigint,date,text,integer,uuid),public.revise_request(uuid,jsonb,bigint,date,text,integer,uuid),public.begin_request_revision(uuid,integer,uuid),public.cancel_request(uuid,integer,text,uuid),public.read_request(uuid,uuid,integer,integer),public.list_my_requests(uuid,integer)from public,anon,authenticated,service_role;
grant execute on function public.create_request_draft(uuid,uuid,uuid,uuid,text,uuid),public.save_request_draft(uuid,jsonb,bigint,date,text,integer,uuid),public.submit_request(uuid,jsonb,bigint,date,text,integer,uuid),public.revise_request(uuid,jsonb,bigint,date,text,integer,uuid),public.begin_request_revision(uuid,integer,uuid),public.cancel_request(uuid,integer,text,uuid),public.read_request(uuid,uuid,integer,integer),public.list_my_requests(uuid,integer)to authenticated;
revoke all on function app_private.request_history_guard(),app_private.request_counter_guard(),app_private.request_spine_guard(),app_private.request_no_generic_grant(),app_private.request_route_ready(public.request_types),app_private.request_actor(uuid,boolean),app_private.request_owned(uuid,boolean),app_private.request_status(uuid,text),app_private.request_receipt(public.work_items),app_private.request_event(public.work_items,text,text),app_private.optional_request_fields(jsonb),app_private.validate_request_values(public.requests,jsonb,bigint,boolean),app_private.request_file_ids(jsonb,jsonb),app_private.submit_request_revision(uuid,jsonb,bigint,date,text,integer,uuid,boolean),app_private.request_readable(uuid,uuid)from public,anon,authenticated,service_role;

-- Reuse working-source capture for these same narrow request drafts.
create or replace function public.save_working_link(p_work_item_id uuid,p_asset_id uuid,p_url text,p_name text,p_notes text,p_label text,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;result jsonb;payload jsonb;begin
 select * into w from public.work_items where id=p_work_item_id for update;
 if not public.can_access_work(w.id,'edit') or public.current_term_membership(w.term_id) is null or w.archived_at is not null or (w.kind not in('task','deliverable','request') or(w.kind='request' and not exists(select 1 from public.requests where work_item_id=w.id and request_type_id is not null and request_state in('draft','revision_draft')))) or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_id,p_url,p_name,p_notes,p_label,p_expected_version);result:=app_private.begin_work_command('save_working_link',p_request_id,payload);if result is not null then return result;end if;
 if p_url is null or length(p_url)>2048 or p_url !~ '^https://(drive\.google\.com/file/d/[A-Za-z0-9_-]+/(view|edit)|docs\.google\.com/(document|spreadsheets|presentation)/d/[A-Za-z0-9_-]+/(edit|view)|www\.canva\.com/design/[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)?/(edit|view))$' or coalesce(length(btrim(p_name)),0) not between 1 and 160 or p_name ~ '[\r\n]' or coalesce(length(btrim(p_notes)),0) not between 1 and 2000 or coalesce(length(btrim(p_label)),0) not between 1 and 120 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_asset_id is null then if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 insert into public.assets(origin_work_item_id,kind,classification,filename,source_url,access_notes,source_label,state,created_by)values(w.id,'working_link',w.classification,p_name,p_url,p_notes,p_label,'working',auth.uid())returning * into a;
 insert into public.asset_links(asset_id,work_item_id,created_by)values(a.id,w.id,auth.uid());
 else select * into a from public.assets where id=p_asset_id and origin_work_item_id=w.id and kind='working_link' for update;
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;if a.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 update public.assets set source_url=p_url,filename=p_name,access_notes=p_notes,source_label=p_label,version=version+1,updated_at=statement_timestamp()where id=a.id returning * into a;end if;
 return app_private.finish_work_command(w,'save_working_link',p_request_id,payload,jsonb_build_object('assetId',a.id,'version',a.version),'["working_source"]');
end$$;

create or replace function public.read_request_catalog(p_term_id uuid,p_type_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id) and membership_kind='core') or not public.has_capability(p_term_id,'workspace.read') then return null;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'key',r.stable_key,'label',r.label,'need',r.need,'classification',r.payload_classification,'guestEligible',r.guest_eligible,'authorityConfirmed',r.authority_confirmed,'liveEnabled',app_private.request_route_ready(r),
 'serviceReady',app_private.request_service_ready(r),'receivingUnit',case when u.archived_at is null then u.name end,
 'primaryContact',case when app_private.request_contact_active(r,r.primary_contact_id) then (select d.display_name from public.read_directory(p_term_id) d where d.member_id=(select member_id from public.term_memberships where id=r.primary_contact_id)) end,
 'backupContact',case when app_private.request_contact_active(r,r.backup_contact_id) then (select d.display_name from public.read_directory(p_term_id) d where d.member_id=(select member_id from public.term_memberships where id=r.backup_contact_id)) end,
 'leadTimeDays',r.lead_time_days,'officialUrl',r.official_url,'processNote',r.process_note,'formVersionId',f.id,'formVersion',f.version,'workflowVersionId',w.id,'workflowVersion',w.version,
 'form',case when p_type_id is not null then f.schema_json end) order by r.label),'[]'::jsonb) into result
 from public.request_types r join public.form_versions f on f.id=r.form_version_id and f.state='published' join public.workflow_versions w on w.id=r.workflow_version_id and w.state='published'
 left join public.org_units u on u.id=r.receiving_unit_id and u.term_id=r.term_id
 where r.term_id=p_term_id and r.archived_at is null and (p_type_id is null or r.id=p_type_id);
 return jsonb_build_object('items',result);
end$$;

-- A private ordinary-type request may select its own private uploads, never another restricted origin.
create or replace function public.request_form_options(p_term_id uuid,p_type_id uuid,p_work_item_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 result:=public.read_request_catalog(p_term_id,p_type_id);
 if result is null or jsonb_array_length(result->'items')<>1 then return null;end if;
 if p_work_item_id is not null and not exists(select 1 from public.work_items where id=p_work_item_id and term_id=p_term_id and archived_at is null and public.can_access_work(id,'edit')) then return null;end if;
 return jsonb_build_object(
 'members',(select coalesce(jsonb_agg(jsonb_build_object('id',d.member_id,'label',d.display_name) order by d.display_name,d.member_id),'[]') from (select d.* from public.read_directory(p_term_id) d join public.term_memberships m on m.member_id=d.member_id and m.term_id=p_term_id and m.membership_kind='core' and m.status='active' and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp() order by d.display_name,d.member_id limit 200) d),
 'units',(select coalesce(jsonb_agg(jsonb_build_object('id',u.id,'label',u.name) order by u.name,u.id),'[]') from (select id,name from public.org_units where term_id=p_term_id and archived_at is null order by name,id limit 200) u),
 'files',(select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'label',a.filename) order by a.filename,a.id),'[]') from (select a.id,a.filename from public.assets a join public.work_items w on w.id=a.origin_work_item_id and w.term_id=p_term_id where p_work_item_id is not null and a.state='finalized' and (a.classification='ordinary' or(a.origin_work_item_id=p_work_item_id and exists(select 1 from public.requests rq where rq.work_item_id=p_work_item_id and rq.request_type_id=p_type_id and rq.request_state in('draft','revision_draft')))or exists(select 1 from public.request_types where id=p_type_id and payload_classification='restricted')) and public.can_access_work(a.origin_work_item_id,'detail') and (a.origin_work_item_id=p_work_item_id or exists(select 1 from public.asset_links l where l.asset_id=a.id and l.work_item_id=p_work_item_id)) order by a.filename,a.id limit 100) a));
end$$;


create function app_private.request_payload_presence()returns trigger language plpgsql set search_path='' as $$
declare rid uuid;rev public.request_revisions;r public.requests;begin
 if tg_table_name='request_revisions'then rid:=new.id;else rid:=new.revision_id;end if;
 select * into rev from public.request_revisions where id=rid;select * into r from public.requests where work_item_id=rev.request_id;
 if rev.payload_classification is distinct from r.payload_classification or rev.revision_no>r.current_revision or ((select count(*)from public.restricted_request_payloads where revision_id=rid)<>case when rev.payload_classification='restricted'then 1 else 0 end)then raise exception using errcode='23514',message='request_payload_classification_required';end if;return null;
end$$;
create constraint trigger request_payload_presence after insert on public.request_revisions deferrable initially deferred for each row execute function app_private.request_payload_presence();
create constraint trigger restricted_payload_presence after insert on public.restricted_request_payloads deferrable initially deferred for each row execute function app_private.request_payload_presence();
revoke all on function app_private.request_payload_presence()from public,anon,authenticated,service_role;
