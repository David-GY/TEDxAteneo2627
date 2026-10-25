import {describe,it,expect} from 'vitest'
import {createLedgerApi,type LedgerCommand} from './ledger-api'
import type {createSupabaseClient} from '../../lib/supabase'
describe('P27 confirmed ledger receipts',()=>{
 it('keeps plausible but incomplete booking success uncertain for identical recovery',async()=>{
  const calls:unknown[]=[],input:LedgerCommand={kind:'actual',id:'11111111-1111-4111-8111-111111111111',type:'expense',amount:'1234',evidence:'22222222-2222-4222-8222-222222222222',reference:'receipt A',on:'2026-10-25',reason:'Documented',version:8};
  const api=createLedgerApi(Promise.resolve({rpc:async(name:string,args:unknown)=>{calls.push([name,args]);return{data:{version:9,requestId:input.id,state:'booked'},error:null}}})as unknown as ReturnType<typeof createSupabaseClient>);
  const result=await api.run(input,'same-key');expect(result.ok).toBe(false);if(!result.ok)expect(result.error.retryable).toBe(true);await api.run(input,'same-key');expect(calls[0]).toEqual(calls[1]);
 });
 it('rejects a reversal receipt for another record',async()=>{
  const api=createLedgerApi(Promise.resolve({rpc:async()=>({data:{version:10,recordId:'22222222-2222-4222-8222-222222222222',state:'reversed'},error:null})})as unknown as ReturnType<typeof createSupabaseClient>);
  const result=await api.run({kind:'reconcile',id:'11111111-1111-4111-8111-111111111111',action:'reverse',reason:'Correction',version:9},'key');expect(result.ok).toBe(false);if(!result.ok)expect(result.error.retryable).toBe(true);
 });
})
