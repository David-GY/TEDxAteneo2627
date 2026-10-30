const http=require('node:http')
const {createDeliverablesDatabase}=require('./deliverables-db.cjs')
async function createPreview({port=5174,authoring=false,tasks=false,synergies=false,contextDelay=0,financeAuthorityPreview=false,notificationPreview=false,calendarPreview=false,organizationPreview=false,accessPreview=false,adoptionPreview=false}={}){
  const {db,ids}=await (authoring?require('./deliverable-authoring-db.cjs').createAuthoringDatabase():createDeliverablesDatabase())
  try{
    if(tasks)await db.transaction(async tx=>{await tx.exec('set local role authenticated');await tx.query(`select set_config('request.jwt.claim.sub',$1,true)`,[ids.viewer]);await tx.query(`select public.create_task($1,$2,gen_random_uuid())`,[ids.term,{title:'Fictional owned task draft',summary:'Synthetic local task example',body:'Fictional task notes',classification:'restricted',taskType:'ordinary',leadUnitId:null,assigneeId:ids.viewer,assignedUnitId:null,collaborators:[],checklist:[],dueOn:'2027-04-10',dueAt:null,parentId:null,reason:'Fictional task seed'}])})
    const synergyFixture=synergies?await require('./synergy-interface-fixtures.cjs').setupSynergyInterface(db,ids):null
    const filePreview=await require('./files-preview.cjs').createFilePreview(db,ids)
    const main=await(await fetch('http://127.0.0.1:5173/src/main.tsx')).text()
    const suffix=main.match(/react-router[.]js(\?v=[^"]+)/)[1]
    const vite='http://127.0.0.1:5173'
    let html=`<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Local synthetic workspace preview</title><script type="module">
      import RefreshRuntime from '${vite}/@react-refresh';RefreshRuntime.injectIntoGlobalHook(window);window.$RefreshReg$=()=>{};window.$RefreshSig$=()=>type=>type;window.__vite_plugin_react_preamble_installed__=true;
      </script></head><body><p style="margin:0;padding:12px 20px;background:#252624;color:white">Local synthetic PostgreSQL + isolated file bytes · simulated sign-in · no real Supabase Storage/Auth${financeAuthorityPreview?' | fictional acceptance/FIN/MCD policy/designations/budget; no institutional approval':''}${notificationPreview?' | fictional notification custodian; manual seeded dispatcher; no external delivery':''}${accessPreview?' | fictional delegation ceiling/custody; preview-bound role and assignment changes only; no real authority':''}${organizationPreview?' | fictional organization administrator; preview-bound changes only; no real roster or institutional approval':''}${calendarPreview?' | fictional calendar publishing authority; locations informational; no Google sync':''}</p>${adoptionPreview?'<nav aria-label="Synthetic role scenarios" style="padding:12px;display:flex;gap:16px;flex-wrap:wrap"><a href="/tasks?synthetic=associate">Member work</a><a href="/deliverables?synthetic=receiver">Head work</a><a href="/deliverables/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8?synthetic=guest">Guest shared work</a><a href="/resources?synthetic=associate">Member help</a></nav>':''}<div id="root"></div><script type="module">
      import React from '${vite}/node_modules/.vite/deps/react.js${suffix}';
      import ReactDOMClient from '${vite}/node_modules/.vite/deps/react-dom_client.js${suffix}';
      import {createBrowserRouter,RouterProvider} from '${vite}/node_modules/.vite/deps/react-router.js${suffix}';
      import {createGuestContactGateway} from '${vite}/src/features/account/guestContacts.ts';
      import {createAccessApi} from '${vite}/src/features/admin/access/api.ts';
      import {createProcessApi} from '${vite}/src/features/admin/process/api.ts';
      import {createLayoutAdminApi} from '${vite}/src/features/admin/layouts/api.ts';
      import {createConfigurationApi} from '${vite}/src/features/admin/config/api.ts';
      import {createOrganizationApi} from '${vite}/src/features/admin/organization/api.ts';
      import {createResourcesApi} from '${vite}/src/features/resources/api.ts';
      import {createPeopleGateway} from '${vite}/src/features/people/gateway.ts';
      import {createProfileGateway} from '${vite}/src/features/account/gateway.ts';
      import {createAppRoutes} from '${vite}/src/app/router.tsx';
      import {createDeliverablesApi} from '${vite}/src/features/deliverables/api.ts';
      import {createDeliverableCommands} from '${vite}/src/features/deliverables/commands.ts';
      import {createTimelineApi} from '${vite}/src/features/timeline/api.ts';
      import {createInboxApi} from '${vite}/src/features/approvals/inbox-api.ts';
      import {createApprovalsApi} from '${vite}/src/features/approvals/api.ts';
      import {createRequestsApi} from '${vite}/src/features/requests/api.ts';
      import {createFinanceApi} from '${vite}/src/features/finance/api.ts';
      import {createCalendarApi} from '${vite}/src/features/calendar/api.ts';
      import {createNotificationsApi} from '${vite}/src/features/notifications/api.ts';
      import {createReadinessApi} from '${vite}/src/features/deliverables/readiness-api.ts';
      import {createPublicityApi} from '${vite}/src/features/publicity/api.ts';
      import {createLedgerApi} from '${vite}/src/features/finance/ledger-api.ts';
      import {createFinAuthorityApi} from '${vite}/src/features/finance/authority-api.ts';
      import {createFormsApi} from '${vite}/src/features/forms/api.ts';
      import {createCatalogApi} from '${vite}/src/features/requests/catalog/api.ts';
      import {createHandoffsApi} from '${vite}/src/features/handoffs/api.ts';
      import {createDependenciesApi} from '${vite}/src/features/tasks/dependenciesApi.ts';
      import {createSynergiesApi} from '${vite}/src/features/synergies/api.ts';
      import {createSearchApi} from '${vite}/src/features/search/api.ts';
      import {createOverviewApi} from '${vite}/src/features/overview/api.ts';
      import {createFilesApi} from '${vite}/src/features/files/api.ts';
      import {createCommentsApi} from '${vite}/src/features/comments/api.ts';
      import {createTasksApi} from '${vite}/src/features/tasks/api.ts';
      import '${vite}/src/styles/tokens.css';import '${vite}/src/styles/global.css';import '${vite}/node_modules/@fontsource-variable/karla/index.css';
      const previewAssociate=${synergies||financeAuthorityPreview?'true':'false'}&&new URL(location.href).searchParams.get('synthetic')==='associate';
      const previewReceiver=${synergies||financeAuthorityPreview?'true':'false'}&&new URL(location.href).searchParams.get('synthetic')==='receiver';
      const previewGuest=${adoptionPreview?'true':'false'}&&new URL(location.href).searchParams.get('synthetic')==='guest';
      const ready=Promise.resolve({functions:{invoke:async(name,{body})=>{const response=await fetch('/__files',{method:'POST',headers:{...(body instanceof FormData?{}:{'content-type':'application/json'}),'x-preview-subject':previewGuest?'guest':previewAssociate?'associate':previewReceiver?'receiver':'requester'},body:body instanceof FormData?body:JSON.stringify(body)});return response.ok?{data:response.headers.get('content-type').includes('application/octet-stream')?await response.blob():await response.json(),error:null}:{data:null,error:{context:response}}}},rpc:(name,args)=>fetch('/__rpc',{method:'POST',headers:{'content-type':'application/json','x-preview-subject':previewGuest?'guest':previewAssociate?'associate':previewReceiver?'receiver':'requester'},body:JSON.stringify({name,args})}).then(r=>r.json())});
      let context={state:'authorized',memberId:previewAssociate?'${ids.outsider}':previewReceiver?'${ids.owner}':'${ids.viewer}',displayName:previewAssociate?'${adoptionPreview?'Fictional Morgan (synthetic member)':'Fictional associate (synthetic reviewer)'}':previewReceiver?'Fictional Alex (synthetic receiving head)':'Fictional River (synthetic requesting head)',organizationId:'${ids.org}',termId:'${ids.term}',termMembershipId:previewAssociate?'${ids.outsider}':previewReceiver?'66666666-6666-4666-8666-666666666661':'${ids.viewerMembership}',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:${organizationPreview?"(previewAssociate||previewReceiver?['workspace.read']:['workspace.read','admin.configure','roles.manage'])":"['workspace.read']"}};
      if(previewGuest)context={state:'authorized',audience:'guest',guestAccessId:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',organizationId:'${ids.org}',termId:'${ids.term}',displayName:'Fictional invited guest',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:[]};
      const gateway={search:createSearchApi(ready),layouts:createLayoutAdminApi(ready),process:createProcessApi(ready),configuration:createConfigurationApi(ready),guestContacts:createGuestContactGateway(ready),access:createAccessApi(ready),organization:createOrganizationApi(ready),resources:createResourcesApi(ready),people:createPeopleGateway(ready),profile:createProfileGateway(ready),calendar:createCalendarApi(ready),notifications:createNotificationsApi(ready),readiness:createReadinessApi(ready),publicity:createPublicityApi(ready),ledger:createLedgerApi(ready),finAuthority:createFinAuthorityApi(ready),finance:createFinanceApi(ready),inbox:createInboxApi(ready),approvals:createApprovalsApi(ready),requests:createRequestsApi(ready),forms:createFormsApi(ready),catalog:createCatalogApi(ready),timeline:createTimelineApi(ready),handoffs:createHandoffsApi(ready),dependencies:createDependenciesApi(ready),synergies:createSynergiesApi(ready),overview:createOverviewApi(ready),files:createFilesApi(ready),comments:previewReceiver?undefined:createCommentsApi(ready),deliverables:createDeliverablesApi(ready),${tasks?'tasks:createTasksApi(ready),':''}${authoring?'deliverableCommands:createDeliverableCommands(ready),':''}readContext:async(_signal,selectedTerm)=>{if(selectedTerm&&!previewGuest)return(await ready.then(c=>c.rpc('read_search_term_context',{p_term_id:selectedTerm}))).data;if(previewGuest)return(await ready.then(c=>c.rpc('resolve_auth_context',{}))).data;if(${Number(contextDelay)||0})await new Promise(r=>setTimeout(r,${Number(contextDelay)||0}));return context},onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}};
      ReactDOMClient.createRoot(document.getElementById('root')).render(React.createElement(RouterProvider,{router:createBrowserRouter(createAppRoutes({state:'not_configured',issues:[]},gateway))}));
      </script></body></html>`
    if(adoptionPreview)html=html.replace(/<p style="margin:0;padding:12px 20px;background:#252624;color:white">[\s\S]*?<\/p>/,'<p style="margin:0;padding:12px 20px;background:#252624;color:white">Synthetic role preview: local SQL and isolated files. No real provider, institutional authority or human usability approval.</p>')
    const server=http.createServer(async(req,res)=>{
      res.setHeader('cache-control','no-store')
      // Injected Vite CSS uses root-relative font paths; keep the separate preview origin faithful.
      if(req.method==='GET'&&/\.(woff2?|ttf)(?:\?|$)/.test(req.url)){
        try{const font=await fetch(vite+req.url);res.writeHead(font.status,{'content-type':font.headers.get('content-type')||'font/woff2'});res.end(Buffer.from(await font.arrayBuffer()));return}
        catch{res.writeHead(502);res.end();return}
      }
      if(req.url==='/__files'&&req.method==='POST'){
        if(adoptionPreview&&req.headers['x-preview-subject']==='guest'){res.writeHead(403,{'content-type':'application/json'});res.end('{"error":"Guest bytes are not connected in this synthetic preview"}');return}
        try{const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>5308416)throw new Error('too_large');chunks.push(chunk)}
        const response=await filePreview.handler(new Request('http://127.0.0.1/__files',{method:'POST',headers:{'content-type':req.headers['content-type']||'','authorization':req.headers['x-preview-subject']==='associate'?'Bearer local-synthetic-associate':req.headers['x-preview-subject']==='receiver'?'Bearer local-synthetic-receiver':'Bearer local-synthetic'},body:Buffer.concat(chunks)}));res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));return
        }catch{res.writeHead(400,{'content-type':'application/json'});res.end('{"error":{"code":"22023"}}');return}
      }
      if(req.url==='/__rpc'&&req.method==='POST'){
        try{
          let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>100000)throw new Error('too_large')}
          const {name,args:a}=JSON.parse(raw)
          const result=await db.transaction(async tx=>{
            await tx.exec('set local role authenticated')
            await tx.query(`select set_config('request.jwt.claim.sub',$1,true)`,[adoptionPreview&&req.headers['x-preview-subject']==='guest'?'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2':(synergies||financeAuthorityPreview)&&req.headers['x-preview-subject']==='associate'?ids.outsider:(synergies||financeAuthorityPreview)&&req.headers['x-preview-subject']==='receiver'?ids.owner:ids.viewer])
            if(name==='list_review_inbox')return tx.query('select public.list_review_inbox($1,$2,$3) as value',[a.p_term_id,a.p_view,a.p_page])
            if(name==='triage_request')return tx.query('select public.triage_request($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_expected_revision,a.p_expected_version,a.p_action,a.p_note,a.p_accepted_on??null,a.p_request_id])
            if(name==='read_request_workflow')return tx.query('select public.read_request_workflow($1,$2) as value',[a.p_term_id,a.p_work_item_id])
            if(name==='activate_request_workflow')return tx.query('select public.activate_request_workflow($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_expected_revision,a.p_expected_stage,a.p_expected_version,a.p_reviewers??null,a.p_reason,a.p_request_id])
            if(name==='transition_request')return tx.query('select public.transition_request($1,$2,$3,$4,$5,$6,$7,$8,$9) as value',[a.p_work_item_id,a.p_assignment_id,a.p_expected_revision,a.p_expected_stage,a.p_expected_version,a.p_action,a.p_reason,a.p_evidence_manifest_id??null,a.p_request_id])
            if(name==='create_request_draft')return tx.query('select public.create_request_draft($1,$2,$3,$4,$5,$6) as value',[a.p_term_id,a.p_type_id,a.p_form_version_id,a.p_workflow_version_id,a.p_title,a.p_request_id])
            if(name==='save_request_draft')return tx.query('select public.save_request_draft($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_values,a.p_requested_centavos,a.p_requested_on,a.p_title,a.p_expected_version,a.p_request_id])
            if(name==='submit_request')return tx.query('select public.submit_request($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_values,a.p_requested_centavos,a.p_requested_on,a.p_title,a.p_expected_version,a.p_request_id])
            if(name==='revise_request')return tx.query('select public.revise_request($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_values,a.p_requested_centavos,a.p_requested_on,a.p_title,a.p_expected_version,a.p_request_id])
            if(name==='begin_request_revision')return tx.query('select public.begin_request_revision($1,$2,$3) as value',[a.p_work_item_id,a.p_expected_version,a.p_request_id])
            if(name==='cancel_request')return tx.query('select public.cancel_request($1,$2,$3,$4) as value',[a.p_work_item_id,a.p_expected_version,a.p_reason,a.p_request_id])
            if(name==='read_own_profile')return tx.query('select public.read_own_profile($1)as value',[a.p_term_id])
            if(name==='save_private_profile')return tx.query('select public.save_private_profile($1,$2,$3,$4)as value',[a.p_term_id,a.p_values,a.p_expected_version,a.p_request_id])
            if(name==='set_profile_visibility')return tx.query('select public.set_profile_visibility($1,$2,$3,$4)as value',[a.p_term_id,a.p_visibility,a.p_expected_version,a.p_request_id])
            if(name==='preview_access_change')return tx.query('select public.preview_access_change($1,$2,$3)as value',[a.p_term_id,a.p_action,a.p_values])
            if(name==='publish_access_change')return tx.query('select public.publish_access_change($1,$2,$3,$4,$5,$6,$7)as value',[a.p_term_id,a.p_action,a.p_values,a.p_expected_version,a.p_fingerprint,a.p_reason,a.p_request_id])
            if(name==='read_access_admin')return tx.query('select public.read_access_admin($1)as value',[a.p_term_id])
            if(name==='read_configurations')return tx.query('select public.read_configurations($1)as value',[a.p_term_id])
            if(name==='read_configuration_history')return tx.query('select public.read_configuration_history($1,$2)as value',[a.p_type_id,a.p_before])
            if(name==='preview_workflow_cases')return tx.query('select public.preview_workflow_cases($1,$2,$3,$4)as value',[a.p_draft_id,a.p_requester_id,a.p_values,a.p_has_evidence])
            if(name==='read_process_admin')return tx.query('select public.read_process_admin($1)as value',[a.p_term_id])
            if(name==='read_process_summary')return tx.query('select public.read_process_summary($1)as value',[a.p_term_id])
            if(name==='preview_process_change')return tx.query('select public.preview_process_change($1,$2,$3)as value',[a.p_term_id,a.p_kind,a.p_values])
            if(name==='publish_process_change')return tx.query('select public.publish_process_change($1,$2,$3,$4,$5,$6,$7)as value',[a.p_term_id,a.p_kind,a.p_values,a.p_expected_version,a.p_fingerprint,a.p_reason,a.p_request_id])
            if(name==='read_configuration')return tx.query('select public.read_configuration($1)as value',[a.p_type_id])
            if(name==='save_configuration_draft')return tx.query('select public.save_configuration_draft($1,$2,$3,$4,$5,$6,$7,$8)as value',[a.p_type_id,a.p_kind,a.p_definition,a.p_base_form_version_id,a.p_base_workflow_version_id,a.p_expected_version,a.p_request_id,a.p_rollback_version_id])
            if(name==='preview_configuration')return tx.query('select public.preview_configuration($1,$2)as value',[a.p_draft_id,a.p_requester_id??null])
            if(name==='publish_configuration')return tx.query('select public.publish_configuration($1,$2,$3,$4,$5,$6)as value',[a.p_draft_id,a.p_expected_version,a.p_review_hash,a.p_reason,a.p_request_id,a.p_requester_id??null])
            if(name==='preflight_access_change')return tx.query('select public.preflight_access_change($1,$2)as value',[a.p_term_id,a.p_values])
            if(name==='preview_synthetic_access')return tx.query('select public.preview_synthetic_access($1,$2)as value',[a.p_term_id,a.p_values])
            if(name==='explain_my_access')return tx.query('select public.explain_my_access($1,$2)as value',[a.p_term_id,a.p_work_id??null])
            if(name==='read_organization')return tx.query('select public.read_organization($1)as value',[a.p_term_id])
            if(name==='preview_organization_change')return tx.query('select public.preview_organization_change($1,$2,$3)as value',[a.p_term_id,a.p_action,a.p_values])
            if(name==='publish_organization_change')return tx.query('select public.publish_organization_change($1,$2,$3,$4,$5,$6,$7)as value',[a.p_term_id,a.p_action,a.p_values,a.p_expected_version,a.p_fingerprint,a.p_reason,a.p_request_id])
            if(name==='read_resources')return tx.query('select public.read_resources($1,$2)as value',[a.p_term_id,a.p_alias??null])
            if(name==='save_resource')return tx.query('select public.save_resource($1,$2,$3,$4,$5)as value',[a.p_term_id,a.p_id??null,a.p_values,a.p_expected_version,a.p_request_id])
            if(name==='set_onboarding_progress')return tx.query('select public.set_onboarding_progress($1,$2,$3,$4,$5,$6)as value',[a.p_term_id,a.p_item,a.p_revision,a.p_state,a.p_expected_version,a.p_request_id])
            if(name==='read_people_directory'||name==='read_process_contacts')return tx.query('select public.'+name+'($1)as value',[a.p_term_id])
            if(name==='read_calendar')return tx.query('select public.read_calendar($1,$2,$3,$4,$5)as value',[a.p_term_id,a.p_from,a.p_to,a.p_unit_id??null,a.p_page])
            if(name==='read_calendar_event')return tx.query('select public.read_calendar_event($1,$2)as value',[a.p_term_id,a.p_key])
            if(name==='save_calendar_event')return tx.query('select public.save_calendar_event($1,$2,$3,$4,$5)as value',[a.p_term_id,a.p_work_item_id??null,a.p_values,a.p_expected_version,a.p_request_id])
            if(name==='read_notifications')return tx.query('select public.read_notifications($1,$2) as value',[a.p_term_id,a.p_page])
            if(name==='set_notification_read')return tx.query('select public.set_notification_read($1,$2,$3,$4)as value',[a.p_notification_id,a.p_read,a.p_expected_version,a.p_request_id])
            if(name==='set_notification_preference')return tx.query('select public.set_notification_preference($1,$2,$3,$4)as value',[a.p_term_id,a.p_mode,a.p_expected_version,a.p_request_id])
            if(name==='read_notification_failures')return tx.query('select public.read_notification_failures($1)as value',[a.p_term_id])
            if(name==='retry_notification_job')return tx.query('select public.retry_notification_job($1,$2,$3,$4,$5)as value',[a.p_term_id,a.p_job_id,a.p_expected_version,a.p_reason,a.p_request_id])
            if(name==='read_deliverable_readiness')return tx.query('select public.read_deliverable_readiness($1) as value',[a.p_work_item_id])
            if(name==='submit_deliverable'||name==='accept_deliverable'||name==='reopen_deliverable')return tx.query('select public.'+name+'($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_evidence,a.p_reason,a.p_expected_version,a.p_criteria_revision,a.p_fingerprint,a.p_request_id])
            if(name==='declare_deliverable_work_types')return tx.query('select public.declare_deliverable_work_types($1,$2,$3,$4,$5) as value',[a.p_work_item_id,a.p_types,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='record_deliverable_scope_exception')return tx.query('select public.record_deliverable_scope_exception($1,$2,$3,$4,$5,$6) as value',[a.p_work_item_id,a.p_task_id,a.p_task_version,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='verify_deliverable_external')return tx.query('select public.verify_deliverable_external($1,$2,$3,$4,$5,$6,$7) as value',[a.p_work_item_id,a.p_manifest_id,a.p_official_reference,a.p_expires_at,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='read_publicity_request')return tx.query('select public.read_publicity_request($1,$2,$3) as value',[a.p_term_id,a.p_work_item_id,a.p_revision??null])
            if(name==='publicity_options')return tx.query('select public.publicity_options($1) as value',[a.p_term_id])
            if(name==='read_publicity_gate')return tx.query('select public.read_publicity_gate($1,$2) as value',[a.p_term_id,a.p_work_item_id])
            if(name==='submit_publicity_request')return tx.query('select public.submit_publicity_request($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_work_item_id,a.p_values,a.p_requested_on,a.p_title,a.p_payload,a.p_expected_version,a.p_request_id,a.p_revision])
            if(name==='activate_publicity_review')return tx.query('select public.activate_publicity_review($1,$2,$3,$4,$5,$6) as value',[a.p_work_item_id,a.p_reviewer_id,a.p_expected_revision,a.p_expected_version,a.p_reason,a.p_request_id])
            if(name==='decide_publicity_request')return tx.query('select public.decide_publicity_request($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_work_item_id,a.p_expected_revision,a.p_expected_version,a.p_action,a.p_reason,a.p_conditions,a.p_expires_at,a.p_request_id])
            if(name==='revoke_publicity_approval')return tx.query('select public.revoke_publicity_approval($1,$2,$3,$4) as value',[a.p_approval_id,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='read_finance_ledger')return tx.query('select public.read_finance_ledger($1,$2) as value',[a.p_term_id,a.p_work_item_id])
            if(name==='record_finance_actual')return tx.query('select public.record_finance_actual($1,$2,$3,$4,$5,$6,$7,$8,$9) as value',[a.p_work_item_id,a.p_kind,a.p_amount_centavos,a.p_evidence_asset_id,a.p_reference,a.p_recorded_on,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='reconcile_finance_actual')return tx.query('select public.reconcile_finance_actual($1,$2,$3,$4,$5) as value',[a.p_record_id,a.p_action,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='release_finance_budget')return tx.query('select public.release_finance_budget($1,$2,$3,$4) as value',[a.p_authorization_id,a.p_reason,a.p_expected_version,a.p_request_id])
            if(name==='read_finance_review')return tx.query('select public.read_finance_review($1,$2) as value',[a.p_term_id,a.p_work_item_id])
            if(name==='list_finance_reviews')return tx.query('select public.list_finance_reviews($1) as value',[a.p_term_id])
            if(name==='activate_finance_review')return tx.query('select public.activate_finance_review($1,$2,$3,$4,$5,$6) as value',[a.p_work_item_id,a.p_reviewer_id,a.p_expected_revision,a.p_expected_version,a.p_reason,a.p_request_id])
            if(name==='decide_finance_request')return tx.query('select public.decide_finance_request($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) as value',[a.p_work_item_id,a.p_expected_revision,a.p_expected_version,a.p_action,a.p_reason,a.p_ceiling_centavos,a.p_conditions,a.p_expires_at,a.p_external_outcome,a.p_external_manifest_id,a.p_request_id])
            if(name==='change_financial_authorization')return tx.query('select public.change_financial_authorization($1,$2,$3,$4,$5,$6) as value',[a.p_authorization_id,a.p_kind,a.p_reason,a.p_manifest_id,a.p_expected_version,a.p_request_id])
            if(name==='update_finance_metadata')return tx.query('select public.update_finance_metadata($1,$2,$3,$4) as value',[a.p_work_item_id,a.p_contact_label,a.p_expected_version,a.p_request_id])
            if(name==='read_finance_intake')return tx.query('select public.read_finance_intake($1,$2,$3) as value',[a.p_term_id,a.p_work_item_id,a.p_revision??null])
            if(name==='list_finance_cases')return tx.query('select public.list_finance_cases($1,$2) as value',[a.p_term_id,a.p_page??1])
            if(name==='read_finance_gate')return tx.query('select public.read_finance_gate($1,$2) as value',[a.p_term_id,a.p_work_item_id])
            if(name==='submit_finance_request')return tx.query('select public.submit_finance_request($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_work_item_id,a.p_values,a.p_requested_on,a.p_title,a.p_finance_payload,a.p_expected_version,a.p_request_id,a.p_revision??false])
            if(name==='read_request')return tx.query('select public.read_request($1,$2,$3,$4) as value',[a.p_term_id,a.p_work_item_id,a.p_revision??null,a.p_history_page??1])
            if(name==='list_my_requests')return tx.query('select public.list_my_requests($1,$2) as value',[a.p_term_id,a.p_page??1])
            if(name==='request_form_options')return tx.query('select public.request_form_options($1,$2,$3) as value',[a.p_term_id,a.p_type_id,a.p_work_item_id??null])
            if(name==='validate_request_form')return tx.query('select public.validate_request_form($1,$2,$3,$4,$5,$6) as value',[a.p_term_id,a.p_type_id,a.p_form_version_id,a.p_values,a.p_requested_centavos??null,a.p_work_item_id??null])
            if(name==='read_request_catalog')return tx.query('select public.read_request_catalog($1,$2) as value',[a.p_term_id,a.p_type_id??null])
            if(name==='read_committee_timeline')return tx.query('select public.read_committee_timeline($1,$2,$3,$4) as value',[a.p_term_id,a.p_filters??{},a.p_page??1,a.p_page_size??50])
            if(name==='read_work_schedule')return tx.query('select public.read_work_schedule($1) as value',[a.p_work_item_id])
            if(name==='update_work_schedule')return tx.query('select public.update_work_schedule($1,$2,$3,$4) as value',[a.p_work_item_id,a.p_planned_start_on,a.p_expected_version,a.p_request_id])
            if(name==='list_deliverables')return tx.query('select public.list_deliverables($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as value',[a.p_term_id,a.p_phase,a.p_unit_id,a.p_owner_id,a.p_blocked,a.p_overdue,a.p_involves_my_unit,a.p_review_pending,a.p_page,a.p_page_size])
            if(name==='list_synergies')return tx.query('select public.list_synergies($1,$2,$3,$4) as value',[a.p_term_id,a.p_view,a.p_parent_id,a.p_page])
            if(name==='synergy_options')return tx.query('select public.synergy_options($1,$2) as value',[a.p_term_id,a.p_parent_id])
            if(name==='submit_handoff')return tx.query('select public.submit_handoff($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) as value',[a.p_source_task_id,a.p_receiver_member_id,a.p_receiver_unit_id,a.p_manifest_id,a.p_terms,a.p_next_task_id,a.p_expected_source_version,a.p_expected_next_version,a.p_request_id,a.p_handoff_id??null,a.p_expected_handoff_version??null])
            if(name==='list_handoffs')return tx.query('select public.list_handoffs($1,$2,$3,$4) as value',[a.p_term_id,a.p_view,a.p_work_item_id,a.p_page])
            if(name==='handoff_submission_options')return tx.query('select public.handoff_submission_options($1,$2) as value',[a.p_source_task_id,a.p_handoff_id??null])
            if(name==='read_handoff')return tx.query('select public.read_handoff($1) as value',[a.p_handoff_id])
            if(name==='respond_to_handoff')return tx.query('select public.respond_to_handoff($1,$2,$3,$4,$5,$6) as value',[a.p_handoff_id,a.p_action,a.p_expected_version,a.p_expected_revision,a.p_reason,a.p_request_id])
            if(name==='accept_handoff')return tx.query('select public.accept_handoff($1,$2,$3,$4,$5) as value',[a.p_handoff_id,a.p_expected_version,a.p_expected_revision,a.p_notes,a.p_request_id])
            if(name==='read_task_dependencies')return tx.query('select public.read_task_dependencies($1,$2) as value',[a.p_successor_id,a.p_search??''])
            if(name==='add_task_dependency')return tx.query('select public.add_task_dependency($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_predecessor_id,a.p_successor_id,a.p_type,a.p_required,a.p_expected_predecessor_version,a.p_expected_successor_version,a.p_reason,a.p_request_id])
            if(name==='remove_task_dependency')return tx.query('select public.remove_task_dependency($1,$2,$3,$4,$5,$6) as value',[a.p_dependency_id,a.p_expected_predecessor_version,a.p_expected_successor_version,a.p_reason,a.p_scope_exception,a.p_request_id])
            if(name==='read_synergy')return tx.query('select public.read_synergy($1) as value',[a.p_agreement_id])
            if(name==='read_contribution')return tx.query('select public.read_contribution($1) as value',[a.p_work_item_id])
            if(name==='propose_synergy')return tx.query('select public.propose_synergy($1,$2,$3,$4,$5,$6,$7) as value',[a.p_parent_id,a.p_receiver_unit_id,a.p_terms,a.p_expected_parent_version,a.p_request_id,a.p_agreement_id??null,a.p_expected_agreement_version??null])
            if(name==='respond_to_synergy')return tx.query('select public.respond_to_synergy($1,$2,$3,$4,$5,$6,$7,$8) as value',[a.p_agreement_id,a.p_action,a.p_expected_version,a.p_expected_revision,a.p_owner_id,a.p_terms,a.p_reason,a.p_request_id])
            if(name==='resolve_auth_context')return tx.query('select public.resolve_auth_context()as value')
            if(name==='read_guest_contacts')return tx.query('select public.read_guest_contacts($1)as value',[a.p_term_id])
            if(name==='resolve_work_reference')return tx.query('select public.resolve_work_reference($1,$2,$3) as value',[a.p_term_id,a.p_kind,a.p_reference])
            if(name==='read_overview')return tx.query('select public.read_overview($1) as value',[a.p_term_id])
            if(name==='search_workspace')return tx.query('select public.search_workspace($1,$2,$3,$4)as value',[a.p_term_id,a.p_query,a.p_filters,a.p_cursor??null])
            if(name==='read_search_terms')return tx.query('select public.read_search_terms($1)as value',[a.p_term_id])
            if(name==='read_search_term_context')return tx.query('select public.read_search_term_context($1)as value',[a.p_term_id])
            if(name==='read_my_layout_configuration')return tx.query('select public.read_my_layout_configuration($1)as value',[a.p_term_id])
            if(name==='read_layout_targets')return tx.query('select public.read_layout_targets($1)as value',[a.p_term_id])
            if(name==='read_presentation_configuration')return tx.query('select public.read_presentation_configuration($1,$2,$3,$4,$5)as value',[a.p_term_id,a.p_kind,a.p_target_kind,a.p_target_id,a.p_before??null])
            if(name==='save_presentation_draft')return tx.query('select public.save_presentation_draft($1,$2,$3,$4,$5,$6,$7,$8,$9)as value',[a.p_term_id,a.p_kind,a.p_target_kind,a.p_target_id,a.p_definition,a.p_base_version,a.p_expected_version,a.p_request_id,a.p_rollback_version_id??null])
            if(name==='preview_presentation_configuration')return tx.query('select public.preview_presentation_configuration($1)as value',[a.p_draft_id])
            if(name==='publish_presentation_configuration')return tx.query('select public.publish_presentation_configuration($1,$2,$3,$4,$5)as value',[a.p_draft_id,a.p_expected_version,a.p_review_hash,a.p_reason,a.p_request_id])
            if(name==='save_operational_view')return tx.query('select public.save_operational_view($1,$2,$3,$4,$5,$6,$7)as value',[a.p_term_id,a.p_view_id,a.p_name,a.p_definition,a.p_archived,a.p_expected_version,a.p_request_id])
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
        }catch(error){res.setHeader('content-type','application/json');res.end(JSON.stringify({data:null,error:{code:(authoring||tasks)&&(/^[245][0-9A-Z]{4}$/.test(error.code??'')||/^command_/.test(error.message))?error.code:'COMMAND_UNAVAILABLE',message:(authoring||tasks)&&/^command_/.test(error.message)?error.message:'preview_query_failed'}}));return}
      }
      if(req.method!=='GET'){res.writeHead(405);res.end();return}
      res.setHeader('content-type','text/html; charset=utf-8');res.end(html)
    })
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve)})
    return{db,ids,synergyFixture,filePreview,url:`http://127.0.0.1:${port}`,close:async()=>{await new Promise(resolve=>server.close(resolve));await db.close()}}
  }catch(error){await db.close();throw error}
}
module.exports={createPreview}
if(require.main===module)createPreview().then(p=>{console.log(`P08 LIVE synthetic PostgreSQL preview: ${p.url}/deliverables`)}).catch(e=>{console.error(e.message);process.exitCode=1})
