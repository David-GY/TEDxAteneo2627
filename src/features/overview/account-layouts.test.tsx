import {render,screen,fireEvent,cleanup} from '@testing-library/react'
import {afterEach,expect,it,vi} from 'vitest'
import {AccountLayouts} from './AccountLayouts'
import type {AccountLayoutApi,AccountLayoutsData,ViewCommand} from './account-api'
import {defaultLayout} from './layout'
afterEach(cleanup)
const layout=defaultLayout('member'),data:AccountLayoutsData={layout,source:'unit',ambiguous:false,repaired:false,views:[{viewId:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',version:2,name:'Weekly follow-up',layout}]}
it('named account views apply presentation only and retry an uncertain save with the exact original payload and key',async()=>{
 const commands:{command:ViewCommand;key:string}[]=[],onUse=vi.fn(),onDefault=vi.fn()
 let attempts=0
 const api:AccountLayoutApi={read:async()=>data,run:async(command,key)=>{commands.push({command,key});if(attempts++===0)return{ok:false,error:{kind:'unavailable',message:'Result uncertain',retryable:true}};return{ok:true,value:{viewId:command.viewId,version:3}}}}
 render(<AccountLayouts api={api} term="term" identity="member" layout={layout} onUse={onUse} onDefault={onDefault} onLock={()=>{}}/>)
 await screen.findByRole('option',{name:'Weekly follow-up'})
 fireEvent.change(screen.getByLabelText('Saved operational view'),{target:{value:data.views[0].viewId}})
 fireEvent.click(screen.getByRole('button',{name:'Use saved view'}));expect(onUse).toHaveBeenCalledWith(layout)
 fireEvent.change(screen.getByLabelText('View name'),{target:{value:'Friday follow-up'}})
 fireEvent.click(screen.getByRole('button',{name:'Save current arrangement as a new view'}))
 await screen.findByText('Result uncertain');expect(screen.getByLabelText('View name').matches(':disabled')).toBe(true)
 fireEvent.click(screen.getByRole('button',{name:'Retry identical view save'}));await screen.findByText('Account view saved.')
 expect(commands).toHaveLength(2);expect(commands[1]).toEqual(commands[0]);expect(commands[0].command.name).toBe('Friday follow-up');expect(commands[0].command.layout).toEqual(layout)
})
it('retired published layout and read failure leave an explicit fallback without requiring member setup',async()=>{
 const onDefault=vi.fn(),api:AccountLayoutApi={read:async()=>({...data,source:'default',layout:null,repaired:true,views:[]}),run:vi.fn()}
 render(<AccountLayouts api={api} term="term" identity="member" layout={layout} onUse={()=>{}} onDefault={onDefault} onLock={()=>{}}/>)
 await screen.findByRole('alert');expect(screen.getByRole('alert').textContent).toContain('no longer supported');expect(onDefault).toHaveBeenCalledWith(null,'default')
 cleanup();render(<AccountLayouts api={{...api,read:async()=>{throw Error()}}} term="term" identity="member" layout={layout} onUse={()=>{}} onDefault={()=>{}} onLock={()=>{}}/>)
 await screen.findByText(/Account views unavailable/);expect(screen.queryByRole('button',{name:'Use saved view'})).toBeNull()
})
