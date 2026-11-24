begin;
-- A shared file keeps the strongest applicable compartment, independently of
-- its original ordinary record. No download/read permission is added here.
create function app_private.turnover_asset_category(p_asset uuid)returns text language sql stable set search_path='' as $$
 select case when exists(select 1 from public.work_items w where w.id in(
  select origin_work_item_id from public.assets where id=p_asset union select work_item_id from public.asset_links where asset_id=p_asset
  union select m.work_item_id from public.asset_manifest_items i join public.asset_manifests m on m.id=i.manifest_id where i.asset_id=p_asset)
  and app_private.retention_work_category(w.id)='finance')then'finance'
 when exists(select 1 from public.assets where id=p_asset and classification='restricted')or exists(select 1 from public.work_items w where w.id in(
  select origin_work_item_id from public.assets where id=p_asset union select work_item_id from public.asset_links where asset_id=p_asset
  union select m.work_item_id from public.asset_manifest_items i join public.asset_manifests m on m.id=i.manifest_id where i.asset_id=p_asset)
  and app_private.retention_work_category(w.id)='restricted')then'restricted'else'operational'end
$$;
create function app_private.turnover_manifest_category(p_manifest uuid)returns text language sql stable set search_path='' as $$
 select case when app_private.retention_work_category(m.work_item_id)='finance'or exists(select 1 from public.asset_manifest_items i where i.manifest_id=m.id and app_private.turnover_asset_category(i.asset_id)='finance')then'finance'
 when app_private.retention_work_category(m.work_item_id)='restricted'or exists(select 1 from public.asset_manifest_items i where i.manifest_id=m.id and app_private.turnover_asset_category(i.asset_id)='restricted')then'restricted'else'operational'end
 from public.asset_manifests m where m.id=p_manifest
$$;
revoke all on function app_private.turnover_asset_category(uuid),app_private.turnover_manifest_category(uuid)from public,anon,authenticated,service_role;
do $$begin
 if not app_private.disposition_catalog_current()then raise exception using errcode='55000',message='privacy_disposition_catalog_changed';end if;
end $$;
update app_private.disposition_sources set query_sql=
 'select app_private.disposition_key(''public.assets'',array[a.id::text])target_hash,app_private.turnover_asset_category(a.id)category,a.origin_work_item_id root_id,
 app_private.retention_is_held($1,app_private.turnover_asset_category(a.id),a.id,a.origin_work_item_id)held,encode(sha256(convert_to(to_jsonb(a)::text,''UTF8'')),''hex'')state_hash
 from public.assets a join public.work_items w on w.id=a.origin_work_item_id where w.term_id=$1'where source_key='public.assets';
update app_private.disposition_sources set query_sql=
 'select app_private.disposition_key(''public.asset_links'',array[l.asset_id::text,l.work_item_id::text])target_hash,app_private.turnover_asset_category(l.asset_id)category,l.work_item_id root_id,
 app_private.retention_is_held($1,app_private.turnover_asset_category(l.asset_id),l.asset_id,l.work_item_id)held,encode(sha256(convert_to(to_jsonb(l)::text,''UTF8'')),''hex'')state_hash
 from public.asset_links l join public.work_items w on w.id=l.work_item_id where w.term_id=$1'where source_key='public.asset_links';
update app_private.disposition_sources set query_sql=
 'select app_private.disposition_key(''public.asset_manifests'',array[m.id::text])target_hash,app_private.turnover_manifest_category(m.id)category,m.work_item_id root_id,
 (app_private.retention_is_held($1,app_private.turnover_manifest_category(m.id),m.id,m.work_item_id)or app_private.retention_is_held($1,app_private.retention_work_category(w.id),m.id,m.work_item_id))held,encode(sha256(convert_to(to_jsonb(m)::text,''UTF8'')),''hex'')state_hash
 from public.asset_manifests m join public.work_items w on w.id=m.work_item_id where w.term_id=$1'where source_key='public.asset_manifests';
update app_private.disposition_sources set query_sql=
 'select app_private.disposition_key(''public.asset_manifest_items'',array[i.manifest_id::text,i.asset_id::text])target_hash,app_private.turnover_manifest_category(i.manifest_id)category,m.work_item_id root_id,
 (app_private.retention_is_held($1,app_private.turnover_manifest_category(i.manifest_id),i.asset_id,m.work_item_id)or app_private.retention_is_held($1,app_private.retention_work_category(w.id),i.asset_id,m.work_item_id))held,encode(sha256(convert_to(to_jsonb(i)::text,''UTF8'')),''hex'')state_hash
 from public.asset_manifest_items i join public.asset_manifests m on m.id=i.manifest_id join public.work_items w on w.id=m.work_item_id where w.term_id=$1'where source_key='public.asset_manifest_items';
-- Category/root/owner changes are security-significant even when row bytes did
-- not change. Old generations must be replanned rather than silently reused.
create or replace function app_private.turnover_fingerprint(p_term uuid)returns text language sql stable set search_path='' as $$
 select encode(sha256(convert_to(coalesce(jsonb_agg(jsonb_build_array(source_key,target_hash,category,root_id,state_hash,held)order by source_key,target_hash),'[]'::jsonb)::text,'UTF8')),'hex')
 from app_private.disposition_inventory(p_term)where category<>'security'and source_key<>'public.privacy_events'and source_key not like'app_private.turnover_%'
$$;
create or replace function app_private.turnover_entry_fingerprint(p_case uuid)returns text language sql stable set search_path='' as $$
 select encode(sha256(convert_to(coalesce(jsonb_agg(jsonb_build_array(source_key,target_hash,category,root_id,state_hash,held,disposition,review_on,owner_id)order by source_key,target_hash),'[]'::jsonb)::text,'UTF8')),'hex')
 from app_private.turnover_entries where case_id=p_case
$$;
commit;
