import {it,expect,vi} from 'vitest'
import {createFinAuthorityApi,type FinCommand} from './authority-api'
import type {createSupabaseClient} from '../../lib/supabase'
it('P26 malformed plausible decision receipt stays uncertain',async()=>{
 const rpc=vi.fn().mockResolvedValue({data:{version:4},error:null}),api=createFinAuthorityApi(Promise.resolve({rpc})as unknown as ReturnType<typeof createSupabaseClient>),command:FinCommand={kind:'decide',id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',revision:1,version:3,action:'approve',reason:'Reviewed',ceiling:'5000',conditions:'Partial only',expiresAt:'2027-04-10T15:59:00Z',externalOutcome:'not_required',manifest:null};const result=await api.run(command,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1');expect(result.ok).toBe(false);if(!result.ok)expect(result.error.retryable).toBe(true);expect(rpc.mock.calls[0][0]).toBe('decide_finance_request');expect(rpc.mock.calls[0][1].p_ceiling_centavos).toBe('5000');expect(rpc.mock.calls[0][1].p_expected_revision).toBe(1)
})
it('P26 FIN deep link survives sign-in with private query stripped',async()=>{
 const{safeReturnPath}=await import('../auth/redirects'),path='/finance/reviews/22222222-2222-4222-8222-222222222221/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';expect(safeReturnPath(path+'?private=hidden')).toBe(path)
})
