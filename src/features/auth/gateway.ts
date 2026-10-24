import type { ClientEnvironment } from '../../lib/env'
import { createSupabaseClient } from '../../lib/supabase'
import { callbackUrl, safeReturnPath } from './redirects'
import { createGuestGateway, type GuestGateway } from '../guests/gateway'
import { createPeopleGateway, type PeopleGateway } from '../people/gateway'
import { createProfileGateway, type ProfileGateway } from '../account/gateway'
import { createGuestContactGateway, type GuestContactGateway } from '../account/guestContacts'
import { createDeliverablesApi, type DeliverablesApi } from '../deliverables/api'
import { createDeliverableCommands, type DeliverableCommands } from '../deliverables/commands'

import { createTasksApi, type TasksApi } from '../tasks/api'

export type MemberContext = {
  state: 'authorized'; memberId: string; displayName: string; organizationId: string
  termId: string; termMembershipId: string; expiresAt: string; capabilities: string[]
}
export type GuestContext = {
  state: 'authorized'; audience: 'guest'; guestAccessId: string; displayName: string
  organizationId: string; termId: string; expiresAt: string; capabilities: string[]
}
export type WorkspaceContext = MemberContext | GuestContext
export const isGuest = (value: WorkspaceContext): value is GuestContext => 'audience' in value && value.audience === 'guest'
export type AuthResult = WorkspaceContext | { state: 'unavailable' | 'signed_out' | 'denied' | 'error' }
export interface AuthGateway {
  tasks?: TasksApi
  deliverables?: DeliverablesApi
  deliverableCommands?: DeliverableCommands
  guestContacts?: GuestContactGateway
  profile?: ProfileGateway
  people?: PeopleGateway
  guests?: GuestGateway
  readContext: (signal?: AbortSignal) => Promise<AuthResult>
  beginGoogle: (returnTo: string) => Promise<void>
  exchange: (code: string) => Promise<void>
  signOut: () => Promise<void>
  onChange: (listener: () => void) => () => void
}

export function parseContext(input: unknown): WorkspaceContext | null {
  if (!input || typeof input !== 'object') return null
  const value = input as Record<string, unknown>
  const keys = value.audience === 'guest' ? ['guestAccessId','displayName','organizationId','termId','expiresAt'] : ['memberId','displayName','organizationId','termId','termMembershipId','expiresAt']
  if (value.state !== 'authorized' || !keys.every((key) => typeof value[key] === 'string' && value[key] !== '')
    || !Array.isArray(value.capabilities) || !value.capabilities.every((entry) => typeof entry === 'string')
    || !Number.isFinite(Date.parse(value.expiresAt as string)) || Date.parse(value.expiresAt as string) <= Date.now()) return null
  if (value.audience === 'guest' && value.capabilities.length !== 0) return null
  return value as WorkspaceContext
}

export const returnStorageKey = 'tedx.auth.return'
export function consumeReturnPath(): string {
  try { const path = safeReturnPath(sessionStorage.getItem(returnStorageKey)); sessionStorage.removeItem(returnStorageKey); return path } catch { return '/' }
}

export function createAuthGateway(environment: ClientEnvironment, origin: string): AuthGateway {
  const redirectTo = callbackUrl(origin)
  const clientReady = redirectTo ? createSupabaseClient(environment).catch(() => null) : Promise.resolve(null)
  let exchangeCode: string | undefined
  let exchangePromise: Promise<void> | undefined
  return {
    tasks: createTasksApi(clientReady),
    deliverables: createDeliverablesApi(clientReady),
    deliverableCommands: createDeliverableCommands(clientReady),
    guestContacts: createGuestContactGateway(clientReady),
    profile: createProfileGateway(clientReady),
    people: createPeopleGateway(clientReady),
    guests: createGuestGateway(clientReady),
    async readContext(signal) {
      const client = await clientReady
      if (!client || !redirectTo) return { state: 'unavailable' }
      try {
        const { data: session, error: sessionError } = await client.auth.getSession()
        if (sessionError || !session.session) return { state: 'signed_out' }
        const { data: identity, error: identityError } = await client.auth.getUser()
        if (identityError || !identity.user) return { state: 'signed_out' }
        signal?.throwIfAborted()
        const query = client.rpc('resolve_auth_context')
        const { data, error } = await (signal ? query.abortSignal(signal) : query)
        if (error) return { state: 'error' }
        return parseContext(data) ?? { state: 'denied' }
      } catch { return { state: 'error' } }
    },
    async beginGoogle(returnTo) {
      const client = await clientReady
      if (!client || !redirectTo) throw new Error('Sign-in is not configured for this address.')
      try { sessionStorage.setItem(returnStorageKey, safeReturnPath(returnTo)) } catch { /* Safe fallback is the overview. */ }
      try { const { error } = await client.auth.signInWithOAuth({ provider: 'google', options: {
        redirectTo, scopes: 'openid email profile', queryParams: { prompt: 'select_account' },
      } })
        if (error) throw error
      } catch { throw new Error('Google sign-in could not start. Check provider setup or try again.') }
    },
    exchange(code) {
      // StrictMode can replay the callback effect. Exchange each code once per gateway instance.
      if (exchangeCode !== code) {
        exchangeCode = code
        exchangePromise = (async () => {
          const client = await clientReady
          if (!client || !redirectTo) throw new Error('Sign-in is not configured.')
          try { const { error } = await client.auth.exchangeCodeForSession(code); if (error) throw error }
          catch { throw new Error('Google sign-in could not be completed. Start sign-in again.') }
        })()
      }
      return exchangePromise!
    },
    async signOut() {
      const client = await clientReady
      if (!client) return
      try { const { error } = await client.auth.signOut({ scope: 'local' }); if (error) throw error }
      catch { throw new Error('Sign-out could not be confirmed. Please try again.') }
      try { sessionStorage.removeItem(returnStorageKey) } catch { /* No application data is cached. */ }
    },
    onChange(listener) {
      let stopped = false
      let unsubscribe = () => undefined as void
      void clientReady.then((client) => {
        if (!client || stopped) return
        const { data } = client.auth.onAuthStateChange(() => { queueMicrotask(() => { if (!stopped) listener() }) })
        unsubscribe = () => data.subscription.unsubscribe()
      })
      return () => { stopped = true; unsubscribe() }
    },
  }
}
