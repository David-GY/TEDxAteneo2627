import { importDriveKey,isDriveUuid,openDriveToken } from '../google-oauth/protocol.ts'
import { matchesTelegramSecret,type TelegramRpc } from './backend.ts'
import { telegramAlert,validateTelegramOrigin,type TelegramBot,type TelegramOutcome } from './telegram.ts'

type Delivery={id:string;lease:string;chatHash:string;sealedChat:string;mode:'immediate'|'digest'}

export async function telegramDispatch(rpc:TelegramRpc,bot:TelegramBot,config:{origin:string;secret:string;encryptionKey:string}) {
  validateTelegramOrigin(config.origin)
  if(!/^[A-Za-z0-9_-]{32,128}$/.test(config.secret))throw Error('Telegram dispatch configuration is invalid')
  const key=await importDriveKey(config.encryptionKey)
  return async(request:Request)=>{
    const reply=(value:unknown,status=200)=>Response.json(value,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}})
    if(request.method!=='POST')return reply({error:'method_not_allowed'},405)
    if(!matchesTelegramSecret(request.headers.get('x-telegram-dispatch-secret'),config.secret))
      return reply({error:'dispatch_denied'},403)
    if(request.body)return reply({error:'empty_body_required'},400)
    try {
      let checked=0,sent=0,deferred=0
      while(checked<6) {
        const job=await rpc('telegram_delivery',{p_action:'prepare'}) as Delivery|{skipped:true}|null
        if(job===null)break
        checked++
        if('skipped'in job){deferred++;continue}
        if(!isDriveUuid(job.id)||!isDriveUuid(job.lease)||!/^[a-f0-9]{64}$/.test(job.chatHash)
          ||typeof job.sealedChat!=='string'||!['immediate','digest'].includes(job.mode))throw Error()
        let result:TelegramOutcome
        try {
          const chat=await openDriveToken(key,'telegram-chat:'+job.chatHash,job.sealedChat)
          result=await bot.send(chat,telegramAlert(config.origin,job.mode))
        } catch {
          result={outcome:'uncertain'}
        }
        const recording=await rpc('telegram_delivery',{
          p_action:'finish',p_id:job.id,p_lease:job.lease,p_outcome:result.outcome,
          p_delay:result.outcome==='retry'?result.delay:null,
        }) as {recorded?:boolean}|null
        if(recording?.recorded!==true)throw Error()
        if(result.outcome==='sent')sent++
        else deferred++
      }
      return reply({checked,sent,deferred})
    } catch {
      return reply({error:'dispatch_unavailable'},503)
    }
  }
}
