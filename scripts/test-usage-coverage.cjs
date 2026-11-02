const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),fs=require('node:fs/promises'),{asSubject}=require('./synergy-interface-fixtures.cjs')
;(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p),policy=randomUUID()
 await p.db.query("insert into app_private.reporting_policies(id,term_id,version,enabled,retention_days,approval_reference)values($1,$2,1,true,90,'Fictional local event coverage policy')",[policy,p.ids.term])
 await p.db.query("insert into app_private.reporting_subjects values($1,$2,'human'),($1,$3,'human')",[policy,p.ids.viewer,p.ids.owner])
 const call=(subject,name,args)=>asSubject(p.db,subject,tx=>tx.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')})v`,args).then(r=>r.rows[0].v))
 const events=async type=>(await p.db.query('select count(*)::int n from app_private.usage_events where event_type=$1',[type])).rows[0].n
 const progressKey=randomUUID(),args=[p.ids.term,'work',1,'done',0,progressKey]
 await call(p.ids.viewer,'set_onboarding_progress',args)
 assert.equal(await events('onboarding_item_completed'),1,'a real completed onboarding item is meaningful; a reserved event name alone is not integration')
 await call(p.ids.viewer,'set_onboarding_progress',args);assert.equal(await events('onboarding_item_completed'),1)
 await call(p.ids.viewer,'set_onboarding_progress',[p.ids.term,'work',1,'done',1,randomUUID()]);assert.equal(await events('onboarding_item_completed'),1,'re-marking an already-complete item is not new activity')
 await call(p.ids.viewer,'set_onboarding_progress',[p.ids.term,'tour',1,'skipped',0,randomUUID()]);assert.equal(await events('onboarding_item_completed'),1,'skipping a tour does not masquerade as completed work')
 await p.db.exec("create function pg_temp.fail_usage_capture()returns trigger language plpgsql as $$begin if new.event_type='onboarding_item_completed'then raise exception 'synthetic analytics write failure';end if;return new;end$$;create trigger fail_usage_capture before insert on app_private.usage_events for each row execute function pg_temp.fail_usage_capture()")
 const failedKey=randomUUID();await assert.rejects(()=>call(p.ids.viewer,'set_onboarding_progress',[p.ids.term,'contacts',1,'done',0,failedKey]),e=>e.code==='P0001')
 assert.equal((await p.db.query("select count(*)::int n from public.onboarding_progress where item='contacts'")).rows[0].n,0)
 assert.equal((await p.db.query('select count(*)::int n from public.idempotency_keys where client_key=$1',[failedKey])).rows[0].n,0,'late event failure rolls back progress and its receipt')
 await p.db.exec('drop trigger fail_usage_capture on app_private.usage_events')
 // Existing P35 publication path: draft/preview are not publish events; exact
 // retry is once, and a late outbox failure rolls back usage with publication.
 await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)values($1,$2,'66666666-6666-4666-8666-666666666661','55555555-5555-4555-8555-555555555559','unit',$3,statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$4)",[p.ids.org,p.ids.term,p.ids.support,p.ids.viewerMembership])
 const current=await call(p.ids.owner,'read_configuration',[f.type.id]),definition={schemaVersion:1,stages:[f.stage('review','one','approved')]}
 const draft=await call(p.ids.owner,'save_configuration_draft',[f.type.id,'workflow',definition,current.formVersionId,current.workflowVersionId,0,randomUUID(),null])
 const preview=await call(p.ids.owner,'preview_configuration',[draft.draftId,p.ids.viewerMembership]);assert.equal(await events('config_published'),0)
 const publish=[draft.draftId,draft.version,preview.reviewHash,'Fictional approved publication',randomUUID(),p.ids.viewerMembership]
 await p.db.exec("create function pg_temp.fail_usage_outbox()returns trigger language plpgsql as $$begin if new.event_type='publish_configuration'then raise exception 'synthetic late outbox failure';end if;return new;end$$;create trigger fail_usage_outbox before insert on public.outbox_jobs for each row execute function pg_temp.fail_usage_outbox()")
 await assert.rejects(()=>call(p.ids.owner,'publish_configuration',publish),e=>e.code==='P0001');assert.equal(await events('config_published'),0)
 await p.db.exec('drop trigger fail_usage_outbox on public.outbox_jobs')
 await call(p.ids.owner,'publish_configuration',publish);await call(p.ids.owner,'publish_configuration',publish);assert.equal(await events('config_published'),1)
 // P38 emits publish_process_change, not the unused name in the first P44 map.
 // Exercise the real audit trigger with a trusted synthetic source audit row.
 const audit=async action=>p.db.transaction(async tx=>{await tx.query("select set_config('request.jwt.claim.sub',$1,true)",[p.ids.owner]);await tx.query("insert into public.audit_events(organization_id,term_id,actor_id,actor_display_name,action,work_item_id,revision,request_id,redacted_diff)values($1,$2,auth.uid(),'Fictional actor',$3,$4,1,$5,$6)",[p.ids.org,p.ids.term,action,p.ids.item,randomUUID(),{fields:['process_configuration'],privateSentinel:'PRIVATE fixture text never copied to usage'}])})
 await audit('publish_process_change');assert.equal(await events('config_published'),2,'P38 actual audit action must emit a publication event')
 await audit('login');await audit('heartbeat');await audit('save_configuration_draft');assert.equal(await events('config_published'),2)
 assert(!(await p.db.query('select to_jsonb(e)::text v from app_private.usage_events e')).rows.some(row=>row.v.includes('PRIVATE')))
 const next=randomUUID();await p.db.query("insert into app_private.reporting_policies(id,term_id,version,enabled,retention_days,approval_reference)values($1,$2,2,true,90,'Fictional replacement window')",[next,p.ids.term]);await p.db.query("insert into app_private.reporting_subjects values($1,$2,'human')",[next,p.ids.viewer])
 await call(p.ids.viewer,'set_onboarding_progress',args);assert.equal(await events('onboarding_item_completed'),1,'old successful retries do not become new-window activity')
 await call(p.ids.viewer,'set_onboarding_progress',[p.ids.term,'contacts',1,'done',0,failedKey]);assert.equal(await events('onboarding_item_completed'),2,'a failed transaction remains retryable')
 const stored=(await p.db.query("select to_jsonb(e)v from app_private.usage_events e where event_type='onboarding_item_completed'limit 1")).rows[0].v
 assert.deepEqual(Object.keys(stored).sort(),['event_key','event_type','id','object_id','occurred_at','policy_id','subject_key','term_id','unit_id'].sort())
 await assert.rejects(()=>call(p.ids.viewer,'capture_term_usage',[p.ids.term,'work_viewed',randomUUID(),null,randomUUID()]),e=>['42883','42501'].includes(e.code))
 await fs.writeFile('docs/build/evidence/P44-usage-coverage.json',JSON.stringify({result:'PASS',target:'Synthetic transactions only; no live capture enabled',checks:['actual onboarding completion; skip/re-mark/exact retry excluded','event/progress/receipt atomic rollback and safe retry','actual P35 draft/preview/publication distinction and exact retry','late publication outbox failure rolls back event too','old retries do not enter a new policy window','minimal opaque objects; no progress/profile/private payload','no public arbitrary event RPC'],future:'archive_verified remains reserved until a verified archive command exists; never fabricate archive success'},null,2)+'\n');console.log('P44 existing action coverage and atomic telemetry PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message,e.where||'',e.stack);process.exitCode=1})
