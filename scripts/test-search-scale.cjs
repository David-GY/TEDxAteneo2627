const assert=require('node:assert/strict'),fs=require('node:fs/promises'),{performance}=require('node:perf_hooks'),{asSubject}=require('./synergy-interface-fixtures.cjs')
;(async()=>{const p=await require('./deliverables-db.cjs').createDeliverablesDatabase();try{
 await p.db.transaction(async tx=>{
  await tx.query(`insert into public.work_items(organization_id,term_id,kind,title,classification,owner_member_id,owner_display_name,lead_unit_id,status_id)
   select w.organization_id,w.term_id,w.kind,case when n=3000 then 'Needlequartz spectacular signage'else 'Fictional checklist '||n end,'restricted',w.owner_member_id,w.owner_display_name,w.lead_unit_id,w.status_id from public.work_items w cross join generate_series(1,3000)n where w.id=$1`,[p.ids.item])
  await tx.query(`insert into public.deliverables(work_item_id,organization_id,term_id,phase_key,outcome,body)select w.id,w.organization_id,w.term_id,'Fictional','Fictional','Unindexed sensitive narrative'from public.work_items w where w.kind='deliverable'and not exists(select 1 from public.deliverables d where d.work_item_id=w.id)`)
 });await p.db.exec('vacuum analyze public.work_items');await p.db.exec('analyze public.work_references')
 const plans={};for(const[name,predicate]of[['fulltext',"to_tsvector('simple',app_private.search_text(title))@@plainto_tsquery('simple','needlequartz')"],['trigram',"'spectaculr' operator(extensions.<%) app_private.search_text(title)"]]){
  plans[name]=(await p.db.query(`explain(analyze,buffers,format json)select id from public.work_items where term_id=$1 and kind in('task','deliverable','request')and archived_at is null and ${predicate}`,[p.ids.term])).rows[0]['QUERY PLAN']
  assert(JSON.stringify(plans[name]).includes(name==='fulltext'?'search_work_titles_fts':'search_work_title_trigrams'),name+' candidate path must use its index with normal planner settings')
 }
 const timings={};for(const q of ['Needlequartz','spectaculr']){const start=performance.now();const result=await asSubject(p.db,p.ids.owner,tx=>tx.query('select public.search_workspace($1,$2)value',[p.ids.term,q]).then(r=>r.rows[0].value));timings[q]=Math.round(performance.now()-start);assert.equal(result.total,1);assert.equal(result.items[0].title,'Needlequartz spectacular signage')}
 await fs.writeFile('docs/build/evidence/P43-search-scale.json',JSON.stringify({result:'PASS',target:'3000 additional isolated PGlite synthetic records; not hosted concurrency/load acceptance',timingsMs:timings,plans},null,2)+'\n');console.log('P43 index paths and 3000-row RPC search PASS',timings)
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message,e.where||'');process.exitCode=1})
