import { bounded, MAX_FILE, workingUrl } from '../files/validation.ts'
import { driveFileId } from './protocol.ts'
import { schoolGoogleConsent, GoogleConsentError as DriveError, type GoogleConsentConfig } from './consent.ts'

export { DriveError }
export type { GoogleConsentErrorCode as DriveErrorCode } from './consent.ts'
export const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive.file'

export function createGoogleDrive(config:GoogleConsentConfig,transport:typeof fetch=fetch) {
  const {request,data,auth,...consent}=schoolGoogleConsent(config,'/integrations/drive/callback',[DRIVE_SCOPE],transport)

  async function fileMetadata(access: string, file: string, resourceKey?: string) {
    if (!driveFileId.test(file) || (resourceKey!==undefined && !driveFileId.test(resourceKey))) throw new DriveError('invalid')
    const url=new URL('https://www.googleapis.com/drive/v3/files/'+file)
    url.search=new URLSearchParams({
      supportsAllDrives:'true',
      fields:'id,name,webViewLink,mimeType,owners(displayName),trashed,isAppAuthorized,version,capabilities(canDownload)',
    }).toString()
    const response=await request(url,{headers:fileHeaders(access,file,resourceKey)})
    if (response.status===401) throw new DriveError('reconnect')
    if ([403,404].includes(response.status)) throw new DriveError('file_unavailable')
    if (!response.ok) throw new DriveError('unavailable')
    const value=await data(response)
    if (value.id!==file || value.isAppAuthorized!==true || value.trashed!==false || typeof value.mimeType!=='string'
      || ['application/vnd.google-apps.folder','application/vnd.google-apps.shortcut'].includes(value.mimeType)
      || typeof value.name!=='string' || !value.name.trim() || typeof value.webViewLink!=='string') {
      throw new DriveError('file_unavailable')
    }
    let link
    try { link=workingUrl(value.webViewLink) } catch { throw new DriveError('file_unavailable') }
    const target=new URL(link)
    if (!['drive.google.com','docs.google.com'].includes(target.hostname) || target.pathname.split('/')[3]!==file)
      throw new DriveError('file_unavailable')
    const singleLine = (text: string, length: number) => text.replace(/[\p{Cc}\p{Cf}]/gu,' ').trim().slice(0,length)
    const owner = Array.isArray(value.owners)?value.owners[0]?.displayName:undefined
    const name=singleLine(value.name,160)
    if (!name) throw new DriveError('file_unavailable')
    return {source:{id:file,name,url:link,owner:typeof owner==='string'?singleLine(owner,160)||null:null},value}
  }

  function fileHeaders(access: string, file: string, resourceKey?: string): Record<string,string> {
    const headers: Record<string,string>=auth(access)
    if (resourceKey) headers['X-Goog-Drive-Resource-Keys']=file+'/'+resourceKey
    return headers
  }

  return {
    ...consent,
    async metadata(access: string, file: string, resourceKey?: string) {
      return (await fileMetadata(access,file,resourceKey)).source
    },
    async nativeSource(access: string, file: string, resourceKey?: string) {
      const {source,value}=await fileMetadata(access,file,resourceKey)
      if (!['application/vnd.google-apps.document','application/vnd.google-apps.spreadsheet','application/vnd.google-apps.presentation'].includes(String(value.mimeType))
        || typeof value.version!=='string' || !/^\d{1,30}$/.test(value.version)
        || (value.capabilities as {canDownload?:boolean}|null)?.canDownload!==true) throw new DriveError('file_unavailable')
      return {id:source.id,name:source.name,url:source.url,version:value.version}
    },
    async pdf(access: string, file: string, resourceKey?: string) {
      if (!driveFileId.test(file) || (resourceKey!==undefined && !driveFileId.test(resourceKey))) throw new DriveError('invalid')
      const url=new URL('https://www.googleapis.com/drive/v3/files/'+file+'/export')
      url.searchParams.set('mimeType','application/pdf')
      const response=await request(url,{headers:fileHeaders(access,file,resourceKey)})
      if (response.status===401) throw new DriveError('reconnect')
      if ([403,404].includes(response.status)) throw new DriveError('file_unavailable')
      if (!response.ok) throw new DriveError('unavailable')
      if (response.headers.get('content-type')?.split(';')[0]!=='application/pdf') throw new DriveError('file_unavailable')
      try { return await bounded(response.body,MAX_FILE) } catch { throw new DriveError('file_unavailable') }
    },
  }
}
