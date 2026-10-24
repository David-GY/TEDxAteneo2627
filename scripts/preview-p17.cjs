require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const{make,call,terms}=await require('./handoff-fixtures.cjs').setupHandoffs(p),f=await make()
 p.filePreview.bytes.set(f.path,new Uint8Array(f.bytes))
 const offered=await call(p.ids.viewer,'submit_handoff',[f.source,p.ids.owner,p.ids.support,f.manifestId,terms,f.nextTask,f.sourceVersion,f.nextVersion,require('node:crypto').randomUUID()])
 console.log(`P17 LIVE synthetic SQL/API preview (no P18 UI): ${p.url}/tasks/${f.nextTask}`)
 console.log(`Synthetic offered handoff ${offered.handoffId}; receiver ${p.ids.owner}; package bytes isolated in verifier, not provider proof`)
}).catch(e=>{console.error(e.message);process.exitCode=1})
