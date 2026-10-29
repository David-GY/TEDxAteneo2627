import type {createSupabaseClient} from '../../lib/supabase'
export type WorkReferenceValue={value:string;termId:string;termLabel:string}
export type ReferencedWork={id:string;kind:'task'|'deliverable';title:string;reference:WorkReferenceValue}
const uuid=(v:unknown)=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
export function validReferenceText(value:unknown,kind:'task'|'deliverable'){
 if(typeof value!=='string')return false
 const match=value.match(kind==='task'?/^TASK-([0-9]{3,16})$/:/^DEL-([0-9]{3,16})$/)
 if(!match)return false
 const number=Number(match[1]);return Number.isSafeInteger(number)&&number>0&&String(number).padStart(3,'0')===match[1]
}
export function validWorkReference(value:unknown,kind:'task'|'deliverable',term?:string):value is WorkReferenceValue{
 const r=value as WorkReferenceValue|undefined
 return !!r&&validReferenceText(r.value,kind)&&uuid(r.termId)&&(!term||r.termId===term)&&typeof r.termLabel==='string'&&r.termLabel.trim().length>0&&r.termLabel.length<=200
}
// Missing fields keep older provider projections compatible; they never fabricate an issued reference.
export const optionalWorkReference=(value:unknown,kind:'task'|'deliverable',term?:string)=>value===undefined||value===null||validWorkReference(value,kind,term)
export function createWorkReferencesApi(ready:ReturnType<typeof createSupabaseClient>){return{
 async resolve(term:string,kind:'task'|'deliverable',reference:string):Promise<ReferencedWork|null>{
  if(!uuid(term)||!['task','deliverable'].includes(kind)||!validReferenceText(reference,kind))return null
  const c=await ready;if(!c)throw Error('Work reference unavailable')
  const{data,error}=await c.rpc('resolve_work_reference',{p_term_id:term,p_kind:kind,p_reference:reference})
  if(error)throw Error('Work reference unavailable');if(data===null)return null
  const v=data as unknown as ReferencedWork
  if(!v||!uuid(v.id)||v.kind!==kind||typeof v.title!=='string'||!v.title.trim()||v.title.length>240||!validWorkReference(v.reference,kind,term)||v.reference.value!==reference)throw Error('Work reference unavailable')
  return v
 }
}}
