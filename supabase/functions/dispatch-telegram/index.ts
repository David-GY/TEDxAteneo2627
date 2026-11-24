import { telegramBot } from '../notification-adapters/telegram.ts'
import { telegramRpc } from '../notification-adapters/backend.ts'
import { telegramDispatch } from '../notification-adapters/telegram-dispatch.ts'

declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}
const url=Deno.env.get('SUPABASE_URL')
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const origin=Deno.env.get('APP_ORIGIN')
const token=Deno.env.get('TELEGRAM_BOT_TOKEN')
const secret=Deno.env.get('TELEGRAM_DISPATCH_SECRET')
const encryptionKey=Deno.env.get('TELEGRAM_BINDING_KEY')

if(Deno.env.get('TELEGRAM_DELIVERY_ENABLED')!=='true'||Deno.env.get('TELEGRAM_LINK_ENABLED')!=='true'
  ||!url||!service||!origin||!token||!secret||!encryptionKey) {
  Deno.serve(async()=>Response.json({error:'dispatch_unavailable'},{status:503,headers:{'Cache-Control':'no-store'}}))
} else {
  Deno.serve(await telegramDispatch(telegramRpc(url,service),telegramBot(token),{origin,secret,encryptionKey}))
}
