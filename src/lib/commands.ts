import type { createSupabaseClient } from './supabase'

export type WorkKind = 'deliverable' | 'task' | 'request' | 'announcement'
export type CommandErrorKind = 'permission_denied' | 'validation_failed' | 'stale_version' | 'dependency_blocked' | 'missing_approver' | 'quota_limit' | 'conflict' | 'idempotency_conflict' | 'unavailable' | 'unexpected'
export type CommandError = { kind: CommandErrorKind; message: string; retryable: boolean }
export type CommandResult<T> = { ok: true; value: T } | { ok: false; error: CommandError }
export type WorkReceipt = { workItemId: string; version: number }
export type CreatedWorkReceipt = WorkReceipt & { kind: WorkKind }
export type GrantReceipt = WorkReceipt & { grantId: string }
export type RecordPrincipal =
  | { memberId: string; unitId?: never; guestInvitationId?: never }
  | { memberId?: never; unitId: string; guestInvitationId?: never }
  | { memberId?: never; unitId?: never; guestInvitationId: string }
export type CreateWorkInput = {
  termId: string; kind: WorkKind; title: string; safeSummary: string; body: string
  classification: 'ordinary' | 'restricted'; leadUnitId?: string | null
  parent?: { id: string; expectedVersion: number } | null; requestId: string
}
export type UpdateWorkInput = { workItemId: string; title: string; safeSummary: string; body: string; expectedVersion: number; requestId: string }
export type GrantWorkInput = { workItemId: string; principal: RecordPrincipal; grantKind: 'read' | 'edit'; expiresAt: string; expectedVersion: number; requestId: string }

const messages: Record<CommandErrorKind, string> = {
  permission_denied: 'Your current access does not allow this action.',
  validation_failed: 'Check the supplied fields and try again.',
  stale_version: 'This record changed. Reload it before applying your edit.',
  dependency_blocked: 'This action needs a prerequisite or a later workflow step.',
  missing_approver: 'An eligible approver must be assigned before this action.',
  quota_limit: 'The permitted limit has been reached. Check the limit before retrying.',
  conflict: 'The action conflicts with an existing record or another change. Reload and review it.',
  idempotency_conflict: 'This request key was already used with different details. Review the earlier request before starting a new one.',
  unavailable: 'The result could not be confirmed. Check access or connection, then retry the same request key and details.',
  unexpected: 'The service returned an unexpected result. Reload and review before retrying.',
}
export function mapCommandError(error: unknown): CommandError {
  const value = error && typeof error === 'object' ? error as { code?: unknown; message?: unknown } : {}
  const code = typeof value.code === 'string' ? value.code : ''
  if(code==='55000'&&value.message==='work_reference_backfill_pending')return{kind:'dependency_blocked',message:'Work references are being prepared for this term. Your inputs are kept. Ask the workspace maintainer to finish setup, then try again.',retryable:false}
  let kind: CommandErrorKind = 'unexpected'
  if (value.message === 'command_idempotency_conflict') kind = 'idempotency_conflict'
  else if (value.message === 'command_missing_approver') kind = 'missing_approver'
  else if (value.message === 'command_quota_limit') kind = 'quota_limit'
  else if (['42501','PGRST301','PGRST302'].includes(code)) kind = 'permission_denied'
  else if (code === '40001') kind = 'stale_version'
  else if (['22023','22007','22008','22P02','23503','23514','23502'].includes(code)) kind = 'validation_failed'
  else if (code === '55000') kind = 'dependency_blocked'
  else if (['23505','40P01','55P03'].includes(code)) kind = 'conflict'
  else if (!code || ['COMMAND_UNAVAILABLE','ECONNRESET','ETIMEDOUT'].includes(code)) kind = 'unavailable'
  return { kind, message: messages[kind], retryable: kind === 'unavailable' }
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
function receipt(value: unknown): value is WorkReceipt {
  if (!value || typeof value !== 'object') return false
  const data = value as Record<string, unknown>
  return typeof data.workItemId === 'string' && uuid.test(data.workItemId) && Number.isInteger(data.version) && (data.version as number) > 0
}
function createdReceipt(value: unknown): value is CreatedWorkReceipt {
  return receipt(value) && 'kind' in value && ['deliverable','task','request','announcement'].includes(value.kind as string)
}
function grantReceipt(value: unknown): value is GrantReceipt {
  return receipt(value) && 'grantId' in value && typeof value.grantId === 'string' && uuid.test(value.grantId)
}
async function confirmed<T>(operation: () => PromiseLike<{ data: unknown; error: unknown }>, valid: (data: unknown) => data is T): Promise<CommandResult<T>> {
  try {
    const { data, error } = await operation()
    if (error) return { ok: false, error: mapCommandError(error) }
    if (!valid(data)) return { ok: false, error: { kind: 'unexpected', message: messages.unexpected, retryable: false } }
    return { ok: true, value: data }
  } catch (error) { return { ok: false, error: mapCommandError(error) } }
}

// Four bounded RPCs, no generic entity dispatcher and no hidden automatic retries.
export function createWorkCommands(ready: ReturnType<typeof createSupabaseClient>) {
  async function client() {
    const value = await ready
    if (!value) throw { code: 'COMMAND_UNAVAILABLE' }
    return value
  }
  return {
    create(input: CreateWorkInput) {
      return confirmed(async () => (await client()).rpc('create_work_item', {
        p_term_id: input.termId, p_kind: input.kind, p_title: input.title, p_safe_summary: input.safeSummary, p_body: input.body,
        p_classification: input.classification, p_lead_unit_id: input.leadUnitId ?? null,
        p_parent_id: input.parent?.id ?? null, p_expected_parent_version: input.parent?.expectedVersion ?? null, p_request_id: input.requestId,
      }), createdReceipt)
    },
    update(input: UpdateWorkInput) {
      return confirmed(async () => (await client()).rpc('update_work_item', {
        p_work_item_id: input.workItemId, p_title: input.title, p_safe_summary: input.safeSummary, p_body: input.body,
        p_expected_version: input.expectedVersion, p_request_id: input.requestId,
      }), receipt)
    },
    grant(input: GrantWorkInput) {
      return confirmed(async () => (await client()).rpc('grant_work_access', {
        p_work_item_id: input.workItemId, p_member_id: input.principal.memberId ?? null, p_unit_id: input.principal.unitId ?? null,
        p_guest_invitation_id: input.principal.guestInvitationId ?? null, p_grant_kind: input.grantKind, p_expires_at: input.expiresAt,
        p_expected_version: input.expectedVersion, p_request_id: input.requestId,
      }), grantReceipt)
    },
    revoke(input: { grantId: string; expectedVersion: number; requestId: string }) {
      return confirmed(async () => (await client()).rpc('revoke_work_access', {
        p_grant_id: input.grantId, p_expected_version: input.expectedVersion, p_request_id: input.requestId,
      }), grantReceipt)
    },
  }
}
