import{render,screen,fireEvent}from'@testing-library/react'
import{createMemoryRouter,RouterProvider}from'react-router'
import{it,expect,vi}from'vitest'
import{TasksPage}from'./TasksPage'
import{createTasksApi}from'./api'
import type{createSupabaseClient}from'../../lib/supabase'
it('read-only tasks recover from errors without retaining rows or exposing diagnostics',async()=>{
  const read=vi.fn().mockRejectedValueOnce(new Error('PRIVATE')).mockResolvedValue({items:[],total:0,page:1})
  render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'fictional-term'}),element:<TasksPage api={{read}}/>}],{initialEntries:['/']})}/>)
  await screen.findByRole('alert');expect(screen.queryByText('PRIVATE')).toBeNull();fireEvent.click(screen.getByRole('button',{name:'Try again'}));await screen.findByRole('heading',{name:'No tasks on this page'})
})
it('owned-task adapter uses actual RPC arguments and rejects malformed responses',async()=>{
  const rpc=vi.fn().mockResolvedValueOnce({data:{items:[],total:0,page:2},error:null}).mockResolvedValueOnce({data:{items:[{title:'PRIVATE'}],total:1,page:2},error:null})
  const api=createTasksApi(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>);expect((await api.read('fictional-term',2)).total).toBe(0);expect(rpc).toHaveBeenCalledWith('read_owned_tasks',{p_term_id:'fictional-term',p_page:2});await expect(api.read('fictional-term',2)).rejects.toThrow('Owned tasks could not load')
})
