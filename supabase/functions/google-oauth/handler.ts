import { bounded } from '../files/validation.ts'
import { type createGoogleDrive, DriveError, type DriveErrorCode } from './google.ts'
import { driveHash, driveNonce, isDriveUuid, makeDriveAttempt, openDriveToken, sealDriveToken } from './protocol.ts'
import { isDriveSelection, type DriveSelection } from './selection.ts'
import { isRendition, type createDriveRendition } from '../drive-export/rendition.ts'
import { isDriveCopy, type createDriveCopy } from '../drive-export/copy.ts'

export type DriveSubject = { membership: string; subject: string; email: string }
export type StoreAction = 'start' | 'status' | 'claim' | 'finish' | 'cancel' | 'disconnect' | 'revoked' | 'picker' | 'expire'
type StoreState = 'disconnected' | 'awaiting_consent' | 'authorized' | 'revocation_pending'
export type StoreResult = { state: StoreState; sealed?: string; generation?: string }
export interface DriveBackend {
  authorize(jwt: string, term: string, work?: string): Promise<DriveSubject>
  store(scope: DriveSubject, action: StoreAction, guard?: string, sealed?: string): Promise<StoreResult>
  saveWorkingSource?(jwt: string, work: string, version: number, requestId: string, source: { url: string; name: string; owner: string | null }): Promise<void>
}

const statuses: Record<DriveErrorCode,number> = {invalid:400,denied:403,reconnect:409,file_unavailable:404,unavailable:503,stale:409}
const callbackErrors = new Set(['access_denied','admin_policy_enforced','org_internal','invalid_scope'])

export function driveOAuthHandler(
  backend: DriveBackend, google: Pick<ReturnType<typeof createGoogleDrive>,'authorize'|'exchange'|'revoke'>,
  key: CryptoKey, origin: string, selection?: DriveSelection, rendition?: ReturnType<typeof createDriveRendition>, copy?: ReturnType<typeof createDriveCopy>,
) {
  return async (request: Request): Promise<Response> => {
    const headers: Record<string,string> = {
      'Cache-Control':'no-store, private','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Vary':'Origin',
    }
    const reply = (value: unknown, status=200) => Response.json(value,{status,headers})
    if (request.headers.get('origin')!==origin) return reply({error:{code:'denied'}},403)
    headers['Access-Control-Allow-Origin']=origin
    if (request.method==='OPTIONS') return new Response(null,{status:204,headers:{
      ...headers,'Access-Control-Allow-Methods':'POST','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type',
    }})
    if (request.method!=='POST') return reply({error:{code:'invalid'}},405)
    try {
      const jwt=request.headers.get('authorization')??''
      if (!/^Bearer [^\s]+$/.test(jwt)) throw new DriveError('denied')
      let input
      try {
        input=JSON.parse(new TextDecoder().decode(await bounded(request.body,8192)))
      } catch {
        throw new DriveError('invalid')
      }
      if (!input || !isDriveUuid(input.term)) throw new DriveError('invalid')
      if (isRendition(input.action)) {
        if (!rendition) throw new DriveError('unavailable')
        return reply(await rendition(input.action,jwt,input.term,input))
      }
      if (isDriveCopy(input.action)) {
        if (!copy) throw new DriveError('unavailable')
        return reply(await copy(input.action,jwt,input.term,input))
      }
      if (isDriveSelection(input.action)) {
        if (!selection) throw new DriveError('unavailable')
        return reply(await selection(input.action,jwt,input.term,input))
      }
      const scope=await backend.authorize(jwt,input.term)
      const context=scope.membership+':'+scope.subject
      switch (input.action) {
        case 'status': {
          const {state}=await backend.store(scope,'status')
          return reply({state:state==='authorized'?'consent_saved':state})
        }
        case 'start': {
          const attempt=await makeDriveAttempt()
          const url=google.authorize(scope.email,attempt)
          await backend.store(scope,'start',await driveHash(attempt.state),await sealDriveToken(key,'verifier:'+context,attempt.verifier))
          return reply({url})
        }
        case 'finish': {
          if (typeof input.state!=='string' || !driveNonce.test(input.state)) throw new DriveError('invalid')
          const hash=await driveHash(input.state)
          if (typeof input.error==='string' && callbackErrors.has(input.error)) {
            await backend.store(scope,'cancel',hash)
            return reply({error:{code:'denied'}},403)
          }
          if (typeof input.code!=='string' || !/^[\x21-\x7e]{1,2048}$/.test(input.code)) throw new DriveError('invalid')
          const attempt=await backend.store(scope,'claim',hash)
          if (!attempt.sealed) throw new DriveError('stale')
          const verifier=await openDriveToken(key,'verifier:'+context,attempt.sealed)
          let refresh
          try {
            refresh=await google.exchange(input.code,verifier,scope.email)
          } catch (error) {
            // An exchange may have consumed the code. A fresh explicit consent attempt can start.
            await backend.store(scope,'cancel',hash).catch(()=>undefined)
            throw error
          }
          const current=await backend.authorize(jwt,input.term)
          if (current.membership!==scope.membership || current.subject!==scope.subject || current.email!==scope.email)
            throw new DriveError('denied')
          const sealed=await sealDriveToken(key,'refresh:'+context,refresh)
          await backend.store(scope,'finish',hash,sealed)
          return reply({state:'consent_saved'})
        }
        case 'disconnect': {
          const connection=await backend.store(scope,'disconnect')
          if (connection.state==='disconnected') return reply({state:'disconnected'})
          if (!connection.sealed || !connection.generation || connection.state!=='revocation_pending')
            throw new DriveError('unavailable')
          const refresh=await openDriveToken(key,'refresh:'+context,connection.sealed)
          await google.revoke(refresh)
          await backend.store(scope,'revoked',connection.generation)
          return reply({state:'disconnected'})
        }
        default: throw new DriveError('invalid')
      }
    } catch (error) {
      const code=error instanceof DriveError?error.code:'unavailable'
      return reply({error:{code}},statuses[code])
    }
  }
}
