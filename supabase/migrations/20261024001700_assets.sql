begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('work-private','work-private',false,5242880,array['application/pdf','image/jpeg','image/png']) on conflict(id) do nothing;
do $$begin if not exists(select 1 from storage.buckets where id='work-private' and not public and file_size_limit=5242880 and allowed_mime_types=array['application/pdf','image/jpeg','image/png']) then raise exception 'Private work bucket configuration mismatch';end if;end$$;
do $$begin if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='storage' and c.relname='objects' and c.relrowsecurity)then raise exception 'Storage RLS must be enabled';end if;end$$;
-- Streaming through the file service is the only supported client path, including downloads/signing.
create policy work_private_client_deny on storage.objects as restrictive for all to anon,authenticated using(bucket_id<>'work-private') with check(bucket_id<>'work-private');
create table public.assets(
 id uuid primary key default gen_random_uuid(),origin_work_item_id uuid not null references public.work_items(id),
 kind text not null check(kind in ('upload','working_link')),classification text not null check(classification in ('ordinary','restricted')),
 filename text not null check(length(filename) between 1 and 160 and filename !~ '[\r\n]'),mime_type text,size_bytes integer,sha256 text,
 object_path text unique,source_url text,access_notes text,source_label text,source_snapshot jsonb,
 state text not null check(state in ('reserved','validated','finalized','working')),version integer not null default 1,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),
 updated_at timestamptz not null default statement_timestamp(),expires_at timestamptz,
 check((kind='upload' and mime_type is not null and size_bytes is not null and sha256 is not null and mime_type in ('application/pdf','image/jpeg','image/png') and size_bytes between 1 and 5242880 and sha256 ~ '^[0-9a-f]{64}$' and object_path is not null and source_url is null and state<>'working')
 or(kind='working_link' and state='working' and source_url is not null and object_path is null and size_bytes is null and sha256 is null)),
 unique(id,origin_work_item_id)
);
create table public.asset_links(asset_id uuid not null references public.assets(id),work_item_id uuid not null references public.work_items(id),created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),primary key(asset_id,work_item_id));
create table public.asset_manifests(id uuid primary key default gen_random_uuid(),work_item_id uuid not null references public.work_items(id),work_version integer not null,entries jsonb not null,sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'),size_bytes integer not null check(size_bytes between 1 and 20971520),created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp());
create table public.asset_manifest_items(manifest_id uuid not null references public.asset_manifests(id),asset_id uuid not null references public.assets(id),primary key(manifest_id,asset_id));
create index assets_origin on public.assets(origin_work_item_id,created_at,id);
create index asset_links_work on public.asset_links(work_item_id,asset_id);
create index asset_manifests_work on public.asset_manifests(work_item_id,created_at,id);
create index asset_manifest_items_asset on public.asset_manifest_items(asset_id,manifest_id);
alter table public.assets enable row level security;
alter table public.assets force row level security;
alter table public.asset_links enable row level security;
alter table public.asset_links force row level security;
alter table public.asset_manifests enable row level security;
alter table public.asset_manifests force row level security;
alter table public.asset_manifest_items enable row level security;
alter table public.asset_manifest_items force row level security;
revoke all on public.assets,public.asset_links,public.asset_manifests,public.asset_manifest_items from public,anon,authenticated,service_role;
grant select on public.assets,public.asset_links,public.asset_manifests,public.asset_manifest_items to authenticated;
create policy assets_read on public.assets for select to authenticated using(public.can_access_work(origin_work_item_id,'detail') and (state<>'reserved' or created_by=auth.uid()));
create policy asset_links_read on public.asset_links for select to authenticated using(public.can_access_work(work_item_id,'detail') and exists(select 1 from public.assets a where a.id=asset_id and public.can_access_work(a.origin_work_item_id,'detail')));
-- Use a definer helper to avoid recursive manifests/items policies.
create function public.can_read_manifest(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.asset_manifests m where m.id=p_id and public.can_access_work(m.work_item_id,'detail') and not exists(select 1 from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=m.id and not public.can_access_work(a.origin_work_item_id,'detail')))$$;
create policy asset_manifests_read on public.asset_manifests for select to authenticated using(public.can_read_manifest(id));
create policy asset_manifest_items_read on public.asset_manifest_items for select to authenticated using(public.can_read_manifest(manifest_id));
create trigger asset_manifests_immutable before update or delete on public.asset_manifests for each row execute function app_private.deny_deliverable_history();
create trigger asset_manifest_items_immutable before update or delete on public.asset_manifest_items for each row execute function app_private.deny_deliverable_history();
create function app_private.keep_final_asset() returns trigger language plpgsql set search_path='' as $$begin if old.state='finalized' then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger final_asset_immutable before update or delete on public.assets for each row execute function app_private.keep_final_asset();
create function app_private.file_work(p_id uuid,p_version integer) returns public.work_items language plpgsql set search_path='' as $$declare w public.work_items;begin
 select * into w from public.work_items where id=p_id for update;
 if not found or w.kind not in ('task','deliverable') or not public.can_access_work(w.id,'edit') or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 if w.version is distinct from p_version then raise exception using errcode='40001',message='command_stale_version';end if;return w;
end$$;
create function public.reserve_upload(p_work_item_id uuid,p_name text,p_mime text,p_size integer,p_sha256 text,p_source_id uuid,p_source_version integer,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;s public.assets;payload jsonb;result jsonb;path text;begin
 select * into w from public.work_items where id=p_work_item_id;
 if not public.can_access_work(w.id,'edit') or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_name,p_mime,p_size,p_sha256,p_source_id,p_source_version,p_expected_version);result:=app_private.begin_work_command('reserve_upload',p_request_id,payload);if result is not null then return result;end if;
 w:=app_private.file_work(p_work_item_id,p_expected_version);
 if p_name is null or length(p_name) not between 1 and 160 or p_name ~ '[\r\n]' or p_mime is null or p_mime not in ('application/pdf','image/jpeg','image/png') or p_size is null or p_size not between 1 and 5242880 or p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 if (select coalesce(sum(size_bytes),0) from public.assets where origin_work_item_id=w.id and (state='validated' or(state='reserved' and expires_at>statement_timestamp())))+p_size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if p_source_id is not null then select * into s from public.assets where id=p_source_id and kind='working_link' and origin_work_item_id=w.id and version=p_source_version;if not found then raise exception using errcode='40001',message='command_stale_version';end if;end if;
 path:=gen_random_uuid()::text||'/'||gen_random_uuid()::text||case p_mime when 'application/pdf' then '.pdf' when 'image/png' then '.png' else '.jpg' end;
 insert into public.assets(origin_work_item_id,kind,classification,filename,mime_type,size_bytes,sha256,object_path,state,created_by,expires_at,source_snapshot)
 values(w.id,'upload',w.classification,p_name,p_mime,p_size,p_sha256,path,'reserved',auth.uid(),statement_timestamp()+interval'20 minutes',case when s.id is not null then jsonb_build_object('assetId',s.id,'version',s.version,'url',s.source_url,'label',s.source_label,'accessNotes',s.access_notes) end) returning * into a;
 insert into public.asset_links(asset_id,work_item_id,created_by) values(a.id,w.id,auth.uid());
 return app_private.finish_work_command(w,'reserve_upload',p_request_id,payload,jsonb_build_object('assetId',a.id,'path',path,'version',1),'["asset_reservation"]');
end$$;
-- Trusted byte validator only; authenticated subjects cannot manufacture validation receipts.
create function public.seal_upload(p_asset_id uuid,p_sha256 text,p_size integer,p_mime text) returns jsonb language plpgsql security definer set search_path='' as $$declare a public.assets;begin
 select * into a from public.assets where id=p_asset_id for update;
 if not found or a.kind<>'upload' or a.sha256 is distinct from p_sha256 or a.size_bytes is distinct from p_size or a.mime_type is distinct from p_mime then raise exception using errcode='22023',message='command_validation_failed';end if;
 if a.state='reserved' then if a.expires_at<=statement_timestamp() then raise exception using errcode='55000',message='command_dependency_blocked';end if;update public.assets set state='validated',version=version+1,updated_at=statement_timestamp() where id=a.id returning * into a;end if;
 return jsonb_build_object('assetId',a.id,'version',a.version,'state',a.state);
end$$;
create function public.finalize_upload(p_work_item_id uuid,p_asset_ids uuid[],p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;payload jsonb;result jsonb;entries jsonb;size integer;mid uuid;begin
 select * into w from public.work_items where id=p_work_item_id;
 if not public.can_access_work(w.id,'edit') or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_ids,p_expected_version);result:=app_private.begin_work_command('finalize_upload',p_request_id,payload);if result is not null then return result;end if;
 w:=app_private.file_work(p_work_item_id,p_expected_version);
 if p_asset_ids is null or cardinality(p_asset_ids) not between 1 and 20 or array_ndims(p_asset_ids)>1 or cardinality(p_asset_ids)<>(select count(distinct x) from unnest(p_asset_ids)x) then raise exception using errcode='22023',message='command_validation_failed';end if;
 for a in select * from public.assets where id=any(p_asset_ids) order by id for update loop
 if a.kind<>'upload' or a.state not in ('validated','finalized') or a.origin_work_item_id<>w.id then raise exception using errcode='42501',message='command_permission_denied';end if;end loop;
 if (select count(*) from public.assets where id=any(p_asset_ids))<>cardinality(p_asset_ids) then raise exception using errcode='42501',message='command_permission_denied';end if;
 select sum(size_bytes)::integer,jsonb_agg(jsonb_build_object('assetId',id,'sha256',sha256,'size',size_bytes,'mime',mime_type,'classification',classification,'source',source_snapshot)order by id) into size,entries from public.assets where id=any(p_asset_ids);
 if size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
 insert into public.asset_manifests(work_item_id,work_version,entries,sha256,size_bytes,created_by) values(w.id,w.version,entries,encode(sha256(convert_to(entries::text,'UTF8')),'hex'),size,auth.uid()) returning id into mid;
 insert into public.asset_manifest_items(manifest_id,asset_id) select mid,unnest(p_asset_ids);
 update public.assets set state='finalized',version=version+1,updated_at=statement_timestamp() where id=any(p_asset_ids) and state='validated';
 return app_private.finish_work_command(w,'finalize_upload',p_request_id,payload,jsonb_build_object('manifestId',mid,'sha256',encode(sha256(convert_to(entries::text,'UTF8')),'hex')),'["immutable_manifest"]');
end$$;
create function public.save_working_link(p_work_item_id uuid,p_asset_id uuid,p_url text,p_name text,p_notes text,p_label text,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;result jsonb;payload jsonb;begin
 select * into w from public.work_items where id=p_work_item_id for update;
 if not public.can_access_work(w.id,'edit') or public.current_term_membership(w.term_id) is null or w.archived_at is not null or w.kind not in('task','deliverable') or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
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
create function public.attach_asset(p_work_item_id uuid,p_asset_id uuid,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare w public.work_items;a public.assets;payload jsonb;result jsonb;begin
 select * into w from public.work_items where id=p_work_item_id;select * into a from public.assets where id=p_asset_id;
 if not found or not public.can_access_work(w.id,'edit') or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') or a.state='reserved' or not public.can_access_work(a.origin_work_item_id,'detail') or not exists(select 1 from public.work_items s where s.id=a.origin_work_item_id and s.organization_id=w.organization_id and s.term_id=w.term_id) then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(w.id,a.id,p_expected_version);result:=app_private.begin_work_command('attach_asset',p_request_id,payload);if result is not null then return result;end if;
 w:=app_private.file_work(p_work_item_id,p_expected_version);insert into public.asset_links(asset_id,work_item_id,created_by)values(a.id,w.id,auth.uid()) on conflict do nothing;
 return app_private.finish_work_command(w,'attach_asset',p_request_id,payload,jsonb_build_object('assetId',a.id),'["asset_link"]');
end$$;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare w public.work_items;a public.assets;result jsonb;payload jsonb;begin
 select * into w from public.work_items where id=p_work_item_id;select * into a from public.assets where id=p_asset_id;
 if auth.uid() is null or not public.can_access_work(w.id,'detail') or not public.can_access_work(a.origin_work_item_id,'detail') or not exists(select 1 from public.asset_links where work_item_id=w.id and asset_id=a.id) or a.state not in ('validated','finalized','working') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(w.id,a.id);result:=app_private.begin_work_command('authorize_asset_download',p_request_id,payload);
 if result is null then insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff) values(w.organization_id,w.term_id,auth.uid(),'Authenticated file reader',case when a.kind='working_link' then 'asset_open' else 'asset_download' end,w.id,w.version,p_request_id,jsonb_build_object('fields',jsonb_build_array('asset_access'),'assetId',a.id));
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'authorize_asset_download',p_request_id,w.organization_id,w.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),'{}');end if;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind',a.kind,'mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256,'url',a.source_url);
end$$;
create function public.read_files(p_work_item_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('workVersion',w.version,'canEdit',public.current_term_membership(w.term_id)is not null and public.can_access_work(w.id,'edit') and w.archived_at is null and exists(select 1 from public.terms where id=w.term_id and state='active'),
 'assets',coalesce((select jsonb_agg(to_jsonb(a)-array['object_path','created_by','expires_at'] order by a.created_at,a.id)from public.asset_links l join public.assets a on a.id=l.asset_id where l.work_item_id=w.id and public.can_access_work(a.origin_work_item_id,'detail') and a.state<>'reserved'),'[]'),
 'manifests',coalesce((select jsonb_agg(to_jsonb(m)-'created_by' order by m.created_at,m.id)from public.asset_manifests m where m.work_item_id=w.id and public.can_read_manifest(m.id)),'[]'))
 from public.work_items w where w.id=p_work_item_id and w.kind in('task','deliverable') and public.can_access_work(w.id,'detail')
$$;
revoke all on function app_private.file_work(uuid,integer),app_private.keep_final_asset() from public,anon,authenticated,service_role;
revoke all on function public.can_read_manifest(uuid),public.reserve_upload(uuid,text,text,integer,text,uuid,integer,integer,uuid),public.seal_upload(uuid,text,integer,text),public.finalize_upload(uuid,uuid[],integer,uuid),public.save_working_link(uuid,uuid,text,text,text,text,integer,uuid),public.attach_asset(uuid,uuid,integer,uuid),public.authorize_asset_download(uuid,uuid,uuid),public.read_files(uuid) from public,anon,authenticated,service_role;
grant execute on function public.seal_upload(uuid,text,integer,text) to service_role;
grant execute on function public.can_read_manifest(uuid),public.reserve_upload(uuid,text,text,integer,text,uuid,integer,integer,uuid),public.finalize_upload(uuid,uuid[],integer,uuid),public.save_working_link(uuid,uuid,text,text,text,text,integer,uuid),public.attach_asset(uuid,uuid,integer,uuid),public.authorize_asset_download(uuid,uuid,uuid),public.read_files(uuid) to authenticated;
commit;
