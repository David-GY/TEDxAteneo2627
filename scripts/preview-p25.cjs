require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const f=await require('./finance-intake-fixtures.cjs').setupFinanceIntake(p);
 console.log('P25 synthetic requester finance form: '+p.url+'/finance/'+p.ids.term+'/'+f.edit.requestId);
 console.log('P25 synthetic zero-cost plan: '+p.url+'/finance/'+p.ids.term+'/'+f.zero.requestId);
 console.log('P25 shared task: '+p.url+'/tasks/'+f.taskId+'?synthetic=associate');
}).catch(e=>{console.error(e.stack);process.exitCode=1})
