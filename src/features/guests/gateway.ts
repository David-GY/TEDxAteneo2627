import type { createSupabaseClient } from '../../lib/supabase'

export type GuestInvitation = {
  id: string; email: string; expiresAt: string; redeemedAt: string | null
  revokedAt: string | null; version: number; scopeMode: 'awaiting_record_attachment' | 'explicit_records'; sharedRecordCount?: number
}
export type InvitationLink = { id: string; token: string | null; reused: boolean }
export interface GuestGateway {
  list(termId: string): Promise<GuestInvitation[]>
  create(termId: string, email: string, requestId: string, expiresAt?: string, replaces?: GuestInvitation): Promise<InvitationLink>
  revoke(invitation: GuestInvitation, requestId: string): Promise<void>
  redeem(token: string): Promise<void>
}
export function createGuestGateway(ready: ReturnType<typeof createSupabaseClient>): GuestGateway {
  const message = 'Guest access could not be updated. Refresh the list and check your account, invitation and expiry before retrying.'
  async function client() {
    const value = await ready
    if (!value) throw new Error('Guest access needs Supabase and Google sign-in setup.')
    return value
  }
  return {
    async list(termId) {
      try {
        const {data,error} = await (await client()).rpc('list_guest_invitations',{p_term_id:termId})
        if (error || !Array.isArray(data)) throw new Error(message)
        return data as unknown as GuestInvitation[]
      } catch { throw new Error(message) }
    },
    async create(termId,email,requestId,expiresAt,replaces) {
      try {
        const {data,error} = await (await client()).rpc('create_guest_invitation',{
          p_term_id:termId,p_email:email,p_request_id:requestId,p_expires_at:expiresAt,
          p_replaces_id:replaces?.id,p_expected_version:replaces?.version,
        })
        if (error || !data || typeof data !== 'object' || Array.isArray(data) || typeof data.id !== 'string'
          || !(data.token === null || (typeof data.token === 'string' && /^[a-f0-9]{64}$/.test(data.token)))) throw new Error(message)
        return data as InvitationLink
      } catch { throw new Error(message) }
    },
    async revoke(invitation,requestId) {
      try {
        const {data,error}=await (await client()).rpc('revoke_guest_access',{p_invitation_id:invitation.id,p_expected_version:invitation.version,p_request_id:requestId})
        if(error || !data || typeof data !== 'object' || Array.isArray(data) || data.state!=='revoked') throw new Error(message)
      } catch { throw new Error(message) }
    },
    async redeem(token) {
      try {
        const {data,error}=await (await client()).rpc('redeem_guest_invitation',{p_token:token})
        if(error || !data || typeof data !== 'object' || Array.isArray(data) || data.state!=='redeemed') throw new Error(message)
      } catch { throw new Error(message) }
    },
  }
}

// A fragment is never sent in the HTTP request. Consume it before rendering or starting OAuth.
export function readInvitationFragment(hash: string): string | null {
  return /^#[a-f0-9]{64}$/.test(hash) ? hash.slice(1) : null
}
export function invitationUrl(origin: string,token: string) { return `${origin}/guest/redeem#${token}` }
