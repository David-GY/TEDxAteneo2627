require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const{make,call,terms}=await require('./handoff-fixtures.cjs').setupHandoffs(p),h=await make();p.filePreview.bytes.set(h.path,new Uint8Array(h.bytes));await call(p.ids.viewer,'submit_handoff',[h.source,p.ids.owner,p.ids.support,h.manifestId,terms,h.nextTask,h.sourceVersion,h.nextVersion,require('node:crypto').randomUUID()]);
 const f=await require('./form-fixtures.cjs').setupForms(p);console.log('Synthetic P20 form: '+p.url+'/requests/services/'+f.typeId+'/preview?workId='+f.workId);console.log('Synthetic catalog: '+p.url+'/requests');
}).catch(e=>{console.error(e.message);process.exitCode=1})
