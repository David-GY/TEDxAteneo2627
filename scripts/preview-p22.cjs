require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p),c=await f.create(undefined,true);await f.activate(c);await f.act(c);
 console.log('P22 requester preview (one of two votes): '+p.url+'/requests/'+p.ids.term+'/'+c.id);
 console.log('P22 exact review API: '+JSON.stringify({termId:p.ids.term,requestId:c.id,stage:'review',quorum:'all',decisions:1,scope:'fictional isolated SQL; no provider or institutional authority'}));
}).catch(e=>{console.error(e.message);process.exitCode=1})
