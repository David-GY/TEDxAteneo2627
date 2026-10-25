import type {createSupabaseClient} from '../../lib/supabase'
import type {FormOptions,FormValues,Validation} from './validation'
import type {Json} from '../../lib/database.types'
export interface FormsApi{options(termId:string,typeId:string,workId?:string):Promise<FormOptions|null>;validate(termId:string,typeId:string,versionId:string,values:FormValues,centavos:number|null,workId?:string):Promise<Validation>}
const object=(x:unknown)=>!!x&&typeof x==='object'&&!Array.isArray(x)
export function createFormsApi(ready:ReturnType<typeof createSupabaseClient>):FormsApi{
 async function client(){const c=await ready;if(!c)throw Error('Connection unavailable');return c}
 return{
 async options(termId,typeId,workId){const{data,error}=await(await client()).rpc('request_form_options',{p_term_id:termId,p_type_id:typeId,p_work_item_id:workId??null});if(error)throw Error('Choices unavailable');if(data===null)return null;const o=data as unknown as FormOptions;if(!o||!['members','units','files'].every(k=>Array.isArray(o[k as keyof FormOptions])&&o[k as keyof FormOptions].length<=200&&o[k as keyof FormOptions].every(x=>typeof x.id==='string'&&typeof x.label==='string')))throw Error('Choices unavailable');return o},
 async validate(termId,typeId,versionId,values,centavos,workId){const{data,error}=await(await client()).rpc('validate_request_form',{p_term_id:termId,p_type_id:typeId,p_form_version_id:versionId,p_values:values as Json,p_requested_centavos:centavos,p_work_item_id:workId??null});if(error)throw Error(error.code==='40001'?'This form version changed. Your inputs are kept; reopen the current requirements before validating again.':'Validation could not complete. Check current access or connection, then retry.');const r=data as unknown as Validation;if(!r||typeof r.valid!=='boolean'||!object(r.errors)||!Object.values(r.errors).every(v=>typeof v==='string')||(r.valid? Object.keys(r.errors).length!==0||!object(r.values)||!object(r.snapshots)||(r.requestedCentavos!==null&&(!Number.isSafeInteger(r.requestedCentavos)||r.requestedCentavos<0)):r.values!==null||r.snapshots!==null||r.requestedCentavos!==null))throw Error('Validation reply unavailable');return r},
 }
}
