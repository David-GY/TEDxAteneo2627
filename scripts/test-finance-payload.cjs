const assert = require('node:assert/strict'), fs = require('node:fs/promises'), { randomUUID, createHash } = require('node:crypto')
;(async () => {
 const p = await require('./deliverable-authoring-db.cjs').createAuthoringDatabase()
 try {
  assert.equal((await p.db.query("select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='submit_finance_request'")).rows[0].n, 1, 'P24 atomic typed finance submission must exist')
  const f = await require('./workflow-fixtures.cjs').setupWorkflows(p)
  p.filePreview = await require('./files-preview.cjs').createFilePreview(p.db, p.ids)
  const fin = (await p.db.query("select * from public.request_types where term_id=$1 and stable_key='fin'", [p.ids.term])).rows[0]
  const schema = (await p.db.query('select schema_json from public.form_versions where id=$1', [fin.form_version_id])).rows[0].schema_json
  schema.fields.push({ key: 'evidence', section: 'need', label: 'Final evidence', help: 'Synthetic exact evidence', type: 'file', classification: 'confidential', required: false, maxItems: 5 })
  const fv = (await p.db.query("insert into public.form_versions(request_type_id,version,state,restricted,schema_json,published_at)values($1,2,'published',true,$2,statement_timestamp())returning id", [fin.id, schema])).rows[0].id
  await p.db.query('update public.request_types set form_version_id=$1 where id=$2', [fv, fin.id])
  const payload = (kind = 'cost') => ({ schemaVersion: 1, currency: 'PHP', kind, purpose: 'PRIVATE finance plan purpose', fundSource: 'PRIVATE synthetic fund', beneficiaryMemberId: p.ids.viewer, relatedDeliverableId: null, plannedOn: '2027-04-10', termsRisks: 'PRIVATE terms; no authority or payment implied', lines: [{ description: 'PRIVATE first item', quantity: '1', unitAmountCentavos: '10', totalCentavos: '10' }, { description: 'PRIVATE second item', quantity: '1', unitAmountCentavos: '20', totalCentavos: '20' }], requestedTotalCentavos: '30', ...(['sales', 'fundraising'].includes(kind) ? { pricing: { unitPriceCentavos: '5', forecastQuantity: '2', forecastRevenueCentavos: '10' } } : {}) })
  const create = () => f.draft(fin.id)
  const submit = (draft, finance = payload(), key = randomUUID(), revision = false, values = { purpose: 'Restricted finance review envelope' }, subject = p.ids.viewer) => f.call(subject, 'submit_finance_request', [draft.requestId, values, '2027-04-10', 'Fictional finance request', finance, draft.version, key, revision])
  const read = (id, revision = null, subject = p.ids.viewer) => f.call(subject, 'read_finance_revision', [p.ids.term, id, revision])
  const cents = await create(), key = randomUUID(), result = await submit(cents, payload(), key), view = await read(cents.requestId)
  assert.equal(view.requestedTotalCentavos, '30'); assert.equal(view.lines.length, 2); assert.equal(view.lines[0].totalCentavos, '10')
  assert.deepEqual(await submit(cents, payload(), key), result)
  await assert.rejects(() => submit(cents, { ...payload(), purpose: 'Changed' }, key), e => e.code === '22023')
  assert.equal((await p.db.query('select count(*)::int n from public.finance_revisions where request_id=$1', [cents.requestId])).rows[0].n, 1)
  const invalid = [
   { ...payload(), requestedTotalCentavos: '31' }, { ...payload(), currency: 'USD' }, { ...payload(), requestedTotalCentavos: '-1' }, { ...payload(), requestedTotalCentavos: '9007199254740992' },
   { ...payload(), unauthorizedField: 'must reject' }, { ...payload(), purpose: '' }, { ...payload(), fundSource: null }, { ...payload(), termsRisks: 42 },
   { ...payload(), lines: [] }, { ...payload(), lines: [{ ...payload().lines[0], quantity: '0' }] }, { ...payload(), lines: [{ ...payload().lines[0], quantity: '1.0001' }] },
   { ...payload(), lines: [{ ...payload().lines[0], unitAmountCentavos: 10 }] }, { ...payload(), lines: [{ ...payload().lines[0], unitAmountCentavos: '1e1' }] },
   { ...payload(), lines: [{ ...payload().lines[0], totalCentavos: '11' }] }, { ...payload(), plannedOn: '2027-02-30' },
   { ...payload('sales'), pricing: { ...payload('sales').pricing, forecastRevenueCentavos: '11' } },
   { ...payload('sales'), pricing: { ...payload('sales').pricing, bankAccount: 'must reject' } },
   { ...payload(), pricing: null }, { ...payload(), lines: [{ ...payload().lines[0], payment: 'must reject' }] },
  ]
  for (const [index, bad] of invalid.entries()) {
   const draft = await create()
   await assert.rejects(() => submit(draft, bad), e => e.code === '22023', `P24_A1 invalid payload ${index}`)
   assert.equal((await p.db.query('select current_revision from public.requests where work_item_id=$1', [draft.requestId])).rows[0].current_revision, 0)
  }
  const half = { ...payload(), requestedTotalCentavos: '1', lines: [{ description: 'Half cent', quantity: '0.005', unitAmountCentavos: '100', totalCentavos: '1' }] }
  const rounded = await create(); await submit(rounded, half); assert.equal((await read(rounded.requestId)).requestedTotalCentavos, '1')
  const max = { ...half, requestedTotalCentavos: '9007199254740991', lines: [{ ...half.lines[0], quantity: '1', unitAmountCentavos: '9007199254740991', totalCentavos: '9007199254740991' }] }
  const maximum = await create(); await submit(maximum, max); assert.equal((await read(maximum.requestId)).requestedTotalCentavos, '9007199254740991')
  const overflow = await create(); await assert.rejects(() => submit(overflow, { ...max, lines: [...max.lines, ...half.lines] }), e => e.code === '22023')
  const stale = await create(); await assert.rejects(() => submit({ ...stale, version: stale.version + 1 }), e => e.code === '40001')
  const general = await f.draft(f.type.id); await assert.rejects(() => submit(general), e => e.code === '55000')
  for (const kind of ['budget', 'expense', 'reimbursement']) { const draft = await create(); await submit(draft, payload(kind)); assert.equal((await read(draft.requestId)).kind, kind) }
  const inactiveBeneficiary = await create()
  await p.db.query("update public.term_memberships set ends_at=statement_timestamp()-interval'1 hour' where member_id=$1", [p.ids.outsider])
  await assert.rejects(() => submit(inactiveBeneficiary, { ...payload(), beneficiaryMemberId: p.ids.outsider }), e => e.code === '42501')
  await p.db.query("update public.term_memberships set ends_at=statement_timestamp()+interval'30 days' where member_id=$1", [p.ids.outsider])
  await assert.rejects(() => submit(inactiveBeneficiary, { ...payload(), beneficiaryMemberId: randomUUID() }), e => e.code === '42501')
  await assert.rejects(() => submit(inactiveBeneficiary, { ...payload(), relatedDeliverableId: p.ids.hidden }), e => e.code === '42501')
  console.log('ok 1 - P24_A1 exact 10+20=30, half-up quantities, max string serialization, inconsistent/negative/overflow/unknown values rejected; exact retries and stale versions')

  const evidence = await create(), bytes = require('./file-fixtures.cjs').png(), sha = createHash('sha256').update(bytes).digest('hex'), assets = []
  for (const name of ['chosen.png', 'not-selected.png']) {
   const a = await f.call(p.ids.viewer, 'reserve_upload', [evidence.requestId, name, 'image/png', bytes.length, sha, null, null, evidence.version, randomUUID()])
   await p.db.transaction(async tx => { await tx.exec('set local role service_role'); await tx.query('select public.seal_upload($1,$2,$3,$4)', [a.assetId, sha, bytes.length, 'image/png']) })
   p.filePreview.bytes.set(a.path, new Uint8Array(bytes)); assets.push(a.assetId)
  }
  await f.call(p.ids.viewer, 'finalize_upload', [evidence.requestId, assets, evidence.version, randomUUID()])
  await submit(evidence, payload('sales'), randomUUID(), false, { purpose: 'Restricted finance envelope', evidence: [assets[0]] })
  const ev = await read(evidence.requestId); assert.deepEqual(ev.files.map(a => a.id), [assets[0]])
  assert.equal(ev.manifestHash, (await p.db.query('select manifest_hash from public.request_revisions where id=$1', [ev.requestRevisionId])).rows[0].manifest_hash)
  const wrong = await create(); await assert.rejects(() => submit(wrong, payload(), randomUUID(), false, { purpose: 'Foreign evidence', evidence: [assets[0]] }), e => ['42501', '22023'].includes(e.code))
  for (const subject of [p.ids.owner, p.ids.outsider]) {
   assert.equal(await read(evidence.requestId, null, subject), null)
   assert.equal(await f.call(subject, 'read_request', [p.ids.term, evidence.requestId, null, 1]), null)
   assert.equal((await f.call(subject, 'list_my_requests', [p.ids.term, 1])).total, 0)
   const queue = await f.call(subject, 'list_review_inbox', [p.ids.term, 'all', 1]); assert(!JSON.stringify(queue).includes('PRIVATE'))
   const workflow = await f.read(evidence.requestId, subject); if (workflow) assert.equal(workflow.package, null)
   await assert.rejects(() => f.call(subject, 'authorize_asset_download', [evidence.requestId, assets[0], randomUUID()]), e => e.code === '42501')
   await assert.rejects(() => submit(evidence, payload(), randomUUID(), false, { purpose: 'Unauthorized' }, subject), e => e.code === '42501')
  }
  const download = await p.filePreview.handler(new Request('http://127.0.0.1/__files', { method: 'POST', headers: { authorization: 'Bearer local-synthetic', 'content-type': 'application/json' }, body: JSON.stringify({ action: 'download', workId: evidence.requestId, assetId: assets[0], key: randomUUID() }) }))
  assert.equal(download.status, 200); assert.deepEqual(Buffer.from(await download.arrayBuffer()), bytes)
  await p.db.query("update public.term_memberships set status='revoked' where id=$1", [p.ids.viewerMembership])
  await assert.rejects(() => read(evidence.requestId), e => e.code === '42501')
  await assert.rejects(() => submit(cents, payload(), key), e => e.code === '42501')
  await p.db.query("update public.term_memberships set status='active' where id=$1", [p.ids.viewerMembership])
  console.log('ok 2 - P24_A2 scoped API/list/count/queue/package/file denial for unrelated head/member; selected immutable manifest and PNG bytes; revocation blocks reads/retries')

  assert.equal(ev.pricing.forecastRevenueCentavos, '10'); assert.equal(ev.pricing.forecastMarginCentavos, '-20')
  assert.equal((await f.read(evidence.requestId, p.ids.viewer)).workflowState, 'paused')
  assert.equal((await p.db.query("select count(*)::int n from public.approval_decisions where request_id=$1", [evidence.requestId])).rows[0].n, 0)
  assert.equal((await p.db.query("select count(*)::int n from pg_tables where schemaname='public' and tablename in('actual_finance_records','financial_authorizations','budget_entries','payments')")).rows[0].n, 0)
  const edit = await f.call(p.ids.viewer, 'begin_request_revision', [evidence.requestId, (await f.read(evidence.requestId, p.ids.viewer)).version, randomUUID()])
  await assert.rejects(() => f.call(p.ids.viewer, 'revise_request', [evidence.requestId, { purpose: 'Attempt untyped bypass' }, null, null, 'Untyped revision', edit.version, randomUUID()]), e => e.code === '55000')
  const next = await submit(edit, { ...payload('sales'), purpose: 'PRIVATE changed financial plan' }, randomUUID(), true)
  const old = await read(evidence.requestId, 1), current = await read(evidence.requestId)
  assert.equal(next.revision, 2); assert.equal(old.payloadHash, ev.payloadHash); assert.equal(old.purpose, payload().purpose); assert.notEqual(current.payloadHash, old.payloadHash)
  assert.equal(current.files.length, 0); assert.equal(old.files.length, 1)
  const noSales = await create(); await submit(noSales, { ...payload('sales'), pricing: { unitPriceCentavos: '5', forecastQuantity: '0', forecastRevenueCentavos: '0' } }); assert.equal((await read(noSales.requestId)).pricing.forecastRevenueCentavos, '0')
  const zero = await create(); await submit(zero, { ...payload('fundraising'), lines: [{ description: 'Zero cost plan', quantity: '1', unitAmountCentavos: '0', totalCentavos: '0' }], requestedTotalCentavos: '0' }); assert.equal((await read(zero.requestId)).requestedTotalCentavos, '0')
  const rollback = await create(), rollbackKey = randomUUID(), counter = (await p.db.query("select next_value from public.tracking_counters where namespace_key='FIN'")).rows[0].next_value
  await p.db.exec("create function pg_temp.fail_finance_outbox()returns trigger language plpgsql as $$begin if new.event_type='submit_finance_request'then raise exception 'P24 late failure';end if;return new;end$$;create trigger p24_fail before insert on public.outbox_jobs for each row execute function pg_temp.fail_finance_outbox()")
  await assert.rejects(() => submit(rollback, payload(), rollbackKey), e => e.code === 'P0001')
  for (const table of ['finance_cases', 'finance_revisions', 'request_revisions']) assert.equal((await p.db.query(`select count(*)::int n from public.${table} where request_id=$1`, [rollback.requestId])).rows[0].n, 0)
  assert.equal((await p.db.query("select count(*)::int n from public.idempotency_keys where client_key=$1", [rollbackKey])).rows[0].n, 0)
  assert.equal((await p.db.query("select next_value from public.tracking_counters where namespace_key='FIN'")).rows[0].next_value, counter)
  assert.equal((await p.db.query('select current_revision from public.requests where work_item_id=$1', [rollback.requestId])).rows[0].current_revision, 0)
  await p.db.exec('drop trigger p24_fail on public.outbox_jobs'); await submit(rollback, payload(), rollbackKey)
  const audit = (await p.db.query("select redacted_diff from public.audit_events where action in('submit_finance_request','read_finance_revision')")).rows
  assert(audit.length > 0); assert(!JSON.stringify(audit).includes('PRIVATE')); assert(!JSON.stringify(audit).includes('Centavos'))
  schema.fields.push({ key: 'requested_centavos', section: 'need', label: 'Requested PHP', help: 'Synthetic bounded adapter', type: 'currency', classification: 'confidential', storage: 'finance', required: true, min: 0, max: 100 })
  const adapterVersion = (await p.db.query("insert into public.form_versions(request_type_id,version,state,restricted,schema_json,published_at)values($1,3,'published',true,$2,statement_timestamp())returning id", [fin.id, schema])).rows[0].id
  await p.db.query('update public.request_types set form_version_id=$1 where id=$2', [adapterVersion, fin.id])
  const adapterDraft = await create(); await submit(adapterDraft, { ...payload(), beneficiaryMemberId: p.ids.owner, relatedDeliverableId: p.ids.item })
  assert.equal((await p.db.query('select requested_centavos from public.request_finance_values where request_id=$1', [adapterDraft.requestId])).rows[0].requested_centavos, 30)
  assert.equal(await read(adapterDraft.requestId, null, p.ids.owner), null, 'Beneficiary identity grants no typed access')
  const injected = await create(); await assert.rejects(() => submit(injected, payload(), randomUUID(), false, { purpose: 'Envelope', requested_centavos: 999 }), e => e.code === '22023')
  const boundedAdapter = await create(); await assert.rejects(() => submit(boundedAdapter, { ...half, requestedTotalCentavos: '101', lines: [{ description: 'Over configured form limit', quantity: '1', unitAmountCentavos: '101', totalCentavos: '101' }] }), e => e.code === '22023')
  const sql = await p.db.exec(await fs.readFile('supabase/tests/finance_payload.test.sql', 'utf8')); assert(sql.some(r => r.rows.some(x => x.tap?.includes('P24_A2/A3'))))
  console.log('ok 3 - P24_A3 forecasts/negative margin/zero cost are plans only; immutable history, exact revised binding, late outbox rollback and redacted audited reads')
  const files = [...p.migrations.map(m => 'supabase/migrations/' + m), 'scripts/test-finance-payload.cjs', 'supabase/tests/finance_payload.test.sql', 'src/features/finance/money.ts', 'src/features/finance/money.test.ts']
  await fs.writeFile('docs/build/evidence/P24-domain.json', JSON.stringify({ target: 'Isolated migrated PGlite; synthetic subjects and isolated PNG bytes. Not actual Supabase17/Auth/Storage/JWT/concurrent-session/institutional/privacy/human acceptance.', checks: ['P24_A1 exact arithmetic, invalid range/shape/totals and exact key/CAS', 'P24_A2 current requester scope; raw/API/list/count/package/file and revocation denial', 'P24_A3 immutable forecasts and bound request/evidence revisions; no approvals/actuals/payments; atomic late failure rollback'], hashes: Object.fromEntries(await Promise.all(files.map(async file => [file, createHash('sha256').update(await fs.readFile(file)).digest('hex')])) ) }, null, 2) + '\n')
 } finally { await p.db.close() }
})().catch(e => { console.error(e.code, e.message, e.where || '', e.stack); process.exitCode = 1 })
