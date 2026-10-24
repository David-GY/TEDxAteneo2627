import {render,screen,waitFor} from '@testing-library/react'
import {it,expect,vi} from 'vitest'
import {RouterProvider,createMemoryRouter} from 'react-router'
import {createAppRoutes} from '../../app/router'
import {readClientEnvironment} from '../../lib/env'
import type {AuthGateway,AuthResult} from '../auth/gateway'
import type {TimelineApi} from './api'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',member={state:'authorized' as const,memberId:id,organizationId:id,termId:id,termMembershipId:id,displayName:'Fictional member',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:[]}
function gateway(result:AuthResult,timeline?:TimelineApi):AuthGateway{return{timeline,readContext:async()=>result,onChange:()=>()=>{},beginGoogle:async()=>{},exchange:async()=>{},signOut:async()=>{}}}
it('matches the static timeline route ahead of agreement IDs and preserves sign-in filter state',async()=>{
 const read=vi.fn(async()=>null),g=gateway(member,{read,context:vi.fn(),save:vi.fn()}),path='/working-together/timeline?date=2027-04-17&scale=week&view=list&page=2'
 const router=createMemoryRouter(createAppRoutes(readClientEnvironment({}),g),{initialEntries:['/login?returnTo='+encodeURIComponent(path)]});render(<RouterProvider router={router}/>);await screen.findByText('Timeline access changed');expect(router.state.location.pathname+router.state.location.search).toBe(path);expect(read).toHaveBeenCalledWith(id,expect.anything(),2)
})
it('a guest deep link redirects without calling the new committee RPC',async()=>{
 const read=vi.fn(),g=gateway({state:'authorized',audience:'guest',guestAccessId:id,organizationId:id,termId:id,displayName:'Fictional guest',expiresAt:member.expiresAt,capabilities:[]},{read,context:vi.fn(),save:vi.fn()})
 const router=createMemoryRouter(createAppRoutes(readClientEnvironment({}),g),{initialEntries:['/working-together/timeline']});render(<RouterProvider router={router}/>);await waitFor(()=>expect(router.state.location.pathname).toBe('/shared'));expect(read).not.toHaveBeenCalled()
})
