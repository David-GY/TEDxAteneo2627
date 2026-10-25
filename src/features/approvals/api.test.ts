import {describe,it,expect,vi} from 'vitest'
import type {createSupabaseClient} from '../../lib/supabase'
import {createApprovalsApi,type TransitionRequest} from './api'
const input:TransitionRequest={requestId:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',assignmentId:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',revision:2,stageKey:'review',version:7,action:'approve',reason:'Exact reviewed revision',evidenceManifestId:null,key:'cccccccc-cccc-4ccc-8ccc-cccccccccccc'}
describe('P22 approval command boundary',()=>{
 it('derives no actor from the caller, pins revision/stage/version and preserves exact retry details',async()=>{
  const rpc=vi.fn(async()=>({data:null,error:{code:'40001'}})),api=createApprovalsApi(Promise.resolve({rpc})as unknown as ReturnType<typeof createSupabaseClient>);const r=await api.transition(input);expect(r.ok).toBe(false);if(!r.ok)expect(r.error.kind).toBe('stale_version');await api.transition(input);expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1]);expect(rpc.mock.calls[0]).toEqual(['transition_request',{p_work_item_id:input.requestId,p_assignment_id:input.assignmentId,p_expected_revision:2,p_expected_stage:'review',p_expected_version:7,p_action:'approve',p_reason:input.reason,p_evidence_manifest_id:null,p_request_id:input.key}]);
 });
 it('treats malformed success as uncertain, never an accepted decision, and preserves denied reads',async()=>{
  const api=createApprovalsApi(Promise.resolve({rpc:async()=>({data:{state:'approved'},error:null})})as unknown as ReturnType<typeof createSupabaseClient>);const r=await api.transition(input);expect(r.ok).toBe(false);if(!r.ok)expect(r.error.retryable).toBe(true);await expect(api.read('term',input.requestId)).rejects.toThrow('could not load');
  const denied=createApprovalsApi(Promise.resolve({rpc:async()=>({data:null,error:null})})as unknown as ReturnType<typeof createSupabaseClient>);expect(await denied.read('term',input.requestId)).toBeNull();
 });
})
