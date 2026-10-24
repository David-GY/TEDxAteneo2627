const http=require('node:http')
const {createDeliverablesDatabase}=require('./deliverables-db.cjs')
async function createPreview({port=5174}={}){
  const {db,ids}=await createDeliverablesDatabase()
  try{
    const main=await(await fetch('http://127.0.0.1:5173/src/main.tsx')).text()
    const suffix=main.match(/react-router[.]js(\?v=[^"]+)/)[1]
    const vite='http://127.0.0.1:5173'
    const html=`<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>P08 synthetic database preview</title><script type="module">
      import RefreshRuntime from '${vite}/@react-refresh';RefreshRuntime.injectIntoGlobalHook(window);window.$RefreshReg$=()=>{};window.$RefreshSig$=()=>type=>type;window.__vite_plugin_react_preamble_installed__=true;
      </script></head><body><p style="margin:0;padding:12px 20px;background:#252624;color:white">Local synthetic PostgreSQL preview · simulated sign-in · no real records or provider connection</p><div id="root"></div><script type="module">
      import React from '${vite}/node_modules/.vite/deps/react.js${suffix}';
      import ReactDOMClient from '${vite}/node_modules/.vite/deps/react-dom_client.js${suffix}';
      import {createBrowserRouter,RouterProvider} from '${vite}/node_modules/.vite/deps/react-router.js${suffix}';
      import {createAppRoutes} from '${vite}/src/app/router.tsx';
      import {createDeliverablesApi} from '${vite}/src/features/deliverables/api.ts';
      import '${vite}/src/styles/tokens.css';import '${vite}/src/styles/global.css';import '${vite}/node_modules/@fontsource-variable/karla/index.css';
      const ready=Promise.resolve({rpc:(name,args)=>fetch('/__rpc',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({name,args})}).then(r=>r.json())});
      const context={state:'authorized',memberId:'${ids.viewer}',displayName:'Fictional River · local preview',organizationId:'${ids.org}',termId:'${ids.term}',termMembershipId:'${ids.viewerMembership}',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:['workspace.read']};
      const gateway={deliverables:createDeliverablesApi(ready),readContext:async()=>context,onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}};
      ReactDOMClient.createRoot(document.getElementById('root')).render(React.createElement(RouterProvider,{router:createBrowserRouter(createAppRoutes({state:'not_configured',issues:[]},gateway))}));
      </script></body></html>`
    const server=http.createServer(async(req,res)=>{
      res.setHeader('cache-control','no-store')
      // Injected Vite CSS uses root-relative font paths; keep the separate preview origin faithful.
      if(req.method==='GET'&&/\.(woff2?|ttf)(?:\?|$)/.test(req.url)){
        try{const font=await fetch(vite+req.url);res.writeHead(font.status,{'content-type':font.headers.get('content-type')||'font/woff2'});res.end(Buffer.from(await font.arrayBuffer()));return}
        catch{res.writeHead(502);res.end();return}
      }
      if(req.url==='/__rpc'&&req.method==='POST'){
        try{
          let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>10000)throw new Error('too_large')}
          const {name,args:a}=JSON.parse(raw)
          const result=await db.transaction(async tx=>{
            await tx.exec('set local role authenticated')
            await tx.query(`select set_config('request.jwt.claim.sub',$1,true)`,[ids.viewer])
            if(name==='list_deliverables')return tx.query('select public.list_deliverables($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as value',[a.p_term_id,a.p_phase,a.p_unit_id,a.p_owner_id,a.p_blocked,a.p_overdue,a.p_involves_my_unit,a.p_review_pending,a.p_page,a.p_page_size])
            if(name==='read_deliverable')return tx.query('select public.read_deliverable($1) as value',[a.p_work_item_id])
            throw new Error('unsupported_rpc')
          })
          res.setHeader('content-type','application/json');res.end(JSON.stringify({data:result.rows[0].value,error:null}));return
        }catch{res.setHeader('content-type','application/json');res.end(JSON.stringify({data:null,error:{message:'preview_query_failed'}}));return}
      }
      if(req.method!=='GET'){res.writeHead(405);res.end();return}
      res.setHeader('content-type','text/html; charset=utf-8');res.end(html)
    })
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve)})
    return{db,ids,url:`http://127.0.0.1:${port}`,close:async()=>{await new Promise(resolve=>server.close(resolve));await db.close()}}
  }catch(error){await db.close();throw error}
}
module.exports={createPreview}
if(require.main===module)createPreview().then(p=>{console.log(`P08 LIVE synthetic PostgreSQL preview: ${p.url}/deliverables`)}).catch(e=>{console.error(e.message);process.exitCode=1})
