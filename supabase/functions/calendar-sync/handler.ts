import { bounded } from '../files/validation.ts'
import { GoogleConsentError, type schoolGoogleConsent } from '../google-oauth/consent.ts'
import { driveHash, driveNonce, isDriveUuid, makeDriveAttempt, openDriveToken, sealDriveToken } from '../google-oauth/protocol.ts'
import { CalendarFault, type CalendarChange, type googleCalendar } from './provider.ts'

export type CredentialAction = 'read'|'start'|'claim'|'finish'|'cancel'|'disconnect'|'revoked'
type Connection = { calendarId?:string; state?:string; generation?:string; sealed?:string }
type Subject = { id:string; email:string }
type Job = CalendarChange & { work:string; lease:string; generation:string }
type JobAction = 'claim'|'claim_removal'|'verify'|'finish'
type Outcome = 'verified'|'retry'|'reconnect'|'conflict'
export interface CalendarBackend {
  authorize(jwt:string,term:string):Promise<Subject>
  credential(term:string,subject:string,action:CredentialAction,guard?:string,sealed?:string):Promise<Connection>
  job(term:string,action:JobAction,fields:{ generation:string; work?:string; lease?:string; version?:number; outcome?:Outcome; etag?:string|null }):Promise<Job|null>
}

const codes = {invalid:400,denied:403,reconnect:409,file_unavailable:404,unavailable:503,stale:409}
const consentErrors = ['access_denied','admin_policy_enforced','org_internal','invalid_scope']

export function calendarSyncHandler(backend:CalendarBackend,consent:ReturnType<typeof schoolGoogleConsent>,
  provider:ReturnType<typeof googleCalendar>,key:CryptoKey,origin:string) {
  return async (request:Request) => {
    const headers:Record<string,string> = {
      'Cache-Control':'no-store, private','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Vary':'Origin',
    }
    const reply=(value:unknown,status=200)=>Response.json(value,{status,headers})
    if(request.headers.get('origin')!==origin) return reply({error:{code:'denied'}},403)
    headers['Access-Control-Allow-Origin']=origin
    if(request.method==='OPTIONS') return new Response(null,{status:204,headers:{
      ...headers,'Access-Control-Allow-Methods':'POST','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type',
    }})
    if(request.method!=='POST') return reply({error:{code:'invalid'}},405)
    try {
      const jwt=request.headers.get('authorization')??''
      if(!/^Bearer [^\s]+$/.test(jwt)) throw new GoogleConsentError('denied')
      let input
      try {input=JSON.parse(new TextDecoder().decode(await bounded(request.body,8192)))}
      catch {throw new GoogleConsentError('invalid')}
      if(!input||!isDriveUuid(input.term)) throw new GoogleConsentError('invalid')
      const term=input.term
      const subject=await backend.authorize(jwt,term)
      const context='calendar:'+term+':'+subject.id
      const credential=(action:CredentialAction,guard?:string,sealed?:string)=>backend.credential(term,subject.id,action,guard,sealed)
      const reauthorize=async()=>{
        const current=await backend.authorize(jwt,term)
        if(current.id!==subject.id||current.email!==subject.email) throw new GoogleConsentError('denied')
      }
      switch(input.action) {
        case 'start': {
          const attempt=await makeDriveAttempt()
          const url=consent.authorize(subject.email,attempt)
          await credential('start',await driveHash(attempt.state),await sealDriveToken(key,'verifier:'+context,attempt.verifier))
          return reply({url})
        }
        case 'finish': {
          if(typeof input.state!=='string'||!driveNonce.test(input.state)) throw new GoogleConsentError('invalid')
          const hash=await driveHash(input.state)
          if(consentErrors.includes(input.error)) {
            await credential('cancel',hash)
            throw new GoogleConsentError('denied')
          }
          if(typeof input.code!=='string'||!/^[\x21-\x7e]{1,2048}$/.test(input.code)) throw new GoogleConsentError('invalid')
          const attempt=await credential('claim',hash)
          if(!attempt.sealed||!attempt.calendarId) throw new GoogleConsentError('stale')
          try {
            const verifier=await openDriveToken(key,'verifier:'+context,attempt.sealed)
            const refresh=await consent.exchange(input.code,verifier,subject.email)
            const token=await consent.refresh(refresh)
            await provider.target(token.access,attempt.calendarId)
            await reauthorize()
            await credential('finish',hash,await sealDriveToken(key,'refresh:'+context,refresh))
          } catch(error) {
            await credential('cancel',hash).catch(()=>undefined)
            throw error
          }
          return reply({state:'connected'})
        }
        case 'disconnect': {
          const connection=await credential('disconnect')
          if(connection.state==='disconnected') return reply({state:'disconnected'})
          if(connection.state!=='revoking'||!connection.sealed||!connection.generation) throw new GoogleConsentError('unavailable')
          await consent.revoke(await openDriveToken(key,'refresh:'+context,connection.sealed))
          await credential('revoked',connection.generation)
          return reply({state:'disconnected'})
        }
        case 'repair_removal':
        case 'process': {
          const repair=input.action==='repair_removal'
          if(input.work!==undefined&&!isDriveUuid(input.work)) throw new GoogleConsentError('invalid')
          if(repair&&input.work!==undefined) throw new GoogleConsentError('invalid')
          const {calendarId,generation,sealed,state}=await credential('read')
          if(state!=='connected'||!calendarId||!generation||!sealed) throw new GoogleConsentError('reconnect')
          const job=await backend.job(term,repair?'claim_removal':'claim',{generation,work:input.work})
          if(!job) return reply({processed:false})
          if(job.generation!==generation || !isDriveUuid(job.work) || !isDriveUuid(job.lease)
            || (input.work!==undefined && job.work!==input.work) || !Number.isSafeInteger(job.version)
            || (repair&&(!job.tombstone||job.event!==null))) throw new GoogleConsentError('stale')
          const guard={generation,work:job.work,lease:job.lease,version:job.version}
          let etag:string|null=null
          let outcome:Outcome='verified'
          try {
            const refresh=await openDriveToken(key,'refresh:'+context,sealed)
            const token=await consent.refresh(refresh)
            await provider.target(token.access,calendarId)
            const result=await provider.apply(token.access,calendarId,job,async()=>{
              try {
                await reauthorize()
                await backend.job(term,'verify',guard)
              } catch {
                throw new CalendarFault('retry')
              }
            })
            etag=result.etag
          } catch(error) {
            if(error instanceof CalendarFault) outcome=error.code
            else if(error instanceof GoogleConsentError&&['denied','reconnect'].includes(error.code)) outcome='reconnect'
            else outcome='retry'
          }
          await backend.job(term,'finish',{...guard,outcome,etag})
          return reply({processed:true,outcome})
        }
        default:throw new GoogleConsentError('invalid')
      }
    } catch(error) {
      const code=error instanceof GoogleConsentError?error.code:
        error instanceof CalendarFault&&error.code==='reconnect'?'reconnect':'unavailable'
      return reply({error:{code}},codes[code])
    }
  }
}
