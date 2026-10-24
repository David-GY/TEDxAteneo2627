import type { createSupabaseClient } from '../../lib/supabase'
export type OwnedTask={id:string;title:string;summary:string;dueOn:string|null;dueAt:string|null;category:string;overdue:boolean}
export interface TasksApi{read(termId:string,page:number):Promise<{items:OwnedTask[];total:number;page:number}>}
export function createTasksApi(ready:ReturnType<typeof createSupabaseClient>):TasksApi{
  return{async read(termId,page){try{
    const client=await ready;if(!client)throw new Error()
    const{data,error}=await client.rpc('read_owned_tasks',{p_term_id:termId,p_page:page})
    const r=data as unknown as {items:OwnedTask[];total:number;page:number}|null
    if(error||!r||!Array.isArray(r.items)||!Number.isSafeInteger(r.total)||r.total<0||r.page!==page||!r.items.every(t=>t&&/^[0-9a-f-]{36}$/i.test(t.id)&&typeof t.title==='string'&&typeof t.summary==='string'&&typeof t.overdue==='boolean'&&['draft','active','needs_revision','approved','completed','rejected','cancelled'].includes(t.category)&&[t.dueOn,t.dueAt].every(d=>d===null||typeof d==='string')))throw new Error()
    return r
  }catch{throw new Error('Owned tasks could not load. Check access or connection and reload.')}}}
}
