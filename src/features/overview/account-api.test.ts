import {expect,it} from 'vitest'
import {createAccountLayoutApi} from './account-api'
it('a retired account view remains visible for archival while its widget definition cannot be applied',async()=>{
 const api=createAccountLayoutApi(Promise.resolve({rpc:async()=>({data:{source:'default',layout:null,repaired:false,ambiguous:false,views:[{viewId:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',version:1,name:'Old planning view',layout:{version:1,widgets:[{id:'retired',size:'wide'}]}}]},error:null})})as unknown as Parameters<typeof createAccountLayoutApi>[0])
 const result=await api.read('term');expect(result.views[0].supported).toBe(false);expect(result.repaired).toBe(true);expect(result.views[0].name).toBe('Old planning view')
})
