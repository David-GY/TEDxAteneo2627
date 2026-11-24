import { mapCommandError,type CommandResult } from '../../../lib/commands'
import type { createSupabaseClient } from '../../../lib/supabase'

export type EmailDigestStatus={
  activation:'ready'|'domain'|'sender'|'quota'
  enabled:boolean
  version:number
  health:'waiting'|'sending'|'accepted'|'delivered'|'bounced'|'failed'|'uncertain'|null
  bounced:boolean
}
export type EmailCommand={term:string;enable:boolean;version:number}
type PreferenceReceipt={version:number;enabled:boolean}
export interface EmailDigestApi {
  status(term:string):Promise<EmailDigestStatus>
  run(command:EmailCommand,key:string):Promise<CommandResult<PreferenceReceipt>>
}

export function createEmailDigestApi(ready:ReturnType<typeof createSupabaseClient>,origin:string):EmailDigestApi {
  async function client(){
    const supabase=await ready
    if(!supabase||window.location.origin!==origin)throw Error('Email preferences are unavailable')
    return supabase
  }
  return {
    async status(term) {
      const {data,error}=await (await client()).rpc('email_digest_status',{p_term_id:term})
      const value=data as EmailDigestStatus|null
      if(error||!value||!['ready','domain','sender','quota'].includes(value.activation)
        ||typeof value.enabled!=='boolean'||typeof value.bounced!=='boolean'||!Number.isSafeInteger(value.version)||value.version<0
        ||(value.health!==null&&!['waiting','sending','accepted','delivered','bounced','failed','uncertain'].includes(value.health)))
        throw Error('Email preferences are unavailable')
      return value
    },
    async run(command,key) {
      try {
        const {data,error}=await (await client()).rpc('set_email_digest',{
          p_term_id:command.term,p_enabled:command.enable,p_expected_version:command.version,p_request_id:key,
        })
        if(error)return {ok:false,error:mapCommandError(error)}
        const receipt=data as PreferenceReceipt|null
        if(!receipt||!Number.isSafeInteger(receipt.version)||receipt.version<=command.version||receipt.enabled!==command.enable)
          throw Error('Email preference could not be confirmed')
        return {ok:true,value:receipt}
      } catch {return {ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}
    },
  }
}
