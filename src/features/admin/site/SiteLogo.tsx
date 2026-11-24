import {useEffect,useState} from 'react'
import type {PublishedSiteApi} from './published'
export function SiteLogo({api,term,scope,asset,approval}:{api:PublishedSiteApi;term:string;scope:string;asset:string;approval:string}){
 const[key,setKey]=useState<{scope:string;asset:string;approval:string;url:string}|null>(null)
 useEffect(()=>{let live=true,url='';if(api.logo)void api.logo(term,asset,approval).then(blob=>{if(!live)return;url=URL.createObjectURL(blob);setKey({scope,asset,approval,url})}).catch(()=>{if(live)setKey(null)});return()=>{live=false;if(url)URL.revokeObjectURL(url)}},[api,term,scope,asset,approval])
 const current=key?.scope===scope&&key.asset===asset&&key.approval===approval?key:null
 return current?<img className="site-approved-logo" src={current.url} alt="Approved TEDx Ateneo de Manila U logo" onError={()=>setKey(null)}/>:null
}
