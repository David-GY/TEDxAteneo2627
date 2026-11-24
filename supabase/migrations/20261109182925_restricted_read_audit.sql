-- P46 authorized content reads: wrap the existing, unchanged authorization and
-- projection implementations. This does not implement any missing export.
create table public.restricted_read_endpoints(
 endpoint text primary key check(endpoint~'^(read_|preview_|search_|export_|list_)[a-z0-9_]+$'or endpoint in('mention_candidates','authorize_asset_download','authorize_site_logo_download')),
 argument_types text not null,registered_at timestamptz not null default statement_timestamp()
);
create table public.restricted_access_events(
 id uuid primary key default gen_random_uuid(),endpoint text not null references public.restricted_read_endpoints(endpoint),
 actor_id uuid references auth.users(id),term_id uuid,object_id uuid,
 authority_assignments uuid[]not null default '{}',outcome text not null check(outcome in('returned','empty')),
 correlation_id uuid not null default gen_random_uuid(),occurred_at timestamptz not null default statement_timestamp()
);
create index restricted_access_scope on public.restricted_access_events(term_id,occurred_at,id);
alter table public.restricted_read_endpoints enable row level security;alter table public.restricted_read_endpoints force row level security;
alter table public.restricted_access_events enable row level security;alter table public.restricted_access_events force row level security;
revoke all on public.restricted_read_endpoints,public.restricted_access_events from public,anon,authenticated,service_role;
create trigger immutable_restricted_access_events before update or delete on public.restricted_access_events for each row execute function app_private.request_history_guard();

create function app_private.record_content_read(p_endpoint text,p_term uuid,p_object uuid,p_returned boolean)returns void language plpgsql security definer set search_path='' as $$declare scope uuid:=p_term;assignments uuid[];begin
 -- Object-scoped calls may not accept a term. Resolve only registered opaque IDs;
 -- never copy arbitrary function arguments, queries, bodies or tokens into logs.
 if scope is null and p_object is not null then
  select term_id into scope from public.work_items where id=p_object;
  if scope is null then select w.term_id into scope from public.comments c join public.work_items w on w.id=c.work_item_id where c.id=p_object;end if;
  if scope is null then select term_id into scope from public.request_types where id=p_object;end if;
  if scope is null then select t.term_id into scope from public.configuration_drafts d join public.request_types t on t.id=d.request_type_id where d.id=p_object;end if;
  if scope is null then select term_id into scope from public.presentation_drafts where id=p_object;end if;
  if scope is null then select term_id into scope from public.handoffs where id=p_object;end if;
  if scope is null then select term_id into scope from public.synergy_agreements where id=p_object;end if;
  if scope is null then select term_id into scope from app_private.task_import_sessions where id=p_object;end if;
  if scope is null then select term_id into scope from app_private.roster_import_sessions where id=p_object;end if;
 end if;
 select coalesce(array_agg(a.id order by a.id),'{}')into assignments from app_private.effective_role_assignments a where a.term_id=scope and a.term_membership_id=public.current_term_membership(scope);
 insert into public.restricted_access_events(endpoint,actor_id,term_id,object_id,authority_assignments,outcome)values(p_endpoint,auth.uid(),scope,p_object,assignments,case when p_returned then'returned'else'empty'end);
end$$;
revoke all on function app_private.record_content_read(text,uuid,uuid,boolean)from public,anon,authenticated,service_role;

do $$declare f record;decl text;signature text;arguments text;delegate text;term_arg text;object_arg text;allow_auth boolean;allow_service boolean;begin
 for f in select p.oid,p.proname,p.proargnames,p.pronargs,pg_get_function_identity_arguments(p.oid)identity_args,pg_get_function_arguments(p.oid)declaration from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'and p.prorettype='jsonb'::regtype and not p.proretset and(p.proname~'^(read_|preview_|search_|export_|list_)'or p.proname in('mention_candidates','authorize_asset_download','authorize_site_logo_download'))order by p.proname loop
  if f.proargnames is null then raise exception 'Content RPC requires named arguments: %',f.proname;end if;
  select string_agg(format('%I',a),','order by ord)into arguments from unnest(f.proargnames)with ordinality x(a,ord)where ord<=f.pronargs;
  term_arg:=case when'p_term_id'=any(f.proargnames)then'p_term_id'else'null::uuid'end;
  object_arg:='null::uuid';
  foreach decl in array array['p_work_item_id','p_successor_id','p_draft_id','p_type_id','p_comment_id','p_handoff_id','p_agreement_id','p_privacy_request_id','p_announcement_id','p_asset_id']loop
   if decl=any(f.proargnames)then object_arg:=format('%I',decl);exit;end if;
  end loop;
  allow_auth:=has_function_privilege('authenticated',f.oid,'execute');allow_service:=has_function_privilege('service_role',f.oid,'execute');
  if has_function_privilege('anon',f.oid,'execute')then raise exception 'Anonymous content RPC needs explicit privacy review: %',f.proname;end if;
  delegate:='p46_read_'||f.proname;signature:=format('public.%I(%s)',f.proname,f.identity_args);
  execute format('alter function %s set schema app_private',signature);
  execute format('alter function app_private.%I(%s)rename to %I',f.proname,f.identity_args,delegate);
  execute format('revoke all on function app_private.%I(%s)from public,anon,authenticated,service_role',delegate,f.identity_args);
  execute format('create function public.%I(%s)returns jsonb language plpgsql volatile security definer set search_path='''' as $wrapper$declare result jsonb;begin result:=app_private.%I(%s);perform app_private.record_content_read(%L,%s,%s,result is not null);return result;end$wrapper$',f.proname,f.declaration,delegate,arguments,f.proname,term_arg,object_arg);
  execute format('revoke all on function %s from public,anon,authenticated,service_role',signature);
  if allow_auth then execute format('grant execute on function %s to authenticated',signature);end if;
  if allow_service then execute format('grant execute on function %s to service_role',signature);end if;
  insert into public.restricted_read_endpoints(endpoint,argument_types)values(f.proname,f.identity_args);
 end loop;
end$$;
-- Routine clients must use the audited projections. Definer RPCs and trusted file
-- authorization keep their existing object/scope checks. No RLS is weakened.
revoke select on public.private_profiles,public.guest_contact_profiles,public.assets,public.asset_manifests,public.asset_manifest_items,public.restricted_request_payloads,public.request_drafts,public.request_revisions from public,anon,authenticated,service_role;
-- Close typed work bodies, history, counts/joins and column-level grants too.
-- Ordinary directory/configuration labels keep their existing scoped policies.
do $$declare t text;cols text;begin foreach t in array array['announcements','asset_links','audit_events','comment_evidence','comment_revisions','comments','deliverable_revisions','deliverable_units','deliverables','record_grants','requests','task_collaborators','task_revisions','tasks','work_items','contributions']loop
 select string_agg(format('%I',a.attname),',')into cols from pg_attribute a where a.attrelid=('public.'||t)::regclass and a.attnum>0 and not a.attisdropped;
 execute format('revoke select on public.%I from public,anon,authenticated,service_role',t);
 execute format('revoke select(%s)on public.%I from public,anon,authenticated,service_role',cols,t);
end loop;end$$;
