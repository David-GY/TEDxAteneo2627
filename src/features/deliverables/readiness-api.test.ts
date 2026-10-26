import {expect,it,vi} from 'vitest'
import {createReadinessApi,type ReadinessCommand} from './readiness-api'
import type {createSupabaseClient} from '../../lib/supabase'
it('readiness acceptance requires a canonical advancing receipt and recovers the identical command',async()=>{
 const input:ReadinessCommand={kind:'accept',id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',version:2,criteriaRevision:1,fingerprint:'f'.repeat(64),evidence:'Exact evidence inspected',reason:'Independent current criteria verified'},key='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',rpc=vi.fn().mockResolvedValueOnce({data:{workItemId:input.id,version:3,state:'accepted'},error:null}).mockResolvedValue({data:{workItemId:input.id,version:3,state:'accepted',eventId:'cccccccc-cccc-4ccc-8ccc-ccccccccccc1'},error:null}),api=createReadinessApi(Promise.resolve({rpc})as unknown as ReturnType<typeof createSupabaseClient>);
 const uncertain=await api.run(input,key);expect(uncertain.ok).toBe(false);if(!uncertain.ok)expect(uncertain.error.retryable).toBe(true);expect((await api.run(input,key)).ok).toBe(true);expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1]);expect(rpc.mock.calls[0][0]).toBe('accept_deliverable');expect(rpc.mock.calls[0][1]).toMatchObject({p_request_id:key,p_fingerprint:input.fingerprint,p_criteria_revision:1,p_evidence:input.evidence})
})
