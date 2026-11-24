import { telegramBot } from '../notification-adapters/telegram.ts'
import { telegramRpc } from '../notification-adapters/backend.ts'
import { telegramWebhook } from './handler.ts'

declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}
const url=Deno.env.get('SUPABASE_URL')
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const token=Deno.env.get('TELEGRAM_BOT_TOKEN')
const secret=Deno.env.get('TELEGRAM_WEBHOOK_SECRET')
const encryptionKey=Deno.env.get('TELEGRAM_BINDING_KEY')

if(Deno.env.get('TELEGRAM_LINK_ENABLED')!=='true'||!url||!service||!token||!secret||!encryptionKey) {
  Deno.serve(async()=>Response.json({ok:false},{status:503,headers:{'Cache-Control':'no-store'}}))
} else {
  const rpc=telegramRpc(url,service)
  Deno.serve(await telegramWebhook({
    async stage(input) {
      return await rpc('telegram_stage',{
        p_action:'stage',p_start_hash:input.startHash,p_confirm_hash:input.confirmHash,
        p_chat_hash:input.chatHash,p_sealed_chat:input.sealedChat,
      })===true
    },
    async abandon(input) {
      await rpc('telegram_stage',{
        p_action:'abandon',p_start_hash:input.startHash,p_confirm_hash:input.confirmHash,p_chat_hash:input.chatHash,
      })
    },
    async block(chatHash,providerSeconds) {
      await rpc('telegram_stage',{p_action:'stop',p_chat_hash:chatHash,p_provider_seconds:providerSeconds})
    },
  },telegramBot(token),{secret,encryptionKey}))
}
