-- P38 bounded process metadata. Semantics, issued counters and pinned requests remain authoritative.
alter table public.status_definitions add column display_color text not null default '#252624'check(display_color in('#252624','#b82320','#62665f')),
 add column display_order integer not null default 0 check(display_order between 0 and 1000);
alter table public.request_types add column lead_time_text text not null default ''check(length(lead_time_text)<=500);
create table public.event_phases(id uuid primary key,term_id uuid not null references public.terms(id),title text not null check(length(btrim(title))between 1 and 200),
 starts_on date not null,ends_on date not null,active boolean not null,sort_order integer not null check(sort_order between 0 and 1000),check(starts_on<=ends_on));
create unique index one_active_event_phase on public.event_phases(term_id)where active;
create table public.process_control(term_id uuid primary key references public.terms(id),work_item_id uuid not null unique references public.announcements(work_item_id));
create table public.process_changes(term_id uuid not null references public.process_control(term_id),version integer not null,kind text not null check(kind in('phase','status','service')),
 target_id uuid not null,previous jsonb,proposed jsonb not null,reason text not null,actor_id uuid not null references auth.users(id),published_at timestamptz not null default statement_timestamp(),primary key(term_id,version));
do $$declare t text;begin foreach t in array array['event_phases','process_control','process_changes']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
end loop;end$$;
create trigger immutable_process_history before update or delete on public.process_changes for each row execute function app_private.request_history_guard();
create trigger immutable_process_control before update or delete on public.process_control for each row execute function app_private.request_history_guard();
create function app_private.preserve_status_semantics()returns trigger language plpgsql set search_path='' as $$begin
 if row(new.id,new.organization_id,new.term_id,new.resource_kind,new.stable_key,new.semantic_category)is distinct from row(old.id,old.organization_id,old.term_id,old.resource_kind,old.stable_key,old.semantic_category)then raise exception using errcode='55000',message='command_published_immutable';end if;return new;end$$;
create trigger preserve_status_semantics before update on public.status_definitions for each row execute function app_private.preserve_status_semantics();
create function public.read_process_admin(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 perform app_private.organization_actor(p_term_id);
 return jsonb_build_object('version',coalesce((select w.version from public.process_control c join public.work_items w on w.id=c.work_item_id where c.term_id=p_term_id),0),
 'phases',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'startsOn',p.starts_on,'endsOn',p.ends_on,'active',p.active,'order',p.sort_order)order by p.sort_order,p.id)from public.event_phases p where term_id=p_term_id),'[]'),
 'statuses',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'kind',s.resource_kind,'key',s.stable_key,'semantic',s.semantic_category,'label',s.label,'color',s.display_color,'order',s.display_order)order by s.resource_kind,s.display_order,s.stable_key)from public.status_definitions s where s.term_id=p_term_id),'[]'),
 'services',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'label',t.label,'need',t.need,'governedKind',t.governed_kind,'unitId',t.receiving_unit_id,'primary',t.primary_contact_id,'backup',t.backup_contact_id,'officialUrl',t.official_url,'leadDays',t.lead_time_days,'leadText',t.lead_time_text,'guestEligible',t.guest_eligible,'prefix',(select prefix from public.tracking_counters c where c.term_id=t.term_id and c.namespace_key=case t.governed_kind when 'general'then 'service:'||t.receiving_unit_id::text when 'fin'then 'FIN'else 'MCD'end),'ready',app_private.request_service_ready(t))order by t.label,t.id)from public.request_types t where t.term_id=p_term_id and t.archived_at is null),'[]'),
 'units',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.name)order by u.name,u.id)from public.org_units u where u.term_id=p_term_id and u.archived_at is null and u.review_service),'[]'),
 'contacts',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'unitId',x.unit_id)order by x.name,x.id)from(select distinct tm.id,person.display_name name,d.unit_id from public.unit_memberships d join public.term_memberships tm on tm.id=d.term_membership_id join public.members person on person.id=tm.member_id where tm.term_id=p_term_id and tm.status='active'and tm.membership_kind='core'and person.account_state='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and d.status='active'and d.deployment_type in('head','primary_contact','backup_contact')and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp())x),'[]'),
 'history',coalesce((select jsonb_agg(to_jsonb(h)order by h.version desc)from(select version,kind,target_id,previous,proposed,reason,published_at from public.process_changes where term_id=p_term_id order by version desc limit 50)h),'[]'));
end$$;
create function public.preview_process_change(p_term_id uuid,p_kind text,p_values jsonb)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;v jsonb;previous jsonb;problem text;allowed text[];change_id uuid;phase public.event_phases;s public.status_definitions;t public.request_types;u uuid;chosen_prefix text;counter public.tracking_counters;n integer;begin
 m:=app_private.organization_actor(p_term_id);v:=public.read_process_admin(p_term_id);
 allowed:=case p_kind when 'phase'then array['id','title','startsOn','endsOn','active','order']when 'status'then array['id','label','color','order']when 'service'then array['id','label','need','unitId','primary','backup','officialUrl','leadDays','leadText','guestEligible','prefix']else null end;
 if allowed is null or not coalesce(app_private.definition_keys(p_values,allowed),false)then problem:='unsupported_fields';else
 begin
 change_id:=(p_values->>'id')::uuid;
 if change_id is null then problem:='missing_target';
 elsif p_kind='phase'then
  select *into phase from public.event_phases where event_phases.id=change_id;previous:=to_jsonb(phase);
  if phase.id is not null and phase.term_id<>p_term_id then problem:='target_unavailable';
  elsif not coalesce(app_private.definition_text(p_values->'title',200),false)or jsonb_typeof(p_values->'active')is distinct from 'boolean'or jsonb_typeof(p_values->'order')is distinct from 'number'or(p_values->>'order')::numeric not between 0 and 1000 or trunc((p_values->>'order')::numeric)<>(p_values->>'order')::numeric
   or p_values->>'startsOn'is null or p_values->>'endsOn'is null or not isfinite((p_values->>'startsOn')::date)or not isfinite((p_values->>'endsOn')::date)
   or(p_values->>'startsOn')::date>(p_values->>'endsOn')::date or not exists(select 1 from public.terms where terms.id=p_term_id and(p_values->>'startsOn')::date>=starts_on and(p_values->>'endsOn')::date<=closes_on)then problem:='invalid_phase_dates';
  elsif(p_values->>'active')::boolean and exists(select 1 from public.event_phases where term_id=p_term_id and active and event_phases.id<>change_id)then problem:='active_phase_exists';end if;
 elsif p_kind='status'then
  select *into s from public.status_definitions where status_definitions.id=change_id and term_id=p_term_id;previous:=to_jsonb(s);
  if s.id is null then problem:='target_unavailable';elsif not coalesce(app_private.definition_text(p_values->'label',120),false)or coalesce(p_values->>'color','')not in('#252624','#b82320','#62665f')or jsonb_typeof(p_values->'order')is distinct from 'number'or(p_values->>'order')::numeric not between 0 and 1000 or trunc((p_values->>'order')::numeric)<>(p_values->>'order')::numeric then problem:='invalid_label_or_contrast';end if;
 elsif p_kind='service'then
  select *into t from public.request_types where request_types.id=change_id and term_id=p_term_id and archived_at is null;previous:=to_jsonb(t);u:=(p_values->>'unitId')::uuid;chosen_prefix:=p_values->>'prefix';
  select *into counter from public.tracking_counters where term_id=p_term_id and namespace_key=case t.governed_kind when 'general'then 'service:'||u::text when 'fin'then 'FIN'else 'MCD'end;
  if t.id is null then problem:='target_unavailable';
  elsif t.governed_kind<>'general'and u is distinct from t.receiving_unit_id then problem:='protected_routing';
  elsif counter.id is not null and chosen_prefix is distinct from counter.prefix then problem:='issued_prefix_immutable';
  elsif counter.id is null and t.governed_kind='general'and(chosen_prefix is null or chosen_prefix!~'^[A-Z]{2,6}$'or chosen_prefix in('FIN','MCD'))then problem:='invalid_or_reserved_prefix';
  elsif counter.id is null and exists(select 1 from public.tracking_counters where term_id=p_term_id and tracking_counters.prefix=chosen_prefix)then problem:='prefix_in_use';
  elsif not coalesce(app_private.definition_text(p_values->'label',200),false)or not coalesce(app_private.definition_text(p_values->'need',1000),false)or jsonb_typeof(p_values->'guestEligible')is distinct from 'boolean'or jsonb_typeof(p_values->'leadText')is distinct from 'string'or length(p_values->>'leadText')>500
   or jsonb_typeof(p_values->'leadDays')is distinct from 'number'or(p_values->>'leadDays')::numeric not between 0 and 365 or trunc((p_values->>'leadDays')::numeric)<>(p_values->>'leadDays')::numeric then problem:='invalid_service';
  elsif not exists(select 1 from public.org_units where org_units.id=u and term_id=p_term_id and review_service and archived_at is null)then problem:='service_unit_unavailable';
  elsif u is distinct from t.receiving_unit_id and exists(select 1 from public.requests where request_type_id=t.id)then problem:='pinned_routing_exists';
  else
   t.receiving_unit_id:=u;t.primary_contact_id:=(p_values->>'primary')::uuid;t.backup_contact_id:=(p_values->>'backup')::uuid;
   if t.primary_contact_id is null or t.backup_contact_id is null or t.primary_contact_id=t.backup_contact_id or not app_private.request_contact_active(t,t.primary_contact_id)or not app_private.request_contact_active(t,t.backup_contact_id)then problem:='inactive_or_missing_contact';
   elsif p_values->>'officialUrl'is not null and not app_private.form_url(p_values->>'officialUrl')then problem:='invalid_official_link';end if;
  end if;
 end if;
 exception when data_exception or integrity_constraint_violation then problem:='invalid_configuration';end;
 end if;
 return jsonb_build_object('version',v->'version','valid',problem is null,'problem',problem,'previous',previous,'proposed',p_values,
  'fingerprint',encode(sha256(convert_to(jsonb_build_array(p_kind,p_values,v->'version',previous)::text,'UTF8')),'hex'),
  'notice','Display changes grant no approval or access. Existing IDs, issued references, pinned submissions and live activation are preserved.');
end$$;
create function public.publish_process_change(p_term_id uuid,p_kind text,p_values jsonb,p_expected_version integer,p_fingerprint text,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;r jsonb;payload jsonb;result jsonb;control uuid;w public.work_items;status uuid;change_id uuid;t public.request_types;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.organization_actor(p_term_id,true);
 payload:=jsonb_build_array(p_term_id,p_kind,p_values,p_expected_version,p_fingerprint,p_reason);result:=app_private.begin_work_command('publish_process_change',p_request_id,payload);if result is not null then return result;end if;
 r:=public.preview_process_change(p_term_id,p_kind,p_values);
 if(r->>'version')::integer is distinct from p_expected_version or r->>'fingerprint'is distinct from p_fingerprint then raise exception using errcode='40001',message='command_stale_version';end if;
 if not(r->>'valid')::boolean or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select work_item_id into control from public.process_control where term_id=p_term_id;
 if control is null then
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,p_term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select status_definitions.id into status from public.status_definitions where term_id=p_term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)values(m.organization_id,p_term_id,'announcement','Process configuration control','restricted',m.member_id,(select display_name from public.members where members.id=m.member_id),status)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);insert into public.process_control values(p_term_id,w.id);
 else update public.work_items set updated_at=statement_timestamp()where work_items.id=control returning *into w;end if;
 change_id:=(p_values->>'id')::uuid;
 if p_kind='phase'then
  insert into public.event_phases values(change_id,p_term_id,btrim(p_values->>'title'),(p_values->>'startsOn')::date,(p_values->>'endsOn')::date,(p_values->>'active')::boolean,(p_values->>'order')::integer)
   on conflict on constraint event_phases_pkey do update set title=excluded.title,starts_on=excluded.starts_on,ends_on=excluded.ends_on,active=excluded.active,sort_order=excluded.sort_order;
 elsif p_kind='status'then update public.status_definitions set label=btrim(p_values->>'label'),display_color=p_values->>'color',display_order=(p_values->>'order')::integer where status_definitions.id=change_id and term_id=p_term_id;
 else
  update public.request_types set label=btrim(p_values->>'label'),need=p_values->>'need',receiving_unit_id=(p_values->>'unitId')::uuid,primary_contact_id=(p_values->>'primary')::uuid,backup_contact_id=(p_values->>'backup')::uuid,official_url=p_values->>'officialUrl',lead_time_days=(p_values->>'leadDays')::integer,lead_time_text=p_values->>'leadText',guest_eligible=(p_values->>'guestEligible')::boolean where request_types.id=change_id and term_id=p_term_id returning *into t;
  if t.governed_kind='general'then insert into public.tracking_counters(organization_id,term_id,namespace_key,prefix,next_value)values(t.organization_id,t.term_id,'service:'||t.receiving_unit_id::text,p_values->>'prefix',1)on conflict(term_id,namespace_key)do nothing;end if;
 end if;
 insert into public.process_changes values(p_term_id,w.version,p_kind,change_id,r->'previous',p_values,btrim(p_reason),auth.uid(),statement_timestamp());
 return app_private.finish_work_command(w,'publish_process_change',p_request_id,payload,jsonb_build_object('id',change_id,'version',w.version),'["process_configuration"]');
end$$;
create function public.read_process_summary(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 perform app_private.request_actor(p_term_id);
 return jsonb_build_object('phase',(select jsonb_build_object('id',id,'title',title,'startsOn',starts_on,'endsOn',ends_on)from public.event_phases where term_id=p_term_id and active),
  'statuses',coalesce((select jsonb_agg(jsonb_build_object('kind',resource_kind,'key',stable_key,'label',label,'semantic',semantic_category,'color',display_color,'order',display_order)order by display_order,stable_key)from public.status_definitions where term_id=p_term_id),'[]'));
end$$;
create function public.resolve_request_reference(p_term_id uuid,p_reference text)returns uuid language sql stable security definer set search_path='' as $$
 select r.work_item_id from public.requests r where r.term_id=p_term_id and r.tracking_id=p_reference and app_private.request_readable(p_term_id,r.work_item_id)
$$;
revoke all on function app_private.preserve_status_semantics()from public,anon,authenticated,service_role;
revoke all on function public.read_process_admin(uuid),public.preview_process_change(uuid,text,jsonb),public.publish_process_change(uuid,text,jsonb,integer,text,text,uuid),public.read_process_summary(uuid),public.resolve_request_reference(uuid,text)from public,anon,authenticated,service_role;
grant execute on function public.read_process_admin(uuid),public.preview_process_change(uuid,text,jsonb),public.publish_process_change(uuid,text,jsonb,integer,text,text,uuid),public.read_process_summary(uuid),public.resolve_request_reference(uuid,text)to authenticated;

alter function public.read_request_catalog(uuid,uuid)rename to read_request_catalog_before_process;
alter function public.read_request_catalog_before_process(uuid,uuid)set schema app_private;
revoke all on function app_private.read_request_catalog_before_process(uuid,uuid)from public,anon,authenticated,service_role;
create function public.read_request_catalog(p_term_id uuid,p_type_id uuid default null)returns jsonb language plpgsql stable security definer set search_path='' as $$declare original jsonb;begin
 original:=app_private.read_request_catalog_before_process(p_term_id,p_type_id);if original is null then return null;end if;
 return original||jsonb_build_object('items',coalesce((select jsonb_agg(item||jsonb_build_object('leadTimeText',t.lead_time_text,
  'primaryContactId',case when item->>'primaryContact'is not null then(select member_id from public.term_memberships where id=t.primary_contact_id)end,
  'backupContactId',case when item->>'backupContact'is not null then(select member_id from public.term_memberships where id=t.backup_contact_id)end)order by ord)
  from jsonb_array_elements(original->'items')with ordinality a(item,ord)join public.request_types t on t.id=(item->>'id')::uuid and t.term_id=p_term_id),'[]'));
end$$;
revoke all on function public.read_request_catalog(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_request_catalog(uuid,uuid)to authenticated;
