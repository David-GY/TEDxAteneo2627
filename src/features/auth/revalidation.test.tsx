import {fireEvent,render,screen,waitFor} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {expect,it,vi} from 'vitest'
import {AuthRevalidator} from './pages'
import type {AuthGateway} from './gateway'
it('P35_U2: background access validation keeps safe inputs inert; a changed identity clears the old form',async()=>{
 let release:undefined|(()=>void),pause=false,memberId='first',capabilities=['workspace.read','directory.read']
 const gateway={onChange:()=>()=>{}} as unknown as AuthGateway
 const router=createMemoryRouter([{element:<AuthRevalidator gateway={gateway}/>,children:[{id:'workspace',path:'/',loader:async()=>{if(pause)await new Promise<void>(r=>{release=r});return{termId:'term',memberId,capabilities}},element:<input aria-label="Safe edit" defaultValue=""/>}]}])
 render(<RouterProvider router={router}/>);const input=await screen.findByLabelText('Safe edit')
 fireEvent.change(input,{target:{value:'Keep my working note'}});pause=true;void router.revalidate()
 await waitFor(()=>expect(router.state.revalidation).toBe('loading'))
 expect((screen.getByLabelText('Safe edit') as HTMLInputElement).value).toBe('Keep my working note')
 await waitFor(()=>expect(screen.getByLabelText('Safe edit').closest('[inert]')).toBeTruthy())
 release!();await waitFor(()=>expect(router.state.revalidation).toBe('idle'))
 expect((screen.getByLabelText('Safe edit') as HTMLInputElement).value).toBe('Keep my working note')
 pause=false;memberId='second';void router.revalidate()
 await waitFor(()=>expect((screen.getByLabelText('Safe edit') as HTMLInputElement).value).toBe(''))
 fireEvent.change(screen.getByLabelText('Safe edit'),{target:{value:'Clear on authority loss'}});capabilities=['workspace.read'];void router.revalidate()
 await waitFor(()=>expect((screen.getByLabelText('Safe edit') as HTMLInputElement).value).toBe(''))
 vi.restoreAllMocks()
})
