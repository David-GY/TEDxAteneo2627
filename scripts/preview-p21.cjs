require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const f=await require('./request-fixtures.cjs').setupRequests(p),draft=await f.create(f.source.id,'Fictional private request draft');
 const submitted=await f.submit(await f.create(f.source.id,'Fictional tracked request'),{purpose:'Fictional tracked publicity requirement; no institutional authority or real records.'});console.log('P21 submitted package: '+p.url+'/requests/'+p.ids.term+'/'+submitted.requestId);
 console.log('P21 private draft: '+p.url+'/requests/'+p.ids.term+'/'+draft.requestId);console.log('P21 My requests: '+p.url+'/requests/mine');console.log('P21 catalog: '+p.url+'/requests');
}).catch(e=>{console.error(e.message);process.exitCode=1})
