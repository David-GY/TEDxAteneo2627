import {digest,FileFault} from '../files/validation.ts'
import type {FileBackend} from '../files/handler.ts'
import {driveConnection} from '../google-oauth/connection.ts'
import {DriveError,type createGoogleDrive} from '../google-oauth/google.ts'
import type {DriveBackend} from '../google-oauth/handler.ts'
import {driveFileId,isDriveUuid} from '../google-oauth/protocol.ts'
import type {createDriveCopyProvider} from './copy-provider.ts'

type Action='drive_copy_choices'|'save_drive_copy'
export const isDriveCopy=(value: unknown): value is Action=>value==='drive_copy_choices'||value==='save_drive_copy'
type Input={work?:unknown;asset?:unknown;destination?:unknown}
type CopyRequest={term:string;work:string;asset:string;destination:string;subject:string}
export type CopyJob=(input: CopyRequest,fileId?:string,verified?:boolean)=>Promise<Record<string,unknown>>

export function createDriveCopy(drive: DriveBackend, files: Pick<FileBackend,'get'|'rpc'>, job: CopyJob,
  google: Pick<ReturnType<typeof createGoogleDrive>,'refresh'>, provider: ReturnType<typeof createDriveCopyProvider>,key: CryptoKey) {
  const connection=driveConnection(drive,google,key)
  return async (action: Action,jwt:string,term:string,input: Input)=>{
    if (!isDriveUuid(input.work)||!isDriveUuid(input.asset)) throw new DriveError('invalid')
    const {work,asset}=input
    const destination=input.destination
    if (action==='save_drive_copy'&&!isDriveUuid(destination)) throw new DriveError('invalid')
    const scope=await drive.authorize(jwt,term)
    const read=(choice?:string)=>files.rpc(jwt,'read_drive_copy',{
      p_term_id:term,p_work_item_id:work,p_asset_id:asset,p_destination_id:choice??null,
    })
    try {
      if (action==='drive_copy_choices') return await read()
      if (typeof destination!=='string') throw new DriveError('invalid')
      const {folder,owner,readers,path,sha256,size,name,mime}=await read(destination)
      if (typeof folder!=='string'||!driveFileId.test(folder)||owner!==scope.email||!Array.isArray(readers)
        || !readers.every(reader=>typeof reader==='string')||typeof path!=='string'||typeof sha256!=='string'
        || typeof name!=='string'||typeof mime!=='string'||!Number.isSafeInteger(size)) throw new DriveError('denied')
      const policy={id:folder,owner,readers}
      const token=await connection.fresh(scope)
      await provider.checkFolder(token.access,policy)
      const request={term,work,asset,destination,subject:scope.subject}
      let record=await job(request)
      if (!record.id) record=await job(request,await provider.generateId(token.access))
      if (!isDriveUuid(record.id)||typeof record.fileId!=='string'||!driveFileId.test(record.fileId)) throw new DriveError('unavailable')
      const bytes=await files.get(path)
      if (bytes.length!==size||await digest(bytes)!==sha256) throw new DriveError('file_unavailable')
      await read(destination)
      await connection.active(scope,token.generation)
      await provider.copy(token.access,{id:record.fileId,folder,name,mime,sha256,receipt:record.id,bytes},policy,record.verified===true)
      await job(request,record.fileId,true)
      return {state:'copied',name}
    } catch(error) {
      if (error instanceof FileFault && error.code==='42501') throw new DriveError('denied')
      if (error instanceof FileFault && error.code==='40001') throw new DriveError('stale')
      throw error
    }
  }
}
