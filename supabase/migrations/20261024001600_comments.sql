begin;
create table public.comments (
 id uuid primary key default gen_random_uuid(), work_item_id uuid not null references public.work_items(id),
 author_id uuid not null references public.members(id), author_name text not null, version integer not null default 1 check(version>0),
 state text not null check(state in ('draft','published','removed','redacted')),
 created_at timestamptz not null default statement_timestamp(), updated_at timestamptz not null default statement_timestamp(),
 unique(id,work_item_id)
);
create table public.comment_revisions (
 comment_id uuid not null references public.comments(id), revision integer not null check(revision>0),
 body text not null check(length(body)<=8000), reason text not null check(length(reason) between 1 and 2000),
 state text not null check(state in ('draft','published','removed','redacted')), mentions uuid[] not null default '{}',
 actor_id uuid not null references auth.users(id), recorded_at timestamptz not null default statement_timestamp(),
 primary key(comment_id,revision), check(cardinality(mentions)<=20)
);
create table public.comment_evidence (
 comment_id uuid not null, revision integer not null, purpose text not null check(purpose in ('task','submission','decision')),
 task_work_id uuid, task_version integer, deliverable_work_id uuid, deliverable_version integer,
 foreign key(comment_id,revision) references public.comment_revisions(comment_id,revision),
 foreign key(task_work_id,task_version) references public.task_revisions(work_item_id,work_version),
 foreign key(deliverable_work_id,deliverable_version) references public.deliverable_revisions(work_item_id,work_version),
 check((task_work_id is not null and task_version is not null and deliverable_work_id is null and deliverable_version is null)
 or (task_work_id is null and task_version is null and deliverable_work_id is not null and deliverable_version is not null))
);
create index comments_thread on public.comments(work_item_id,created_at,id);
create index comment_evidence_revision on public.comment_evidence(comment_id,revision);
create index comment_evidence_task on public.comment_evidence(task_work_id,task_version);
create index comment_evidence_deliverable on public.comment_evidence(deliverable_work_id,deliverable_version);
alter table public.comments enable row level security;
alter table public.comments force row level security;
alter table public.comment_revisions enable row level security;
alter table public.comment_revisions force row level security;
alter table public.comment_evidence enable row level security;
alter table public.comment_evidence force row level security;
revoke all on public.comments,public.comment_revisions,public.comment_evidence from public,anon,authenticated,service_role;
create function public.can_read_comment(p_comment_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.comments c where c.id=p_comment_id and public.can_access_work(c.work_item_id,'detail')
 and (c.state not in ('draft','removed') or exists(select 1 from public.term_memberships tm where tm.id=public.current_term_membership((select term_id from public.work_items where id=c.work_item_id)) and tm.member_id=c.author_id)))
$$;
grant select on public.comments,public.comment_revisions,public.comment_evidence to authenticated;
create policy comment_read on public.comments for select to authenticated using(public.can_read_comment(id));
-- Redacted/removed originals remain immutable in custody, but never appear in ordinary reads.
create policy comment_revision_read on public.comment_revisions for select to authenticated using(public.can_read_comment(comment_id)
 and exists(select 1 from public.comments c where c.id=comment_id and c.state not in ('removed','redacted')
 and (comment_revisions.state<>'draft' or comment_revisions.actor_id=auth.uid())));
create policy comment_evidence_read on public.comment_evidence for select to authenticated using(public.can_read_comment(comment_id)
 and public.can_access_work(coalesce(task_work_id,deliverable_work_id),'detail'));
create trigger comment_revisions_immutable before update or delete on public.comment_revisions for each row execute function app_private.deny_deliverable_history();
create trigger comment_evidence_immutable before update or delete on public.comment_evidence for each row execute function app_private.deny_deliverable_history();

create function app_private.comment_member_eligible(w public.work_items,p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members m join public.term_memberships tm on tm.member_id=m.id
 where m.id=p_member and m.account_state='active' and tm.term_id=w.term_id and tm.status='active' and tm.joined_at<=statement_timestamp() and tm.ends_at>statement_timestamp()
 and (m.id=w.owner_member_id
 or exists(select 1 from public.task_collaborators c join public.tasks t on t.work_item_id=c.work_item_id where c.work_item_id=w.id and c.member_id=m.id
 and (t.assigned_unit_id is null or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null where um.term_membership_id=tm.id and um.unit_id=t.assigned_unit_id and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())))
 or exists(select 1 from public.record_grants g where g.work_item_id=w.id and g.revoked_at is null and g.starts_at<=statement_timestamp() and g.expires_at>statement_timestamp()
 and (g.member_id=m.id or exists(select 1 from public.unit_memberships um join public.org_units u on u.id=um.unit_id and u.archived_at is null where um.term_membership_id=tm.id and um.unit_id=g.unit_id and um.status='active' and um.effective_from<=statement_timestamp() and um.effective_to>statement_timestamp())))))
$$;
create function public.mention_candidates(p_work_item_id uuid,p_search text default '') returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',display_name) order by display_name,id),'[]') from
 (select m.id,m.display_name from public.members m join public.work_items w on w.id=p_work_item_id
 where w.kind in ('task','deliverable') and public.can_access_work(w.id,'detail') and public.current_term_membership(w.term_id) is not null and length(coalesce(p_search,''))<=100
 and app_private.comment_member_eligible(w,m.id) and position(lower(coalesce(p_search,'')) in lower(m.display_name))>0 order by m.display_name,m.id limit 20) s
$$;
create function app_private.comment_writable(w public.work_items) returns boolean language sql stable set search_path='' as $$
 select w.kind in ('task','deliverable') and w.archived_at is null and public.current_term_membership(w.term_id) is not null
 and public.can_access_work(w.id,'detail') and exists(select 1 from public.terms where id=w.term_id and state='active')
$$;
create function public.add_comment(p_work_item_id uuid,p_body text,p_mentions uuid[],p_draft boolean,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.work_items; member uuid; name text; result jsonb; payload jsonb; cid uuid; person uuid;begin
 select * into w from public.work_items where id=p_work_item_id for update;
 if not found or not app_private.comment_writable(w) then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_body,p_mentions,p_draft);result:=app_private.begin_work_command('add_comment',p_request_id,payload);
 if result is not null then return result;end if;
 if coalesce(length(btrim(p_body)),0) not between 1 and 8000 or p_draft is null or p_mentions is null or cardinality(p_mentions)>20 or array_ndims(p_mentions)>1 then raise exception using errcode='22023',message='command_validation_failed';end if;
 foreach person in array p_mentions loop if not coalesce(app_private.comment_member_eligible(w,person),false) then raise exception using errcode='42501',message='command_permission_denied';end if;end loop;
 select m.id,m.display_name into member,name from public.members m join public.term_memberships tm on tm.member_id=m.id where tm.id=public.current_term_membership(w.term_id);
 insert into public.comments(work_item_id,author_id,author_name,state) values(w.id,member,name,case when p_draft then 'draft' else 'published' end) returning id into cid;
 insert into public.comment_revisions(comment_id,revision,body,reason,state,mentions,actor_id) values(cid,1,p_body,'Created',case when p_draft then 'draft' else 'published' end,array(select distinct unnest(p_mentions)),auth.uid());
 result:=app_private.finish_work_command(w,'add_comment',p_request_id,payload,jsonb_build_object('commentId',cid,'version',1),'["comment"]');
 if not p_draft and cardinality(p_mentions)>0 then update public.outbox_jobs set event_type='comment_mentions',payload=jsonb_build_object('eventId',event_id,'workItemId',w.id,'commentId',cid,'revision',1) where event_id=(select id from public.audit_events where actor_id=auth.uid() and action='add_comment' and request_id=p_request_id);end if;
 return result;
end$$;
create function public.revise_comment(p_comment_id uuid,p_body text,p_mentions uuid[],p_action text,p_reason text,p_expected_version integer,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.comments;w public.work_items;member uuid;result jsonb;payload jsonb;person uuid; target text;begin
 select * into c from public.comments where id=p_comment_id;
 if not found or not public.can_read_comment(c.id) then raise exception using errcode='42501',message='command_permission_denied';end if;
 select * into w from public.work_items where id=c.work_item_id for update;
 select * into c from public.comments where id=p_comment_id for update;
 select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id);
 if not app_private.comment_writable(w) or not (member=c.author_id or (p_action='redact' and public.can_access_work(w.id,'owner'))) then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_comment_id,p_body,p_mentions,p_action,p_reason,p_expected_version);result:=app_private.begin_work_command('revise_comment',p_request_id,payload);
 if result is not null then return result;end if;
 if p_expected_version is distinct from c.version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_action is null or p_action not in ('edit','publish','remove','redact') or coalesce(length(btrim(p_reason)),0) not between 1 and 2000 or p_mentions is null or cardinality(p_mentions)>20 or array_ndims(p_mentions)>1 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if c.state in ('removed','redacted') or (p_action in ('publish','remove') and c.state<>'draft') or (p_action='remove' and exists(select 1 from public.comment_evidence where comment_id=c.id)) then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if p_action in ('edit','publish') and coalesce(length(btrim(p_body)),0) not between 1 and 8000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 foreach person in array p_mentions loop if not coalesce(app_private.comment_member_eligible(w,person),false) then raise exception using errcode='42501',message='command_permission_denied';end if;end loop;
 target:=case p_action when 'publish' then 'published' when 'remove' then 'removed' when 'redact' then 'redacted' else c.state end;
 update public.comments set state=target,version=version+1,updated_at=statement_timestamp() where id=c.id returning * into c;
 insert into public.comment_revisions(comment_id,revision,body,reason,state,mentions,actor_id) values(c.id,c.version,case when target in ('removed','redacted') then '' else p_body end,p_reason,target,case when target in ('removed','redacted') then '{}'::uuid[] else array(select distinct unnest(p_mentions)) end,auth.uid());
 result:=app_private.finish_work_command(w,'revise_comment',p_request_id,payload,jsonb_build_object('commentId',c.id,'version',c.version),'["comment_revision","reason"]');
 if target='published' and cardinality(p_mentions)>0 then update public.outbox_jobs set event_type='comment_mentions',payload=jsonb_build_object('eventId',event_id,'workItemId',w.id,'commentId',c.id,'revision',c.version) where event_id=(select id from public.audit_events where actor_id=auth.uid() and action='revise_comment' and request_id=p_request_id);end if;
 return result;
end$$;

create function public.read_comments(p_work_item_id uuid,p_page integer default 1) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;member uuid;begin
 if p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select * into w from public.work_items where id=p_work_item_id;
 if not found or w.kind not in ('task','deliverable') or not public.can_access_work(w.id,'detail') then return null;end if;
 select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id);
 return jsonb_build_object('canComment',app_private.comment_writable(w),'page',p_page,
 'total',(select count(*) from public.comments c where c.work_item_id=w.id and public.can_read_comment(c.id)),
 'items',coalesce((select jsonb_agg(item order by created_at,id) from (select c.id,c.created_at,jsonb_build_object('id',c.id,'version',c.version,'state',c.state,'author',c.author_name,'createdAt',c.created_at,'updatedAt',c.updated_at,
 'body',case when c.state in ('redacted','removed') then null else r.body end,'reason',r.reason,
 'mentions',case when c.state in ('redacted','removed') then '[]'::jsonb else to_jsonb(r.mentions) end,
 'canEdit',app_private.comment_writable(w) and member=c.author_id and c.state in ('draft','published'),
 'canRedact',app_private.comment_writable(w) and (member=c.author_id or public.can_access_work(w.id,'owner')) and c.state='published',
 'evidence',coalesce((select jsonb_agg(jsonb_build_object('revision',e.revision,'purpose',e.purpose,'workVersion',coalesce(e.task_version,e.deliverable_version))) from public.comment_evidence e where e.comment_id=c.id and public.can_access_work(coalesce(e.task_work_id,e.deliverable_work_id),'detail')),'[]')) as item
 from public.comments c join public.comment_revisions r on r.comment_id=c.id and r.revision=c.version where c.work_item_id=w.id and public.can_read_comment(c.id) order by c.created_at,c.id limit 20 offset(p_page-1)*20) s),'[]'));
end$$;
create function public.read_comment_history(p_comment_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('revision',r.revision,'body',case when c.state in ('removed','redacted') then null else r.body end,'reason',r.reason,'state',r.state,'recordedAt',r.recorded_at) order by r.revision),'[]')
 from public.comment_revisions r join public.comments c on c.id=r.comment_id where c.id=p_comment_id and public.can_read_comment(c.id) and (r.state<>'draft' or r.actor_id=auth.uid())
$$;
create function app_private.pin_comment_evidence() returns trigger language plpgsql security definer set search_path='' as $$
declare evidence text; purpose text;cid uuid;rev integer;c public.comments;begin
 foreach purpose in array case when tg_table_name='task_revisions' then array['task'] else array['submission','decision'] end loop
 evidence:=to_jsonb(new)->>case purpose when 'task' then 'evidence' when 'submission' then 'final_evidence' else 'review_evidence' end;
 if evidence like 'comment:%' then
 if evidence !~ '^comment:[0-9a-fA-F-]{36}:[1-9][0-9]*$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 if length(split_part(evidence,':',3))>10 or split_part(evidence,':',3)::numeric>2147483647 then raise exception using errcode='22023',message='command_validation_failed';end if;
 cid:=split_part(evidence,':',2)::uuid;rev:=split_part(evidence,':',3)::integer;
 select * into c from public.comments where id=cid for update;
 if not found or c.work_item_id<>new.work_item_id or c.state<>'published' or not public.can_read_comment(c.id)
 or not exists(select 1 from public.comment_revisions where comment_id=cid and revision=rev and state='published') then raise exception using errcode='42501',message='command_permission_denied';end if;
 insert into public.comment_evidence(comment_id,revision,purpose,task_work_id,task_version,deliverable_work_id,deliverable_version)
 values(cid,rev,purpose,case when purpose='task' then new.work_item_id end,case when purpose='task' then new.work_version end,case when purpose<>'task' then new.work_item_id end,case when purpose<>'task' then new.work_version end);
 end if;end loop;return new;
end$$;
create trigger task_comment_evidence after insert on public.task_revisions for each row execute function app_private.pin_comment_evidence();
create trigger deliverable_comment_evidence after insert on public.deliverable_revisions for each row execute function app_private.pin_comment_evidence();
revoke all on function app_private.comment_member_eligible(public.work_items,uuid),app_private.comment_writable(public.work_items),app_private.pin_comment_evidence() from public,anon,authenticated,service_role;
revoke all on function public.can_read_comment(uuid),public.mention_candidates(uuid,text),public.add_comment(uuid,text,uuid[],boolean,uuid),public.revise_comment(uuid,text,uuid[],text,text,integer,uuid),public.read_comments(uuid,integer),public.read_comment_history(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_comment(uuid),public.mention_candidates(uuid,text),public.add_comment(uuid,text,uuid[],boolean,uuid),public.revise_comment(uuid,text,uuid[],text,text,integer,uuid),public.read_comments(uuid,integer),public.read_comment_history(uuid) to authenticated;
commit;
