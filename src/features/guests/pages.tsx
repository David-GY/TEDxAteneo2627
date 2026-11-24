import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Link, useLoaderData, useNavigate, useRouteLoaderData } from 'react-router'
import { PageHeading, Panel } from '../../components/Page'
import { TextField } from '../../components/TextField'
import { isGuest,type AuthGateway,type AuthResult,type WorkspaceContext } from '../auth/gateway'
import { invitationUrl, readInvitationFragment, type GuestGateway, type GuestInvitation, type GuestWork } from './gateway'

export function SharedWork({api}:{api?:GuestGateway}) {
  const context=useRouteLoaderData('workspace') as WorkspaceContext|undefined
  return context&&isGuest(context)&&api?.listShared
    ?<SharedWorkList key={context.termId+':'+context.guestAccessId} api={api} term={context.termId}/>:null
}

function SharedWorkList({api,term}:{api:GuestGateway;term:string}) {
  const [page,setPage]=useState(1)
  const [revision,setRevision]=useState(0)
  const [loaded,setLoaded]=useState<{key:string;work:GuestWork|null}|null>(null)
  const key=term+':'+page+':'+revision
  useEffect(()=>{
    if(!api.listShared)return
    let active=true
    void api.listShared(term,page).then(work=>{if(active)setLoaded({key,work})})
      .catch(()=>{if(active)setLoaded({key,work:null})})
    return()=>{active=false}
  },[api,key,page,term])
  useEffect(()=>{
    const check=()=>{if(document.visibilityState!=='hidden')setRevision(value=>value+1)}
    window.addEventListener('focus',check)
    document.addEventListener('visibilitychange',check)
    return()=>{
      window.removeEventListener('focus',check)
      document.removeEventListener('visibilitychange',check)
    }
  },[])
  const current=loaded?.key===key?loaded:null
  return <Panel title="Shared work">
    {!current?<p role="status">Checking your shared work…</p>:current.work?<>{current.work.items.length?
      <ul className="guest-list">{current.work.items.map(item=><li key={item.id}>
        <Link className="button button--secondary" to={(item.kind==='task'?'/tasks/':'/deliverables/')+item.id}>{item.title}</Link>
      </li>)}</ul>:<p>Your sponsor has not shared any current tasks or deliverables on this page.</p>}
      {page>1||current.work.hasMore?<div className="auth-actions">
        {page>1?<button className="button button--secondary" type="button" onClick={()=>setPage(page-1)}>Previous shared work</button>:null}
        {current.work.hasMore?<button className="button button--secondary" type="button" onClick={()=>setPage(page+1)}>Next shared work</button>:null}
      </div>:null}
    </>:<><p role="alert">Shared work could not be checked. Ask your sponsor if you expected access.</p>
      <button className="button button--secondary" type="button" onClick={()=>setRevision(value=>value+1)}>Check shared work again</button>
    </>}
  </Panel>
}

export function SponsorPage({api}:{api:GuestGateway}) {
  const context=useRouteLoaderData('workspace') as WorkspaceContext
  const [items,setItems]=useState<GuestInvitation[]>([])
  const [email,setEmail]=useState('')
  const [days,setDays]=useState('14')
  const [loading,setLoading]=useState(true)
  const [busy,setBusy]=useState(false)
  const [error,setError]=useState('')
  const [notice,setNotice]=useState('')
  const [link,setLink]=useState('')
  const request=useRef<{key:string;id:string;expiry:string}|null>(null)
  useEffect(()=>{
    let active=true
    void api.list(context.termId).then(rows=>{if(active)setItems(rows)}).catch(()=>{if(active)setError('Invitations could not load. Refresh this page to try again.')}).finally(()=>{if(active)setLoading(false)})
    return ()=>{active=false}
  },[api,context.termId])
  async function mutate(action:()=>Promise<void>) {
    setBusy(true);setError('');setNotice('');setLink('')
    try {await action();setItems(await api.list(context.termId))}
    catch {setError('The change could not be confirmed. Refresh the list and retry. Your account may no longer have access.')}
    finally {setBusy(false)}
  }
  async function create(event?:FormEvent,replaces?:GuestInvitation) {
    event?.preventDefault()
    if(!Number.isInteger(Number(days))||Number(days)<1||Number(days)>14){setError('Choose a whole number of days between 1 and 14.');return}
    const key=JSON.stringify([replaces?.id??'',replaces?.version??0,replaces?.email??email,days])
    if(request.current?.key!==key)request.current={key,id:crypto.randomUUID(),expiry:new Date(Date.now()+Number(days)*86400000).toISOString()}
    const current=request.current
    await mutate(async()=>{
      const result=await api.create(context.termId,replaces?.email??email,current.id,current.expiry,replaces)
      if(result.token)setLink(invitationUrl(window.location.origin,result.token))
      setNotice(result.token ? 'Invitation created. Copy the link now; it cannot be shown again after leaving this page.' : 'This request already succeeded. Its link cannot be recovered. Renew that invitation to issue a new link.')
      request.current=null
    })
  }
  return <>
    <PageHeading title="Guest invitations" description="Manage only the invitations you sponsor. Access requires your current term access-administrator grant." />
    <Panel title="Invite a guest">
      <p><strong>Scope preview: zero shared records.</strong> New invitations begin with no records. Each work record needs a separate sharing action. This invitation grants no full member directory, committee or organization-wide access.</p>
      <form className="guest-form" onSubmit={event=>void create(event)}>
        <TextField id="guest-email" label="Guest Google email" type="email" required value={email} autoComplete="off" onChange={event=>setEmail(event.target.value)} hint="Use the exact email the guest will sign in with. External Google accounts are supported." />
        <TextField id="guest-days" label="Access duration in days" type="number" min="1" max="14" required value={days} onChange={event=>setDays(event.target.value)} hint="Default 14 days; renewal replaces the old link and requires redemption again." />
        <button className="button" disabled={busy||loading}>Create invitation link</button>
      </form>
      <p className="muted">No email is sent. Share the copied link yourself. The guest must use the bound Google account.</p>
    </Panel>
    {error?<p role="alert">{error}</p>:null}
    {notice?<p role="status">{notice}</p>:null}
    {link?<Panel title="Copy this invitation now"><div className="guest-link-copy"><p>The link remains only in this page’s memory.</p><button className="button" onClick={()=>void navigator.clipboard.writeText(link).then(()=>setNotice('Invitation link copied.')).catch(()=>setError('Clipboard access failed. Use the selectable invitation link below.'))}>Copy invitation link</button><TextField id="invite-link" label="Invitation link" value={link} readOnly onFocus={event=>event.target.select()} /><button className="button button--secondary" onClick={()=>setLink('')}>Hide invitation link</button></div></Panel>:null}
    <Panel title="Your invitations">
      <p>Check whether a guest has accepted, or when their access ends.</p>
      {loading?<p role="status">Loading invitations…</p>:items.length===0?<p>No invitations are available.</p>:<ul className="guest-list">{items.map(item=><li key={item.id}>
        <h3>{item.email}</h3><p>{item.revokedAt?'Revoked':Date.parse(item.expiresAt)<=Date.now()?'Expired':item.redeemedAt?'Redeemed':'Awaiting redemption'} · Ends {new Date(item.expiresAt).toLocaleString('en-PH',{timeZone:'Asia/Manila'})} (Manila)</p>
        <p className="muted">{item.scopeMode === 'explicit_records' ? `${item.sharedRecordCount === undefined ? 'Explicitly shared' : item.sharedRecordCount + ' explicitly shared'} work records; no full directory access.` : 'Zero shared records; no directory access.'}</p>
        {!item.revokedAt?<div className="auth-actions"><button className="button button--secondary" disabled={busy} onClick={()=>void create(undefined,item)}>Renew invitation for {item.email}</button><button className="button button--secondary" disabled={busy} onClick={()=>void mutate(async()=>{await api.revoke(item,crypto.randomUUID());setNotice('Guest access revoked. Current sessions can no longer use this invitation.')} )}>Revoke access for {item.email}</button></div>:null}
      </li>)}</ul>}
    </Panel>
  </>
}

export function RedeemPage({gateway}:{gateway:AuthGateway}) {
  const auth=useLoaderData() as AuthResult
  // Lazy state survives StrictMode replay; never persist the bearer through an OAuth redirect.
  const [token]=useState(()=>readInvitationFragment(window.location.hash))
  const [busy,setBusy]=useState(false)
  const [error,setError]=useState('')
  const [otherShared,setOtherShared]=useState(()=>auth.state==='authorized'&&isGuest(auth))
  const navigate=useNavigate()
  useEffect(()=>{window.history.replaceState(window.history.state,'','/guest/redeem')},[])
  async function redeem() {
    if(!token||!gateway.guests)return
    setBusy(true);setError('')
    try {await gateway.guests.redeem(token);await navigate('/shared',{replace:true})}
    catch {
      setError('This invitation could not be accepted. Check that you used the Google account your sponsor invited. If the link has expired or was already used, ask your sponsor to check your access or send a fresh link.')
      const current=await gateway.readContext().catch(()=>null)
      setOtherShared(current?.state==='authorized'&&isGuest(current))
      setBusy(false)
    }
  }
  async function signIn() {
    setBusy(true);setError('')
    try {await gateway.signOut();await gateway.beginGoogle('/guest/redeem')}
    catch {setError('Google sign-in could not start. Try again, or ask your sponsor for help if it stays unavailable.');setBusy(false)}
  }
  return <main className="standalone-page auth-page">
    <h1>Accept your guest invitation</h1>
    <p>Use the Google account your sponsor invited. It can be an account outside the school.</p>
    <Panel title="What guest access covers"><p>You can open only the work your sponsor has shared with you and only until your invitation expires.</p></Panel>
    <p>After signing in, reopen the original invitation link and accept it here. Ask your sponsor for a fresh link if you no longer have it.</p>
    {auth.state==='unavailable'?<p role="status">Google sign-in is unavailable right now. Ask your sponsor for help.</p>:null}
    {error?<p role="alert">{error}</p>:null}
    <div className="auth-actions">
      {token?<button className="button" disabled={busy||!gateway.guests||['unavailable','signed_out','error'].includes(auth.state)}
        onClick={()=>void redeem()}>Accept invitation with signed-in account</button>:null}
      <button className="button button--secondary" disabled={busy||auth.state==='unavailable'} onClick={()=>void signIn()}>Sign in or switch Google account</button>
      {otherShared?<Link className="button button--secondary" to="/shared">Open work already shared with you</Link>:null}
    </div>
    <p>Email sign-in is currently unavailable. If you cannot use the invited Google account, ask your sponsor for help.</p>
    <Link className="button button--secondary" to="/login">Return to sign-in</Link>
  </main>
}
