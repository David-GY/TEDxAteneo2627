require('./preview-p08.cjs').createPreview({port:5178,tasks:true}).then(p=>console.log(`P13 LIVE synthetic overview: ${p.url}/`)).catch(e=>{console.error(e.message);process.exitCode=1})
