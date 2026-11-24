begin;

-- Custody approves a named recipient list, one final file, and one folder.
create table app_private.drive_copy_destinations (
  id uuid primary key default gen_random_uuid(),
  approval_id uuid not null references public.publicity_approvals(id),
  asset_id uuid not null references public.assets(id),
  folder_id text not null check(folder_id ~ '^[A-Za-z0-9_-]{1,180}$'),
  label text not null check(length(btrim(label)) between 1 and 160),
  classification text not null check(classification='restricted_publicity'),
  owner_email text not null check(owner_email ~ '^[^[:space:]@]+@student\.ateneo\.edu$'),
  reader_emails text[] not null default '{}' check(cardinality(reader_emails)<=20 and array_position(reader_emails,null) is null),
  approved_by uuid not null references public.term_memberships(id),
  expires_at timestamptz not null check(isfinite(expires_at)),
  revoked_at timestamptz check(isfinite(revoked_at)),
  unique(approval_id,asset_id,folder_id)
);
create table app_private.drive_copy_jobs (
  id uuid primary key default gen_random_uuid(),
  destination_id uuid not null references app_private.drive_copy_destinations(id),
  subject_id uuid not null references auth.users(id),
  file_id text not null unique check(file_id ~ '^[A-Za-z0-9_-]{1,180}$'),
  created_at timestamptz not null default statement_timestamp(),
  verified_at timestamptz,
  unique(destination_id,subject_id)
);
alter table app_private.drive_copy_destinations enable row level security;
alter table app_private.drive_copy_destinations force row level security;
alter table app_private.drive_copy_jobs enable row level security;
alter table app_private.drive_copy_jobs force row level security;
revoke all on app_private.drive_copy_destinations,app_private.drive_copy_jobs from public,anon,authenticated,service_role;

create function app_private.keep_drive_copy_destination() returns trigger language plpgsql set search_path='' as $$
begin
  if to_jsonb(old)-array['label','revoked_at']<>to_jsonb(new)-array['label','revoked_at']
    or (old.revoked_at is not null and new.revoked_at is distinct from old.revoked_at) then
    raise exception using errcode='42501',message='command_permission_denied';
  end if;
  return new;
end;
$$;
create trigger drive_copy_destination_binding before update on app_private.drive_copy_destinations
  for each row execute function app_private.keep_drive_copy_destination();
revoke all on function app_private.keep_drive_copy_destination() from public,anon,authenticated,service_role;

create function app_private.drive_copy_choices(p_term uuid,p_work uuid,p_asset uuid,p_subject uuid)
returns setof app_private.drive_copy_destinations language sql stable security definer set search_path='' as $$
  select d.* from app_private.drive_copy_destinations d
  join public.publicity_approvals a on a.id=d.approval_id
  join public.publicity_reviews v on v.id=a.publicity_review_id
  join public.asset_manifest_items item on item.manifest_id=v.manifest_id and item.asset_id=d.asset_id
  join public.assets f on f.id=item.asset_id
  join public.work_items w on w.id=v.request_id
  join public.terms term on term.id=w.term_id and term.state='active'
  join public.members owner on owner.id=w.owner_member_id and owner.auth_user_id=p_subject and owner.account_state='active'
  join public.term_memberships m on m.member_id=owner.id and m.term_id=w.term_id
  join public.term_memberships approver on approver.id=d.approved_by and approver.term_id=w.term_id
  where w.id=p_work and w.term_id=p_term and f.id=p_asset and f.origin_work_item_id=w.id
    and f.kind='upload' and f.state='finalized' and f.mime_type in ('application/pdf','image/jpeg','image/png')
    and m.membership_kind='core' and m.status='active' and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp()
    and d.revoked_at is null and d.expires_at>statement_timestamp()
    and owner.email=d.owner_email and approver.member_id<>owner.id
    and approver.membership_kind='core' and approver.status='active' and approver.joined_at<=statement_timestamp() and approver.ends_at>statement_timestamp()
    and app_private.privacy_custodian_live(w.term_id,approver.id)
    and app_private.publicity_approval_state(a)='approved'
    and app_private.publicity_finance_state(v) in ('not_required','authorized');
$$;
revoke all on function app_private.drive_copy_choices(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.read_drive_copy(p_term_id uuid,p_work_item_id uuid,p_asset_id uuid,p_destination_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  d app_private.drive_copy_destinations;
  f public.assets;
begin
  perform app_private.request_actor(p_term_id,true);
  if not public.can_access_work(p_work_item_id,'detail') then raise exception using errcode='42501',message='command_permission_denied'; end if;
  if p_destination_id is null then
    return jsonb_build_object('destinations',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'label',c.label) order by c.label,c.id)
      from app_private.drive_copy_choices(p_term_id,p_work_item_id,p_asset_id,auth.uid()) c),'[]'::jsonb));
  end if;
  select c.* into d from app_private.drive_copy_choices(p_term_id,p_work_item_id,p_asset_id,auth.uid()) c where c.id=p_destination_id;
  if not found then raise exception using errcode='42501',message='command_permission_denied'; end if;
  select * into strict f from public.assets where id=p_asset_id;
  return jsonb_build_object('folder',d.folder_id,'owner',d.owner_email,'readers',d.reader_emails,
    'name',f.filename,'mime',f.mime_type,'sha256',f.sha256,'size',f.size_bytes,'path',f.object_path);
end;
$$;
revoke all on function public.read_drive_copy(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_drive_copy(uuid,uuid,uuid,uuid) to authenticated;

create function public.drive_copy_job(p_term_id uuid,p_work_item_id uuid,p_asset_id uuid,p_destination_id uuid,p_subject_id uuid,
  p_file_id text default null,p_verified boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  d app_private.drive_copy_destinations;
  j app_private.drive_copy_jobs;
  w public.work_items;
begin
  select c.* into d from app_private.drive_copy_choices(p_term_id,p_work_item_id,p_asset_id,p_subject_id) c where c.id=p_destination_id;
  if not found then raise exception using errcode='42501',message='command_permission_denied'; end if;
  if p_verified then
    select * into j from app_private.drive_copy_jobs where destination_id=d.id and subject_id=p_subject_id
      and file_id=p_file_id for update;
    if not found then raise exception using errcode='40001',message='command_stale_version'; end if;
    if j.verified_at is null then
      update app_private.drive_copy_jobs set verified_at=statement_timestamp() where id=j.id returning * into j;
      select * into strict w from public.work_items where id=p_work_item_id;
      insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)
      select w.organization_id,w.term_id,p_subject_id,m.display_name,'copy_approved_drive_file',w.id,w.version,j.id,
        jsonb_build_object('destination',d.id,'classification',d.classification)
      from public.members m where m.id=w.owner_member_id;
    end if;
  elsif p_file_id is not null then
    insert into app_private.drive_copy_jobs(destination_id,subject_id,file_id) values(d.id,p_subject_id,p_file_id)
      on conflict(destination_id,subject_id) do nothing;
    select * into strict j from app_private.drive_copy_jobs where destination_id=d.id and subject_id=p_subject_id;
  else
    select * into j from app_private.drive_copy_jobs where destination_id=d.id and subject_id=p_subject_id;
    if not found then return '{}'::jsonb; end if;
  end if;
  return jsonb_build_object('id',j.id,'fileId',j.file_id,'verified',j.verified_at is not null);
end;
$$;
revoke all on function public.drive_copy_job(uuid,uuid,uuid,uuid,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.drive_copy_job(uuid,uuid,uuid,uuid,uuid,text,boolean) to service_role;

insert into app_private.disposition_sources(source_key,category,scope_kind,key_columns,query_sql,structure_hash,preserve)
values
('app_private.drive_copy_destinations','restricted','term',array['id'],
  'select app_private.disposition_key(''app_private.drive_copy_destinations'',array[d.id::text]) target_hash,
    ''restricted'' category,a.request_id root_id,app_private.retention_is_held($1,''restricted'',null::uuid,a.request_id) held,
    encode(sha256(convert_to(to_jsonb(d)::text,''UTF8'')),''hex'') state_hash
    from app_private.drive_copy_destinations d join public.publicity_approvals a on a.id=d.approval_id
    join public.work_items w on w.id=a.request_id where w.term_id=$1',
  app_private.disposition_structure('app_private.drive_copy_destinations'),false),
('app_private.drive_copy_jobs','restricted','term',array['id'],
  'select app_private.disposition_key(''app_private.drive_copy_jobs'',array[j.id::text]) target_hash,
    ''restricted'' category,a.request_id root_id,app_private.retention_is_held($1,''restricted'',null::uuid,a.request_id) held,
    encode(sha256(convert_to(to_jsonb(j)::text,''UTF8'')),''hex'') state_hash
    from app_private.drive_copy_jobs j join app_private.drive_copy_destinations d on d.id=j.destination_id
    join public.publicity_approvals a on a.id=d.approval_id join public.work_items w on w.id=a.request_id where w.term_id=$1',
  app_private.disposition_structure('app_private.drive_copy_jobs'),false);

commit;
