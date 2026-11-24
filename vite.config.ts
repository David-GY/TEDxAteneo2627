import react from '@vitejs/plugin-react'
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { loadEnv } from 'vite'
import { defineConfig } from 'vite'
import { readClientEnvironment } from './src/lib/env.ts'

export default defineConfig(({ command, mode }) => {
  const values = loadEnv(mode, process.cwd(), 'VITE_')
  const input = {
    VITE_SUPABASE_URL: values.VITE_SUPABASE_URL,
    VITE_SUPABASE_PUBLISHABLE_KEY: values.VITE_SUPABASE_PUBLISHABLE_KEY,
    VITE_APP_ORIGIN: values.VITE_APP_ORIGIN,
    VITE_DRIVE_PICKER_ENABLED: values.VITE_DRIVE_PICKER_ENABLED,
    VITE_DRIVE_EVIDENCE_ENABLED: values.VITE_DRIVE_EVIDENCE_ENABLED,
    VITE_CALENDAR_SYNC_ENABLED: values.VITE_CALENDAR_SYNC_ENABLED,
    VITE_TELEGRAM_BOT_USERNAME: values.VITE_TELEGRAM_BOT_USERNAME,
    VITE_EMAIL_DIGEST_ENABLED: values.VITE_EMAIL_DIGEST_ENABLED,
  }
  const hasSettings = !!(input.VITE_SUPABASE_URL?.trim() || input.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()
    || input.VITE_APP_ORIGIN?.trim() || input.VITE_TELEGRAM_BOT_USERNAME?.trim()
    || [input.VITE_DRIVE_PICKER_ENABLED,input.VITE_DRIVE_EVIDENCE_ENABLED,input.VITE_CALENDAR_SYNC_ENABLED,input.VITE_EMAIL_DIGEST_ENABLED]
      .some(setting=>setting?.trim() && setting.trim()!=='false'))
  const environment = readClientEnvironment(input)
  // Client-side rejection is too late: VITE_ values can already be in the bundle.
  if (command === 'build') {
    if (Object.keys(values).some(key => !Object.hasOwn(input,key))) {
      throw new Error('Unexpected VITE_ setting. Only documented public settings are allowed in a build.')
    }
    if (hasSettings && environment.state !== 'configured') {
      throw new Error('Invalid public configuration. Supply the documented origins and publishable key, or leave the settings blank.')
    }
    if (mode === 'pages' && (environment.state !== 'configured' || !environment.appOrigin)) {
      throw new Error('A Pages build requires the exact HTTPS frontend origin and its Supabase project settings.')
    }
  }

  const offlineDocument = readFileSync(new URL('./public/offline/index.html', import.meta.url), 'utf8')
  const offlineStyle = offlineDocument.match(/<style>([\s\S]*?)<\/style>/)?.[1]?.replace(/\r\n?/g, '\n')
  if (!offlineStyle) throw new Error('The offline document must include its standalone stylesheet.')
  const offlineHash = createHash('sha256').update(offlineStyle).digest('base64')
  const apiOrigin = environment.state === 'configured' ? ` ${environment.supabaseUrl}` : ''
  const picker = environment.state==='configured' && environment.drivePicker
  const headers = {
    'Content-Security-Policy': [
      "default-src 'none'", "base-uri 'none'", "frame-ancestors 'none'", "form-action 'self'",
      picker ? "script-src 'self' https://apis.google.com" : "script-src 'self'",
      ...(picker ? ["frame-src https://docs.google.com https://drive.google.com"] : []),
      `style-src 'self' 'sha256-${offlineHash}'`, "img-src 'self' blob:",
      "font-src 'self'", `connect-src 'self'${apiOrigin}`, "manifest-src 'self'", "worker-src 'self'",
    ].join('; '),
    'Cache-Control': 'no-store',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-Robots-Tag': 'noindex, nofollow, noarchive',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  }

  return {
    plugins: [react(), {
      name: 'workspace-pages-headers',
      apply: 'build',
      generateBundle() {
        const source = '/*\n' + Object.entries(headers).map(([name,value]) => `  ${name}: ${value}\n`).join('')
        this.emitFile({ type: 'asset', fileName: '_headers', source })
      },
    }],
    preview: { headers },
  }
})
