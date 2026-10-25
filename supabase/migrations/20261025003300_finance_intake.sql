-- P25 presentation seams; no reviewer authority or approval outcomes are installed.
alter function public.read_request(uuid,uuid,integer,integer)rename to read_request_p24;
alter function public.read_request_p24(uuid,uuid,integer,integer)set schema app_private;
create function public.read_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null,p_history_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare base jsonb;begin
 base:=app_private.read_request_p24(p_term_id,p_work_item_id,p_revision,p_history_page);if base is null then return null;end if;
 return base||jsonb_build_object('governedKind',(select t.governed_kind from public.requests r join public.request_types t on t.id=r.request_type_id where r.work_item_id=p_work_item_id));
end$$;
create function public.read_finance_intake(p_term_id uuid,p_work_item_id uuid,p_revision integer default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare base jsonb;t public.request_types;begin
 base:=public.read_request(p_term_id,p_work_item_id,p_revision,1);if base is null or base->>'governedKind'is distinct from 'fin'then return null;end if;
 select typ.*into t from public.request_types typ where typ.id=(base->>'typeId')::uuid;
 return jsonb_build_object('request',base,'finance',public.read_finance_revision(p_term_id,p_work_item_id,p_revision),
 'options',case when(base->>'canEdit')::boolean then public.request_form_options(p_term_id,t.id,p_work_item_id)end,
 'deliverables',case when(base->>'canEdit')::boolean then coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'label',d.title)order by d.title,d.id)from(select w.id,w.title from public.work_items w join public.deliverables x on x.work_item_id=w.id where w.term_id=p_term_id and w.archived_at is null and public.can_access_work(w.id,'detail')order by w.title,w.id limit 100)d),'[]')else '[]'::jsonb end,
 'processNote',t.process_note,'officialUrl',t.official_url);
end$$;
create function public.list_finance_cases(p_term_id uuid,p_page integer default 1)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;rows jsonb;total integer;begin
 m:=app_private.request_actor(p_term_id);
 if p_page is null or p_page not between 1 and 10000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 select count(*)into total from public.requests r join public.request_types t on t.id=r.request_type_id join public.work_items w on w.id=r.work_item_id
 where r.term_id=p_term_id and t.governed_kind='fin'and w.owner_member_id=m.member_id and w.archived_at is null and public.can_access_work(w.id,'detail');
 select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'title',q.title,'state',q.request_state,'trackingId',q.tracking_id,'revision',q.current_revision)order by q.updated_at desc,q.id),'[]')into rows from(
 select w.id,w.title,w.updated_at,r.request_state,r.tracking_id,r.current_revision from public.requests r join public.request_types t on t.id=r.request_type_id join public.work_items w on w.id=r.work_item_id
 where r.term_id=p_term_id and t.governed_kind='fin'and w.owner_member_id=m.member_id and w.archived_at is null and public.can_access_work(w.id,'detail')order by w.updated_at desc,w.id limit 20 offset(p_page-1)*20)q;
 return jsonb_build_object('items',rows,'total',total,'page',p_page,'pageSize',20);
end$$;
create function public.read_finance_gate(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare w public.work_items;target uuid;pending boolean:=false;begin
 select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id and kind in('task','deliverable');
 if not found or not public.can_access_work(w.id,'detail')then return null;end if;
 target:=case when w.kind='deliverable'then w.id else w.parent_work_item_id end;
 -- A task link never confers parent or financial-case access, even for this safe projection.
 if w.archived_at is null and target is not null and public.current_term_membership(p_term_id)is not null and public.can_access_work(target,'detail')then
  select exists(select 1 from public.finance_revisions f join public.requests r on r.current_revision_id=f.request_revision_id join public.work_items rw on rw.id=r.work_item_id
  where f.term_id=p_term_id and f.related_deliverable_id=target and r.request_state<>'cancelled'and rw.archived_at is null)into pending;
 end if;
 return jsonb_build_object('state',case when pending then 'pending'else 'not_verified'end);
end$$;
revoke all on function app_private.read_request_p24(uuid,uuid,integer,integer)from public,anon,authenticated,service_role;
revoke all on function public.read_request(uuid,uuid,integer,integer),public.read_finance_intake(uuid,uuid,integer),public.list_finance_cases(uuid,integer),public.read_finance_gate(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_request(uuid,uuid,integer,integer),public.read_finance_intake(uuid,uuid,integer),public.list_finance_cases(uuid,integer),public.read_finance_gate(uuid,uuid)to authenticated;
