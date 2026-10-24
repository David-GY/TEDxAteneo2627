import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { beforeEach, expect, it, vi } from 'vitest'
import { createAppRoutes } from '../../app/router'
import { readClientEnvironment } from '../../lib/env'
import { parseContext, type AuthGateway, type AuthResult } from '../auth/gateway'
import { createGuestGateway, invitationUrl, readInvitationFragment, type GuestGateway } from './gateway'
import type { createSupabaseClient } from '../../lib/supabase'

const environment=readClientEnvironment({})
const core={state:'authorized' as const,memberId:'member',organizationId:'org',termId:'term',termMembershipId:'tm',displayName:'Fictional admin',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:['roles.manage']}
const guest={state:'authorized' as const,audience:'guest' as const,guestAccessId:'invite',organizationId:'org',termId:'term',displayName:'Invited guest',expiresAt:core.expiresAt,capabilities:[]}
const token='a'.repeat(64)
function auth(result:AuthResult,guests?:GuestGateway):AuthGateway{return {guests,readContext:vi.fn(async()=>result),onChange:()=>()=>undefined,exchange:vi.fn(async()=>undefined),beginGoogle:vi.fn(async()=>undefined),signOut:vi.fn(async()=>undefined)}}
function api():GuestGateway{return {list:vi.fn(async()=>[]),create:vi.fn(async()=>({id:'invitation',token,reused:false})),revoke:vi.fn(async()=>undefined),redeem:vi.fn(async()=>undefined)}}
beforeEach(()=>{window.history.replaceState({},'','/');localStorage.clear();sessionStorage.clear()})

it('P05_A2: guest deep links to directory/admin are redirected and never invoke invitation listing',async()=>{
  const guests=api();const gateway=auth(guest,guests)
  const router=createMemoryRouter(createAppRoutes(environment,gateway),{initialEntries:['/people']})
  render(<RouterProvider router={router}/> )
  expect(await screen.findByRole('heading',{name:'Shared with me'})).toBeTruthy()
  expect(screen.queryByRole('link',{name:'People'})).toBeNull()
  await act(async()=>{await router.navigate('/guests')})
  expect(router.state.location.pathname).toBe('/shared')
  expect(guests.list).not.toHaveBeenCalled()
  expect(parseContext({...guest,capabilities:['roles.manage']})).toBeNull()
})

it('P05_A2: ordinary core member cannot open sponsor controls',async()=>{
  const guests=api()
  const router=createMemoryRouter(createAppRoutes(environment,auth({...core,capabilities:[]},guests)),{initialEntries:['/guests']})
  render(<RouterProvider router={router}/> )
  expect(await screen.findByRole('heading',{name:'Overview'})).toBeTruthy()
  expect(guests.list).not.toHaveBeenCalled()
})

it('P05_A3: redemption scrubs fragment and persists no token; successful RPC navigates to guest records',async()=>{
  window.history.replaceState({},'','/guest/redeem#'+token)
  const guests=api();const gateway=auth(guest,guests)
  const router=createMemoryRouter(createAppRoutes(environment,gateway),{initialEntries:['/guest/redeem']})
  render(<RouterProvider router={router}/> )
  const button=await screen.findByRole('button',{name:'Accept invitation with signed-in account'})
  expect(window.location.hash).toBe('')
  fireEvent.click(button)
  expect(await screen.findByRole('heading',{name:'Shared with me'})).toBeTruthy()
  expect(guests.redeem).toHaveBeenCalledWith(token)
  expect(localStorage.length).toBe(0);expect(sessionStorage.length).toBe(0)
})

it('P05_A3: sponsor link follows confirmed RPC only, with explicit zero-record preview and copy failure recovery',async()=>{
  const guests=api()
  Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:vi.fn(async()=>{throw new Error('blocked')})}})
  render(<RouterProvider router={createMemoryRouter(createAppRoutes(environment,auth(core,guests)),{initialEntries:['/guests']})}/> )
  await screen.findByRole('heading',{name:'Guest invitations'})
  await waitFor(()=>expect((screen.getByRole('button',{name:'Create invitation link'}) as HTMLButtonElement).disabled).toBe(false))
  expect(screen.getByText(/Scope preview: zero shared records/)).toBeTruthy()
  fireEvent.change(screen.getByLabelText('Guest Google email (required)'),{target:{value:'visitor@example.invalid'}})
  await act(async()=>{fireEvent.click(screen.getByRole('button',{name:'Create invitation link'}))})
  expect(guests.create).toHaveBeenCalledWith('term','visitor@example.invalid',expect.any(String),expect.any(String),undefined)
  expect(await screen.findByLabelText('Invitation link')).toHaveProperty('value',invitationUrl(window.location.origin,token))
  fireEvent.click(screen.getByRole('button',{name:'Copy invitation link'}))
  expect(await screen.findByRole('alert')).toHaveProperty('textContent','Clipboard access failed. Use the selectable invitation link below.')
  expect(sessionStorage.length).toBe(0)
})

it('P05_A3: failed RPC never returns a token or echoes raw diagnostics',async()=>{
  const rpc=vi.fn(async()=>({data:null,error:{message:'private-'+token}}))
  const guests=createGuestGateway(Promise.resolve({rpc} as unknown as Awaited<ReturnType<typeof createSupabaseClient>>))
  await expect(guests.redeem(token)).rejects.toThrow('Guest access could not be updated')
  await expect(guests.create('term','visitor@example.invalid','request')).rejects.not.toThrow(token)
  expect(readInvitationFragment('#'+token)).toBe(token)
  expect(readInvitationFragment('#token='+token)).toBeNull()
  expect(readInvitationFragment('#<script>')).toBeNull()
})
it('P07: sponsor list reports explicit record count without implying directory access',async()=>{
  const guests=api()
  guests.list=vi.fn(async()=>[{id:'invitation',email:'fictional@example.invalid',expiresAt:core.expiresAt,redeemedAt:null,revokedAt:null,version:1,scopeMode:'explicit_records' as const,sharedRecordCount:2}])
  render(<RouterProvider router={createMemoryRouter(createAppRoutes(environment,auth(core,guests)),{initialEntries:['/guests']})}/> )
  expect(await screen.findByText('2 explicitly shared work records; no full directory access.')).toBeTruthy()
})
