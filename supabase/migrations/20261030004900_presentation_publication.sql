-- P40: closed presentation definitions reuse P35 private drafts and P38 neutral audit spines.
-- These definitions never participate in permission, query, work status or file authorization.
create table public.presentation_controls(
 term_id uuid not null references public.terms(id),kind text not null check(kind in('site','layout')),
 target_kind text not null check(target_kind in('term','unit','role')),target_id uuid not null,
 work_item_id uuid not null unique references public.announcements(work_item_id),
 primary key(term_id,kind,target_kind,target_id),check(kind='layout'or target_kind='term')
);
create table public.presentation_drafts(
 id uuid primary key default gen_random_uuid(),term_id uuid not null references public.terms(id),
 kind text not null check(kind in('site','layout')),target_kind text not null check(target_kind in('term','unit','role')),target_id uuid not null,
 actor_id uuid not null references auth.users(id),version integer not null check(version>0),base_version integer not null check(base_version>=0),
 definition jsonb not null check(jsonb_typeof(definition)='object'and octet_length(definition::text)<=50000),
 rollback_version_id uuid,published_version_id uuid,updated_at timestamptz not null default statement_timestamp(),
 unique(term_id,kind,target_kind,target_id,actor_id),check(kind='layout'or target_kind='term')
);
create table public.presentation_versions(
 id uuid primary key default gen_random_uuid(),control_id uuid not null references public.presentation_controls(work_item_id),
 version integer not null check(version>0),definition jsonb not null,previous_version integer not null,
 rollback_version_id uuid references public.presentation_versions(id),actor_id uuid not null references auth.users(id),
 reason text not null check(length(btrim(reason))between 1 and 2000),published_at timestamptz not null default statement_timestamp(),unique(control_id,version)
);
alter table public.presentation_drafts add foreign key(rollback_version_id)references public.presentation_versions(id),
 add foreign key(published_version_id)references public.presentation_versions(id);
do $$declare t text;begin foreach t in array array['presentation_controls','presentation_drafts','presentation_versions']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
end loop;end$$;
create trigger immutable_presentation_control before update or delete on public.presentation_controls for each row execute function app_private.request_history_guard();
create trigger immutable_presentation_version before update or delete on public.presentation_versions for each row execute function app_private.request_history_guard();

create function app_private.presentation_actor(p_term uuid,p_kind text,p_target_kind text,p_target uuid,p_write boolean default false)returns public.term_memberships
language plpgsql stable security definer set search_path='' as $$declare m public.term_memberships;begin
 m:=app_private.request_actor(p_term,p_write);
 if p_kind is null or p_kind not in('site','layout')or p_target_kind is null or p_target_kind not in('term','unit','role')or p_target is null
  or(p_kind='site'and p_target_kind<>'term')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if(p_target_kind='term'and p_target<>p_term)
  or(p_target_kind='unit'and not exists(select 1 from public.org_units where id=p_target and term_id=p_term and archived_at is null))
  or(p_target_kind='role'and not exists(select 1 from public.roles where id=p_target and term_id=p_term and state='active'))
 then raise exception using errcode='42501',message='command_permission_denied';end if;
 if not public.has_capability(p_term,'admin.configure')and not(p_kind='layout'and p_target_kind='unit'
  and public.has_capability(p_term,'committee.manage',p_target)
  and exists(select 1 from public.unit_memberships where term_membership_id=m.id and unit_id=p_target and status='active'
   and deployment_type='head'and effective_from<=statement_timestamp()and effective_to>statement_timestamp()))
 then raise exception using errcode='42501',message='command_permission_denied';end if;
 return m;
end$$;

create function app_private.presentation_text(v jsonb,n integer)returns boolean language sql immutable set search_path='' as $$
 select coalesce(jsonb_typeof(v)='string'and length(v#>>'{}')between 1 and n and length(btrim(v#>>'{}'))>0 and(v#>>'{}')!~'[[:cntrl:]<>]',false)
$$;
create function app_private.validate_presentation(p_kind text,d jsonb)returns void language plpgsql immutable set search_path='' as $$
declare w jsonb;b jsonb;k text;v jsonb;keys text[]:=array['overview','deliverables','tasks','working','requests','calendar','resources','people'];begin
 if jsonb_typeof(d)is distinct from 'object'or octet_length(d::text)>50000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_kind='layout'then
  if not app_private.definition_keys(d,array['version','widgets'])or d->'version'is distinct from '1'::jsonb or jsonb_typeof(d->'widgets')is distinct from 'array'then raise exception using errcode='22023',message='command_validation_failed';end if;
  if jsonb_array_length(d->'widgets')>7 then raise exception using errcode='22023',message='command_validation_failed';end if;
  for w in select value from jsonb_array_elements(d->'widgets')loop
   if not coalesce(app_private.definition_keys(w,array['id','size']),false)or jsonb_typeof(w->'id')is distinct from 'string'or jsonb_typeof(w->'size')is distinct from 'string'
    or w->>'id'not in('waiting','tasks','deliverables','working','reviews','calendar','resources')or w->>'size'not in('wide','compact')
   then raise exception using errcode='22023',message='command_validation_failed';end if;
  end loop;
  if(select count(distinct value->>'id')from jsonb_array_elements(d->'widgets'))<>jsonb_array_length(d->'widgets')then raise exception using errcode='22023',message='command_validation_failed';end if;
 elsif p_kind='site'then
  if not app_private.definition_keys(d,array['schemaVersion','labels','order','accent','blocks'])or d->'schemaVersion'is distinct from '1'::jsonb
   or jsonb_typeof(d->'labels')is distinct from 'object'or jsonb_typeof(d->'order')is distinct from 'array'or jsonb_typeof(d->'blocks')is distinct from 'array'
   or d->>'accent'not in('#b82320','#252624')or d->>'accent'is null then raise exception using errcode='22023',message='command_validation_failed';end if;
  for k,v in select *from jsonb_each(d->'labels')loop
   if not(k=any(keys))or not app_private.presentation_text(v,80)then raise exception using errcode='22023',message='command_validation_failed';end if;
  end loop;
  if jsonb_array_length(d->'order')>8 or exists(select 1 from jsonb_array_elements(d->'order')x where jsonb_typeof(x)<>'string'or not(x#>>'{}'=any(keys)))
   or(select count(distinct value)from jsonb_array_elements(d->'order'))<>jsonb_array_length(d->'order')or jsonb_array_length(d->'blocks')>12
  then raise exception using errcode='22023',message='command_validation_failed';end if;
  for b in select value from jsonb_array_elements(d->'blocks')loop
   if not coalesce(app_private.definition_keys(b,array['id','kind','title','body','href']),false)or jsonb_typeof(b->'id')is distinct from 'string'or(b->>'id')!~'^[a-z][a-z0-9_]{0,59}$'
    or b->>'kind'is null or b->>'kind'not in('text','link','card')or not app_private.presentation_text(b->'title',200)or not app_private.presentation_text(b->'body',2000)
    or(b->>'kind'='text'and b?'href')or(b->>'kind'<>'text'and(b->>'href'is null or b->>'href'not in('/','/deliverables','/tasks','/working-together','/requests','/calendar','/resources','/people')))
   then raise exception using errcode='22023',message='command_validation_failed';end if;
  end loop;
  if(select count(distinct value->>'id')from jsonb_array_elements(d->'blocks'))<>jsonb_array_length(d->'blocks')then raise exception using errcode='22023',message='command_validation_failed';end if;
 else raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;

create function public.read_presentation_configuration(p_term_id uuid,p_kind text,p_target_kind text,p_target_id uuid,p_before integer default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$declare c uuid;current_version integer;begin
 perform app_private.presentation_actor(p_term_id,p_kind,p_target_kind,p_target_id);
 select work_item_id into c from public.presentation_controls where term_id=p_term_id and kind=p_kind and target_kind=p_target_kind and target_id=p_target_id;
 select coalesce(max(version),0)into current_version from public.presentation_versions where control_id=c;
 return jsonb_build_object('version',current_version,'definition',(select definition from public.presentation_versions where control_id=c and version=current_version),
 'drafts',coalesce((select jsonb_agg(jsonb_build_object('draftId',id,'version',version,'baseVersion',base_version,'definition',definition,'rollbackVersionId',rollback_version_id,'publishedVersionId',published_version_id))from public.presentation_drafts where term_id=p_term_id and kind=p_kind and target_kind=p_target_kind and target_id=p_target_id and actor_id=auth.uid()),'[]'),
 'history',coalesce((select jsonb_agg(to_jsonb(h)order by h.version desc)from(select id,version,definition,previous_version as "previousVersion",rollback_version_id as "rollbackVersionId",reason,published_at as "publishedAt" from public.presentation_versions where control_id=c and(p_before is null or version<p_before)order by version desc limit 50)h),'[]'),
 'nextBefore',(select min(version)from(select version from public.presentation_versions where control_id=c and(p_before is null or version<p_before)order by version desc limit 50)h having count(*)=50));
end$$;

create function public.save_presentation_draft(p_term_id uuid,p_kind text,p_target_kind text,p_target_id uuid,p_definition jsonb,p_base_version integer,p_expected_version integer,p_request_id uuid,p_rollback_version_id uuid default null)returns jsonb
language plpgsql security definer set search_path='' as $$declare m public.term_memberships;d public.presentation_drafts;payload jsonb;r jsonb;c uuid;v integer;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.presentation_actor(p_term_id,p_kind,p_target_kind,p_target_id,true);
 payload:=jsonb_build_array(p_term_id,p_kind,p_target_kind,p_target_id,p_definition,p_base_version,p_expected_version,p_rollback_version_id);
 r:=app_private.begin_work_command('save_presentation_draft',p_request_id,payload);if r is not null then return r;end if;
 perform app_private.validate_presentation(p_kind,p_definition);
 if p_expected_version is null or p_expected_version<0 or p_base_version is null or p_base_version<0 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select work_item_id into c from public.presentation_controls where term_id=p_term_id and kind=p_kind and target_kind=p_target_kind and target_id=p_target_id;
 select coalesce(max(version),0)into v from public.presentation_versions where control_id=c;
 select *into d from public.presentation_drafts where term_id=p_term_id and kind=p_kind and target_kind=p_target_kind and target_id=p_target_id and actor_id=auth.uid()for update;
 if v<>p_base_version or coalesce(d.version,0)<>p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_rollback_version_id is not null and not exists(select 1 from public.presentation_versions where id=p_rollback_version_id and control_id=c and definition=p_definition)then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.presentation_drafts(term_id,kind,target_kind,target_id,actor_id,version,base_version,definition,rollback_version_id)
  values(p_term_id,p_kind,p_target_kind,p_target_id,auth.uid(),1,p_base_version,p_definition,p_rollback_version_id)
  on conflict(term_id,kind,target_kind,target_id,actor_id)do update set version=presentation_drafts.version+1,base_version=excluded.base_version,definition=excluded.definition,rollback_version_id=excluded.rollback_version_id,published_version_id=null,updated_at=statement_timestamp()returning *into d;
 r:=jsonb_build_object('draftId',d.id,'version',d.version);
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'save_presentation_draft',p_request_id,m.organization_id,m.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),r);
 return r;
end$$;

create function public.preview_presentation_configuration(p_draft_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d public.presentation_drafts;r jsonb;h text;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id);
 perform app_private.validate_presentation(d.kind,d.definition);
 r:=public.read_presentation_configuration(d.term_id,d.kind,d.target_kind,d.target_id);
 h:=encode(sha256(convert_to(jsonb_build_array(d.id,d.version,d.base_version,d.definition,d.rollback_version_id,r->'version',r->'definition')::text,'UTF8')),'hex');
 return jsonb_build_object('valid',true,'version',r->'version','baseVersion',d.base_version,'stale',d.base_version<>(r->>'version')::integer,'previous',r->'definition','proposed',d.definition,'reviewHash',h,'requiredActionsProtected',true,'grantsAccess',false);
end$$;

create function public.publish_presentation_configuration(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$declare d public.presentation_drafts;m public.term_memberships;r jsonb;payload jsonb;c uuid;s uuid;w public.work_items;v uuid;review jsonb;begin
 select *into d from public.presentation_drafts where id=p_draft_id and actor_id=auth.uid();if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.readiness_lock(d.term_id);m:=app_private.presentation_actor(d.term_id,d.kind,d.target_kind,d.target_id,true);
 payload:=jsonb_build_array(p_draft_id,p_expected_version,p_review_hash,p_reason);
 r:=app_private.begin_work_command('publish_presentation_configuration',p_request_id,payload);if r is not null then return r;end if;
 select *into d from public.presentation_drafts where id=p_draft_id for update;
 review:=public.preview_presentation_configuration(d.id);
 if d.version is distinct from p_expected_version or d.base_version<>(review->>'version')::integer or p_review_hash is distinct from review->>'reviewHash'or d.published_version_id is not null then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select work_item_id into c from public.presentation_controls where term_id=d.term_id and kind=d.kind and target_kind=d.target_kind and target_id=d.target_id;
 if c is null then
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,m.term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select id into s from public.status_definitions where term_id=m.term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)values(m.organization_id,m.term_id,'announcement','Presentation configuration control','restricted',m.member_id,(select display_name from public.members where id=m.member_id),s)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
  insert into public.presentation_controls values(d.term_id,d.kind,d.target_kind,d.target_id,w.id);
 else update public.work_items set updated_at=statement_timestamp()where id=c returning *into w;end if;
 insert into public.presentation_versions(control_id,version,definition,previous_version,rollback_version_id,actor_id,reason)values(w.id,w.version,d.definition,d.base_version,d.rollback_version_id,auth.uid(),btrim(p_reason))returning id into v;
 update public.presentation_drafts set published_version_id=v where id=d.id;
 return app_private.finish_work_command(w,'publish_presentation_configuration',p_request_id,payload,jsonb_build_object('draftId',d.id,'version',w.version,'definitionVersionId',v),'["presentation_version"]');
end$$;
revoke all on function app_private.presentation_actor(uuid,text,text,uuid,boolean),app_private.presentation_text(jsonb,integer),app_private.validate_presentation(text,jsonb)from public,anon,authenticated,service_role;
revoke all on function public.read_presentation_configuration(uuid,text,text,uuid,integer),public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),public.preview_presentation_configuration(uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_presentation_configuration(uuid,text,text,uuid,integer),public.save_presentation_draft(uuid,text,text,uuid,jsonb,integer,integer,uuid,uuid),public.preview_presentation_configuration(uuid),public.publish_presentation_configuration(uuid,integer,text,text,uuid)to authenticated;

create table public.operational_views(
 id uuid primary key,term_id uuid not null references public.terms(id),actor_id uuid not null references auth.users(id),
 work_item_id uuid not null unique references public.announcements(work_item_id)
);
create table public.operational_view_versions(
 view_id uuid not null references public.operational_views(id),version integer not null check(version>0),
 name text not null check(length(btrim(name))between 1 and 80),definition jsonb not null,archived boolean not null,
 saved_at timestamptz not null default statement_timestamp(),primary key(view_id,version)
);
do $$declare t text;begin foreach t in array array['operational_views','operational_view_versions']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
end loop;end$$;
create trigger immutable_operational_view before update or delete on public.operational_views for each row execute function app_private.request_history_guard();
create trigger immutable_operational_view_version before update or delete on public.operational_view_versions for each row execute function app_private.request_history_guard();
create function public.save_operational_view(p_term_id uuid,p_view_id uuid,p_name text,p_definition jsonb,p_archived boolean,p_expected_version integer,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$declare m public.term_memberships;v public.operational_views;w public.work_items;r jsonb;payload jsonb;s uuid;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.request_actor(p_term_id,true);
 select *into v from public.operational_views where id=p_view_id;
 if v.id is not null and(v.term_id<>p_term_id or v.actor_id<>auth.uid())then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_view_id,p_name,p_definition,p_archived,p_expected_version);
 r:=app_private.begin_work_command('save_operational_view',p_request_id,payload);if r is not null then return r;end if;
 perform app_private.validate_presentation('layout',p_definition);
 if p_view_id is null or not app_private.presentation_text(to_jsonb(p_name),80)or p_archived is null or p_expected_version is null or p_expected_version<0 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if v.id is null then
  if p_expected_version<>0 then raise exception using errcode='40001',message='command_stale_version';end if;
  if(select count(*)from public.operational_views where term_id=p_term_id and actor_id=auth.uid())>=20 then raise exception using errcode='22023',message='command_validation_failed';end if;
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,m.term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select id into s from public.status_definitions where term_id=m.term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)values(m.organization_id,m.term_id,'announcement','Private operational view control','restricted',m.member_id,(select display_name from public.members where id=m.member_id),s)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
  insert into public.operational_views values(p_view_id,p_term_id,auth.uid(),w.id);
 else
  select *into w from public.work_items where id=v.work_item_id for update;
  if w.version<>p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  update public.work_items set updated_at=statement_timestamp()where id=w.id returning *into w;
 end if;
 insert into public.operational_view_versions(view_id,version,name,definition,archived)values(p_view_id,w.version,btrim(p_name),p_definition,p_archived);
 return app_private.finish_work_command(w,'save_operational_view',p_request_id,payload,jsonb_build_object('viewId',p_view_id,'version',w.version),'["private_operational_view"]');
end$$;

create function public.read_my_layout_configuration(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;chosen record;rank integer;n integer;ambiguous boolean:=false;repaired boolean:=false;layout jsonb;source text:='default';begin
 m:=app_private.request_actor(p_term_id);
 -- Unit > role > term. Multiple equally specific targets fall through, never an arbitrary winner.
 for rank in reverse 3..1 loop
  select count(*)into n from public.presentation_controls c where c.term_id=p_term_id and c.kind='layout'and
   ((rank=1 and c.target_kind='term')or(rank=2 and c.target_kind='role'and exists(select 1 from app_private.effective_role_assignments a where a.term_membership_id=m.id and a.role_id=c.target_id and a.scope_type in('term','unit')and app_private.access_assignment_live(a.id)))or
    (rank=3 and c.target_kind='unit'and exists(select 1 from public.unit_memberships u join public.org_units unit on unit.id=u.unit_id where u.term_membership_id=m.id and u.unit_id=c.target_id and u.status='active'and u.effective_from<=statement_timestamp()and u.effective_to>statement_timestamp()and unit.archived_at is null)));
  if n>1 then ambiguous:=true;end if;
  if n=1 then
   select c.*into chosen from public.presentation_controls c where c.term_id=p_term_id and c.kind='layout'and
    ((rank=1 and c.target_kind='term')or(rank=2 and c.target_kind='role'and exists(select 1 from app_private.effective_role_assignments a where a.term_membership_id=m.id and a.role_id=c.target_id and a.scope_type in('term','unit')and app_private.access_assignment_live(a.id)))or
     (rank=3 and c.target_kind='unit'and exists(select 1 from public.unit_memberships u join public.org_units unit on unit.id=u.unit_id where u.term_membership_id=m.id and u.unit_id=c.target_id and u.status='active'and u.effective_from<=statement_timestamp()and u.effective_to>statement_timestamp()and unit.archived_at is null)));
   select definition into layout from public.presentation_versions where control_id=chosen.work_item_id order by version desc limit 1;
   source:=chosen.target_kind;exit;
  end if;
 end loop;
 if layout is not null then
  begin perform app_private.validate_presentation('layout',layout);
  exception when invalid_parameter_value then layout:=null;source:='default';repaired:=true;end;
 end if;
 return jsonb_build_object('layout',layout,'source',source,'ambiguous',ambiguous,'repaired',repaired,'views',coalesce((select jsonb_agg(jsonb_build_object('viewId',v.id,'version',h.version,'name',h.name,'layout',h.definition)order by h.name,v.id)
  from public.operational_views v join lateral(select *from public.operational_view_versions where view_id=v.id order by version desc limit 1)h on not h.archived
  where v.term_id=p_term_id and v.actor_id=auth.uid()),'[]'));
end$$;
revoke all on function public.save_operational_view(uuid,uuid,text,jsonb,boolean,integer,uuid),public.read_my_layout_configuration(uuid)from public,anon,authenticated,service_role;
grant execute on function public.save_operational_view(uuid,uuid,text,jsonb,boolean,integer,uuid),public.read_my_layout_configuration(uuid)to authenticated;

create function public.read_layout_targets(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;items jsonb:='[]';u public.org_units;r public.roles;begin
 m:=app_private.request_actor(p_term_id);
 if public.has_capability(p_term_id,'admin.configure')then
  items:=jsonb_build_array(jsonb_build_object('kind','term','id',p_term_id,'label','Term default'));
  for r in select *from public.roles where term_id=p_term_id and state='active'order by name,id loop
   items:=items||jsonb_build_array(jsonb_build_object('kind','role','id',r.id,'label',r.name));
  end loop;
 end if;
 for u in select *from public.org_units where term_id=p_term_id and archived_at is null order by name,id loop
  begin perform app_private.presentation_actor(p_term_id,'layout','unit',u.id);
   items:=items||jsonb_build_array(jsonb_build_object('kind','unit','id',u.id,'label',u.name));
  exception when insufficient_privilege then null;end;
 end loop;
 return items;
end$$;
revoke all on function public.read_layout_targets(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_layout_targets(uuid)to authenticated;
