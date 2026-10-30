import {render,screen,fireEvent,cleanup} from '@testing-library/react'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {afterEach,expect,it,vi} from 'vitest'
import {Search} from './Search'
import type {SearchApi} from './api'
afterEach(cleanup)
function show(api:SearchApi){render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'term',termMembershipId:'member'}),element:<Search api={api}/>}])}/>)}
it('title-first results open the existing permitted record; clearing hides results and resets input',async()=>{
 const read=vi.fn().mockResolvedValue({items:[{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',kind:'task',title:'Prepare checklist',reference:'TASK-027',termId:'term',termLabel:'Fictional term',href:'/tasks/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8'}],total:1,nextCursor:null})
 show({read});fireEvent.change(await screen.findByLabelText('Search titles or references'),{target:{value:'checklist'}});fireEvent.click(screen.getByRole('button',{name:'Search work'}));expect((await screen.findByRole('link',{name:'Prepare checklist'})).getAttribute('href')).toContain('/tasks/');expect(screen.getByText(/TASK-027/)).toBeTruthy()
 fireEvent.click(screen.getByRole('button',{name:'Clear search'}));expect(screen.queryByRole('link',{name:'Prepare checklist'})).toBeNull();expect((screen.getByLabelText('Search titles or references')as HTMLInputElement).value).toBe('')
})
it('no match and connection failure are distinct without claiming a restricted match exists',async()=>{
 const read=vi.fn().mockResolvedValueOnce({items:[],total:0,nextCursor:null}).mockRejectedValue(Error())
 show({read});fireEvent.change(await screen.findByLabelText('Search titles or references'),{target:{value:'private'}});fireEvent.click(screen.getByRole('button',{name:'Search work'}));await screen.findByText('No permitted matches. Try a title or reference in this term.')
 fireEvent.click(screen.getByRole('button',{name:'Search work'}));await screen.findByRole('alert');expect(screen.queryByText('No permitted matches. Try a title or reference in this term.')).toBeNull()
})
