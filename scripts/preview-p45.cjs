async function createCsvPreview(port=5182){return require('./preview-p44.cjs').createReportsPreview(port)}
module.exports={createCsvPreview}
if(require.main===module)createCsvPreview().then(p=>console.log('P45 synthetic private task imports '+p.url+'/admin/imports?term='+p.ids.term+'; no real roster/provider/exports/delivery or human acceptance')).catch(e=>{console.error(e.code,e.message,e.where||'');process.exitCode=1})
