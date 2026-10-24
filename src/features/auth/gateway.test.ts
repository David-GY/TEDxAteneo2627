import { beforeEach, expect, it, vi } from 'vitest'
import { createSupabaseClient } from '../../lib/supabase'
import { readClientEnvironment } from '../../lib/env'
import { createAuthGateway, parseContext, returnStorageKey } from './gateway'

vi.mock('../../lib/supabase', () => ({ createSupabaseClient: vi.fn() }))
const configured = readClientEnvironment({ VITE_SUPABASE_URL: 'https://example.supabase.co', VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test_only' })
const context = { state: 'authorized', memberId: 'm', organizationId: 'o', termId: 't', termMembershipId: 'tm', displayName: 'Test only', expiresAt: new Date(Date.now()+60_000).toISOString(), capabilities: [] }
function fixture() {
  const auth = {
    getSession: vi.fn(async () => ({ data: { session: {} }, error: null })),
    getUser: vi.fn(async () => ({ data: { user: { id: 'verified-subject' } }, error: null as unknown })),
    exchangeCodeForSession: vi.fn(async () => ({ error: null })),
    signInWithOAuth: vi.fn(async () => ({ error: null })),
    signOut: vi.fn(async () => ({ error: null as unknown })),
    onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
  }
  const rpc = vi.fn(async () => ({ data: context, error: null }))
  vi.mocked(createSupabaseClient).mockResolvedValue({ auth, rpc } as unknown as Awaited<ReturnType<typeof createSupabaseClient>>)
  return { auth, rpc, gateway: createAuthGateway(configured, 'http://127.0.0.1:5173') }
}
beforeEach(() => { vi.clearAllMocks(); sessionStorage.clear() })

it('P04_A1: valid session still requires a trusted context, with no submitted actor/email', async () => {
  const { gateway, rpc } = fixture()
  expect(await gateway.readContext()).toEqual(context)
  expect(rpc).toHaveBeenCalledWith('resolve_auth_context')
  expect(parseContext({ ...context, expiresAt: '2000-01-01' })).toBeNull()
  expect(parseContext({ email: 'approved@student.ateneo.edu', state: 'authorized' })).toBeNull()
})

it('P04_A2: rejected/expired server session never calls roster RPC', async () => {
  const { gateway, rpc, auth } = fixture()
  auth.getUser.mockResolvedValue({ data: { user: { id: 'old-subject' } }, error: new Error('expired') })
  expect(await gateway.readContext()).toEqual({ state: 'signed_out' })
  expect(rpc).not.toHaveBeenCalled()
})

it('P04_A3: PKCE callback is exchanged once and OAuth uses exact redirect/account prompt', async () => {
  const { gateway, auth } = fixture()
  await Promise.all([gateway.exchange('test-code'), gateway.exchange('test-code')])
  expect(auth.exchangeCodeForSession).toHaveBeenCalledTimes(1)
  await gateway.beginGoogle('//untrusted.example')
  expect(sessionStorage.getItem(returnStorageKey)).toBe('/')
  expect(auth.signInWithOAuth).toHaveBeenCalledWith({ provider: 'google', options: {
    redirectTo: 'http://127.0.0.1:5173/auth/callback', scopes: 'openid email profile', queryParams: { prompt: 'select_account' },
  } })
})

it('P04_A3: sign-out failure stays a failure and unexpected provider details are not shown', async () => {
  const { gateway, auth } = fixture()
  auth.signOut.mockResolvedValue({ error: new Error('private-token-diagnostic') })
  await expect(gateway.signOut()).rejects.toThrow('Sign-out could not be confirmed')
  auth.signInWithOAuth.mockRejectedValue(new Error('private-token-diagnostic'))
  await expect(gateway.beginGoogle('/tasks')).rejects.toThrow('Google sign-in could not start')
})

it('P04_A3: unsupported application origin prevents starting OAuth or resolving access', async () => {
  fixture()
  const gateway = createAuthGateway(configured, 'https://unapproved.example')
  expect(await gateway.readContext()).toEqual({ state: 'unavailable' })
  await expect(gateway.beginGoogle('/')).rejects.toThrow('not configured for this address')
})
