import {it,expect,vi} from 'vitest'
import {render,screen,fireEvent,waitFor} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {createHandoffsApi} from './api'
import {safeReturnPath,isHandoffPath} from '../auth/redirects'
import {Overview} from '../overview/Overview'
import {HandoffDrafts,useHandoffDrafts} from './Drafts'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
function api(data:unknown){return createHandoffsApi(Promise.resolve({rpc:vi.fn(async()=>({data,error:null}))}) as unknown as Parameters<typeof createHandoffsApi>[0])}
it('validates scoped list/options bounds and refuses malformed target versions/file hashes',async()=>{
 expect(await api(null).list(id,'incoming',null,1)).toBeNull()
 await expect(api({items:[],total:-1,page:1,pageSize:20}).list(id,'incoming',null,1)).rejects.toThrow()
 const options={sourceId:id,sourceVersion:2,canSubmit:true,manifests:[],targets:[{key:'task:'+id,name:'Permitted target',receiverId:id,receiverUnitId:id,nextTaskId:id,nextVersion:null}]}
 await expect(api(options).options(id)).rejects.toThrow();expect((await api({...options,targets:[]}).options(id))?.sourceVersion).toBe(2)
})
it('allows exact handoff deep links through sign-in without allowing sibling/foreign URLs',()=>{
 expect(isHandoffPath('/working-together/handoffs/'+id)).toBe(true);expect(safeReturnPath('/working-together/handoffs/'+id)).toBe('/working-together/handoffs/'+id)
 expect(safeReturnPath('/working-together/handoffs/secret-name')).toBe('/');expect(safeReturnPath('//evil.invalid/working-together/handoffs/'+id)).toBe('/')
})
it('P18_A3 links a permitted handoff once and removes its resolved action on actual view refresh',async()=>{
 const read=vi.fn().mockResolvedValueOnce({items:[{id,source:'handoff',title:'Explicit package',owner:'Sender',dueOn:'2027-04-10',dueAt:null,lane:'actionable',action:'Review exact revision',person:'Receiver',state:'proposed',committee:'Known committee',overdue:false}],hasMore:false,refreshedAt:'2026-10-25T00:00:00Z'}).mockResolvedValue({items:[],hasMore:false,refreshedAt:'2026-10-25T01:00:00Z'})
 render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:id,memberId:id}),Component:()=> <Overview api={{read}}/>}])}/>);expect((await screen.findByRole('link',{name:'Explicit package'})).getAttribute('href')).toBe('/working-together/handoffs/'+id);fireEvent.click(screen.getByText('Refresh overview'));await waitFor(()=>expect(screen.queryByText('Explicit package')).toBeNull());await screen.findByText('No next actions in this view')
})
it('keeps explicit handoff request input only within its identity, including remounts',()=>{
 function Probe(){const drafts=useHandoffDrafts();return <button onClick={()=>drafts?.set('own',{fields:{reason:'Keep my review'},pending:null})}>{drafts?.get('own')?.fields.reason??'Empty'}</button>}
 const view=render(<HandoffDrafts identity="actor-A"><Probe/></HandoffDrafts>);fireEvent.click(screen.getByText('Empty'));view.rerender(<HandoffDrafts identity="actor-A"><p>Checking</p></HandoffDrafts>);view.rerender(<HandoffDrafts identity="actor-A"><Probe/></HandoffDrafts>);expect(screen.getByText('Keep my review')).toBeTruthy();view.rerender(<HandoffDrafts identity="actor-B"><Probe/></HandoffDrafts>);expect(screen.getByText('Empty')).toBeTruthy()
})
