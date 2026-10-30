import { act, render, screen } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { expect, it, vi } from 'vitest'
import { readClientEnvironment } from '../lib/env'
import type { AuthGateway, AuthResult, MemberContext } from '../features/auth/gateway'
import { createAppRoutes } from './router'

const environment = readClientEnvironment({})
const member: MemberContext = { state: 'authorized', memberId: 'member', displayName: 'Fictional test member', organizationId: 'org', termId: 'term', termMembershipId: 'membership', expiresAt: new Date(Date.now()+3_600_000).toISOString(), capabilities: ['workspace.read'] }
function gateway(result: AuthResult): AuthGateway {
  return { readContext: vi.fn(async () => result), beginGoogle: vi.fn(async () => undefined), exchange: vi.fn(async () => undefined), signOut: vi.fn(async () => undefined), onChange: () => () => undefined }
}
it('term-qualified search links pass scope to the trusted workspace loader',async()=>{
 const auth=gateway(member),term='22222222-2222-4222-8222-222222222222'
 const router=createMemoryRouter(createAppRoutes(environment,auth),{initialEntries:['/search?term='+term]})
 render(<RouterProvider router={router}/>);await screen.findByRole('heading',{name:'Search unavailable'})
 expect(auth.readContext).toHaveBeenCalledWith(expect.any(AbortSignal),term)
})
it('sign-in recovery keeps the requested term instead of redirecting through a different authorized term',async()=>{
 const auth=gateway({state:'denied'}),term='22222222-2222-4222-8222-222222222222'
 const router=createMemoryRouter(createAppRoutes(environment,auth),{initialEntries:['/login?returnTo='+encodeURIComponent('/search?term='+term)]})
 render(<RouterProvider router={router}/>);await screen.findByRole('heading',{name:'Sign in to your workspace'})
 expect(auth.readContext).toHaveBeenCalledWith(expect.any(AbortSignal),term)
})
it('a guest can resume an explicitly shared work link with its own term context',async()=>{
 const guest={...member,audience:'guest'as const,guestAccessId:'g',termId:'22222222-2222-4222-8222-222222222222',capabilities:[]},path='/deliverables/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8?term=22222222-2222-4222-8222-222222222222'
 const router=createMemoryRouter(createAppRoutes(environment,gateway(guest)),{initialEntries:['/login?returnTo='+encodeURIComponent(path)]})
 render(<RouterProvider router={router}/>);await vi.waitFor(()=>expect(router.state.location.pathname+router.state.location.search).toBe(path))
})

it('P04_A1: unavailable configuration shows setup without protected navigation or a success action', async () => {
  render(<RouterProvider router={createMemoryRouter(createAppRoutes(environment))} />)
  expect(await screen.findByRole('heading', { name: 'Setup needed' })).toBeTruthy()
  expect(screen.queryByRole('navigation')).toBeNull()
  expect(screen.queryByRole('button', { name: 'Continue with Google' })).toBeNull()
})

it('P04_A1: only server-authorized context enters a protected route', async () => {
  const router = createMemoryRouter(createAppRoutes(environment, gateway(member)))
  render(<RouterProvider router={router} />)
  expect(await screen.findByRole('heading', { name: 'Overview' })).toBeTruthy()
  expect(screen.getByText('Fictional test member')).toBeTruthy()
})

it('P04_A2: denied context cannot deep-link; an old authorized context is rechecked on navigation', async () => {
  const auth = gateway(member)
  const router = createMemoryRouter(createAppRoutes(environment, auth))
  render(<RouterProvider router={router} />)
  await screen.findByRole('heading', { name: 'Overview' })
  vi.mocked(auth.readContext).mockResolvedValue({ state: 'denied' })
  await act(async () => { await router.navigate('/tasks') })
  expect(await screen.findByRole('heading', { name: 'Sign in to your workspace' })).toBeTruthy()
  expect(screen.queryByRole('heading', { name: 'My tasks' })).toBeNull()
  expect(screen.queryByText('Fictional test member')).toBeNull()
})

it('P04_A3: rejected callback offers safe recovery without echoing provider details', async () => {
  const auth = gateway({ state: 'signed_out' })
  render(<RouterProvider router={createMemoryRouter(createAppRoutes(environment, auth), { initialEntries: ['/auth/callback?error=denied&error_description=private-provider-diagnostic'] })} />)
  expect(await screen.findByRole('heading', { name: 'Sign-in could not be completed' })).toBeTruthy()
  expect(screen.queryByText(/private-provider-diagnostic/)).toBeNull()
  expect(auth.exchange).not.toHaveBeenCalled()
  expect(screen.getByRole('link', { name: 'Start sign-in again' }).getAttribute('href')).toBe('/login')
})

it('offers a return route for an unknown address', () => {
  render(<RouterProvider router={createMemoryRouter(createAppRoutes(environment, gateway({ state: 'signed_out' })), { initialEntries: ['/missing'] })} />)
  expect(screen.getByRole('heading', { name: 'Page not found' })).toBeTruthy()
})

it('catches render failure without exposing internal details', async () => {
  const log = vi.spyOn(console, 'error').mockImplementation(() => undefined)
  try {
    function Broken(): never { throw new Error('Synthetic private diagnostic') }
    const routes = createAppRoutes(environment, gateway({ state: 'signed_out' }))
    routes[0].element = <Broken />
    render(<RouterProvider router={createMemoryRouter(routes, { initialEntries: ['/missing'] })} />)
    expect(await screen.findByRole('heading', { name: 'The workspace could not open' })).toBeTruthy()
    expect(screen.queryByText(/Synthetic private diagnostic/)).toBeNull()
  } finally { log.mockRestore() }
})
