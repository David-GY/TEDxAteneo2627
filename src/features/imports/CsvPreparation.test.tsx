import {act,cleanup,fireEvent,render,screen} from '@testing-library/react'
import {afterEach,expect,it} from 'vitest'
import {createMemoryRouter,RouterProvider} from 'react-router'
import {CsvPreparation} from './CsvPreparation'
afterEach(cleanup)
function show(capabilities=['admin.configure','roles.manage']){
  const router=createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'term',memberId:'member',capabilities}),element:<CsvPreparation/>}])
  render(<RouterProvider router={router}/>);return router
}
it('P45_A3 presentation denies preparation without both current administration permissions',async()=>{
  show(['admin.configure']);await screen.findByText('CSV preparation unavailable');expect(screen.queryByLabelText('CSV input')).toBeNull()
})
it('P45_U1 local retry retains named mappings and input, invalidates old review and cannot commit even valid rows',async()=>{
  show();const input=await screen.findByLabelText('CSV input')
  fireEvent.change(input,{target:{value:'source_key,title,due_on,reference\na,Signs,2027-02-29,TASK-027\na,Other,2027-04-17,TASK-028'}})
  for(const label of ['Source for person responsible','Source for committee'])fireEvent.change(screen.getByLabelText(label),{target:{value:''}})
  fireEvent.click(screen.getByRole('button',{name:'Review mapped values'}));expect(await screen.findAllByText(/Duplicate source key/)).toHaveLength(2)
  fireEvent.change(input,{target:{value:'source_key,title,due_on,reference\na,Signs,2027-02-28,TASK-027\nb,Other,2027-04-17,TASK-028'}})
  expect(screen.queryByRole('heading',{name:'Mapped review'})).toBeNull()
  expect((screen.getByLabelText('Source for title') as HTMLSelectElement).value).toBe('title')
  fireEvent.click(screen.getByRole('button',{name:'Review mapped values'}));await screen.findByText('Local validation passed for 2 records. No records were imported.')
  expect(screen.getByText('TASK-027')).toBeTruthy()
  expect((screen.getByRole('button',{name:'Import unavailable'}) as HTMLButtonElement).disabled).toBe(true)
  expect((input as HTMLTextAreaElement).value).toContain('TASK-028')
})
it('clears raw review context when account/term changes and hides preparation when permission is revoked',async()=>{
  let context={termId:'term',memberId:'one',capabilities:['admin.configure','roles.manage']}
  const router=createMemoryRouter([{id:'workspace',path:'/',loader:()=>context,element:<CsvPreparation/>}])
  render(<RouterProvider router={router}/>);const input=await screen.findByLabelText('CSV input')
  fireEvent.change(input,{target:{value:'source_key,title\na,Private temporary CSV'}})
  context={...context,memberId:'two',termId:'other'}
  await act(async()=>{router.revalidate()})
  expect((screen.getByLabelText('CSV input') as HTMLTextAreaElement).value).not.toContain('Private temporary CSV')
  context={...context,capabilities:[]};await act(async()=>{router.revalidate()})
  expect(screen.queryByLabelText('CSV input')).toBeNull()
})
