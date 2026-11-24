import { type createGoogleDrive, DriveError } from './google.ts'
import type { DriveBackend, DriveSubject } from './handler.ts'
import { driveFileId, isDriveUuid, openDriveToken, sealDriveToken } from './protocol.ts'
import { driveConnection } from './connection.ts'

type Action = 'begin_picker' | 'check_selection' | 'attach_selection'
type Source = Awaited<ReturnType<ReturnType<typeof createGoogleDrive>['metadata']>>
type SelectionScope = { term: string; work: string; version: number; generation: string; until: number }
type CheckedSelection = SelectionScope & { source: Source; resourceKey?: string; requestId: string }
type SelectionInput = { work?: unknown; version?: unknown; selection?: unknown; file?: unknown; resourceKey?: unknown }
export type DriveSelection = (action: Action, jwt: string, term: string, input: SelectionInput) => Promise<unknown>

export function isDriveSelection(action: unknown): action is Action {
  return action==='begin_picker' || action==='check_selection' || action==='attach_selection'
}

export function driveSelection(
  backend: DriveBackend, google: Pick<ReturnType<typeof createGoogleDrive>,'refresh'|'metadata'>,
  key: CryptoKey, picker: { appId: string; developerKey: string },
): DriveSelection {
  if (!/^\d{1,24}$/.test(picker.appId) || !/^AIza[A-Za-z0-9_-]{15,80}$/.test(picker.developerKey))
    throw new Error('Drive Picker configuration is invalid')

  const {active,fresh:freshToken}=driveConnection(backend,google,key)

  async function current(jwt: string, expected: DriveSubject, term: string, work: string, generation: string) {
    const scope=await backend.authorize(jwt,term,work)
    if (scope.membership!==expected.membership || scope.subject!==expected.subject || scope.email!==expected.email)
      throw new DriveError('denied')
    await active(scope,generation)
  }

  async function proof<T extends SelectionScope>(sealed: unknown, context: string, term: string, work: string): Promise<T> {
    if (typeof sealed!=='string') throw new DriveError('invalid')
    let value: T
    try {
      value=JSON.parse(await openDriveToken(key,context,sealed))
    } catch {
      throw new DriveError('stale')
    }
    if (!value || value.term!==term || value.work!==work || value.until<=Date.now()) throw new DriveError('stale')
    return value
  }

  return async (action,jwt,term,input) => {
    if (!isDriveUuid(input.work)) throw new DriveError('invalid')
    const work=input.work, scope=await backend.authorize(jwt,term,work)
    const context=scope.membership+':'+scope.subject
    if (action==='begin_picker') {
      if (typeof input.version!=='number' || !Number.isSafeInteger(input.version) || input.version<1)
        throw new DriveError('invalid')
      const token=await freshToken(scope)
      await current(jwt,scope,term,work,token.generation)
      const until=Date.now()+Math.min(5*60,token.expiresIn)*1000
      const selection=await sealDriveToken(key,'picker:'+context,JSON.stringify({term,work,version:input.version,generation:token.generation,until}))
      return {selection,accessToken:token.access,...picker}
    }
    if (action==='check_selection') {
      if (typeof input.file!=='string' || !driveFileId.test(input.file)
        || (input.resourceKey!==undefined && (typeof input.resourceKey!=='string' || !driveFileId.test(input.resourceKey))))
        throw new DriveError('invalid')
      const checked=await proof<SelectionScope>(input.selection,'picker:'+context,term,work)
      const token=await freshToken(scope,checked.generation)
      const source=await google.metadata(token.access,input.file,input.resourceKey)
      await current(jwt,scope,term,work,checked.generation)
      const checkedSelection=await sealDriveToken(key,'attachment:'+context,JSON.stringify({
        ...checked,source,resourceKey:input.resourceKey,requestId:crypto.randomUUID(),until:Date.now()+5*60*1000,
      }))
      return {selection:checkedSelection,name:source.name,owner:source.owner}
    }

    const checked=await proof<CheckedSelection>(input.selection,'attachment:'+context,term,work)
    const token=await freshToken(scope,checked.generation)
    await google.metadata(token.access,checked.source.id,checked.resourceKey)
    await current(jwt,scope,term,work,checked.generation)
    if (!backend.saveWorkingSource) throw new DriveError('unavailable')
    await backend.saveWorkingSource(jwt,work,checked.version,checked.requestId,checked.source)
    return {state:'attached',name:checked.source.name}
  }
}
