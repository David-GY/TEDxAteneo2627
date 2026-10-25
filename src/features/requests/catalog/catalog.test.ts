import {describe,it,expect} from 'vitest'
import {createCatalogApi,safeOfficialUrl} from './api'
import type {createSupabaseClient} from '../../../lib/supabase'
describe('P19 catalog boundary',()=>{
 it('rejects executable/credential URLs and malformed provider results instead of presenting a catalog',async()=>{
  expect(safeOfficialUrl('javascript:alert(1)')).toBe(false);expect(safeOfficialUrl('https://password@school.invalid')).toBe(false);expect(safeOfficialUrl('https://school.invalid/process')).toBe(true);
  const ready=Promise.resolve({rpc:async()=>({data:{items:[{label:'Forged service'}]},error:null})}) as unknown as ReturnType<typeof createSupabaseClient>;
  await expect(createCatalogApi(ready).read('term')).rejects.toThrow('could not load');
 });
 it('preserves denied and unavailable states without fictional fallback entries',async()=>{
  const denied=Promise.resolve({rpc:async()=>({data:null,error:null})}) as unknown as ReturnType<typeof createSupabaseClient>;
  expect(await createCatalogApi(denied).read('term')).toBeNull();await expect(createCatalogApi(Promise.resolve(null)).read('term')).rejects.toThrow('could not load');
 });
})
