-- Closed operational-title search. No body/profile/finance/file extraction or external index.
create index search_operational_titles on public.work_items using gin(to_tsvector('simple',title))where kind in('task','deliverable')and archived_at is null;
create function public.search_workspace(p_term_id uuid,p_query text,p_filters jsonb default '{}',p_cursor jsonb default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare q text;selected_kind text;scope text;after_id uuid;items jsonb;total integer;more boolean;exact boolean;begin
 perform app_private.request_actor(p_term_id);
 if p_query is null or length(btrim(p_query))not between 2 and 120 or p_query~'[[:cntrl:]]'
  or not coalesce(app_private.definition_keys(p_filters,array['kind']),false)then raise exception using errcode='22023',message='command_validation_failed';end if;
 selected_kind:=coalesce(p_filters->>'kind','all');
 if selected_kind not in('all','task','deliverable')then raise exception using errcode='22023',message='command_validation_failed';end if;
 q:=btrim(p_query);scope:=encode(sha256(convert_to(jsonb_build_array(auth.uid(),p_term_id,q,selected_kind)::text,'UTF8')),'hex');
 if p_cursor is not null then
  if not coalesce(app_private.definition_keys(p_cursor,array['after','scope']),false)or p_cursor->>'scope'is distinct from scope then raise exception using errcode='22023',message='command_validation_failed';end if;
  begin after_id:=(p_cursor->>'after')::uuid;exception when others then raise exception using errcode='22023',message='command_validation_failed';end;
  if after_id is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 end if;
 exact:=q~*'^(TASK|DEL)-[0-9]+$|^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
 with authorized as materialized(
  select w.id,w.kind,w.title,r.reference_text from public.work_items w left join public.work_references r on r.work_item_id=w.id
  where w.term_id=p_term_id and w.kind in('task','deliverable')and w.archived_at is null and(selected_kind='all'or w.kind=selected_kind)and public.can_access_work(w.id,'detail')
 ),matched as materialized(select *from authorized a where lower(a.reference_text)=lower(q)or a.id::text=lower(q)
  or(not exact and(to_tsvector('simple',a.title)@@plainto_tsquery('simple',q)or strpos(lower(a.title),lower(q))>0))),
 page as(select *from matched where after_id is null or id>after_id order by id limit 21)
 select coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',p.kind,'title',title,'reference',reference_text,'termId',p_term_id,
  'termLabel',(select label from public.terms where id=p_term_id),'href',case p.kind when 'task'then '/tasks/'else '/deliverables/'end||id::text)order by id)from(select *from page order by id limit 20)p),'[]'),
  (select count(*)::integer from matched),(select count(*)>20 from page)into items,total,more;
 return jsonb_build_object('items',items,'total',total,'nextCursor',case when more then jsonb_build_object('after',items->19->>'id','scope',scope)else null end);
end$$;
revoke all on function public.search_workspace(uuid,text,jsonb,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.search_workspace(uuid,text,jsonb,jsonb)to authenticated;
