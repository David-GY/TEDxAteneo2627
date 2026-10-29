const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const { randomUUID, createHash } = require('node:crypto')
const { asSubject } = require('./synergy-interface-fixtures.cjs')

;(async () => {
  const p = await require('./deliverable-authoring-db.cjs').createAuthoringDatabase()
  try {
    const f = await require('./workflow-fixtures.cjs').setupWorkflows(p)
    // Trusted synthetic provisioning, never a public permission-granting endpoint.
    await p.db.query(`insert into public.role_permissions(organization_id,term_id,role_id,capability,allowed_scope)
      values($1,$2,'55555555-5555-4555-8555-555555555559','committee.manage','unit') on conflict do nothing`, [p.ids.org, p.ids.term])
    await p.db.query(`insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)
      values($1,$2,'66666666-6666-4666-8666-666666666661','55555555-5555-4555-8555-555555555559','unit',$3,statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$4)`, [p.ids.org, p.ids.term, p.ids.support, p.ids.viewerMembership])
    const call = (subject, name, args) => asSubject(p.db, subject, tx => tx.query(`select public.${name}(${args.map((_, i) => '$' + (i + 1)).join(',')}) value`, args).then(r => r.rows[0].value))
    const read = (subject = p.ids.owner, type = f.type.id) => call(subject, 'read_configuration', [type])
    const initial = await read()
    assert((await call(p.ids.owner, 'read_configurations', [p.ids.term])).some(t => t.id === f.type.id))
    assert.deepEqual(await call(p.ids.viewer, 'read_configurations', [p.ids.term]), [])
    assert(initial.reviewers.some(r => r.id === f.reviewers[0] && r.name.length > 0))
    assert.equal(initial.typeId, f.type.id)
    const definition = { schemaVersion: 1, stages: [f.stage('review', 'one', 'approved', { label: 'Review service evidence' })] }
    const save = async (definition, kind = 'workflow', subject = p.ids.owner, version = 0, base, rollback = null, key = randomUUID(), type = f.type.id) => {
      const current = base ?? await read(subject, type)
      return call(subject, 'save_configuration_draft', [type, kind, definition, current.formVersionId, current.workflowVersionId, version, key, rollback])
    }
    const preview = (draft, subject = p.ids.owner) => call(subject, 'preview_configuration', [draft.draftId,p.ids.viewerMembership])
    const publish = async (draft, subject = p.ids.owner, review, key = randomUUID()) => call(subject, 'publish_configuration', [draft.draftId, draft.version, (review ?? await preview(draft, subject)).reviewHash, 'Reviewed fictional service change', key,p.ids.viewerMembership])
    // A missing implementation must fail here before any production migration is written.
    const draftKey = randomUUID(), draft = await save(definition, 'workflow', p.ids.owner, 0, initial, null, draftKey)
    assert.deepEqual(await save(definition, 'workflow', p.ids.owner, 0, initial, null, draftKey), draft)
    await assert.rejects(() => save({...definition, extra:'script'}, 'workflow', p.ids.owner, 0, initial, null, draftKey), e => e.code === '22023')
    const impact = await preview(draft)
    assert.equal(impact.valid, true)
    assert.equal(impact.definition.stages[0].label, 'Review service evidence')
    assert.equal(impact.existingCasesRemainPinned, true)
    const counts=await p.db.query('select (select count(*)from public.work_items)::int work,(select count(*)from public.audit_events)::int audit,(select count(*)from public.outbox_jobs)::int outbox')
    const cases=await call(p.ids.owner,'preview_workflow_cases',[draft.draftId,p.ids.viewerMembership,{purpose:'Fictional evaluated preview'},true])
    assert.equal(cases.cases[0].stages[0].blocker,null)
    assert.equal(cases.cases[2].stages[0].blocker,'reviewer_unavailable')
    assert.equal(cases.cases[3].stages[0].blocker,'requester_conflict')
    assert.equal(cases.cases[1].stages[0].revisionReturnsTo,'Review service evidence')
    assert(cases.cases[0].stages[0].people.length>0)
    const invalid=await call(p.ids.owner,'preview_workflow_cases',[draft.draftId,p.ids.viewerMembership,{},false]);assert.equal(invalid.formValid,false)
    assert.deepEqual(await p.db.query('select (select count(*)from public.work_items)::int work,(select count(*)from public.audit_events)::int audit,(select count(*)from public.outbox_jobs)::int outbox'),counts)
    await assert.rejects(()=>call(p.ids.viewer,'preview_workflow_cases',[draft.draftId,p.ids.viewerMembership,{},false]),e=>e.code==='42501')
    const selfConflict=await call(p.ids.owner,'preview_configuration',[draft.draftId,f.reviewers[0]])
    assert.equal(selfConflict.valid,false)
    assert.equal(selfConflict.problem,'requester_conflict')
    await assert.rejects(()=>call(p.ids.owner,'publish_configuration',[draft.draftId,draft.version,selfConflict.reviewHash,'Self-only reviewer must fail',randomUUID(),f.reviewers[0]]),e=>e.code==='22023')
    await assert.rejects(() => read(p.ids.viewer), e => e.code === '42501')
    await assert.rejects(() => save(definition, 'workflow', p.ids.viewer), e => e.code === '42501')
    await assert.rejects(() => call(p.ids.viewer, 'preview_configuration', [draft.draftId]), e => e.code === '42501')
    await assert.rejects(() => save(definition, 'roles'), e => e.code === '22023')
    console.log('ok 1 - current scoped head can save/preview only own bounded draft; ordinary member and unsupported kinds denied')

    const oldCase = await f.draft(f.type.id, 'Fictional pinned request')
    await f.submit(oldCase,{purpose:'Fictional pinned active request'})
    const oldPair = (await p.db.query('select form_version_id,workflow_version_id from public.requests where work_item_id=$1', [oldCase.requestId])).rows[0]
    const key = randomUUID(), result = await publish(draft, p.ids.owner, impact, key)
    assert.deepEqual(await publish(draft, p.ids.owner, impact, key), result)
    await assert.rejects(() => call(p.ids.owner, 'publish_configuration', [draft.draftId, draft.version, impact.reviewHash, 'Changed same key', key,p.ids.viewerMembership]), e => e.code === '22023')
    assert.notEqual(result.definitionVersionId, initial.workflowVersionId)
    assert.equal((await read()).history.length, 1)
    assert(!(await read()).pinnedCases.some(c=>c.id===oldCase.requestId)) // A service head is not automatically the requester or a private-case reader.
    assert.deepEqual((await p.db.query('select form_version_id,workflow_version_id from public.requests where work_item_id=$1', [oldCase.requestId])).rows[0], oldPair)
    const newCase = await f.draft(f.type.id, 'Fictional new version request')
    assert.equal((await p.db.query('select workflow_version_id from public.requests where work_item_id=$1', [newCase.requestId])).rows[0].workflow_version_id, result.definitionVersionId)
    console.log('ok 2 - P35_A3/P37_A3 foundation: exact publication retry is one effect; old case pins preserved, new draft takes new version')

    const beforeConflict = await read()
    const staleDraft = await save({ ...definition, stages: [{ ...definition.stages[0], label: 'Retained stale draft' }] }, 'workflow', p.ids.owner, draft.version, beforeConflict)
    const staleImpact = await preview(staleDraft)
    // A second eligible synthetic head has a separate private draft.
    await p.db.query(`update public.unit_memberships set deployment_type='head' where term_membership_id=$1 and unit_id=$2`, [p.ids.outsider, p.ids.support])
    await p.db.query(`insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)
      values($1,$2,$3,'55555555-5555-4555-8555-555555555559','unit',$4,statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$5)`, [p.ids.org, p.ids.term, p.ids.outsider, p.ids.support, p.ids.viewerMembership])
    assert.equal((await read(p.ids.outsider)).drafts.length, 0)
    await assert.rejects(() => preview(staleDraft, p.ids.outsider), e => e.code === '42501')
    const other = await save({ ...definition, stages: [{ ...definition.stages[0], label: 'Second head publication' }] }, 'workflow', p.ids.outsider)
    const otherResult = await publish(other, p.ids.outsider)
    await assert.rejects(() => publish(staleDraft, p.ids.owner, staleImpact), e => e.code === '40001')
    assert.equal((await read()).drafts[0].definition.stages[0].label, 'Retained stale draft')
    assert.equal((await read()).workflowVersionId, otherResult.definitionVersionId)
    await assert.rejects(() => save(definition, 'workflow', p.ids.owner, draft.version), e => e.code === '40001')
    const rebased = await save(staleImpact.definition, 'workflow', p.ids.owner, staleDraft.version)
    const rebasedImpact = await preview(rebased)
    await assert.rejects(() => publish(rebased, p.ids.owner, staleImpact), e => e.code === '40001')
    console.log('ok 3 - P35_A2: two head drafts do not overwrite publication; draft and preview versions reject stale edits and keep inputs')

    for (const bad of [
      { ...definition, stages: [{ ...definition.stages[0], reviewers: [randomUUID()] }] },
      { ...definition, stages: [{ ...definition.stages[0], review: 'all', reviewers: [f.reviewers[0], f.reviewers[0]] }] },
      { ...definition, stages: [{ ...definition.stages[0], entryFields: ['missing'] }] },
      { ...definition, stages: [{ ...definition.stages[0], condition: { op: 'javascript', value: 'run()' } }] },
      { ...definition, stages: [{ ...definition.stages[0], outcome: 'pending' }] },
      { ...definition, stages: [{ ...definition.stages[0], review: 'none', reviewers: [] }] },
    ]) {
      const d = await save(bad, 'workflow', p.ids.outsider, (await read(p.ids.outsider)).drafts[0].version)
      const pr = await preview(d, p.ids.outsider)
      assert.equal(pr.valid, false, JSON.stringify(bad))
      await assert.rejects(() => publish(d, p.ids.outsider, pr), e => e.code === '22023')
    }
    // Authority is checked again after a valid preview, before replay as well as a fresh effect.
    await p.db.query("update public.role_assignments set status='revoked'where id=$1", [f.roles[0]])
    await assert.rejects(() => publish(rebased, p.ids.owner, rebasedImpact), e => e.code === '22023')
    await p.db.query("update public.role_assignments set status='active'where id=$1", [f.roles[0]])
    for (const kind of ['fin','mcd']) {
      const financial = (await p.db.query('select *from public.request_types where term_id=$1 and stable_key=$2', [p.ids.term,kind])).rows[0]
      const protectedDef = (await p.db.query('select definition_json from public.workflow_versions where id=$1', [financial.workflow_version_id])).rows[0].definition_json
      const protectedDraft = await save(protectedDef, 'workflow', p.ids.owner, 0, null, null, randomUUID(), financial.id)
      assert.equal((await preview(protectedDraft)).valid, false)
      await assert.rejects(() => publish(protectedDraft), e => e.code === '22023')
    }
    console.log('ok 4 - P35_A1 foundation: unknown/ineligible reviewers, missing fields, scripts, nonterminal/automatic review and protected FIN mapping rejected')

    const form = structuredClone((await read()).formDefinition)
    form.fields[0].classification = 'confidential'
    const badForm = await save(form, 'form')
    assert.equal((await preview(badForm)).valid, false)
    await assert.rejects(() => publish(badForm), e => e.code === '22023')
    const safeForm = structuredClone((await read()).formDefinition)
    safeForm.fields[0].label = 'Describe the service needed'
    const fd = await save(safeForm, 'form', p.ids.owner, badForm.version)
    const fp = await publish(fd)
    assert.notEqual(fp.definitionVersionId, initial.formVersionId)
    assert.deepEqual((await p.db.query('select form_version_id,workflow_version_id from public.requests where work_item_id=$1', [oldCase.requestId])).rows[0], oldPair)
    // The form publication changed the reviewed pair: explicitly rebase the retained workflow draft.
    const rb = await save(impact.definition, 'workflow', p.ids.owner, rebased.version, null, result.definitionVersionId)
    const rbResult = await publish(rb)
    assert.notEqual(rbResult.definitionVersionId, result.definitionVersionId)
    const history = (await read()).history
    assert.equal(history.length, 4)
    assert.equal(history[0].rollbackVersionId, result.definitionVersionId)
    assert(history.some(h => h.definitionVersionId === otherResult.definitionVersionId))
    await assert.rejects(() => p.db.query('update public.configuration_publications set reason=$1', ['rewrite']), e => e.code === '55000')
    console.log('ok 5 - P35_A3 foundation: rollback appends a new immutable version, preserves intervening history and all pinned pairs; ordinary confidential form rejected')

    const finalDraft = await save(definition, 'workflow', p.ids.owner, rb.version)
    const finalPreview = await preview(finalDraft), rollbackKey = randomUUID(), before = await read()
    await p.db.exec("create function pg_temp.fail_config_outbox()returns trigger language plpgsql as $$begin if new.event_type='publish_configuration'then raise exception 'Injected config outbox failure';end if;return new;end$$;create trigger fail_config_outbox before insert on public.outbox_jobs for each row execute function pg_temp.fail_config_outbox()")
    await assert.rejects(() => publish(finalDraft, p.ids.owner, finalPreview, rollbackKey), e => e.code === 'P0001')
    assert.deepEqual(await read(), before)
    assert.equal((await p.db.query("select count(*)::int n from public.idempotency_keys where command='publish_configuration'and client_key=$1", [rollbackKey])).rows[0].n, 0)
    await p.db.exec('drop trigger fail_config_outbox on public.outbox_jobs')
    await publish(finalDraft, p.ids.owner, finalPreview, rollbackKey)
    await p.db.query("update public.role_assignments set status='revoked'where term_membership_id=$1 and role_id='55555555-5555-4555-8555-555555555559'and unit_id=$2",[f.reviewers[0],p.ids.support])
    await assert.rejects(()=>publish(finalDraft,p.ids.owner,finalPreview,rollbackKey),e=>e.code==='42501')
    await assert.rejects(()=>read(),e=>e.code==='42501')
    await p.db.query("update public.role_assignments set status='active'where term_membership_id=$1 and role_id='55555555-5555-4555-8555-555555555559'and unit_id=$2",[f.reviewers[0],p.ids.support])
    await p.db.query("update public.terms set state='frozen',frozen_at=statement_timestamp()where id=$1",[p.ids.term])
    assert.equal((await read()).typeId,f.type.id)
    await assert.rejects(()=>save(definition,'workflow',p.ids.owner,finalDraft.version),e=>e.code==='42501')
    await p.db.query("update public.terms set state='active',frozen_at=null where id=$1",[p.ids.term])
    const conditional=await save({...definition,stages:[{...definition.stages[0],requiredManifest:true,condition:{op:'eq',field:'purpose',value:'Exact fictional value'}}]},'workflow',p.ids.owner,finalDraft.version)
    const dry=(values,evidence)=>call(p.ids.owner,'preview_workflow_cases',[conditional.draftId,p.ids.viewerMembership,values,evidence])
    assert.equal((await dry({purpose:'Wrong value'},false)).cases[0].stages[0].blocker,'required_documents_missing')
    assert.equal((await dry({purpose:'Wrong value'},true)).cases[0].stages[0].blocker,'entry_condition_not_met')
    assert.equal((await dry({purpose:'Exact fictional value'},true)).cases[0].stages[0].blocker,null)
    let last=conditional
    for(let i=0;i<51;i++){last=await save(definition,'workflow',p.ids.owner,last.version);await publish(last)}
    const firstHistory=await call(p.ids.owner,'read_configuration_history',[f.type.id,null]);assert.equal(firstHistory.items.length,50);assert(firstHistory.nextBefore)
    const older=await call(p.ids.owner,'read_configuration_history',[f.type.id,firstHistory.nextBefore]);assert(older.items.length>0);assert(older.items.every(h=>!firstHistory.items.some(x=>x.id===h.id)));assert.equal(older.nextBefore,null)
    for (const table of ['configuration_drafts', 'configuration_publications', 'configuration_controls']) {
      await assert.rejects(() => asSubject(p.db, p.ids.owner, tx => tx.query('select *from public.' + table)), e => e.code === '42501')
    }
    const tap = await p.db.exec(await fs.readFile('supabase/tests/config_publish.test.sql', 'utf8'))
    assert(tap.some(r => r.rows.some(x => x.tap?.includes('configuration boundary'))))
    console.log('ok 6 - late failure rollback; exact retry; revoked publisher cannot replay/read; frozen history readable but writes closed; raw/private/anonymous boundaries closed')
    const files = ['scripts/test-config-publication.cjs', 'supabase/tests/config_publish.test.sql', ...p.migrations.map(m => 'supabase/migrations/' + m)]
    await fs.writeFile('docs/build/evidence/P37-publication-foundation.json', JSON.stringify({ target: 'Isolated PGlite and synthetic subjects; no actual Supabase/JWT/independent concurrency or human proof. Browser evidence is separate.', acceptance: { P35_A1: 'server invalid-reference/protected-policy/privacy checks PASS', P35_A2: 'sequential stale-editor checks PASS; independent provider concurrency UNVERIFIED', P35_A3: 'server rollback/history/pinned-pair checks PASS', P37_A1: 'scoped head server configuration PASS; UI evidence separate', P37_A2: 'FIN/MCD changes and requester-only example publication rejected PASS; runtime rechecks every real requester', P37_A3: 'server pinning/append-only rollback PASS; active/new execution evidence separate' }, hashes: Object.fromEntries(await Promise.all(files.map(async file => [file, createHash('sha256').update(await fs.readFile(file)).digest('hex')]))) }, null, 2) + '\n')
  } finally { await p.db.close() }
})().catch(e => { console.error(e.code, e.message, e.where || '', e.stack); process.exitCode = 1 })
