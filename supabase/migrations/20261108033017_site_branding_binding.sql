-- P39: approved image selection, separate from interface typography/accent.
-- No logo bytes, URL or approval checkbox can be supplied in presentation JSON.
create function app_private.site_logo_valid(p_term uuid,p_asset uuid,p_approval uuid)returns boolean
language plpgsql stable security definer set search_path='' as $$declare approval public.publicity_approvals;review public.publicity_reviews;begin
 select *into approval from public.publicity_approvals where id=p_approval;
 select *into review from public.publicity_reviews where id=approval.publicity_review_id and term_id=p_term;
 if review.id is null then return false;end if;
 return app_private.publicity_approval_state(approval)='approved' and app_private.publicity_finance_state(review)<>'pending'
  and review.payload->>'intendedUse'='core_workspace_logo'
  and review.payload->>'channel'='Core workspace (members and invited guests)'
  and review.payload->>'identity'='TEDx Ateneo de Manila U'
  and exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id
   where i.manifest_id=review.manifest_id and a.id=p_asset and a.origin_work_item_id=review.request_id
    and a.kind='upload' and a.state='finalized' and a.mime_type in('image/png','image/jpeg'));
exception when insufficient_privilege or invalid_parameter_value then return false;end$$;

alter function app_private.validate_presentation(text,jsonb)rename to validate_presentation_before_branding;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql stable security definer set search_path='' as $$declare a uuid;term uuid;begin
 if p_kind='site' and d->'schemaVersion'='2'::jsonb then
  if octet_length(d::text)>50000 then raise exception using errcode='22023',message='command_validation_failed';end if;
  perform app_private.validate_presentation_before_branding('site',(d-'logo')||'{"schemaVersion":1}'::jsonb);
  if not(d?'logo')then raise exception using errcode='22023',message='command_validation_failed';end if;
  if d->'logo'<>'null'::jsonb then
   if jsonb_typeof(d->'logo')is distinct from 'object' or not app_private.definition_keys(d->'logo',array['assetId','approvalId'])
    or coalesce(d->'logo'->>'assetId','')!~'^[0-9a-fA-F-]{36}$' or coalesce(d->'logo'->>'approvalId','')!~'^[0-9a-fA-F-]{36}$'
   then raise exception using errcode='22023',message='command_validation_failed';end if;
   a:=(d->'logo'->>'approvalId')::uuid;select p.term_id into term from public.publicity_reviews p join public.publicity_approvals x on x.publicity_review_id=p.id where x.id=a;
   if not coalesce(app_private.site_logo_valid(term,(d->'logo'->>'assetId')::uuid,a),false)then raise exception using errcode='22023',message='command_validation_failed';end if;
  end if;
 else perform app_private.validate_presentation_before_branding(p_kind,d);end if;
end$$;

-- Keep the original implementations private and delegate unchanged. Validate the
-- selected logo against the target term as well as its current exact approval.
alter function public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid)set schema app_private;
alter function app_private.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid)rename to save_presentation_before_branding;
create function public.save_presentation_draft(p_term_id uuid,p_kind text,p_target_kind text,p_target_id uuid,p_definition jsonb,p_base_version integer,p_expected_version integer,p_request_id uuid,p_rollback_version_id uuid default null)returns jsonb
language plpgsql security definer set search_path='' as $$begin
 perform app_private.readiness_lock(p_term_id);
 perform app_private.presentation_actor(p_term_id,p_kind,p_target_kind,p_target_id,true);
 if p_kind='site'and p_definition->'logo' is not null and p_definition->'logo'<>'null'::jsonb and not coalesce(app_private.site_logo_valid(p_term_id,(p_definition->'logo'->>'assetId')::uuid,(p_definition->'logo'->>'approvalId')::uuid),false)then raise exception using errcode='22023',message='command_validation_failed';end if;
 return app_private.save_presentation_before_branding(p_term_id,p_kind,p_target_kind,p_target_id,p_definition,p_base_version,p_expected_version,p_request_id,p_rollback_version_id);
end$$;
alter function public.publish_presentation_configuration(uuid,integer,text,text,uuid)set schema app_private;
alter function app_private.publish_presentation_configuration(uuid,integer,text,text,uuid)rename to publish_presentation_before_branding;
create function public.publish_presentation_configuration(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$declare d public.presentation_drafts;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.readiness_lock(d.term_id);
 perform app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id,true);
 if d.kind='site'and d.definition->'logo' is not null and d.definition->'logo'<>'null'::jsonb and not coalesce(app_private.site_logo_valid(d.term_id,(d.definition->'logo'->>'assetId')::uuid,(d.definition->'logo'->>'approvalId')::uuid),false)then raise exception using errcode='22023',message='command_validation_failed';end if;
 return app_private.publish_presentation_before_branding(p_draft_id,p_expected_version,p_review_hash,p_reason,p_request_id);
end$$;

create function public.read_site_logo_choices(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 perform app_private.presentation_actor(p_term_id,'site','term',p_term_id);
 return coalesce((select jsonb_agg(jsonb_build_object('assetId',asset,'approvalId',approval,'label',label,'conditions',conditions,'expiresAt',expires)order by label,asset)from(
  select a.id asset,x.id approval,a.filename label,x.conditions,x.expires_at expires
  from public.publicity_reviews p join public.publicity_approvals x on x.publicity_review_id=p.id join public.asset_manifest_items i on i.manifest_id=p.manifest_id join public.assets a on a.id=i.asset_id
  where p.term_id=p_term_id and public.can_access_work(p.request_id,'detail')and app_private.site_logo_valid(p_term_id,a.id,x.id)order by a.filename,a.id limit 100
 )choices),'[]');
end$$;
create function public.authorize_site_logo_download(p_term_id uuid,p_asset_id uuid,p_approval_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare config jsonb;a public.assets;begin
 config:=public.read_my_site_presentation(p_term_id);
 if config->'definition'->'logo' is distinct from jsonb_build_object('assetId',p_asset_id,'approvalId',p_approval_id)
  or not coalesce(app_private.site_logo_valid(p_term_id,p_asset_id,p_approval_id),false)then raise exception using errcode='42501',message='command_permission_denied';end if;
 select *into a from public.assets where id=p_asset_id;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind','upload','mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256);
end$$;
revoke all on function app_private.site_logo_valid(uuid,uuid,uuid),app_private.validate_presentation_before_branding(text,jsonb),app_private.validate_presentation(text,jsonb),app_private.save_presentation_before_branding(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),app_private.publish_presentation_before_branding(uuid,integer,text,text,uuid)from public,anon,authenticated,service_role;
revoke all on function public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid),public.read_site_logo_choices(uuid),public.authorize_site_logo_download(uuid,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid),public.read_site_logo_choices(uuid),public.authorize_site_logo_download(uuid,uuid,uuid)to authenticated;
