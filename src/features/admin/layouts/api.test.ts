import {expect,it} from 'vitest'
import {createLayoutAdminApi} from './api'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',target={kind:'unit' as const,id,label:'Fictional unit'}
it('retired current definitions remain reviewable for repair without presenting them as valid rollback candidates',async()=>{
 const retired={version:1,widgets:[{id:'retired',size:'wide'}]}
 const response={version:2,definition:retired,drafts:[],history:[{id,version:2,definition:retired,rollbackVersionId:null,reason:'Fictional old layout'}],nextBefore:null}
 const api=createLayoutAdminApi(Promise.resolve({rpc:async()=>({data:response,error:null})})as unknown as Parameters<typeof createLayoutAdminApi>[0])
 const result=await api.read(id,target)
 expect(result.repaired).toBe(true);expect(result.history[0].supported).toBe(false)
})
