import {fileHandler} from './handler.ts'
import {restBackend} from './backend.ts'
declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}
const url=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_ANON_KEY'),secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),origin=Deno.env.get('APP_ORIGIN')
// Fail closed without a named origin and server-only credentials; never print environment values.
if(!url||!key||!secret||!origin||new URL(origin).origin!==origin)throw new Error('File service configuration required')
Deno.serve(fileHandler(restBackend(url,key,secret),origin))
