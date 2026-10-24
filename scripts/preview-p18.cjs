require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const{make,call,terms}=await require('./handoff-fixtures.cjs').setupHandoffs(p),f=await make();p.filePreview.bytes.set(f.path,new Uint8Array(f.bytes))
 const offer=await call(p.ids.viewer,'submit_handoff',[f.source,p.ids.owner,p.ids.support,f.manifestId,terms,f.nextTask,f.sourceVersion,f.nextVersion,require('node:crypto').randomUUID()])
 console.log('P18 sender: '+p.url+'/working-together/handoffs?view=outgoing');console.log('P18 receiver: '+p.url+'/working-together/handoffs/'+offer.handoffId+'?synthetic=receiver');console.log('P18 source: '+p.url+'/tasks/'+f.source)
}).catch(e=>{console.error(e.message);process.exitCode=1})
