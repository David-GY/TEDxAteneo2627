import type { createSupabaseClient } from '../../lib/supabase'
import { spreadsheetCsv } from '../imports/csv'

export type OperationalKind = 'task' | 'deliverable'

const headers = ['term_id', 'term', 'work_id', 'reference', 'title', 'due_on', 'due_at_utc', 'original_due_on', 'original_due_at_utc']
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function csvRow(value: unknown, kind: OperationalKind, termId: string, termLabel: string) {
  if (!value || typeof value !== 'object') throw new Error()
  const { id, reference, title, dueOn, dueAt, originalDueOn, originalDueAt } = value as Record<string, unknown>
  const referencePattern = kind === 'task' ? /^TASK-\d{3,16}$/ : /^DEL-\d{3,16}$/
  if (Object.keys(value).length !== 7 || typeof id !== 'string' || !uuid.test(id) ||
      typeof reference !== 'string' || !referencePattern.test(reference) || typeof title !== 'string') throw new Error()
  const dates = [dueOn, dueAt, originalDueOn, originalDueAt].map(date => {
    if (date === null) return ''
    if (typeof date !== 'string' || !Number.isFinite(Date.parse(date))) throw new Error()
    return date
  })
  return [termId, termLabel, id, reference, title, ...dates]
}

export type OperationalExport = (termId: string, kind: OperationalKind) => Promise<string | null>

export function createOperationalExport(ready: ReturnType<typeof createSupabaseClient>): OperationalExport {
  return async (termId, kind) => {
    const client = await ready
    if (!client) throw new Error('The connection is unavailable. Try again.')
    const { data, error } = await client.rpc('export_operational_work', { p_term_id: termId, p_kind: kind })
    if (error?.code === '42501') throw new Error('Current access does not allow this download.')
    if (error?.message === 'operational_export_limit') throw new Error('This term has more than 2,000 eligible records. No partial file was downloaded.')
    if (error?.message === 'work_reference_backfill_pending') throw new Error('Some eligible records are waiting for issued references. Ask a workspace administrator to check reference backfill.')
    if (error || !data || typeof data !== 'object' || Array.isArray(data)) throw new Error('The CSV could not be prepared. Check your connection and try again.')
    const { termId: responseTerm, termLabel, kind: responseKind, rows } = data
    if (Object.keys(data).length !== 4 || responseTerm !== termId || responseKind !== kind ||
        typeof termLabel !== 'string' || !Array.isArray(rows) || rows.length > 2000) throw new Error()
    return rows.length ? spreadsheetCsv([headers, ...rows.map(row => csvRow(row, kind, termId, termLabel))]) : null
  }
}
