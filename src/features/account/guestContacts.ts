import type { createSupabaseClient } from '../../lib/supabase'
export type GuestContact = { displayName: string; verifiedEmail: string; contactRoute: string | null; version: number }
export type GuestContactView = { own: GuestContact; sharedContacts: []; scopeMode: 'awaiting_record_attachment' }
export interface GuestContactGateway {
  read(termId: string): Promise<GuestContactView>
  save(termId: string, values: { displayName: string | null; contactRoute: string | null }, version: number, requestId: string): Promise<GuestContactView>
}
function parse(data: unknown): GuestContactView {
  if (!data || typeof data !== 'object') throw new Error('Your contacts are unavailable. Check your invitation access and reload.')
  const value = data as Record<string, unknown>
  const own = value.own as Record<string, unknown> | undefined
  if (!own || typeof own.displayName !== 'string' || typeof own.verifiedEmail !== 'string' || !Number.isInteger(own.version) || (own.version as number) < 0
    || (own.contactRoute !== null && typeof own.contactRoute !== 'string') || !Array.isArray(value.sharedContacts) || value.sharedContacts.length !== 0 || value.scopeMode !== 'awaiting_record_attachment') {
    throw new Error('Your contacts are unavailable. Check your invitation access and reload.')
  }
  return value as GuestContactView
}
export function createGuestContactGateway(ready: ReturnType<typeof createSupabaseClient>): GuestContactGateway {
  const message = 'Your contact request could not be confirmed. Retry the same details or reload your contacts.'
  return {
    async read(termId) {
      try {
        const client = await ready
        if (!client) throw new Error()
        const { data, error } = await client.rpc('read_guest_contacts', { p_term_id: termId })
        if (error) throw new Error()
        return parse(data)
      } catch { throw new Error('Your contacts are unavailable. Check your invitation access and reload.') }
    },
    async save(termId, values, version, requestId) {
      let result
      try {
        const client = await ready
        if (!client) throw new Error()
        result = await client.rpc('save_guest_contact_profile', { p_term_id: termId, p_values: values, p_expected_version: version, p_request_id: requestId })
      } catch { throw new Error(message) }
      if (result.error?.code === '40001') throw new Error('Your contact details changed elsewhere. Reload before saving again.')
      if (result.error?.code === '42501') throw new Error('Your invitation access changed. Reopen your invitation or ask its sender for help.')
      if (result.error) throw new Error(message)
      return parse(result.data)
    },
  }
}
