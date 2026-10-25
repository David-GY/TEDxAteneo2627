-- P27: configuration remains empty; no actual account, authority or fund is invented.
create table public.budget_accounts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),term_id uuid not null references public.terms(id),
 unit_id uuid not null references public.org_units(id),fund_source text not null check(length(btrim(fund_source))between 1 and 500),
 ceiling_centavos bigint not null check(ceiling_centavos between 0 and 9007199254740991),enabled boolean not null,
 official_reference text not null check(length(btrim(official_reference))between 1 and 1000),confirmed_by uuid not null references public.term_memberships(id),
 effective_from timestamptz not null,effective_to timestamptz not null,check(effective_to>effective_from),unique(id,term_id)
);
alter table public.finance_authorization_policies add budget_account_id uuid references public.budget_accounts(id),add reconciliation_enabled boolean not null default false;
create table public.budget_entries(
 id uuid primary key default gen_random_uuid(),account_id uuid not null references public.budget_accounts(id),authorization_id uuid not null references public.financial_authorizations(id),
 kind text not null check(kind in('reservation','release','expense','revenue','reversal')),
 reserved_delta_centavos bigint not null default 0,expense_delta_centavos bigint not null default 0,revenue_delta_centavos bigint not null default 0,
 reverses_entry_id uuid unique references public.budget_entries(id),actor_id uuid not null references auth.users(id),reason text not null check(length(btrim(reason))between 1 and 2000),recorded_at timestamptz not null default statement_timestamp(),
 check((kind='reservation'and reserved_delta_centavos>=0 and expense_delta_centavos=0 and revenue_delta_centavos=0 and reverses_entry_id is null)
 or(kind='release'and reserved_delta_centavos<=0 and expense_delta_centavos=0 and revenue_delta_centavos=0 and reverses_entry_id is null)
 or(kind='expense'and reserved_delta_centavos<=0 and expense_delta_centavos>0 and revenue_delta_centavos=0 and reverses_entry_id is null)
 or(kind='revenue'and reserved_delta_centavos=0 and expense_delta_centavos=0 and revenue_delta_centavos>0 and reverses_entry_id is null)
 or(kind='reversal'and reserved_delta_centavos=0 and expense_delta_centavos<=0 and revenue_delta_centavos<=0 and reverses_entry_id is not null))
);
create unique index budget_reservation_once on public.budget_entries(authorization_id)where kind='reservation';
create unique index budget_release_once on public.budget_entries(authorization_id)where kind='release';
create index budget_entries_account on public.budget_entries(account_id,authorization_id);
create table public.actual_finance_records(
 id uuid primary key default gen_random_uuid(),request_id uuid not null references public.finance_cases(request_id),term_id uuid not null references public.terms(id),
 authorization_id uuid not null references public.financial_authorizations(id),kind text not null check(kind in('expense','revenue')),amount_centavos bigint not null check(amount_centavos between 1 and 9007199254740991),
 evidence_asset_id uuid not null,evidence_sha256 text not null check(evidence_sha256~'^[0-9a-f]{64}$'),reference text not null check(length(btrim(reference))between 1 and 200),
 recorded_on date not null,recorded_by uuid not null references auth.users(id),recorded_at timestamptz not null default statement_timestamp(),
 unique(term_id,kind,evidence_sha256),unique(term_id,kind,reference),foreign key(evidence_asset_id,request_id)references public.assets(id,origin_work_item_id)
);
create index actual_finance_case on public.actual_finance_records(request_id,recorded_at,id);
create table public.actual_finance_events(
 id uuid primary key default gen_random_uuid(),record_id uuid not null references public.actual_finance_records(id),kind text not null check(kind in('booked','reversed')),
 authorization_id uuid not null references public.financial_authorizations(id),entry_id uuid unique references public.budget_entries(id),
 actor_id uuid not null references auth.users(id),reason text not null check(length(btrim(reason))between 1 and 2000),recorded_at timestamptz not null default statement_timestamp(),unique(record_id,kind)
);
do $$declare t text;begin foreach t in array array['budget_accounts','budget_entries','actual_finance_records','actual_finance_events']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 execute format('create trigger immutable_finance_ledger before update or delete on public.%I for each row execute function app_private.request_history_guard()',t);
end loop;end$$;

create function app_private.finance_ledger_actor(r public.requests)returns public.term_memberships language plpgsql security definer set search_path='' as $$
declare m public.term_memberships;begin m:=app_private.request_actor(r.term_id);
 if r.work_item_id is null or not coalesce((app_private.finance_policy(r)).reconciliation_enabled,false)or exists(select 1 from public.work_items where id=r.work_item_id and archived_at is not null)or(app_private.finance_assignment(r,m.id)).id is null then raise exception using errcode='42501',message='command_permission_denied';end if;return m;end$$;
create function app_private.budget_available(account uuid)returns numeric language sql stable security definer set search_path='' as $$
 select a.ceiling_centavos-coalesce((select sum(e.reserved_delta_centavos::numeric+e.expense_delta_centavos)from public.budget_entries e where e.account_id=a.id),0)from public.budget_accounts a where a.id=account
$$;
create function app_private.finance_expenses(work uuid)returns numeric language sql stable security definer set search_path='' as $$
 select coalesce(sum(a.amount_centavos::numeric),0)from public.actual_finance_records a where a.request_id=work and a.kind='expense'and exists(select 1 from public.actual_finance_events e where e.record_id=a.id and e.kind='booked')and not exists(select 1 from public.actual_finance_events e where e.record_id=a.id and e.kind='reversed')
$$;
create function app_private.reserve_financial_budget()returns trigger language plpgsql security definer set search_path='' as $$
declare account public.budget_accounts;policy public.finance_authorization_policies;r public.requests;amount numeric;begin
 select *into policy from public.finance_authorization_policies where id=new.policy_id;
 if app_private.finance_expenses(new.request_id)>new.ceiling_centavos then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if policy.budget_account_id is null then return new;end if;
 select *into account from public.budget_accounts where id=policy.budget_account_id for update;select *into r from public.requests where work_item_id=new.request_id;
 if current_setting('transaction_isolation')<>'read committed'or account.id is null or not account.enabled or account.organization_id<>new.organization_id or account.term_id<>new.term_id or account.unit_id<>r.receiving_unit_id or account.fund_source is distinct from(select fund_source from public.finance_revisions where id=new.finance_revision_id)
 or account.effective_from>statement_timestamp()or account.effective_to<=statement_timestamp()or not exists(select 1 from public.term_memberships where id=account.confirmed_by and term_id=account.term_id and organization_id=account.organization_id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if exists(select 1 from public.budget_entries e join public.financial_authorizations a on a.id=e.authorization_id where a.request_id=new.request_id group by e.authorization_id having sum(e.reserved_delta_centavos)>0)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 amount:=new.ceiling_centavos-app_private.finance_expenses(new.request_id);
 if amount<0 or amount>app_private.budget_available(account.id)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 insert into public.budget_entries(account_id,authorization_id,kind,reserved_delta_centavos,actor_id,reason)values(account.id,new.id,'reservation',amount::bigint,auth.uid(),'Exact FIN permit reservation');return new;
end$$;
create trigger reserve_financial_budget after insert on public.financial_authorizations for each row execute function app_private.reserve_financial_budget();

create function app_private.release_financial_budget(auth_id uuid,explanation text)returns void language plpgsql security definer set search_path='' as $$
declare entry public.budget_entries;remaining bigint;begin
 select *into entry from public.budget_entries where authorization_id=auth_id and kind='reservation';if entry.id is null then return;end if;
 perform 1 from public.budget_accounts where id=entry.account_id for update;
 if exists(select 1 from public.budget_entries where authorization_id=auth_id and kind='release')then return;end if;
 select coalesce(sum(reserved_delta_centavos),0)::bigint into remaining from public.budget_entries where authorization_id=auth_id;
 insert into public.budget_entries(account_id,authorization_id,kind,reserved_delta_centavos,actor_id,reason)values(entry.account_id,auth_id,'release',-remaining,auth.uid(),explanation);
end$$;
create function app_private.cancel_financial_budget()returns trigger language plpgsql security definer set search_path='' as $$declare a public.financial_authorizations;begin
 if new.request_state='cancelled'and old.request_state is distinct from new.request_state then
 perform 1 from public.budget_accounts b where b.id in(select e.account_id from public.budget_entries e join public.financial_authorizations fa on fa.id=e.authorization_id where fa.request_id=new.work_item_id)order by b.id for update;
 for a in select *from public.financial_authorizations where request_id=new.work_item_id order by id loop perform app_private.release_financial_budget(a.id,'Explicit request cancellation');end loop;end if;return new;end$$;
create trigger cancel_financial_budget after update of request_state on public.requests for each row execute function app_private.cancel_financial_budget();
create function public.release_finance_budget(p_authorization_id uuid,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.financial_authorizations;w public.work_items;r public.requests;m public.term_memberships;payload jsonb;result jsonb;begin
 select *into a from public.financial_authorizations where id=p_authorization_id;select *into w from public.work_items where id=a.request_id for update;select *into r from public.requests where work_item_id=w.id;
 m:=app_private.finance_ledger_actor(r);perform app_private.lock_finance_scope(r,m.id);m:=app_private.finance_ledger_actor(r);
 payload:=jsonb_build_array(p_authorization_id,p_reason,p_expected_version);result:=app_private.begin_work_command('release_finance_budget',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 insert into public.financial_authorization_events(authorization_id,kind,reason,actor_id)values(a.id,'revoked',p_reason,auth.uid())on conflict(authorization_id,kind)do nothing;
 perform app_private.release_financial_budget(a.id,p_reason);update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'release_finance_budget',p_request_id,payload,jsonb_build_object('authorizationId',a.id,'version',w.version),'["budget_release"]');end$$;

-- Returns false for an overrun/budget shortfall; the immutable documented record stays pending review.
create function app_private.book_finance_actual(item public.actual_finance_records,permit public.financial_authorizations,explanation text)returns boolean language plpgsql security definer set search_path='' as $$
declare account uuid;entry uuid;remaining numeric;amount bigint:=item.amount_centavos;begin
 if permit.request_id<>item.request_id or app_private.financial_authorization_state(permit)<>'valid'or exists(select 1 from public.budget_entries where authorization_id=permit.id and kind='release')then return false;end if;
 if item.kind='expense'and app_private.finance_expenses(item.request_id)+amount>permit.ceiling_centavos then return false;end if;
 select budget_account_id into account from public.finance_authorization_policies where id=permit.policy_id;
 if account is not null then
  perform 1 from public.budget_accounts where id=account for update;
  select coalesce(sum(reserved_delta_centavos),0)into remaining from public.budget_entries where authorization_id=permit.id;
  if item.kind='expense'and greatest(amount-remaining,0)>app_private.budget_available(account)then return false;end if;
  insert into public.budget_entries(account_id,authorization_id,kind,reserved_delta_centavos,expense_delta_centavos,revenue_delta_centavos,actor_id,reason)
  values(account,permit.id,item.kind,case when item.kind='expense'then -least(remaining,amount)::bigint else 0 end,case when item.kind='expense'then amount else 0 end,case when item.kind='revenue'then amount else 0 end,auth.uid(),explanation)returning id into entry;
 end if;
 insert into public.actual_finance_events(record_id,kind,authorization_id,entry_id,actor_id,reason)values(item.id,'booked',permit.id,entry,auth.uid(),explanation);return true;
end$$;
create function public.record_finance_actual(p_work_item_id uuid,p_kind text,p_amount_centavos text,p_evidence_asset_id uuid,p_reference text,p_recorded_on date,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;a public.financial_authorizations;asset public.assets;item public.actual_finance_records;payload jsonb;result jsonb;booked boolean;amount bigint;begin
 select *into w from public.work_items where id=p_work_item_id for update;select *into r from public.requests where work_item_id=w.id;m:=app_private.finance_ledger_actor(r);perform app_private.lock_finance_scope(r,m.id);m:=app_private.finance_ledger_actor(r);
 payload:=jsonb_build_array(p_work_item_id,p_kind,p_amount_centavos,p_evidence_asset_id,p_reference,p_recorded_on,p_reason,p_expected_version);result:=app_private.begin_work_command('record_finance_actual',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 select *into a from public.financial_authorizations where request_revision_id=r.current_revision_id;
 if a.id is null or app_private.financial_authorization_state(a)<>'valid'or exists(select 1 from public.budget_entries where authorization_id=a.id and kind='release')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 amount:=app_private.finance_cents(to_jsonb(p_amount_centavos));
 if amount<=0 or p_kind is null or p_kind not in('expense','revenue')or p_reference is null or length(btrim(p_reference))not between 1 and 200 or p_reason is null or length(btrim(p_reason))not between 1 and 2000 or p_recorded_on is null or p_recorded_on>(statement_timestamp()at time zone'Asia/Manila')::date or not exists(select 1 from public.terms where id=w.term_id and p_recorded_on between starts_on and closes_on)then raise exception using errcode='22023',message='command_validation_failed';end if;
 select *into asset from public.assets where id=p_evidence_asset_id and origin_work_item_id=w.id and kind='upload'and state='finalized'and exists(select 1 from public.asset_manifest_items where asset_id=p_evidence_asset_id);
 if asset.id is null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from public.actual_finance_records where term_id=w.term_id and kind=p_kind and(evidence_sha256=asset.sha256 or reference=lower(btrim(p_reference))))then raise exception using errcode='23505',message='command_duplicate_evidence';end if;
 insert into public.actual_finance_records(request_id,term_id,authorization_id,kind,amount_centavos,evidence_asset_id,evidence_sha256,reference,recorded_on,recorded_by)
 values(w.id,w.term_id,a.id,p_kind,amount,asset.id,asset.sha256,lower(btrim(p_reference)),p_recorded_on,auth.uid())returning *into item;
 booked:=app_private.book_finance_actual(item,a,p_reason);update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'record_finance_actual',p_request_id,payload,jsonb_build_object('requestId',w.id,'recordId',item.id,'state',case when booked then 'booked'else 'requires_review'end,'version',w.version),'["documented_actual"]');end$$;
create function public.reconcile_finance_actual(p_record_id uuid,p_action text,p_reason text,p_expected_version integer,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.actual_finance_records;w public.work_items;r public.requests;m public.term_memberships;a public.financial_authorizations;booking public.actual_finance_events;entry public.budget_entries;new_entry uuid;payload jsonb;result jsonb;begin
 select *into item from public.actual_finance_records where id=p_record_id;select *into w from public.work_items where id=item.request_id for update;select *into r from public.requests where work_item_id=w.id;m:=app_private.finance_ledger_actor(r);perform app_private.lock_finance_scope(r,m.id);m:=app_private.finance_ledger_actor(r);
 payload:=jsonb_build_array(p_record_id,p_action,p_reason,p_expected_version);result:=app_private.begin_work_command('reconcile_finance_actual',p_request_id,payload);if result is not null then return result;end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_action is null or p_action not in('book','reverse')or p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 if exists(select 1 from public.actual_finance_events where record_id=item.id and kind='reversed')then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 select *into a from public.financial_authorizations where request_revision_id=r.current_revision_id;select *into booking from public.actual_finance_events where record_id=item.id and kind='booked';
 if p_action='book'then
  if booking.id is not null or a.id is null or a.id=item.authorization_id or not app_private.book_finance_actual(item,a,p_reason)then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 else
  if booking.entry_id is not null then
   select *into entry from public.budget_entries where id=booking.entry_id;perform 1 from public.budget_accounts where id=entry.account_id for update;
   -- A reversed expense refunds booked use; it never recreates a cancelled financial commitment.
   insert into public.budget_entries(account_id,authorization_id,kind,expense_delta_centavos,revenue_delta_centavos,reverses_entry_id,actor_id,reason)
   values(entry.account_id,entry.authorization_id,'reversal',-entry.expense_delta_centavos,-entry.revenue_delta_centavos,entry.id,auth.uid(),p_reason)returning id into new_entry;
  end if;
  insert into public.actual_finance_events(record_id,kind,authorization_id,entry_id,actor_id,reason)values(item.id,'reversed',coalesce(booking.authorization_id,item.authorization_id),new_entry,auth.uid(),p_reason);
 end if;
 update public.work_items set title=title where id=w.id returning *into w;
 return app_private.finish_work_command(w,'reconcile_finance_actual',p_request_id,payload,jsonb_build_object('recordId',item.id,'state',case when p_action='book'then 'booked'else 'reversed'end,'version',w.version),'["actual_reconciliation"]');end$$;

create function public.read_finance_ledger(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;m public.term_memberships;a public.financial_authorizations;account public.budget_accounts;rows jsonb;begin
 select *into w from public.work_items where id=p_work_item_id and term_id=p_term_id;select *into r from public.requests where work_item_id=w.id;
 begin m:=app_private.finance_ledger_actor(r);exception when sqlstate '42501'then return null;end;
 select *into a from public.financial_authorizations where request_revision_id=r.current_revision_id;
 select b.*into account from public.budget_accounts b join public.finance_authorization_policies p on p.budget_account_id=b.id where p.id=a.policy_id;
 select coalesce(jsonb_agg(row order by recorded_at,id),'[]')into rows from(select ar.id,ar.recorded_at,jsonb_build_object('id',ar.id,'kind',ar.kind,'amountCentavos',ar.amount_centavos::text,'reference',ar.reference,'recordedOn',ar.recorded_on,'evidenceAssetId',ar.evidence_asset_id,'evidenceSha256',ar.evidence_sha256,'state',case when exists(select 1 from public.actual_finance_events e where e.record_id=ar.id and e.kind='reversed')then 'reversed'when exists(select 1 from public.actual_finance_events e where e.record_id=ar.id and e.kind='booked')then 'booked'else 'requires_review'end)row from public.actual_finance_records ar where ar.request_id=w.id order by ar.recorded_at desc,ar.id limit 100)items;
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(w.organization_id,w.term_id,auth.uid(),'Current independent FIN reviewer','read_finance_ledger',w.id,r.current_revision,gen_random_uuid(),'{"fields":["restricted_ledger_access"]}');
 return jsonb_build_object('id',w.id,'version',w.version,'authorizationId',a.id,'authorizationState',case when a.id is not null then app_private.financial_authorization_state(a)end,'downloadContext',(select review_context_id from public.workflow_instances where revision_id=r.current_revision_id),'requestedCentavos',(select requested_total_centavos::text from public.finance_revisions where request_revision_id=r.current_revision_id),'ceilingCentavos',a.ceiling_centavos::text,
 'bookedExpenseCentavos',app_private.finance_expenses(w.id)::text,'actualRevenueCentavos',(select coalesce(sum(ar.amount_centavos::numeric),0)::text from public.actual_finance_records ar where ar.request_id=w.id and ar.kind='revenue'and exists(select 1 from public.actual_finance_events e where e.record_id=ar.id and e.kind='booked')and not exists(select 1 from public.actual_finance_events e where e.record_id=ar.id and e.kind='reversed')),
 'budget',case when account.id is not null then jsonb_build_object('id',account.id,'fundSource',account.fund_source,'ceilingCentavos',account.ceiling_centavos::text,'availableCentavos',app_private.budget_available(account.id)::text,'reservedCentavos',(select coalesce(sum(reserved_delta_centavos),0)::text from public.budget_entries where authorization_id=a.id))end,
 'commitments',coalesce((select jsonb_agg(jsonb_build_object('id',old_auth.id,'revision',fr.revision_no,'reservedCentavos',(select coalesce(sum(e.reserved_delta_centavos),0)::text from public.budget_entries e where e.authorization_id=old_auth.id),'state',app_private.financial_authorization_state(old_auth)))from public.financial_authorizations old_auth join public.finance_revisions fr on fr.id=old_auth.finance_revision_id where old_auth.request_id=w.id and exists(select 1 from public.budget_entries e where e.authorization_id=old_auth.id and e.kind='reservation')and not exists(select 1 from public.budget_entries e where e.authorization_id=old_auth.id and e.kind='release')),'[]'),
 'canRecord',a.id is not null and app_private.financial_authorization_state(a)='valid'and not exists(select 1 from public.budget_entries where authorization_id=a.id and kind='release'),'records',rows,
 'evidence',coalesce((select jsonb_agg(jsonb_build_object('id',asset.id,'name',asset.filename,'sha256',asset.sha256))from public.assets asset where asset.origin_work_item_id=w.id and asset.state='finalized'and asset.kind='upload'and(asset.created_at>=a.recorded_at or exists(select 1 from public.actual_finance_records recorded where recorded.evidence_asset_id=asset.id and recorded.request_id=w.id))and exists(select 1 from public.asset_manifest_items where asset_id=asset.id)),'[]'),
 'entries',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'reservedDelta',e.reserved_delta_centavos::text,'expenseDelta',e.expense_delta_centavos::text,'revenueDelta',e.revenue_delta_centavos::text,'reversesEntryId',e.reverses_entry_id))from public.budget_entries e join public.financial_authorizations fa on fa.id=e.authorization_id where fa.request_id=w.id),'[]'));
end$$;

alter function public.read_finance_gate(uuid,uuid)rename to read_finance_gate_p26;
alter function public.read_finance_gate_p26(uuid,uuid)set schema app_private;
create function public.read_finance_gate(p_term_id uuid,p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;target uuid;begin
 result:=app_private.read_finance_gate_p26(p_term_id,p_work_item_id);if result is null or result->>'state'<>'authorized'then return result;end if;
 select case when kind='deliverable'then id else parent_work_item_id end into target from public.work_items where id=p_work_item_id;
 if exists(select 1 from public.finance_revisions f join public.requests r on r.current_revision_id=f.request_revision_id join public.work_items w on w.id=r.work_item_id where f.related_deliverable_id=target and r.term_id=p_term_id and r.request_state<>'cancelled'and w.archived_at is null and(exists(select 1 from public.actual_finance_records ar where ar.request_id=r.work_item_id and not exists(select 1 from public.actual_finance_events e where e.record_id=ar.id))or exists(select 1 from public.financial_authorizations a join public.budget_entries e on e.authorization_id=a.id and e.kind='release'where a.request_revision_id=r.current_revision_id)))then return '{"state":"pending"}';end if;return result;end$$;

alter function public.authorize_asset_download(uuid,uuid,uuid)rename to authorize_asset_download_p26;
alter function public.authorize_asset_download_p26(uuid,uuid,uuid)set schema app_private;
create function public.authorize_asset_download(p_work_item_id uuid,p_asset_id uuid,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.requests;x public.workflow_instances;m public.term_memberships;a public.assets;payload jsonb;prior jsonb;begin
 select *into x from public.workflow_instances where review_context_id=p_work_item_id;select *into r from public.requests where work_item_id=x.request_id;
 if x.id is null or r.current_revision_id<>x.revision_id or not(exists(select 1 from public.actual_finance_records where request_id=r.work_item_id and evidence_asset_id=p_asset_id)or exists(select 1 from public.assets pending join public.financial_authorizations fa on fa.request_id=pending.origin_work_item_id join public.work_items wi on wi.id=fa.request_id where pending.id=p_asset_id and fa.request_revision_id=r.current_revision_id and pending.created_at>=fa.recorded_at and app_private.can_add_finance_receipt(wi)))then return app_private.authorize_asset_download_p26(p_work_item_id,p_asset_id,p_request_id);end if;
 m:=app_private.finance_ledger_actor(r);select *into a from public.assets where id=p_asset_id and origin_work_item_id=r.work_item_id and state='finalized';if a.id is null then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_id);prior:=app_private.begin_work_command('download_finance_actual',p_request_id,payload);
 if prior is null then
 insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values(r.organization_id,r.term_id,auth.uid(),'Current independent FIN reviewer','download_finance_actual',r.work_item_id,r.current_revision,p_request_id,'{"fields":["actual_evidence_bytes"]}');
 insert into public.idempotency_keys(actor_id,command,client_key,organization_id,term_id,payload_hash,result_reference)values(auth.uid(),'download_finance_actual',p_request_id,r.organization_id,r.term_id,encode(sha256(convert_to(payload::text,'UTF8')),'hex'),'{}');end if;
 return jsonb_build_object('assetId',a.id,'path',a.object_path,'kind',a.kind,'mime',a.mime_type,'size',a.size_bytes,'sha256',a.sha256);end$$;

revoke all on function app_private.finance_ledger_actor(public.requests),app_private.budget_available(uuid),app_private.finance_expenses(uuid),app_private.reserve_financial_budget(),app_private.release_financial_budget(uuid,text),app_private.cancel_financial_budget(),app_private.book_finance_actual(public.actual_finance_records,public.financial_authorizations,text),app_private.read_finance_gate_p26(uuid,uuid),app_private.authorize_asset_download_p26(uuid,uuid,uuid)from public,anon,authenticated,service_role;
revoke all on function public.release_finance_budget(uuid,text,integer,uuid),public.record_finance_actual(uuid,text,text,uuid,text,date,text,integer,uuid),public.reconcile_finance_actual(uuid,text,text,integer,uuid),public.read_finance_ledger(uuid,uuid),public.read_finance_gate(uuid,uuid),public.authorize_asset_download(uuid,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.release_finance_budget(uuid,text,integer,uuid),public.record_finance_actual(uuid,text,text,uuid,text,date,text,integer,uuid),public.reconcile_finance_actual(uuid,text,text,integer,uuid),public.read_finance_ledger(uuid,uuid),public.read_finance_gate(uuid,uuid),public.authorize_asset_download(uuid,uuid,uuid)to authenticated;

-- Receipt uploads are a file-only extension; approved request editing remains closed.
create function app_private.can_add_finance_receipt(w public.work_items)returns boolean language plpgsql stable security definer set search_path='' as $$declare r public.requests;member uuid;begin
 select *into r from public.requests where work_item_id=w.id;
 if r.request_state<>'approved'or not coalesce((app_private.finance_policy(r)).reconciliation_enabled,false)or w.archived_at is not null or not exists(select 1 from public.financial_authorizations a where a.request_revision_id=r.current_revision_id and app_private.financial_authorization_state(a)='valid'and not exists(select 1 from public.budget_entries e where e.authorization_id=a.id and e.kind='release'))then return false;end if;
 select member_id into member from public.term_memberships where id=public.current_term_membership(w.term_id)and membership_kind='core';
 return member is not null and public.has_capability(w.term_id,'workspace.read')and(member=w.owner_member_id or(app_private.finance_assignment(r,public.current_term_membership(w.term_id))).id is not null);end$$;
create or replace function app_private.file_work(p_id uuid,p_version integer)returns public.work_items language plpgsql set search_path='' as $$declare w public.work_items;begin
 select *into w from public.work_items where id=p_id for update;
 if w.id is null or not((w.kind in('task','deliverable')or(w.kind='request'and exists(select 1 from public.requests where work_item_id=w.id and request_type_id is not null and request_state in('draft','revision_draft'))))and public.can_access_work(w.id,'edit')or app_private.can_add_finance_receipt(w))or public.current_term_membership(w.term_id)is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active')then raise exception using errcode='42501',message='command_permission_denied';end if;
 if w.version is distinct from p_version then raise exception using errcode='40001',message='command_stale_version';end if;return w;end$$;

create or replace function public.reserve_upload(p_work_item_id uuid,p_name text,p_mime text,p_size integer,p_sha256 text,p_source_id uuid,p_source_version integer,p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;s public.assets;payload jsonb;result jsonb;path text;begin
 select * into w from public.work_items where id=p_work_item_id;
 if not(public.can_access_work(w.id,'edit')or app_private.can_add_finance_receipt(w)) or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_name,p_mime,p_size,p_sha256,p_source_id,p_source_version,p_expected_version);result:=app_private.begin_work_command('reserve_upload',p_request_id,payload);if result is not null then return result;end if;
 w:=app_private.file_work(p_work_item_id,p_expected_version);
 if p_name is null or length(p_name) not between 1 and 160 or p_name ~ '[\r\n]' or p_mime is null or p_mime not in ('application/pdf','image/jpeg','image/png') or p_size is null or p_size not between 1 and 5242880 or p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then raise exception using errcode='22023',message='command_validation_failed';end if;
 if (select coalesce(sum(size_bytes),0) from public.assets where origin_work_item_id=w.id and (state='validated' or(state='reserved' and expires_at>statement_timestamp())))+p_size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
 if app_private.can_add_finance_receipt(w)and p_source_id is not null then raise exception using errcode='22023',message='command_validation_failed';end if;
 if p_source_id is not null then select * into s from public.assets where id=p_source_id and kind='working_link' and origin_work_item_id=w.id and version=p_source_version;if not found then raise exception using errcode='40001',message='command_stale_version';end if;end if;
 path:=gen_random_uuid()::text||'/'||gen_random_uuid()::text||case p_mime when 'application/pdf' then '.pdf' when 'image/png' then '.png' else '.jpg' end;
 insert into public.assets(origin_work_item_id,kind,classification,filename,mime_type,size_bytes,sha256,object_path,state,created_by,expires_at,source_snapshot)
 values(w.id,'upload',w.classification,p_name,p_mime,p_size,p_sha256,path,'reserved',auth.uid(),statement_timestamp()+interval'20 minutes',case when s.id is not null then jsonb_build_object('assetId',s.id,'version',s.version,'url',s.source_url,'label',s.source_label,'accessNotes',s.access_notes) end) returning * into a;
 insert into public.asset_links(asset_id,work_item_id,created_by) values(a.id,w.id,auth.uid());
 return app_private.finish_work_command(w,'reserve_upload',p_request_id,payload,jsonb_build_object('assetId',a.id,'path',path,'version',1),'["asset_reservation"]');
end$$;


create or replace function public.finalize_upload(p_work_item_id uuid,p_asset_ids uuid[],p_expected_version integer,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;a public.assets;payload jsonb;result jsonb;entries jsonb;size integer;mid uuid;begin
 select * into w from public.work_items where id=p_work_item_id;
 if not(public.can_access_work(w.id,'edit')or app_private.can_add_finance_receipt(w)) or public.current_term_membership(w.term_id) is null or w.archived_at is not null or not exists(select 1 from public.terms where id=w.term_id and state='active') then raise exception using errcode='42501',message='command_permission_denied';end if;
 payload:=jsonb_build_array(p_work_item_id,p_asset_ids,p_expected_version);result:=app_private.begin_work_command('finalize_upload',p_request_id,payload);if result is not null then return result;end if;
 w:=app_private.file_work(p_work_item_id,p_expected_version);
 if p_asset_ids is null or cardinality(p_asset_ids) not between 1 and 20 or array_ndims(p_asset_ids)>1 or cardinality(p_asset_ids)<>(select count(distinct x) from unnest(p_asset_ids)x) then raise exception using errcode='22023',message='command_validation_failed';end if;
 for a in select * from public.assets where id=any(p_asset_ids) order by id for update loop
 if a.kind<>'upload' or a.state not in ('validated','finalized') or a.origin_work_item_id<>w.id then raise exception using errcode='42501',message='command_permission_denied';end if;end loop;
 if (select count(*) from public.assets where id=any(p_asset_ids))<>cardinality(p_asset_ids) then raise exception using errcode='42501',message='command_permission_denied';end if;
 select sum(size_bytes)::integer,jsonb_agg(jsonb_build_object('assetId',id,'sha256',sha256,'size',size_bytes,'mime',mime_type,'classification',classification,'source',source_snapshot)order by id) into size,entries from public.assets where id=any(p_asset_ids);
 if size>20971520 then raise exception using errcode='22023',message='command_quota_limit';end if;
 insert into public.asset_manifests(work_item_id,work_version,entries,sha256,size_bytes,created_by) values(w.id,w.version,entries,encode(sha256(convert_to(entries::text,'UTF8')),'hex'),size,auth.uid()) returning id into mid;
 insert into public.asset_manifest_items(manifest_id,asset_id) select mid,unnest(p_asset_ids);
 update public.assets set state='finalized',version=version+1,updated_at=statement_timestamp() where id=any(p_asset_ids) and state='validated';
 return app_private.finish_work_command(w,'finalize_upload',p_request_id,payload,jsonb_build_object('manifestId',mid,'sha256',encode(sha256(convert_to(entries::text,'UTF8')),'hex')),'["immutable_manifest"]');
end$$;


revoke all on function app_private.can_add_finance_receipt(public.work_items)from public,anon,authenticated,service_role;

create or replace function public.cancel_request(p_work_item_id uuid,p_expected_version integer,p_reason text,p_request_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items;r public.requests;payload jsonb;result jsonb;begin
 w:=app_private.request_owned(p_work_item_id,true);payload:=jsonb_build_array(p_work_item_id,p_expected_version,p_reason);result:=app_private.begin_work_command('cancel_request',p_request_id,payload);if result is not null then return result;end if;
 select * into r from public.requests where work_item_id=w.id;
 if r.request_state not in('draft','revision_draft','paused','in_review','needs_revision')and not(r.request_state='approved'and exists(select 1 from public.finance_cases where request_id=w.id))then raise exception using errcode='55000',message='command_dependency_blocked';end if;
 if w.version is distinct from p_expected_version then raise exception using errcode='40001',message='command_stale_version';end if;
 if p_reason is null or length(btrim(p_reason))not between 1 and 2000 then raise exception using errcode='22023',message='command_validation_failed';end if;
 update public.requests set request_state='cancelled'where work_item_id=w.id;
 update public.workflow_instances set state='cancelled'where request_id=w.id and state in('paused','active','needs_revision');
 update public.work_items set status_id=app_private.request_status(w.term_id,'cancelled')where id=w.id returning * into w;
 perform app_private.request_event(w,'cancelled',p_reason);return app_private.finish_work_command(w,'cancel_request',p_request_id,payload,app_private.request_receipt(w),'["request_cancelled"]');
end$$;


alter function public.read_request(uuid,uuid,integer,integer)rename to read_request_p26;
alter function public.read_request_p26(uuid,uuid,integer,integer)set schema app_private;
create function public.read_request(p_term_id uuid,p_work_item_id uuid,p_revision integer default null,p_history_page integer default 1)returns jsonb language plpgsql stable security definer set search_path='' as $$declare result jsonb;begin
 result:=app_private.read_request_p26(p_term_id,p_work_item_id,p_revision,p_history_page);if result is null then return null;end if;
 if result->>'governedKind'='fin'and result->>'state'='approved'then return result||'{"canCancel":true}';end if;return result;end$$;
revoke all on function app_private.read_request_p26(uuid,uuid,integer,integer),public.read_request(uuid,uuid,integer,integer)from public,anon,authenticated,service_role;
grant execute on function public.read_request(uuid,uuid,integer,integer)to authenticated;

alter function public.read_files(uuid)rename to read_files_p26;
alter function public.read_files_p26(uuid)set schema app_private;
create function public.read_files(p_work_item_id uuid)returns jsonb language plpgsql stable security definer set search_path='' as $$declare w public.work_items;r public.requests;a public.financial_authorizations;owner boolean;begin
 select *into w from public.work_items where id=p_work_item_id;
 if not app_private.can_add_finance_receipt(w)then return app_private.read_files_p26(p_work_item_id);end if;
 select *into r from public.requests where work_item_id=w.id;select *into a from public.financial_authorizations where request_revision_id=r.current_revision_id;
 owner:=public.can_access_work(w.id,'detail');
 return jsonb_build_object('workVersion',w.version,'canEdit',true,'assets',coalesce((select jsonb_agg(to_jsonb(asset)-array['object_path','created_by','expires_at']order by asset.created_at,asset.id)from public.assets asset where asset.origin_work_item_id=w.id and asset.state<>'reserved'and(owner or asset.created_at>=a.recorded_at or exists(select 1 from public.actual_finance_records ar where ar.request_id=w.id and ar.evidence_asset_id=asset.id))),'[]'),'manifests','[]'::jsonb);end$$;
revoke all on function app_private.read_files_p26(uuid),public.read_files(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_files(uuid)to authenticated;

-- Defense in depth: every ledger insert takes the account lock, even internal callers.
create function app_private.budget_entry_guard()returns trigger language plpgsql security definer set search_path='' as $$
declare a public.financial_authorizations;original public.budget_entries;begin
 perform 1 from public.budget_accounts where id=new.account_id for update;
 select *into a from public.financial_authorizations where id=new.authorization_id;
 if new.account_id is distinct from(select budget_account_id from public.finance_authorization_policies where id=a.policy_id)then raise exception using errcode='22023',message='command_validation_failed';end if;
 if new.kind='reversal'then
 select *into original from public.budget_entries where id=new.reverses_entry_id;
 if original.kind not in('expense','revenue')or original.account_id is distinct from new.account_id or original.authorization_id is distinct from new.authorization_id or new.expense_delta_centavos is distinct from -original.expense_delta_centavos or new.revenue_delta_centavos is distinct from -original.revenue_delta_centavos then raise exception using errcode='22023',message='command_validation_failed';end if;
 end if;return new;end$$;
create trigger budget_entry_guard before insert on public.budget_entries for each row execute function app_private.budget_entry_guard();
create function app_private.budget_balance_guard()returns trigger language plpgsql security definer set search_path='' as $$begin
 if app_private.budget_available(new.account_id)<0 or exists(select 1 from public.budget_entries where authorization_id=new.authorization_id group by authorization_id having sum(reserved_delta_centavos)<0)then raise exception using errcode='55000',message='command_dependency_blocked';end if;return new;end$$;
create trigger budget_balance_guard after insert on public.budget_entries for each row execute function app_private.budget_balance_guard();
revoke all on function app_private.budget_entry_guard(),app_private.budget_balance_guard()from public,anon,authenticated,service_role;
