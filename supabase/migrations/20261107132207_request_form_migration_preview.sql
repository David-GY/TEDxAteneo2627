begin;
-- P36 first migration slice: requester-owned, saved never-submitted ordinary drafts.
-- This is a comparison only. It returns names/issues, never candidate values or an apply receipt.
create function public.preview_request_form_migration(p_work_item_id uuid,p_expected_version integer)returns jsonb
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
  or t.governed_kind<>'general' or r.payload_classification<>'ordinary' or t.payload_classification<>'ordinary'
  or t.workflow_version_id is distinct from r.workflow_version_id then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into d from public.request_drafts where request_id=w.id;
 select *into source from public.form_versions where id=r.form_version_id and request_type_id=t.id and state='published';
 select *into target from public.form_versions where id=t.form_version_id and request_type_id=t.id and state='published';
 if d.request_id is null or source.id is null or target.id is null or d.requested_centavos is not null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 perform app_private.validate_form_definition(source.schema_json,false);perform app_private.validate_form_definition(target.schema_json,false);
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
revoke all on function public.preview_request_form_migration(uuid,integer)from public,anon,authenticated,service_role;
grant execute on function public.preview_request_form_migration(uuid,integer)to authenticated;
commit;
