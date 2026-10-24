import { describe, expect, it } from 'vitest'
import { readClientEnvironment } from './env'

const publicKey = 'sb_publishable_synthetic_test_only'

describe('public configuration', () => {
  it('boots unconfigured with both public values missing', () => {
    expect(readClientEnvironment({})).toEqual({
      state: 'not_configured',
      issues: ['VITE_SUPABASE_URL is missing.', 'VITE_SUPABASE_PUBLISHABLE_KEY is missing.'],
    })
  })

  it.each(['https://example.supabase.co', 'http://127.0.0.1:54321', 'http://localhost:54321', 'http://[::1]:54321'])(
    'accepts public settings at %s without claiming a connection', (url) => {
      expect(readClientEnvironment({ VITE_SUPABASE_URL: url, VITE_SUPABASE_PUBLISHABLE_KEY: publicKey }).state)
        .toBe('configured')
    },
  )

  it.each(['not-a-url', 'http://remote.example', 'https://user:password@example.com', 'https://example.com/path', 'https://example.com?key=private'])(
    'rejects unsafe or malformed origin %s without echoing it', (url) => {
      const result = readClientEnvironment({ VITE_SUPABASE_URL: url, VITE_SUPABASE_PUBLISHABLE_KEY: publicKey })
      expect(result.state).toBe('not_configured')
      expect(JSON.stringify(result)).not.toContain(url)
    },
  )

  it.each(['sb_secret_synthetic_never_expose', 'eyJsyntheticLegacyRole', 'sb_publishable_'])(
    'rejects inappropriate keys without including their values in errors', (key) => {
      const result = readClientEnvironment({ VITE_SUPABASE_URL: 'https://example.supabase.co', VITE_SUPABASE_PUBLISHABLE_KEY: key })
      expect(result.state).toBe('not_configured')
      expect(JSON.stringify(result)).not.toContain(key)
    },
  )
})
