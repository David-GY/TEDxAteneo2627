const assert=require('node:assert/strict'),fs=require('node:fs/promises'),{randomUUID}=require('node:crypto')
;(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./notification-fixtures.cjs').setupNotifications(p);await f.custodian()
 const definition={version:1,title:'Fictional committee decision',body:'Read the decision. This is not a task acceptance or legal waiver.',requiredAck:true,pinned:true,expiresAt:'2027-04-18T00:00:00Z'}
 const save=(actor=p.ids.viewer,body=definition,version=0,base=0,key=randomUUID())=>f.call(actor,'save_presentation_draft',[p.ids.term,'bulletin','unit',p.ids.support,body,base,version,key,null])
 await assert.rejects(()=>save(),e=>e.code==='42501') // admin.configure alone is deliberately insufficient.
 await p.db.query(`insert into public.announcement_publishers(term_id,membership_id,target_kind,target_id,approved_by)values($1,$2,'unit',$3,'66666666-6666-4666-8666-666666666661')`,[p.ids.term,p.ids.viewerMembership,p.ids.support])
 const key=randomUUID(),d=await save(p.ids.viewer,definition,0,0,key);assert.deepEqual(await save(p.ids.viewer,definition,0,0,key),d)
 for(const bad of [{...definition,attachments:[p.ids.hidden]},{...definition,guests:[p.ids.owner]},{...definition,body:'<script>unsafe()</script>'},{...definition,expiresAt:'not a date'},{...definition,requiredAck:'true'}])await assert.rejects(()=>save(p.ids.viewer,bad,d.version),e=>e.code==='22023')
 await assert.rejects(()=>save(p.ids.owner),e=>e.code==='42501')
 const review=await f.call(p.ids.viewer,'preview_presentation_configuration',[d.draftId]),pubKey=randomUUID()
 const publish=()=>f.call(p.ids.viewer,'publish_presentation_configuration',[d.draftId,d.version,review.reviewHash,'Fictional publication',pubKey])
 const result=await publish();assert.deepEqual(await publish(),result)
 const asSubject=require('./synergy-interface-fixtures.cjs').asSubject
 await assert.rejects(()=>asSubject(p.db,p.ids.viewer,tx=>tx.query('select *from public.announcement_publishers')),e=>e.code==='42501')
 await assert.rejects(()=>f.call(p.ids.viewer,'save_presentation_draft',[p.ids.term,'bulletin','unit',p.ids.lead,definition,0,0,randomUUID(),null]),e=>e.code==='42501')
 await assert.rejects(()=>save(p.ids.viewer,definition,d.version,0),e=>e.code==='40001')
 await p.db.query(`update public.announcement_publishers set revoked_at=statement_timestamp()where membership_id=$1`,[p.ids.viewerMembership])
 await assert.rejects(publish,e=>e.code==='42501')
 await assert.rejects(()=>f.call(p.ids.owner,'read_presentation_configuration',[p.ids.term,'bulletin','unit',p.ids.support,null]),e=>e.code==='42501')
 await fs.writeFile('docs/build/evidence/P42-publication-server.json',JSON.stringify({result:'PASS',target:'Isolated PGlite/synthetic authority; not real provider/JWT/concurrency',checks:['admin configuration alone cannot publish','explicit trusted exact-target publisher mapping','private drafts/current scope','unsafe markup/attachments/guest fields rejected','exact retry/stale-base/revoked replay denial'],remaining:['member scoped reader/counts','material acknowledgments','explicit guest sharing','independent attachment visibility','publisher UI/overview/inbox','provider and human acceptance']},null,2)+'\n');console.log('P42 closed announcement publisher foundation PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message);process.exitCode=1})
