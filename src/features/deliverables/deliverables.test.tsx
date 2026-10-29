import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { expect, it, vi } from 'vitest'
import { createAppRoutes } from '../../app/router'
import { readClientEnvironment } from '../../lib/env'
import type { AuthGateway, WorkspaceContext } from '../auth/gateway'
import { createDeliverablesApi, filterSearch, parseFilters, type Deliverable, type DeliverablesApi } from './api'
import type { createSupabaseClient } from '../../lib/supabase'
import { safeReturnPath } from '../auth/redirects'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'
const item:Deliverable={id,termId:id,title:'Fictional output',summary:'Safe summary',owner:{id,name:'Fictional owner',active:true},leadUnit:null,supportingUnits:[],phase:null,dueAt:null,dueOn:null,originalDueAt:null,originalDueOn:null,overdue:false,blocked:false,blocker:null,readiness:'pending_gate_verification',nextAction:'Confirm required reviews.',gates:{finance:'pending_assessment',publicity:'pending_assessment',acceptance:'pending_definition'},updatedAt:'2026-10-24T00:00:00Z',archivedAt:null,version:1}
const core:WorkspaceContext={state:'authorized',memberId:id,organizationId:id,termId:id,termMembershipId:id,displayName:'Fictional viewer',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:['workspace.read']}
it('P36_U2: an authorized title keeps its UUID link while copy reference includes the term; failed copying never reports success',async()=>{
 const writeText=vi.fn(async()=>{});Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText}})
 const referenced={...item,reference:{value:'DEL-012',termId:id,termLabel:'2026–27'}}
 const router=setup({list:async()=>({items:[referenced],total:1,page:1,pageSize:20,options:{phases:[],units:[],owners:[]}}),read:async()=>({...referenced,details:null})})
 const title=await screen.findByRole('link',{name:'Fictional output'});expect(title.getAttribute('href')).toBe('/deliverables/'+id);await screen.findByText('DEL-012');fireEvent.click(title)
 await screen.findByRole('heading',{name:'Fictional output'});fireEvent.click(await screen.findByRole('button',{name:'Copy reference'}));await screen.findByText('Reference copied.');expect(writeText).toHaveBeenLastCalledWith('DEL-012 · 2026–27')
 fireEvent.click(screen.getByRole('button',{name:'Copy link'}));await screen.findByText('Link copied.');expect(writeText).toHaveBeenLastCalledWith(new URL('/deliverables/'+id,window.location.origin).href);expect(router.state.location.pathname).toBe('/deliverables/'+id)
 writeText.mockRejectedValueOnce(Error('Clipboard unavailable'));fireEvent.click(screen.getByRole('button',{name:'Copy reference'}));await screen.findByText('Copy unavailable. Select the reference or link below to copy.');expect(screen.queryByText('Reference copied.')).toBeNull()
})
it('P36_U2: malformed or wrong-term references cannot masquerade as an issued deliverable reference',async()=>{
 for(const reference of [{value:'TASK-012',termId:id,termLabel:'2026–27'},{value:'DEL-012',termId:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',termLabel:'Another term'}]){
  const api=createDeliverablesApi(Promise.resolve({rpc:vi.fn(async()=>({data:{...item,details:null,reference},error:null}))}) as unknown as ReturnType<typeof createSupabaseClient>)
  await expect(api.read(id)).rejects.toThrow()
 }
})
function setup(api:DeliverablesApi,path='/deliverables',context=core){
  const gateway:AuthGateway={deliverables:api,readContext:async()=>context,onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}}
  const router=createMemoryRouter(createAppRoutes(readClientEnvironment({}),gateway),{initialEntries:[path]})
  render(<RouterProvider router={router}/>);return router
}
it('P08_A2/A3: URL filters reset pagination, stable detail link and back link preserve scope; summary never invents private fields',async()=>{
  const list=vi.fn(async(_term,f)=>({items:f.page===2?[]:[item],total:1,page:f.page,pageSize:20,options:{phases:[],units:[],owners:[]}}))
  const api:DeliverablesApi={list,read:async()=>({...item,details:null})}
  const router=setup(api,'/deliverables?page=2')
  await screen.findByLabelText('Involves my committee')
  fireEvent.click(screen.getByLabelText('Involves my committee'))
  fireEvent.click(screen.getByRole('button',{name:'Apply filters'}))
  await screen.findByRole('link',{name:'Fictional output'})
  expect(router.state.location.search).toBe('?mine=1')
  expect(list.mock.calls.at(-1)?.[1]).toMatchObject({mine:true,page:1})
  fireEvent.click(screen.getByRole('link',{name:'Fictional output'}))
  await screen.findByText('Summary access only. Participant details are not shared with your account.')
  expect(router.state.location.pathname).toBe('/deliverables/'+id)
  expect(screen.getByRole('link',{name:'Back to deliverables'}).getAttribute('href')).toBe('/deliverables?mine=1')
  expect(screen.queryByText(/Approved|100%/)).toBeNull()
})
it('P08_A3: list errors clear records and recover; error payload is not displayed',async()=>{
  const list=vi.fn().mockRejectedValueOnce(new Error('PRIVATE payload')).mockResolvedValueOnce({items:[],total:0,page:1,pageSize:20,options:{phases:[],units:[],owners:[]}})
  setup({list,read:async()=>null})
  await screen.findByRole('alert')
  expect(screen.queryByText('PRIVATE payload')).toBeNull()
  fireEvent.click(screen.getByRole('button',{name:'Try again'}))
  await screen.findByRole('heading',{name:'No deliverables match'})
})
it('P08_A1/A3: guest deep link may request only a record; denied response has no full list link',async()=>{
  const read=vi.fn(async()=>null)
  setup({list:vi.fn(),read},'/login?returnTo='+encodeURIComponent('/deliverables/'+id),{state:'authorized',audience:'guest',guestAccessId:id,organizationId:id,termId:id,displayName:'Fictional guest',expiresAt:core.expiresAt,capabilities:[]})
  await screen.findByRole('heading',{name:'Deliverable unavailable'})
  expect(read).toHaveBeenCalledWith(id)
  expect(screen.getByRole('link',{name:'Back to shared with me'}).getAttribute('href')).toBe('/shared')
  expect(screen.queryByRole('link',{name:'Back to deliverables'})).toBeNull()
})
it('P08 stable UUID return paths and filter parsing reject unsafe/invalid values',()=>{
  expect(safeReturnPath('/deliverables/'+id+'?token=secret#fragment')).toBe('/deliverables/'+id)
  expect(safeReturnPath('/deliverables/%2f%2fevil')).toBe('/')
  expect(filterSearch(parseFilters('?page=-1&mine=1&owner=invalid&token=secret'))).toBe('?mine=1')
  expect(parseFilters('?page=10001').page).toBe(1)
})
it('real RPC adapter keeps filters bounded, rejects approval-shaped responses and sanitizes failures',async()=>{
  const rpc=vi.fn().mockResolvedValueOnce({data:{items:[item],total:1,page:1,pageSize:20,options:{phases:[],units:[],owners:[]}},error:null})
    .mockResolvedValueOnce({data:{...item,gates:{...item.gates,finance:'approved'},details:null},error:null})
    .mockResolvedValueOnce({data:null,error:{message:'PRIVATE SQL'}})
  const api=createDeliverablesApi(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>)
  expect((await api.list(id,parseFilters('?mine=1'))).total).toBe(1)
  expect(rpc).toHaveBeenLastCalledWith('list_deliverables',expect.objectContaining({p_involves_my_unit:true,p_page:1,p_page_size:20,p_unit_id:null}))
  await expect(api.read(id)).rejects.toThrow('Deliverables could not be loaded')
  await expect(api.read(id)).rejects.not.toThrow('PRIVATE SQL')
  await expect(api.read('not-a-uuid')).resolves.toBeNull()
  await waitFor(()=>expect(rpc).toHaveBeenCalledTimes(3))
})
