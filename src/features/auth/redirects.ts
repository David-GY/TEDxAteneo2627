import { navigationItems } from '../../app/navigation'

export const authOrigins = ['http://127.0.0.1:5173', 'http://127.0.0.1:4173'] as const
const hasControl = (value: string) => Array.from(value).some((char) => char.charCodeAt(0) <= 32 || char.charCodeAt(0) === 127)
export function callbackUrl(origin: string): string | null {
  return authOrigins.some((allowed) => allowed === origin) ? `${origin}/auth/callback` : null
}

export function safeReturnPath(value: string | null): string {
  if (!value?.startsWith('/') || value.startsWith('//') || /[\\%]/.test(value) || hasControl(value)) return '/'
  const path = value.split(/[?#]/, 1)[0]
  return navigationItems.some((item) => item.href === path && item.id !== 'shared') ? path : '/'
}

export function readCallback(search: string): string | null {
  const params = new URLSearchParams(search)
  if (params.has('error') || params.has('error_description') || params.getAll('code').length !== 1) return null
  const code = params.get('code')
  return code && code.length <= 2048 && !/\s/.test(code) && !hasControl(code) ? code : null
}
