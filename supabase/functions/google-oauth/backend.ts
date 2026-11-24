import { DriveError } from './google.ts'
import { type DriveBackend, type StoreResult } from './handler.ts'
import { isDriveUuid, schoolAddress } from './protocol.ts'

export function driveRestBackend(url: string, publicKey: string, serviceKey: string): DriveBackend {
  async function rpc(method: string, args: Record<string,unknown>, authorization: string, apikey: string) {
    const response=await fetch(url+'/rest/v1/rpc/'+method,{
      method:'POST',headers:{apikey,Authorization:authorization,'Content-Type':'application/json'},
      body:JSON.stringify(args),redirect:'error',signal:AbortSignal.timeout(8000),
    })
    const value=await response.json()
    if (!response.ok) {
      if (value?.code==='42501') throw new DriveError('denied')
      if (value?.code==='40001') throw new DriveError('stale')
      throw new DriveError('unavailable')
    }
    return value
  }

  return {
    async authorize(jwt,term,work) {
      const response=await fetch(url+'/auth/v1/user',{
        headers:{apikey:publicKey,Authorization:jwt},redirect:'error',signal:AbortSignal.timeout(8000),
      })
      if (!response.ok) throw new DriveError(response.status===401||response.status===403?'denied':'unavailable')
      const user=await response.json()
      if (!isDriveUuid(user?.id) || typeof user.email!=='string' || !schoolAddress.test(user.email)
        || typeof user.email_confirmed_at!=='string') throw new DriveError('denied')
      const membership=await rpc('drive_oauth_scope',{p_term_id:term,p_work_item_id:work??null},jwt,publicKey)
      if (!isDriveUuid(membership)) throw new DriveError('denied')
      return {subject:user.id,email:user.email,membership}
    },
    async store(scope,action,guard,sealed) {
      const result: StoreResult=await rpc('drive_oauth_store',{
        p_membership_id:scope.membership,p_subject_id:scope.subject,p_action:action,p_guard:guard??null,p_sealed:sealed??null,
      },'Bearer '+serviceKey,serviceKey)
      if (!result || !['disconnected','awaiting_consent','authorized','revocation_pending'].includes(result.state))
        throw new DriveError('unavailable')
      return result
    },
    async saveWorkingSource(jwt,work,version,requestId,source) {
      const result=await rpc('save_working_link',{
        p_work_item_id:work,p_asset_id:null,p_url:source.url,p_name:source.name,
        p_notes:(source.owner?'Drive owner: '+source.owner+'. ':'')+'Ask the source custodian for access. Google sharing still applies.',
        p_label:'Drive working source',p_expected_version:version,p_request_id:requestId,
      },jwt,publicKey)
      if (!isDriveUuid(result?.assetId) || !Number.isSafeInteger(result.version)) throw new DriveError('unavailable')
    },
  }
}
