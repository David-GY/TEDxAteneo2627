import type { createSupabaseClient } from '../../../lib/supabase'

const states = ['missing', 'started', 'interrupted', 'verified', 'failed', 'blocked', 'stale', 'pending'] as const
const blockers = ['device', 'provider', 'key', 'ledger', 'target', 'custody'] as const
export type BackupState = typeof states[number]
type BackupBlocker = typeof blockers[number]
export type BackupHealth = {
  checkedAt: string
  backupStatus: BackupState
  restoreStatus: BackupState
  backupBlocker: BackupBlocker | null
  restoreBlocker: BackupBlocker | null
  lastVerifiedBackupAt: string | null
  lastBackupAttemptAt: string | null
  lastRestoreAttemptAt: string | null
  backupFreshUntil: string | null
  backupEvidence: string | null
  restoreEvidence: string | null
}
export type ReadBackupHealth = (term: string) => Promise<BackupHealth>

const validTime = (v: unknown) => typeof v === 'string' && Number.isFinite(Date.parse(v))
const validHash = (v: unknown) => v === null || typeof v === 'string' && /^[a-f0-9]{64}$/.test(v)
const validBlocker = (v: BackupBlocker | null) => v === null || blockers.includes(v)
function validHealth(v: BackupHealth): boolean {
  return !!v && validTime(v.checkedAt) && states.includes(v.backupStatus) && states.includes(v.restoreStatus) &&
    validBlocker(v.backupBlocker) && validBlocker(v.restoreBlocker) &&
    [v.lastVerifiedBackupAt, v.lastBackupAttemptAt, v.lastRestoreAttemptAt, v.backupFreshUntil].every(x => x === null || validTime(x)) &&
    validHash(v.backupEvidence) && validHash(v.restoreEvidence) &&
    (v.backupStatus !== 'verified' || !!v.backupFreshUntil && !!v.backupEvidence) &&
    (v.restoreStatus !== 'verified' || v.backupStatus === 'verified' && !!v.restoreEvidence)
}

export function createBackupHealthReader(ready: ReturnType<typeof createSupabaseClient>): ReadBackupHealth {
  return async term => {
    const client = await ready
    if (!client) throw new Error('Recovery status unavailable')
    const { data, error } = await client.rpc('read_backup_health', { p_term_id: term })
    if (error) throw error
    const health = data as unknown as BackupHealth
    if (!validHealth(health)) throw new Error('Recovery status unavailable')
    return health
  }
}
