import type { createSupabaseClient } from '../../../lib/supabase'
import { mapCommandError, type CommandResult } from '../../../lib/commands'

export const profileFields = {
  displayName: 'Display name',
  course: 'Course',
  yearLevel: 'Year level',
  phone: 'Phone',
  externalContact: 'External contact',
  skills: 'Skills',
  pronunciation: 'Pronunciation',
  affiliation: 'Affiliation',
  contactRoute: 'Contact route',
}
export type ProfileField = keyof typeof profileFields
type Values = Partial<Record<ProfileField, string | null>>
type Sharing = Partial<Record<ProfileField, boolean>>
type Scope = { term: string; id: string }
type Candidate = {
  status: 'ready' | 'prepared'
  audience: 'member' | 'guest'
  verificationReference: string
  validUntil: string
  values: Values
  sharing: Sharing
  correctionField: ProfileField | null
  correctionValue: string | null
  canApprove: boolean
  reviewHash: string | null
}
export type Fulfillment = Candidate | { status: 'waiting' | 'step_up' | 'paused' | 'finished' | 'identity_needed' | 'stale' }
  | { status: 'released'; validUntil: string }
export type ProfileResponse = { reference: string; validUntil: string; values: Values; sharing: Sharing }
export type FulfillmentCommand = Scope & { version: number } & (
  { action: 'prepare'; field: string | null; value: string | null }
  | { action: 'approve'; reviewHash: string }
)
export interface FulfillmentApi {
  read(scope: Scope): Promise<Fulfillment | null>
  response(scope: Scope, exportCsv: boolean): Promise<ProfileResponse | null>
  run(command: FulfillmentCommand, key: string): Promise<CommandResult<{ version: number }>>
}
const plain = (value: unknown): value is Record<string, unknown> => !!value && typeof value === 'object' && !Array.isArray(value)
const map = (value: unknown, valid: (v: unknown) => boolean) =>
  plain(value) && Object.entries(value).every(([field, entry]) => Object.hasOwn(profileFields, field) && valid(entry))
const optionalValue = (v: unknown) => v === null || typeof v === 'string' && v.length <= 1000
const expiry = (v: unknown) => typeof v === 'string' && Number.isFinite(Date.parse(v))
const validHash = (v: unknown) => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v)

export function createFulfillmentApi(ready: ReturnType<typeof createSupabaseClient>): FulfillmentApi {
  type Reader = 'read_privacy_fulfillment' | 'read_privacy_response' | 'export_privacy_response'
  async function read(name: Reader, scope: Scope) {
    const client = await ready
    if (!client) throw new Error()
    const { data, error } = await client.rpc(name, { p_term_id: scope.term, p_privacy_request_id: scope.id })
    if (error) throw error
    return data
  }
  return {
    async read(scope) {
      const data = await read('read_privacy_fulfillment', scope)
      if (data === null) return null
      if (!plain(data)) throw new Error()
      if (typeof data.status === 'string' &&
          ['waiting', 'step_up', 'paused', 'finished', 'identity_needed', 'stale'].includes(data.status)) {
        return { status: data.status } as Fulfillment
      }
      if (data.status === 'released' && typeof data.validUntil === 'string' && expiry(data.validUntil)) {
        return { status: 'released', validUntil: data.validUntil }
      }
      if ((data.status === 'ready' || data.status === 'prepared') && (data.audience === 'member' || data.audience === 'guest') &&
          typeof data.verificationReference === 'string' && expiry(data.validUntil) &&
          map(data.values, optionalValue) && map(data.sharing, v => typeof v === 'boolean') &&
          (data.correctionField === null || typeof data.correctionField === 'string' && Object.hasOwn(profileFields, data.correctionField)) &&
          optionalValue(data.correctionValue) && typeof data.canApprove === 'boolean' &&
          (data.status === 'ready' ? data.reviewHash === null : validHash(data.reviewHash))) return data as Candidate
      throw new Error()
    },
    async response(scope, exportCsv) {
      const data = await read(exportCsv ? 'export_privacy_response' : 'read_privacy_response', scope)
      if (data === null) return null
      if (!plain(data) || Object.keys(data).length !== 4 || typeof data.reference !== 'string' || !/^PRIV-\d+$/.test(data.reference) ||
          !expiry(data.validUntil) || !map(data.values, optionalValue) || !map(data.sharing, v => typeof v === 'boolean')) throw new Error()
      return data as ProfileResponse
    },
    async run(command, key) {
      try {
        const client = await ready
        if (!client) throw { code: 'COMMAND_UNAVAILABLE' }
        const args = { p_term_id: command.term, p_privacy_request_id: command.id, p_expected_version: command.version, p_request_id: key }
        const { data, error } = command.action === 'prepare'
          ? await client.rpc('prepare_privacy_fulfillment', { ...args, p_correction_field: command.field, p_correction_value: command.value })
          : await client.rpc('approve_privacy_fulfillment', { ...args, p_review_hash: command.reviewHash })
        if (error) throw error
        const version = command.version + (command.action === 'approve' ? 1 : 0)
        if (!plain(data) || data.version !== version) throw { code: 'COMMAND_UNAVAILABLE' }
        return { ok: true, value: { version } }
      } catch (error) {
        const e = error as { message?: string }
        return { ok: false, error: e.message === 'privacy_identity_evidence_required'
          ? { kind: 'dependency_blocked', message: 'Current verified identity evidence is required through the approved privacy channel.', retryable: false }
          : mapCommandError(error) }
      }
    },
  }
}
