import {parseTimelineQuery,timelineSearch} from '../timeline/filters'
import { navigationItems } from '../../app/navigation'

export const authOrigins = ['http://127.0.0.1:5173', 'http://127.0.0.1:4173'] as const
const hasControl = (value: string) => Array.from(value).some((char) => char.charCodeAt(0) <= 32 || char.charCodeAt(0) === 127)
export const isDeliverablePath = (path: string) => /^\/deliverables\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(path)
export const isTaskPath = (path: string) => /^\/tasks\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(path)
export const isHandoffPath=(path:string)=>/^\/working-together\/handoffs(?:\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})?$/i.test(path)
export const isAgreementPath = (path: string) => /^\/working-together\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(path)
export function callbackUrl(origin: string): string | null {
  return authOrigins.some((allowed) => allowed === origin) ? `${origin}/auth/callback` : null
}

export function safeReturnPath(value: string | null): string {
  if(value?.startsWith('/working-together/timeline?')&&!/[\\#]/.test(value)&&!hasControl(value))return '/working-together/timeline'+timelineSearch(parseTimelineQuery(value.slice(value.indexOf('?'))))
  if(value==='/working-together/timeline')return value
  if (!value?.startsWith('/') || value.startsWith('//') || /[\\%]/.test(value) || hasControl(value)) return '/'
  const path = value.split(/[?#]/, 1)[0]
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  const requestParts=path.split('/'),requestPath=requestParts.length===4&&requestParts[1]==='requests'&&uuid.test(requestParts[2])&&uuid.test(requestParts[3])
  if(path==='/search'||path==='/people'||path==='/resources'||isTaskPath(path)||isDeliverablePath(path)||requestPath){
    const input=new URLSearchParams(value.split('?')[1]?.split('#')[0]),kept=new URLSearchParams()
    const focus=path==='/resources'?'resource':path==='/people'?'contact':null
    if(focus&&input.getAll(focus).length===1&&uuid.test(input.get(focus)!))kept.set(focus,input.get(focus)!)
    if(input.getAll('term').length===1&&uuid.test(input.get('term')!))kept.set('term',input.get('term')!)
    return path+(kept.size?'?'+kept.toString():'')
  }
  return /^\/publicity\/[0-9a-f-]{36}\/[0-9a-f-]{36}$/i.test(path) || path === '/reviews' || /^\/finance\/reviews\/[0-9a-f-]{36}\/[0-9a-f-]{36}$/i.test(path) || /^\/finance\/[0-9a-f-]{36}\/[0-9a-f-]{36}$/i.test(path) || /^\/reviews\/[0-9a-f-]{36}\/[0-9a-f-]{36}$/i.test(path) || path === '/guest/redeem' || isDeliverablePath(path) || isTaskPath(path) || isAgreementPath(path) || isHandoffPath(path) || navigationItems.some((item) => item.href === path) ? path : '/'
}

export function readCallback(search: string): string | null {
  const params = new URLSearchParams(search)
  if (params.has('error') || params.has('error_description') || params.getAll('code').length !== 1) return null
  const code = params.get('code')
  return code && code.length <= 2048 && !/\s/.test(code) && !hasControl(code) ? code : null
}
