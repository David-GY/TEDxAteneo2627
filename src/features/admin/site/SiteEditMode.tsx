import {useEffect,useRef,useState} from 'react'
import {useLocation,useRevalidator} from 'react-router'
import {navigationItems} from '../../../app/navigation'
import {TextField} from '../../../components/TextField'
import {isGuest,type WorkspaceContext} from '../../auth/gateway'
import {forgetRecordDrafts} from '../../auth/draftScope'
import {useFinDecision} from '../../finance/DecisionMemory'
import {siteNavigationIds,validSitePresentation,type SitePresentation} from './presentation'
import {SiteControls} from './SiteControls'
import {SavedSitePreview,SiteReconcile} from './SiteReview'
import type {SiteWordingApi,SiteWordingConfiguration,SiteWordingSave,SitePublish,SiteReview,LogoChoice} from './wording-api'
import './site.css'

const defaultSite:SitePresentation={schemaVersion:1,labels:{},order:[],accent:'#b82320',blocks:[]}
const text=(v:SitePresentation)=>JSON.stringify(v)
export function SiteEditMode({api,context,onPublished}:{api:SiteWordingApi;context:WorkspaceContext;onPublished?:()=>void}){
 return isGuest(context)||!context.capabilities.includes('admin.configure')?null:<SiteMode key={context.termId+context.termMembershipId} api={api} term={context.termId} identity={context.termMembershipId} refreshToken={context} onPublished={onPublished}/>
}
function SiteMode({api,term,identity,refreshToken,onPublished}:{api:SiteWordingApi;term:string;identity:string;refreshToken:WorkspaceContext;onPublished?:()=>void}){
 const[open,setOpen]=useState(false),[data,setData]=useState<SiteWordingConfiguration|null>(null),[state,setState]=useState<'loading'|'ready'|'error'|'denied'>('loading'),[epoch,setEpoch]=useState(0),[revision,setRevision]=useState(0),[locked,setLocked]=useState(false),[saved,setSaved]=useState(false)
 const record='site-wording-'+term
 const{revalidate}=useRevalidator(),[published,setPublished]=useState(false)
 const path=useLocation().pathname,previousPath=useRef(path)
 function denied(){forgetRecordDrafts(record);setData(null);setState('denied');setLocked(false)}
 useEffect(()=>{let live=true;if(open){setState('loading');void api.read(term).then(v=>{if(live){setData(v);setState('ready')}}).catch(e=>{if(!live)return;if(e?.denied){forgetRecordDrafts(record);setData(null);setState('denied');setLocked(false)}else setState('error')})}return()=>{live=false}},[api,term,open,epoch,refreshToken,record])
 useEffect(()=>{const refresh=()=>{if(open&&document.visibilityState!=='hidden')setEpoch(n=>n+1)};window.addEventListener('focus',refresh);return()=>window.removeEventListener('focus',refresh)},[open])
 useEffect(()=>()=>forgetRecordDrafts(record),[record])
 // EditSafety permits a dirty route change only after explicit discard. The shared
 // shell survives that navigation, so close and clear this contextual editor too.
 useEffect(()=>{if(previousPath.current!==path){previousPath.current=path;forgetRecordDrafts(record);setOpen(false);setData(null);setLocked(false);setSaved(false)}},[path,record])
 return <section className="site-wording-mode" aria-label="Site wording edit mode">
 {!open?<button className="button button--secondary" onClick={()=>{setOpen(true);setSaved(false)}}>Edit site wording</button>:<div className="panel">
  <h2>Site Edit Mode · private site presentation</h2><p>Only you can read this draft. Saving does not change ordinary navigation or publish anything. Routes, access and approved identity stay protected.</p>
  <div className="auth-actions"><button className="button button--secondary" disabled={locked} onClick={()=>setEpoch(n=>n+1)}>Refresh wording settings (keep inputs)</button><button className="button button--secondary" disabled={locked} data-discard-edits onClick={()=>{forgetRecordDrafts(record);setOpen(false);setData(null);setSaved(false)}}>Close site wording</button></div>
  {saved?<p role="status">{published?'Site presentation published. Navigation has refreshed.':'Private wording draft saved. Ordinary navigation is unchanged.'}</p>:null}
  {state==='loading'?<p role="status">Checking current site-editing authority…</p>:null}
  {state==='error'?<p role="alert">Site wording settings could not be checked. Inputs are kept; refresh access or connection before saving. Unsupported saved definitions require a reviewed repair.</p>:null}
  {state==='denied'?<p role="alert">Site editing is no longer allowed. Private client inputs were cleared. Ordinary work remains available.</p>:null}
  {data&&state!=='denied'?<WordingDraft key={revision} api={api} data={data} term={term} identity={identity} record={record} disabled={state!=='ready'} onLock={setLocked} denied={denied} conflict={()=>setEpoch(n=>n+1)} saved={pub=>{setSaved(true);setPublished(!!pub);setData(null);setRevision(n=>n+1);setEpoch(n=>n+1);if(pub){onPublished?.();void revalidate()}}}/>:null}
 </div>}
 </section>
}
function WordingDraft({api,data,term,identity,record,disabled,onLock,denied,conflict,saved}:{api:SiteWordingApi;data:SiteWordingConfiguration;term:string;identity:string;record:string;disabled:boolean;onLock:(v:boolean)=>void;denied:()=>void;conflict:()=>void;saved:(pub?:boolean)=>void}){
 const alive=useRef(true)
 useEffect(()=>{alive.current=true;return()=>{alive.current=false}},[])
 const draft=data.draft,privateDraft=draft&&!draft.publishedVersionId?draft:null,initial=text(privateDraft?.definition??data.definition??defaultSite)
 const runner={run:async(command:SiteWordingSave|SitePublish,key:string)=>{const result=await api.run(command,key);if(alive.current&&!result.ok){if(result.error.kind==='permission_denied')denied();if(result.error.kind==='stale_version')conflict()}return result}}
 const mem=useFinDecision<SiteWordingSave|SitePublish,{draftId:string;version:number}>(runner,record+':'+identity,{definition:initial,baseline:initial,base:String(privateDraft?.baseVersion??data.version),version:String(draft?.version??0),rollback:privateDraft?.rollbackVersionId??'',reason:''})
 const[review,setReview]=useState<{value:SiteReview;signature:string}|null>(null),[ack,setAck]=useState(false),[checking,setChecking]=useState(false),[error,setError]=useState(''),[logos,setLogos]=useState<LogoChoice[]|null>(null),[history,setHistory]=useState(data.history??[]),[before,setBefore]=useState(data.nextBefore??null)
 const value=JSON.parse(mem.fields.definition)as SitePresentation,dirty=mem.fields.definition!==mem.fields.baseline,stale=Number(mem.fields.base)!==data.version||Number(mem.fields.version)!==(draft?.version??0),valid=validSitePresentation(value)
 useEffect(()=>onLock(mem.locked||checking),[mem.locked,checking,onLock])
 const signature=JSON.stringify([mem.fields.definition,mem.fields.base,mem.fields.version,mem.fields.rollback,draft?.draftId,data.version]),currentReview=review?.signature===signature?review.value:null,reviewLogo=logos?.find(x=>x.assetId===currentReview?.proposed.logo?.assetId&&x.approvalId===currentReview?.proposed.logo?.approvalId)
 useEffect(()=>{let live=true;if(api.logos)void api.logos(term).then(v=>{if(live)setLogos(v)}).catch(e=>{if(!live)return;setError('Approved logo choices unavailable; keep protected text identity or refresh current authority.');if(e?.denied)denied()});return()=>{live=false}},[api,term])
 function replace(next:SitePresentation,rollback=''){mem.change({...mem.fields,definition:text(next),rollback});setReview(null);setAck(false)}
 function change(id:string,label:string){const labels={...value.labels};if(label==='')delete labels[id];else labels[id]=label;replace({...value,labels})}
 async function save(retry=false){if(!retry&&(disabled||stale||!valid))return;const command=mem.pending?.command;const result=await mem.run(retry?undefined:{term,definition:value,baseVersion:Number(mem.fields.base),version:Number(mem.fields.version),rollbackVersionId:mem.fields.rollback||null});if(result)saved(!!command&&'action'in command&&command.action==='publish')}
 async function inspect(){if(!privateDraft||dirty||stale||!api.preview)return;setChecking(true);setReview(null);setAck(false);setError('');try{const r=await api.preview(privateDraft.draftId);if(alive.current)setReview({value:r,signature})}catch(e){if(!alive.current)return;setError('Saved preview unavailable. Inputs are retained; refresh current authority.');if((e as{denied?:boolean})?.denied)denied()}finally{if(alive.current)setChecking(false)}}
 async function publish(){if(!currentReview||currentReview.stale||dirty||stale||!!currentReview.proposed.logo&&!reviewLogo||!ack||!mem.fields.reason.trim()||!privateDraft)return;const result=await mem.run({action:'publish',draftId:privateDraft.draftId,version:privateDraft.version,reviewHash:currentReview.reviewHash,reason:mem.fields.reason});if(result)saved(true)}
 return <div data-pending-command={mem.locked||checking} data-unsaved-changes={dirty||!!mem.fields.reason}>
  <fieldset disabled={mem.locked||disabled||checking}><legend>Navigation wording</legend><p>Leave a wording field empty to use its built-in name. Use plain text, up to80 characters. Other draft fields are retained.</p>
   {navigationItems.filter(item=>siteNavigationIds.includes(item.id)).map(item=><TextField key={item.id} id={'site-wording-'+item.id} label={item.id==='tasks'?'Tasks wording':item.label+' wording'} maxLength={80} value={value.labels[item.id]??''} placeholder={item.label} hint={'Built-in name: '+item.label} error={value.labels[item.id]&&!validSitePresentation({...value,labels:{[item.id]:value.labels[item.id]}})?'Use plain text without HTML, control characters or blank-only wording.':undefined} onChange={e=>change(item.id,e.target.value)}/>)}
   {stale?<p role="alert">Publication or private draft changed. Your wording is retained. Refresh to inspect current settings; do not overwrite them. Close and explicitly discard local inputs to reopen the latest saved draft. Use the comparison below to choose a source for every part before saving a reconciled private draft.</p>:null}
   <button className="button button--secondary" disabled={stale||!valid} onClick={()=>void save()}>Save private wording draft</button>
  </fieldset>
  {api.preview?<>
  <details><summary>Guidance, order, accent and approved logo</summary><SiteControls value={value} disabled={disabled||mem.locked||checking} change={replace}/>
   <div><label htmlFor="site-approved-logo">Approved logo</label><select id="site-approved-logo" disabled={disabled||mem.locked||logos===null} value={value.logo?value.logo.assetId+':'+value.logo.approvalId:''} onChange={e=>{const selected=logos?.find(x=>x.assetId+':'+x.approvalId===e.target.value);replace({...value,schemaVersion:2,logo:selected?{assetId:selected.assetId,approvalId:selected.approvalId}:null})}}><option value="">Protected text identity</option>{logos?.map(x=><option key={x.assetId+':'+x.approvalId} value={x.assetId+':'+x.approvalId}>{x.label} · MCD review valid until {new Date(x.expiresAt).toLocaleDateString('en-PH',{timeZone:'Asia/Manila'})}</option>)}</select></div>
   <p>Only a finalized PNG/JPEG from an exact current independent MCD approval for whole-workspace logo use is selectable. No logo upload, recoloring, distortion or approval checkbox. Actual license/rights and approval conditions require institutional confirmation.</p>{value.logo&&!logos?.some(x=>x.assetId===value.logo?.assetId&&x.approvalId===value.logo?.approvalId)?<p role="alert">Selected logo review is unavailable or no longer current. Choose protected text identity or a current approved image before saving.</p>:null}{logos?.filter(x=>x.assetId===value.logo?.assetId&&x.approvalId===value.logo?.approvalId).map(x=><p key={x.approvalId}>MCD conditions: {x.conditions}</p>)}
  </details>
  {!valid?<p role="alert">Use supported destinations, unique blocks and bounded plain text without HTML or control characters; use a supported accent and exact approved logo selection.</p>:null}
  {stale?<SiteReconcile key={data.version+':'+data.draft?.version} retained={value} current={data.definition??defaultSite} saved={data.draft?.definition??data.definition??defaultSite} disabled={disabled||mem.locked||checking} apply={v=>{mem.change({...mem.fields,definition:text(v),base:String(data.version),version:String(data.draft?.version??0),rollback:''});setReview(null);setAck(false)}}/>:null}
  <p>Save your private draft before previewing its exact changes. Publication requires that saved preview, your reason and explicit confirmation.</p><button className="button button--secondary" disabled={disabled||mem.locked||checking||dirty||stale||!privateDraft||!valid} onClick={()=>void inspect()}>Preview saved site draft</button>
  {currentReview?<section className="panel"><h2>Review before publishing</h2><p>{currentReview.stale?'This preview is stale. Reconcile against the latest publication and save again.':'This review binds the exact saved draft and current publication.'}</p><SavedSitePreview previous={currentReview.previous} proposed={currentReview.proposed}/>{currentReview.proposed.logo?<p>Approved image: {reviewLogo?.label??'No current selectable review'}. Conditions: {reviewLogo?.conditions??'Refresh authority and choose a current approved image or protected text identity.'} {reviewLogo?'Review expiry: '+new Date(reviewLogo.expiresAt).toLocaleString('en-PH',{timeZone:'Asia/Manila'}):''}</p>:null}<TextField id="site-publication-reason" label="Reason for site publication" maxLength={2000} disabled={mem.locked} value={mem.fields.reason} onChange={e=>mem.change({...mem.fields,reason:e.target.value})}/><label><input type="checkbox" checked={ack} disabled={mem.locked} onChange={e=>setAck(e.target.checked)}/>I reviewed the exact diff, synthetic role previews and any MCD conditions</label><button className="button" disabled={disabled||mem.locked||dirty||stale||currentReview.stale||!!currentReview.proposed.logo&&!reviewLogo||!ack||!mem.fields.reason.trim()} onClick={()=>void publish()}>Publish reviewed site presentation</button></section>:null}
  <details><summary>Site publication history and restore</summary><p>Restore selects an immutable snapshot as a private draft. Save, preview and explicitly publish it as a new version; history never changes.</p>{history.map(h=><section key={h.id}><h3>Version {h.version}</h3><p>{h.reason}</p>{!h.supported?<p>This older snapshot uses unsupported fields and cannot be restored. Keep the current draft or select a supported version.</p>:null}<button className="button button--secondary" disabled={disabled||mem.locked||!h.supported} onClick={()=>{mem.change({...mem.fields,definition:text(h.definition),base:String(data.version),version:String(data.draft?.version??0),rollback:h.id});setReview(null);setAck(false)}}>Restore site version {h.version} as private draft</button></section>)}{before?<button className="button button--secondary" disabled={disabled||mem.locked||checking} onClick={()=>{setChecking(true);void api.read(term,before).then(v=>{if(!alive.current)return;setHistory([...history,...(v.history??[])]);setBefore(v.nextBefore??null)}).catch(e=>{if(!alive.current)return;setError('Older history unavailable. Current inputs are kept.');if(e?.denied)denied()}).finally(()=>{if(alive.current)setChecking(false)})}}>Load older site history</button>:null}</details>
  </>:null}
  {mem.pending?<button className="button" disabled={mem.busy||disabled} onClick={()=>void save(true)}>Retry identical wording save</button>:null}
  {mem.error?<p role="alert">{mem.error} Private inputs are kept unless current authority is denied.</p>:null}
  {error?<p role="alert">{error}</p>:null}
 </div>
}
