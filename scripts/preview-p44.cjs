async function createReportsPreview(port=5181){const p=await require('./preview-p43.cjs').createSearchPreview(port);try{const reports=await require('./reports-fixtures.cjs').setupReports(p);return{...p,reports}}catch(e){await p.close();throw e}}
module.exports={createReportsPreview}
if(require.main===module)createReportsPreview().then(p=>console.log('P44 synthetic scoped reports '+p.url+'/reports; telemetry unconfigured, no provider/human acceptance')).catch(e=>{console.error(e.code,e.message,e.where||'');process.exitCode=1})
