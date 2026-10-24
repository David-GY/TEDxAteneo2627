import { expect, it, vi } from 'vitest'
import { createProfileGateway } from './gateway'
import type { createSupabaseClient } from '../../lib/supabase'

const own = { memberId:'fictional',displayName:'Fictional member',version:1,course:null,yearLevel:null,phone:null,externalContact:null,shareCourse:false,shareYearLevel:false,sharePhone:false,shareExternalContact:false }
function ready(rpc: ReturnType<typeof vi.fn>) { return Promise.resolve({ rpc }) as unknown as ReturnType<typeof createSupabaseClient> }
it('sends distinct value/visibility RPCs with expected version and unchanged retry key',async()=>{
  const rpc=vi.fn(async()=>({data:own,error:null}))
  const gateway=createProfileGateway(ready(rpc))
  await gateway.save('term',{course:null,yearLevel:null,phone:null,externalContact:null},0,'request')
  expect(rpc).toHaveBeenLastCalledWith('save_private_profile',{p_term_id:'term',p_values:{course:null,yearLevel:null,phone:null,externalContact:null},p_expected_version:0,p_request_id:'request'})
  await gateway.share('term',{shareCourse:false,shareYearLevel:false,sharePhone:false,shareExternalContact:false},1,'share-request')
  expect(rpc).toHaveBeenLastCalledWith('set_profile_visibility',{p_term_id:'term',p_visibility:{shareCourse:false,shareYearLevel:false,sharePhone:false,shareExternalContact:false},p_expected_version:1,p_request_id:'share-request'})
})
it('sanitizes backend details while distinguishing version and permission recovery',async()=>{
  const rpc=vi.fn().mockResolvedValueOnce({data:null,error:{code:'40001',message:'RAW PRIVATE BODY'}})
    .mockResolvedValueOnce({data:null,error:{code:'42501',message:'RAW PRIVATE BODY'}})
    .mockRejectedValueOnce(new Error('RAW PRIVATE BODY'))
  const gateway=createProfileGateway(ready(rpc))
  const values={course:null,yearLevel:null,phone:null,externalContact:null}
  await expect(gateway.save('term',values,1,'a')).rejects.toThrow('changed elsewhere')
  await expect(gateway.save('term',values,1,'b')).rejects.toThrow('term is frozen')
  await expect(gateway.save('term',values,1,'c')).rejects.toThrow('could not be confirmed')
})
it('rejects denied/malformed owner reads rather than offering empty editable defaults',async()=>{
  const rpc=vi.fn().mockResolvedValueOnce({data:null,error:null}).mockResolvedValueOnce({data:{...own,sharePhone:'true'},error:null})
  const gateway=createProfileGateway(ready(rpc))
  await expect(gateway.read('term')).rejects.toThrow('could not be loaded')
  await expect(gateway.read('term')).rejects.toThrow('could not be loaded')
})
