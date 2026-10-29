begin;
-- Freeze the legacy candidate set while the marker and creation trigger are installed.
lock table public.work_items in share row exclusive mode;

-- References are separate from mutable work/version/receipt storage.
create table public.work_reference_counters(
 organization_id uuid not null,term_id uuid not null,kind text not null check(kind in('task','deliverable')),
 last_number bigint not null default 0 check(last_number between 0 and 9007199254740991),
 backfill_complete boolean not null default true,
 primary key(term_id,kind),foreign key(organization_id,term_id)references public.terms(organization_id,id)
);
create table public.work_references(
 organization_id uuid not null,term_id uuid not null,work_item_id uuid primary key,kind text not null check(kind in('task','deliverable')),
 sequence_no bigint not null check(sequence_no between 1 and 9007199254740991),
 reference_text text generated always as((case kind when 'task'then 'TASK-'else 'DEL-'end)||lpad(sequence_no::text,greatest(3,length(sequence_no::text)),'0'))stored,
 issued_at timestamptz not null default statement_timestamp(),
 unique(term_id,kind,sequence_no),unique(term_id,reference_text),
 foreign key(organization_id,term_id,work_item_id,kind)references public.work_items(organization_id,term_id,id,kind)
);
alter table public.work_reference_counters enable row level security;
alter table public.work_reference_counters force row level security;
alter table public.work_references enable row level security;
alter table public.work_references force row level security;
revoke all on public.work_reference_counters,public.work_references from public,anon,authenticated,service_role;
create index work_reference_backfill_order on public.work_items(term_id,kind,created_at,id)where kind in('task','deliverable');

create function app_private.protect_work_reference()returns trigger language plpgsql set search_path='' as $$begin
 if tg_table_name='work_reference_counters'and tg_op='UPDATE'then
  if(new.organization_id,new.term_id,new.kind)is not distinct from(old.organization_id,old.term_id,old.kind)and
   ((new.last_number=old.last_number+1 and new.backfill_complete=old.backfill_complete)or
    (new.last_number=old.last_number and not old.backfill_complete and new.backfill_complete))then return new;end if;
 end if;
 raise exception using errcode='55000',message='work_reference_immutable';
end$$;
create trigger work_reference_immutable before update or delete on public.work_references for each row execute function app_private.protect_work_reference();
create trigger work_reference_counter_monotonic before update or delete on public.work_reference_counters for each row execute function app_private.protect_work_reference();

-- Only migration/approved server operators may invoke issuance or resumable backfill.
create function app_private.issue_work_reference(id uuid,backfill boolean default false)returns void
language plpgsql security definer set search_path='' as $$declare w public.work_items;c public.work_reference_counters;n bigint;begin
 select *into w from public.work_items where work_items.id=issue_work_reference.id;
 if not found or w.kind not in('task','deliverable')then return;end if;
 perform app_private.readiness_lock(w.term_id);
 perform pg_advisory_xact_lock(hashtextextended('work_reference:'||w.term_id::text||':'||w.kind,0));
 if exists(select 1 from public.work_references where work_item_id=w.id)then return;end if;
 insert into public.work_reference_counters(organization_id,term_id,kind)values(w.organization_id,w.term_id,w.kind)on conflict do nothing;
 select *into c from public.work_reference_counters where term_id=w.term_id and kind=w.kind for update;
 if not c.backfill_complete and not backfill then raise exception using errcode='55000',message='work_reference_backfill_pending';end if;
 update public.work_reference_counters set last_number=last_number+1 where term_id=w.term_id and kind=w.kind returning last_number into n;
 insert into public.work_references(organization_id,term_id,work_item_id,kind,sequence_no)values(w.organization_id,w.term_id,w.id,w.kind,n);
end$$;
create function app_private.backfill_work_references(term uuid,resource_kind text,batch_size integer default 100)returns jsonb
language plpgsql security definer set search_path='' as $$declare w record;processed integer:=0;remaining bigint;begin
 if resource_kind is null or resource_kind not in('task','deliverable')or batch_size is null or batch_size not between 1 and 500 then raise exception using errcode='22023',message='command_validation_failed';end if;
 perform app_private.readiness_lock(term);
 perform pg_advisory_xact_lock(hashtextextended('work_reference:'||term::text||':'||resource_kind,0));
 -- NOWAIT aborts this whole batch instead of waiting behind a work editor while holding the term lock.
 for w in select wi.id from public.work_items wi where wi.term_id=term and wi.kind=resource_kind and not exists(select 1 from public.work_references r where r.work_item_id=wi.id)
  order by wi.created_at,wi.id limit batch_size for key share of wi nowait loop
  perform app_private.issue_work_reference(w.id,true);processed:=processed+1;
 end loop;
 select count(*)into remaining from public.work_items wi where wi.term_id=term and wi.kind=resource_kind and not exists(select 1 from public.work_references r where r.work_item_id=wi.id);
 if remaining=0 then update public.work_reference_counters set backfill_complete=true where term_id=term and kind=resource_kind and not backfill_complete;end if;
 return jsonb_build_object('processed',processed,'remaining',remaining,'complete',remaining=0);
end$$;
-- Mark legacy namespaces before installing the creation trigger. New namespaces start complete.
insert into public.work_reference_counters(organization_id,term_id,kind,backfill_complete)
 select organization_id,term_id,kind,false from public.work_items where kind in('task','deliverable')group by organization_id,term_id,kind;
create function app_private.issue_created_work_reference()returns trigger language plpgsql security definer set search_path='' as $$begin
 perform app_private.issue_work_reference(new.id,false);return new;
end$$;
create trigger issue_created_work_reference after insert on public.work_items for each row when(new.kind in('task','deliverable'))execute function app_private.issue_created_work_reference();
do $$declare c record;begin for c in select term_id,kind from public.work_reference_counters order by term_id,kind loop
 perform app_private.backfill_work_references(c.term_id,c.kind,100);
end loop;end$$;

create function app_private.work_reference(id uuid)returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('value',r.reference_text,'termId',r.term_id,'termLabel',t.label)
 from public.work_references r join public.terms t on t.id=r.term_id where r.work_item_id=$1 and public.can_access_work(r.work_item_id,'summary')
$$;
alter function app_private.deliverable_summary(public.work_items,public.deliverables)rename to deliverable_summary_p36;
create function app_private.deliverable_summary(w public.work_items,d public.deliverables)returns jsonb language sql stable set search_path='' as $$
 select app_private.deliverable_summary_p36(w,d)||jsonb_build_object('reference',app_private.work_reference(w.id))
$$;
alter function public.read_task(uuid)rename to read_task_p36;
alter function public.read_task_p36(uuid)set schema app_private;
create function public.read_task(p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare v jsonb;begin
 v:=app_private.read_task_p36(p_work_item_id);if v is null then return null;end if;
 return v||jsonb_build_object('reference',app_private.work_reference(p_work_item_id));
end$$;
alter function public.read_owned_tasks(uuid,integer)rename to read_owned_tasks_p36;
alter function public.read_owned_tasks_p36(uuid,integer)set schema app_private;
create function public.read_owned_tasks(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare v jsonb;begin
 v:=app_private.read_owned_tasks_p36(p_term_id,p_page);if v is null then return null;end if;
 return jsonb_set(v,'{items}',coalesce((select jsonb_agg(item||jsonb_build_object('reference',app_private.work_reference((item->>'id')::uuid))order by n)from jsonb_array_elements(v->'items')with ordinality a(item,n)),'[]'::jsonb));
end$$;
alter function public.read_overview(uuid)rename to read_overview_p36;
alter function public.read_overview_p36(uuid)set schema app_private;
create function public.read_overview(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare v jsonb;begin
 v:=app_private.read_overview_p36(p_term_id);if v is null then return null;end if;
 return jsonb_set(v,'{items}',coalesce((select jsonb_agg(case when item->>'source'in('task','deliverable')then item||jsonb_build_object('reference',app_private.work_reference((item->>'id')::uuid))else item end order by n)from jsonb_array_elements(v->'items')with ordinality a(item,n)),'[]'::jsonb));
end$$;
create function public.resolve_work_reference(p_term_id uuid,p_kind text,p_reference text)returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',w.id,'kind',w.kind,'title',w.title,'reference',app_private.work_reference(w.id))
 from public.work_references r join public.work_items w on w.id=r.work_item_id
 where r.term_id=p_term_id and r.kind=p_kind and r.reference_text=p_reference and public.can_access_work(w.id,'summary')
$$;
revoke all on function app_private.protect_work_reference(),app_private.issue_work_reference(uuid,boolean),app_private.backfill_work_references(uuid,text,integer),app_private.issue_created_work_reference(),app_private.work_reference(uuid),app_private.deliverable_summary_p36(public.work_items,public.deliverables),app_private.deliverable_summary(public.work_items,public.deliverables),app_private.read_task_p36(uuid),app_private.read_owned_tasks_p36(uuid,integer),app_private.read_overview_p36(uuid)from public,anon,authenticated,service_role;
revoke all on function public.read_task(uuid),public.read_owned_tasks(uuid,integer),public.read_overview(uuid),public.resolve_work_reference(uuid,text,text)from public,anon,authenticated,service_role;
grant execute on function public.read_task(uuid),public.read_owned_tasks(uuid,integer),public.read_overview(uuid),public.resolve_work_reference(uuid,text,text)to authenticated;
commit;
