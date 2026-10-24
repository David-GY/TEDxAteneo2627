import { expect, it, vi } from 'vitest'
import { createClient } from '@supabase/supabase-js'
import { createSupabaseClient } from './supabase'
vi.mock('@supabase/supabase-js', () => ({ createClient: vi.fn() }))

it('P04_A3: no client without config; configured client uses explicit PKCE and manual callback exchange', async () => {
  expect(await createSupabaseClient({ state: 'not_configured', issues: [] })).toBeNull()
  expect(createClient).not.toHaveBeenCalled()
  await createSupabaseClient({ state: 'configured', supabaseUrl: 'https://example.supabase.co', supabasePublishableKey: 'sb_publishable_test_only' })
  expect(createClient).toHaveBeenCalledWith('https://example.supabase.co','sb_publishable_test_only', {
    auth: { flowType: 'pkce', detectSessionInUrl: false, persistSession: true, autoRefreshToken: true },
  })
})
