import {useState} from 'react'
import {Panel} from '../../components/Page'
import {TextField} from '../../components/TextField'
// Deliberately accepts no API, callback, work ID, upload or production request payload.
export function Practice(){
 const[title,setTitle]=useState(''),[date,setDate]=useState(''),[scope,setScope]=useState(''),[result,setResult]=useState(''),[draft,setDraft]=useState<{kind:string;title:string;date:string;scope:string}|null>(null)
 function tryDraft(kind:'task'|'request'){
  if(!title.trim()||!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date))||!scope.trim()){setResult('Enter a fictional title, date and done criteria or request scope.');setDraft(null);return}
  setDraft({kind,title:title.trim(),date,scope:scope.trim()});setResult('Practice only: no real task, request or FIN case was created.')
 }
 return <Panel title="Practice safely"><p>Use fictional details. Practice data stays here and clears when you leave. A proposed date is not an accepted commitment; a practice submission does not approve spending or publicity.</p><TextField id="practice-title" label="Practice title" value={title} onChange={e=>setTitle(e.target.value)} maxLength={240}/><TextField id="practice-date" label="Practice date" type="date" value={date} onChange={e=>setDate(e.target.value)}/><TextField id="practice-scope" label="Practice done criteria or request scope" value={scope} onChange={e=>setScope(e.target.value)} maxLength={1000}/><div className="auth-actions"><button className="button button--secondary" onClick={()=>tryDraft('task')}>Try practice task</button><button className="button button--secondary" onClick={()=>tryDraft('request')}>Try practice request</button></div><p role="status">{result}</p>{draft?<div className="resource-article"><h3>Fictional practice {draft.kind}: {draft.title}</h3><p>Owner: you (practice only) · Proposed date: {draft.date}</p><p className="resource-body">{draft.scope}</p>{draft.kind==='request'?<p>Next real step: find the confirmed service and its current contacts. Finance (FIN) review is required for costs, fundraising or sales, including zero-cost plans. Finalized publication review (MCD) is independent.</p>:<p>Next real step: confirm the assignee, agreed date and done criteria. The owner remains responsible until the next handoff is accepted.</p>}</div>:null}</Panel>
}
