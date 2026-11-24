import { emailDispatch } from './handler.ts'
import { approvedMail } from './provider.ts'

declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}
const url=Deno.env.get('SUPABASE_URL')
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const origin=Deno.env.get('APP_ORIGIN')
const term=Deno.env.get('EMAIL_TERM_ID')
const secret=Deno.env.get('EMAIL_DISPATCH_SECRET')
const sender=Deno.env.get('EMAIL_FROM_ADDRESS')
const domainId=Deno.env.get('EMAIL_PROVIDER_DOMAIN_ID')
const sendKey=Deno.env.get('EMAIL_PROVIDER_SEND_KEY')
const readKey=Deno.env.get('EMAIL_PROVIDER_READ_KEY')

function configuredHandler() {
  if(Deno.env.get('EMAIL_DIGEST_ENABLED')!=='true'||!url||!service||!origin||!term||!secret||!sender||!domainId||!sendKey||!readKey)
    return null
  const provider=approvedMail({sender,domainId,sendKey,readKey})
  return emailDispatch(async(name,body)=>{
    const response=await fetch(url.replace(/\/$/,'')+'/rest/v1/rpc/'+name,{
      method:'POST',headers:{apikey:service,authorization:'Bearer '+service,'content-type':'application/json'},
      body:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(5000),
    })
    if(!response.ok)throw Error('Email service unavailable')
    return response.json()
  },provider,{term,origin,secret})
}

const blocked=async()=>Response.json({state:'blocked',reason:'sender'},{status:503,headers:{'Cache-Control':'no-store'}})
let handler:ReturnType<typeof emailDispatch>|null=null
try {handler=configuredHandler()} catch { /* Malformed configuration is held closed. */ }
Deno.serve(handler??blocked)
