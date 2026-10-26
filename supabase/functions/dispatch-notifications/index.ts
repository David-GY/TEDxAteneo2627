import{dispatchHandler}from './handler.ts'
declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}
const url=Deno.env.get('SUPABASE_URL'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),secret=Deno.env.get('NOTIFICATION_DISPATCH_SECRET');if(!url||!service||!secret)throw Error('Dispatch configuration required');
Deno.serve(dispatchHandler({async rpc(name,args){const response=await fetch(url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:service,authorization:'Bearer '+service,'content-type':'application/json'},body:JSON.stringify(args),signal:AbortSignal.timeout(5000)});if(!response.ok)throw Error('Dispatch unavailable');return response.json()}},secret))
