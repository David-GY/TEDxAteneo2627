import {useEffect,useId,useRef,useState,type FormEvent} from 'react'
import {useRouteLoaderData} from 'react-router'
import {Panel} from '../../components/Page'
import {LoadingState,ErrorState,EmptyState} from '../../components/FeedbackState'
import type {WorkspaceContext} from '../auth/gateway'
import type {CommentsApi,CommentPage,CommentItem,CommentHistory,CommentInput,Candidate} from './api'

const stamp=(value:string)=>new Intl.DateTimeFormat('en-PH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Manila'}).format(new Date(value))
export function Comments({api,workId}:{api:CommentsApi;workId:string}) {
 const context=useRouteLoaderData('workspace') as WorkspaceContext|undefined
 const subject=context?('memberId'in context?context.memberId:context.guestAccessId):''
 return <Thread key={workId+':'+subject} api={api} workId={workId}/>
}
function Thread({api,workId}:{api:CommentsApi;workId:string}) {
 const [page,setPage]=useState(1),[reload,setReload]=useState(0)
 const [loaded,setLoaded]=useState<{key:string;data:CommentPage|null;error:boolean}|null>(null)
 const key=page+':'+reload
 useEffect(()=>{let live=true;void api.read(workId,page).then(data=>{if(live)setLoaded({key,data,error:false})}).catch(()=>{if(live)setLoaded({key,data:null,error:true})});return()=>{live=false}},[api,workId,page,key])
 const current=loaded
 return <Panel title="Comments"><p>Plain text only. Links and HTML remain text. Times are Manila time. Only current participants with detail access can read this thread; drafts are private to their author.</p>
 <button className="button button--secondary" onClick={()=>setReload(reload+1)}>Reload comments</button>
 {current&&current.key!==key?<p role="status">Refreshing comment permissions…</p>:null}
 {!current?<LoadingState title="Loading comments"/>:current.error?<ErrorState title="Comments unavailable" description="Check access or connection, then reload comments."/>:!current.data?<EmptyState title="Comments are not shared" description="Detail access is required. No comments or mention candidates are shown."/>:<>
 <p>{current.data.canComment?'You can comment. Only authors edit their comments; authors and the work owner can redact published text.':'Read-only thread. Your current permission or the record state prevents changes.'}</p>
 {current.data.items.length===0?<p>No comments on this page.</p>:current.data.items.map(item=><CommentRow key={item.id} api={api} workId={workId} item={item} onSaved={()=>setReload(reload+1)}/>)}
 <div className="auth-actions"><button className="button button--secondary" disabled={page===1} onClick={()=>setPage(page-1)}>Previous comments</button><span>Page {page} · {current.data.total} permitted comments</span><button className="button button--secondary" disabled={page*20>=current.data.total} onClick={()=>setPage(page+1)}>Next comments</button></div>
 </>}
 {current?.data?.canComment?<Composer api={api} workId={workId} onSaved={()=>setReload(reload+1)}/>:null}
 </Panel>
}
function CommentRow({api,workId,item,onSaved}:{api:CommentsApi;workId:string;item:CommentItem;onSaved:()=>void}) {
 const [history,setHistory]=useState<{version:number;rows:CommentHistory[]}|null>(null),[error,setError]=useState(''),[editing,setEditing]=useState(false),[pending,setPending]=useState(false)
 return <article className="comment-row"><h3>{item.author}</h3><p>{stamp(item.createdAt)} · Version {item.version} · {item.state}{item.version>1?' · Amended '+stamp(item.updatedAt):''}</p>
 <p className="record-text">{item.body??(item.state==='redacted'?'Comment redacted. Original evidence retained in protected custody.':'Draft removed.')}</p>{item.version>1?<p className="record-text">Reason: {item.reason}</p>:null}
 {item.state==='published'?<p className="record-text">Evidence reference: <code>{'comment:'+item.id+':'+item.version}</code></p>:null}
 {item.evidence.map((e,i)=><p key={i}>Revision {e.revision} retained for {e.purpose} at work version {e.workVersion}.{e.revision<item.version?' A later amendment exists.':''}</p>)}
 <div className="auth-actions"><button className="button button--secondary" onClick={()=>{setError('');void api.history(item.id).then(rows=>setHistory({version:item.version,rows})).catch(()=>setError('History could not load. Try again.'))}}>Show edit history</button>{item.canEdit||item.canRedact?<button disabled={pending} className="button button--secondary" onClick={()=>setEditing(!editing)}>{editing?'Close editor (discard draft)':'Amend comment'}</button>:null}</div>
 {error?<p role="alert">{error}</p>:null}{history?.version===item.version?<ol>{history.rows.map(h=><li key={h.revision}><p>Revision {h.revision} · {stamp(h.recordedAt)} · {h.state}</p><p className="record-text">{h.body??'Text withheld after removal or redaction.'}</p><p className="record-text">Reason: {h.reason}</p></li>)}</ol>:null}
 {editing?<Composer key={item.id} api={api} workId={workId} item={item} onPending={setPending} onSaved={()=>{setEditing(false);onSaved()}}/>:null}</article>
}
function Composer({api,workId,item,onSaved,onPending}:{api:CommentsApi;workId:string;item?:CommentItem;onSaved:()=>void;onPending?:(pending:boolean)=>void}) {
 const fieldId=useId()
 const [baseVersion]=useState(item?.version)
 const [body,setBody]=useState(item?.body??''),[reason,setReason]=useState(''),[draft,setDraft]=useState(false),[mentions,setMentions]=useState<string[]>(item?.mentions??[])
 const [search,setSearch]=useState(''),[candidates,setCandidates]=useState<Candidate[]>([]),[candidateError,setCandidateError]=useState('')
 const [finding,setFinding]=useState(false),[searched,setSearched]=useState(false)
 const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[conflict,setConflict]=useState(false),[error,setError]=useState('')
 const pending=useRef<{input:CommentInput;key:string}|null>(null)
 async function send(input:CommentInput) {const request=pending.current??{input,key:crypto.randomUUID()};pending.current=request;setBusy(true);onPending?.(true);setError('');const result=await api.execute(request.input,request.key);setBusy(false)
  if(!result.ok){setError(result.error.message);setUncertain(result.error.retryable);onPending?.(result.error.retryable);setConflict(['stale_version','conflict','idempotency_conflict','unexpected'].includes(result.error.kind));if(!result.error.retryable)pending.current=null;return}
  pending.current=null;setUncertain(false);onPending?.(false);setBody('');setReason('');setMentions([]);setDraft(false);onSaved()
 }
 function submit(e:FormEvent<HTMLFormElement>) {e.preventDefault();const action=(e.nativeEvent as SubmitEvent).submitter?.getAttribute('value') as CommentInput['action']||'edit';void send({workId,commentId:item?.id,version:baseVersion,body,mentions,draft,action,reason})}
 const locked=busy||uncertain||conflict
 return <form className="deliverable-editor" onSubmit={submit}><h3>{item?'Amendment':'New comment'}</h3>
 {error?<p role="alert">{error}{conflict?' Your text is retained below. Copy it before reloading comments and reopening the latest version.':''}</p>:null}
 {uncertain?<button type="button" className="button" disabled={busy} onClick={()=>pending.current&&void send(pending.current.input)}>Retry same comment request</button>:null}
 <fieldset disabled={locked}><div className="form-field"><label htmlFor={fieldId+'-body'}>Comment text{!item||item.canEdit?' (required)':''}</label><textarea id={fieldId+'-body'} value={body} onChange={e=>setBody(e.target.value)} maxLength={8000} required={!item||item.canEdit} readOnly={!!item&&!item.canEdit}/></div>
 {item?<div className="form-field"><label htmlFor={fieldId+'-reason'}>Amendment or redaction reason (required)</label><textarea id={fieldId+'-reason'} value={reason} onChange={e=>setReason(e.target.value)} maxLength={2000} required/></div>:<label className="editor-check"><input type="checkbox" checked={draft} onChange={e=>setDraft(e.target.checked)}/>Save as private draft</label>}
 {!item||item.canEdit?<><div className="form-field"><label htmlFor={fieldId+'-search'}>Find eligible mentions</label><input id={fieldId+'-search'} value={search} maxLength={100} onChange={e=>setSearch(e.target.value)}/></div><button type="button" disabled={finding} className="button button--secondary" onClick={()=>{setCandidates([]);setCandidateError('');setFinding(true);setSearched(false);void api.candidates(workId,search).then(rows=>{setCandidates(rows);setSearched(true)}).catch(()=>setCandidateError('Mention candidates could not load. Search again.')).finally(()=>setFinding(false))}}>Find participants</button>
 {finding?<p role="status">Checking eligible participants…</p>:searched?<p role="status">{candidates.length?`${candidates.length} eligible participants shown. Search by name to narrow the list.`:'No eligible participants match this search.'}</p>:null}
 <p>Mention selections: {mentions.length}. Candidates include current owners, collaborators and explicit member or committee participants. Mention notifications are not delivered yet.</p>{candidateError?<p role="alert">{candidateError}</p>:null}{candidates.map(c=><label className="editor-check" key={c.id}><input type="checkbox" checked={mentions.includes(c.id)} disabled={!mentions.includes(c.id)&&mentions.length>=20} onChange={e=>setMentions(e.target.checked?[...mentions,c.id]:mentions.filter(id=>id!==c.id))}/>{c.name}</label>)}{mentions.length?<button type="button" className="button button--secondary" onClick={()=>setMentions([])}>Clear mentions</button>:null}
 <button className="button" value="edit">{item?'Save amendment':draft?'Save private comment draft':'Post comment'}</button></>:null}
 {item?.canEdit&&item.state==='draft'?<><button className="button" value="publish">Publish draft</button><button className="button button--secondary" value="remove" formNoValidate>Remove own draft</button></>:null}
 {item?.canRedact?<button className="button button--secondary" value="redact" formNoValidate>Redact published text</button>:null}
 </fieldset></form>
}
