import type { createSupabaseClient } from '../../../lib/supabase'
import { pickDriveFile } from './picker'
import {createApprovedCopyApi,createRenditionApi,type ApprovedCopyApi,type RenditionApi} from './exports/api'

const attemptTerm='tedx.drive.consent-term'

export type DriveState = 'disconnected' | 'awaiting_consent' | 'consent_saved' | 'revocation_pending'
export class DriveUiError extends Error {
  constructor(readonly code: string) { super(code) }
}

export interface DriveApi {
  rendition?: RenditionApi
  approvedCopy?: ApprovedCopyApi
  status(term: string): Promise<DriveState>
  connect(term: string, popup: Window): Promise<void>
  finish(term: string, state: string, code: string | null, error: string | null): Promise<void>
  disconnect(term: string): Promise<void>
  select(term: string, work: string, version: number, signal: AbortSignal): Promise<{selection: string; name: string; owner: string | null} | null>
  attach(term: string, work: string, selection: string): Promise<{name: string}>
}

export function takeDriveConsentTerm() {
  const term=sessionStorage.getItem(attemptTerm)
  sessionStorage.removeItem(attemptTerm)
  return term
}

export function createDriveApi(ready: ReturnType<typeof createSupabaseClient>, origin: string, evidence=false): DriveApi {
  async function send(term: string, action: string, fields: Record<string,unknown>={}) {
    const client=await ready
    if (!client || window.location.origin!==origin) throw new DriveUiError('unavailable')
    const {data,error}=await client.functions.invoke('google-oauth',{body:{term,action,...fields}})
    if (error || !data || typeof data!=='object') {
      const response=error?.context instanceof Response?await error.context.json().catch(()=>null):null
      throw new DriveUiError(typeof response?.error?.code==='string'?response.error.code:'unavailable')
    }
    return data
  }
  return {
    ...(evidence?{rendition:createRenditionApi(send,origin),approvedCopy:createApprovedCopyApi(send)}:{}),
    async status(term) {
      const {state}=await send(term,'status')
      if (!['disconnected','awaiting_consent','consent_saved','revocation_pending'].includes(state))
        throw new DriveUiError('unavailable')
      return state
    },
    async connect(term,popup) {
      const {url}=await send(term,'start')
      if (typeof url!=='string' || popup.closed) throw new DriveUiError('unavailable')
      const target=new URL(url)
      if (target.origin!=='https://accounts.google.com' || target.pathname!=='/o/oauth2/v2/auth'
        || target.searchParams.get('redirect_uri')!==origin+'/integrations/drive/callback') throw new DriveUiError('denied')
      popup.sessionStorage.setItem(attemptTerm,term)
      popup.opener=null
      popup.location.replace(target.href)
    },
    async finish(term,state,code,error) {
      if ((await send(term,'finish',{state,code,error})).state!=='consent_saved') throw new DriveUiError('unavailable')
    },
    async disconnect(term) {
      if ((await send(term,'disconnect')).state!=='disconnected') throw new DriveUiError('unavailable')
    },
    async select(term,work,version,signal) {
      const opened=await send(term,'begin_picker',{work,version})
      if (typeof opened.accessToken!=='string' || typeof opened.selection!=='string' || typeof opened.appId!=='string'
        || typeof opened.developerKey!=='string') throw new DriveUiError('unavailable')
      if (signal.aborted) return null
      const picked=await pickDriveFile(opened,origin,signal)
      if (!picked || signal.aborted) return null
      const checked=await send(term,'check_selection',{work,selection:opened.selection,file:picked.id,resourceKey:picked.resourceKey})
      if (typeof checked.selection!=='string' || typeof checked.name!=='string'
        || (checked.owner!==null && typeof checked.owner!=='string')) throw new DriveUiError('unavailable')
      return {selection:checked.selection,name:checked.name,owner:checked.owner}
    },
    async attach(term,work,selection) {
      const result=await send(term,'attach_selection',{work,selection})
      if (result.state!=='attached' || typeof result.name!=='string') throw new DriveUiError('unavailable')
      return {name:result.name}
    },
  }
}
