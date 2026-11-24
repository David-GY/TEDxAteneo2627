begin;
-- P45 bounded roster-add batch. Reuse P33 publication; do not provision logins,
-- deployments or roles. Private drafts never become ordinary announcement content.
create table app_private.roster_import_sessions(
 id uuid primary key references public.announcements(work_item_id),term_id uuid not null references public.terms(id),
 actor_id uuid not null references auth.users(id),list_name text not null check(length(btrim(list_name))between 1 and 80),list_key text not null,
 version integer not null check(version>0),state text not null check(state in('draft','committed')),updated_at timestamptz not null default statement_timestamp()
);
create index roster_import_owner on app_private.roster_import_sessions(actor_id,term_id,updated_at desc,id);
create table app_private.roster_import_revisions(
 session_id uuid not null references app_private.roster_import_sessions(id),version integer not null,input jsonb not null,
 joined_at timestamptz not null,ends_at timestamptz not null,recorded_at timestamptz not null default statement_timestamp(),primary key(session_id,version),
 check(isfinite(joined_at)and isfinite(ends_at)and joined_at<ends_at)
);
create table app_private.roster_import_bindings(
 term_id uuid not null references public.terms(id),list_key text not null,source_key text not null,
 membership_id uuid not null references public.term_memberships(id),session_id uuid not null references app_private.roster_import_sessions(id),created_at timestamptz not null default statement_timestamp(),
 primary key(term_id,list_key,source_key),unique(term_id,list_key,membership_id)
);
create table app_private.roster_import_commits(
 session_id uuid primary key references app_private.roster_import_sessions(id),review_hash text not null,result jsonb not null,committed_at timestamptz not null default statement_timestamp()
);
do $$declare t text;begin foreach t in array array['roster_import_sessions','roster_import_revisions','roster_import_bindings','roster_import_commits']loop
 execute format('alter table app_private.%I enable row level security',t);execute format('alter table app_private.%I force row level security',t);
 execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',t);
 if t<>'roster_import_sessions'then execute format('create trigger immutable_roster_import_history before update or delete on app_private.%I for each row execute function app_private.request_history_guard()',t);end if;
end loop;end$$;
create function app_private.roster_import_control_guard()returns trigger language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from app_private.roster_import_sessions where id=old.id)then
  if tg_op='DELETE'or current_setting('app.roster_import_write',true)is distinct from 'approved'then raise exception using errcode='42501',message='command_permission_denied';end if;
  if(new.title,new.safe_summary,new.owner_member_id,new.owner_display_name,new.lead_unit_id,new.status_id,new.archived_at)is distinct from(old.title,old.safe_summary,old.owner_member_id,old.owner_display_name,old.lead_unit_id,old.status_id,old.archived_at)then raise exception using errcode='42501',message='command_permission_denied';end if;
 end if;if tg_op='DELETE'then return old;end if;return new;
end$$;
create trigger roster_import_control_guard before update or delete on public.work_items for each row execute function app_private.roster_import_control_guard();
create function app_private.roster_import_announcement_guard()returns trigger language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from app_private.roster_import_sessions where id=old.work_item_id)then raise exception using errcode='42501',message='command_permission_denied';end if;if tg_op='DELETE'then return old;end if;return new;
end$$;
create trigger roster_import_announcement_guard before update or delete on public.announcements for each row execute function app_private.roster_import_announcement_guard();
create function app_private.roster_import_session(id uuid)returns app_private.roster_import_sessions
language plpgsql stable security definer set search_path='' as $$declare d app_private.roster_import_sessions;begin
 select *into d from app_private.roster_import_sessions s where s.id=roster_import_session.id and s.actor_id=auth.uid();
 if not found then raise exception using errcode='42501',message='command_permission_denied';end if;
 perform app_private.organization_actor(d.term_id,true);return d;
end$$;
create function app_private.roster_import_schema(input jsonb)returns void language plpgsql immutable set search_path='' as $$begin
 if not coalesce(app_private.definition_keys(input,array['header','mapping','rows']),false)or not(input?&array['header','mapping','rows'])or octet_length(input::text)>200000
  or jsonb_typeof(input->'header')<>'array'or jsonb_typeof(input->'mapping')<>'object'or jsonb_typeof(input->'rows')<>'array'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if jsonb_array_length(input->'header')not between 3 and 32 or jsonb_array_length(input->'rows')not between 1 and 50
  or exists(select 1 from jsonb_array_elements(input->'header')h where jsonb_typeof(h)<>'string'or length(btrim(h#>>'{}'))not between 1 and 120)
  or(select count(*)<>count(distinct lower(btrim(h)))from jsonb_array_elements_text(input->'header')h)
  or exists(select 1 from jsonb_array_elements_text(input->'header')h where lower(h)~'(^|[^a-z])(roles?|admin|permissions?|capabilit(y|ies)|privileges?|amount|cost|centavos|financial|money|auth|identity|status|deployment|membership|query|script)([^a-z]|$)')
  or not app_private.definition_keys(input->'mapping',array['source_key','display_name','email'])
  or exists(select 1 from jsonb_each(input->'mapping')e where jsonb_typeof(e.value)<>'string'or not exists(select 1 from jsonb_array_elements(input->'header')h where h=e.value))
  or(select count(*)<>count(distinct value)from jsonb_each_text(input->'mapping'))
  or coalesce(input->'mapping'->>'source_key','')=''or coalesce(input->'mapping'->>'display_name','')=''or coalesce(input->'mapping'->>'email','')=''
  then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from jsonb_array_elements(input->'rows')r where jsonb_typeof(r)<>'array')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from jsonb_array_elements(input->'rows')r cross join lateral jsonb_array_elements(r)c where jsonb_typeof(c)<>'string'or length(c#>>'{}')>2000)then raise exception using errcode='22023',message='command_validation_failed';end if;
end$$;
create function app_private.roster_import_plan(d app_private.roster_import_sessions)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;rev app_private.roster_import_revisions;row jsonb;v jsonb;rows jsonb:='[]';errors jsonb;idx integer;record integer:=1;field text;source text;bound uuid;
 person public.members;tm public.term_memberships;before_value jsonb;after_value jsonb;operation text;cols jsonb;impact jsonb;
begin
 m:=app_private.organization_actor(d.term_id,true);
 select *into rev from app_private.roster_import_revisions r where r.session_id=d.id and r.version=d.version;
 perform app_private.roster_import_schema(rev.input);
 for row in select value from jsonb_array_elements(rev.input->'rows')loop
  record:=record+1;v:='{}';errors:='[]';bound:=null;person:=null;tm:=null;before_value:=null;operation:='create';impact:=null;
  foreach field in array array['source_key','display_name','email']loop
   source:=rev.input->'mapping'->>field;select ord::integer-1 into idx from jsonb_array_elements_text(rev.input->'header')with ordinality h(name,ord)where h.name=source;
   v:=v||jsonb_build_object(field,coalesce(row->>idx,''));
  end loop;
  v:=v||jsonb_build_object('email',lower(btrim(v->>'email')),'display_name',btrim(v->>'display_name'));
  if jsonb_array_length(row)<>jsonb_array_length(rev.input->'header')then errors:=errors||'"Repair the cell count for this CSV record."'::jsonb;end if;
  if v->>'source_key'!~'^[a-zA-Z0-9][a-zA-Z0-9._:-]{0,99}$'then errors:=errors||'"Enter a stable source key of 1–100 letters, digits, dots, colons, hyphens or underscores."'::jsonb;end if;
  if length(v->>'display_name')not between 1 and 200 then errors:=errors||'"Enter a person’s name of 1–200 characters."'::jsonb;end if;
  if v->>'email'!~'^[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@student[.]ateneo[.]edu$'then errors:=errors||'"Use an exact student.ateneo.edu school email."'::jsonb;end if;
  select b.membership_id into bound from app_private.roster_import_bindings b where b.term_id=d.term_id and b.list_key=d.list_key and b.source_key=v->>'source_key';
  select *into person from public.members where organization_id=m.organization_id and normalized_email=v->>'email';
  if person.id is not null then
   select *into tm from public.term_memberships where term_id=d.term_id and member_id=person.id and membership_kind='core';
   if tm.id is null or tm.status<>'active'or person.account_state<>'active'then
    errors:=errors||'"Candidate is unavailable here. Use the reviewed organization workflow."'::jsonb;tm:=null;person:=null;
   elsif person.display_name is distinct from v->>'display_name'then errors:=errors||'"Existing name differs. Review changes on the organization page; CSV never renames people."'::jsonb;
   end if;
  end if;
  if bound is not null and bound is distinct from tm.id then
   errors:='["Source row is unavailable here. Keep its original school email and source key."]';tm:=null;person:=null;
  end if;
  if tm.id is not null then
   operation:='unchanged';before_value:=jsonb_build_object('name',person.display_name,'email',person.normalized_email,'status',tm.status,'joinedAt',tm.joined_at,'endsAt',tm.ends_at);
   after_value:=before_value;
   if exists(select 1 from app_private.roster_import_bindings b where b.term_id=d.term_id and b.list_key=d.list_key and b.membership_id=tm.id and b.source_key<>v->>'source_key')then errors:=errors||'"Keep the original source key for this person in this list."'::jsonb;end if;
  else
   after_value:=jsonb_build_object('name',v->>'display_name','email',v->>'email','status','active','joinedAt',rev.joined_at,'endsAt',rev.ends_at);
   if jsonb_array_length(errors)=0 then
    impact:=public.preview_organization_change(d.term_id,'roster_add',jsonb_build_object('name',v->>'display_name','email',v->>'email','joinedAt',rev.joined_at,'endsAt',rev.ends_at));
    if(impact->>'blocked')::boolean then errors:=errors||'"Resolve this candidate on the organization page."'::jsonb;end if;
   end if;
  end if;
  if(select count(*)from jsonb_array_elements(rev.input->'rows')r where r->>((select ord::integer-1 from jsonb_array_elements_text(rev.input->'header')with ordinality h(name,ord)where name=rev.input->'mapping'->>'source_key'))=v->>'source_key')>1 then errors:=errors||'"Duplicate source key; repair every matching record."'::jsonb;end if;
  if(select count(*)from jsonb_array_elements(rev.input->'rows')r where lower(btrim(r->>((select ord::integer-1 from jsonb_array_elements_text(rev.input->'header')with ordinality h(name,ord)where name=rev.input->'mapping'->>'email'))))=v->>'email')>1 then errors:=errors||'"Duplicate school email; repair every matching record."'::jsonb;end if;
  -- Only supplied input and selected-term core identity details may appear here.
  rows:=rows||jsonb_build_object('record',record,'sourceKey',v->>'source_key','operation',operation,'targetId',tm.id,'memberId',case when tm.id is not null then person.id end,'expectedMembershipVersion',tm.version,'expectedMemberVersion',case when tm.id is not null then person.version end,'before',before_value,'after',after_value,'errors',errors);
 end loop;
 cols:=jsonb_build_object('draftId',d.id,'version',d.version,'termId',d.term_id,'termLabel',(select label from public.terms where id=d.term_id),'listName',d.list_name,'joinedAt',rev.joined_at,'endsAt',rev.ends_at,'rows',rows,'valid',not exists(select 1 from jsonb_array_elements(rows)r where jsonb_array_length(r->'errors')>0),
  'organizationFingerprint',app_private.organization_fingerprint(d.term_id,'roster_import','{}'));
 return cols||jsonb_build_object('reviewHash',encode(sha256(convert_to(cols::text,'UTF8')),'hex'));
end$$;
create function public.save_roster_import(p_term_id uuid,p_list_name text,p_joined_at timestamptz,p_ends_at timestamptz,p_input jsonb,p_draft_id uuid,p_expected_version integer,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$declare m public.term_memberships;d app_private.roster_import_sessions;w public.work_items;payload jsonb;result jsonb;status uuid;begin
 perform app_private.readiness_lock(p_term_id);m:=app_private.organization_actor(p_term_id,true);perform set_config('app.roster_import_write','approved',true);
 if p_list_name is null or length(btrim(p_list_name))not between 1 and 80 or p_expected_version is null or p_joined_at is null or p_ends_at is null or not isfinite(p_joined_at)or not isfinite(p_ends_at)or p_joined_at>=p_ends_at then raise exception using errcode='22023',message='command_validation_failed';end if;
 perform app_private.roster_import_schema(p_input);
 if p_draft_id is not null then d:=app_private.roster_import_session(p_draft_id);if d.term_id<>p_term_id or d.list_key<>lower(btrim(p_list_name))then raise exception using errcode='42501',message='command_permission_denied';end if;end if;
 payload:=jsonb_build_array(p_term_id,p_list_name,p_joined_at,p_ends_at,p_input,p_draft_id,p_expected_version);result:=app_private.begin_work_command('save_roster_import',p_request_id,payload);if result is not null then perform app_private.roster_import_session((result->>'draftId')::uuid);return result;end if;
 if p_draft_id is null then
  if p_expected_version<>0 then raise exception using errcode='40001',message='command_stale_version';end if;
  insert into public.status_definitions(organization_id,term_id,resource_kind,stable_key,semantic_category,label)values(m.organization_id,p_term_id,'announcement','draft','draft','Draft')on conflict(term_id,resource_kind,stable_key)do nothing;
  select id into status from public.status_definitions where term_id=p_term_id and resource_kind='announcement'and stable_key='draft';
  insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,status_id)values(m.organization_id,p_term_id,'announcement','Roster CSV import control','restricted',m.member_id,(select display_name from public.members where id=m.member_id),status)returning *into w;
  insert into public.announcements(work_item_id,organization_id,term_id)values(w.id,w.organization_id,w.term_id);
  insert into app_private.roster_import_sessions values(w.id,p_term_id,auth.uid(),btrim(p_list_name),lower(btrim(p_list_name)),1,'draft',statement_timestamp())returning *into d;
 else
  if d.state<>'draft'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
  if d.version<>p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
  update public.work_items set updated_at=statement_timestamp()where id=d.id returning *into w;
  update app_private.roster_import_sessions set version=version+1,updated_at=statement_timestamp()where id=d.id returning *into d;
 end if;
 insert into app_private.roster_import_revisions values(d.id,d.version,p_input,p_joined_at,p_ends_at,statement_timestamp());
 return app_private.finish_work_command(w,'save_roster_import',p_request_id,payload,jsonb_build_object('draftId',d.id,'version',d.version,'state',d.state),'["private_roster_import_draft"]');
end$$;
create function public.read_roster_import(p_term_id uuid,p_draft_id uuid default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$declare d app_private.roster_import_sessions;begin
 perform app_private.organization_actor(p_term_id,true);
 if p_draft_id is not null then d:=app_private.roster_import_session(p_draft_id);if d.term_id<>p_term_id then raise exception using errcode='42501',message='command_permission_denied';end if;end if;
 return jsonb_build_object('drafts',coalesce((select jsonb_agg(jsonb_build_object('draftId',s.id,'listName',s.list_name,'version',s.version,'state',s.state)order by s.updated_at desc,s.id)from(select *from app_private.roster_import_sessions s where s.term_id=p_term_id and s.actor_id=auth.uid()order by s.updated_at desc,s.id limit 20)s),'[]'),
 'draft',case when d.id is not null then(select jsonb_build_object('draftId',d.id,'version',d.version,'termId',d.term_id,'listName',d.list_name,'state',d.state,'input',r.input,'joinedAt',r.joined_at,'endsAt',r.ends_at,'receipt',(select c.result from app_private.roster_import_commits c where c.session_id=d.id))from app_private.roster_import_revisions r where r.session_id=d.id order by r.version desc limit 1)end);
end$$;
create function public.preview_roster_import(p_draft_id uuid,p_expected_version integer)returns jsonb
language plpgsql stable security definer set search_path='' as $$declare d app_private.roster_import_sessions;begin
 d:=app_private.roster_import_session(p_draft_id);
 if d.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if d.state<>'draft'then raise exception using errcode='55000',message='command_dependency_blocked';end if;return app_private.roster_import_plan(d);
end$$;
create function public.commit_roster_import(p_draft_id uuid,p_expected_version integer,p_review_hash text,p_reason text,p_request_id uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare d app_private.roster_import_sessions;w public.work_items;plan jsonb;row jsonb;payload jsonb;result jsonb;items jsonb:='[]';values jsonb;impact jsonb;target uuid;created integer:=0;unchanged integer:=0;
begin
 d:=app_private.roster_import_session(p_draft_id);perform app_private.readiness_lock(d.term_id);d:=app_private.roster_import_session(p_draft_id);
 payload:=jsonb_build_array(p_draft_id,p_expected_version,p_review_hash,p_reason);result:=app_private.begin_work_command('commit_roster_import',p_request_id,payload);if result is not null then return result;end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 1000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if d.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if d.state<>'draft'then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 -- P33's term readiness lock serializes organization commands in this term.
 -- Block cross-term identity inserts/edits too while resolving this bounded file.
 lock table public.members,public.term_memberships in share row exclusive mode;
 plan:=app_private.roster_import_plan(d);
 if p_review_hash is distinct from plan->>'reviewHash'then raise exception using errcode='40001',message='command_stale_version';end if;
 if not(plan->>'valid')::boolean then raise exception using errcode='22023',message='command_validation_failed';end if;
 for row in select value from jsonb_array_elements(plan->'rows')loop
  target:=(row->>'targetId')::uuid;
  if row->>'operation'='create'then
   values:=(row->'after')-'status';impact:=public.preview_organization_change(d.term_id,'roster_add',values);
   -- Earlier rows change P33's version/fingerprint inside this same transaction;
   -- refresh only that command proof, after the complete file was verified above.
   result:=public.publish_organization_change(d.term_id,'roster_add',values,(impact->>'version')::integer,impact->>'fingerprint',p_reason,gen_random_uuid());
   target:=(result->>'id')::uuid;created:=created+1;
  else unchanged:=unchanged+1;end if;
  insert into app_private.roster_import_bindings(term_id,list_key,source_key,membership_id,session_id)values(d.term_id,d.list_key,row->>'sourceKey',target,d.id)on conflict(term_id,list_key,source_key)do nothing;
  if not exists(select 1 from app_private.roster_import_bindings b where b.term_id=d.term_id and b.list_key=d.list_key and b.source_key=row->>'sourceKey'and b.membership_id=target)then raise exception using errcode='40001',message='command_stale_version';end if;
  items:=items||jsonb_build_object('sourceKey',row->>'sourceKey','membershipId',target,'memberId',(select member_id from public.term_memberships where id=target),'name',row->'after'->>'name','action',row->>'operation');
 end loop;
 perform set_config('app.roster_import_write','approved',true);
 update public.work_items set updated_at=statement_timestamp()where id=d.id returning *into w;
 update app_private.roster_import_sessions set version=version+1,state='committed',updated_at=statement_timestamp()where id=d.id returning *into d;
 result:=jsonb_build_object('draftId',d.id,'version',d.version,'termId',d.term_id,'state','committed','items',items,'created',created,'unchanged',unchanged);
 insert into app_private.roster_import_commits values(d.id,p_review_hash,result,statement_timestamp());
 return app_private.finish_work_command(w,'commit_roster_import',p_request_id,payload,result,'["roster_import_commit"]');
end$$;
revoke all on function app_private.roster_import_control_guard(),app_private.roster_import_announcement_guard(),app_private.roster_import_session(uuid),app_private.roster_import_schema(jsonb),app_private.roster_import_plan(app_private.roster_import_sessions)from public,anon,authenticated,service_role;
revoke all on function public.save_roster_import(uuid,text,timestamptz,timestamptz,jsonb,uuid,integer,uuid),public.read_roster_import(uuid,uuid),public.preview_roster_import(uuid,integer),public.commit_roster_import(uuid,integer,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.save_roster_import(uuid,text,timestamptz,timestamptz,jsonb,uuid,integer,uuid),public.read_roster_import(uuid,uuid),public.preview_roster_import(uuid,integer),public.commit_roster_import(uuid,integer,text,text,uuid)to authenticated;
commit;
