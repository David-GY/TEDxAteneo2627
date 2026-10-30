import {render,screen,fireEvent,cleanup} from '@testing-library/react'
import {afterEach,expect,it,vi} from 'vitest'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {LayoutsPage} from './LayoutsPage'
import {FinDecisionMemory} from '../../finance/DecisionMemory'
import {LayoutEditor} from './LayoutEditor'
import type {LayoutAdminApi,LayoutConfiguration} from './api'
afterEach(cleanup)
const layout={version:1 as const,widgets:[{id:'tasks' as const,size:'wide' as const}]}
const data:LayoutConfiguration={version:1,definition:layout,drafts:[{draftId:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',version:2,baseVersion:1,definition:layout,rollbackVersionId:null,publishedVersionId:null}],history:[{id:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',version:1,definition:layout,rollbackVersionId:null,reason:'Fictional first layout'}],nextBefore:null}
it('publication requires an explicit saved preview, current diff acknowledgment and reason',async()=>{
 const run=vi.fn().mockResolvedValue({ok:true,value:{version:2}}),preview=vi.fn().mockResolvedValue({valid:true,version:1,baseVersion:1,stale:false,previous:layout,proposed:layout,reviewHash:'a'.repeat(64),requiredActionsProtected:true,grantsAccess:false})
 const api={run,preview}as unknown as LayoutAdminApi
 render(<LayoutEditor api={api} term="term" identity="member" target={{kind:'unit',id:'unit',label:'Fictional unit'}} data={data} refreshed={()=>{}} onLock={()=>{}}/>)
 expect(screen.queryByRole('button',{name:'Publish reviewed layout'})).toBeNull()
 fireEvent.click(screen.getByRole('button',{name:'Preview saved layout'}));await screen.findByText(/Review before publishing/)
 const publish=screen.getByRole('button',{name:'Publish reviewed layout'});expect(publish.matches(':disabled')).toBe(true)
 fireEvent.change(screen.getByLabelText('Reason for publication'),{target:{value:'Clearer weekly planning'}})
 fireEvent.click(screen.getByLabelText('I reviewed this exact layout change'));fireEvent.click(publish)
 expect(run).toHaveBeenCalledWith(expect.objectContaining({action:'publish',version:2,reviewHash:'a'.repeat(64),reason:'Clearer weekly planning'}),expect.any(String))
})
it('confirmed target scope loss clears a locked command and permits choosing a remaining authorized target',async()=>{
 let revoked=false
 const first={kind:'unit' as const,id:'first',label:'First unit'},second={kind:'unit' as const,id:'second',label:'Second unit'}
 const api:LayoutAdminApi={targets:async()=>revoked?[second]:[first,second],read:async()=>data,preview:vi.fn(),run:async()=>({ok:false,error:{kind:'unavailable',message:'Result uncertain',retryable:true}})}
 render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'term',termMembershipId:'member'}),element:<FinDecisionMemory identity="member"><LayoutsPage api={api}/></FinDecisionMemory>}])}/> )
 fireEvent.change(await screen.findByLabelText('Layout audience'),{target:{value:'unit:first'}})
 fireEvent.click(await screen.findByRole('button',{name:'Save private layout draft'}));await screen.findByText(/Result uncertain/)
 expect(screen.getByLabelText('Layout audience').matches(':disabled')).toBe(true)
 revoked=true;fireEvent(window,new Event('focus'))
 await screen.findByText('Choose a role, committee or term default')
 expect(screen.getByLabelText('Layout audience').matches(':disabled')).toBe(false)
})
it('restoring a historical layout prepares a private draft and never publishes automatically',()=>{
 const run=vi.fn().mockResolvedValue({ok:true,value:{version:3}}),api={run}as unknown as LayoutAdminApi
 render(<LayoutEditor api={api} term="term" identity="member" target={{kind:'role',id:'role',label:'Fictional role'}} data={data} refreshed={()=>{}} onLock={()=>{}}/>)
 fireEvent.click(screen.getByRole('button',{name:'Restore version 1 as a private draft'}))
 expect(run).not.toHaveBeenCalled();expect(screen.getByText(/Historical layout selected/)).toBeTruthy()
 fireEvent.click(screen.getByRole('button',{name:'Save private layout draft'}))
 expect(run).toHaveBeenCalledWith(expect.objectContaining({action:'save',rollbackVersionId:data.history[0].id,baseVersion:1,version:2}),expect.any(String))
})
