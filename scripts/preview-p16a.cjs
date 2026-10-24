require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 await require('./timeline-fixtures.cjs').setupTimeline(p)
 console.log('P16A LIVE fictional SQL timeline: '+p.url+'/working-together/timeline?date=2027-04-17&scale=month')
}).catch(e=>{console.error(e.message);process.exitCode=1})
