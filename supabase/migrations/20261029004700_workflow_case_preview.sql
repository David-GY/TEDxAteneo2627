-- Read-only counterfactual preview. No request, assignment, grant, decision or outbox is created.
create function public.preview_workflow_cases(p_draft_id uuid,p_requester_id uuid,p_values jsonb,p_has_evidence boolean)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d public.configuration_drafts;t public.request_types;m public.term_memberships;f public.form_versions;
 options jsonb;validation jsonb;s jsonb;cases jsonb:='[]';steps jsonb;scenario text;blocker text;prior_blocked boolean;
 k text;reviewer text;people jsonb;return_label text;begin
 select *into d from public.configuration_drafts where id=p_draft_id and actor_id=auth.uid();
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 m:=app_private.configuration_actor(d.request_type_id);
 select *into t from public.request_types where id=d.request_type_id;
 if d.kind<>'workflow'or app_private.configuration_problem(t,d)is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if d.base_form_version_id is distinct from t.form_version_id or d.base_workflow_version_id is distinct from t.workflow_version_id then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_requester_id is null or(p_requester_id<>m.id and app_private.workflow_role(t.term_id,p_requester_id,t.receiving_unit_id)is null)then raise exception using errcode='42501',message='command_permission_denied';end if;
 if jsonb_typeof(p_values)is distinct from 'object'or octet_length(p_values::text)>100000 or p_has_evidence is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 select *into f from public.form_versions where id=t.form_version_id;
 options:=public.request_form_options(t.term_id,t.id,null);
 if options is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 validation:=app_private.validate_form_fields(f.schema_json->'fields',p_values,options,null);
 foreach scenario in array array['happy','revision','missing_reviewer','requester_conflict']loop
  steps:='[]';prior_blocked:=false;
  for s in select value from jsonb_array_elements(d.definition->'stages')loop
   blocker:=null;people:='[]';
   if validation->'errors'<>'{}'::jsonb then blocker:='invalid_answers';end if;
   for k in select value from jsonb_array_elements_text(s->'entryFields')loop
    if not((validation->'values')?k)or validation->'values'->k in('null'::jsonb,'""'::jsonb,'[]'::jsonb)then blocker:=coalesce(blocker,'required_fields_missing');end if;
   end loop;
   if(coalesce((s->>'requiredManifest')::boolean,false)or coalesce((s->>'externalEvidenceRequired')::boolean,false))and not p_has_evidence then blocker:=coalesce(blocker,'required_documents_missing');end if;
   if s?'condition'and not app_private.form_condition(s->'condition',coalesce(validation->'values','{}'))then blocker:=coalesce(blocker,'entry_condition_not_met');end if;
   for reviewer in select value from jsonb_array_elements_text(s->'reviewers')loop
    if app_private.workflow_role(t.term_id,reviewer::uuid,t.receiving_unit_id)is null then blocker:=coalesce(blocker,'reviewer_unavailable');end if;
    if reviewer::uuid=p_requester_id then blocker:=coalesce(blocker,'requester_conflict');end if;
    people:=people||coalesce((select jsonb_build_array(jsonb_build_object('id',tm.id,'name',person.display_name))from public.term_memberships tm join public.members person on person.id=tm.member_id where tm.id=reviewer::uuid and tm.term_id=t.term_id),'[]');
   end loop;
   if scenario='missing_reviewer'then blocker:=coalesce(blocker,'reviewer_unavailable');end if;
   if scenario='requester_conflict'then blocker:=coalesce(blocker,'requester_conflict');end if;
   select st->>'label'into return_label from jsonb_array_elements(d.definition->'stages')st where st->>'key'=coalesce(s->>'revisionStage',d.definition->'stages'->0->>'key');
   steps:=steps||jsonb_build_array(jsonb_build_object('key',s->>'key','label',s->>'label','people',people,'blocker',blocker,
    'reachable',not prior_blocked,'revisionReturnsTo',return_label,'nextAction',case when prior_blocked then 'Finish the preceding step first'
     when blocker='invalid_answers'or blocker='required_fields_missing'then 'Requester: complete the required answers'
     when blocker='required_documents_missing'then 'Requester: provide the required final evidence'
     when blocker='entry_condition_not_met'then 'Requester and service head: resolve the unmet entry condition'
     when blocker is not null then 'Service head: assign an independent current eligible reviewer'
     when scenario='revision'then 'Requester: revise the submission, then return to '||return_label
     else 'Named reviewers: review this submission; approval continues along the configured route'end));
   prior_blocked:=prior_blocked or blocker is not null;
  end loop;
  cases:=cases||jsonb_build_array(jsonb_build_object('scenario',scenario,'stages',steps));
 end loop;
 return jsonb_build_object('draftId',d.id,'version',d.version,'synthetic',true,'formValid',validation->'errors'='{}'::jsonb,'errors',validation->'errors','cases',cases);
end$$;
revoke all on function public.preview_workflow_cases(uuid,uuid,jsonb,boolean)from public,anon,authenticated,service_role;
grant execute on function public.preview_workflow_cases(uuid,uuid,jsonb,boolean)to authenticated;

create function public.read_configuration_history(p_type_id uuid,p_before integer default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare items jsonb;more boolean;begin
 perform app_private.configuration_actor(p_type_id);
 if p_before is not null and p_before<1 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'kind',h.kind,'definitionVersionId',h.definition_version_id,
  'rollbackVersionId',h.rollback_version_id,'version',h.control_version,'publishedAt',h.published_at,'reason',h.reason,
  'definition',case h.kind when 'form'then(select schema_json from public.form_versions where id=h.definition_version_id)
   else(select definition_json from public.workflow_versions where id=h.definition_version_id)end)order by h.control_version desc),'[]')into items
 from(select *from public.configuration_publications where request_type_id=p_type_id and(p_before is null or control_version<p_before)order by control_version desc limit 51)h;
 more:=jsonb_array_length(items)>50;
 select coalesce(jsonb_agg(value order by ordinality),'[]')into items from jsonb_array_elements(items)with ordinality where ordinality<=50;
 return jsonb_build_object('items',items,'nextBefore',case when more then(items->49->>'version')::integer else null end);
end$$;
revoke all on function public.read_configuration_history(uuid,integer)from public,anon,authenticated,service_role;
grant execute on function public.read_configuration_history(uuid,integer)to authenticated;

alter function public.read_configuration(uuid)rename to read_configuration_before_cases;
alter function public.read_configuration_before_cases(uuid)set schema app_private;
revoke all on function app_private.read_configuration_before_cases(uuid)from public,anon,authenticated,service_role;
create function public.read_configuration(p_type_id uuid)returns jsonb
language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 result:=app_private.read_configuration_before_cases(p_type_id);
 return result||jsonb_build_object('pinnedCases',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'termId',c.term_id,'title',c.title,'formVersion',c.fv,'workflowVersion',c.wv,'workflowVersionId',c.workflow_version_id)order by c.id)
 from(select w.id,w.term_id,w.title,f.version fv,v.version wv,r.workflow_version_id from public.requests r join public.work_items w on w.id=r.work_item_id
  join public.form_versions f on f.id=r.form_version_id join public.workflow_versions v on v.id=r.workflow_version_id
  where r.request_type_id=p_type_id and w.archived_at is null and r.request_state not in('approved','rejected','completed','cancelled')
  and app_private.request_readable(w.term_id,w.id)order by w.id limit 50)c),'[]'));
end$$;
revoke all on function public.read_configuration(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_configuration(uuid)to authenticated;
