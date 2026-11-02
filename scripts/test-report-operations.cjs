// Synthetic local histories only; no provider, production policy or human acceptance.
const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),fs=require('node:fs/promises')
const {asSubject}=require('./synergy-interface-fixtures.cjs')
;(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p)
 const reports=await require('./reports-fixtures.cjs').setupReports(p)
 const policy=randomUUID();await p.db.query("insert into app_private.reporting_policies(id,term_id,version,enabled,retention_days,approval_reference)values($1,$2,1,true,90,'Fictional existing-action integration policy')",[policy,p.ids.term]);await p.db.query("insert into app_private.reporting_subjects select $1,member_id,case when member_id=any($2::uuid[])then 'human'else 'test'end from public.term_memberships where term_id=$3",[policy,[p.ids.viewer,p.ids.owner],p.ids.term])
 const head='66666666-6666-4666-8666-666666666661'
 await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,effective_from,effective_to,granted_by)values($1,$2,$3,$4,'term',statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$3)",[p.ids.org,p.ids.term,head,reports.role])
 await p.db.query("insert into public.role_assignments(organization_id,term_id,term_membership_id,role_id,scope_type,unit_id,effective_from,effective_to,granted_by)values($1,$2,$3,'55555555-5555-4555-8555-555555555559','unit',$4,statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$3)",[p.ids.org,p.ids.term,head,p.ids.support])
 const week=(await p.db.query('select app_private.report_week(statement_timestamp())::text week')).rows[0].week
 const read=(subject=p.ids.owner,unit=null,period=week)=>asSubject(p.db,subject,tx=>tx.query('select public.read_reports($1,$2,$3,$4)v',[p.ids.term,period,unit,{}]).then(r=>r.rows[0].v))
 const c=await f.create([f.stage('review','one','approved')])
 let r=await read();assert(r.operations,'queue/handoff/review metrics must exist, rather than leaving P44 unfinished')
 assert.equal(r.operations.queue.total,1);assert.equal(r.operations.queue.unassigned,1)
 assert.equal(r.operations.queue.items[0].reference,c.result.trackingId)
 assert.equal(r.operations.queue.items[0].title,'General support','unassigned managers receive the safe service title, never the private package title')
 assert.equal(r.operations.queue.items[0].href,`/reviews/${p.ids.term}/${c.id}`)
 assert.equal((await read(p.ids.viewer)).operations.queue.total,0,'a requester report grant must not confer independent review authority')
 const submittedSince=r.operations.queue.items[0].since
 await f.activate(c);r=await read();assert.equal(r.operations.queue.unassigned,0);assert.equal(r.operations.queue.assigned,1);assert.equal(r.operations.queue.items[0].since,submittedSince,'assignment must not reset current-revision queue age')
 await f.act(c);r=await read();assert.equal(r.operations.queue.total,0,'approved cases are not a pending-review queue')
 assert.equal(r.operations.reviews.samples,1);assert(r.operations.reviews.medianDays>=0)
 // Hand-authored immutable timestamp fixtures: two old generations in the same
 // submitted revision exercise exact pairing, even after the live stage is complete.
 const assigned=(await p.db.query('select *from public.approval_assignments where request_id=$1 order by assigned_at limit 1',[c.id])).rows[0]
 const base=(await p.db.query("select (app_private.report_week(statement_timestamp())-7)::timestamp at time zone'Asia/Manila' start")).rows[0].start
 for(const [generation,days]of [[80,2],[81,4]]){
  const aid=randomUUID();await p.db.query("insert into public.approval_assignments(id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at,assigned_at)select $1,organization_id,term_id,request_id,revision_id,instance_id,stage_key,$2,slot,reviewer_id,reviewer_name,authority_id,authority_version,expires_at,$3 from public.approval_assignments where id=$4",[aid,generation,base,assigned.id])
  await p.db.query("insert into public.approval_decisions(assignment_id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,action,reason,payload_hash,decided_at)select id,organization_id,term_id,request_id,revision_id,instance_id,stage_key,generation,'approve','PRIVATE decision narrative',repeat('a',64),$2::timestamptz+make_interval(days=>$3)from public.approval_assignments where id=$1",[aid,base,days])
 }
 const lastWeek=(await p.db.query('select (app_private.report_week(statement_timestamp())-7)::text week')).rows[0].week
 r=await read(undefined,null,lastWeek);assert.equal(r.operations.reviews.samples,2);assert.equal(r.operations.reviews.medianDays,3);assert.equal(r.operations.reviews.p90Days,3.8,'exact generation pairs; calendar-time percentile, not business SLA')
 const privateType=randomUUID();await p.db.query("insert into public.request_types(id,organization_id,term_id,stable_key,label,need,governed_kind,payload_classification,receiving_unit_id,primary_contact_id,backup_contact_id,authority_confirmed,process_note)select $1,organization_id,term_id,'private_general_reporting','Private general type',need,governed_kind,'restricted',receiving_unit_id,primary_contact_id,backup_contact_id,true,process_note from public.request_types where id=$2",[privateType,f.type.id])
 const privateForm=(await p.db.query("insert into public.form_versions(request_type_id,version,state,restricted,schema_json,published_at)select $1,1,'published',true,schema_json,statement_timestamp()from public.form_versions where id=$2 returning id",[privateType,f.type.form_version_id])).rows[0].id
 const privateWorkflow=(await p.db.query("insert into public.workflow_versions(request_type_id,version,state,definition_json,published_at)select $1,1,'published',definition_json,statement_timestamp()from public.workflow_versions where request_type_id=$2 order by version desc limit 1 returning id",[privateType,f.type.id])).rows[0].id
 await p.db.query('update public.request_types set form_version_id=$2,workflow_version_id=$3,live_enabled=true where id=$1',[privateType,privateForm,privateWorkflow])
 const privateDraft=await f.draft(privateType);await f.submit(privateDraft);assert.equal((await read()).operations.queue.total,0,'restricted payload cases excluded before counts')
 const pending=await f.create([f.stage('review','one','approved')]);await f.activate(pending)
 await p.db.query("update public.role_assignments set status='revoked'where id=$1",[f.roles[0]])
 assert.equal((await read()).operations.queue.total,0,'current source authority revoked: even metadata and aggregate disappear')
 assert.equal((await read()).operations.reviews.samples,0,'historical decision counts use current access too')
 await p.db.query("update public.role_assignments set status='active'where id=$1",[f.roles[0]])
 const safe=await read();assert(!JSON.stringify(safe.operations).includes('PRIVATE'));assert(!JSON.stringify(safe.operations).includes('reason'))
 await assert.rejects(()=>read(undefined,p.ids.privateUnit),e=>e.code==='42501')
 await assert.rejects(()=>read(p.ids.outsider),e=>e.code==='42501')
 // Workload snapshot and current deadlines retain exactly the work scope of P44.
 const work=await read(p.ids.viewer,p.ids.lead)
 assert.equal(work.workload.assignedOpen,1);assert.equal(work.workload.unassignedOpen,0)
 assert.equal(work.workload.dueInSevenDays,0);assert.equal(work.workload.undatedOpen,0)
 assert.equal(work.items.find(x=>x.id===reports.taskId).declaredEffort,null)
 const today=(await p.db.query("select (statement_timestamp()at time zone'Asia/Manila')::date::text as date_value")).rows[0].date_value
 const input={title:'Ordinary task due today',summary:'Fictional due-horizon source',body:'Fictional work instructions',classification:'ordinary',taskType:'ordinary',leadUnitId:p.ids.lead,assigneeId:null,assignedUnitId:null,collaborators:[],checklist:[],dueOn:today,dueAt:null,parentId:null,reason:'Fictional workload boundary'}
 await reports.call('create_task',[p.ids.term,input,randomUUID()]);const dated=await read(p.ids.viewer,p.ids.lead)
 assert.equal(dated.workload.totalOpen,2);assert.equal(dated.workload.assignedOpen,2);assert.equal(dated.workload.dueInSevenDays,1);assert.equal(dated.workload.dueSelectedWeek,1)
 p.synergyFixture=await require('./synergy-interface-fixtures.cjs').setupSynergyInterface(p.db,p.ids)
 const hf=await require('./handoff-fixtures.cjs').setupHandoffs(p),h=await hf.make({classification:'ordinary',title:'Finished event signage'})
 const key=randomUUID(),args=[h.source,p.ids.owner,p.ids.support,h.manifestId,hf.terms,null,h.sourceVersion,null,key]
 const submitted=await hf.call(p.ids.viewer,'submit_handoff',args);await hf.call(p.ids.viewer,'submit_handoff',args)
 r=await read(p.ids.viewer);assert.equal(r.operations.handoffs.pending,1);assert.equal(r.operations.handoffs.items[0].title,'Finished event signage')
 const acceptedKey=randomUUID();const acceptedArgs=[submitted.handoffId,1,1,'PRIVATE acceptance notes',acceptedKey]
 await hf.call(p.ids.owner,'accept_handoff',acceptedArgs);await hf.call(p.ids.owner,'accept_handoff',acceptedArgs)
 r=await read(p.ids.viewer);assert.equal(r.operations.handoffs.pending,0);assert.equal(r.operations.handoffs.responseSamples,1);assert.equal(r.operations.handoffs.acceptanceSamples,1,'idempotent acceptance does not inflate denominators')
 assert.equal(r.operations.handoffs.items[0].href,`/working-together/handoffs/${submitted.handoffId}?term=${p.ids.term}`)
 assert(!JSON.stringify(r.operations).includes('PRIVATE'))
 const privateHandoff=await hf.make();await hf.call(p.ids.viewer,'submit_handoff',[privateHandoff.source,p.ids.owner,p.ids.support,privateHandoff.manifestId,hf.terms,null,privateHandoff.sourceVersion,null,randomUUID()]);assert.equal((await read(p.ids.viewer)).operations.handoffs.total,1,'private handoff source excluded even for a participant')
 const captured=(await p.db.query('select distinct event_type from app_private.usage_events')).rows.map(row=>row.event_type)
 for(const kind of ['task_updated','request_submitted','decision_recorded','synergy_proposed','synergy_responded','handoff_submitted','handoff_accepted'])assert(captured.includes(kind),`actual existing ${kind} command must emit its safe event`)
 const evidence={result:'PASS',target:'Isolated synthetic SQL only',checks:['current report AND source/unit authority','requester cannot become reviewer','unassigned/assigned/approved queue boundaries','safe metadata titles and canonical term links','immutable revision/generation pairing and exact 3-day median/3.8-day p90','selected-week decision samples; current pending snapshot','restricted cases/handoff sources excluded before counts','source-role revocation removes current and historical aggregates','assigned/open/due workload and missing effort','participant-only handoffs; exact retries do not inflate samples','no bodies/reasons/files/names in metrics']}
 await fs.writeFile('docs/build/evidence/P44-operations-server.json',JSON.stringify(evidence,null,2)+'\n');console.log('P44 queue, turnaround, workload and isolation PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.stack,e.where||'');process.exitCode=1})
