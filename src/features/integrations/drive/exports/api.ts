import { DriveUiError } from '../api'
import { pickDriveFile } from '../picker'

export type RenditionOffer = {selection: string; name: string}
export type SavedRendition = {manifestId: string; name: string; url: string}
export interface RenditionApi {
  pick(term: string,work: string,signal: AbortSignal): Promise<RenditionOffer|null>
  save(term: string,work: string,selection: string): Promise<SavedRendition>
}
type Destination = {id:string;label:string}
export interface ApprovedCopyApi {
  destinations(term:string,work:string,asset:string):Promise<Destination[]>
  copy(term:string,work:string,asset:string,destination:string):Promise<{name:string}>
}

export function createApprovedCopyApi(send: (term:string,action:string,fields:Record<string,unknown>)=>Promise<unknown>): ApprovedCopyApi {
  return {
    async destinations(term,work,asset) {
      const result=await send(term,'drive_copy_choices',{work,asset}) as Partial<{destinations:Destination[]}>
      if (!Array.isArray(result.destinations)||!result.destinations.every(item=>item&&typeof item.id==='string'&&typeof item.label==='string'))
        throw new DriveUiError('unavailable')
      return result.destinations
    },
    async copy(term,work,asset,destination) {
      const result=await send(term,'save_drive_copy',{work,asset,destination}) as Partial<{state:string;name:string}>
      if (result.state!=='copied'||typeof result.name!=='string') throw new DriveUiError('unavailable')
      return {name:result.name}
    },
  }
}

export function createRenditionApi(send: (term: string,action: string,fields: Record<string,unknown>)=>Promise<unknown>, origin: string): RenditionApi {
  return {
    async pick(term,work,signal) {
      const opened=await send(term,'begin_rendition',{work}) as Partial<{accessToken: string; selection: string; appId: string; developerKey: string}>
      const {accessToken,selection,appId,developerKey}=opened
      if (typeof accessToken!=='string' || typeof selection!=='string' || typeof appId!=='string' || typeof developerKey!=='string')
        throw new DriveUiError('unavailable')
      if (signal.aborted) return null
      const model=await pickDriveFile({accessToken,appId,developerKey},origin,signal)
      if (!model || signal.aborted) return null
      const offer=await send(term,'review_rendition',{work,selection,file:model.id,resourceKey:model.resourceKey}) as Partial<RenditionOffer>
      if (typeof offer.selection!=='string' || typeof offer.name!=='string') throw new DriveUiError('unavailable')
      return {selection:offer.selection,name:offer.name}
    },
    async save(term,work,selection) {
      const receipt=await send(term,'save_rendition',{work,selection}) as Partial<SavedRendition>
      if (typeof receipt.manifestId!=='string' || typeof receipt.name!=='string' || typeof receipt.url!=='string') throw new DriveUiError('unavailable')
      return {manifestId:receipt.manifestId,name:receipt.name,url:receipt.url}
    },
  }
}
