import {render,screen,fireEvent,waitFor,cleanup}from '@testing-library/react'
import {createMemoryRouter,RouterProvider}from'react-router'
import {it,expect,vi,afterEach}from'vitest'
import {Overview}from'./Overview'
import type{OverviewApi,OverviewRow}from'./api'
afterEach(cleanup)
const row:OverviewRow={id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',source:'task',title:'Fictional next action',owner:'Fictional River',dueOn:'2027-04-10',dueAt:null,lane:'actionable',action:'Update task progress',person:'Fictional River',state:'todo',committee:null,overdue:false}
it('P13_A1/A3: counts rendered rows and refetches completed work on focus',async()=>{const api:OverviewApi={read:vi.fn().mockResolvedValueOnce({items:[row],hasMore:false,refreshedAt:'2026-10-24T00:00:00Z'}).mockResolvedValue({items:[],hasMore:false,refreshedAt:'2026-10-24T01:00:00Z'})};render(<RouterProvider router={createMemoryRouter([{id:'workspace',path:'/',loader:()=>({termId:'term',memberId:'actor'}),Component:()=> <Overview api={api}/>}])}/>);await screen.findByRole('heading',{name:'Who is waiting on you · 1'});expect(screen.getAllByRole('link',{name:'Fictional next action'})).toHaveLength(1);fireEvent(window,new Event('focus'));await screen.findByRole('heading',{name:'Who is waiting on you · 0'});await waitFor(()=>expect(screen.queryByText('Fictional next action')).toBeNull())})
