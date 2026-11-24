import { GoogleConsentError, schoolGoogleConsent } from '../google-oauth/consent.ts'
import { importDriveKey, isDriveUuid, schoolAddress } from '../google-oauth/protocol.ts'
import { calendarSyncHandler, type CalendarBackend } from './handler.ts'
import { googleCalendar } from './provider.ts'

declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}

const origin=Deno.env.get('APP_ORIGIN')
const url=Deno.env.get('SUPABASE_URL')
const anon=Deno.env.get('SUPABASE_ANON_KEY')
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const clientId=Deno.env.get('CALENDAR_OAUTH_CLIENT_ID')
const clientSecret=Deno.env.get('CALENDAR_OAUTH_CLIENT_SECRET')
const secret=Deno.env.get('CALENDAR_OAUTH_ENCRYPTION_KEY')

if(Deno.env.get('CALENDAR_SYNC_ENABLED')!=='true'||!origin||!url||!anon||!service||!clientId||!clientSecret||!secret) {
  Deno.serve(async()=>Response.json({error:{code:'unavailable'}},{status:503,headers:{'Cache-Control':'no-store'}}))
} else {
  const key=await importDriveKey(secret)
  const auth='Bearer '+service
  const consent=schoolGoogleConsent({origin,clientId,clientSecret},'/integrations/calendar/callback',[
    'https://www.googleapis.com/auth/calendar.events.owned',
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  ])
  const source=url.replace(/\/$/,'')
  async function get(path:string,authorization:string,apikey:string,body?:Record<string,unknown>) {
    const response=await fetch(source+path,{
      method:body?'POST':'GET',headers:{Authorization:authorization,apikey,'Content-Type':'application/json'},
      body:body?JSON.stringify(body):undefined,redirect:'error',signal:AbortSignal.timeout(8000),
    })
    const value=await response.json().catch(()=>null)
    if(!response.ok) {
      if(value?.code==='40001') throw new GoogleConsentError('stale')
      if(value?.code==='42501'||response.status===401||response.status===403) throw new GoogleConsentError('denied')
      throw new GoogleConsentError('unavailable')
    }
    return value
  }
  const backend:CalendarBackend={
    async authorize(jwt,term) {
      const current=await get('/auth/v1/user',jwt,anon!)
      if(!isDriveUuid(current?.id)||typeof current.email!=='string'||!schoolAddress.test(current.email)
        ||typeof current.email_confirmed_at!=='string') throw new GoogleConsentError('denied')
      const status=await get('/rest/v1/rpc/calendar_sync_status',jwt,anon!,{p_term_id:term,p_event_id:null})
      if(status?.canManage!==true) throw new GoogleConsentError('denied')
      return {id:current.id,email:current.email}
    },
    credential(term,subject,action,guard,sealed) {
      return get('/rest/v1/rpc/calendar_sync_credential',auth,service!,{
        p_term_id:term,p_subject_id:subject,p_action:action,p_guard:guard??null,p_sealed:sealed??null,
      })
    },
    job(term,action,fields) {
      return get('/rest/v1/rpc/calendar_sync_job',auth,service!,{
        p_term_id:term,p_action:action,p_generation:fields.generation,p_event_id:fields.work??null,
        p_lease:fields.lease??null,p_version:fields.version??null,p_outcome:fields.outcome??null,p_etag:fields.etag??null,
      })
    },
  }
  Deno.serve(calendarSyncHandler(backend,consent,googleCalendar(),key,origin))
}
