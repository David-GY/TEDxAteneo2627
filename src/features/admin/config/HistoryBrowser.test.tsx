import {render,screen,fireEvent,waitFor} from '@testing-library/react'
import {it,expect,vi} from 'vitest'
import {HistoryBrowser} from './HistoryBrowser'
import type {ConfigurationApi,History} from './api'
it('older immutable publications use a stable cursor and prepare the selected old version for restoration',async()=>{
 const row=(version:number):History=>({id:String(version),kind:'workflow',definitionVersionId:'definition-'+version,rollbackVersionId:null,version,publishedAt:'2026-10-29T00:00:00Z',reason:'Fictional history',definition:{schemaVersion:1,stages:[{key:'review',label:'Review '+version,review:'one',reviewers:[],outcome:'approved',entryFields:[],reminderDays:7}]}})
 const history=vi.fn(async()=>({items:[row(1)],nextBefore:null})),restore=vi.fn(),api={history}as unknown as ConfigurationApi
 render(<HistoryBrowser api={api} type="type" kind="workflow" initial={Array.from({length:50},(_,i)=>row(51-i))} locked={false} restore={restore}/>);
 fireEvent.click(screen.getByRole('button',{name:'Load older publications'}));fireEvent.click(await screen.findByRole('button',{name:'Prepare restored draft from publication 1'}));expect(history).toHaveBeenCalledWith('type',2);expect(restore).toHaveBeenCalledWith(row(1));await waitFor(()=>expect(screen.queryByRole('button',{name:'Load older publications'})).toBeNull())
})
