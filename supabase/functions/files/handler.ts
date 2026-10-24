import {bounded,digest,FileFault,MAX_FILE,validateFile} from './validation.ts'
export interface FileBackend {
 authenticate(token:string):Promise<void>
 rpc(token:string,name:string,args:Record<string,unknown>):Promise<Record<string,unknown>>
 put(path:string,bytes:Uint8Array,mime:string,hash:string):Promise<void>
 seal(id:string,hash:string,size:number,mime:string):Promise<Record<string,unknown>>
 get(path:string):Promise<Uint8Array>
}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
export function fileHandler(backend:FileBackend,origin:string){return async(request:Request):Promise<Response>=>{
 const headers:Record<string,string>={'Cache-Control':'no-store, private','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'none'; sandbox",'Vary':'Origin'}
 const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{...headers,'Content-Type':'application/json'}})
 if(request.headers.get('origin')&&request.headers.get('origin')!==origin)return json({error:{code:'42501'}},403)
 if(request.headers.get('origin')===origin)headers['Access-Control-Allow-Origin']=origin
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers:{...headers,'Access-Control-Allow-Methods':'POST','Access-Control-Allow-Headers':'authorization,apikey,x-client-info,content-type'}})
 if(request.method!=='POST')return json({error:{code:'22023'}},405)
 try{
 const token=request.headers.get('authorization')??'';if(!/^Bearer [^\s]+$/.test(token))throw new FileFault('42501');await backend.authenticate(token)
 const raw=await bounded(request.body,MAX_FILE+65536),copy=new Request(request.url,{method:'POST',headers:request.headers,body:raw as Uint8Array<ArrayBuffer>})
 if(request.headers.get('content-type')?.startsWith('multipart/form-data')){
 const form=await copy.formData(),file=form.get('file'),meta=JSON.parse(String(form.get('metadata')))
 if(!(file instanceof File)||!meta||!uuid.test(meta.workId)||!uuid.test(meta.key)||!Number.isInteger(meta.version))throw new FileFault()
 const bytes=new Uint8Array(await file.arrayBuffer()),checked=await validateFile(file.name,file.type,bytes)
 const reserveArgs={p_work_item_id:meta.workId,p_name:file.name,p_mime:checked.mime,p_size:checked.size,p_sha256:checked.sha256,p_source_id:meta.sourceId??null,p_source_version:meta.sourceVersion??null,p_expected_version:meta.version,p_request_id:meta.key}
 const reservation=await backend.rpc(token,'reserve_upload',reserveArgs)
 if(typeof reservation.path!=='string'||!uuid.test(String(reservation.assetId)))throw new FileFault('COMMAND_UNAVAILABLE')
 await backend.put(reservation.path,bytes,checked.mime,checked.sha256)
 await backend.rpc(token,'reserve_upload',reserveArgs)
 const sealed=await backend.seal(String(reservation.assetId),checked.sha256,checked.size,checked.mime)
 return json(sealed)
 }
 const data=await copy.json();if(!data||!uuid.test(data.workId)||!uuid.test(data.assetId)||!uuid.test(data.key)||data.action!=='download'&&data.action!=='open')throw new FileFault()
 const args={p_work_item_id:data.workId,p_asset_id:data.assetId,p_request_id:data.key},asset=await backend.rpc(token,'authorize_asset_download',args)
 if(data.action==='open'){if(asset.kind!=='working_link'||typeof asset.url!=='string')throw new FileFault();return json({url:asset.url})}
 if(asset.kind!=='upload'||typeof asset.path!=='string')throw new FileFault()
 const bytes=await backend.get(asset.path);if(bytes.length!==asset.size||await digest(bytes)!==asset.sha256)throw new FileFault('55000')
 await backend.rpc(token,'authorize_asset_download',args)
 const ext=asset.mime==='application/pdf'?'pdf':asset.mime==='image/png'?'png':'jpg'
 return new Response(bytes as Uint8Array<ArrayBuffer>,{headers:{...headers,'Content-Type':'application/octet-stream','Content-Disposition':`attachment; filename="download.${ext}"`,'Content-Length':String(bytes.length)}})
 }catch(error){const code=error instanceof FileFault?error.code:error instanceof SyntaxError?'22023':'COMMAND_UNAVAILABLE';return json({error:{code,message:error instanceof FileFault?error.tag:'file_request_rejected'}},code==='42501'?403:code==='40001'?409:code==='COMMAND_UNAVAILABLE'?503:400)}
}}
