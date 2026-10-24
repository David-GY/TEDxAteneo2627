require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const f=await require('./dependency-fixtures.cjs').setupDependencies(p)
 console.log(`P16 LIVE synthetic SQL preview: ${p.url}/tasks/${f.successor}`)
 console.log(`Receiving-owner simulation: ${p.url}/tasks/${f.successor}?synthetic=receiver`)
}).catch(e=>{console.error(e.message);process.exitCode=1})
