import {expect,it,vi} from 'vitest'
import {createFinanceApi} from './api'
import {calculatePlan,emptyPlan} from './intake'
import type {createSupabaseClient} from '../../lib/supabase'
import {safeReturnPath} from '../auth/redirects'
it('malformed finance success is uncertain and retains the exact command contract',async()=>{
 const rpc=vi.fn().mockResolvedValue({data:{state:'approved'},error:null}),api=createFinanceApi(Promise.resolve({rpc})as unknown as ReturnType<typeof createSupabaseClient>),d=emptyPlan('33333333-3333-4333-8333-333333333332');Object.assign(d,{purpose:'Plan',fundSource:'Fund',termsRisks:'Terms'});d.lines=[{description:'Item',quantity:'1',amount:'0'}];const input={id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',values:{purpose:'Envelope'},requestedOn:null,title:'Private',payload:calculatePlan(d).payload!,version:1,revision:false},key='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
 const result=await api.submit(input,key);expect(result.ok).toBe(false);if(!result.ok)expect(result.error.retryable).toBe(true);expect(rpc.mock.calls[0]).toEqual(['submit_finance_request',{p_work_item_id:input.id,p_values:input.values,p_requested_on:null,p_title:'Private',p_finance_payload:input.payload,p_expected_version:1,p_request_id:key,p_revision:false}])
})
it('shared gate rejects extra confidential metadata even in a plausible reply',async()=>{
 const rpc=vi.fn().mockResolvedValue({data:{state:'pending',privateTitle:'PRIVATE'},error:null}),api=createFinanceApi(Promise.resolve({rpc})as unknown as ReturnType<typeof createSupabaseClient>);await expect(api.gate('term','work')).rejects.toThrow()
})
it('finance sign-in return keeps the exact case path and strips query values',()=>{
 const path='/finance/22222222-2222-4222-8222-222222222221/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';expect(safeReturnPath(path+'?private=hidden')).toBe(path)
})
