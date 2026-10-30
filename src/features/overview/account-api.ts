import type {createSupabaseClient} from '../../lib/supabase'
import type {Json} from '../../lib/database.types'
import {mapCommandError,type CommandResult} from '../../lib/commands'
import {defaultLayout,validateLayout,type Layout} from './layout'
export type SavedView={viewId:string;version:number;name:string;layout:Layout;supported?:boolean}
export type AccountLayoutsData={layout:Layout|null;source:'default'|'term'|'role'|'unit';ambiguous:boolean;repaired:boolean;views:SavedView[]}
export type ViewCommand={term:string;viewId:string;name:string;layout:Layout;version:number;archived:boolean}
export interface AccountLayoutApi{read(term:string):Promise<AccountLayoutsData>;run(command:ViewCommand,key:string):Promise<CommandResult<{viewId:string;version:number}>>}
const uuid=(x:unknown):x is string=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x)
export function createAccountLayoutApi(ready:ReturnType<typeof createSupabaseClient>):AccountLayoutApi{return{
 async read(term){const c=await ready;if(!c)throw Error('Account views unavailable');const{data,error}=await c.rpc('read_my_layout_configuration',{p_term_id:term}),v=data as unknown as AccountLayoutsData
  if(error||!v||!['default','term','role','unit'].includes(v.source)||typeof v.ambiguous!=='boolean'||typeof v.repaired!=='boolean'||!Array.isArray(v.views)||v.views.length>20||!v.views.every(x=>x&&uuid(x.viewId)&&Number.isInteger(x.version)&&x.version>0&&typeof x.name==='string'&&x.name.length<=80))throw Error('Account views unavailable')
  if(v.layout!==null&&!validateLayout(v.layout,'member')){v.layout=null;v.source='default';v.repaired=true}
  v.views=v.views.map(x=>({...x,supported:validateLayout(x.layout,'member'),layout:validateLayout(x.layout,'member')?x.layout:defaultLayout('member')}))
  if(v.views.some(x=>!x.supported))v.repaired=true
  return v},
 async run(command,key){try{const c=await ready;if(!c)throw Error();const{data,error}=await c.rpc('save_operational_view',{p_term_id:command.term,p_view_id:command.viewId,p_name:command.name,p_definition:command.layout as unknown as Json,p_archived:command.archived,p_expected_version:command.version,p_request_id:key});if(error)return{ok:false,error:mapCommandError(error)};const v=data as unknown as {viewId:string;version:number};if(!v||v.viewId!==command.viewId||!Number.isInteger(v.version)||v.version<=0)throw Error();return{ok:true,value:v}}catch{return{ok:false,error:mapCommandError({code:'COMMAND_UNAVAILABLE'})}}}
}}
