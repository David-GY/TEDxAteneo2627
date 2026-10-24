export type ClientEnvironment =
  | { state: 'not_configured'; issues: string[] }
  | { state: 'configured'; supabaseUrl: string; supabasePublishableKey: string }

type ClientEnvironmentInput = {
  VITE_SUPABASE_URL?: string
  VITE_SUPABASE_PUBLISHABLE_KEY?: string
}

export function readClientEnvironment(input: ClientEnvironmentInput): ClientEnvironment {
  const supabaseUrl = input.VITE_SUPABASE_URL?.trim() ?? ''
  const supabasePublishableKey = input.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ?? ''
  const issues: string[] = []

  if (!supabaseUrl) {
    issues.push('VITE_SUPABASE_URL is missing.')
  } else {
    try {
      const url = new URL(supabaseUrl)
      const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)
      if (
        (url.protocol !== 'https:' && !(local && url.protocol === 'http:')) ||
        url.username || url.password || url.search || url.hash || url.pathname !== '/'
      ) {
        issues.push('VITE_SUPABASE_URL must be an HTTPS origin, or HTTP on local loopback.')
      }
    } catch {
      issues.push('VITE_SUPABASE_URL must be a valid project URL.')
    }
  }

  if (!supabasePublishableKey) {
    issues.push('VITE_SUPABASE_PUBLISHABLE_KEY is missing.')
  } else if (!/^sb_publishable_[A-Za-z0-9_-]+$/.test(supabasePublishableKey)) {
    issues.push('VITE_SUPABASE_PUBLISHABLE_KEY must be a publishable key, never a secret key.')
  }

  return issues.length
    ? { state: 'not_configured', issues }
    : { state: 'configured', supabaseUrl, supabasePublishableKey }
}
