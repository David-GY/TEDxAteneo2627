import{expect,it}from'vitest'
import{createReportsApi}from'./api'
import type{createSupabaseClient}from'../../lib/supabase'
it('rejects incomplete metrics and cross-scope links instead of rendering misleading values',async()=>{
 const term='22222222-2222-4222-8222-222222222221',id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',value={asOf:'2026-10-30T00:00:00Z',week:'2026-10-26',weekEnd:'2026-11-01',timezone:'Asia/Manila',units:[],summary:{total:0},usage:{state:'unconfigured'},items:[],total:0,nextAfter:null}
 function api(data:unknown){return createReportsApi(Promise.resolve({rpc:async()=>({data,error:null})})as unknown as ReturnType<typeof createSupabaseClient>)}
 await expect(api(value).read(term,value.week,null,'all')).rejects.toThrow()
 const valid={...value,summary:{total:1,open:1,overdue:0,originalOverdue:1,blocked:0,assignedOpen:0,unassignedOpen:0,readyDeliverables:0},items:[{id,kind:'deliverable',title:'Signage',reference:'DEL-027',state:'in_progress',dueOn:null,dueAt:null,originalDueOn:null,originalDueAt:null,overdue:false,originalOverdue:false,blockedSince:null,blockedDays:null,checksMet:false,href:'/deliverables/'+id+'?term='+term}]}
 expect((await api(valid).read(term,value.week,null,'all')).items[0].title).toBe('Signage')
 for(const href of ['https://example.invalid','/deliverables/'+id+'?term='+id])await expect(api({...valid,items:[{...valid.items[0],href}]}).read(term,value.week,null,'all')).rejects.toThrow()
 const badDate=createReportsApi(Promise.resolve({rpc:async()=>({data:null,error:{code:'22007'}})})as unknown as ReturnType<typeof createSupabaseClient>);await expect(badDate.read(term,'',null,'all')).rejects.toMatchObject({kind:'validation'})
})
