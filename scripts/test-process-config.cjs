const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto'),fs=require('node:fs/promises')
;(async()=>{const p=await require('./deliverable-authoring-db.cjs').createAuthoringDatabase();try{
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p),access=await require('./access-preview-fixtures.cjs').seedAccess(p)
 await p.db.query("insert into public.unit_memberships(organization_id,term_id,term_membership_id,unit_id,deployment_type,effective_from,effective_to,approved_by)values($1,$2,$3,$4,'primary_contact',statement_timestamp()-interval'1 day',statement_timestamp()+interval'7 days',$3)",[p.ids.org,p.ids.term,p.ids.viewerMembership,p.ids.support])
 const call=(name,args,subject=p.ids.viewer)=>access.call(subject,name,args),read=()=>call('read_process_admin',[p.ids.term]),preview=(kind,values)=>call('preview_process_change',[p.ids.term,kind,values])
 const publish=async(kind,values,key=randomUUID(),review)=>{const r=review??await preview(kind,values);return call('publish_process_change',[p.ids.term,kind,values,r.version,r.fingerprint,'Fictional configuration verification',key])}
 const phase={id:randomUUID(),title:'Fictional preparation',startsOn:'2027-01-01',endsOn:'2027-04-16',active:true,order:1}
 assert.equal((await preview('phase',phase)).valid,true)
 const invalid=await preview('phase',{...phase,endsOn:'2026-12-31'});assert.equal(invalid.valid,false);await assert.rejects(()=>publish('phase',{...phase,endsOn:'2026-12-31'}),e=>e.code==='22023')
 const old=await preview('phase',phase),key=randomUUID(),first=await publish('phase',phase,key,old);assert.deepEqual(await publish('phase',phase,key,old),first)
 assert.equal((await call('read_process_summary',[p.ids.term])).phase.title,phase.title)
 await assert.rejects(()=>publish('phase',{...phase,title:'Stale'},randomUUID(),old),e=>e.code==='40001')
 const status=(await read()).statuses.find(s=>s.kind==='deliverable'),statusValues={id:status.id,label:'Approved',color:'#252624',order:2},before=(await p.db.query('select stable_key,semantic_category from public.status_definitions where id=$1',[status.id])).rows[0]
 await publish('status',statusValues);assert.deepEqual((await p.db.query('select stable_key,semantic_category from public.status_definitions where id=$1',[status.id])).rows[0],before)
 const readiness=await call('read_deliverable_readiness',[p.ids.item],p.ids.owner);assert.equal(typeof readiness.category,'string');assert.notEqual(readiness.category,'ready');assert.notEqual(readiness.category,'accepted')
 assert.equal((await preview('status',{...statusValues,semantic:'approved'})).valid,false)
 assert.equal((await preview('status',{...statusValues,color:'#ffffff'})).valid,false)
 await assert.rejects(()=>p.db.query("update public.status_definitions set semantic_category='approved'where id=$1",[status.id]),e=>e.code==='55000')
 const general=(await read()).services.find(s=>s.id===f.type.id),service={id:general.id,label:'Fictional renamed service',need:general.need,unitId:p.ids.support,primary:p.ids.viewerMembership,backup:f.reviewers[0],officialUrl:'https://example.invalid/process',leadDays:3,leadText:'Allow three calendar days',guestEligible:false,prefix:'SUP'}
 assert.equal((await preview('service',service)).valid,true);await publish('service',service)
 const created=await f.draft(f.type.id),submitted=await f.submit(created,{purpose:'Fictional immutable reference'});assert.equal(submitted.trackingId,'SUP-001')
 const pinned=(await p.db.query('select type_label,service_label,tracking_id,form_version_id,workflow_version_id from public.requests where work_item_id=$1',[created.requestId])).rows[0]
 await publish('service',{...service,label:'PRISM display name'});assert.deepEqual((await p.db.query('select type_label,service_label,tracking_id,form_version_id,workflow_version_id from public.requests where work_item_id=$1',[created.requestId])).rows[0],pinned)
 assert.equal((await preview('service',{...service,prefix:'NEW'})).valid,false)
 assert.equal(await call('resolve_request_reference',[p.ids.term,'SUP-001']),created.requestId);assert.equal(await call('resolve_request_reference',[p.ids.term,'SUP-001'],p.ids.outsider),null)
 assert.equal((await preview('service',{...service,backup:p.ids.outsider})).valid,false)
 const other=await f.cloneType('general','prefix_other');assert.equal((await preview('service',{...service,id:other,unitId:p.ids.lead,prefix:'SUP'})).valid,false)
 for(const prefix of ['FIN','MCD','TOOLONG','unsafe','A'])assert.equal((await preview('service',{...service,id:other,prefix})).valid,false)
 await assert.rejects(()=>call('read_process_admin',[p.ids.term],p.ids.outsider),e=>e.code==='42501')
 const snapshot=await read(),rollbackKey=randomUUID();await p.db.exec("create function pg_temp.fail_process()returns trigger language plpgsql as $$begin if new.event_type='publish_process_change'then raise exception 'Injected process failure';end if;return new;end$$;create trigger fail_process before insert on public.outbox_jobs for each row execute function pg_temp.fail_process()")
 await assert.rejects(()=>publish('status',{...statusValues,label:'Retained status'},rollbackKey),e=>e.code==='P0001');assert.deepEqual(await read(),snapshot);await p.db.exec('drop trigger fail_process on public.outbox_jobs');await publish('status',{...statusValues,label:'Retained status'},rollbackKey)
 await fs.writeFile('docs/build/evidence/P38-process-domain.json',JSON.stringify({target:'Isolated PGlite/synthetic subjects; not real provider/JWT/concurrency/institutional/human proof',checks:['P38_A1 immutable IDs/semantics/pinned labels/pairs/refs','P38_A2 phase dates/contact eligibility before publish','P38_A3 Approved label cannot mutate semantic category; versioned publication','P38_U2 fixed prefix reservation/collision/reserved/immutable lookup boundary','Exact replay/stale preview/atomic outbox failure/privacy denial'],schema:'local only'},null,2)+'\n');console.log('P38 process phase/status/service/prefix/retry/security SQL PASS')
 }finally{await p.db.close()}})().catch(e=>{console.error(e.code,e.message,e.where||'',e.stack);process.exitCode=1})
