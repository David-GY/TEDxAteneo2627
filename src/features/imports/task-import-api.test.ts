import {expect,it} from 'vitest'
import {createTaskImportsApi} from './task-import-api'
import type {createSupabaseClient} from '../../lib/supabase'
it('rejects forged source links and malformed import receipts; classifies conflicts without losing the caller’s retry data',async()=>{
 const term='22222222-2222-4222-8222-222222222221',id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
 function api(data:unknown,error:unknown=null){return createTaskImportsApi(Promise.resolve({rpc:async()=>({data,error})})as unknown as ReturnType<typeof createSupabaseClient>)}
 const value={draftId:id,version:2,state:'committed',created:1,updated:0,unchanged:0,items:[{sourceKey:'one',workItemId:id,title:'Prepare signage',reference:'TASK-027',version:1,action:'create',href:'/tasks/'+id+'?term='+term}]}
 expect((await api(value).commit(term,id,1,'hash','key')).items[0].reference).toBe('TASK-027')
 await expect(api({...value,items:[{...value.items[0],href:'https://example.invalid'}]}).commit(term,id,1,'hash','key')).rejects.toMatchObject({kind:'connection'})
 await expect(api({...value,created:0}).commit(term,id,1,'hash','key')).rejects.toMatchObject({kind:'connection'})
 await expect(api(null,{code:'40001'}).preview(id,1)).rejects.toMatchObject({kind:'conflict'})
 await expect(api(null,{code:'42501'}).read(term)).rejects.toMatchObject({kind:'denied'})
})
