-- P31 local calendar. No Google IDs, tokens, sync job, room reservation or external delivery.
create table public.calendar_events(
 work_item_id uuid primary key references public.announcements(work_item_id),visibility text not null check(visibility in('core','unit','restricted')),
 title text not null check(length(btrim(title))between 1 and 240),description text not null default ''check(length(description)<=4000),location text not null default ''check(length(location)<=1000),
 all_day boolean not null,start_on date,end_on date,starts_at timestamptz,ends_at timestamptz,state text not null check(state in('confirmed','cancelled')),
 check((all_day and start_on is not null and end_on is not null and end_on>start_on and starts_at is null and ends_at is null)or(not all_day and starts_at is not null and ends_at is not null and ends_at>starts_at and start_on is null and end_on is null)),
 check(start_on is null or isfinite(start_on)and isfinite(end_on)),check(starts_at is null or isfinite(starts_at)and isfinite(ends_at))
);
create table public.calendar_event_versions(
 work_item_id uuid not null references public.calendar_events(work_item_id),version integer not null,actor_id uuid not null references auth.users(id),snapshot jsonb not null,reason text not null,
 recorded_at timestamptz not null default statement_timestamp(),primary key(work_item_id,version)
);
alter table public.calendar_events enable row level security;alter table public.calendar_events force row level security;
alter table public.calendar_event_versions enable row level security;alter table public.calendar_event_versions force row level security;
revoke all on public.calendar_events,public.calendar_event_versions from public,anon,authenticated,service_role;
create trigger immutable_calendar_history before update or delete on public.calendar_event_versions for each row execute function app_private.request_history_guard();
create function app_private.calendar_editor(term uuid,visibility text,unit uuid,owner uuid)returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_memberships tm join public.terms t on t.id=tm.term_id where tm.id=public.current_term_membership(term)and tm.membership_kind='core'and t.state='active'and public.has_capability(term,'workspace.read')and case visibility when 'core'then public.has_capability(term,'admin.configure')when 'unit'then unit is not null and public.has_capability(term,'committee.manage',unit)when 'restricted'then tm.member_id=owner else false end)
$$;
create function app_private.calendar_visible(w public.work_items,e public.calendar_events)returns boolean language sql stable security definer set search_path='' as $$
 select w.archived_at is null and(
 (e.visibility='core'and public.has_capability(w.term_id,'workspace.read'))or
 (e.visibility='unit'and public.has_capability(w.term_id,'workspace.read')and exists(select 1 from public.unit_memberships d join public.org_units u on u.id=d.unit_id where d.term_membership_id=public.current_term_membership(w.term_id)and d.unit_id=w.lead_unit_id and d.status='active'and d.effective_from<=statement_timestamp()and d.effective_to>statement_timestamp()and u.archived_at is null))or
 public.can_access_work(w.id,'detail'))
$$;
create function app_private.calendar_spine_guard()returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.calendar_events where work_item_id=old.id)and current_setting('app.calendar_write',true)is distinct from old.id::text and(new.title,new.safe_summary,new.lead_unit_id,new.owner_member_id,new.archived_at)is distinct from(old.title,old.safe_summary,old.lead_unit_id,old.owner_member_id,old.archived_at)then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger protect_calendar_spine before update on public.work_items for each row execute function app_private.calendar_spine_guard();

create function public.save_calendar_event(p_term_id uuid,p_work_item_id uuid default null,p_values jsonb default null,p_expected_version integer default null,p_request_id uuid default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;w public.work_items;old public.calendar_events;e public.calendar_events;term public.terms;unit uuid;owner uuid;status uuid;payload jsonb;result jsonb;reason text;name text;day_start date;day_end date;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.request_actor(p_term_id,true);select *into term from public.terms where id=p_term_id;
 if p_work_item_id is not null then select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id for update;select *into old from public.calendar_events where work_item_id=w.id;if old.work_item_id is null or not app_private.calendar_editor(p_term_id,old.visibility,w.lead_unit_id,w.owner_member_id)then raise exception using errcode='42501',message='command_permission_denied';end if;owner:=w.owner_member_id;else owner:=m.member_id;end if;
 if jsonb_typeof(p_values)is distinct from 'object'or exists(select 1 from jsonb_object_keys(p_values)k where k not in('title','description','location','visibility','unitId','allDay','startOn','endOn','startsAt','endsAt','state','coreSafe','reason'))then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from jsonb_each(p_values)f where(f.key in('title','description','location','visibility','state','reason')and jsonb_typeof(f.value)<>'string')or(f.key in('allDay','coreSafe')and jsonb_typeof(f.value)<>'boolean')or(f.key in('unitId','startOn','endOn','startsAt','endsAt')and jsonb_typeof(f.value)not in('string','null')))then raise exception using errcode='22023',message='command_validation_failed';end if;
 unit:=nullif(p_values->>'unitId','')::uuid;
 if not app_private.calendar_editor(p_term_id,p_values->>'visibility',unit,owner)or(unit is not null and not exists(select 1 from public.org_units where id=unit and term_id=p_term_id and archived_at is null))then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_term_id,p_work_item_id,p_values,p_expected_version);result:=app_private.begin_work_command('save_calendar_event',p_request_id,payload);if result is not null then return result;end if;
 if(p_work_item_id is null and p_expected_version is distinct from 0)or(p_work_item_id is not null and w.version is distinct from p_expected_version)then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_values->>'visibility'='core'and(p_values->>'coreSafe')is distinct from 'true'then raise exception using errcode='22023',message='command_validation_failed';end if;
 e.title:=btrim(p_values->>'title');e.description:=p_values->>'description';e.location:=p_values->>'location';e.visibility:=p_values->>'visibility';e.all_day:=(p_values->>'allDay')::boolean;e.state:=p_values->>'state';reason:=btrim(p_values->>'reason');
 if e.title is null or length(e.title)not between 1 and 240 or e.description is null or length(e.description)>4000 or e.location is null or length(e.location)>1000 or e.state is null or e.state not in('confirmed','cancelled')or e.all_day is null or reason is null or length(reason)not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if e.all_day then
 if(p_values->>'startOn')!~'^\d{4}-\d{2}-\d{2}$'or(p_values->>'endOn')!~'^\d{4}-\d{2}-\d{2}$'or p_values->>'startsAt'is not null or p_values->>'endsAt'is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 e.start_on:=(p_values->>'startOn')::date;e.end_on:=(p_values->>'endOn')::date;day_start:=e.start_on;day_end:=e.end_on-1;
 else
 if(p_values->>'startsAt')!~'^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'or(p_values->>'endsAt')!~'^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'or p_values->>'startOn'is not null or p_values->>'endOn'is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 e.starts_at:=(p_values->>'startsAt')::timestamptz;e.ends_at:=(p_values->>'endsAt')::timestamptz;day_start:=(e.starts_at at time zone'Asia/Manila')::date;day_end:=((e.ends_at-interval'1 microsecond')at time zone'Asia/Manila')::date;
 end if;
 if(e.all_day and e.end_on<=e.start_on)or(not e.all_day and e.ends_at<=e.starts_at)or day_start is null or day_end is null or not isfinite(day_start)or not isfinite(day_end)or day_start<term.starts_on or day_end>term.closes_on or day_end<day_start then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_work_item_id is null then
 insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,p_term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;select id into status from public.status_definitions where term_id=p_term_id and resource_kind='announcement'and stable_key='draft'and semantic_category='draft';select display_name into name from public.members where id=m.member_id;
 insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,lead_unit_id,status_id)values(m.organization_id,p_term_id,'announcement','Calendar entry','restricted',m.member_id,name,unit,status)returning *into w;
 insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
 else perform set_config('app.calendar_write',w.id::text,true);update public.work_items set lead_unit_id=unit where id=w.id returning *into w;end if;
 e.work_item_id:=w.id;
 insert into public.calendar_events values(e.*)on conflict(work_item_id)do update set visibility=excluded.visibility,title=excluded.title,description=excluded.description,location=excluded.location,all_day=excluded.all_day,start_on=excluded.start_on,end_on=excluded.end_on,starts_at=excluded.starts_at,ends_at=excluded.ends_at,state=excluded.state;
 insert into public.calendar_event_versions(work_item_id,version,actor_id,snapshot,reason)values(w.id,w.version,auth.uid(),to_jsonb(e),reason);
 return app_private.finish_work_command(w,'save_calendar_event',p_request_id,payload,jsonb_build_object('workItemId',w.id,'key','local:'||w.id,'version',w.version),'["calendar_event"]');end$$;

create function app_private.calendar_rows(term uuid)returns setof jsonb language plpgsql stable security definer set search_path='' as $$declare w public.work_items;e public.calendar_events;kind text;dt date;start_at timestamptz;state text;title text;ordinary boolean;begin
 for w in select wi.*from public.work_items wi where wi.term_id=term and wi.archived_at is null and wi.kind in('announcement','task','deliverable')loop
 if w.kind='announcement'then
 select *into e from public.calendar_events where work_item_id=w.id;if e.work_item_id is null or not app_private.calendar_visible(w,e)then continue;end if;
 return next jsonb_build_object('key','local:'||w.id,'version',w.version,'title',e.title,'description',e.description,'location',e.location,'visibility',e.visibility,'unitId',w.lead_unit_id,'allDay',e.all_day,'startOn',e.start_on,'endOn',e.end_on,'startsAt',e.starts_at,'endsAt',e.ends_at,'state',e.state,'updatedAt',w.updated_at,'source','local','href',null,'canEdit',app_private.calendar_editor(term,e.visibility,w.lead_unit_id,w.owner_member_id),'exportAllowed',e.visibility='core'and public.has_capability(term,'workspace.read'));
 else
 if not public.can_access_work(w.id,case when w.classification='ordinary'and w.kind='deliverable'then 'summary'else 'detail'end)then continue;end if;
 ordinary:=w.classification='ordinary';select case when w.kind='task'then(select workflow_state from public.tasks where work_item_id=w.id)else(select workflow_state from public.deliverables where work_item_id=w.id)end into state;
 title:=case when ordinary then w.title else 'Private '||w.kind end;
 foreach kind in array array['start','deadline']loop
 dt:=case when kind='start'then w.planned_start_on else w.due_on end;start_at:=case when kind='deadline'and w.due_on is null then w.due_at end;if dt is null and start_at is null then continue;end if;
 return next jsonb_build_object('key',kind||':'||w.id,'version',w.version,'title',case kind when 'start'then 'Planned start · 'else 'Deadline · 'end||title,'description','Source-linked '||kind||'. Work remains authoritative.'||case when start_at is not null then ' Timed deadline uses a one-minute calendar marker; the original deadline is unchanged.'else ''end,'location','','visibility',case when ordinary then 'core'else 'restricted'end,'unitId',w.lead_unit_id,'allDay',dt is not null,'startOn',dt,'endOn',dt+1,'startsAt',start_at,'endsAt',start_at+interval'1 minute','state',case when state='cancelled'then 'cancelled'else 'confirmed'end,'updatedAt',w.updated_at,'source',kind,'href',case w.kind when 'task'then '/tasks/'else '/deliverables/'end||w.id,'canEdit',false,'exportAllowed',ordinary and public.has_capability(term,'workspace.read'));
 end loop;end if;end loop;end$$;
create function public.read_calendar(p_term_id uuid,p_from date,p_to date,p_unit_id uuid default null,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare rows jsonb;total integer;opts jsonb;ctx jsonb;begin
 ctx:=public.resolve_auth_context();if ctx->>'state'is distinct from 'authorized'or ctx->>'termId'is distinct from p_term_id::text then raise exception using errcode='42501',message='command_permission_denied';end if;
 if p_from is null or p_to is null or not isfinite(p_from)or not isfinite(p_to)or p_to<=p_from or p_to-p_from>62 or p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 with permitted as materialized(select value r from app_private.calendar_rows(p_term_id)value),in_range as(select *from permitted where(case when(r->>'allDay')::boolean then(r->>'startOn')::date<p_to and(r->>'endOn')::date>p_from else(r->>'startsAt')::timestamptz<(p_to::timestamp at time zone'Asia/Manila')and(r->>'endsAt')::timestamptz>(p_from::timestamp at time zone'Asia/Manila')end)),filtered as(select *from in_range where p_unit_id is null or r->>'unitId'=p_unit_id::text),page as(select *from filtered order by coalesce(r->>'startOn',r->>'startsAt'),r->>'key'offset(p_page-1)*100 limit 100)
 select coalesce((select jsonb_agg(r order by coalesce(r->>'startOn',r->>'startsAt'),r->>'key')from page),'[]'),(select count(*)from filtered),coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)order by name,id)from public.org_units where id in(select(r->>'unitId')::uuid from in_range)),'[]')into rows,total,opts;
 return jsonb_build_object('items',rows,'total',total,'hasMore',p_page*100<total,'units',opts,'canCreate',app_private.calendar_editor(p_term_id,'restricted',null,app_private.synergy_actor(p_term_id)),'canPublishCore',app_private.calendar_editor(p_term_id,'core',null,null),'managedUnits',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)order by name,id)from public.org_units where term_id=p_term_id and archived_at is null and public.has_capability(p_term_id,'committee.manage',id)),'[]'),'refreshedAt',statement_timestamp());end$$;
create function public.read_calendar_event(p_term_id uuid,p_key text)returns jsonb language plpgsql stable security definer set search_path='' as $$declare ctx jsonb;begin
 ctx:=public.resolve_auth_context();if ctx->>'state'is distinct from 'authorized'or ctx->>'termId'is distinct from p_term_id::text then return null;end if;
 return(select value from app_private.calendar_rows(p_term_id)value where value->>'key'=p_key);end$$;

do $$declare f text;begin for f in select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_private'and p.proname like 'calendar_%'loop execute 'revoke all on function '||f||' from public,anon,authenticated,service_role';end loop;end$$;
revoke all on function public.save_calendar_event(uuid,uuid,jsonb,integer,uuid),public.read_calendar(uuid,date,date,uuid,integer),public.read_calendar_event(uuid,text)from public,anon,authenticated,service_role;
grant execute on function public.save_calendar_event(uuid,uuid,jsonb,integer,uuid),public.read_calendar(uuid,date,date,uuid,integer),public.read_calendar_event(uuid,text)to authenticated;
