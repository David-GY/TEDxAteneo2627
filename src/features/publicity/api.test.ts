import {describe,it,expect} from 'vitest'
import {createPublicityApi} from './api'
import type {createSupabaseClient} from '../../lib/supabase'
import {safeReturnPath} from '../auth/redirects'
describe('P28 exact confirmation',()=>{
 it('keeps plausible MCD success without exact decision/approval uncertain',async()=>{const api=createPublicityApi(Promise.resolve({rpc:async()=>({data:{requestId:'11111111-1111-4111-8111-111111111111',revision:1,version:9},error:null})})as unknown as ReturnType<typeof createSupabaseClient>);const r=await api.run({kind:'decide',id:'11111111-1111-4111-8111-111111111111',revision:1,version:8,action:'approve',reason:'Reviewed',conditions:'Exact use',expiresAt:'2027-04-10T10:00:00Z'},'same-key');expect(r.ok).toBe(false);if(!r.ok)expect(r.error.retryable).toBe(true)});
 it('allows only the exact publicity return path and strips query evidence',()=>{expect(safeReturnPath('/publicity/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222?caption=private')).toBe('/publicity/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222');expect(safeReturnPath('//external/publicity')).toBe('/')})
})
