const assert=require('node:assert/strict')
async function createFilePreview(db,ids){
 const{fileHandler}=await import('../supabase/functions/files/handler.ts'),{digest,FileFault}=await import('../supabase/functions/files/validation.ts'),bytes=new Map()
 const backend={
 async authenticate(token){if(token!=='Bearer local-synthetic')throw new FileFault('42501')},
 async rpc(token,name,a){await backend.authenticate(token);return db.transaction(async tx=>{await tx.exec('set local role authenticated');await tx.query(`select set_config('request.jwt.claim.sub',$1,true)`,[ids.viewer]);let r
 if(name==='reserve_upload')r=await tx.query('select public.reserve_upload($1,$2,$3,$4,$5,$6,$7,$8,$9) as value',[a.p_work_item_id,a.p_name,a.p_mime,a.p_size,a.p_sha256,a.p_source_id,a.p_source_version,a.p_expected_version,a.p_request_id])
 else if(name==='authorize_asset_download')r=await tx.query('select public.authorize_asset_download($1,$2,$3) as value',[a.p_work_item_id,a.p_asset_id,a.p_request_id])
 else throw new FileFault();return r.rows[0].value}).catch(e=>{throw e instanceof FileFault?e:new FileFault(e.code||'COMMAND_UNAVAILABLE',e.message)})},
 async put(path,b,mime,hash){void mime;if(bytes.has(path))assert.equal(await digest(bytes.get(path)),hash);else bytes.set(path,new Uint8Array(b))},
 async seal(id,hash,size,mime){return db.transaction(async tx=>{await tx.exec('set local role service_role');return(await tx.query('select public.seal_upload($1,$2,$3,$4)as value',[id,hash,size,mime])).rows[0].value}).catch(e=>{throw new FileFault(e.code)})},
 async get(path){if(!bytes.has(path))throw new FileFault('COMMAND_UNAVAILABLE');return new Uint8Array(bytes.get(path))},
 }
 return{handler:fileHandler(backend,'http://127.0.0.1'),bytes,backend}
}
module.exports={createFilePreview}
