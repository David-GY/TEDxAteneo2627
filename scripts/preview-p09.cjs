const {createPreview}=require('./preview-p08.cjs')
createPreview({port:5176,authoring:true}).then(p=>console.log(`P09 LIVE synthetic PostgreSQL authoring preview: ${p.url}/deliverables`)).catch(e=>{console.error(e.message);process.exitCode=1})
