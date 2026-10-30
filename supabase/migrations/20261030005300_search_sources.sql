-- Only operational projections enter search. Aliases are identity hints, never access grants.
begin;
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
do $$begin
 if exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname in('pg_trgm','unaccent')and n.nspname<>'extensions')then
  raise exception using errcode='55000',message='search_extension_schema_unavailable';
 end if;
end$$;
-- Fixed packaged dictionary. A future dictionary change requires index rebuilds.
create function app_private.search_text(value text)returns text language sql immutable strict set search_path='' as $$
 select lower(extensions.unaccent('extensions.unaccent'::regdictionary,value))
$$;
revoke all on function app_private.search_text(text)from public,anon,authenticated,service_role;
create index search_work_titles_fts on public.work_items using gin(to_tsvector('simple',app_private.search_text(title)))where kind in('task','deliverable','request')and archived_at is null;
drop index public.search_operational_titles;
create index search_published_guidance on public.resource_versions using gin(to_tsvector('simple',app_private.search_text(label||' '||body)))where published;
create index search_work_title_trigrams on public.work_items using gin(app_private.search_text(title)extensions.gin_trgm_ops)where kind in('task','deliverable','request')and archived_at is null;
create index search_guide_trigrams on public.resource_versions using gin(app_private.search_text(label||' '||body)extensions.gin_trgm_ops)where published;
-- A term is offered only to its current core member. No roster/user impersonation.
create function public.read_search_terms(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;begin
 m:=app_private.request_actor(p_term_id);
 return coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'label',t.label)order by(t.id=p_term_id)desc,t.starts_on desc,t.id)
  from public.terms t where t.organization_id=m.organization_id and public.current_term_membership(t.id)is not null and public.has_capability(t.id,'workspace.read')),'[]');
end$$;
create function public.read_search_term_context(p_term_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.term_memberships;begin
 m:=app_private.request_actor(p_term_id);
 return jsonb_build_object('state','authorized','memberId',m.member_id,'displayName',(select display_name from public.members where id=m.member_id),
  'organizationId',m.organization_id,'termId',m.term_id,'termMembershipId',m.id,'expiresAt',m.ends_at,
  'capabilities',coalesce((select jsonb_agg(distinct g->>'capability')from jsonb_array_elements(public.explain_access(m.term_id)->'grants')g),'[]'));
end$$;
revoke all on function public.read_search_terms(uuid),public.read_search_term_context(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_search_terms(uuid),public.read_search_term_context(uuid)to authenticated;
create or replace function public.search_workspace(p_term_id uuid,p_query text,p_filters jsonb default '{}',p_cursor jsonb default null)returns jsonb
language plpgsql stable security definer set search_path='' set pg_trgm.word_similarity_threshold='0.6' as $$
declare q text;needle text;selected_kind text;scope text;after_id uuid;after_kind text;items jsonb;total integer;more boolean;exact boolean;exact_id uuid;begin
 perform app_private.request_actor(p_term_id);
 if p_query is null or length(btrim(p_query))not between 2 and 120 or p_query~'[[:cntrl:]]'
  or not coalesce(app_private.definition_keys(p_filters,array['kind']),false)or(p_filters?'kind'and jsonb_typeof(p_filters->'kind')<>'string')then raise exception using errcode='22023',message='command_validation_failed';end if;
 selected_kind:=coalesce(p_filters->>'kind','all');
 if selected_kind not in('all','task','deliverable','request','guide','glossary','contact')then raise exception using errcode='22023',message='command_validation_failed';end if;
 q:=btrim(p_query);needle:=app_private.search_text(q);scope:=encode(sha256(convert_to(jsonb_build_array('sources-v2',auth.uid(),p_term_id,q,selected_kind)::text,'UTF8')),'hex');
 if p_cursor is not null then
  if not coalesce(app_private.definition_keys(p_cursor,array['after','kind','scope']),false)or p_cursor->>'scope'is distinct from scope
   or p_cursor->>'kind'not in('task','deliverable','request','guide','glossary','contact')or p_cursor->>'kind'is null then raise exception using errcode='22023',message='command_validation_failed';end if;
  begin after_id:=(p_cursor->>'after')::uuid;exception when others then raise exception using errcode='22023',message='command_validation_failed';end;
  after_kind:=p_cursor->>'kind';if after_id is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 end if;
 -- Every issued namespace (including historical long prefixes) uses exact identity lookup.
 exact:=q~*'^[a-z][a-z0-9_ -]*-[0-9]+$|^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
 if q~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'then exact_id:=q::uuid;end if;
 -- Candidate matching can use indexes; authorization is materialized before any
 -- response projection or aggregate. No indexed predicate is an authority grant.
 with aliases as materialized(select unit_id,alias from public.unit_aliases where term_id=p_term_id and alias=lower(q)),
 candidates as materialized(
  select w.id from public.work_items w where w.term_id=p_term_id and w.kind in('task','deliverable','request')and w.archived_at is null and not exact
   and(to_tsvector('simple',app_private.search_text(w.title))@@plainto_tsquery('simple',needle)or needle operator(extensions.<%)app_private.search_text(w.title))
  union select w.id from public.work_items w where w.term_id=p_term_id and w.kind in('task','deliverable','request')and w.archived_at is null and w.id=exact_id
  union select r.work_item_id from public.work_references r where r.term_id=p_term_id and r.reference_text=upper(q)
  union select r.work_item_id from public.requests r where r.term_id=p_term_id and r.tracking_id=upper(q)
  union select w.id from public.work_items w where w.term_id=p_term_id and w.archived_at is null and not exact
   and(exists(select 1 from aliases where unit_id=w.lead_unit_id)or exists(select 1 from public.work_unit_origins o join aliases a on a.unit_id=o.unit_id where o.work_item_id=w.id))
 ),
 authorized_work as materialized(
  select w.id,w.kind,w.title,coalesce(r.reference_text,req.tracking_id)reference_text,w.lead_unit_id
  from candidates c join public.work_items w on w.id=c.id left join public.work_references r on r.work_item_id=w.id
  left join public.requests req on req.work_item_id=w.id
  where w.term_id=p_term_id and w.archived_at is null and(selected_kind='all'or w.kind=selected_kind)
   and((w.kind in('task','deliverable')and public.can_access_work(w.id,'detail'))
    or(w.kind='request'and app_private.request_readable(p_term_id,w.id)))
 ),authorized_resources as materialized(
  select w.id,r.kind,v.label title,v.body,v.alias,w.lead_unit_id from public.resources r
  join public.work_items w on w.id=r.work_item_id join public.resource_versions v on v.resource_id=r.work_item_id and v.version=r.published_version and v.published
  where w.term_id=p_term_id and(selected_kind='all'or r.kind=selected_kind)and app_private.resource_visible(w.id)
   and(w.id::text=lower(q)or exists(select 1 from public.resource_aliases ra where ra.resource_id=w.id and ra.term_id=p_term_id and ra.alias=lower(q)
    and exists(select 1 from public.resource_versions pv where pv.resource_id=w.id and pv.alias=ra.alias and pv.published))
    or(not exact and(to_tsvector('simple',app_private.search_text(v.label||' '||v.body))@@plainto_tsquery('simple',needle)or needle operator(extensions.<%)app_private.search_text(v.label||' '||v.body)or exists(select 1 from aliases where unit_id=w.lead_unit_id))))
 ),authorized_contacts as materialized(select d.member_id id,d.display_name title,
  (select a.alias from aliases a where exists(select 1 from public.unit_memberships um join public.term_memberships tm on tm.id=um.term_membership_id
   join public.org_units u on u.id=um.unit_id and u.term_id=p_term_id and u.archived_at is null
   where tm.term_id=p_term_id and tm.member_id=d.member_id and um.unit_id=a.unit_id and um.status='active'and um.effective_from<=statement_timestamp()and um.effective_to>statement_timestamp()))matched_alias
  from public.read_directory(p_term_id)d where selected_kind in('all','contact')),
 matched as materialized(
  select a.id,a.kind,a.title,a.reference_text,a.lead_unit_id,(select alias from aliases al where al.unit_id=a.lead_unit_id or exists(select 1 from public.work_unit_origins o where o.work_item_id=a.id and o.unit_id=al.unit_id))matched_alias from authorized_work a
  union all select a.id,a.kind,a.title,null,a.lead_unit_id,(select alias from aliases where unit_id=a.lead_unit_id)from authorized_resources a
  union all select a.id,'contact',a.title,null,null,a.matched_alias from authorized_contacts a where a.id::text=lower(q)or(not exact and(strpos(app_private.search_text(a.title),needle)>0 or a.matched_alias is not null))
 ),page as(select *from matched where after_id is null or(kind,id)>(after_kind,after_id)order by kind,id limit 21)
 select coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',p.kind,'title',title,'reference',reference_text,'termId',p_term_id,
  'termLabel',(select label from public.terms where id=p_term_id),'matchedAlias',matched_alias,
  'href',case p.kind when 'task'then '/tasks/'||id when 'deliverable'then '/deliverables/'||id when 'request'then '/requests/'||p_term_id||'/'||id when 'contact'then '/people?contact='||id else '/resources?resource='||id end||case when p.kind in('contact','guide','glossary')then '&term='else '?term='end||p_term_id)order by p.kind,id)from(select *from page order by kind,id limit 20)p),'[]'),
  (select count(*)::integer from matched),(select count(*)>20 from page)into items,total,more;
 return jsonb_build_object('items',items,'total',total,'nextCursor',case when more then jsonb_build_object('after',items->19->>'id','kind',items->19->>'kind','scope',scope)else null end);
end$$;
commit;
