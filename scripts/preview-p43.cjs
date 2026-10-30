require('./preview-p37.cjs').createWorkflowPreview(5180)
 .then(p=>console.log('P43 synthetic permitted-work search '+p.url+'/search?synthetic=associate; no provider or human acceptance'))
 .catch(e=>{console.error(e.code,e.message);process.exitCode=1})
