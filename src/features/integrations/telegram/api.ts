import type { createSupabaseClient } from '../../../lib/supabase'

export type TelegramStatus={
  state:'linked'|'relink'|'unlinked'
  attempt:'start'|'confirm'|'expired'|null
  issue:'failed'|'uncertain'|'retry'|null
}
export type TelegramCommand={action:'start'|'confirm'|'cancel'|'unlink';hash:string|null;key:string}
export interface TelegramApi {
  status(term:string):Promise<TelegramStatus>
  run(term:string,command:TelegramCommand):Promise<'start'|'linked'|'cancelled'|'unlinked'>
  startUrl(code:string):string
}
export class TelegramUiError extends Error {
  constructor(readonly code:'permission'|'restart'|'retry'){super(code)}
}
export const telegramConfirmCode=/^[A-Za-z0-9_-]{24}$/

export const telegramStartCode=()=>btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))))
  .replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'')

export async function telegramProofHash(proof:string){
  const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(proof))
  return Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join('')
}

export function createTelegramApi(ready:ReturnType<typeof createSupabaseClient>,origin:string,bot:string):TelegramApi {
  async function client(){
    const supabase=await ready
    if(!supabase||location.origin!==origin)throw new TelegramUiError('retry')
    return supabase
  }
  return {
    async status(term){
      const {data,error}=await (await client()).rpc('telegram_status',{p_term_id:term})
      if(error)throw new TelegramUiError(error.code==='42501'?'permission':'retry')
      const value=data as TelegramStatus|null
      if(!value||!['linked','relink','unlinked'].includes(value.state)
        ||(value.attempt!==null&&!['start','confirm','expired'].includes(value.attempt))
        ||(value.issue!==null&&!['failed','uncertain','retry'].includes(value.issue)))throw new TelegramUiError('retry')
      return value
    },
    async run(term,command){
      const {data,error}=await (await client()).rpc('telegram_link',{
        p_term_id:term,p_action:command.action,p_hash:command.hash,p_request_id:command.key,
      })
      if(error)throw new TelegramUiError(error.code==='42501'?'permission':
        ['40001','22023','23505'].includes(error.code)?'restart':'retry')
      const state={confirm:'linked',unlink:'unlinked',cancel:'cancelled',start:'start'} as const
      if((data as {state?:string}|null)?.state!==state[command.action])throw new TelegramUiError('retry')
      return state[command.action]
    },
    startUrl(code){
      if(!/^[A-Za-z][A-Za-z0-9_]{1,28}bot$/i.test(bot)||!/^[A-Za-z0-9_-]{43}$/.test(code))throw new TelegramUiError('restart')
      const url=new URL('https://t.me/'+bot)
      url.searchParams.set('start',code)
      return url.href
    },
  }
}
