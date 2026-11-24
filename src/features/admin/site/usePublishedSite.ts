import {useEffect,useState} from 'react'
import {parsePublishedSite,type PublishedSite,type PublishedSiteApi} from './published'

// Existing auth revalidation refreshes the publication. No new poll or persisted cache.
// Scope changes immediately hide the previous result; late reads cannot cross identities.
export function usePublishedSite(api:PublishedSiteApi|undefined,term:string,scope:string,accessState:string,refreshToken?:unknown,publicationEpoch=0){
 const[state,setState]=useState<{api:PublishedSiteApi;scope:string;value:PublishedSite|null;unavailable:boolean}|null>(null)
 useEffect(()=>{let live=true
  if(api&&accessState==='idle')void api.read(term).then(parsePublishedSite).then(value=>{if(live)setState({api,scope,value,unavailable:value.repaired})}).catch(()=>{if(live)setState({api,scope,value:null,unavailable:true})})
  return()=>{live=false}
 },[api,term,scope,accessState,refreshToken,publicationEpoch])
 const current=state?.scope===scope&&state.api===api?state:null
 return {presentation:current?.value?.definition??undefined,unavailable:current?.unavailable??false}
}
