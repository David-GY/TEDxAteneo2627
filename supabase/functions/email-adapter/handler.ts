import { isDriveUuid } from '../google-oauth/protocol.ts'
import { approvedRecipient,workspaceDigest,type MailProvider } from './provider.ts'

type Rpc=(procedure:string,args:Record<string,unknown>)=>Promise<unknown>
type Receipt={recorded?:boolean}

export function emailDispatch(rpc:Rpc,provider:MailProvider,config:{term:string;origin:string;secret:string}) {
  const message=workspaceDigest(config.origin)
  if(!isDriveUuid(config.term)||!/^[A-Za-z0-9_-]{32,128}$/.test(config.secret))throw Error('Invalid email dispatch configuration')
  return async(request:Request)=>{
    const reply=(value:unknown,status=200)=>Response.json(value,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}})
    if(request.method!=='POST')return reply({error:'method_not_allowed'},405)
    const actual=request.headers.get('x-email-dispatch-secret')??''
    let different=actual.length^config.secret.length
    for(let i=0;i<config.secret.length;i++)different|=(actual.charCodeAt(i)||0)^config.secret.charCodeAt(i)
    if(different)return reply({error:'dispatch_denied'},403)
    if(request.body)return reply({error:'empty_body_required'},400)
    const run=(action:string,fields:Record<string,unknown>={})=>rpc('email_digest_dispatch',{
      p_term_id:config.term,p_action:action,p_sender:provider.binding.sender,p_domain_id:provider.binding.domainId,...fields,
    })
    try {
      const gate=await run('gate') as {allowed?:boolean;reason?:string}|null
      if(gate?.allowed!==true)return reply({state:'blocked',reason:gate?.reason==='quota'?'quota':'sender'},503)
      const verified=await provider.verify()
      const domain=await run('domain',{p_outcome:verified?'verified':'failed'}) as Receipt|null
      if(domain?.recorded!==true)return reply({state:'blocked',reason:'sender'},503)
      if(!verified)return reply({state:'blocked',reason:'domain'},503)
      let accepted=0,delivered=0,deferred=0
      const check=await run('check') as {id?:unknown;providerId?:unknown;lease?:unknown}|null
      if(check){
        if(!isDriveUuid(check.id)||!isDriveUuid(check.providerId)||!isDriveUuid(check.lease))throw Error()
        const result=await provider.status(check.providerId)
        const confirmation=await run('reconcile',{p_id:check.id,p_lease:check.lease,p_outcome:result}) as Receipt|null
        if(confirmation?.recorded!==true)throw Error()
        if(result==='delivered')delivered++
      }
      for(let attempt=0;attempt<4;attempt++){
        const job=await run('prepare') as {id?:unknown;lease?:unknown;recipient?:unknown;skipped?:boolean;blocked?:string}|null
        if(!job)break
        if(job.blocked==='quota')return reply({state:'blocked',reason:'quota',accepted,delivered,deferred},503)
        if(job.blocked==='domain')return reply({state:'blocked',reason:'domain',accepted,delivered,deferred},503)
        if(job.blocked)return reply({state:'blocked',reason:'sender',accepted,delivered,deferred},503)
        if(job.skipped===true){deferred++;continue}
        if(!isDriveUuid(job.id)||!isDriveUuid(job.lease)||typeof job.recipient!=='string'||!approvedRecipient.test(job.recipient))throw Error()
        const result=await provider.send(job.recipient,job.id,message)
        const receipt=await run('finish',{
          p_id:job.id,p_lease:job.lease,p_outcome:result.outcome,
          p_provider_id:result.outcome==='accepted'?result.providerId:null,p_delay:result.outcome==='retry'?result.delay:null,
        }) as Receipt|null
        if(receipt?.recorded!==true)throw Error()
        if(result.outcome==='accepted')accepted++
        else if(result.outcome==='quota')return reply({state:'blocked',reason:'quota',accepted,delivered,deferred},503)
        else deferred++
      }
      return reply({state:'checked',accepted,delivered,deferred})
    } catch {return reply({error:'dispatch_unavailable'},503)}
  }
}
