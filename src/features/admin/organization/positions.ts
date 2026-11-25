import type { createSupabaseClient } from '../../../lib/supabase'
import { mapCommandError, type CommandResult } from '../../../lib/commands'

export type Position = {
  id: string
  name: string
  unitId: string | null
  tier: 'leadership' | 'head' | 'core'
  administrator: boolean
  available: boolean
}

export type Seat = {
  id: string
  membershipId: string
  roleId: string
  deploymentId: string | null
  version: number
  from: string
  to: string
  state: string
  managed: boolean
}

export type PositionRoster = { positions: Position[]; seats: Seat[] }
export type SeatChange = {
  term: string
  seat: Seat | null
  membershipId: string
  roleId: string
  from: string
  to: string
  reason: string
  remove: boolean
}

type Client = NonNullable<Awaited<ReturnType<typeof createSupabaseClient>>>

export async function readPositionRoster(client: Client, term: string): Promise<PositionRoster | null> {
  const { data, error } = await client.rpc('read_tedx_positions', { p_term_id: term })
  const roster = data as unknown as PositionRoster | null
  if (error || !roster || !Array.isArray(roster.positions) || !Array.isArray(roster.seats)) return null
  return roster
}

export async function saveSeat(
  ready: ReturnType<typeof createSupabaseClient>, change: SeatChange, key: string,
): Promise<CommandResult<{ id: string; version: number }>> {
  try {
    const client = await ready
    if (!client) throw { code: 'COMMAND_UNAVAILABLE' }
    const { data, error } = await client.rpc('save_tedx_seat', {
      p_term_id: change.term,
      p_seat_id: change.seat?.id ?? null,
      p_expected_version: change.seat?.version ?? null,
      p_membership_id: change.membershipId,
      p_role_id: change.roleId,
      p_from: change.remove ? null : change.from,
      p_to: change.remove ? null : change.to,
      p_remove: change.remove,
      p_reason: change.reason,
      p_request_id: key,
    })
    if (error) {
      if (error.message === 'command_position_overlap') {
        return { ok: false, error: { kind: 'conflict', message: 'This member already has that role for part of the selected dates.', retryable: false } }
      }
      if (error.message === 'command_deployment_overlap') {
        return { ok: false, error: { kind: 'conflict', message: 'A deployment already starts at this time. Choose a new start or review the existing deployment.', retryable: false } }
      }
      return { ok: false, error: mapCommandError(error) }
    }
    const result = data as { id?: string; version?: number } | null
    if (result && typeof result.id === 'string' && typeof result.version === 'number' && Number.isSafeInteger(result.version)) {
      return { ok: true, value: { id: result.id, version: result.version } }
    }
    return { ok: false, error: mapCommandError({ code: 'COMMAND_UNAVAILABLE' }) }
  } catch (error) {
    return { ok: false, error: mapCommandError(error) }
  }
}
