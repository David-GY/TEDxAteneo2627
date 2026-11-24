begin;
alter table public.request_events drop constraint request_events_action_check;
alter table public.request_events add constraint request_events_action_check check(action in('draft_created','draft_saved','submitted','revision_started','revised','cancelled','form_migrated','form_migration_undone'));
-- Private immutable pre-change snapshots. Only the bounded commands below may move an unsubmitted form pin.
create table public.request_form_migrations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,request_id uuid not null,
 actor_id uuid not null references auth.users(id),kind text not null check(kind in('apply','undo')),
 source_form_version_id uuid not null references public.form_versions(id),target_form_version_id uuid not null references public.form_versions(id),
 workflow_version_id uuid not null references public.workflow_versions(id),reverses_id uuid unique references public.request_form_migrations(id),
 expected_work_version integer not null check(expected_work_version>0),before_payload jsonb not null check(jsonb_typeof(before_payload)='object'and octet_length(before_payload::text)<=100000),
 before_snapshots jsonb not null,before_requested_on date,before_title text not null,
 transition_txid bigint not null default txid_current(),created_at timestamptz not null default statement_timestamp(),
 foreign key(organization_id,term_id,request_id)references public.requests(organization_id,term_id,work_item_id),
 check(source_form_version_id<>target_form_version_id),check((kind='apply')=(reverses_id is null))
);
create index request_form_migrations_request_idx on public.request_form_migrations(request_id,expected_work_version desc,id);
alter table public.request_form_migrations enable row level security;
alter table public.request_form_migrations force row level security;
revoke all on public.request_form_migrations from public,anon,authenticated,service_role;
create trigger immutable_form_migration before update or delete on public.request_form_migrations for each row execute function app_private.request_history_guard();

create function app_private.form_change_request(p_id uuid)returns public.requests language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;m public.term_memberships;begin
 select *into w from public.work_items where id=p_id and kind='request';if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 m:=app_private.request_actor(w.term_id,true);select *into r from public.requests where work_item_id=w.id;select *into t from public.request_types where id=r.request_type_id;
 if w.owner_member_id is distinct from m.member_id or w.archived_at is not null or t.id is null or t.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 if t.governed_kind<>'general' or t.payload_classification is distinct from r.payload_classification then raise exception using errcode='55000',message='command_dependency_blocked';end if;return r;
end$$;
create function app_private.form_change_draft(p_id uuid,p_version integer)returns public.requests language plpgsql stable security definer set search_path='' as $$
declare r public.requests;begin r:=app_private.form_change_request(p_id);
 if r.request_state<>'draft' or r.current_revision<>0 or r.tracking_id is not null or exists(select 1 from public.request_revisions where request_id=p_id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if (select version from public.work_items where id=p_id)is distinct from p_version then raise exception using errcode='40001',message='command_stale_version';end if;return r;
end$$;
create function app_private.form_migration_candidate(p_source jsonb,p_target jsonb,p_values jsonb)returns jsonb language plpgsql immutable set search_path='' as $$
declare f jsonb;old jsonb;result jsonb:='{}';begin
 for f in select value from jsonb_array_elements(p_target->'fields')loop
  select value into old from jsonb_array_elements(p_source->'fields')where value->>'key'=f->>'key';
  if old is not null and f->>'type'=old->>'type' and coalesce(f->>'storage','custom')=coalesce(old->>'storage','custom') and f->>'classification'=old->>'classification' and(f->>'type'<>'line_items' or f->'itemFields'=old->'itemFields')and p_values?(f->>'key')and(not(f?'visibleWhen')or app_private.form_condition(f->'visibleWhen',result))then result:=result||jsonb_build_object(f->>'key',p_values->(f->>'key'));end if;
 end loop;return result;
end$$;
create function app_private.last_form_migration(p_id uuid)returns public.request_form_migrations language sql stable security definer set search_path='' as $$
 select e from public.request_form_migrations e where e.request_id=p_id and e.kind='apply'and not exists(select 1 from public.request_form_migrations x where x.reverses_id=e.id)order by e.expected_work_version desc,e.id desc limit 1
$$;
create function public.prepare_request_form_migration(p_work_item_id uuid,p_expected_version integer)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare c jsonb;r public.requests;source jsonb;target jsonb;v jsonb;e public.request_form_migrations;begin
 c:=public.preview_request_form_migration(p_work_item_id,p_expected_version);select *into r from public.requests where work_item_id=p_work_item_id;
 select schema_json into source from public.form_versions where id=r.form_version_id;select schema_json into target from public.form_versions where id=(c->>'targetFormVersionId')::uuid;
 select payload_json into v from public.request_drafts where request_id=p_work_item_id;e:=app_private.last_form_migration(p_work_item_id);
 return jsonb_build_object('comparison',c,'classification',r.payload_classification,'definition',target,'values',app_private.form_migration_candidate(source,target,v),'undoAvailable',e.id is not null and e.target_form_version_id=r.form_version_id);
end$$;
create function public.review_request_form_migration(p_work_item_id uuid,p_expected_version integer,p_target_form_version_id uuid,p_values jsonb)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare c jsonb;r public.requests;d public.request_drafts;v jsonb;definition jsonb;fingerprint text;begin
 c:=public.preview_request_form_migration(p_work_item_id,p_expected_version);
 if not(c->>'changed')::boolean or(c->>'targetFormVersionId')::uuid is distinct from p_target_form_version_id then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into r from public.requests where work_item_id=p_work_item_id;select *into d from public.request_drafts where request_id=p_work_item_id;r.form_version_id:=p_target_form_version_id;
 v:=app_private.validate_request_values(r,p_values,null,true);select schema_json into definition from public.form_versions where id=p_target_form_version_id;
 fingerprint:=encode(sha256(convert_to(jsonb_build_array(auth.uid(),p_work_item_id,p_expected_version,c->>'sourceFormVersionId',p_target_form_version_id,r.workflow_version_id,to_jsonb(d),(select title from public.work_items where id=p_work_item_id),v)::text,'UTF8')),'hex');
 return jsonb_build_object('requestId',p_work_item_id,'classification',r.payload_classification,'version',p_expected_version,'sourceFormVersionId',c->'sourceFormVersionId','targetFormVersionId',p_target_form_version_id,'definition',definition,'values',v->'values','snapshots',v->'snapshots','reviewHash',fingerprint,'mode','apply','migrationId',null,'title',(select title from public.work_items where id=p_work_item_id),'requestedOn',d.requested_on);
end$$;
create function public.review_request_form_migration_undo(p_work_item_id uuid,p_expected_version integer)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.requests;e public.request_form_migrations;d public.request_drafts;v jsonb;definition jsonb;fingerprint text;begin
 r:=app_private.form_change_draft(p_work_item_id,p_expected_version);e:=app_private.last_form_migration(p_work_item_id);
 if e.id is null or e.target_form_version_id<>r.form_version_id or e.workflow_version_id<>r.workflow_version_id then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select *into d from public.request_drafts where request_id=p_work_item_id;r.form_version_id:=e.source_form_version_id;
 v:=app_private.validate_request_values(r,e.before_payload,null,false);select schema_json into definition from public.form_versions where id=e.source_form_version_id;
 fingerprint:=encode(sha256(convert_to(jsonb_build_array(auth.uid(),p_work_item_id,p_expected_version,e.id,to_jsonb(d),(select title from public.work_items where id=p_work_item_id),v,r.workflow_version_id)::text,'UTF8')),'hex');
 return jsonb_build_object('requestId',p_work_item_id,'classification',r.payload_classification,'version',p_expected_version,'sourceFormVersionId',e.target_form_version_id,'targetFormVersionId',e.source_form_version_id,'definition',definition,'values',v->'values','snapshots',e.before_snapshots,'reviewHash',fingerprint,'mode','undo','migrationId',e.id,'title',e.before_title,'requestedOn',e.before_requested_on);
end$$;

-- A pin transition needs a new immutable command event from this exact transaction, actor and work version.
-- No setting/session flag, client-side schema or generic request update can bypass the original guard.
create or replace function app_private.request_spine_guard()returns trigger language plpgsql set search_path='' as $$
declare allowed_form boolean:=false;begin
 if tg_op='DELETE'then if old.request_type_id is not null then raise exception using errcode='55000',message='command_submitted_immutable';end if;return old;end if;
 if new.form_version_id is distinct from old.form_version_id then
  allowed_form:=old.request_state='draft'and new.request_state='draft'and old.current_revision=0 and new.current_revision=0 and old.tracking_id is null and new.tracking_id is null
   and not exists(select 1 from public.request_revisions where request_id=old.work_item_id)
   and exists(select 1 from public.request_form_migrations e where e.request_id=old.work_item_id and e.source_form_version_id=old.form_version_id and e.target_form_version_id=new.form_version_id and e.workflow_version_id=old.workflow_version_id and e.actor_id=auth.uid()and e.transition_txid=txid_current()and e.expected_work_version=(select version from public.work_items where id=old.work_item_id));
 end if;
 if old.request_type_id is not null and(new.request_type_id is distinct from old.request_type_id or(new.form_version_id is distinct from old.form_version_id and not allowed_form)or new.workflow_version_id<>old.workflow_version_id or new.receiving_unit_id is distinct from old.receiving_unit_id or new.payload_classification<>old.payload_classification or new.type_label<>old.type_label or new.service_label is distinct from old.service_label or old.tracking_id is not null and(new.tracking_id is distinct from old.tracking_id or new.tracking_counter_id is distinct from old.tracking_counter_id or new.sequence_no is distinct from old.sequence_no or new.tracking_prefix_snapshot is distinct from old.tracking_prefix_snapshot or new.original_requested_on is distinct from old.original_requested_on))then raise exception using errcode='55000',message='command_submitted_immutable';end if;return new;
end$$;
create function public.apply_request_form_migration(p_work_item_id uuid,p_expected_version integer,p_target_form_version_id uuid,p_values jsonb,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;d public.request_drafts;payload jsonb;result jsonb;review jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);r:=app_private.form_change_request(p_work_item_id);payload:=jsonb_build_array(p_work_item_id,p_expected_version,p_target_form_version_id,p_values,p_review_hash,p_reason);
 result:=app_private.begin_work_command('apply_request_form_migration',p_request_id,payload);if result is not null then return result;end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 -- Serialize target publication against validation and the committed pin transition.
 perform 1 from public.request_types where id=r.request_type_id for share;
 review:=public.review_request_form_migration(p_work_item_id,p_expected_version,p_target_form_version_id,p_values);
 if p_review_hash is distinct from review->>'reviewHash'then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into d from public.request_drafts where request_id=w.id;
 insert into public.request_form_migrations(organization_id,term_id,request_id,actor_id,kind,source_form_version_id,target_form_version_id,workflow_version_id,expected_work_version,before_payload,before_snapshots,before_requested_on,before_title)
 values(w.organization_id,w.term_id,w.id,auth.uid(),'apply',r.form_version_id,p_target_form_version_id,r.workflow_version_id,w.version,d.payload_json,d.choice_snapshots,d.requested_on,w.title);
 update public.requests set form_version_id=p_target_form_version_id where work_item_id=w.id;
 update public.request_drafts set payload_json=review->'values',choice_snapshots=review->'snapshots'where request_id=w.id;
 update public.work_items set title=title where id=w.id returning *into w;
 perform app_private.request_event(w,'form_migrated',p_reason);
 return app_private.finish_work_command(w,'apply_request_form_migration',p_request_id,payload,app_private.request_receipt(w)||'{"formChanged":true}','["draft_form_version","draft_payload"]');
end$$;
create function public.undo_request_form_migration(p_work_item_id uuid,p_expected_version integer,p_migration_id uuid,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;d public.request_drafts;e public.request_form_migrations;payload jsonb;result jsonb;review jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);r:=app_private.form_change_request(p_work_item_id);payload:=jsonb_build_array(p_work_item_id,p_expected_version,p_migration_id,p_review_hash,p_reason);
 result:=app_private.begin_work_command('undo_request_form_migration',p_request_id,payload);if result is not null then return result;end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 review:=public.review_request_form_migration_undo(p_work_item_id,p_expected_version);
 if p_review_hash is distinct from review->>'reviewHash'or p_migration_id is distinct from(review->>'migrationId')::uuid then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into e from public.request_form_migrations where id=p_migration_id;select *into d from public.request_drafts where request_id=w.id;
 insert into public.request_form_migrations(organization_id,term_id,request_id,actor_id,kind,source_form_version_id,target_form_version_id,workflow_version_id,reverses_id,expected_work_version,before_payload,before_snapshots,before_requested_on,before_title)
 values(w.organization_id,w.term_id,w.id,auth.uid(),'undo',r.form_version_id,e.source_form_version_id,r.workflow_version_id,e.id,w.version,d.payload_json,d.choice_snapshots,d.requested_on,w.title);
 update public.requests set form_version_id=e.source_form_version_id where work_item_id=w.id;
 update public.request_drafts set payload_json=review->'values',choice_snapshots=review->'snapshots',requested_on=e.before_requested_on where request_id=w.id;
 update public.work_items set title=e.before_title where id=w.id returning *into w;
 perform app_private.request_event(w,'form_migration_undone',p_reason);
 return app_private.finish_work_command(w,'undo_request_form_migration',p_request_id,payload,app_private.request_receipt(w)||'{"formChanged":true}','["draft_form_restored","draft_payload"]');
end$$;
revoke all on function app_private.form_change_request(uuid),app_private.form_change_draft(uuid,integer),app_private.form_migration_candidate(jsonb,jsonb,jsonb),app_private.last_form_migration(uuid)from public,anon,authenticated,service_role;
revoke all on function public.prepare_request_form_migration(uuid,integer),public.review_request_form_migration(uuid,integer,uuid,jsonb),public.review_request_form_migration_undo(uuid,integer),public.apply_request_form_migration(uuid,integer,uuid,jsonb,text,text,uuid),public.undo_request_form_migration(uuid,integer,uuid,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.prepare_request_form_migration(uuid,integer),public.review_request_form_migration(uuid,integer,uuid,jsonb),public.review_request_form_migration_undo(uuid,integer),public.apply_request_form_migration(uuid,integer,uuid,jsonb,text,text,uuid),public.undo_request_form_migration(uuid,integer,uuid,text,text,uuid)to authenticated;
create or replace function public.preview_request_form_migration(p_work_item_id uuid,p_expected_version integer)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;d public.request_drafts;m public.term_memberships;
 source public.form_versions;target public.form_versions;f jsonb;old jsonb;candidate jsonb:='{}';changes jsonb:='[]';issues jsonb:='[]';
 action text;compatible boolean;validation jsonb;problem record;label text;issue_count integer:=0;
begin
 select *into w from public.work_items where id=p_work_item_id and kind='request';
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 m:=app_private.request_actor(w.term_id,true);
 if w.owner_member_id is distinct from m.member_id or w.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 select *into r from public.requests where work_item_id=w.id;
 select *into t from public.request_types where id=r.request_type_id and term_id=w.term_id;
 if t.id is null or t.archived_at is not null then raise exception using errcode='42501',message='command_permission_denied';end if;
 if r.request_state<>'draft' or r.current_revision<>0 or exists(select 1 from public.request_revisions where request_id=w.id)
  or t.governed_kind<>'general' or r.payload_classification is distinct from t.payload_classification
  or t.workflow_version_id is distinct from r.workflow_version_id then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into d from public.request_drafts where request_id=w.id;
 select *into source from public.form_versions where id=r.form_version_id and request_type_id=t.id and state='published';
 select *into target from public.form_versions where id=t.form_version_id and request_type_id=t.id and state='published';
 if d.request_id is null or source.id is null or target.id is null or d.requested_centavos is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 perform app_private.validate_form_definition(source.schema_json,r.payload_classification='restricted');perform app_private.validate_form_definition(target.schema_json,r.payload_classification='restricted');
 for f in select value from jsonb_array_elements((source.schema_json->'fields')||(target.schema_json->'fields'))loop
  if coalesce(f->>'storage','custom')<>'custom' or f->>'type'='currency' or exists(select 1 from jsonb_array_elements(coalesce(f->'itemFields','[]'))c where coalesce(c->>'storage','custom')<>'custom' or c->>'type'='currency')then
   raise exception using errcode='55000',message='command_dependency_blocked';end if;
 end loop;
 for f in select value from jsonb_array_elements(target.schema_json->'fields')loop
  select value into old from jsonb_array_elements(source.schema_json->'fields')where value->>'key'=f->>'key';
  compatible:=old is not null and f->>'type'=old->>'type' and coalesce(f->>'storage','custom')=coalesce(old->>'storage','custom') and f->>'classification'=old->>'classification'
   and (f->>'type'<>'line_items' or f->'itemFields'=old->'itemFields');
  action:=case when old is null then 'added' when compatible then 'kept' else 'manual'end;
  if compatible and d.payload_json?(f->>'key')then candidate:=candidate||jsonb_build_object(f->>'key',d.payload_json->(f->>'key'));end if;
  changes:=changes||jsonb_build_array(jsonb_build_object('fromLabel',old->>'label','toLabel',f->>'label','action',action,'hasSavedAnswer',old is not null and d.payload_json?(old->>'key')));
 end loop;
 for old in select value from jsonb_array_elements(source.schema_json->'fields')loop
  if not exists(select 1 from jsonb_array_elements(target.schema_json->'fields')new_field where new_field->>'key'=old->>'key')then
   changes:=changes||jsonb_build_array(jsonb_build_object('fromLabel',old->>'label','toLabel',null,'action','removed','hasSavedAnswer',d.payload_json?(old->>'key')));end if;
 end loop;
 validation:=app_private.validate_form_fields(target.schema_json->'fields',candidate,public.request_form_options(w.term_id,t.id,w.id),null);
 for problem in select key,value from jsonb_each_text(validation->'errors')loop
  issue_count:=issue_count+1;
  if issue_count<=100 then
   select value->>'label'into label from jsonb_array_elements(target.schema_json->'fields')where value->>'key'=split_part(problem.key,'.',1);
   issues:=issues||jsonb_build_array(jsonb_build_object('label',coalesce(label,'Form answers'),'code',problem.value));
  end if;
 end loop;
 return jsonb_build_object('requestId',w.id,'version',w.version,'sourceFormVersionId',source.id,'sourceVersion',source.version,
  'targetFormVersionId',target.id,'targetVersion',target.version,'changed',source.id<>target.id,'readOnly',true,'changes',changes,'issues',issues,'issuesTruncated',issue_count>100);
end$$;

commit;
