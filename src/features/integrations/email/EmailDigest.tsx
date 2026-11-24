import { useEffect,useState } from 'react'
import { Panel } from '../../../components/Page'
import { useFinDecision } from '../../finance/DecisionMemory'
import type { EmailDigestApi,EmailDigestStatus } from './api'

const activationText={
  ready:'Email sender verified.',
  sender:'Email delivery is unavailable until the workspace sender is approved and tested.',
  domain:'Email delivery is paused while the sending domain is checked.',
  quota:'Email delivery is paused until the sending allowance is verified.',
}
const healthText={
  waiting:'The last email is waiting for another delivery attempt.',
  sending:'The last email is being checked.',
  accepted:'The provider accepted the last email. Delivery is pending.',
  delivered:'The provider confirmed delivery of the last email.',
  bounced:'The last email was returned. Email is paused for this address.',
  failed:'The last email could not be delivered.',
  uncertain:'Delivery could not be confirmed. Check this inbox for the updates.',
}

export function EmailDigest({api,term,scopeReady}:{api:EmailDigestApi;term:string;scopeReady:boolean}) {
  const preference=useFinDecision(api,'email-digest:'+term,{})
  const [revision,setRevision]=useState(0)
  const [read,setRead]=useState<{revision:number;status:EmailDigestStatus|null}|null>(null)
  const [saved,setSaved]=useState('')
  const status=read?.revision===revision?read.status:null
  function refresh(){setRevision(value=>value+1)}
  useEffect(()=>{
    let active=true
    void api.status(term).then(status=>{if(active)setRead({revision,status})})
      .catch(()=>{if(active)setRead({revision,status:null})})
    return()=>{active=false}
  },[api,revision,term])
  async function update(enable?:boolean){
    setSaved('')
    const result=await preference.run(status&&enable!==undefined?{term,enable,version:status.version}:undefined)
    if(result)setSaved(result.enabled?'Email digest preference saved.':'Email digest turned off.')
    refresh()
  }
  return <Panel title="Email digest">
    <p>Optional email links back to this inbox for eligible unread updates from the previous day. Delivery can start at 8 am Manila time. Your required updates stay here.</p>
    <p role="status">{status?activationText[status.activation]:read?.revision===revision?'Email settings are unavailable.':'Checking email settings…'}</p>
    {status?.bounced?<p role="status">Email is paused for this address. Contact your workspace maintainer if the address is correct.</p>:
      status?.health?<p role="status">{healthText[status.health]}</p>:null}
    {saved?<p role="status">{saved}</p>:null}{preference.error?<p role="alert">{preference.error}</p>:null}
    <div className="auth-actions">
      {status&&(status.enabled||status.activation==='ready'&&!status.bounced)?<button type="button" className="button button--secondary"
        disabled={preference.locked||!scopeReady} onClick={()=>void update(!status.enabled)}>
        {status.enabled?'Turn off email digest':'Turn on daily email digest'}
      </button>:null}
      {preference.pending?<button type="button" className="button button--secondary" disabled={preference.busy}
        onClick={()=>void update()}>Retry the same email preference change</button>:null}
      <button type="button" className="button button--secondary" onClick={refresh}>Check email status</button>
    </div>
  </Panel>
}
