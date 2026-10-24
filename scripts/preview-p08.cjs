const http=require('node:http')
const {createDeliverablesDatabase}=require('./deliverables-db.cjs')
async function createPreview({port=5174,authoring=false,tasks=false,synergies=false}={}){
  const {db,ids}=await (authoring?require('./deliverable-authoring-db.cjs').createAuthoringDatabase():createDeliverablesDatabase())
  try{
    if(tasks)await db.transaction(async tx=>{await tx.exec('set local role authenticated');await tx.query(`select set_config('request.jwt.claim.sub',$1,true)`,[ids.viewer]);await tx.query(`select public.create_task($1,$2,gen_random_uuid())`,[ids.term,{title:'Fictional owned task draft',summary:'Synthetic local task example',body:'Fictional task notes',classification:'restricted',taskType:'ordinary',leadUnitId:null,assigneeId:ids.viewer,assignedUnitId:null,collaborators:[],checklist:[],dueOn:'2027-04-10',dueAt:null,parentId:null,reason:'Fictional task seed'}])})
    const synergyFixture=synergies?await require('./synergy-interface-fixtures.cjs').setupSynergyInterface(db,ids):null
    const filePreview=await require('./files-preview.cjs').createFilePreview(db,ids)
    const main=await(await fetch('http://127.0.0.1:5173/src/main.tsx')).text()
    const suffix=main.match(/react-router[.]js(\?v=[^"]+)/)[1]
    const vite='http://127.0.0.1:5173'
    const html=`<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${synergies?'P15':tasks?'P14':authoring?'P09':'P08'} synthetic database preview</title><script type="module">
      import RefreshRuntime from '${vite}/@react-refresh';RefreshRuntime.injectIntoGlobalHook(window);window.$RefreshReg$=()=>{};window.$RefreshSig$=()=>type=>type;window.__vite_plugin_react_preamble_installed__=true;
      </script></head><body><p style="margin:0;padding:12px 20px;background:#252624;color:white">Local synthetic PostgreSQL + isolated file bytes · simulated sign-in · no real Supabase Storage/Auth</p><div id="root"></div><script type="module">
      import React from '${vite}/node_modules/.vite/deps/react.js${suffix}';
      import ReactDOMClient from '${vite}/node_modules/.vite/deps/react-dom_client.js${suffix}';
      import {createBrowserRouter,RouterProvider} from '${vite}/node_modules/.vite/deps/react-router.js${suffix}';
      import {createAppRoutes} from '${vite}/src/app/router.tsx';
      import {createDeliverablesApi} from '${vite}/src/features/deliverables/api.ts';
      import {createDeliverableCommands} from '${vite}/src/features/deliverables/commands.ts';
      import {createDependenciesApi} from '${vite}/src/features/tasks/dependenciesApi.ts';
      import {createSynergiesApi} from '${vite}/src/features/synergies/api.ts';
      import {createOverviewApi} from '${vite}/src/features/overview/api.ts';
      import {createFilesApi} from '${vite}/src/features/files/api.ts';
      import {createCommentsApi} from '${vite}/src/features/comments/api.ts';
      import {createTasksApi} from '${vite}/src/features/tasks/api.ts';
      import '${vite}/src/styles/tokens.css';import '${vite}/src/styles/global.css';import '${vite}/node_modules/@fontsource-variable/karla/index.css';
      const previewReceiver=${synergies?'true':'false'}&&new URL(location.href).searchParams.get('synthetic')==='receiver';
      const ready=Promise.resolve({functions:{invoke:async(name,{body})=>{const response=await fetch('/__files',{method:'POST',headers:body instanceof FormData?{}:{'content-type':'application/json'},body:body instanceof FormData?body:JSON.stringify(body)});return response.ok?{data:response.headers.get('content-type').includes('application/octet-stream')?await response.blob():await response.json(),error:null}:{data:null,error:{context:response}}}},rpc:(name,args)=>fetch('/__rpc',{method:'POST',headers:{'content-type':'application/json','x-preview-subject':previewReceiver?'receiver':'requester'},body:JSON.stringify({name,args})}).then(r=>r.json())});
      const context={state:'authorized',memberId:previewReceiver?'${ids.owner}':'${ids.viewer}',displayName:previewReceiver?'Fictional Alex (synthetic receiving head)':'Fictional River (synthetic requesting head)',organizationId:'${ids.org}',termId:'${ids.term}',termMembershipId:previewReceiver?'66666666-6666-4666-8666-666666666661':'${ids.viewerMembership}',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:['workspace.read']};
      const gateway={dependencies:createDependenciesApi(ready),synergies:createSynergiesApi(ready),overview:createOverviewApi(ready),files:previewReceiver?undefined:createFilesApi(ready),comments:previewReceiver?undefined:createCommentsApi(ready),deliverables:createDeliverablesApi(ready),${tasks?'tasks:createTasksApi(ready),':''}${authoring?'deliverableCommands:createDeliverableCommands(ready),':''}readContext:async()=>context,onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}};
      ReactDOMClient.createRoot(document.getElementById('root')).render(React.createElement(RouterProvider,{router:createBrowserRouter(createAppRoutes({state:'not_configured',issues:[]},gateway))}));
      </script></body></html>`
    const server=http.createServer(async(req,res)=>{
      res.setHeader('cache-control','no-store')
      // Injected Vite CSS uses root-relative font paths; keep the separate preview origin faithful.
      if(req.method==='GET'&&/\.(woff2?|ttf)(?:\?|$)/.test(req.url)){
        try{const font=await fetch(vite+req.url);res.writeHead(font.status,{'content-type':font.headers.get('content-type')||'font/woff2'});res.end(Buffer.from(await font.arrayBuffer()));return}
        catch{res.writeHead(502);res.end();return}
      }
      if(req.url==='/__files'&&req.method==='POST'){
        try{const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>5308416)throw new Error('too_large');chunks.push(chunk)}
        const response=await filePreview.handler(new Request('http://127.0.0.1/__files',{method:'POST',headers:{'content-type':req.headers['content-type']||'','authorization':'Bearer local-synthetic'},body:Buffer.concat(chunks)}));res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));return
        }catch{res.writeHead(400,{'content-type':'application/json'});res.end('{"error":{"code":"22023"}}');return}
      }
      if(req.url==='/__rpc'&&req.method==='POST'){
        try{
          let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>100000)throw new Error('too_large')}
          const {name,args:a}=JSON.parse(raw)
          const result=await db.transaction(async tx=>{
            await tx.exec('set local role authenticated')
            await tx.query(`select set_config('request.jwt.claim.sub',$1,true)`,[synergies&&req.headers['x-preview-subject']==='receiver'?ids.owner:ids.viewer])
            if(name==='list_deliverables')return tx.query('select public.list_deliverables($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as value',[a.p_term_id,a.p_phase,a.p_unit_id,a.p_owner_id,a.p_blocked,a.p_overdue,a.p_involves_my_unit,a.p_review_pending,a.p_page,a.p_page_size])
            if(name==='list_synergies')return tx.query('select public.list_synergies($1,$2,$3,$4) as value',[a.p_term_id,a.p_view,a.p_parent_id,a.p_page])
            if(name==='synergy_options')return tx.query('select public.synergy_options($1,$2) as value',[a.p_term_id,a.p_parent_id])
            if(name==='read_task_dependencies')return tx.query('select public.read_task_dependencies($1,$2) as value',[a.p_successor_id,a.p_search??''])
            if(name==='add_task_dependency')return tx.query('select public.add_task_dependency($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_predecessor_id,a.p_successor_id,a.p_type,a.p_required,a.p_expected_predecessor_version,a.p_expected_successor_version,a.p_reason,a.p_request_id])
            if(name==='remove_task_dependency')return tx.query('select public.remove_task_dependency($1,$2,$3,$4,$5,$6) as value',[a.p_dependency_id,a.p_expected_predecessor_version,a.p_expected_successor_version,a.p_reason,a.p_scope_exception,a.p_request_id])
            if(name==='read_synergy')return tx.query('select public.read_synergy($1) as value',[a.p_agreement_id])
            if(name==='read_contribution')return tx.query('select public.read_contribution($1) as value',[a.p_work_item_id])
            if(name==='propose_synergy')return tx.query('select public.propose_synergy($1,$2,$3,$4,$5,$6,$7) as value',[a.p_parent_id,a.p_receiver_unit_id,a.p_terms,a.p_expected_parent_version,a.p_request_id,a.p_agreement_id??null,a.p_expected_agreement_version??null])
            if(name==='respond_to_synergy')return tx.query('select public.respond_to_synergy($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_agreement_id,a.p_action,a.p_expected_version,a.p_expected_revision,a.p_owner_id,a.p_terms,a.p_reason,a.p_request_id])
            if(name==='read_overview')return tx.query('select public.read_overview($1) as value',[a.p_term_id])
            if(name==='read_files')return tx.query('select public.read_files($1) as value',[a.p_work_item_id])
            if(name==='finalize_upload')return tx.query('select public.finalize_upload($1,$2,$3,$4) as value',[a.p_work_item_id,a.p_asset_ids,a.p_expected_version,a.p_request_id])
            if(name==='save_working_link')return tx.query('select public.save_working_link($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_work_item_id,a.p_asset_id,a.p_url,a.p_name,a.p_notes,a.p_label,a.p_expected_version,a.p_request_id])
            if(name==='read_comments')return tx.query('select public.read_comments($1,$2) as value',[a.p_work_item_id,a.p_page])
            if(name==='read_comment_history')return tx.query('select public.read_comment_history($1) as value',[a.p_comment_id])
            if(name==='mention_candidates')return tx.query('select public.mention_candidates($1,$2) as value',[a.p_work_item_id,a.p_search])
            if(name==='add_comment')return tx.query('select public.add_comment($1,$2,$3,$4,$5) as value',[a.p_work_item_id,a.p_body,a.p_mentions,a.p_draft,a.p_request_id])
            if(name==='revise_comment')return tx.query('select public.revise_comment($1,$2,$3,$4,$5,$6,$7) as value',[a.p_comment_id,a.p_body,a.p_mentions,a.p_action,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='read_deliverable')return tx.query('select public.read_deliverable($1) as value',[a.p_work_item_id])
            if(tasks&&name==='read_owned_tasks')return tx.query('select public.read_owned_tasks($1,$2) as value',[a.p_term_id,a.p_page])
            if(tasks&&name==='read_tasks')return tx.query('select public.read_tasks($1,$2,$3) as value',[a.p_term_id,a.p_view,a.p_page])
            if(tasks&&name==='read_task')return tx.query('select public.read_task($1) as value',[a.p_work_item_id])
            if(tasks&&name==='task_options')return tx.query('select public.task_options($1) as value',[a.p_term_id])
            if(tasks&&name==='create_task')return tx.query('select public.create_task($1,$2,$3) as value',[a.p_term_id,a.p_data,a.p_request_id])
            if(tasks&&['update_task','assign_task','transition_task'].includes(name))return tx.query(`select public.${name}($1,$2,$3,$4) as value`,[a.p_work_item_id,a.p_data,a.p_expected_version,a.p_request_id])
            if(authoring&&name==='read_deliverable_authoring')return tx.query('select public.read_deliverable_authoring($1,$2) as value',[a.p_term_id,a.p_work_item_id])
            if(authoring&&name==='create_deliverable')return tx.query('select public.create_deliverable($1,$2,$3,$4) as value',[a.p_term_id,a.p_data,a.p_propose,a.p_request_id])
            if(authoring&&name==='update_deliverable')return tx.query('select public.update_deliverable($1,$2,$3,$4) as value',[a.p_work_item_id,a.p_data,a.p_expected_version,a.p_request_id])
            if(authoring&&name==='transition_deliverable')return tx.query('select public.transition_deliverable($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_action,a.p_reason,a.p_evidence,a.p_expected_version,a.p_request_id,a.p_criteria_revision])
            throw new Error('unsupported_rpc')
          })
          res.setHeader('content-type','application/json');res.end(JSON.stringify({data:result.rows[0].value,error:null}));return
        }catch(error){res.setHeader('content-type','application/json');res.end(JSON.stringify({data:null,error:{code:(authoring||tasks)&&/^command_/.test(error.message)?error.code:'COMMAND_UNAVAILABLE',message:(authoring||tasks)&&/^command_/.test(error.message)?error.message:'preview_query_failed'}}));return}
      }
      if(req.method!=='GET'){res.writeHead(405);res.end();return}
      res.setHeader('content-type','text/html; charset=utf-8');res.end(html)
    })
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve)})
    return{db,ids,synergyFixture,url:`http://127.0.0.1:${port}`,close:async()=>{await new Promise(resolve=>server.close(resolve));await db.close()}}
  }catch(error){await db.close();throw error}
}
module.exports={createPreview}
if(require.main===module)createPreview().then(p=>{console.log(`P08 LIVE synthetic PostgreSQL preview: ${p.url}/deliverables`)}).catch(e=>{console.error(e.message);process.exitCode=1})
