-- P19: definition metadata only. Institutional activation and case commands remain gated.
create function app_private.definition_keys(v jsonb, allowed text[]) returns boolean
language sql immutable set search_path='' as $$
 select jsonb_typeof(v)='object' and not exists(select 1 from jsonb_object_keys(v) k where not(k=any(allowed)))
$$;
create function app_private.definition_text(v jsonb, n integer) returns boolean
language sql immutable set search_path='' as $$select jsonb_typeof(v)='string' and length(v#>>'{}') between 1 and n$$;

create function app_private.validate_form_condition(c jsonb, fields jsonb, depth integer default 1) returns void
language plpgsql immutable set search_path='' as $$
declare f jsonb; x jsonb; op text:=c->>'op'; typ text;
begin
 if depth>4 or octet_length(c::text)>8000 or not app_private.definition_keys(c,array['op','field','value','conditions']) then raise exception using errcode='22023',message='command_validation_failed';end if;
 if op in('and','or') then
  if not app_private.definition_keys(c,array['op','conditions']) or jsonb_typeof(c->'conditions') is distinct from 'array' or jsonb_array_length(c->'conditions') not between 1 and 5 then raise exception using errcode='22023',message='command_validation_failed';end if;
  for x in select value from jsonb_array_elements(c->'conditions') loop perform app_private.validate_form_condition(x,fields,depth+1);end loop;
 else
  if op is null or op not in('eq','in','gt','gte','lt','lte') or not(c?'field' and c?'value') or c?'conditions' then raise exception using errcode='22023',message='command_validation_failed';end if;
  select value into f from jsonb_array_elements(fields) where value->>'key'=c->>'field';typ:=f->>'type';
  if f is null or typ not in('short_text','long_text','number','currency','single_choice','checkbox') then raise exception using errcode='22023',message='command_validation_failed';end if;
  if op in('gt','gte','lt','lte') and typ not in('number','currency') then raise exception using errcode='22023',message='command_validation_failed';end if;
  if op='in' then
   if jsonb_typeof(c->'value') is distinct from 'array' or jsonb_array_length(c->'value') not between 1 and 50 then raise exception using errcode='22023',message='command_validation_failed';end if;
  end if;
  for x in select value from jsonb_array_elements(case when op='in' then c->'value' else jsonb_build_array(c->'value') end) loop
   if (typ in('number','currency') and jsonb_typeof(x)<>'number') or (typ='checkbox' and jsonb_typeof(x)<>'boolean') or (typ in('short_text','long_text','single_choice') and not coalesce(app_private.definition_text(x,200),false))
    or (typ='single_choice' and not exists(select 1 from jsonb_array_elements(f->'options') o where o->'id'=x)) then raise exception using errcode='22023',message='command_validation_failed';end if;
  end loop;
 end if;
end$$;

create function app_private.validate_form_definition(s jsonb, restricted boolean) returns void
language plpgsql immutable set search_path='' as $$
declare f jsonb; o jsonb; seen text[]:='{}'; sections text[]:='{}'; earlier jsonb:='[]'; all_fields jsonb; k text; typ text; total integer:=0; child jsonb;
begin
 if not coalesce(app_private.definition_keys(s,array['schemaVersion','sections','fields']),false) or s->'schemaVersion' is distinct from '1'::jsonb or jsonb_typeof(s->'sections') is distinct from 'array' or jsonb_typeof(s->'fields') is distinct from 'array' or octet_length(s::text)>100000 or jsonb_array_length(s->'sections') not between 1 and 10 or jsonb_array_length(s->'fields') not between 1 and 50 then raise exception using errcode='22023',message='command_validation_failed';end if;
 for f in select value from jsonb_array_elements(s->'sections') loop
  k:=f->>'key';if not coalesce(app_private.definition_keys(f,array['key','label']),false) or k is null or k!~'^[a-z][a-z0-9_]{0,59}$' or k=any(sections) or not coalesce(app_private.definition_text(f->'label',200),false) then raise exception using errcode='22023',message='command_validation_failed';end if;sections:=array_append(sections,k);
 end loop;
 -- Flatten one bounded line-item level for unique keys and the total field cap.
 all_fields:=s->'fields';
 for f in select value from jsonb_array_elements(s->'fields') loop
  if f->>'type'='line_items' then
   if jsonb_typeof(f->'itemFields') is distinct from 'array' or jsonb_array_length(f->'itemFields') not between 1 and 20 then raise exception using errcode='22023',message='command_validation_failed';end if;
   for child in select value from jsonb_array_elements(f->'itemFields') loop
    if child->>'type'='line_items' or child?'visibleWhen' or child?'requiredWhen' then raise exception using errcode='22023',message='command_validation_failed';end if;
   end loop;all_fields:=all_fields||(f->'itemFields');
  end if;
 end loop;
 for f in select value from jsonb_array_elements(all_fields) loop
  total:=total+1;k:=f->>'key';typ:=f->>'type';
  if total>50 or not coalesce(app_private.definition_keys(f,array['key','section','label','help','type','classification','required','requiredWhen','visibleWhen','options','min','max','maxLength','maxItems','itemFields','storage']),false)
   or k is null or k!~'^[a-z][a-z0-9_]{0,59}$' or k=any(seen) or not coalesce((f->>'section')=any(sections),false)
   or not coalesce(app_private.definition_text(f->'label',200),false) or jsonb_typeof(f->'help') is distinct from 'string' or length(f->>'help')>1000
   or jsonb_typeof(f->'required') is distinct from 'boolean' or typ is null or typ not in('short_text','long_text','number','currency','date','date_time','single_choice','multi_choice','checkbox','member','unit','url','file','line_items')
   or (f->>'classification') is null or (f->>'classification') not in('ordinary','confidential') or (f->>'classification'='confidential' and not restricted)
   or coalesce(f->>'storage','custom') not in('custom','finance','workflow')
   or k ~ '(secret|password|token|case_note)' then raise exception using errcode='22023',message='command_validation_failed';end if;
  -- Protected values must be handled by typed adapters, never the ordinary JSON validator/store.
  if (typ='currency' or k ~ '(amount|centavos|ceiling|price|revenue|cost|quantity)') and coalesce(f->>'storage','custom')<>'finance'
   or (k ~ '(approv|decision|authorized)' and coalesce(f->>'storage','custom') not in('finance','workflow')) then raise exception using errcode='22023',message='command_validation_failed';end if;
  if f?'maxLength' and (typ not in('short_text','long_text','url') or jsonb_typeof(f->'maxLength')<>'number' or (f->>'maxLength')::numeric not between 1 and 20000 or trunc((f->>'maxLength')::numeric)<>(f->>'maxLength')::numeric) then raise exception using errcode='22023',message='command_validation_failed';end if;
  if f?'min' or f?'max' then
   if typ not in('number','currency') or (f?'min' and jsonb_typeof(f->'min')<>'number') or (f?'max' and jsonb_typeof(f->'max')<>'number') or (f?'min' and f?'max' and (f->>'min')::numeric>(f->>'max')::numeric) then raise exception using errcode='22023',message='command_validation_failed';end if;
  end if;
  if typ in('single_choice','multi_choice') then
   if jsonb_typeof(f->'options') is distinct from 'array' or jsonb_array_length(f->'options') not between 1 and 50 or (select count(distinct x->>'id') from jsonb_array_elements(f->'options') x)<>jsonb_array_length(f->'options') then raise exception using errcode='22023',message='command_validation_failed';end if;
   for o in select value from jsonb_array_elements(f->'options') loop
    if not app_private.definition_keys(o,array['id','label']) or (o->>'id') is null or (o->>'id')!~'^[a-z][a-z0-9_]{0,59}$' or not coalesce(app_private.definition_text(o->'label',200),false) then raise exception using errcode='22023',message='command_validation_failed';end if;
   end loop;
  elsif f?'options' then raise exception using errcode='22023',message='command_validation_failed';end if;
  if typ in('line_items','multi_choice','file') then
   if jsonb_typeof(f->'maxItems') is distinct from 'number' or (f->>'maxItems')::numeric not between 1 and 100 or trunc((f->>'maxItems')::numeric)<>(f->>'maxItems')::numeric then raise exception using errcode='22023',message='command_validation_failed';end if;
  elsif f?'maxItems' then raise exception using errcode='22023',message='command_validation_failed';end if;
  if typ<>'line_items' and f?'itemFields' then raise exception using errcode='22023',message='command_validation_failed';end if;
  -- Conditions only reference preceding top-level custom fields: no cycles, hidden/protected dependencies.
  if f?'requiredWhen' then perform app_private.validate_form_condition(f->'requiredWhen',earlier);end if;
  if f?'visibleWhen' then perform app_private.validate_form_condition(f->'visibleWhen',earlier);end if;
  if coalesce(f->>'storage','custom')='custom' and exists(select 1 from jsonb_array_elements(s->'fields') x where x->>'key'=k) then earlier:=earlier||jsonb_build_array(f);end if;
  seen:=array_append(seen,k);
 end loop;
end$$;

create function app_private.validate_workflow_definition(s jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare f jsonb; keys text[]:='{}'; k text;
begin
 if not coalesce(app_private.definition_keys(s,array['schemaVersion','stages']),false) or s->'schemaVersion' is distinct from '1'::jsonb or jsonb_typeof(s->'stages') is distinct from 'array' or jsonb_array_length(s->'stages') not between 1 and 12 or octet_length(s::text)>20000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 for f in select value from jsonb_array_elements(s->'stages') loop
  k:=f->>'key';if not coalesce(app_private.definition_keys(f,array['key','label','review','reviewers','outcome','revisionStage','entryFields','reminderDays']),false) or k is null or k!~'^[a-z][a-z0-9_]{0,59}$' or k=any(keys) or not coalesce(app_private.definition_text(f->'label',200),false)
   or coalesce(f->>'review','') not in('none','one','all') or jsonb_typeof(f->'reviewers') is distinct from 'array' or jsonb_array_length(f->'reviewers')>10
   or coalesce(f->>'outcome','') not in('pending','revision','approved','rejected','completed') or jsonb_typeof(f->'entryFields') is distinct from 'array' or jsonb_array_length(f->'entryFields')>50
   or jsonb_typeof(f->'reminderDays') is distinct from 'number' or (f->>'reminderDays')::numeric not between 1 and 365 or trunc((f->>'reminderDays')::numeric)<>(f->>'reminderDays')::numeric then raise exception using errcode='22023',message='command_validation_failed';end if;
  if exists(select 1 from jsonb_array_elements_text(f->'reviewers') r where r!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') or exists(select 1 from jsonb_array_elements_text(f->'entryFields') r where r!~'^[a-z][a-z0-9_]{0,59}$') then raise exception using errcode='22023',message='command_validation_failed';end if;
  keys:=array_append(keys,k);
 end loop;
 for f in select value from jsonb_array_elements(s->'stages') loop
  if f?'revisionStage' and not coalesce((f->>'revisionStage')=any(keys),false) then raise exception using errcode='22023',message='command_validation_failed';end if;
 end loop;
end$$;

create table public.request_types(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_id uuid not null,
 stable_key text not null check(stable_key ~ '^[a-z][a-z0-9_]{0,59}$'),label text not null check(length(label) between 1 and 200),need text not null check(length(need) between 1 and 1000),
 governed_kind text not null check(governed_kind in('general','fin','mcd')),payload_classification text not null default 'ordinary' check(payload_classification in('ordinary','restricted')),
 form_version_id uuid,workflow_version_id uuid,receiving_unit_id uuid,primary_contact_id uuid,backup_contact_id uuid,
 guest_eligible boolean not null default false,authority_confirmed boolean not null default false,live_enabled boolean not null default false,
 lead_time_days integer check(lead_time_days between 0 and 365),official_url text check(official_url is null or (length(official_url)<=2048 and official_url ~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]]*)?$' and official_url !~ '@')),
 process_note text not null check(length(process_note) between 1 and 2000),archived_at timestamptz,
 unique(organization_id,term_id,id),unique(term_id,stable_key),
 foreign key(organization_id,term_id) references public.terms(organization_id,id),
 foreign key(organization_id,term_id,receiving_unit_id) references public.org_units(organization_id,term_id,id),
 foreign key(organization_id,term_id,primary_contact_id) references public.term_memberships(organization_id,term_id,id),
 foreign key(organization_id,term_id,backup_contact_id) references public.term_memberships(organization_id,term_id,id),
 check(not live_enabled or (authority_confirmed and receiving_unit_id is not null and primary_contact_id is not null and backup_contact_id is not null and form_version_id is not null and workflow_version_id is not null)),
 check(primary_contact_id is null or backup_contact_id is null or primary_contact_id<>backup_contact_id)
);
create table public.form_versions(
 id uuid primary key default gen_random_uuid(),request_type_id uuid not null references public.request_types(id),version integer not null check(version>0),
 state text not null check(state in('draft','published')),restricted boolean not null default false,schema_json jsonb not null,
 published_at timestamptz,unique(request_type_id,version),unique(request_type_id,id),check((state='published')=(published_at is not null))
);
create table public.workflow_versions(
 id uuid primary key default gen_random_uuid(),request_type_id uuid not null references public.request_types(id),version integer not null check(version>0),
 state text not null check(state in('draft','published')),definition_json jsonb not null,published_at timestamptz,
 unique(request_type_id,version),unique(request_type_id,id),check((state='published')=(published_at is not null))
);
alter table public.request_types add foreign key(id,form_version_id) references public.form_versions(request_type_id,id),add foreign key(id,workflow_version_id) references public.workflow_versions(request_type_id,id);
create index request_types_receiver_idx on public.request_types(organization_id,term_id,receiving_unit_id);
create index request_types_primary_idx on public.request_types(organization_id,term_id,primary_contact_id);
create index request_types_backup_idx on public.request_types(organization_id,term_id,backup_contact_id);

create function app_private.guard_request_definition() returns trigger
language plpgsql set search_path='' as $$begin
 if tg_op<>'INSERT' and old.state='published' then raise exception using errcode='55000',message='command_published_immutable';end if;
 if tg_op='DELETE' then return old;end if;
 if tg_table_name='form_versions' then perform app_private.validate_form_definition(new.schema_json,new.restricted);
 else perform app_private.validate_workflow_definition(new.definition_json);end if;
 if tg_op='UPDATE' and (new.id<>old.id or new.request_type_id<>old.request_type_id or new.version<>old.version) then raise exception using errcode='22023',message='command_validation_failed';end if;
 return new;
end$$;
create trigger guard_form_definition before insert or update or delete on public.form_versions for each row execute function app_private.guard_request_definition();
create trigger guard_workflow_definition before insert or update or delete on public.workflow_versions for each row execute function app_private.guard_request_definition();
create function app_private.guard_request_type() returns trigger language plpgsql set search_path='' as $$begin
 if tg_op='UPDATE' and (new.id<>old.id or new.term_id<>old.term_id or new.organization_id<>old.organization_id or new.stable_key<>old.stable_key or new.governed_kind<>old.governed_kind or new.payload_classification<>old.payload_classification) then raise exception using errcode='55000',message='command_published_immutable';end if;
 if new.form_version_id is not null and not exists(select 1 from public.form_versions where id=new.form_version_id and request_type_id=new.id and state='published' and restricted=(new.payload_classification='restricted')) then raise exception using errcode='22023',message='command_validation_failed';end if;
 if new.workflow_version_id is not null and not exists(select 1 from public.workflow_versions where id=new.workflow_version_id and request_type_id=new.id and state='published') then raise exception using errcode='22023',message='command_validation_failed';end if;
 return new;end$$;
create trigger guard_request_type before insert or update on public.request_types for each row execute function app_private.guard_request_type();

create function app_private.request_contact_active(t public.request_types, membership uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships m join public.members p on p.id=m.member_id join public.unit_memberships u on u.term_membership_id=m.id
 where m.id=membership and m.term_id=t.term_id and m.membership_kind='core' and m.status='active' and m.joined_at<=statement_timestamp() and m.ends_at>statement_timestamp() and p.account_state='active'
 and u.unit_id=t.receiving_unit_id and u.status='active' and u.effective_from<=statement_timestamp() and u.effective_to>statement_timestamp() and u.deployment_type in('head','primary_contact','backup_contact'))
$$;
create function app_private.request_service_ready(t public.request_types) returns boolean
language sql stable security definer set search_path='' as $$
 select t.live_enabled and t.authority_confirmed and t.archived_at is null
 and exists(select 1 from public.terms where id=t.term_id and state='active')
 and exists(select 1 from public.org_units where id=t.receiving_unit_id and term_id=t.term_id and archived_at is null and review_service)
 and app_private.request_contact_active(t,t.primary_contact_id) and app_private.request_contact_active(t,t.backup_contact_id)
 and exists(select 1 from public.form_versions where id=t.form_version_id and state='published') and exists(select 1 from public.workflow_versions where id=t.workflow_version_id and state='published')
 and not exists(select 1 from public.workflow_versions v cross join lateral jsonb_array_elements(v.definition_json->'stages') s where v.id=t.workflow_version_id and (
  (s->>'review'<>'none' and jsonb_array_length(s->'reviewers')=0)
  or exists(select 1 from jsonb_array_elements_text(s->'reviewers') r where not app_private.request_contact_active(t,r::uuid))
  or exists(select 1 from jsonb_array_elements_text(s->'entryFields') k where not exists(select 1 from public.form_versions f cross join lateral jsonb_array_elements(f.schema_json->'fields') field where f.id=t.form_version_id and field->>'key'=k))))
 -- P19 does not activate approval engines merely because their stage labels exist.
 and t.governed_kind='general'
$$;

create function app_private.seed_request_templates() returns trigger language plpgsql security definer set search_path='' as $$
declare k text; t uuid; f uuid; w uuid;begin
 foreach k in array array['general','fin','mcd'] loop
  insert into public.request_types(organization_id,term_id,stable_key,label,need,governed_kind,payload_classification,process_note)
  values(new.organization_id,new.id,k,case k when 'general' then 'General support' when 'fin' then 'FIN financial review' else 'MCD publicity review' end,
   case k when 'general' then 'Ask where to route a practical support need.' when 'fin' then 'Find the required review for costs, expenses or fundraising, including zero-cost plans.' else 'Find review for the exact finalized publicity, caption and intended use.' end,k,case when k='general' then 'ordinary' else 'restricted' end,
   'Unconfirmed template. Receiving service, contacts, lead time and official process require institutional approval. No live submissions or approval authority are enabled.') returning id into t;
  insert into public.form_versions(request_type_id,version,state,restricted,published_at,schema_json) values(t,1,'published',k<>'general',statement_timestamp(),
   jsonb_build_object('schemaVersion',1,'sections',jsonb_build_array(jsonb_build_object('key','need','label','Your support need')),'fields',jsonb_build_array(jsonb_build_object('key','purpose','section','need','label','What do you need?','help','Describe the purpose without passwords, financial figures or private case notes.','type','long_text','classification',case when k='general' then 'ordinary' else 'confidential' end,'required',true,'maxLength',2000)))) returning id into f;
  insert into public.workflow_versions(request_type_id,version,state,published_at,definition_json) values(t,1,'published',statement_timestamp(),
   '{"schemaVersion":1,"stages":[{"key":"triage","label":"Unconfirmed triage","review":"one","reviewers":[],"outcome":"pending","entryFields":["purpose"],"reminderDays":7}]}') returning id into w;
  update public.request_types set form_version_id=f,workflow_version_id=w where id=t;
 end loop;return new;end$$;
create trigger seed_request_templates after insert on public.terms for each row execute function app_private.seed_request_templates();
-- Use the same trigger for existing terms without fabricating an institution or roster.
do $$declare t record;begin for t in select id from public.terms loop
 execute 'create temporary table p19_existing_term (like public.terms including defaults) on commit drop';
 execute 'create trigger seed_request_templates after insert on p19_existing_term for each row execute function app_private.seed_request_templates()';
 execute 'insert into p19_existing_term select * from public.terms where id=$1' using t.id;
 execute 'drop table p19_existing_term';end loop;end$$;

-- Explicit allowlist projection; schemas never contain defaults, secrets or submitted values.
create function public.read_request_catalog(p_term_id uuid,p_type_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not exists(select 1 from public.term_memberships where id=public.current_term_membership(p_term_id) and membership_kind='core') or not public.has_capability(p_term_id,'workspace.read') then return null;end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'key',r.stable_key,'label',r.label,'need',r.need,'classification',r.payload_classification,'guestEligible',r.guest_eligible,'authorityConfirmed',r.authority_confirmed,'liveEnabled',false,
 'serviceReady',app_private.request_service_ready(r),'receivingUnit',case when u.archived_at is null then u.name end,
 'primaryContact',case when app_private.request_contact_active(r,r.primary_contact_id) then (select d.display_name from public.read_directory(p_term_id) d where d.member_id=(select member_id from public.term_memberships where id=r.primary_contact_id)) end,
 'backupContact',case when app_private.request_contact_active(r,r.backup_contact_id) then (select d.display_name from public.read_directory(p_term_id) d where d.member_id=(select member_id from public.term_memberships where id=r.backup_contact_id)) end,
 'leadTimeDays',r.lead_time_days,'officialUrl',r.official_url,'processNote',r.process_note,'formVersionId',f.id,'formVersion',f.version,'workflowVersionId',w.id,'workflowVersion',w.version,
 'form',case when p_type_id is not null then f.schema_json end) order by r.label),'[]'::jsonb) into result
 from public.request_types r join public.form_versions f on f.id=r.form_version_id and f.state='published' join public.workflow_versions w on w.id=r.workflow_version_id and w.state='published'
 left join public.org_units u on u.id=r.receiving_unit_id and u.term_id=r.term_id
 where r.term_id=p_term_id and r.archived_at is null and (p_type_id is null or r.id=p_type_id);
 return jsonb_build_object('items',result);
end$$;
alter table public.request_types enable row level security;
alter table public.form_versions enable row level security;
alter table public.workflow_versions enable row level security;
revoke all on public.request_types,public.form_versions,public.workflow_versions from public,anon,authenticated,service_role;
revoke all on function public.read_request_catalog(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.read_request_catalog(uuid,uuid) to authenticated;
revoke all on function app_private.definition_keys(jsonb,text[]),app_private.definition_text(jsonb,integer),app_private.validate_form_condition(jsonb,jsonb,integer),app_private.validate_form_definition(jsonb,boolean),app_private.validate_workflow_definition(jsonb),app_private.guard_request_definition(),app_private.guard_request_type(),app_private.request_contact_active(public.request_types,uuid),app_private.request_service_ready(public.request_types),app_private.seed_request_templates() from public,anon,authenticated,service_role;

-- Preserve historical generic requests, but close all creation until P21 owns validated cases.
create or replace function public.create_work_item(p_term_id uuid,p_kind text,p_title text,p_safe_summary text,p_body text,p_classification text,
 p_lead_unit_id uuid default null,p_parent_id uuid default null,p_expected_parent_version integer default null,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$begin
 if p_kind in('deliverable','task','request') then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 return app_private.create_work_item(p_term_id,p_kind,p_title,p_safe_summary,p_body,p_classification,p_lead_unit_id,p_parent_id,p_expected_parent_version,p_request_id);end$$;
