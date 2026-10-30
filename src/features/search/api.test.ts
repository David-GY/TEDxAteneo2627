import {expect,it} from 'vitest'
import {createSearchApi} from './api'
import type {createSupabaseClient} from '../../lib/supabase'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',term='22222222-2222-4222-8222-222222222221'
function api(item:unknown){return createSearchApi(Promise.resolve({rpc:async()=>({data:{items:[item],total:1,nextCursor:null},error:null})})as unknown as ReturnType<typeof createSupabaseClient>)}
it('accepts only canonical source routes in the requested term',async()=>{
 for(const[kind,href,reference]of[['request',`/requests/${term}/${id}?term=${term}`,'LOCAL_DUAL-027'],['guide',`/resources?resource=${id}&term=${term}`,null],['glossary',`/resources?resource=${id}&term=${term}`,null],['contact',`/people?contact=${id}&term=${term}`,null]]){
  const row={id,kind,href,reference,title:'Find signage help',termId:term,termLabel:'Fictional term',matchedAlias:'old event team'}
  expect((await api(row).read(term,'signage','all',null)).items[0].href).toBe(href)
  for(const changed of [{href:'https://example.invalid'}, {termId:id},{kind:'finance'},{matchedAlias:17}])await expect(api({...row,...changed}).read(term,'signage','all',null)).rejects.toThrow()
 }
})
