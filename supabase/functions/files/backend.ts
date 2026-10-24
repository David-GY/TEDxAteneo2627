import type {FileBackend} from './handler.ts'
import {bounded,digest,FileFault,MAX_FILE} from './validation.ts'
export function restBackend(url:string,publishable:string,serviceKey:string):FileBackend {
 async function rpc(token:string,name:string,args:Record<string,unknown>,key=publishable){const response=await fetch(url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,Authorization:token,'Content-Type':'application/json'},body:JSON.stringify(args)});const value=await response.json();if(!response.ok)throw new FileFault(typeof value.code==='string'?value.code:'COMMAND_UNAVAILABLE',value.message);if(!value||typeof value!=='object')throw new FileFault('COMMAND_UNAVAILABLE');return value}
 function path(value:string){if(!/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.(pdf|png|jpg)$/.test(value))throw new FileFault();return url+'/storage/v1/object/work-private/'+value}
 const serviceHeaders={apikey:serviceKey,Authorization:'Bearer '+serviceKey}
 async function get(objectPath:string){const response=await fetch(path(objectPath),{headers:serviceHeaders});if(!response.ok)throw new FileFault('COMMAND_UNAVAILABLE');return bounded(response.body,MAX_FILE)}
 return{
 async authenticate(token){const response=await fetch(url+'/auth/v1/user',{headers:{apikey:publishable,Authorization:token}});if(!response.ok)throw new FileFault('42501');const user=await response.json();if(typeof user.id!=='string')throw new FileFault('42501')},rpc,
 async put(objectPath,bytes,mime,hash){const response=await fetch(path(objectPath),{method:'POST',headers:{...serviceHeaders,'Content-Type':mime,'x-upsert':'false','cache-control':'no-store'},body:bytes as Uint8Array<ArrayBuffer>});if(!response.ok){if(response.status!==409&&response.status!==400)throw new FileFault('COMMAND_UNAVAILABLE');const existing=await get(objectPath);if(await digest(existing)!==hash)throw new FileFault('22023')}},
 async seal(id,hash,size,mime){return rpc('Bearer '+serviceKey,'seal_upload',{p_asset_id:id,p_sha256:hash,p_size:size,p_mime:mime},serviceKey)},get,
 }
}
