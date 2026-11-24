import { DriveError, type createGoogleDrive } from './google.ts'
import type { DriveBackend, DriveSubject } from './handler.ts'
import { openDriveToken } from './protocol.ts'

export function driveConnection(backend: DriveBackend, google: Pick<ReturnType<typeof createGoogleDrive>,'refresh'>, key: CryptoKey) {
  async function active(scope: DriveSubject, generation?: string) {
    const connection=await backend.store(scope,'picker')
    if (connection.state!=='authorized' || !connection.sealed || !connection.generation)
      throw new DriveError(connection.state==='revocation_pending'?'denied':'reconnect')
    if (generation && connection.generation!==generation) throw new DriveError('stale')
    return {sealed:connection.sealed,generation:connection.generation}
  }
  async function fresh(scope: DriveSubject, generation?: string) {
    const connection=await active(scope,generation)
    const refresh=await openDriveToken(key,'refresh:'+scope.membership+':'+scope.subject,connection.sealed)
    try {
      return {...await google.refresh(refresh),generation:connection.generation}
    } catch (error) {
      if (error instanceof DriveError && error.code==='reconnect') await backend.store(scope,'expire',connection.generation)
      throw error
    }
  }
  return {active,fresh}
}
