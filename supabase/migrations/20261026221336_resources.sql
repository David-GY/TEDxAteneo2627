-- P32: plain-text resources; restricted audit spines never contain guide text.
create table public.resources(
 work_item_id uuid primary key references public.announcements(work_item_id),
 visibility text not null check(visibility in('core','unit')),published_version integer,
 kind text not null check(kind in('guide','glossary')),essential boolean not null default false
);
create table public.resource_versions(
 resource_id uuid not null references public.resources(work_item_id),version integer not null,
 label text not null check(length(btrim(label))between 1 and 240),body text not null check(length(body)<=12000),
 alias text not null check(alias ~ '^[a-z0-9][a-z0-9-]{0,79}$'),owner_id uuid not null references public.members(id),
 review_on date not null check(isfinite(review_on)),service_id uuid references public.org_units(id),targets jsonb not null,
 published boolean not null,actor_id uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),
 primary key(resource_id,version)
);
alter table public.resources add foreign key(work_item_id,published_version)references public.resource_versions(resource_id,version)deferrable initially deferred;
create table public.resource_aliases(
 term_id uuid not null references public.terms(id),alias text not null,resource_id uuid not null references public.resources(work_item_id),primary key(term_id,alias)
);
create table public.onboarding_progress(
 term_membership_id uuid not null references public.term_memberships(id),item text not null,revision integer not null check(revision>0),
 state text not null check(state in('done','skipped')),version integer not null check(version>0),updated_at timestamptz not null default statement_timestamp(),
 primary key(term_membership_id,item,revision)
);
do $$declare t text;begin foreach t in array array['resources','resource_versions','resource_aliases','onboarding_progress']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);end loop;end$$;
create trigger immutable_resource_versions before update or delete on public.resource_versions for each row execute function app_private.request_history_guard();
create trigger permanent_resource_aliases before update or delete on public.resource_aliases for each row execute function app_private.request_history_guard();
create function app_private.resource_editor(term uuid,scope text,unit uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships where id=public.current_term_membership(term)and membership_kind='core')and public.has_capability(term,'workspace.read')and exists(select 1 from public.terms where id=term and state='active')and
 case scope when 'core'then public.has_capability(term,'admin.configure')when 'unit'then unit is not null and public.has_capability(term,'committee.manage',unit)else false end
$$;
create function app_private.resource_visible(p_resource_id uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.resources r join public.work_items w on w.id=r.work_item_id where r.work_item_id=p_resource_id and w.archived_at is null and r.published_version is not null and public.has_capability(w.term_id,'workspace.read')and
 (r.visibility='core'or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id where um.term_membership_id=public.current_term_membership(w.term_id)and um.unit_id=w.lead_unit_id and um.status='active'and um.effective_from<=statement_timestamp()and um.effective_to>statement_timestamp()and u.archived_at is null)))
$$;
create function app_private.resource_spine_guard()returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.resources where work_item_id=old.id)and current_setting('app.resource_write',true)is distinct from old.id::text and(new.title,new.safe_summary,new.lead_unit_id,new.owner_member_id,new.archived_at)is distinct from(old.title,old.safe_summary,old.lead_unit_id,old.owner_member_id,old.archived_at)then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger protect_resource_spine before update on public.work_items for each row execute function app_private.resource_spine_guard();
create function public.save_resource(p_term_id uuid,p_id uuid default null,p_values jsonb default null,p_expected_version integer default null,p_request_id uuid default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;w public.work_items;old public.resources;r public.resource_versions;unit uuid;visibility text;kind text;essential boolean;publish boolean;payload jsonb;result jsonb;status uuid;target jsonb;owner_name text;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.request_actor(p_term_id,true);
 if p_id is not null then select *into w from public.work_items where id=p_id and term_id=p_term_id for update;select *into old from public.resources where work_item_id=w.id;
 if old.work_item_id is null or not app_private.resource_editor(p_term_id,old.visibility,w.lead_unit_id)then raise exception using errcode='42501',message='command_permission_denied';end if;end if;
 if jsonb_typeof(p_values)is distinct from 'object'or exists(select 1 from jsonb_object_keys(p_values)k where k not in('label','body','alias','ownerId','reviewOn','serviceId','targets','visibility','unitId','kind','essential','publish','coreSafe'))or
 exists(select 1 from jsonb_each(p_values)f where(f.key in('label','body','alias','ownerId','reviewOn','visibility','kind')and jsonb_typeof(f.value)<>'string')or(f.key in('essential','publish','coreSafe')and jsonb_typeof(f.value)<>'boolean')or(f.key in('unitId','serviceId')and jsonb_typeof(f.value)not in('string','null')))then raise exception using errcode='22023',message='command_validation_failed';end if;
 visibility:=p_values->>'visibility';unit:=nullif(p_values->>'unitId','')::uuid;kind:=p_values->>'kind';essential:=(p_values->>'essential')::boolean;publish:=(p_values->>'publish')::boolean;
 if visibility is null or visibility not in('core','unit')or kind is null or kind not in('guide','glossary')or essential is null or publish is null or(visibility='core'and unit is not null)or(essential and visibility<>'core')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if not app_private.resource_editor(p_term_id,visibility,unit)or(unit is not null and not exists(select 1 from public.org_units where id=unit and term_id=p_term_id and archived_at is null))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if old.work_item_id is not null and(old.visibility,w.lead_unit_id,old.kind,old.essential)is distinct from(visibility,unit,kind,essential)then raise exception using errcode='22023',message='resource_scope_fixed';end if;
 payload:=jsonb_build_array(p_term_id,p_id,p_values,p_expected_version);result:=app_private.begin_work_command('save_resource',p_request_id,payload);if result is not null then return result;end if;
 if(p_id is null and p_expected_version is distinct from 0)or(p_id is not null and w.version is distinct from p_expected_version)then raise exception using errcode='40001',message='command_stale_version';end if;
 r.label:=btrim(p_values->>'label');r.body:=p_values->>'body';r.alias:=p_values->>'alias';r.owner_id:=(p_values->>'ownerId')::uuid;r.review_on:=(p_values->>'reviewOn')::date;r.service_id:=nullif(p_values->>'serviceId','')::uuid;r.targets:=p_values->'targets';
 if r.label is null or length(r.label)not between 1 and 240 or r.body is null or length(r.body)>12000 or r.alias is null or r.alias!~'^[a-z0-9][a-z0-9-]{0,79}$'or r.review_on is null or not isfinite(r.review_on)or jsonb_typeof(r.targets)is distinct from 'array'or jsonb_array_length(r.targets)>20 or not exists(select 1 from public.term_memberships tm join public.members mm on mm.id=tm.member_id where tm.term_id=p_term_id and tm.member_id=r.owner_id and tm.membership_kind='core'and tm.status='active'and tm.joined_at<=statement_timestamp()and tm.ends_at>statement_timestamp()and mm.account_state='active')or(r.service_id is not null and not exists(select 1 from public.org_units where id=r.service_id and term_id=p_term_id and archived_at is null))then raise exception using errcode='22023',message='command_validation_failed';end if;
 if publish and visibility='core'and(p_values->>'coreSafe')is distinct from 'true'then raise exception using errcode='22023',message='command_validation_failed';end if;
 for target in select value from jsonb_array_elements(r.targets)loop
 if jsonb_typeof(target)<>'object'or(target->>'kind')is null or(target->>'kind')not in('resource','work')or jsonb_typeof(target->'id')is distinct from 'string'or exists(select 1 from jsonb_object_keys(target)k where k not in('kind','id'))then raise exception using errcode='22023',message='command_validation_failed';end if;
 if target->>'kind'='work'then if not exists(select 1 from public.work_items x where x.id=(target->>'id')::uuid and x.term_id=p_term_id and x.kind in('task','deliverable')and public.can_access_work(x.id,'detail'))then raise exception using errcode='42501',message='command_permission_denied';end if;
 else if not exists(select 1 from public.resources rr join public.work_items ww on ww.id=rr.work_item_id where rr.work_item_id=(target->>'id')::uuid and ww.term_id=p_term_id and app_private.resource_visible(rr.work_item_id))then raise exception using errcode='42501',message='command_permission_denied';end if;end if;end loop;
 if p_id is null then
 insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,p_term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;select id into status from public.status_definitions where term_id=p_term_id and resource_kind='announcement'and stable_key='draft';select display_name into owner_name from public.members where id=r.owner_id;
 insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,lead_unit_id,status_id)values(m.organization_id,p_term_id,'announcement','Resource entry','restricted',r.owner_id,owner_name,unit,status)returning *into w;
 insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
 insert into public.resources(work_item_id,visibility,kind,essential)values(w.id,visibility,kind,essential);
 else perform set_config('app.resource_write',w.id::text,true);select display_name into owner_name from public.members where id=r.owner_id;update public.work_items set owner_member_id=r.owner_id,owner_display_name=owner_name where id=w.id returning *into w;end if;
 insert into public.resource_aliases values(p_term_id,r.alias,w.id)on conflict(term_id,alias)do nothing;
 if not exists(select 1 from public.resource_aliases where term_id=p_term_id and alias=r.alias and resource_id=w.id)then raise exception using errcode='22023',message='resource_alias_unavailable';end if;
 insert into public.resource_versions values(w.id,w.version,r.label,r.body,r.alias,r.owner_id,r.review_on,r.service_id,r.targets,publish,auth.uid(),statement_timestamp());
 if publish then update public.resources set published_version=w.version where work_item_id=w.id;end if;
 return app_private.finish_work_command(w,'save_resource',p_request_id,payload,jsonb_build_object('id',w.id,'version',w.version),'["resource_revision"]');end$$;
create function app_private.resource_projection(p_resource_id uuid,rev integer,editing boolean)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r public.resources;v public.resource_versions;w public.work_items;links jsonb:='[]';safe_targets jsonb:='[]';target jsonb;x public.work_items;begin
 select *into r from public.resources where work_item_id=p_resource_id;select *into w from public.work_items where work_items.id=p_resource_id;select *into v from public.resource_versions where resource_id=p_resource_id and version=rev;
 for target in select value from jsonb_array_elements(v.targets)loop
 if target->>'kind'='work'then select *into x from public.work_items where work_items.id=(target->>'id')::uuid and term_id=w.term_id and kind in('task','deliverable')and public.can_access_work(work_items.id,'detail');
 if found then safe_targets:=safe_targets||jsonb_build_array(target);links:=links||jsonb_build_array(jsonb_build_object('label',x.title,'href',case x.kind when 'task'then '/tasks/'else '/deliverables/'end||x.id));end if;
 elsif app_private.resource_visible((target->>'id')::uuid)then safe_targets:=safe_targets||jsonb_build_array(target);links:=links||jsonb_build_array(jsonb_build_object('label','Related guidance','href','/resources?resource='||(target->>'id')));end if;end loop;
 return jsonb_build_object('id',p_resource_id,'version',w.version,'publishedVersion',r.published_version,'label',v.label,'body',v.body,'alias',v.alias,'ownerId',v.owner_id,'ownerName',(select display_name from public.members where members.id=v.owner_id),'reviewOn',v.review_on,'reviewDue',v.review_on<=(statement_timestamp()at time zone'Asia/Manila')::date,'serviceId',v.service_id,'visibility',r.visibility,'unitId',w.lead_unit_id,'kind',r.kind,'essential',r.essential,'links',links,'canEdit',editing,'targets',case when editing then safe_targets else '[]'::jsonb end);
 end$$;
create function public.read_resources(p_term_id uuid,p_alias text default null)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;r record;items jsonb:='[]';drafts jsonb:='[]';progress jsonb;begin
 -- Guests receive no core directory or guide fallback; essential static help remains in the UI.
 m:=app_private.request_actor(p_term_id);
 for r in select rr.*,w.version,w.lead_unit_id from public.resources rr join public.work_items w on w.id=rr.work_item_id where w.term_id=p_term_id and w.archived_at is null and(p_alias is null or exists(select 1 from public.resource_aliases a where a.term_id=p_term_id and a.alias=p_alias and a.resource_id=rr.work_item_id))order by rr.work_item_id loop
 if app_private.resource_visible(r.work_item_id)then items:=items||jsonb_build_array(app_private.resource_projection(r.work_item_id,r.published_version,app_private.resource_editor(p_term_id,r.visibility,r.lead_unit_id)));end if;
 if app_private.resource_editor(p_term_id,r.visibility,r.lead_unit_id)then drafts:=drafts||jsonb_build_array(app_private.resource_projection(r.work_item_id,r.version,true));end if;end loop;
 select coalesce(jsonb_agg(jsonb_build_object('item',item,'revision',revision,'state',state,'version',version)),'[]')into progress from public.onboarding_progress where term_membership_id=m.id;
 return jsonb_build_object('items',items,'drafts',drafts,'progress',progress,'checklistVersion',1,'canPublishCore',app_private.resource_editor(p_term_id,'core',null),'managedUnits',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name))from public.org_units where term_id=p_term_id and archived_at is null and app_private.resource_editor(p_term_id,'unit',id)),'[]'));
 end$$;
create function public.set_onboarding_progress(p_term_id uuid,p_item text,p_revision integer,p_state text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;old public.onboarding_progress;payload jsonb;result jsonb;rid uuid;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.request_actor(p_term_id,true);
 if p_item is null or p_state is null or p_state not in('done','skipped')or(p_state='skipped'and p_item<>'tour')or p_revision is null or p_revision<1 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_item like 'guide:%'then rid:=substring(p_item from 7)::uuid;
 if not exists(select 1 from public.resources rr join public.work_items w on w.id=rr.work_item_id where rr.work_item_id=rid and w.term_id=p_term_id and rr.published_version=p_revision and app_private.resource_visible(rid))then raise exception using errcode='42501',message='command_permission_denied';end if;
 elsif p_item not in('profile','contacts','work','gates','practice','tour')or p_revision<>1 then raise exception using errcode='22023',message='command_validation_failed';end if;
 payload:=jsonb_build_array(p_term_id,p_item,p_revision,p_state,p_expected_version);result:=app_private.begin_work_command('set_onboarding_progress',p_request_id,payload);if result is not null then return result;end if;
 select *into old from public.onboarding_progress where term_membership_id=m.id and item=p_item and revision=p_revision for update;
 if coalesce(old.version,0)is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 insert into public.onboarding_progress values(m.id,p_item,p_revision,p_state,coalesce(old.version,0)+1,statement_timestamp())on conflict(term_membership_id,item,revision)do update set state=excluded.state,version=excluded.version,updated_at=excluded.updated_at;
 result:=jsonb_build_object('version',coalesce(old.version,0)+1);
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'set_onboarding_progress',p_request_id,m.organization_id,p_term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),result);
 -- Own progress contains no private profile values and triggers no real work/FIN/outbox command.
 return result;end$$;
revoke all on function app_private.resource_editor(uuid,text,uuid),app_private.resource_visible(uuid),app_private.resource_spine_guard(),app_private.resource_projection(uuid,integer,boolean)from public,anon,authenticated,service_role;
revoke all on function public.save_resource(uuid,uuid,jsonb,integer,uuid),public.read_resources(uuid,text),public.set_onboarding_progress(uuid,text,integer,text,integer,uuid)from public,anon,authenticated,service_role;
grant execute on function public.save_resource(uuid,uuid,jsonb,integer,uuid),public.read_resources(uuid,text),public.set_onboarding_progress(uuid,text,integer,text,integer,uuid)to authenticated;
