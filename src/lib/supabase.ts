import type { Database } from './database.types'
import type { ClientEnvironment } from './env'

export async function createSupabaseClient(environment: ClientEnvironment) {
  if (environment.state !== 'configured') return null
  const { createClient } = await import('@supabase/supabase-js')
  return createClient<Database>(environment.supabaseUrl, environment.supabasePublishableKey, {
    auth: { flowType: 'pkce', detectSessionInUrl: false, persistSession: true, autoRefreshToken: true },
  })
}
