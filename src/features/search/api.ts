import type {createSupabaseClient} from '../../lib/supabase'
import type {Json} from '../../lib/database.types'
export type SearchRow={id:string;kind:'task'|'deliverable';title:string;reference:string|null;termId:string;termLabel:string;href:string}
export type SearchResult={items:SearchRow[];total:number;nextCursor:{after:string;scope:string}|null}
export interface SearchApi{read(term:string,query:string,kind:string,cursor:SearchResult['nextCursor']):Promise<SearchResult>}
export class SearchError extends Error{constructor(public denied:boolean){super('Search unavailable')}}
const uuid=(x:unknown)=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x)
export function createSearchApi(ready:ReturnType<typeof createSupabaseClient>):SearchApi{return{async read(term,query,kind,cursor){const c=await ready;if(!c)throw new SearchError(false);const{data,error}=await c.rpc('search_workspace',{p_term_id:term,p_query:query,p_filters:{kind},p_cursor:cursor as Json});if(error)throw new SearchError(error.code==='42501');const v=data as unknown as SearchResult;
 if(!v||!Array.isArray(v.items)||v.items.length>20||!Number.isSafeInteger(v.total)||v.total<0||!v.items.every(r=>r&&uuid(r.id)&&['task','deliverable'].includes(r.kind)&&r.termId===term&&typeof r.title==='string'&&typeof r.termLabel==='string'&&(r.reference===null||typeof r.reference==='string'&&new RegExp(r.kind==='task'?'^TASK-[0-9]{3,}$':'^DEL-[0-9]{3,}$').test(r.reference))&&r.href===(r.kind==='task'?'/tasks/':'/deliverables/')+r.id)||v.nextCursor!==null&&(!uuid(v.nextCursor.after)||!/^[0-9a-f]{64}$/.test(v.nextCursor.scope)))throw new SearchError(false);return v}}}
