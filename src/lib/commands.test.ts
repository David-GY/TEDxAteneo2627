import { expect, it, vi } from 'vitest'
import { createWorkCommands, mapCommandError } from './commands'
import type { createSupabaseClient } from './supabase'

const workId='11111111-1111-4111-8111-111111111111'
const grantId='22222222-2222-4222-8222-222222222222'
const requestId='33333333-3333-4333-8333-333333333333'
function ready(rpc: ReturnType<typeof vi.fn>) { return Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient> }
it('P07_A2: create preserves request key and explicit parent version; no actor/owner/status input is forwarded',async()=>{
  const rpc=vi.fn(async()=>({data:{workItemId:workId,version:1,kind:'task'},error:null}))
  const commands=createWorkCommands(ready(rpc))
  const input={termId:workId,kind:'task' as const,title:'Fictional draft',safeSummary:'Safe summary',body:'Private details',classification:'restricted' as const,parent:{id:grantId,expectedVersion:3},requestId}
  expect(await commands.create(input)).toEqual({ok:true,value:{workItemId:workId,version:1,kind:'task'}})
  await commands.create(input)
  expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1])
  expect(rpc).toHaveBeenCalledWith('create_work_item',{p_term_id:workId,p_kind:'task',p_title:'Fictional draft',p_safe_summary:'Safe summary',p_body:'Private details',p_classification:'restricted',p_lead_unit_id:null,p_parent_id:grantId,p_expected_parent_version:3,p_request_id:requestId})
})
it('P07_A3: update conflict is explicit, sanitized and never automatically retried',async()=>{
  const rpc=vi.fn(async()=>({data:null,error:{code:'40001',message:'PRIVATE SQL title/body',details:'protected record'}}))
  const result=await createWorkCommands(ready(rpc)).update({workItemId:workId,title:'Edit',safeSummary:'',body:'',expectedVersion:3,requestId})
  expect(result).toEqual({ok:false,error:{kind:'stale_version',message:'This record changed. Reload it before applying your edit.',retryable:false}})
  expect(JSON.stringify(result)).not.toContain('PRIVATE')
  expect(rpc).toHaveBeenCalledTimes(1)
})
it('preserves exactly one record principal, expiry and optimistic version for grant/revoke',async()=>{
  const rpc=vi.fn(async()=>({data:{workItemId:workId,grantId,version:4},error:null}))
  const commands=createWorkCommands(ready(rpc))
  await commands.grant({workItemId:workId,principal:{guestInvitationId:grantId},grantKind:'read',expiresAt:'2026-11-01T00:00:00Z',expectedVersion:3,requestId})
  expect(rpc).toHaveBeenLastCalledWith('grant_work_access',{p_work_item_id:workId,p_member_id:null,p_unit_id:null,p_guest_invitation_id:grantId,p_grant_kind:'read',p_expires_at:'2026-11-01T00:00:00Z',p_expected_version:3,p_request_id:requestId})
  expect(await commands.revoke({grantId,expectedVersion:4,requestId})).toEqual({ok:true,value:{workItemId:workId,grantId,version:4}})
  expect(rpc).toHaveBeenLastCalledWith('revoke_work_access',{p_grant_id:grantId,p_expected_version:4,p_request_id:requestId})
})
it('maps known logical/database errors and hides unknown metadata',()=>{
  for(const [code,kind] of [['42501','permission_denied'],['22023','validation_failed'],['23503','validation_failed'],['23505','conflict'],['55000','dependency_blocked'],['40P01','conflict']]){
    expect(mapCommandError({code,message:'RAW payload',details:'RAW'}).kind).toBe(kind)
    expect(JSON.stringify(mapCommandError({code,message:'RAW payload'}))).not.toContain('RAW')
  }
  expect(mapCommandError({code:'22023',message:'command_idempotency_conflict'}).kind).toBe('idempotency_conflict')
  expect(mapCommandError({code:'55000',message:'command_missing_approver'}).kind).toBe('missing_approver')
  expect(mapCommandError({code:'P0001',message:'command_quota_limit'}).kind).toBe('quota_limit')
  expect(mapCommandError({code:'UNKNOWN',message:'private'}).kind).toBe('unexpected')
})
it('unconfigured/transport failures never claim success, and malformed receipts fail closed',async()=>{
  const input={workItemId:workId,title:'Edit',safeSummary:'',body:'',expectedVersion:1,requestId}
  expect(await createWorkCommands(Promise.resolve(null)).update(input)).toMatchObject({ok:false,error:{kind:'unavailable',retryable:true}})
  const rpc=vi.fn().mockRejectedValueOnce(new Error('private transport body')).mockResolvedValueOnce({data:{workItemId:workId,version:0},error:null})
  const commands=createWorkCommands(ready(rpc))
  expect(await commands.update(input)).toMatchObject({ok:false,error:{kind:'unavailable'}})
  expect(await commands.update(input)).toMatchObject({ok:false,error:{kind:'unexpected',retryable:false}})
})
