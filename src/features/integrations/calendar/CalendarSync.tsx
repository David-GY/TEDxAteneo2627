import { useEffect,useRef,useState } from 'react'
import { Link } from 'react-router'
import { Panel } from '../../../components/Page'
import { CalendarSyncError,takeCalendarTerm,type CalendarSyncApi,type SyncStatus } from './api'

const failed=(error:unknown)=>error instanceof CalendarSyncError?
  ({
    stale:'This event or connection changed. Refresh the calendar and try again.',
    denied:'Permission to use this named calendar could not be confirmed.',
    reconnect:'Ask the calendar custodian to reconnect the approved school account.',
  } as Record<string,string>)[error.code]??'Google Calendar could not be checked. Use the app calendar for the latest schedule.'
  :'Google Calendar could not be checked. Use the app calendar for the latest schedule.'

function useStatus(api:CalendarSyncApi,term:string,event?:string) {
  const [reading,setReading]=useState<{key:string;status:SyncStatus|null;error:boolean}|null>(null)
  const [revision,setRevision]=useState(0)
  const key=JSON.stringify([term,event,revision])
  useEffect(()=>{
    let live=true
    void api.status(term,event).then(status=>{if(live)setReading({key,status,error:false})})
      .catch(()=>{if(live)setReading({key,status:null,error:true})})
    return()=>{live=false}
  },[api,event,key,term])
  const current=reading?.key===key?reading:null
  return {...current,pending:current===null,refresh:()=>setRevision(n=>n+1)}
}

const label=(status:SyncStatus)=>{
  if(status.connection==='reconnect')return 'Google access needs reconnecting. Use the app calendar for the latest schedule.'
  if(status.connection==='revoking')return 'Google access is being disconnected.'
  if(status.connection==='disconnected')return 'Shared Google Calendar sync is disconnected.'
  switch(status.state){
    case 'current':return 'Published to Google Calendar. The app calendar holds the official schedule.'
    case 'queued':return status.tombstone?'Removal from Google Calendar is pending.':'A change from the app calendar is waiting to publish.'
    case 'removed':return 'Removal from Google Calendar verified.'
    case 'retry':return 'Google Calendar could not be updated. The change is waiting for another attempt.'
    case 'conflict':return 'Google Calendar needs review. Ask the custodian to check the matching event.'
    case 'reconnect':return 'Google access needs reconnecting. Use the app calendar for the latest schedule.'
    default:return 'Available to publish to the approved calendar.'
  }
}

export function CalendarSyncEvent({api,term,event,version,confirmed}:{
  api:CalendarSyncApi;term:string;event:string;version:number;confirmed:boolean
}) {
  const [open,setOpen]=useState(false)
  return <div className="calendar-sync-event">
    <button className="button button--secondary" aria-expanded={open} onClick={()=>setOpen(!open)}>
      {open?'Hide Google Calendar sync status':'Google Calendar sync status'}
    </button>
    {open?<CalendarSyncDetails api={api} term={term} event={event} version={version} confirmed={confirmed}/>:null}
  </div>
}

function CalendarSyncDetails({api,term,event,version,confirmed}:{
  api:CalendarSyncApi;term:string;event:string;version:number;confirmed:boolean
}) {
  const {status,pending,error,refresh}=useStatus(api,term,event)
  const [busy,setBusy]=useState(false)
  const [notice,setNotice]=useState('')
  async function run(queue:boolean){
    setBusy(true)
    setNotice('')
    try {
      if(queue)await api.queue(term,event,version)
      if(!await api.process(term,event))setNotice('There is no change ready to send. Check again later.')
    } catch(error){setNotice(failed(error))}
    finally{refresh();setBusy(false)}
  }
  if(pending)return <p role="status">Checking shared Google Calendar status…</p>
  if(error)return <p role="status">Shared Google Calendar status is unavailable. The app calendar has the latest schedule.</p>
  if(!status)return <p role="status">No shared Google Calendar publication is recorded for this event.</p>
  const previous=status.lastVerifiedAt
  return <div>
    <div role="status">
      <p><strong>{status.calendar}</strong> · {busy?'Checking the latest result with Google…':label(status)}</p>
      {previous?<p>Last verified with Google <time dateTime={previous}>{new Date(previous).toLocaleString('en-PH',{timeZone:'Asia/Manila'})} Manila</time></p>:null}
      {notice?<p>{notice}</p>:null}
    </div>
    {status.canManage&&status.connection==='connected'&&(confirmed||status.state!==null)?<div className="auth-actions">
      {status.state==='queued'||status.state==='retry'
        ?<button className="button button--secondary" disabled={busy} onClick={()=>void run(false)}>Send pending change to Google</button>
        :<button className="button button--secondary" disabled={busy} onClick={()=>void run(true)}>
          {status.state===null?`Publish to ${status.calendar}`:'Verify with Google again'}
        </button>}
    </div>:null}
  </div>
}

export function CalendarSyncSettings({api,term}:{api:CalendarSyncApi;term:string}) {
  const {status,refresh}=useStatus(api,term)
  const [busy,setBusy]=useState(false)
  const [notice,setNotice]=useState('')
  async function run(action:'connect'|'disconnect'|'process'|'repair') {
    setBusy(true)
    setNotice('')
    const popup=action==='connect'?window.open('about:blank','_blank'):null
    try {
      if(action==='connect'){
        if(!popup){setNotice('Allow the Google consent window, then try again.');return}
        await api.connect(term,popup)
        setNotice('Complete consent in the Google window, then check the connection here.')
      } else if(action==='disconnect') await api.disconnect(term)
      else {
        const outcome=await (action==='repair'?api.repairRemoval(term):api.process(term))
        setNotice(outcome==='verified'?'One calendar change verified with Google.':
          outcome==='retry'?'Google Calendar could not be updated. A retry is pending.':
          outcome==='conflict'?'A calendar change needs review. Check the matching Google event.':
          outcome==='reconnect'?'Reconnect the approved school account.':'No calendar change is ready to send.')
      }
    } catch(error){popup?.close();setNotice(failed(error))}
    finally {if(action!=='connect')refresh();setBusy(false)}
  }
  if(!status?.canManage)return null
  return <Panel title="Shared Google Calendar">
    <p><strong>{status.calendar}</strong> · {status.connection==='connected'?'Connection ready.':label(status)}</p>
    <p>Shared publishing is optional. Publish individual core events from their sync status. The app calendar is the official schedule.</p>
    {notice?<p role="status">{notice}</p>:null}
    <div className="auth-actions">
      {status.connection==='disconnected'||status.connection==='reconnect'?<button className="button button--secondary" disabled={busy} onClick={()=>void run('connect')}>
        {status.connection==='reconnect'?'Reconnect Google Calendar':'Connect approved Google Calendar'}
      </button>:null}
      {status.connection!=='disconnected'?<button className="button button--secondary" disabled={busy} onClick={()=>void run('disconnect')}>
        {status.connection==='revoking'?'Finish disconnecting Google Calendar':'Disconnect Google Calendar'}
      </button>:null}
      {status.connection==='connected'?<button className="button button--secondary" disabled={busy} onClick={()=>void run('process')}>Process next pending calendar change</button>:null}
      {status.connection==='connected'&&status.pausedRemoval?<button className="button button--secondary" disabled={busy} onClick={()=>void run('repair')}>Retry a paused removal</button>:null}
      <button className="button button--secondary" disabled={busy} onClick={refresh}>Check calendar connection</button>
    </div>
  </Panel>
}

export function CalendarSyncCallback({api}:{api:CalendarSyncApi}) {
  const [message,setMessage]=useState('Confirming access to the approved calendar…')
  const attempt=useRef<Promise<void>|null>(null)
  useEffect(()=>{
    attempt.current??=(async()=>{
      const query=new URLSearchParams(window.location.search)
      window.history.replaceState(window.history.state,'',window.location.pathname)
      const term=takeCalendarTerm(),state=query.get('state')
      if(!term||!state||query.getAll('state').length!==1)throw new CalendarSyncError('stale')
      await api.finish(term,state,query.get('code'),query.get('error'))
    })()
    let live=true
    void attempt.current.then(
      ()=>{if(live)setMessage('Google Calendar connected. Return to the workspace calendar to publish selected events.')},
      error=>{if(live)setMessage(failed(error))},
    )
    return()=>{live=false}
  },[api])
  return <main className="standalone-page"><h1>Google Calendar connection</h1><p role="status">{message}</p><Link to="/calendar">Open workspace calendar</Link></main>
}
