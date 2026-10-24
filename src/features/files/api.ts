import type {createSupabaseClient} from '../../lib/supabase'
import {mapCommandError,type CommandResult} from '../../lib/commands'
export type Asset={id:string;origin_work_item_id:string;kind:'upload'|'working_link';filename:string;mime_type:string|null;size_bytes:number|null;sha256:string|null;state:'validated'|'finalized'|'working';version:number;source_url:string|null;access_notes:string|null;source_label:string|null}
export type ManifestEntry={assetId:string;sha256:string;size:number;mime:string;classification:'ordinary'|'restricted';source:{assetId:string;version:number;url:string;label:string;accessNotes:string}|null}
export type Manifest={id:string;sha256:string;size_bytes:number;created_at:string;entries:ManifestEntry[]}
export type FilesPage={assets:Asset[];manifests:Manifest[];workVersion:number;canEdit:boolean}
export type FileAction={kind:'upload';workId:string;version:number;file:File;sourceId:string|null;sourceVersion:number|null}|{kind:'finalize';workId:string;version:number;assetIds:string[]}|{kind:'link';workId:string;assetId:string|null;version:number;url:string;name:string;notes:string;label:string}
export interface FilesApi{read(id:string):Promise<FilesPage|null>;execute(input:FileAction,key:string):Promise<CommandResult<Record<string,unknown>>>;download(workId:string,assetId:string):Promise<Blob>;open(workId:string,assetId:string):Promise<string>}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const hash=/^[0-9a-f]{64}$/
function entry(e:ManifestEntry){return e&&uuid.test(e.assetId)&&hash.test(e.sha256)&&Number.isInteger(e.size)&&e.size>0&&['application/pdf','image/jpeg','image/png'].includes(e.mime)&&['ordinary','restricted'].includes(e.classification)&&(e.source===null||e.source&&uuid.test(e.source.assetId)&&Number.isInteger(e.source.version)&&e.source.version>0&&typeof e.source.url==='string'&&typeof e.source.label==='string'&&typeof e.source.accessNotes==='string')}
export function createFilesApi(ready:ReturnType<typeof createSupabaseClient>):FilesApi{
 async function client(){const c=await ready;if(!c)throw{code:'COMMAND_UNAVAILABLE'};return c}
 async function edge(body:FormData|Record<string,unknown>){const {data,error}=await(await client()).functions.invoke('files',{body});if(error){if(error.context instanceof Response){const value=await error.context.json().catch(()=>null);throw value?.error??{code:'COMMAND_UNAVAILABLE'}}throw{code:'COMMAND_UNAVAILABLE'}}return data}
 return{
 async read(id){const{data,error}=await(await client()).rpc('read_files',{p_work_item_id:id});if(error)throw new Error('Files unavailable');if(data===null)return null;const r=data as unknown as FilesPage;if(!r||!Number.isInteger(r.workVersion)||r.workVersion<1||typeof r.canEdit!=='boolean'||!Array.isArray(r.assets)||!r.assets.every(a=>a&&uuid.test(a.id)&&uuid.test(a.origin_work_item_id)&&typeof a.filename==='string'&&['upload','working_link'].includes(a.kind)&&['validated','finalized','working'].includes(a.state)&&Number.isInteger(a.version)&&a.version>0&&(a.kind==='upload'?typeof a.sha256==='string'&&hash.test(a.sha256)&&Number.isInteger(a.size_bytes)&&a.size_bytes!>0:a.state==='working'&&typeof a.source_url==='string'&&typeof a.access_notes==='string'&&typeof a.source_label==='string'))||!Array.isArray(r.manifests)||!r.manifests.every(m=>m&&uuid.test(m.id)&&hash.test(m.sha256)&&Number.isInteger(m.size_bytes)&&Number.isFinite(Date.parse(m.created_at))&&Array.isArray(m.entries)&&m.entries.every(entry)))throw new Error('Files unavailable');return r},
 async execute(input,key){try{let r:unknown
 if(input.kind==='upload'){const body=new FormData();body.set('file',input.file);body.set('metadata',JSON.stringify({workId:input.workId,version:input.version,key,sourceId:input.sourceId,sourceVersion:input.sourceVersion}));r=await edge(body)}
 else if(input.kind==='finalize'){const {data,error}=await(await client()).rpc('finalize_upload',{p_work_item_id:input.workId,p_asset_ids:input.assetIds,p_expected_version:input.version,p_request_id:key});if(error)throw error;r=data}
 else{const {data,error}=await(await client()).rpc('save_working_link',{p_work_item_id:input.workId,p_asset_id:input.assetId!,p_url:input.url,p_name:input.name,p_notes:input.notes,p_label:input.label,p_expected_version:input.version,p_request_id:key});if(error)throw error;r=data}
 if(!r||typeof r!=='object')throw{code:'COMMAND_UNAVAILABLE'};const value=r as Record<string,unknown>;if(input.kind==='finalize'?!uuid.test(String(value.manifestId))||!hash.test(String(value.sha256)):!uuid.test(String(value.assetId))||!Number.isInteger(value.version))throw{code:'COMMAND_UNAVAILABLE'};return{ok:true,value}
 }catch(e){return{ok:false,error:mapCommandError(e)}}},
 async download(workId,assetId){const value=await edge({action:'download',workId,assetId,key:crypto.randomUUID()});if(!(value instanceof Blob)||value.size>5242880||value.size===0)throw new Error('File unavailable');return value},
 async open(workId,assetId){const value=await edge({action:'open',workId,assetId,key:crypto.randomUUID()});if(!value||typeof value.url!=='string')throw new Error('Source unavailable');return value.url},
 }
}
