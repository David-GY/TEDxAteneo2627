import {describe,it,expect} from 'vitest'
import {createResourcesApi} from './api'
import type {createSupabaseClient} from '../../lib/supabase'
function api(data:unknown,error:unknown=null){return createResourcesApi(Promise.resolve({rpc:async()=>({data,error})})as unknown as ReturnType<typeof createSupabaseClient>)}
const empty={items:[],drafts:[],progress:[],checklistVersion:1,canPublishCore:false,managedUnits:[]}
describe('P32 gateway boundary',()=>{
 it('rejects unconfirmed schemas and unsafe related URLs',async()=>{await expect(api({...empty,items:[{links:[{href:'https://evil.invalid'}]}]}).read('term')).rejects.toThrow();await expect(api({...empty,progress:[{item:'profile',revision:0,state:'done',version:1}]}).read('term')).rejects.toThrow();await expect(api(null).read('term')).rejects.toThrow();expect(await api(empty).read('term')).toEqual(empty)})
 it('returns uncertainty and conflict without fabricated mutation success',async()=>{const cmd={kind:'progress' as const,term:'term',item:'profile',revision:1,state:'done' as const,version:0};expect((await api(null).run(cmd,'key')).ok).toBe(false);expect((await api(null,{code:'40001'}).run(cmd,'key'))).toMatchObject({ok:false,error:{kind:'stale_version',retryable:false}});expect((await api({version:1}).run(cmd,'key'))).toEqual({ok:true,value:{version:1}})})
})
