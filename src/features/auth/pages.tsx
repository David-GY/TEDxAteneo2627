import {SiteLogo} from '../admin/site/SiteLogo'
import {SiteEditMode} from '../admin/site/SiteEditMode'
import {usePublishedSite} from '../admin/site/usePublishedSite'
import {CurrentRecordScope} from './RecordScope'
import {EditSafety} from '../../components/EditSafety'
import {NotificationCenter} from '../notifications/Notifications'
import type {NotificationsApi} from '../notifications/api'
import {FinDecisionMemory} from '../finance/DecisionMemory'
import {FinanceMemory} from '../finance/Memory'
import {ReviewMemory} from '../approvals/Memory'
import {RequestMemory} from '../requests/Memory'
import {FormDrafts} from '../forms/Drafts'
import {HandoffDrafts} from '../handoffs/Drafts'
import { useEffect, useRef, useState } from 'react'
import { Link, Outlet, useLoaderData, useLocation, useNavigate, useRevalidator, useRouteLoaderData } from 'react-router'
import { ProfileEditor } from '../account/ProfileEditor'
import { GuestContactEditor } from '../account/GuestContactEditor'
import { LoadingState } from '../../components/FeedbackState'
import { AppShell } from '../../app/AppShell'
import { InstallWorkspace } from '../../app/InstallWorkspace'
import { DriveConnection } from '../integrations/drive/DriveSource'
import type { NavigationCapability } from '../../app/navigation'
import type { AuthGateway, AuthResult, WorkspaceContext } from './gateway'
import { consumeReturnPath, isGuest } from './gateway'
import { readCallback, safeReturnPath } from './redirects'
import {ScheduleDrafts} from '../timeline/ScheduleDrafts'

export function AuthRevalidator({ gateway }: { gateway: AuthGateway }) {
  const { revalidate, state } = useRevalidator()
  const location = useLocation()
  const workspace=useRouteLoaderData('workspace') as WorkspaceContext|undefined
  const [offline, setOffline] = useState(() => !navigator.onLine)
  const [signingOut, setSigningOut] = useState(false)
  const [offlineError, setOfflineError] = useState('')
  const offlineHeading = useRef<HTMLHeadingElement>(null)
  const draftIdentity=workspace?JSON.stringify([workspace.termId,isGuest(workspace)?'guest:'+workspace.guestAccessId:'core:'+workspace.memberId,[...(workspace.capabilities??[])].sort()]):'signed-out'
  useEffect(() => { if (offline) offlineHeading.current?.focus() }, [offline])
  useEffect(() => {
    const refresh = () => { if (document.visibilityState === 'visible' && window.location.pathname !== '/auth/callback') void revalidate() }
    const stop = gateway.onChange(refresh)
    window.addEventListener('focus', refresh)
    document.addEventListener('visibilitychange', refresh)
    const timer = window.setInterval(refresh, 30_000)
    return () => { stop(); clearInterval(timer); window.removeEventListener('focus', refresh); document.removeEventListener('visibilitychange', refresh) }
  }, [gateway, revalidate])
  useEffect(() => {
    const disconnected = () => setOffline(true)
    const reconnected = () => { void revalidate().then(() => setOffline(!navigator.onLine)) }
    const hide = () => { document.documentElement.classList.add('leaving-workspace') }
    const restore = (event: PageTransitionEvent) => { if (event.persisted) window.location.reload() }
    window.addEventListener('offline', disconnected)
    window.addEventListener('online', reconnected)
    window.addEventListener('pagehide', hide)
    window.addEventListener('pageshow', restore)
    return () => {
      window.removeEventListener('offline', disconnected)
      window.removeEventListener('online', reconnected)
      window.removeEventListener('pagehide', hide)
      window.removeEventListener('pageshow', restore)
    }
  }, [revalidate])

  async function leaveOffline() {
    setSigningOut(true)
    setOfflineError('')
    try {
      await gateway.signOut()
      window.location.replace('/login')
    } catch {
      setSigningOut(false)
      setOfflineError('Sign-out could not be confirmed. Reconnect and try again.')
    }
  }

  return <FinDecisionMemory identity={draftIdentity}><FinanceMemory identity={draftIdentity}><ReviewMemory identity={draftIdentity}><RequestMemory identity={draftIdentity}><FormDrafts identity={draftIdentity}><ScheduleDrafts identity={draftIdentity}><HandoffDrafts identity={draftIdentity}><EditSafety key={draftIdentity}>
    {offline?<main className="standalone-page"><h1 ref={offlineHeading} tabIndex={-1}>You’re offline</h1><p role="status">Reconnect to check your current access and resume work. If you tried to save just before the connection dropped, check the result before trying again.</p>{workspace?<button className="button button--secondary" disabled={signingOut} onClick={()=>void leaveOffline()}>Sign out of this browser</button>:null}{offlineError?<p role="alert">{offlineError}</p>:null}</main>:null}
    {!offline&&state==='loading'&&workspace?<p role="status">Checking current access. Your edits stay here while actions are paused.</p>:null}
    <div hidden={offline} inert={offline||state==='loading'&&!!workspace}>{state === 'loading' && !workspace && location.pathname !== '/auth/callback' ? <main className="standalone-page"><LoadingState /></main> : <Outlet />}</div>
  </EditSafety></HandoffDrafts></ScheduleDrafts></FormDrafts></RequestMemory></ReviewMemory></FinanceMemory></FinDecisionMemory>
}

export function ProtectedShell({notifications,gateway}:{notifications?:NotificationsApi;gateway?:AuthGateway}) {
  const member = useLoaderData() as WorkspaceContext
  const[siteEpoch,setSiteEpoch]=useState(0)
  const { revalidate,state } = useRevalidator()
  const siteScope=JSON.stringify([member.organizationId,member.termId,isGuest(member)?'guest:'+member.guestAccessId:'core:'+member.memberId,[...member.capabilities].sort()])
  const site=usePublishedSite(gateway?.site,member.termId,siteScope,state,member,siteEpoch)
  useEffect(() => {
    const timer = window.setTimeout(() => void revalidate(), Math.min(2_147_483_647, Math.max(0, Date.parse(member.expiresAt) - Date.now())))
    return () => clearTimeout(timer)
  }, [member.expiresAt, revalidate])
  return <NotificationCenter api={notifications} term={member.termId} identity={'memberId'in member?member.memberId:member.guestAccessId}><AppShell context={{ audience: isGuest(member) ? 'guest' : 'core', capabilities: member.capabilities as NavigationCapability[] }} identity={{ displayName: member.displayName }} preview={false} sitePresentation={site.presentation} siteUnavailable={site.unavailable} siteLogo={gateway?.site&&site.presentation?.logo?<SiteLogo api={gateway.site} term={member.termId} scope={siteScope} asset={site.presentation.logo.assetId} approval={site.presentation.logo.approvalId}/>:undefined} siteEditor={gateway?.siteWording?<SiteEditMode api={gateway.siteWording} context={member} onPublished={()=>setSiteEpoch(n=>n+1)}/>:undefined} content={gateway?<CurrentRecordScope gateway={gateway}><Outlet /></CurrentRecordScope>:undefined} /></NotificationCenter>
}

export function LoginPage({ gateway }: { gateway: AuthGateway }) {
  const result = useLoaderData() as AuthResult
  const location = useLocation()
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const denied = result.state === 'denied' || new URLSearchParams(location.search).get('reason') === 'denied'
  const returnTo=safeReturnPath(new URLSearchParams(location.search).get('returnTo'))
  const guestEntry=returnTo==='/shared'||returnTo==='/guest/redeem'
  async function start(switchAccount = false) {
    setBusy(true); setError('')
    try {
      if (switchAccount) await gateway.signOut()
      await gateway.beginGoogle(returnTo)
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Sign-in could not start.'); setBusy(false) }
  }
  return <main className="standalone-page auth-page">
    <p className="muted">TEDx Ateneo de Manila U · Core workspace</p>
    <h1>Sign in to your workspace</h1>
    {new URLSearchParams(safeReturnPath(new URLSearchParams(location.search).get('returnTo')).split('?')[1]).has('term')?<p>The selected term could not be opened. You can <Link to="/search">return to current workspace search</Link> or retry sign-in for the selected term below.</p>:null}
    {guestEntry?<p>Use the Google account your guest sponsor invited. If your access has expired, ask your sponsor for a fresh link.</p>:
      <p>Use your approved <strong>student.ateneo.edu</strong> Google account. A school email alone does not grant access.</p>}
    {new URLSearchParams(location.search).get('reason') === 'check' ? <p>Your session needs a current access check. Sign in again if it has expired.</p> : null}
    {result.state === 'unavailable' ? <section className="feedback-state"><h2>Setup needed</h2><p>Sign-in is unavailable until Supabase and Google login are configured for this address. No member records are being loaded.</p></section> : <>
      {denied ? <p role="alert">{guestEntry?'Guest access could not be confirmed. Check the invited Google account or ask your sponsor for help.':
        'This account does not have active core access. Use another account or contact the roster custodian.'}</p> : null}
      {result.state === 'error' ? <p role="alert">Access could not be checked. Please retry when the service is available.</p> : null}
      <button className="button" disabled={busy} onClick={() => void start(denied)}>{busy ? 'Opening Google…' : denied ? 'Use another Google account' : 'Continue with Google'}</button>
    </>}
    {error ? <p className="field-error" role="alert">{error}</p> : null}
    <p className="muted">Invited guests may use an external Google account. Open the invitation link from your sponsor to continue.</p>
    {import.meta.env.DEV ? <Link className="button button--secondary" to="/preview">View development shell preview</Link> : null}
  </main>
}

export function CallbackPage({ gateway }: { gateway: AuthGateway }) {
  const location = useLocation()
  const navigate = useNavigate()
  const [failed, setFailed] = useState(false)
  const [retryPath,setRetryPath]=useState('/')
  const recovered=useRef<string|null>(null)
  useEffect(() => {
    let active = true
    const code = readCallback(location.search)
    window.history.replaceState(window.history.state, '', '/auth/callback')
    const fail=()=>{
      if(!active)return
      recovered.current??=consumeReturnPath()
      setRetryPath(recovered.current)
      setFailed(true)
    }
    if (!code) { fail(); return }
    void gateway.exchange(code).then(() => { if (active) void navigate(consumeReturnPath(), { replace: true }) }).catch(fail)
    return () => { active = false }
  }, [gateway, location.search, navigate])
  return <main className="standalone-page">{failed ? <><h1>Sign-in could not be completed</h1><p>Google sign-in may have been declined or expired. Try again. Guests can ask their sponsor for help.</p>
    <Link className="button" to={retryPath==='/'?'/login':'/login?returnTo='+encodeURIComponent(retryPath)}>Start sign-in again</Link></> : <LoadingState />}</main>
}

export function AccountPage({ gateway }: { gateway: AuthGateway }) {
  const context = useRouteLoaderData('workspace') as WorkspaceContext | undefined
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  async function leave(switchAccount: boolean) {
    setBusy(true); setError('')
    try { await gateway.signOut(); if (switchAccount) await gateway.beginGoogle('/'); else window.location.replace('/login') }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Sign-out could not be confirmed.'); setBusy(false) }
  }
  return <><h1>Your account</h1><p>{context && isGuest(context) ? 'Access follows your current invitation and its expiry.' : 'Access follows your current roster membership and scoped grants.'}</p><div className="auth-actions">
    <button className="button" disabled={busy} onClick={() => void leave(false)}>Sign out of this browser</button>
    <button className="button button--secondary" disabled={busy} onClick={() => void leave(true)}>Switch Google account</button>
  </div>{error ? <p role="alert">{error}</p> : null}
  <p><Link className="button button--secondary" to="/privacy">Privacy notice and requests</Link></p>
  <InstallWorkspace />
  {context && !isGuest(context) && gateway.files?.drive ? <DriveConnection key={context.memberId+context.termId} api={gateway.files.drive} term={context.termId} /> : null}
  {context && !isGuest(context) && gateway.profile ? <ProfileEditor key={context.memberId + context.termId} api={gateway.profile} termId={context.termId} /> : null}
  {context && isGuest(context) && gateway.guestContacts ? <GuestContactEditor key={context.guestAccessId} api={gateway.guestContacts} termId={context.termId} /> : null}</>
}
