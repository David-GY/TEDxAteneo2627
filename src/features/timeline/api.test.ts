import {it,expect,vi} from 'vitest'
import {createTimelineApi} from './api'
import {parseTimelineQuery,timelineSearch} from './filters'
import {safeReturnPath} from '../auth/redirects'
import type {createSupabaseClient} from '../../lib/supabase'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',key='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa9'
const row={id,version:1,plannedStartOn:null,dueOn:'2027-04-10',dueAt:null,type:'task',title:'Fictional permitted work',owner:{id,name:'Fictional member'},primaryUnit:null,participatingUnits:[],phase:null,status:'todo',endOn:'2027-04-10',originalDueOn:'2027-04-10',originalDueAt:null,blocked:false,overdue:false,href:'/tasks/'+id}
function setup(data:unknown,error:unknown=null){const rpc=vi.fn(async()=>({data,error})),api=createTimelineApi(Promise.resolve({rpc}) as unknown as ReturnType<typeof createSupabaseClient>);return{api,rpc}}
it('validates canonical IDs, dates, routes and both-loaded edge endpoints at the RPC boundary',async()=>{
 const result={items:[row],total:1,page:1,pageSize:50,options:{units:[],owners:[],phases:[]},dependencies:[]}
 expect((await setup(result).api.read(id,{},1))?.items[0].id).toBe(id)
 for(const bad of [{...result,items:[row,row]},{...result,items:[{...row,href:'https://example.org'}]},{...result,items:[{...row,endOn:'2027-04-11'}]},{...result,dependencies:[{id:key,predecessorId:key,successorId:id,type:'finish_to_start',required:true}]}])await expect(setup(bad).api.read(id,{},1)).rejects.toThrow('Timeline unavailable')
 expect(await setup(null).api.read(id,{},1)).toBeNull();await expect(setup(result,{code:'42501'}).api.read(id,{},1)).rejects.toThrow()
})
it('sends nullable schedule starts, exact expected version and caller key; malformed receipts never succeed',async()=>{
 const{api,rpc}=setup({workItemId:id,version:2});expect((await api.save(id,null,1,key)).ok).toBe(true)
 expect(rpc).toHaveBeenCalledWith('update_work_schedule',{p_work_item_id:id,p_planned_start_on:null,p_expected_version:1,p_request_id:key})
 expect((await setup({workItemId:key,version:2}).api.save(id,'2027-04-01',1,key)).ok).toBe(false)
 const stale=await setup(null,{code:'40001'}).api.save(id,'2027-04-01',1,key);expect(!stale.ok&&stale.error.kind).toBe('stale_version')
 expect((await setup(null).api.save(id,'2027-02-29',1,key)).ok).toBe(false)
})
it('checks exact record context and excludes malformed reverse ranges',async()=>{
 const context={id,version:1,plannedStartOn:null,dueOn:'2027-04-10',dueAt:null,canSchedule:true}
 expect(await setup(context).api.context(id)).toEqual(context)
 await expect(setup({...context,id:key}).api.context(id)).rejects.toThrow()
 await expect(setup({...context,plannedStartOn:'2027-04-11'}).api.context(id)).rejects.toThrow()
})
it('preserves only safe timeline filters across sign-in and chart/list pagination',()=>{
 const q=parseTimelineQuery('?date=2027-04-17&scale=week&view=list&unit='+id+'&unit='+id+'&owner='+key+'&phase=Event%20day&page=2&blocked=1')
 expect(q.units).toEqual([id]);expect(parseTimelineQuery(timelineSearch(q))).toEqual(q)
 expect(safeReturnPath('/working-together/timeline'+timelineSearch(q))).toBe('/working-together/timeline'+timelineSearch(q))
 expect(safeReturnPath('/working-together/timeline?redirect=https://evil.invalid&date=bad')).not.toContain('evil')
 expect(safeReturnPath('/working-together/timeline/evil')).toBe('/')
 expect(safeReturnPath('//evil.invalid/working-together/timeline')).toBe('/')
 expect(parseTimelineQuery('?date=2027-02-29&page=-1&owner=bad','2026-10-25').anchor).toBe('2026-10-25')
})
