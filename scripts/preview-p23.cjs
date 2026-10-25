require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const f=await require('./workflow-fixtures.cjs').setupWorkflows(p);
 await f.create([f.stage('review','one','approved')]);
 const assigned=await f.create([f.stage('review','one','approved')],true);await f.activate(assigned);
 const revision=await f.create([f.stage('review','one','approved')]);await f.activate(revision);await f.act(revision,p.ids.owner,'request_revision');
 console.log('P23 synthetic service head inbox: '+p.url+'/reviews?synthetic=receiver');
 console.log('P23 exact assigned review: '+p.url+'/reviews/'+p.ids.term+'/'+assigned.id+'?synthetic=receiver');
}).catch(e=>{console.error(e.stack);process.exitCode=1})
