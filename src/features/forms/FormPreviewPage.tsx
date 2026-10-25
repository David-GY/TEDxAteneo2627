import {useEffect,useState} from 'react'
import {Link,useParams,useRouteLoaderData,useSearchParams} from 'react-router'
import {PageHeading} from '../../components/Page'
import {LoadingState,ErrorState,EmptyState} from '../../components/FeedbackState'
import type {WorkspaceContext} from '../auth/gateway'
import type {CatalogApi,CatalogEntry} from '../requests/catalog/api'
import type {FilesApi} from '../files/api'
import {Files} from '../files/Files'
import {FormRenderer} from './FormRenderer'
import type {FormsApi} from './api'
import type {FormOptions} from './validation'
import './forms.css'
export function FormPreviewPage({api,catalog,files}:{api:FormsApi;catalog:CatalogApi;files?:FilesApi}){
 const context=useRouteLoaderData('workspace') as WorkspaceContext,{typeId=''}=useParams(),[params]=useSearchParams(),workId=params.get('workId')??undefined,[retry,setRetry]=useState(0);
 const identity=context.termId+('memberId'in context?context.memberId:context.guestAccessId),key=identity+typeId+workId+retry;
 const[state,setState]=useState<{key:string;entry:CatalogEntry|null;options:FormOptions|null;error:boolean}|null>(null);
 useEffect(()=>{let live=true;void Promise.all([catalog.read(context.termId,typeId),api.options(context.termId,typeId,workId)]).then(([rows,options])=>{if(live)setState({key,entry:rows?.[0]??null,options,error:false})}).catch(()=>{if(live)setState({key,entry:null,options:null,error:true})});return()=>{live=false}},[api,catalog,context.termId,typeId,workId,key]);
 const current=state?.key===key?state:null;
 return <><PageHeading title="Check configured form" description="Try the published fields and current validation. This preview does not save a draft, submit a case or grant approval."/><p><Link to={'/requests/services/'+typeId}>Back to service requirements</Link></p><button className="button button--secondary" onClick={()=>setRetry(n=>n+1)}>Refresh current choices</button>
 {!current?<LoadingState/>:current.error?<ErrorState title="Form unavailable" description="Check current access or connection, then refresh. Inputs remain in memory for this account and version."/>:!current.entry?.form||!current.options?<EmptyState title="This form cannot be shown" description="A current published definition and authorized scope are required."/>:<>
 <h2>{current.entry.label} · version {current.entry.formVersion}</h2><p>{current.entry.processNote}</p>
 <FormRenderer key={identity+current.entry.formVersionId+workId} definition={current.entry.form} restricted={current.entry.classification==='restricted'} options={current.options} draftKey={current.entry.formVersionId+':'+(workId??'none')} validate={(values,centavos)=>api.validate(context.termId,typeId,current.entry!.formVersionId,values,centavos,workId)}/>
 {current.entry.form.fields.some(f=>f.type==='file')?<p>{workId?'Finalized-file choices are scoped to the selected work. After upload/finalization, refresh current choices.':'No origin work is selected. File inputs require an independently authorized work record; no bytes are uploaded by this preview.'}</p>:null}
 {workId&&files?<Files api={files} workId={workId}/>:null}
 </>}
 </>
}
