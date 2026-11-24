import type {createSupabaseClient} from '../../../lib/supabase'
import {validSitePresentation,type SitePresentation} from './presentation'

export type PublishedSite={version:number;definition:SitePresentation|null;repaired:boolean}
export interface PublishedSiteApi{read(term:string):Promise<PublishedSite>;logo?(term:string,asset:string,approval:string):Promise<Blob>}
export function parsePublishedSite(input:unknown):PublishedSite{
 const v=input as PublishedSite|null
 if(!v||!Number.isSafeInteger(v.version)||v.version<0||typeof v.repaired!=='boolean'
  ||(v.definition!==null&&!validSitePresentation(v.definition))
  ||(v.version===0?(v.definition!==null||v.repaired):(v.repaired?v.definition!==null:v.definition===null)))throw Error('Published site settings unavailable')
 return {version:v.version,definition:v.definition,repaired:v.repaired}
}
export function createPublishedSiteApi(ready:ReturnType<typeof createSupabaseClient>):PublishedSiteApi{return{
 async read(term){const c=await ready;if(!c)throw Error('Published site settings unavailable');const{data,error}=await c.rpc('read_my_site_presentation',{p_term_id:term});if(error)throw Error('Published site settings unavailable');return parsePublishedSite(data)},
 async logo(term,asset,approval){const c=await ready;if(!c)throw Error();const{data,error}=await c.functions.invoke('files',{body:{action:'site_logo',term,assetId:asset,approvalId:approval}});if(error||!(data instanceof Blob)||data.size===0||data.size>5242880)throw Error('Approved logo unavailable');return data},
}}
