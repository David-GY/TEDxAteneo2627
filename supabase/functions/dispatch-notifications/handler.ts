export interface DispatchBackend{rpc(name:string,args:Record<string,unknown>):Promise<unknown>}
const uuid=(v:unknown)=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
export function dispatchHandler(backend:DispatchBackend,secret:string){if(secret.length<32)throw Error('Dispatch configuration required');return async(request:Request)=>{
 const headers={'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'},reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
 if(request.method!=='POST')return reply({error:'method_not_allowed'},405);const supplied=request.headers.get('x-notification-dispatch-secret')??'',expected=secret;let difference=supplied.length^expected.length;for(let i=0;i<expected.length;i++)difference|=(supplied.charCodeAt(i)||0)^expected.charCodeAt(i);if(difference)return reply({error:'dispatch_denied'},403);if(request.body)return reply({error:'empty_body_required'},400);
 try{await backend.rpc('enqueue_notification_reminders',{p_limit:100});const jobs=await backend.rpc('claim_notification_jobs',{p_limit:20});if(!Array.isArray(jobs)||jobs.length>20||!jobs.every(j=>j&&uuid(j.id)&&uuid(j.lease)))throw Error();let delivered=0,deferred=0;
 for(let offset=0;offset<jobs.length;offset+=4){await Promise.all(jobs.slice(offset,offset+4).map(async j=>{try{const result=await backend.rpc('deliver_notification_job',{p_job_id:j.id,p_lease:j.lease})as{state?:string};if(result?.state==='delivered')delivered++;else deferred++}catch{deferred++}}))}return reply({claimed:jobs.length,delivered,deferred,externalAdapters:'disabled'});
 }catch{return reply({error:'dispatch_unavailable'},503)}
}}
