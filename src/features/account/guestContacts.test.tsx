import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { expect, it, vi } from 'vitest'
import { GuestContactEditor } from './GuestContactEditor'
import { createGuestContactGateway, type GuestContactGateway, type GuestContactView } from './guestContacts'
import type { createSupabaseClient } from '../../lib/supabase'

const own: GuestContactView = { own: { displayName:'Fictional guest',verifiedEmail:'fictional@example.invalid',contactRoute:null,version:0 }, sharedContacts:[],scopeMode:'awaiting_record_attachment' }
it('P06 guest account shows own contacts and no core directory/profile fields; optional save confirms no sharing',async()=>{
  const api: GuestContactGateway = { read:vi.fn(async()=>own),save:vi.fn(async(_term,values)=>({...own,own:{...own.own,...values,displayName:values.displayName ?? 'Invited guest',version:1}})) }
  render(<MemoryRouter><GuestContactEditor api={api} termId="term" /></MemoryRouter>)
  await screen.findByLabelText('Preferred contact route')
  expect(screen.getByText(/Verified Google email: fictional@example.invalid/)).toBeTruthy()
  expect(screen.queryByLabelText('Course')).toBeNull()
  expect(screen.queryByRole('link',{name:'People'})).toBeNull()
  expect(screen.getByText(/No other contacts are shared/)).toBeTruthy()
  fireEvent.change(screen.getByLabelText('Preferred contact route'),{target:{value:'Fictional contact'}})
  fireEvent.click(screen.getByRole('button',{name:'Save my contact details'}))
  await screen.findByText('Your contact details were saved. They have not been shared with other people.')
  expect(api.save).toHaveBeenCalledWith('term',{displayName:'Fictional guest',contactRoute:'Fictional contact'},0,expect.any(String))
})
it('guest save retries the same key without a premature success notice',async()=>{
  const save=vi.fn().mockRejectedValueOnce(new Error('Save not confirmed')).mockResolvedValueOnce(own)
  const api:GuestContactGateway={read:async()=>own,save}
  render(<MemoryRouter><GuestContactEditor api={api} termId="term" /></MemoryRouter>)
  await screen.findByLabelText('Display name')
  fireEvent.click(screen.getByRole('button',{name:'Save my contact details'}))
  await screen.findByRole('alert')
  expect(screen.queryByText(/Your contact details were saved/)).toBeNull()
  fireEvent.click(screen.getByRole('button',{name:'Save my contact details'}))
  await waitFor(()=>expect(save).toHaveBeenCalledTimes(2))
  expect(save.mock.calls[0]).toEqual(save.mock.calls[1])
  await screen.findByText(/Your contact details were saved/)
})
it('guest gateway rejects denied or unexpectedly broad contacts and sanitizes transport errors',async()=>{
  const rpc=vi.fn().mockResolvedValueOnce({data:null,error:null})
    .mockResolvedValueOnce({data:{...own,sharedContacts:[{name:'Unexpected other person'}]},error:null})
    .mockRejectedValueOnce(new Error('PRIVATE transport payload'))
    .mockResolvedValueOnce({data:own,error:null})
  const gateway=createGuestContactGateway(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>)
  await expect(gateway.read('term')).rejects.toThrow('contacts are unavailable')
  await expect(gateway.read('term')).rejects.toThrow('contacts are unavailable')
  await expect(gateway.save('term',{displayName:null,contactRoute:null},0,'request')).rejects.toThrow('could not be confirmed')
  await gateway.save('term',{displayName:null,contactRoute:null},0,'request')
  expect(rpc).toHaveBeenLastCalledWith('save_guest_contact_profile',{p_term_id:'term',p_values:{displayName:null,contactRoute:null},p_expected_version:0,p_request_id:'request'})
})
it('P07_A1: only validated explicit-record contacts render, and reload removes withdrawn scope',async()=>{
  const scoped:GuestContactView={...own,scopeMode:'explicit_records',sharedContacts:[{id:'owner',name:'Fictional work owner',organizationContact:'fictional+work@student.ateneo.edu'}]}
  const read=vi.fn().mockResolvedValueOnce(scoped).mockResolvedValueOnce(own)
  const api:GuestContactGateway={read,save:async()=>own}
  render(<MemoryRouter><GuestContactEditor api={api} termId="term" /></MemoryRouter>)
  const email=await screen.findByRole('link',{name:'Email Fictional work owner'})
  expect(email.getAttribute('href')).toBe('mailto:fictional%2Bwork%40student.ateneo.edu')
  expect(screen.queryByRole('link',{name:'People'})).toBeNull()
  fireEvent.click(screen.getByRole('button',{name:'Reload contacts and discard unsaved edits'}))
  await screen.findByText(/No other contacts are shared/)
  expect(screen.queryByRole('link',{name:'Email Fictional work owner'})).toBeNull()
})
it('P07_A1: guest parser accepts explicit safe contacts but rejects malformed shared fields',async()=>{
  const scoped:GuestContactView={...own,scopeMode:'explicit_records',sharedContacts:[{id:'owner',name:'Fictional work owner',organizationContact:null}]}
  const rpc=vi.fn().mockResolvedValueOnce({data:scoped,error:null}).mockResolvedValueOnce({data:{...scoped,sharedContacts:[{id:'owner',name:'Fictional',organizationContact:{phone:'private'}}]},error:null})
  const gateway=createGuestContactGateway(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>)
  expect(await gateway.read('term')).toEqual(scoped)
  await expect(gateway.read('term')).rejects.toThrow('contacts are unavailable')
})
