import {useEffect,useRef,useState} from 'react'
import {Panel} from '../../components/Page'
import type {ImportInput,ImportRef} from './task-import-api'
import type {RosterImportsApi,RosterPreview,RosterRead,RosterReceipt} from './roster-import-api'

const instant=(date:string)=>date?date+'T00:00:00+08:00':''
const manilaDate=(value:string)=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Manila',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(value))
const stampOf=(list:string,joined:string,ends:string,input:ImportInput)=>JSON.stringify({list,joined,ends,header:input.header,rows:input.rows,mapping:Object.fromEntries(Object.entries(input.mapping).sort(([a],[b])=>a.localeCompare(b)))})
type Pending={run:()=>Promise<()=>void>}
export function RosterImportPanel({api,term,input,enabled,onLoad,onDenied,onLockChange}:{api:RosterImportsApi;term:string;input:ImportInput;enabled:boolean;onLoad:(value:NonNullable<RosterRead['draft']>)=>void;onDenied:()=>void;onLockChange:(locked:boolean)=>void}){
 const [list,setList]=useState(''),[joined,setJoined]=useState(''),[ends,setEnds]=useState(''),[reason,setReason]=useState(''),[selected,setSelected]=useState('')
 const [drafts,setDrafts]=useState<RosterRead['drafts']>([]),[draft,setDraft]=useState<(ImportRef&{stamp:string})|null>(null),[review,setReview]=useState<{value:RosterPreview;stamp:string}|null>(null),[receipt,setReceipt]=useState<RosterReceipt|null>(null)
 const [busy,setBusy]=useState(false),[pending,setPending]=useState<Pending|null>(null),[confirmed,setConfirmed]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState(''),epoch=useRef(0)
 const callbacks=useRef({onLoad,onDenied,onLockChange});callbacks.current={onLoad,onDenied,onLockChange}
 const stamp=stampOf(list,joined,ends,input),currentReview=review?.stamp===stamp?review.value:null,locked=busy||!!pending
 function problem(e:unknown){const kind=(e as{kind?:string}).kind
  if(kind==='denied'){setDraft(null);setDrafts([]);setReview(null);setReceipt(null);setList('');setJoined('');setEnds('');setReason('');setSelected('');callbacks.current.onDenied();return 'Current roster permission is unavailable. Private review context was cleared.'}
  return kind==='conflict'?'The draft or organization changed. Recheck the saved version, then save and preview again. Your edits are kept.':kind==='validation'?'Repair the rows or membership dates, then save and preview again. Your edits are kept.':'The connection is unavailable. Your input is kept.'
 }
 async function read(id?:string,replace=false){const seq=++epoch.current;setBusy(true);setError('');callbacks.current.onLockChange(true)
  try{const v=await api.read(term,id);if(seq!==epoch.current)return;setDrafts(v.drafts)
   if(v.draft){const d=v.draft,j=manilaDate(d.joinedAt),e=manilaDate(d.endsAt);setDraft({...d,stamp:stampOf(d.listName,j,e,d.input)});setReceipt(d.receipt);setReview(null);setConfirmed(false)
    if(replace){setList(d.listName);setJoined(j);setEnds(e);setReason('');callbacks.current.onLoad(d)}
   }
  }catch(e){if(seq===epoch.current)setError(problem(e))}finally{if(seq===epoch.current){setBusy(false);callbacks.current.onLockChange(false)}}
 }
 useEffect(()=>{void read();return()=>{epoch.current++}},[api,term])
 async function execute(action:Pending){const seq=++epoch.current;setPending(action);setBusy(true);setError('');callbacks.current.onLockChange(true)
  try{const apply=await action.run();if(seq!==epoch.current)return;apply();setPending(null);callbacks.current.onLockChange(false)}catch(e){if(seq!==epoch.current)return;setReview(null);setConfirmed(false)
   if((e as{kind?:string}).kind==='connection')setError('Result not confirmed. Retry the identical roster request; its input, reason and key are locked to prevent duplicates.')
   else{setPending(null);callbacks.current.onLockChange(false);setError(problem(e))}
  }finally{if(seq===epoch.current)setBusy(false)}
 }
 function save(){const data=structuredClone(input),id=draft?.draftId??null,version=draft?.version??0,key=crypto.randomUUID(),savedStamp=stamp
  void execute({run:async()=>{const d=await api.save(term,list,instant(joined),instant(ends),data,id,version,key);return()=>{setDraft({...d,stamp:savedStamp});setReview(null);setReceipt(null);setConfirmed(false);setMessage('Private roster draft saved. Preview the current additions before importing.')}}})
 }
 async function preview(){if(!draft)return;const seq=++epoch.current;setBusy(true);callbacks.current.onLockChange(true);setReview(null);setConfirmed(false);setError('');const savedStamp=stamp
  try{const v=await api.preview(term,draft.draftId,draft.version);if(seq===epoch.current)setReview({value:v,stamp:savedStamp})}catch(e){if(seq===epoch.current)setError(problem(e))}finally{if(seq===epoch.current){setBusy(false);callbacks.current.onLockChange(false)}}
 }
 function commit(){if(!draft||!currentReview?.valid||!confirmed||!reason.trim())return;const id=draft.draftId,version=draft.version,hash=currentReview.reviewHash,key=crypto.randomUUID(),why=reason
  void execute({run:async()=>{const result=await api.commit(term,id,version,hash,why,key);return()=>{setReceipt(result);setDraft({...result,stamp});setReview(null);setConfirmed(false);setMessage('Reviewed roster additions were saved. No login, deployment or role was created.')}}})
 }
 return <Panel title="3. Save and review roster additions">
  <p>Up to 50 records and 200,000 bytes of mapped input per whole-file import. A reviewed addition creates approved core membership in the selected term through Organization administration. School sign-in still requires its own verified identity checks. No login is linked, invitation sent, or deployment or role assigned.</p>
  <p>Reuse the same list name and case-sensitive source keys. Existing matching people remain unchanged, including their names and membership dates. Resolve name differences, returning people from other terms, guests or suspended accounts on the organization page.</p>
  <label>Roster list name (reuse for retries)<input maxLength={80} disabled={locked||!!draft} value={list} onChange={e=>{setList(e.target.value);setConfirmed(false)}}/></label>
  <label>New memberships start (Manila date)<input type="date" disabled={locked} value={joined} onChange={e=>{setJoined(e.target.value);setConfirmed(false)}}/></label>
  <label>New memberships end (exclusive Manila date)<input type="date" disabled={locked} value={ends} onChange={e=>{setEnds(e.target.value);setConfirmed(false)}}/></label>
  <p>Dates apply only to new memberships, from midnight in Asia/Manila up to but excluding the end date. They are never inferred from CSV role or identity fields.</p>
  <div className="auth-actions"><button className="button" disabled={locked||!enabled||!list.trim()||!joined||!ends||joined>=ends||draft?.state==='committed'} onClick={save}>Save private roster draft</button><button className="button button--secondary" disabled={locked||!draft||draft.state!=='draft'||draft.stamp!==stamp} onClick={()=>void preview()}>Preview roster changes</button></div>
  {message?<p role="status">{message}</p>:null}{error?<p role="alert">{error}</p>:null}
  {pending?<button className="button" disabled={busy} onClick={()=>void execute(pending)}>Retry identical roster request</button>:null}
  {currentReview&&!receipt?<section aria-label="Exact roster changes"><h3>Exact roster changes · {currentReview.termLabel} · {currentReview.listName}</h3>
   <p>New rows add active core membership with the dates below. Existing rows keep their current membership. This confirmation assigns no deployments or roles.</p>
   <ol>{currentReview.rows.map(r=><li key={r.record}><h4>CSV record {r.record}: {r.operation==='create'?'Add core membership':'Keep existing membership'}</h4><p>Source key {r.sourceKey}</p><dl><dt>Before</dt><dd>{r.before?`${r.before.name} · ${r.before.email} · active · ${manilaDate(r.before.joinedAt)} to ${manilaDate(r.before.endsAt)} (exclusive)`:'No selected-term core membership will be changed'}</dd><dt>After</dt><dd>{r.after.name} · {r.after.email} · active · {manilaDate(r.after.joinedAt)} to {manilaDate(r.after.endsAt)} (exclusive)</dd></dl>{r.errors.length?<ul role="alert">{r.errors.map((e,i)=><li key={i}>{e}</li>)}</ul>:null}</li>)}</ol>
   {!currentReview.valid?<p>Repair every row error and save again. No partial import is available.</p>:null}
   <label className="csv-confirm"><input type="checkbox" checked={confirmed} disabled={locked||!currentReview.valid} onChange={e=>setConfirmed(e.target.checked)}/>I reviewed these exact roster additions and their membership dates.</label>
  </section>:null}
  {currentReview||pending?<label>Reason for these roster additions<input maxLength={1000} value={reason} disabled={locked} onChange={e=>setReason(e.target.value)}/></label>:null}
  {currentReview?<button className="button" disabled={locked||!currentReview.valid||!confirmed||!reason.trim()} onClick={commit}>Import reviewed roster additions</button>:null}
  {receipt?<section aria-label="Saved roster receipt"><h3>Saved roster import</h3><p>{receipt.created} added · {receipt.unchanged} unchanged in this term.</p><ul>{receipt.items.map(r=><li key={r.sourceKey}>{r.name} · {r.action==='create'?'Added':'Unchanged'}</li>)}</ul></section>:null}
  <details><summary>Resume a private roster draft</summary><p>Saved input, mapping and receipts require your current roster authority. Nothing is saved in browser storage.</p><button className="button button--secondary" disabled={locked} onClick={()=>void read()}>Refresh roster drafts (keep input)</button><label>Saved roster draft<select aria-label="Saved roster draft" disabled={locked} value={selected} onChange={e=>setSelected(e.target.value)}><option value="">Choose your saved draft</option>{drafts.map(d=><option key={d.draftId} value={d.draftId}>{d.listName} · {d.state} · version {d.version}</option>)}</select></label><button className="button button--secondary" disabled={locked||!selected} onClick={()=>void read(selected,true)}>Replace input with saved roster draft</button>{draft?<button className="button button--secondary" disabled={locked} onClick={()=>void read(draft.draftId)}>Recheck roster version (keep edits)</button>:null}</details>
  {draft?<button className="button button--secondary" disabled={locked} onClick={()=>{setDraft(null);setReview(null);setReceipt(null);setConfirmed(false);setReason('');setMessage('Starting another roster file. Keep the same list name and source keys to avoid duplicates.')}}>Start another roster file (keep input)</button>:null}
 </Panel>
}
