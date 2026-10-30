import {render,screen,fireEvent,cleanup,within} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {afterEach,expect,it,vi} from 'vitest'
import {Overview} from './Overview'
import {viewStorageKey} from './layout'
import type {OverviewRow} from './api'
import type {AccountLayoutApi} from './account-api'
afterEach(()=>{cleanup();localStorage.clear();vi.restoreAllMocks()})
const key=viewStorageKey('org','term','member:membership')
const row:OverviewRow={id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',source:'task',title:'Fictional assigned task',owner:'Fictional River',dueOn:'2027-04-10',dueAt:null,lane:'actionable',action:'Update task progress',person:'Fictional River',state:'todo',committee:null,overdue:false}
function show(items:OverviewRow[]=[],subject='membership',layouts?:AccountLayoutApi){
 const read=vi.fn().mockResolvedValue({items,hasMore:false,refreshedAt:'2026-10-29T00:00:00Z'})
 render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'term',organizationId:'org',memberId:'actor',termMembershipId:subject,capabilities:['workspace.read']}),element:<Overview api={{read,layouts}}/>}])}/>);return read
}
it('published role defaults apply without setup while existing device arrangements and required work retain precedence',async()=>{
 const layouts:AccountLayoutApi={read:async()=>({source:'role',layout:{version:1,widgets:[{id:'resources',size:'wide'}]},ambiguous:false,repaired:false,views:[]}),run:vi.fn()}
 show([row],'membership',layouts);await screen.findByText('Using the published role layout. No setup needed.')
 expect(screen.getByRole('link',{name:row.title})).toBeTruthy();expect(screen.getByRole('link',{name:'Find a permitted contact'})).toBeTruthy()
 expect(screen.getByRole('heading',{name:'Resources & Start Here'})).toBeTruthy()
 cleanup();localStorage.setItem(key,JSON.stringify({version:1,widgets:[{id:'calendar',size:'wide'}]}))
 show([row],'membership',layouts);await screen.findByRole('link',{name:row.title});await screen.findByText('Your view is saved on this device.')
 expect(screen.getByRole('heading',{name:'Upcoming dates'})).toBeTruthy();expect(screen.queryByRole('heading',{name:'Resources & Start Here'})).toBeNull()
 fireEvent.click(screen.getByText('Saved account views'));fireEvent.click(screen.getByRole('button',{name:'Use published default'}));expect(localStorage.getItem(key)).toBeNull();expect(screen.getByRole('heading',{name:'Resources & Start Here'})).toBeTruthy()
})
it('P40_U1/U2: no setup required, keyboard control changes only secondary view and persists no work data',async()=>{
 const read=show([row]);await screen.findByRole('link',{name:row.title})
 expect(screen.getByRole('link',{name:'Find a permitted contact'}).getAttribute('href')).toBe('/people')
 fireEvent.click(screen.getByText('Arrange my overview'))
 const editor=screen.getByRole('group',{name:'Secondary views'})
 const move=within(editor).getByRole('button',{name:'Move Upcoming dates up'});move.focus();fireEvent.click(move)
 expect(within(editor).getAllByRole('button',{name:/Move .* up/})[0].getAttribute('aria-label')).toBe('Move Upcoming dates up')
 expect(screen.getByRole('link',{name:row.title}).getAttribute('href')).toBe('/tasks/'+row.id)
 expect(read).toHaveBeenCalledTimes(1)
 const saved=localStorage.getItem(key)!;expect(JSON.parse(saved).widgets[0].id).toBe('calendar');expect(saved).not.toContain(row.title);expect(saved).not.toContain(row.id)
 cleanup();show([row]);await screen.findByRole('link',{name:row.title});expect(screen.getByText('Your view is saved on this device.')).toBeTruthy()
 cleanup();show([], 'different');await screen.findByRole('heading',{name:'Who is waiting on you · 0'});expect(screen.getByRole('link',{name:'Find a permitted contact'})).toBeTruthy()
})
it('P40_A3: tampered or retired widget config produces useful default and an explicit repair',async()=>{
 localStorage.setItem(key,JSON.stringify({version:1,widgets:[{id:'finance',query:'private',size:'wide'}]}));show()
 await screen.findByText(/Saved view is no longer supported/)
 expect(await screen.findByRole('heading',{name:'Who is waiting on you · 0'})).toBeTruthy()
 expect(screen.getByRole('link',{name:'Find a permitted contact'})).toBeTruthy()
 fireEvent.click(screen.getByText('Arrange my overview'));expect(screen.queryByRole('button',{name:/finance/i})).toBeNull()
 fireEvent.click(screen.getByRole('button',{name:'Restore default view'}));expect(screen.queryByText(/Saved view is no longer supported/)).toBeNull()
})
it('P40_U2: storage failure retains usable current view and explains device persistence failure',async()=>{
 vi.spyOn(Storage.prototype,'setItem').mockImplementation(()=>{throw Error('unavailable')});show([row]);await screen.findByRole('link',{name:row.title})
 fireEvent.click(screen.getByText('Arrange my overview'));fireEvent.click(screen.getByRole('button',{name:'Move Upcoming dates up'}))
 expect(screen.getByRole('status').textContent).toContain('could not be saved');expect(screen.getByRole('link',{name:row.title})).toBeTruthy()
})
it('P40_U1: waiting requests preserve proposed/accepted dates and task references after moving widgets',async()=>{
 show([{...row,source:'request',termId:'term',title:'Fictional revision waiting',lane:'waiting',requestedOn:'2027-04-10',dueOn:null,state:'submitted'},{...row,lane:'waiting',reference:{value:'TASK-027',termId:row.id,termLabel:'2026–27'}}]);await screen.findByRole('link',{name:'Fictional revision waiting'})
 expect(screen.getByText(/Requested:/).textContent).toContain('Accepted: Not agreed');expect(screen.getByText('TASK-027')).toBeTruthy()
})
it('P40_U1/U2: fictional previews evaluate the same layout for late joiner, assignee, head and guest without querying another identity',async()=>{
 const read=show();await screen.findByRole('heading',{name:'Who is waiting on you · 0'})
 fireEvent.click(screen.getByText('Try fictional layouts'))
 const preview=await screen.findByRole('region',{name:'Fictional layout preview'})
 expect(within(preview).getByRole('link',{name:'Find a permitted contact'})).toBeTruthy()
 fireEvent.change(within(preview).getByLabelText('Example person'),{target:{value:'assignee'}})
 expect(within(preview).getByRole('link',{name:'Prepare the fictional handoff'})).toBeTruthy()
 expect(within(preview).getByText(/Owner: Fictional River/)).toBeTruthy()
 fireEvent.change(within(preview).getByLabelText('Example person'),{target:{value:'head'}})
 expect(within(preview).getByText(/Next action: Assign an independent reviewer/)).toBeTruthy()
 fireEvent.change(within(preview).getByLabelText('Example person'),{target:{value:'guest'}})
 expect(within(preview).getByRole('link',{name:'Shared with me'})).toBeTruthy()
 expect(within(preview).queryByRole('link',{name:'Find a permitted contact'})).toBeNull()
 expect(read).toHaveBeenCalledTimes(1)
})
