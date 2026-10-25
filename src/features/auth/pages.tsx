import {FinanceMemory} from '../finance/Memory'
import {ReviewMemory} from '../approvals/Memory'
import {RequestMemory} from '../requests/Memory'
import {FormDrafts} from '../forms/Drafts'
import {HandoffDrafts} from '../handoffs/Drafts'
import { useEffect, useState } from 'react'
import { Link, Outlet, useLoaderData, useLocation, useNavigate, useRevalidator, useRouteLoaderData } from 'react-router'
import { ProfileEditor } from '../account/ProfileEditor'
import { GuestContactEditor } from '../account/GuestContactEditor'
import { LoadingState } from '../../components/FeedbackState'
import { AppShell } from '../../app/AppShell'
import type { NavigationCapability } from '../../app/navigation'
import type { AuthGateway, AuthResult, WorkspaceContext } from './gateway'
import { consumeReturnPath, isGuest } from './gateway'
import { readCallback, safeReturnPath } from './redirects'
import {ScheduleDrafts} from '../timeline/ScheduleDrafts'

export function AuthRevalidator({ gateway }: { gateway: AuthGateway }) {
  const { revalidate, state } = useRevalidator()
  const location = useLocation()
  const workspace=useRouteLoaderData('workspace') as WorkspaceContext|undefined
  const draftIdentity=workspace?workspace.termId+':'+(isGuest(workspace)?'guest:'+workspace.guestAccessId:'core:'+workspace.memberId):'signed-out'
  useEffect(() => {
    const refresh = () => { if (document.visibilityState === 'visible' && window.location.pathname !== '/auth/callback') void revalidate() }
    const stop = gateway.onChange(refresh)
    window.addEventListener('focus', refresh)
    document.addEventListener('visibilitychange', refresh)
    const timer = window.setInterval(refresh, 30_000)
    return () => { stop(); clearInterval(timer); window.removeEventListener('focus', refresh); document.removeEventListener('visibilitychange', refresh) }
  }, [gateway, revalidate])
  return <FinanceMemory identity={draftIdentity}><ReviewMemory identity={draftIdentity}><RequestMemory identity={draftIdentity}><FormDrafts identity={draftIdentity}><ScheduleDrafts identity={draftIdentity}><HandoffDrafts identity={draftIdentity}>{state === 'loading' && location.pathname !== '/auth/callback' ? <main className="standalone-page"><LoadingState /></main> : <Outlet />}</HandoffDrafts></ScheduleDrafts></FormDrafts></RequestMemory></ReviewMemory></FinanceMemory>
}

export function ProtectedShell() {
  const member = useLoaderData() as WorkspaceContext
  const { revalidate } = useRevalidator()
  useEffect(() => {
    const timer = window.setTimeout(() => void revalidate(), Math.min(2_147_483_647, Math.max(0, Date.parse(member.expiresAt) - Date.now())))
    return () => clearTimeout(timer)
  }, [member.expiresAt, revalidate])
  return <AppShell context={{ audience: isGuest(member) ? 'guest' : 'core', capabilities: member.capabilities as NavigationCapability[] }} identity={{ displayName: member.displayName }} preview={false} />
}

export function LoginPage({ gateway }: { gateway: AuthGateway }) {
  const result = useLoaderData() as AuthResult
  const location = useLocation()
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const denied = result.state === 'denied' || new URLSearchParams(location.search).get('reason') === 'denied'
  async function start(switchAccount = false) {
    setBusy(true); setError('')
    try {
      if (switchAccount) await gateway.signOut()
      await gateway.beginGoogle(safeReturnPath(new URLSearchParams(location.search).get('returnTo')))
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Sign-in could not start.'); setBusy(false) }
  }
  return <main className="standalone-page auth-page">
    <p className="muted">TEDx Ateneo de Manila U · Core workspace</p>
    <h1>Sign in to your workspace</h1>
    <p>Use your approved <strong>student.ateneo.edu</strong> Google account. A school email alone does not grant access.</p>
    {new URLSearchParams(location.search).get('reason') === 'check' ? <p>Your session needs a current access check. Sign in again if it has expired.</p> : null}
    {result.state === 'unavailable' ? <section className="feedback-state"><h2>Setup needed</h2><p>Sign-in is unavailable until Supabase and Google login are configured for this address. No member records are being loaded.</p></section> : <>
      {denied ? <p role="alert">This account does not have active core access. Use another account or contact the roster custodian.</p> : null}
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
  useEffect(() => {
    let active = true
    const code = readCallback(location.search)
    window.history.replaceState(window.history.state, '', '/auth/callback')
    if (!code) { setFailed(true); return }
    void gateway.exchange(code).then(() => { if (active) void navigate(consumeReturnPath(), { replace: true }) }).catch(() => { if (active) { consumeReturnPath(); setFailed(true) } })
    return () => { active = false }
  }, [gateway, location.search, navigate])
  return <main className="standalone-page">{failed ? <><h1>Sign-in could not be completed</h1><p>Google may have rejected access, or the sign-in link expired. Start again or check with your school administrator.</p><Link className="button" to="/login">Start sign-in again</Link></> : <LoadingState />}</main>
}

export function AccountPage({ gateway }: { gateway: AuthGateway }) {
  const context = useRouteLoaderData('workspace') as WorkspaceContext | undefined
  const navigate = useNavigate()
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  async function leave(switchAccount: boolean) {
    setBusy(true); setError('')
    try { await gateway.signOut(); if (switchAccount) await gateway.beginGoogle('/'); else await navigate('/login', { replace: true }) }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Sign-out could not be confirmed.'); setBusy(false) }
  }
  return <><h1>Your account</h1><p>{context && isGuest(context) ? 'Access follows your current invitation and its expiry.' : 'Access follows your current roster membership and scoped grants.'}</p><div className="auth-actions">
    <button className="button" disabled={busy} onClick={() => void leave(false)}>Sign out of this browser</button>
    <button className="button button--secondary" disabled={busy} onClick={() => void leave(true)}>Switch Google account</button>
  </div>{error ? <p role="alert">{error}</p> : null}
  {context && !isGuest(context) && gateway.profile ? <ProfileEditor key={context.memberId + context.termId} api={gateway.profile} termId={context.termId} /> : null}
  {context && isGuest(context) && gateway.guestContacts ? <GuestContactEditor key={context.guestAccessId} api={gateway.guestContacts} termId={context.termId} /> : null}</>
}
