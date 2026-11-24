begin;

-- A requester can recover only their own reservation and manifest for this editable draft.
create function public.drive_rendition_stage(
  p_term_id uuid, p_work_item_id uuid, p_version integer default null,
  p_reserve_key uuid default null, p_finish_key uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  member public.term_memberships;
  work public.work_items;
  asset public.assets;
  manifest uuid;
  result jsonb;
begin
  member:=app_private.request_actor(p_term_id,true);
  select w.* into work
  from public.work_items w
  join public.requests r on r.work_item_id=w.id
  join public.request_types t on t.id=r.request_type_id
  where w.id=p_work_item_id and w.term_id=p_term_id and w.owner_member_id=member.member_id
    and w.archived_at is null and r.request_state in ('draft','revision_draft')
    and r.payload_classification='restricted' and t.governed_kind='mcd'
    and public.can_access_work(w.id,'edit');
  if not found then raise exception using errcode='42501',message='command_permission_denied'; end if;
  if p_version is not null and work.version<>p_version then raise exception using errcode='40001',message='command_stale_version'; end if;
  result:=jsonb_build_object('version',work.version);
  if p_reserve_key is null then return result; end if;

  select a.* into asset
  from public.idempotency_keys k
  join public.assets a on a.id=(k.result_reference->>'assetId')::uuid
  where k.actor_id=auth.uid() and k.term_id=p_term_id and k.command='reserve_upload' and k.client_key=p_reserve_key
    and a.origin_work_item_id=work.id and a.created_by=auth.uid() and a.kind='upload' and a.mime_type='application/pdf';
  if not found then return result; end if;
  if asset.state='reserved' and asset.expires_at<=statement_timestamp() then
    raise exception using errcode='55000',message='command_dependency_blocked';
  end if;
  select m.id into manifest
  from public.idempotency_keys k
  join public.asset_manifests m on m.id=(k.result_reference->>'manifestId')::uuid
  join public.asset_manifest_items item on item.manifest_id=m.id and item.asset_id=asset.id
  where k.actor_id=auth.uid() and k.term_id=p_term_id and k.command='finalize_upload' and k.client_key=p_finish_key
    and m.work_item_id=work.id and m.work_version=work.version and jsonb_array_length(m.entries)=1;
  return jsonb_strip_nulls(result||jsonb_build_object('asset',jsonb_build_object(
    'id',asset.id,'path',asset.object_path,'size',asset.size_bytes,'sha256',asset.sha256,'state',asset.state),'manifestId',manifest));
end;
$$;
revoke all on function public.drive_rendition_stage(uuid,uuid,integer,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.drive_rendition_stage(uuid,uuid,integer,uuid,uuid) to authenticated;

commit;
