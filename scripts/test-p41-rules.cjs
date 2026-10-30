const assert=require('node:assert/strict'),fs=require('node:fs/promises'),{randomUUID}=require('node:crypto')
;(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./notification-fixtures.cjs').setupNotifications(p);await f.custodian()
 const rule={version:1,audience:'current_assignees',channel:'in_app',mode:'digest',beforeDays:2,dueDay:true,overdueEveryDays:1,hour:8,quietStart:20,quietEnd:8,template:'action_link'}
 const read=(actor=p.ids.viewer)=>f.call(actor,'read_presentation_configuration',[p.ids.term,'notification','term',p.ids.term,null])
 const save=(definition=rule,version=0,base=0,actor=p.ids.viewer,key=randomUUID())=>f.call(actor,'save_presentation_draft',[p.ids.term,'notification','term',p.ids.term,definition,base,version,key,null])
 await assert.rejects(()=>save(rule,0,0,p.ids.owner),e=>e.code==='42501')
 const key=randomUUID(),d=await save(rule,0,0,p.ids.viewer,key);assert.deepEqual(await save(rule,0,0,p.ids.viewer,key),d)
 for(const bad of [{...rule,recipients:[p.ids.owner]},{...rule,template:'{{amount}}'},{...rule,active:true},{...rule,channel:'messenger'},{...rule,beforeDays:100},{...rule,hour:24},{...rule,quietEnd:20},{...rule,dueDay:'true'}])await assert.rejects(()=>save(bad,d.version),e=>e.code==='22023')
 const review=await f.call(p.ids.viewer,'preview_presentation_configuration',[d.draftId]);assert.equal(review.valid,true)
 const pubKey=randomUUID(),publish=()=>f.call(p.ids.viewer,'publish_presentation_configuration',[d.draftId,d.version,review.reviewHash,'Fictional proposal, not activation',pubKey])
 const result=await publish();assert.deepEqual(await publish(),result);assert.equal((await read()).history.length,1)
 await assert.rejects(()=>read(p.ids.owner),e=>e.code==='42501')
 await assert.rejects(()=>save(rule,d.version,0),e=>e.code==='40001')
 const jobs=(await p.db.query(`select count(*)::int n from public.outbox_jobs where event_type='publish_presentation_configuration'`)).rows[0].n
 assert.equal(jobs,1)
 // Publication is a versioned proposal only: it never enters P30's recognized dispatch events.
 assert.equal((await p.db.query(`select count(*)::int n from public.notifications n join public.outbox_jobs j on j.id=n.job_id where j.event_type='publish_presentation_configuration'`)).rows[0].n,0)
 await fs.writeFile('docs/build/evidence/P41-rules-server.json',JSON.stringify({result:'PASS',target:'Isolated PGlite/synthetic custodian; no actual JWT/provider/independent races',checks:['term admin only','private draft','closed server fields/templates/channels/timing','no activation flag','exact draft/publication retry','stale base','immutable proposal history','no notification delivery from publication'],remaining:['rule administration save/review UI','authorized actual recipient preview','durable configurable scheduling/digest dispatch','external/provider/human gates']},null,2)+'\n');console.log('P41 server private rule proposal publication PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message);process.exitCode=1})
