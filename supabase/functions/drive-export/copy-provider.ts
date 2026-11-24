import {bounded} from '../files/validation.ts'
import {DriveError} from '../google-oauth/google.ts'
import {driveFileId,schoolAddress} from '../google-oauth/protocol.ts'

export type DriveFolderPolicy = {id: string; owner: string; readers: string[]}
type Copy = {id: string; folder: string; name: string; mime: string; sha256: string; receipt: string; bytes: Uint8Array}
const base='https://www.googleapis.com/drive/v3/files'
const fields='id,parents,trashed,size,mimeType,sha256Checksum,appProperties'

export function createDriveCopyProvider(transport: typeof fetch=fetch) {
  async function request(access: string,url: string|URL,init: RequestInit={}) {
    try {
      return await transport(url,{...init,headers:{...init.headers,Authorization:'Bearer '+access},
        redirect:'error',signal:AbortSignal.timeout(15000)})
    } catch { throw new DriveError('unavailable') }
  }
  function requireSuccess(response: Response) {
    if (response.status===401) throw new DriveError('reconnect')
    if ([403,404].includes(response.status)) throw new DriveError('denied')
    if (!response.ok) throw new DriveError('unavailable')
  }
  async function json(response: Response): Promise<Record<string,unknown>> {
    requireSuccess(response)
    try {
      const data=JSON.parse(new TextDecoder().decode(await bounded(response.body,16384)))
      if (data&&typeof data==='object'&&!Array.isArray(data)) return data
    } catch { /* Provider details are not returned to members. */ }
    throw new DriveError('unavailable')
  }
  function url(id: string,scope: string) {
    if (!driveFileId.test(id)) throw new DriveError('invalid')
    return new URL(base+'/'+id+scope)
  }

  async function checkFolder(access: string,policy: DriveFolderPolicy) {
    const expected=new Map<string,string>([[policy.owner,'owner'],...policy.readers.map((email):[string,string]=>[email,'reader'])])
    if (expected.size!==policy.readers.length+1 || expected.size>21 || [...expected.keys()].some(email=>!schoolAddress.test(email)))
      throw new DriveError('invalid')
    const folder=url(policy.id,'')
    folder.searchParams.set('fields','id,name,mimeType,trashed,driveId,isAppAuthorized,inheritedPermissionsDisabled,writersCanShare,capabilities(canAddChildren)')
    const data=await json(await request(access,folder))
    if (data.id!==policy.id || data.mimeType!=='application/vnd.google-apps.folder' || data.trashed!==false
      || data.isAppAuthorized!==true || data.driveId!==undefined || data.inheritedPermissionsDisabled!==true
      || data.writersCanShare!==false || (data.capabilities as {canAddChildren?:boolean}|null)?.canAddChildren!==true
      || typeof data.name!=='string' || !data.name.trim()) throw new DriveError('denied')
    const acl=url(policy.id,'/permissions')
    acl.search=new URLSearchParams({pageSize:'100',fields:'nextPageToken,permissions(type,emailAddress,role,deleted,expirationTime,pendingOwner,view)'}).toString()
    const list=await json(await request(access,acl))
    if (list.nextPageToken || !Array.isArray(list.permissions) || list.permissions.length!==expected.size)
      throw new DriveError('denied')
    for (const permission of list.permissions) {
      if (permission?.type!=='user' || !expected.has(permission.emailAddress) || permission.role!==expected.get(permission.emailAddress)
        || permission.deleted || permission.expirationTime || permission.pendingOwner || permission.view) throw new DriveError('denied')
      expected.delete(permission.emailAddress)
    }
    return data.name.replace(/[\p{Cc}\p{Cf}]/gu,' ').trim().slice(0,160)
  }

  async function generateId(access: string) {
    const data=await json(await request(access,base+'/generateIds?count=1&space=drive&type=files'))
    if (!Array.isArray(data.ids)||data.ids.length!==1||typeof data.ids[0]!=='string'||!driveFileId.test(data.ids[0]))
      throw new DriveError('unavailable')
    return data.ids[0]
  }

  async function copy(access: string,input: Copy, policy: DriveFolderPolicy, alreadyVerified=false) {
    if (input.folder!==policy.id || !/^[a-f0-9]{64}$/.test(input.sha256) || !driveFileId.test(input.receipt)
      || !['application/pdf','image/jpeg','image/png'].includes(input.mime)
      || input.name.length<1 || input.name.length>160 || /[\p{Cc}\p{Cf}]/u.test(input.name))
      throw new DriveError('invalid')
    const lookup=url(input.id,'')
    lookup.searchParams.set('fields',fields)
    await checkFolder(access,policy)
    const boundary='workspace_'+crypto.randomUUID()
    const metadata={id:input.id,name:input.name,parents:[policy.id],mimeType:input.mime,appProperties:{workspaceReceipt:input.receipt}}
    const body=new Blob([
      '--'+boundary+'\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'+JSON.stringify(metadata)+'\r\n',
      '--'+boundary+'\r\nContent-Type: '+input.mime+'\r\n\r\n',input.bytes as Uint8Array<ArrayBuffer>,
      '\r\n--'+boundary+'--\r\n',
    ])
    const upload=new URL('https://www.googleapis.com/upload/drive/v3/files')
    upload.searchParams.set('uploadType','multipart')
    upload.searchParams.set('fields',fields)
    const response=alreadyVerified ? await request(access,lookup)
      : await request(access,upload,{method:'POST',headers:{'Content-Type':'multipart/related; boundary='+boundary},body})
    const actual=await json(response.status===409?await request(access,lookup):response)
    if (actual.id!==input.id || actual.trashed!==false || !Array.isArray(actual.parents) || actual.parents.length!==1
      || actual.parents[0]!==policy.id || actual.mimeType!==input.mime || actual.size!==String(input.bytes.length)
      || actual.sha256Checksum!==input.sha256 || (actual.appProperties as {workspaceReceipt?:string}|null)?.workspaceReceipt!==input.receipt)
      throw new DriveError('denied')
    await checkFolder(access,policy)
  }

  return {checkFolder,generateId,copy}
}
