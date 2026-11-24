export type ClientEnvironment =
  | { state: 'not_configured'; issues: string[] }
  | { state: 'configured'; supabaseUrl: string; supabasePublishableKey: string; appOrigin?: string; drivePicker?: true; driveEvidence?: true; calendarSync?: true; telegramBot?: string; emailDigest?: true }

type ClientEnvironmentInput = {
  VITE_SUPABASE_URL?: string
  VITE_SUPABASE_PUBLISHABLE_KEY?: string
  VITE_APP_ORIGIN?: string
  VITE_DRIVE_PICKER_ENABLED?: string
  VITE_DRIVE_EVIDENCE_ENABLED?: string
  VITE_CALENDAR_SYNC_ENABLED?: string
  VITE_TELEGRAM_BOT_USERNAME?: string
  VITE_EMAIL_DIGEST_ENABLED?: string
}

function isExactHttpsOrigin(value: string): boolean {
  try {
    const url = new URL(value)
    return url.protocol === 'https:' && url.origin === value && !url.port
      && /^[a-z0-9-]+(?:\.[a-z0-9-]+)+$/.test(url.hostname)
  } catch {
    return false
  }
}

export function readClientEnvironment(input: ClientEnvironmentInput): ClientEnvironment {
  const supabaseUrl = input.VITE_SUPABASE_URL?.trim() ?? ''
  const supabasePublishableKey = input.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ?? ''
  const appOrigin = input.VITE_APP_ORIGIN?.trim()
  const drivePicker = input.VITE_DRIVE_PICKER_ENABLED?.trim()
  const driveEvidence = input.VITE_DRIVE_EVIDENCE_ENABLED?.trim()
  const calendarSync = input.VITE_CALENDAR_SYNC_ENABLED?.trim()
  const telegramBot = input.VITE_TELEGRAM_BOT_USERNAME?.trim()
  const emailDigest = input.VITE_EMAIL_DIGEST_ENABLED?.trim()
  const issues: string[] = []

  if (!supabaseUrl) {
    issues.push('VITE_SUPABASE_URL is missing.')
  } else {
    try {
      const url = new URL(supabaseUrl)
      const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)
      const allowedLoopback = !appOrigin && local && url.protocol === 'http:' && url.origin === supabaseUrl.replace(/\/$/, '')
      if (!allowedLoopback && !isExactHttpsOrigin(supabaseUrl.replace(/\/$/, ''))) {
        issues.push('VITE_SUPABASE_URL must be an HTTPS origin, or HTTP on local loopback.')
      }
    } catch {
      issues.push('VITE_SUPABASE_URL must be a valid project URL.')
    }
  }

  if (appOrigin && !isExactHttpsOrigin(appOrigin)) issues.push('VITE_APP_ORIGIN must be one exact HTTPS origin.')
  if (appOrigin && appOrigin === supabaseUrl.replace(/\/$/, '')) issues.push('Use separate frontend and Supabase origins.')
  if (drivePicker && drivePicker!=='false' && (drivePicker!=='true'||!appOrigin)) {
    issues.push('Drive Picker requires an explicit true setting and the exact HTTPS frontend origin.')
  }
  if (driveEvidence && driveEvidence!=='false' && (driveEvidence!=='true'||drivePicker!=='true')) {
    issues.push('Drive rendition requires explicit Drive Picker configuration.')
  }
  if (calendarSync && calendarSync!=='false' && (calendarSync!=='true'||!appOrigin)) {
    issues.push('Calendar sync requires an explicit true setting and the exact HTTPS frontend origin.')
  }
  if (telegramBot && (!/^[A-Za-z][A-Za-z0-9_]{1,28}bot$/i.test(telegramBot)||!appOrigin)) {
    issues.push('Telegram requires a bot username and the exact HTTPS frontend origin.')
  }
  if (emailDigest && emailDigest!=='false' && (emailDigest!=='true'||!appOrigin)) {
    issues.push('Email digest requires an explicit true setting and the exact HTTPS frontend origin.')
  }

  if (!supabasePublishableKey) {
    issues.push('VITE_SUPABASE_PUBLISHABLE_KEY is missing.')
  } else if (!/^sb_publishable_[A-Za-z0-9_-]+$/.test(supabasePublishableKey)) {
    issues.push('VITE_SUPABASE_PUBLISHABLE_KEY must be a publishable key, never a secret key.')
  }

  return issues.length
    ? { state: 'not_configured', issues }
    : { state: 'configured', supabaseUrl: new URL(supabaseUrl).origin, supabasePublishableKey,
      ...(appOrigin ? {appOrigin} : {}), ...(drivePicker==='true' ? {drivePicker:true} : {}),
      ...(driveEvidence==='true' ? {driveEvidence:true} : {}), ...(calendarSync==='true' ? {calendarSync:true} : {}),
      ...(telegramBot ? {telegramBot} : {}), ...(emailDigest==='true' ? {emailDigest:true} : {}) }
}
