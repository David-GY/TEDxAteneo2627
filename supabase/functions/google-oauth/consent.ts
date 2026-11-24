import {bounded} from '../files/validation.ts'
import {schoolAddress} from './protocol.ts'

export type GoogleConsentConfig = {origin:string;clientId:string;clientSecret:string}
export type GoogleConsentErrorCode = 'invalid' | 'denied' | 'reconnect' | 'file_unavailable' | 'unavailable' | 'stale'
export class GoogleConsentError extends Error {
  constructor(readonly code:GoogleConsentErrorCode){super(code)}
}

export function schoolGoogleConsent(config:GoogleConsentConfig,callback:string,scopes:readonly string[],fetcher:typeof fetch=fetch) {
  if (new URL(config.origin).origin!==config.origin || !config.origin.startsWith('https://')
    || !/^[A-Za-z0-9-]+\.apps\.googleusercontent\.com$/.test(config.clientId) || !config.clientSecret.trim()) {
    throw Error('Google consent configuration is invalid')
  }
  const redirect=config.origin+callback
  const allowed=new Set([...scopes,'openid','email','https://www.googleapis.com/auth/userinfo.email'])
  const form=(values:Record<string,string>):RequestInit=>({method:'POST',body:new URLSearchParams(values)})
  const auth=(token:string)=>({Authorization:'Bearer '+token})
  const validToken=(value:unknown):value is string=>typeof value==='string'&&/^[\x21-\x7e]{1,4096}$/.test(value)

  async function request(endpoint:string|URL,init:RequestInit){
    try{return await fetcher(endpoint,{...init,redirect:'error',signal:AbortSignal.timeout(8000)})}
    catch{throw new GoogleConsentError('unavailable')}
  }
  async function data(response:Response):Promise<Record<string,unknown>>{
    try{
      const value=JSON.parse(new TextDecoder().decode(await bounded(response.body,16384)))
      if(value&&typeof value==='object'&&!Array.isArray(value))return value
    }catch{ /* Provider errors may contain private values. */ }
    throw new GoogleConsentError('unavailable')
  }
  async function tokens(input:Record<string,string>,requireScope:boolean){
    const response=await request('https://oauth2.googleapis.com/token',form({
      ...input,client_id:config.clientId,client_secret:config.clientSecret,
    }))
    const value=await data(response)
    if(!response.ok){
      if(value.error==='invalid_grant'||value.error==='invalid_token')throw new GoogleConsentError('reconnect')
      if(['admin_policy_enforced','access_denied','invalid_scope'].includes(String(value.error)))throw new GoogleConsentError('denied')
      throw new GoogleConsentError('unavailable')
    }
    if(value.scope!==undefined||requireScope){
      const granted=typeof value.scope==='string'?value.scope.trim().split(/\s+/):[]
      if(!scopes.every(scope=>granted.includes(scope))||granted.some(scope=>!allowed.has(scope)))throw new GoogleConsentError('denied')
    }
    if(!validToken(value.access_token)||value.token_type!=='Bearer'||typeof value.expires_in!=='number'
      ||!Number.isInteger(value.expires_in)||value.expires_in<=0||value.expires_in>3600)throw new GoogleConsentError('unavailable')
    return {access:value.access_token,refresh:value.refresh_token,expiresIn:value.expires_in}
  }
  return {
    authorize(email:string,attempt:{state:string;challenge:string}){
      if(!schoolAddress.test(email))throw new GoogleConsentError('denied')
      const url=new URL('https://accounts.google.com/o/oauth2/v2/auth')
      url.search=new URLSearchParams({client_id:config.clientId,redirect_uri:redirect,scope:[...scopes,'openid','email'].join(' '),
        response_type:'code',access_type:'offline',include_granted_scopes:'false',login_hint:email,prompt:'consent',
        state:attempt.state,code_challenge_method:'S256',code_challenge:attempt.challenge}).toString()
      return url.href
    },
    async exchange(code:string,verifier:string,email:string){
      if(!schoolAddress.test(email))throw new GoogleConsentError('denied')
      const token=await tokens({grant_type:'authorization_code',code,code_verifier:verifier,redirect_uri:redirect},true)
      if(!validToken(token.refresh))throw new GoogleConsentError('reconnect')
      const response=await request('https://openidconnect.googleapis.com/v1/userinfo',{headers:auth(token.access)})
      if(!response.ok)throw new GoogleConsentError(response.status===401?'reconnect':'unavailable')
      const identity=await data(response)
      if(identity.email_verified!==true||identity.email!==email)throw new GoogleConsentError('denied')
      return token.refresh
    },
    refresh(refresh:string){return tokens({grant_type:'refresh_token',refresh_token:refresh},false)},
    async revoke(refresh:string){
      const response=await request('https://oauth2.googleapis.com/revoke',form({token:refresh}))
      if(response.ok||(response.status===400&&(await data(response)).error==='invalid_token'))return
      throw new GoogleConsentError('unavailable')
    },
    request,data,auth,
  }
}
