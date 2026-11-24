import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router'
import { type DriveApi, type DriveState, DriveUiError, takeDriveConsentTerm } from './api'

const messages: Record<string,string> = {
  denied:'Drive access was declined or blocked. You can still paste a working link or upload a private file.',
  reconnect:'Connect Drive again to continue. You can also paste a working link or upload a private file.',
  file_unavailable:'Google could not verify access to that file. Choose another file or ask its custodian for access.',
  stale:'The work or selection changed. Reload the files before choosing again.',
  unavailable:'Drive is temporarily unavailable. Your other file options are still available.',
}

function driveMessage(error: unknown) {
  return error instanceof DriveUiError ? messages[error.code]??messages.unavailable : messages.unavailable
}

export function DriveSource({api,term,work,version,onSaved}: {
  api: DriveApi; term: string; work: string; version: number; onSaved: ()=>void
}) {
  const [busy,setBusy]=useState(false)
  const [notice,setNotice]=useState('')
  const [error,setError]=useState('')
  const [manage,setManage]=useState(false)
  const [retry,setRetry]=useState<string|null>(null)
  const operation=useRef<AbortController|null>(null)
  useEffect(()=>()=>operation.current?.abort(),[])

  async function run(checked?: string) {
    if (operation.current) return
    const active=new AbortController()
    operation.current=active
    setBusy(true);setError('');setNotice('');setManage(false)
    try {
      const selection=checked??(await api.select(term,work,version,active.signal))?.selection
      if (active.signal.aborted || !selection) return
      setRetry(selection)
      const saved=await api.attach(term,work,selection)
      if (active.signal.aborted) return
      setRetry(null);setNotice('Working source saved · '+saved.name);onSaved()
    } catch (cause) {
      if (active.signal.aborted) return
      const code=cause instanceof DriveUiError?cause.code:'unavailable'
      if (code!=='unavailable') setRetry(null)
      setManage(code==='reconnect' || code==='denied')
      setError(driveMessage(cause))
    } finally {
      operation.current=null
      if (!active.signal.aborted) setBusy(false)
    }
  }

  return <div>
    <button type="button" className="button button--secondary" disabled={busy||!!retry} onClick={()=>void run()}>Choose a Drive working source</button>
    {busy?<p role="status">Checking the Drive source…</p>:null}
    {notice?<p role="status">{notice}</p>:null}
    {error?<p role="alert">{error}</p>:null}
    {retry&&!busy?<div className="auth-actions"><button className="button" type="button" onClick={()=>void run(retry)}>Retry saving this source</button>
      <button className="button button--secondary" type="button" onClick={()=>{setRetry(null);setError('')}}>Clear Drive selection</button></div>:null}
    {manage?<Link to={'/account?term='+encodeURIComponent(term)+'#drive-connection'}>Manage your Drive connection</Link>:null}
  </div>
}

const states: Record<DriveState,string> = {
  disconnected:'No Drive consent is stored for this term.',
  awaiting_consent:'Waiting for Google consent. You can start again.',
  consent_saved:'Drive consent is saved. Google checks access again when you choose a file.',
  revocation_pending:'Drive use is paused in this workspace. Retry disconnecting to finish revocation at Google.',
}

export function DriveConnection({api,term}: {api: DriveApi; term: string}) {
  const [state,setState]=useState<DriveState>()
  const [busy,setBusy]=useState(false)
  const [error,setError]=useState('')

  async function refresh() {
    setBusy(true);setError('')
    try {setState(await api.status(term))}
    catch(cause){setError(driveMessage(cause));setState(undefined)}
    finally {setBusy(false)}
  }

  async function start() {
    const tab=window.open('about:blank','_blank')
    if (!tab) {setError('Allow a new tab to open Google consent, then try again.');return}
    setBusy(true);setError('')
    try {await api.connect(term,tab);setState('awaiting_consent')}
    catch(cause){tab.close();setError(driveMessage(cause))}
    finally{setBusy(false)}
  }

  async function disconnect() {
    setBusy(true);setError('')
    try {await api.disconnect(term);setState('disconnected')}
    catch(cause){setState(await api.status(term).catch(()=>undefined));setError(driveMessage(cause))}
    finally{setBusy(false)}
  }

  return <details className="work-section" id="drive-connection" open={window.location.hash==='#drive-connection'||undefined}
    onToggle={event=>{if(event.currentTarget.open&&!busy&&!state) void refresh()}}>
    <summary>Optional Google Drive connection</summary>
    <p>Connect separately from workspace sign-in. You choose individual files. Google controls who can open them. Working links and private uploads are also available.</p>
    {state?<p role="status">{states[state]}</p>:null}
    {error?<p role="alert">{error}</p>:null}
    <div className="auth-actions">
      {state!=='consent_saved'&&state!=='revocation_pending'?<button type="button" className="button" disabled={busy} onClick={()=>void start()}>Connect Drive in a new tab</button>:null}
      {state==='consent_saved'||state==='revocation_pending'?<button type="button" className="button" disabled={busy} onClick={()=>void disconnect()}>Disconnect Drive</button>:null}
      <button type="button" className="button button--secondary" disabled={busy} onClick={()=>void refresh()}>Check Drive connection</button>
    </div>
  </details>
}

export function DriveCallback({api}: {api: DriveApi}) {
  const [result,setResult]=useState('')
  const attempt=useRef<Promise<void>|null>(null)
  useEffect(()=>{
    if (!attempt.current) {
      attempt.current=(async()=>{
        const params=new URLSearchParams(location.search)
        history.replaceState(history.state,'',location.pathname)
        const term=takeDriveConsentTerm(),state=params.get('state')
        if (!term || !state || params.getAll('state').length!==1) throw new DriveUiError('stale')
        await api.finish(term,state,params.get('code'),params.get('error'))
      })()
    }
    let live=true
    void attempt.current.then(
      ()=>{if(live)setResult('Drive consent saved. Return to the workspace tab to choose a file.')},
      error=>{if(live)setResult(error instanceof DriveUiError&&error.code==='stale'
        ?'This connection attempt ended. Return to the workspace tab to start again.':driveMessage(error))},
    )
    return ()=>{live=false}
  },[api])
  return <main className="standalone-page">
    <h1>Connect Google Drive</h1>
    <p role="status">{result||'Checking your Drive consent…'}</p>
    {result?<button className="button button--secondary" onClick={()=>window.close()}>Close this tab</button>:null}
  </main>
}
