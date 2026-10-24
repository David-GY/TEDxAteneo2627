const {randomUUID}=require('node:crypto')
require('./preview-p08.cjs').createPreview({port:5178,authoring:true,tasks:true,synergies:true}).then(async p=>{
 const {asSubject}=require('./synergy-interface-fixtures.cjs')
 const receipt=await asSubject(p.db,p.ids.viewer,async tx=>(await tx.query('select public.propose_synergy($1,$2,$3,1,$4)as value',[p.synergyFixture.parent,p.ids.support,{output:'Fictional committee contribution',criteria:'Synthetic preview: agree the output, owner and deadline.',effort:'medium',dueOn:'2027-04-10',reason:'Clearly synthetic local preview request'},randomUUID()])).rows[0].value)
 console.log(`P15 LIVE synthetic SQL preview: ${p.url}/working-together/${receipt.agreementId}`)
 console.log(`Receiving-head simulation: ${p.url}/working-together/${receipt.agreementId}?synthetic=receiver`)
}).catch(e=>{console.error(e.message);process.exitCode=1})
