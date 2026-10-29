import {act,fireEvent,render,screen,waitFor} from '@testing-library/react'
import {createMemoryRouter,RouterProvider,Link} from 'react-router'
import {it,expect,vi} from 'vitest'
import {EditSafety} from './EditSafety'
import {useState} from 'react'
function setup(pending=false){let refresh=0;const router=createMemoryRouter([{path:'/',element:<EditSafety><form data-edit-form data-pending-command={pending}><input aria-label="Notes"/><button type="button" data-discard-edits onClick={()=>refresh++}>Refresh work</button></form><Link to="/other">Other page</Link></EditSafety>},{path:'/other',element:<p>Other destination</p>}]);render(<RouterProvider router={router}/>);return{router,refreshed:()=>refresh}}
it('button-only draft changes warn before reload and keep navigation reversible',async()=>{
 function ButtonEditor(){const[changed,setChanged]=useState(false);return <div data-edit-form data-unsaved-changes={changed}><button onClick={()=>setChanged(true)}>Add draft step</button></div>}
 const router=createMemoryRouter([{path:'/',element:<EditSafety><ButtonEditor/><Link to="/other">Other page</Link></EditSafety>},{path:'/other',element:<p>Other destination</p>}]);render(<RouterProvider router={router}/>);
 fireEvent.click(screen.getByRole('button',{name:'Add draft step'}));const unload=new Event('beforeunload',{cancelable:true});window.dispatchEvent(unload);expect(unload.defaultPrevented).toBe(true)
 fireEvent.click(screen.getByRole('link',{name:'Other page'}));fireEvent.click(await screen.findByRole('button',{name:'Keep editing'}));expect(screen.getByRole('button',{name:'Add draft step'})).toBeTruthy()
})
it('P35_U2: refresh needs explicit discard; cancelled navigation/back keeps inputs; confirmed leaving clears them',async()=>{
 const confirm=vi.spyOn(window,'confirm').mockReturnValue(false),s=setup()
 fireEvent.change(screen.getByLabelText('Notes'),{target:{value:'Unsaved'}})
 const unload=new Event('beforeunload',{cancelable:true});window.dispatchEvent(unload);expect(unload.defaultPrevented).toBe(true)
 fireEvent.click(screen.getByRole('button',{name:'Refresh work'}));expect(s.refreshed()).toBe(0)
 fireEvent.click(screen.getByRole('link',{name:'Other page'}));await screen.findByRole('button',{name:'Keep editing'})
 fireEvent.click(screen.getByRole('button',{name:'Keep editing'}));expect((screen.getByLabelText('Notes') as HTMLInputElement).value).toBe('Unsaved')
 fireEvent.click(screen.getByRole('link',{name:'Other page'}));fireEvent.click(await screen.findByRole('button',{name:'Discard edits and leave'}));await screen.findByText('Other destination')
 expect(confirm).toHaveBeenCalledTimes(1);confirm.mockRestore()
})
it('P35_U2: uncertain command cannot lose its retry key through refresh or navigation',async()=>{
 const s=setup(true);fireEvent.change(screen.getByLabelText('Notes'),{target:{value:'Unconfirmed'}})
 fireEvent.click(screen.getByRole('button',{name:'Refresh work'}));expect(s.refreshed()).toBe(0)
 fireEvent.click(screen.getByRole('link',{name:'Other page'}));await screen.findByRole('button',{name:'Keep editing'})
 expect(screen.queryByRole('button',{name:'Discard edits and leave'})).toBeNull()
 await waitFor(()=>expect(s.router.state.location.pathname).toBe('/'))
})
it('P35_U2: history Back cancellation retains inputs; explicit discard permits the original history destination',async()=>{
 const router=createMemoryRouter([{path:'/',element:<EditSafety><form data-edit-form><input aria-label="Back recovery notes"/></form></EditSafety>},{path:'/previous',element:<p>Previous permitted page</p>}],{initialEntries:['/previous','/'],initialIndex:1})
 render(<RouterProvider router={router}/>);fireEvent.change(screen.getByLabelText('Back recovery notes'),{target:{value:'Keep this on Back'}})
 await act(async()=>{await router.navigate(-1)})
 fireEvent.click(await screen.findByRole('button',{name:'Keep editing'}))
 expect(router.state.location.pathname).toBe('/')
 expect((screen.getByLabelText('Back recovery notes') as HTMLInputElement).value).toBe('Keep this on Back')
 await act(async()=>{await router.navigate(-1)})
 fireEvent.click(await screen.findByRole('button',{name:'Discard edits and leave'}))
 await screen.findByText('Previous permitted page')
 expect(screen.queryByLabelText('Back recovery notes')).toBeNull()
})
