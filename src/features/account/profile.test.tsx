import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { expect, it, vi } from 'vitest'
import { ProfileEditor } from './ProfileEditor'
import type { OwnProfile, ProfileGateway } from './gateway'

const initial: OwnProfile = { memberId:'fictional',displayName:'Fictional member',version:1,course:null,yearLevel:null,phone:null,externalContact:null,shareCourse:false,shareYearLevel:false,sharePhone:false,shareExternalContact:false }
function api(): ProfileGateway {
  return { read:vi.fn(async()=>initial),save:vi.fn(async(_term,values)=>({...initial,...values,version:2})),share:vi.fn(async(_term,visibility)=>({...initial,...visibility,version:3})) }
}
it('P06_A1/A2: saves optional private values separately from disclosure and retains independent unsaved choices',async()=>{
  const gateway=api()
  render(<MemoryRouter><ProfileEditor api={gateway} termId="term" /></MemoryRouter>)
  await screen.findByLabelText('Course')
  expect(screen.getByRole('link',{name:'Find a process contact'})).toBeTruthy()
  fireEvent.change(screen.getByLabelText('Course'),{target:{value:'Fictional course'}})
  fireEvent.click(screen.getByLabelText('Share course'))
  fireEvent.click(screen.getByRole('button',{name:'Save private details'}))
  await screen.findByText('Private details saved. Your sharing choices were kept.')
  expect(gateway.save).toHaveBeenCalledWith('term',{course:'Fictional course',yearLevel:null,phone:null,externalContact:null},1,expect.any(String))
  expect(gateway.share).not.toHaveBeenCalled()
  expect((screen.getByLabelText('Share course') as HTMLInputElement).checked).toBe(true)
  fireEvent.click(screen.getByRole('button',{name:'Save sharing choices'}))
  await screen.findByText('Sharing choices saved. Unchecked details are hidden from the directory.')
  expect(gateway.share).toHaveBeenCalledWith('term',{shareCourse:true,shareYearLevel:false,sharePhone:false,shareExternalContact:false},2,expect.any(String))
})
it('keeps a retry key after unconfirmed save and reports no success before confirmation',async()=>{
  const gateway=api()
  const save=vi.fn().mockRejectedValueOnce(new Error('The save could not be confirmed.')).mockResolvedValueOnce({...initial,version:2})
  gateway.save=save
  render(<MemoryRouter><ProfileEditor api={gateway} termId="term" /></MemoryRouter>)
  await screen.findByLabelText('Course')
  fireEvent.click(screen.getByRole('button',{name:'Save private details'}))
  await screen.findByRole('alert')
  expect(screen.queryByText('Private details saved. Your sharing choices were kept.')).toBeNull()
  fireEvent.click(screen.getByRole('button',{name:'Save private details'}))
  await waitFor(()=>expect(save).toHaveBeenCalledTimes(2))
  expect(save.mock.calls[0]).toEqual(save.mock.calls[1])
  await screen.findByText('Private details saved. Your sharing choices were kept.')
})
