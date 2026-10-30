const assert=require('node:assert/strict'),fs=require('node:fs/promises')
const{asSubject}=require('./synergy-interface-fixtures.cjs')
;(async()=>{const p=await require('./deliverables-db.cjs').createDeliverablesDatabase();try{
 const call=(query,filters={},cursor=null,actor=p.ids.viewer,term=p.ids.term)=>asSubject(p.db,actor,tx=>tx.query('select public.search_workspace($1,$2,$3,$4)value',[term,query,filters,cursor]).then(r=>r.rows[0].value))
 const title=(await p.db.query('select title from public.work_items where id=$1',[p.ids.item])).rows[0].title
 const reference=(await p.db.query('select reference_text from public.work_references where work_item_id=$1',[p.ids.item])).rows[0].reference_text
 const hits=await call(title);assert(hits.items.some(x=>x.id===p.ids.item));assert.equal((await call(reference)).items[0].id,p.ids.item);assert.equal((await call(p.ids.item)).items[0].id,p.ids.item)
 const empty=await call('never-found-fictional-title');for(const query of ['PRIVATE OUTPUT','PRIVATE BODY','987654321',p.ids.hidden])assert.deepEqual(await call(query),empty)
 assert.deepEqual(await call("' OR true --"),empty)
 for(const filter of [{kind:'finance'},{sql:'true'},{kind:'all',term:p.ids.term}])await assert.rejects(()=>call(title,filter),e=>e.code==='22023')
 await assert.rejects(()=>call(title,{}, {after:p.ids.item,scope:'forged'}),e=>e.code==='22023')
 await assert.rejects(()=>call(title,{},null,p.ids.viewer,'22222222-2222-4222-8222-222222222222'),e=>e.code==='42501')
 assert.equal((await call(title,{kind:'task'})).items.length,0)
 await p.db.transaction(async tx=>{for(let i=0;i<23;i++){const id=require('node:crypto').randomUUID();await tx.query(`insert into public.work_items(id,organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,lead_unit_id,status_id)select $1,organization_id,term_id,kind,'Fictional pagination row','restricted',owner_member_id,owner_display_name,lead_unit_id,status_id from public.work_items where id=$2`,[id,p.ids.item]);await tx.query(`insert into public.deliverables(work_item_id,organization_id,term_id,phase_key,outcome,body)values($1,$2,$3,'Fictional','Fictional','Not indexed')`,[id,p.ids.org,p.ids.term])}})
 const first=await call('pagination',{},null,p.ids.owner);assert.equal(first.items.length,20);assert.equal(first.total,23);assert(first.nextCursor)
 const second=await call('pagination',{},first.nextCursor,p.ids.owner);assert.equal(second.items.length,3);assert(second.items.every(x=>!first.items.some(y=>x.id===y.id)));assert.equal(second.nextCursor,null)
 await assert.rejects(()=>call('different query',{},first.nextCursor,p.ids.owner),e=>e.code==='22023')
 await fs.writeFile('docs/build/evidence/P43-search-server.json',JSON.stringify({result:'PASS',target:'Isolated PGlite/synthetic subjects; no real JWT/provider/concurrent proof',checks:['permitted title/ref/UUID same target','hidden title/body/ID indistinguishable from unknown','literal SQL-like query','closed filters/scope-bound cursor','other-term denial'],remaining:['request refs','guides and contacts','old unit aliases','trigram/typeahead','provider/human acceptance']},null,2)+'\n');console.log('P43 authorized operational search PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message);process.exitCode=1})
