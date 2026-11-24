import type { createSupabaseClient } from '../../../lib/supabase'

const consentTerm='tedx.calendar.consent-term'
export const calendarCallback='/integrations/calendar/callback'
const connections=['disconnected','connected','reconnect','revoking'] as const
const states=['queued','current','removed','retry','conflict','reconnect'] as const
type Outcome='verified'|'retry'|'conflict'|'reconnect'
export type SyncStatus={
  calendar:string;connection:typeof connections[number];state:typeof states[number]|null
  canManage:boolean;tombstone:boolean;lastVerifiedAt:string|null;pausedRemoval:boolean
}

export class CalendarSyncError extends Error {
  constructor(readonly code:string) {super(code)}
}

export interface CalendarSyncApi {
  status(term:string,event?:string):Promise<SyncStatus|null>
  queue(term:string,event:string,version:number):Promise<void>
  process(term:string,event?:string):Promise<Outcome|null>
  repairRemoval(term:string):Promise<Outcome|null>
  connect(term:string,popup:Window):Promise<void>
  finish(term:string,state:string,code:string|null,error:string|null):Promise<void>
  disconnect(term:string):Promise<void>
}

export function takeCalendarTerm() {
  const term=sessionStorage.getItem(consentTerm)
  sessionStorage.removeItem(consentTerm)
  return term
}

export function createCalendarSyncApi(ready:ReturnType<typeof createSupabaseClient>,origin:string):CalendarSyncApi {
  async function client() {
    const supabase=await ready
    if(!supabase||window.location.origin!==origin) throw new CalendarSyncError('unavailable')
    return supabase
  }
  async function send(term:string,action:string,fields:Record<string,unknown>={}) {
    const {data,error}=await (await client()).functions.invoke('calendar-sync',{body:{term,action,...fields}})
    if(error||!data||typeof data!=='object'){
      const response=error?.context instanceof Response?await error.context.json().catch(()=>null):null
      throw new CalendarSyncError(typeof response?.error?.code==='string'?response.error.code:'unavailable')
    }
    return data
  }
  async function process(term:string,action:string,fields:Record<string,unknown>={}) {
    const result=await send(term,action,fields)
    if(result.processed===false)return null
    if(result.processed!==true||!['verified','retry','conflict','reconnect'].includes(result.outcome))
      throw new CalendarSyncError('unavailable')
    return result.outcome as Outcome
  }
  return {
    async status(term,event) {
      const {data,error}=await (await client()).rpc('calendar_sync_status',{p_term_id:term,p_event_id:event??null})
      if(error) throw new CalendarSyncError('unavailable')
      if(data===null) return null
      const value=data as SyncStatus
      if(typeof value.calendar!=='string'||!value.calendar.trim()||!connections.includes(value.connection)
        ||(value.state!==null&&!states.includes(value.state))||typeof value.canManage!=='boolean'||typeof value.tombstone!=='boolean'
        ||typeof value.pausedRemoval!=='boolean'
        ||(value.lastVerifiedAt!==null&&(typeof value.lastVerifiedAt!=='string'||!Number.isFinite(Date.parse(value.lastVerifiedAt)))))
        throw new CalendarSyncError('unavailable')
      return value
    },
    async queue(term,event,version) {
      const {error}=await (await client()).rpc('calendar_sync_queue',{p_term_id:term,p_event_id:event,p_version:version})
      if(error) throw new CalendarSyncError(error.code==='40001'?'stale':error.code==='42501'?'denied':'unavailable')
    },
    process:(term,event)=>process(term,'process',event?{work:event}:{}),
    repairRemoval:term=>process(term,'repair_removal'),
    async connect(term,popup) {
      const {url}=await send(term,'start')
      if(typeof url!=='string'||popup.closed) throw new CalendarSyncError('unavailable')
      const target=new URL(url)
      if(target.origin!=='https://accounts.google.com'||target.pathname!=='/o/oauth2/v2/auth'
        ||target.searchParams.get('redirect_uri')!==origin+calendarCallback) throw new CalendarSyncError('denied')
      popup.sessionStorage.setItem(consentTerm,term)
      popup.opener=null
      popup.location.replace(target.href)
    },
    async finish(term,state,code,error) {
      if((await send(term,'finish',{state,code,error})).state!=='connected') throw new CalendarSyncError('unavailable')
    },
    async disconnect(term) {
      if((await send(term,'disconnect')).state!=='disconnected') throw new CalendarSyncError('unavailable')
    },
  }
}
