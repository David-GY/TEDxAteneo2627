-- P24: restricted plans only. No financial authorizations, ledger, actuals or payments.
create table public.finance_cases(
 request_id uuid primary key,organization_id uuid not null,term_id uuid not null,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default statement_timestamp(),
 unique(organization_id,term_id,request_id),
 foreign key(organization_id,term_id,request_id)references public.requests(organization_id,term_id,work_item_id)
);
create table public.finance_revisions(
 id uuid primary key default gen_random_uuid(),request_id uuid not null,organization_id uuid not null,term_id uuid not null,
 request_revision_id uuid not null unique,revision_no integer not null,
 case_kind text not null check(case_kind in('cost','budget','expense','reimbursement','fundraising','sales')),
 currency text not null check(currency='PHP'),purpose text not null,fund_source text not null,beneficiary_member_id uuid not null,
 related_deliverable_id uuid,planned_on date,terms_risks text not null,
 requested_total_centavos bigint not null check(requested_total_centavos between 0 and 9007199254740991),
 unit_price_centavos bigint check(unit_price_centavos between 0 and 9007199254740991),
 forecast_quantity_milli integer check(forecast_quantity_milli between 0 and 1000000000),
 forecast_revenue_centavos bigint check(forecast_revenue_centavos between 0 and 9007199254740991),
 manifest_id uuid,manifest_hash text not null check(manifest_hash~'^[0-9a-f]{64}$'),
 payload_hash text not null check(payload_hash~'^[0-9a-f]{64}$'),hash_version text not null default 'sha256-jsonb-v1' check(hash_version='sha256-jsonb-v1'),
 submitted_by uuid not null references auth.users(id),submitted_at timestamptz not null default statement_timestamp(),
 unique(request_id,revision_no),unique(id,request_id),
 foreign key(organization_id,term_id,request_id)references public.finance_cases(organization_id,term_id,request_id),
 foreign key(organization_id,term_id,request_id,request_revision_id)references public.request_revisions(organization_id,term_id,request_id,id),
 foreign key(request_id,request_revision_id,revision_no)references public.request_revisions(request_id,id,revision_no),
 foreign key(manifest_id,request_id)references public.asset_manifests(id,work_item_id),
 foreign key(beneficiary_member_id)references public.members(id),
 foreign key(related_deliverable_id)references public.deliverables(work_item_id),
 check((case_kind in('fundraising','sales')and unit_price_centavos is not null and forecast_quantity_milli is not null and forecast_revenue_centavos is not null)
  or(case_kind not in('fundraising','sales')and unit_price_centavos is null and forecast_quantity_milli is null and forecast_revenue_centavos is null))
);
create table public.finance_lines(
 finance_revision_id uuid not null references public.finance_revisions(id),line_no integer not null check(line_no between 1 and 100),
 description text not null check(length(btrim(description))between 1 and 500),
 quantity_milli integer not null check(quantity_milli between 1 and 1000000000),
 unit_amount_centavos bigint not null check(unit_amount_centavos between 0 and 9007199254740991),
 total_centavos bigint not null check(total_centavos between 0 and 9007199254740991),
 primary key(finance_revision_id,line_no),
 check(total_centavos=floor((quantity_milli::numeric*unit_amount_centavos+500)/1000))
);
create index finance_revisions_scope on public.finance_revisions(organization_id,term_id,request_id);
do $$declare t text;begin
 foreach t in array array['finance_cases','finance_revisions','finance_lines']loop
  execute format('alter table public.%I enable row level security',t);
  execute format('alter table public.%I force row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('create trigger immutable_finance_history before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);
 end loop;
end$$;

create function app_private.finance_cents(v jsonb)returns bigint language plpgsql immutable set search_path='' as $$begin
 if jsonb_typeof(v)is distinct from 'string' or (v#>>'{}')!~'^(0|[1-9][0-9]{0,15})$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 if (v#>>'{}')::numeric>9007199254740991 then raise exception using errcode='22023',message='command_validation_failed';end if;
 return(v#>>'{}')::bigint;
end$$;
create function app_private.finance_quantity(v jsonb,allow_zero boolean default false)returns integer language plpgsql immutable set search_path='' as $$declare q numeric;begin
 if jsonb_typeof(v)is distinct from 'string' or(v#>>'{}')!~'^(0|[1-9][0-9]{0,6})(\.[0-9]{1,3})?$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 q:=(v#>>'{}')::numeric*1000;
 if q<(case when allow_zero then 0 else 1 end)or q>1000000000 then raise exception using errcode='22023',message='command_validation_failed';end if;return q::integer;
end$$;
create function app_private.validate_finance_payload(v jsonb)returns jsonb language plpgsql immutable set search_path='' as $$
declare line jsonb;lines jsonb:='[]';price jsonb;q integer;unit bigint;amount numeric;total numeric:=0;requested bigint;forecast numeric;begin
 if jsonb_typeof(v)is distinct from 'object'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if app_private.definition_keys(v,array['schemaVersion','currency','kind','purpose','fundSource','beneficiaryMemberId','relatedDeliverableId','plannedOn','termsRisks','lines','requestedTotalCentavos','pricing'])is distinct from true then raise exception using errcode='22023',message='command_validation_failed';end if;
 if v->'schemaVersion'is distinct from '1'::jsonb or v->>'currency'is distinct from 'PHP' or coalesce(v->>'kind','')not in('cost','budget','expense','reimbursement','fundraising','sales')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if app_private.definition_text(v->'purpose',2000)is distinct from true or app_private.definition_text(v->'fundSource',500)is distinct from true or app_private.definition_text(v->'termsRisks',4000)is distinct from true
 or length(btrim(v->>'purpose'))=0 or length(btrim(v->>'fundSource'))=0 or length(btrim(v->>'termsRisks'))=0 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if coalesce(v->>'beneficiaryMemberId','')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 or(v->>'relatedDeliverableId'is not null and(v->>'relatedDeliverableId')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
 or(v->>'plannedOn'is not null and(v->>'plannedOn')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$')then raise exception using errcode='22023',message='command_validation_failed';end if;
 if v->>'plannedOn'is not null then
  begin if not((v->>'plannedOn')::date between '0001-01-01'and'9999-12-31')then raise exception using errcode='22023',message='command_validation_failed';end if;
  exception when datetime_field_overflow or invalid_datetime_format then raise exception using errcode='22023',message='command_validation_failed';end;
 end if;
 if jsonb_typeof(v->'lines')is distinct from 'array'then raise exception using errcode='22023',message='command_validation_failed';end if;
 if jsonb_array_length(v->'lines')not between 1 and 100 or octet_length(v::text)>100000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 for line in select value from jsonb_array_elements(v->'lines')loop
  if jsonb_typeof(line)is distinct from 'object'then raise exception using errcode='22023',message='command_validation_failed';end if;
  if app_private.definition_keys(line,array['description','quantity','unitAmountCentavos','totalCentavos'])is distinct from true or app_private.definition_text(line->'description',500)is distinct from true or length(btrim(line->>'description'))=0 then raise exception using errcode='22023',message='command_validation_failed';end if;
  q:=app_private.finance_quantity(line->'quantity');unit:=app_private.finance_cents(line->'unitAmountCentavos');amount:=floor((q::numeric*unit+500)/1000);
  if amount>9007199254740991 or amount<>app_private.finance_cents(line->'totalCentavos')then raise exception using errcode='22023',message='command_validation_failed';end if;
  total:=total+amount;if total>9007199254740991 then raise exception using errcode='22023',message='command_validation_failed';end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('description',line->>'description','quantityMilli',q,'unitAmountCentavos',unit::text,'totalCentavos',amount::bigint::text));
 end loop;
 requested:=app_private.finance_cents(v->'requestedTotalCentavos');if total<>requested then raise exception using errcode='22023',message='command_validation_failed';end if;
 if v->>'kind'in('fundraising','sales')then
  price:=v->'pricing';if jsonb_typeof(price)is distinct from 'object'then raise exception using errcode='22023',message='command_validation_failed';end if;
  if app_private.definition_keys(price,array['unitPriceCentavos','forecastQuantity','forecastRevenueCentavos'])is distinct from true then raise exception using errcode='22023',message='command_validation_failed';end if;
  unit:=app_private.finance_cents(price->'unitPriceCentavos');q:=app_private.finance_quantity(price->'forecastQuantity',true);forecast:=floor((q::numeric*unit+500)/1000);
  if forecast>9007199254740991 or forecast<>app_private.finance_cents(price->'forecastRevenueCentavos')then raise exception using errcode='22023',message='command_validation_failed';end if;
  price:=jsonb_build_object('unitPriceCentavos',unit::text,'forecastQuantityMilli',q,'forecastRevenueCentavos',forecast::bigint::text);
 elsif v?'pricing'then raise exception using errcode='22023',message='command_validation_failed';end if;
 return(v-'lines'-'pricing')||jsonb_build_object('lines',lines,'pricing',price);
end$$;

create function public.submit_finance_request(p_work_item_id uuid,p_values jsonb,p_requested_on date,p_title text,p_finance_payload jsonb,p_expected_version integer,p_request_id uuid,p_revision boolean default false)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;t public.request_types;v jsonb;payload jsonb;result jsonb;rev public.request_revisions;fid uuid;line jsonb;n integer:=0;adapter bigint;begin
 w:=app_private.request_owned(p_work_item_id,true);select *into r from public.requests where work_item_id=w.id;
 select *into t from public.request_types where id=r.request_type_id;
 if t.governed_kind<>'fin' or r.payload_classification<>'restricted' or p_revision is null then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 payload:=jsonb_build_array(p_work_item_id,p_values,p_requested_on,p_title,p_finance_payload,p_expected_version,p_revision);
 result:=app_private.begin_work_command('submit_finance_request',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 v:=app_private.validate_finance_payload(p_finance_payload);
 if not exists(select 1 from public.term_memberships where term_id=w.term_id and member_id=(v->>'beneficiaryMemberId')::uuid and status='active'and membership_kind='core'and joined_at<=statement_timestamp()and(ends_at is null or ends_at>statement_timestamp()))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if v->>'relatedDeliverableId'is not null and not exists(select 1 from public.deliverables d join public.work_items dw on dw.id=d.work_item_id where dw.id=(v->>'relatedDeliverableId')::uuid and dw.term_id=w.term_id and dw.archived_at is null and public.can_access_work(dw.id,'detail'))then raise exception using errcode='42501',message='command_permission_denied';end if;
 if exists(select 1 from public.form_versions f cross join lateral jsonb_array_elements(f.schema_json->'fields')field where f.id=r.form_version_id and field->>'key'='requested_centavos'and field->>'storage'='finance')then adapter:=(v->>'requestedTotalCentavos')::bigint;end if;
 result:=app_private.submit_request_revision(w.id,p_values,adapter,p_requested_on,p_title,p_expected_version,p_request_id,p_revision);
 select *into r from public.requests where work_item_id=w.id;select *into rev from public.request_revisions where id=r.current_revision_id;
 insert into public.finance_cases(request_id,organization_id,term_id,created_by)values(w.id,w.organization_id,w.term_id,auth.uid())on conflict(request_id)do nothing;
 insert into public.finance_revisions(request_id,organization_id,term_id,request_revision_id,revision_no,case_kind,currency,purpose,fund_source,beneficiary_member_id,related_deliverable_id,planned_on,terms_risks,requested_total_centavos,unit_price_centavos,forecast_quantity_milli,forecast_revenue_centavos,manifest_id,manifest_hash,payload_hash,submitted_by)
 values(w.id,w.organization_id,w.term_id,rev.id,rev.revision_no,v->>'kind','PHP',v->>'purpose',v->>'fundSource',(v->>'beneficiaryMemberId')::uuid,(v->>'relatedDeliverableId')::uuid,(v->>'plannedOn')::date,v->>'termsRisks',(v->>'requestedTotalCentavos')::bigint,(v->'pricing'->>'unitPriceCentavos')::bigint,(v->'pricing'->>'forecastQuantityMilli')::integer,(v->'pricing'->>'forecastRevenueCentavos')::bigint,rev.manifest_id,rev.manifest_hash,
 encode(sha256(convert_to(jsonb_build_object('hashVersion','sha256-jsonb-v1','requestRevisionId',rev.id,'manifestHash',rev.manifest_hash,'payload',v)::text,'UTF8')),'hex'),auth.uid())returning id into fid;
 for line in select value from jsonb_array_elements(v->'lines')loop n:=n+1;
  insert into public.finance_lines values(fid,n,line->>'description',(line->>'quantityMilli')::integer,(line->>'unitAmountCentavos')::bigint,(line->>'totalCentavos')::bigint);
 end loop;
 select *into w from public.work_items where id=w.id;
 result:=result||jsonb_build_object('financeRevisionId',fid,'requestRevisionId',rev.id);
 return app_private.finish_work_command(w,'submit_finance_request',p_request_id,payload,result,'["restricted_finance_revision"]');
end$$;

create function public.read_finance_revision(p_term_id uuid,p_work_item_id uuid,p_revision integer default null)returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;w public.work_items;f public.finance_revisions;result jsonb;begin
 m:=app_private.request_actor(p_term_id);select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id;
 -- No label-based FIN or service-head access. P26 must supply independent typed authority.
 if w.id is null or w.archived_at is not null or w.owner_member_id<>m.member_id or not public.can_access_work(w.id,'detail')then return null;end if;
 select fr.*into f from public.finance_revisions fr join public.requests r on r.work_item_id=fr.request_id
 where fr.request_id=w.id and fr.revision_no=coalesce(p_revision,r.current_revision);if not found then return null;end if;
 result:=jsonb_build_object('id',f.id,'requestId',w.id,'requestRevisionId',f.request_revision_id,'revision',f.revision_no,'kind',f.case_kind,'currency',f.currency,'purpose',f.purpose,'fundSource',f.fund_source,'beneficiaryMemberId',f.beneficiary_member_id,'relatedDeliverableId',f.related_deliverable_id,'plannedOn',f.planned_on,'termsRisks',f.terms_risks,'requestedTotalCentavos',f.requested_total_centavos::text,
 'pricing',case when f.unit_price_centavos is not null then jsonb_build_object('unitPriceCentavos',f.unit_price_centavos::text,'forecastQuantityMilli',f.forecast_quantity_milli,'forecastRevenueCentavos',f.forecast_revenue_centavos::text,'forecastMarginCentavos',(f.forecast_revenue_centavos::numeric-f.requested_total_centavos)::text)end,
 'lines',(select jsonb_agg(jsonb_build_object('description',l.description,'quantityMilli',l.quantity_milli,'unitAmountCentavos',l.unit_amount_centavos::text,'totalCentavos',l.total_centavos::text)order by l.line_no)from public.finance_lines l where l.finance_revision_id=f.id),
 'manifestId',f.manifest_id,'manifestHash',f.manifest_hash,'payloadHash',f.payload_hash,'hashVersion',f.hash_version,
 'files',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.filename,'sha256',a.sha256,'size',a.size_bytes)order by a.id)from public.asset_manifest_items i join public.assets a on a.id=i.asset_id where i.manifest_id=f.manifest_id),'[]'));
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)
 values(w.organization_id,w.term_id,auth.uid(),'Current finance requester','read_finance_revision',w.id,f.revision_no,gen_random_uuid(),'{"fields":["restricted_finance_access"]}');return result;
end$$;

-- Once typed, every later request revision must also have a typed snapshot at commit.
create function app_private.finance_revision_required()returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.finance_cases where request_id=new.request_id)and not exists(select 1 from public.finance_revisions where request_revision_id=new.id)then raise exception using errcode='55000',message='command_finance_revision_required';end if;return new;
end$$;
create constraint trigger finance_revision_required after insert on public.request_revisions deferrable initially deferred for each row execute function app_private.finance_revision_required();
revoke all on function app_private.finance_cents(jsonb),app_private.finance_quantity(jsonb,boolean),app_private.validate_finance_payload(jsonb),app_private.finance_revision_required()from public,anon,authenticated,service_role;
revoke all on function public.submit_finance_request(uuid,jsonb,date,text,jsonb,integer,uuid,boolean),public.read_finance_revision(uuid,uuid,integer)from public,anon,authenticated,service_role;
grant execute on function public.submit_finance_request(uuid,jsonb,date,text,jsonb,integer,uuid,boolean),public.read_finance_revision(uuid,uuid,integer)to authenticated;
