import type { FileBackend } from '../files/handler.ts'
import { FileFault, validateFile } from '../files/validation.ts'
import { driveConnection } from '../google-oauth/connection.ts'
import { DriveError, type createGoogleDrive } from '../google-oauth/google.ts'
import type { DriveBackend } from '../google-oauth/handler.ts'
import { driveFileId, isDriveUuid, openDriveToken, sealDriveToken } from '../google-oauth/protocol.ts'

type Action = 'begin_rendition' | 'review_rendition' | 'save_rendition'
export const isRendition = (value: unknown): value is Action =>
  value==='begin_rendition' || value==='review_rendition' || value==='save_rendition'
type Input = {work?: unknown; selection?: unknown; file?: unknown; resourceKey?: unknown}
type Source = Awaited<ReturnType<ReturnType<typeof createGoogleDrive>['nativeSource']>>
type Ticket = {term: string; work: string; version: number; generation: string; until: number}
type Offer = Ticket & {source: Source; resourceKey?: string; reserve: string; finish: string}
type StagedAsset = {id: string; path: string; sha256: string; size: number; state: 'reserved'|'validated'|'finalized'}
export type RenditionStage = {version: number; asset?: StagedAsset; manifestId?: string}
export type ReadRenditionStage = (jwt: string, term: string, work: string, version?: number, reserve?: string, finish?: string)=>Promise<RenditionStage>

export function createDriveRendition(
  drive: DriveBackend, readStage: ReadRenditionStage, files: Pick<FileBackend,'rpc'|'get'|'put'|'seal'>,
  google: Pick<ReturnType<typeof createGoogleDrive>,'refresh'|'nativeSource'|'pdf'>, key: CryptoKey,
  picker: {appId: string; developerKey: string},
) {
  const connection=driveConnection(drive,google,key)
  const mime='application/pdf'
  const filename=(name: string)=>name.replace(/[/\\]/g,'-').replace(/\.pdf$/i,'').slice(0,156)+'.pdf'

  async function verify<T extends Ticket>(value: unknown, context: string, term: string, work: string): Promise<T> {
    if (typeof value!=='string') throw new DriveError('invalid')
    let ticket: T
    try { ticket=JSON.parse(await openDriveToken(key,context,value)) } catch { throw new DriveError('stale') }
    if (ticket.term!==term || ticket.work!==work || ticket.until<=Date.now()) throw new DriveError('stale')
    return ticket
  }

  async function save(jwt: string, offer: Offer, scope: Awaited<ReturnType<DriveBackend['authorize']>>) {
    const {term,work,source,version,resourceKey,reserve,finish}=offer
    const stage=await readStage(jwt,term,work,version,reserve,finish)
    const name=filename(source.name)
    const receipt=(manifestId: string)=>({manifestId,name,url:source.url})
    if (stage.manifestId) return receipt(stage.manifestId)
    let bytes: Uint8Array|undefined
    if (stage.asset) {
      try { bytes=await files.get(stage.asset.path) }
      catch (error) {
        if (!(error instanceof FileFault) || error.code!=='COMMAND_UNAVAILABLE') throw error
      }
    }
    const needsWrite=!bytes
    if (!bytes) {
      const token=await connection.fresh(scope,offer.generation)
      if ((await google.nativeSource(token.access,source.id,resourceKey)).version!==source.version) throw new DriveError('stale')
      bytes=await google.pdf(token.access,source.id,resourceKey)
      if ((await google.nativeSource(token.access,source.id,resourceKey)).version!==source.version) throw new DriveError('stale')
      await connection.active(scope,offer.generation)
    }
    const checked=await validateFile(name,mime,bytes).catch(()=>{throw new DriveError('file_unavailable')})
    if (stage.asset && (stage.asset.sha256!==checked.sha256 || stage.asset.size!==checked.size))
      throw new DriveError('file_unavailable')
    await readStage(jwt,term,work,version,reserve,finish)
    const asset=stage.asset??await files.rpc(jwt,'reserve_upload',{
      p_work_item_id:work,p_name:name,p_mime:mime,p_size:checked.size,p_sha256:checked.sha256,
      p_source_id:null,p_source_version:null,p_expected_version:version,p_request_id:reserve,
    }).then(result=>{
      if (!isDriveUuid(result.assetId) || typeof result.path!=='string') throw new DriveError('unavailable')
      return {id:result.assetId,path:result.path}
    })
    if (!asset) throw new DriveError('unavailable')
    if (needsWrite) await files.put(asset.path,bytes,mime,checked.sha256)
    await readStage(jwt,term,work,version,reserve,finish)
    await files.seal(asset.id,checked.sha256,checked.size,mime)
    const result=await files.rpc(jwt,'finalize_upload',{
      p_work_item_id:work,p_asset_ids:[asset.id],p_expected_version:version,p_request_id:finish,
    })
    if (!isDriveUuid(result.manifestId)) throw new DriveError('unavailable')
    return receipt(result.manifestId)
  }

  return async (action: Action,jwt: string,term: string,input: Input) => {
    if (!isDriveUuid(input.work)) throw new DriveError('invalid')
    const work=input.work, scope=await drive.authorize(jwt,term)
    const context=scope.membership+':'+scope.subject
    try {
      if (action==='begin_rendition') {
        const stage=await readStage(jwt,term,work)
        const token=await connection.fresh(scope)
        await readStage(jwt,term,work,stage.version)
        await connection.active(scope,token.generation)
        const until=Date.now()+Math.min(300,token.expiresIn)*1000
        const selection=await sealDriveToken(key,'rendition-picker:'+context,JSON.stringify({
          term,work,version:stage.version,generation:token.generation,until,
        }))
        return {selection,accessToken:token.access,...picker}
      }
      if (action==='review_rendition') {
        if (typeof input.file!=='string' || !driveFileId.test(input.file)
          || (input.resourceKey!==undefined && (typeof input.resourceKey!=='string'||!driveFileId.test(input.resourceKey))))
          throw new DriveError('invalid')
        const ticket=await verify<Ticket>(input.selection,'rendition-picker:'+context,term,work)
        await readStage(jwt,term,work,ticket.version)
        const token=await connection.fresh(scope,ticket.generation)
        const source=await google.nativeSource(token.access,input.file,input.resourceKey)
        await readStage(jwt,term,work,ticket.version)
        await connection.active(scope,ticket.generation)
        const offer: Offer={...ticket,source,resourceKey:input.resourceKey,reserve:crypto.randomUUID(),finish:crypto.randomUUID(),until:Date.now()+3600_000}
        return {selection:await sealDriveToken(key,'rendition-save:'+context,JSON.stringify(offer)),name:filename(source.name),version:source.version}
      }
      const offer=await verify<Offer>(input.selection,'rendition-save:'+context,term,work)
      return await save(jwt,offer,scope)
    } catch (error) {
      if (!(error instanceof FileFault)) throw error
      if (error.code==='42501') throw new DriveError('denied')
      if (error.code==='40001' || error.tag==='command_idempotency_conflict') throw new DriveError('stale')
      if (error.code==='22023' || error.code==='55000') throw new DriveError('file_unavailable')
      throw new DriveError('unavailable')
    }
  }
}
