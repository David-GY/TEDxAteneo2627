require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true,financeAuthorityPreview:true}).then(async p=>{
 const f=await require('./finance-ledger-fixtures.cjs').setupFinanceLedger(p),c=await f.create({},true);await f.activate(c);await f.decide(c);const receipt=await f.receipt(c);await f.actual(c,receipt,'expense','3000','Fictional receipt 001');const over=await f.receipt(c,'fictional-overrun');await f.actual(c,over,'expense','2500','Fictional overrun - new FIN review required');
 console.log('P27 FICTIONAL budget/actuals: '+p.url+'/finance/reviews/'+p.ids.term+'/'+c.id+'?synthetic=receiver');console.log('No real budget, institutional designation, payment or provider proof.');
}).catch(e=>{console.error(e.stack);process.exitCode=1})
