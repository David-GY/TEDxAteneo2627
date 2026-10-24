const assert=require('node:assert/strict')
const fs=require('node:fs')
const {chromium}=require(process.env.TEDX_PLAYWRIGHT_PATH||'C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')
;(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true})
  const evidence={target:'local production unconfigured redemption; development component fixture with explicitly simulated gateway',checks:[],errors:[]}
  try{
    const page=await browser.newPage({viewport:{width:1280,height:900}})
    page.on('pageerror',e=>{evidence.errors.push(e.message);console.error('Browser error:',e.message)})
    const token='b'.repeat(64)
    const requests=[]
    page.on('request',r=>requests.push(r.url()))
    await page.goto('http://127.0.0.1:4173/guest/redeem#'+token)
    await page.getByRole('heading',{name:'Accept your guest invitation'}).waitFor()
    assert.equal(new URL(page.url()).hash,'')
    assert(await page.getByRole('button',{name:'Accept invitation with signed-in account'}).isDisabled())
    assert.equal(await page.evaluate(()=>localStorage.length+sessionStorage.length),0)
    assert(!requests.some(url=>url.includes(token)))
    await page.screenshot({path:'docs/build/evidence/P05-redemption.png',fullPage:true})
    await page.setViewportSize({width:320,height:740})
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),320)
    await page.screenshot({path:'docs/build/evidence/P05-redemption-mobile.png',fullPage:true})
    evidence.checks.push('Production redemption strips fragment, sends no bearer in URL requests, persists none, disables unconfigured actions and reflows at 320px')
    // Test-only gateway: no fixture route, identities or fake success endpoints ship in the app.
    const main=await (await fetch('http://127.0.0.1:5173/src/main.tsx')).text()
    const suffix=main.match(/react-router[.]js(\?v=[^"]+)/)[1]
    const html=`<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><script type="module">
      import RefreshRuntime from '/@react-refresh';RefreshRuntime.injectIntoGlobalHook(window);window.$RefreshReg$=()=>{};window.$RefreshSig$=()=>type=>type;window.__vite_plugin_react_preamble_installed__=true;
      </script></head><body><p>Local test fixture · simulated gateway · fictional identity</p><div id="root"></div><script type="module">
      import React from '/node_modules/.vite/deps/react.js${suffix}';
      import ReactDOMClient from '/node_modules/.vite/deps/react-dom_client.js${suffix}';
      import {createMemoryRouter,RouterProvider} from '/node_modules/.vite/deps/react-router.js${suffix}';
      import {createAppRoutes} from '/src/app/router.tsx';
      import '/src/styles/tokens.css';import '/src/styles/global.css';import '@fontsource-variable/karla';
      let rows=[];let version=1;
      const guests={list:async()=>rows,create:async(term,email,id,expiry,replaces)=>{rows=[{id:'fixture-id',email,expiresAt:expiry,redeemedAt:null,revokedAt:null,version:version++,scopeMode:'awaiting_record_attachment'}];return{id:'fixture-id',token:'c'.repeat(64),reused:false}},revoke:async()=>{rows=rows.map(r=>({...r,revokedAt:new Date().toISOString(),version:r.version+1}))},redeem:async()=>{}};
      const context={state:'authorized',memberId:'m',displayName:'Fictional local sponsor',organizationId:'o',termId:'t',termMembershipId:'tm',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:['roles.manage']};
      const gateway={guests,readContext:async()=>context,onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}};
      ReactDOMClient.createRoot(document.getElementById('root')).render(React.createElement(RouterProvider,{router:createMemoryRouter(createAppRoutes({state:'not_configured',issues:[]},gateway),{initialEntries:['/guests']})}));
      </script></body></html>`
    await page.route('**/__p05_fixture',route=>route.fulfill({contentType:'text/html',body:html.replace("import '@fontsource-variable/karla';","import '/node_modules/@fontsource-variable/karla/index.css';")}))
    await page.goto('http://127.0.0.1:5173/__p05_fixture')
    await page.getByRole('heading',{name:'Guest invitations',exact:true}).waitFor()
    await page.getByLabel('Guest Google email (required)').fill('fictional-long-visitor-for-layout-check@example.invalid')
    await page.getByRole('button',{name:'Create invitation link',exact:true}).click()
    await page.getByLabel('Invitation link',{exact:true}).waitFor()
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),320)
    for(const button of await page.getByRole('button').all()){
      if(!await button.isVisible())continue
      const rect=await button.boundingBox();assert(rect.height>=44&&rect.width>=44)
    }
    await page.evaluate(()=>{document.activeElement?.blur();window.scrollTo(0,0)})
    await page.screenshot({path:'docs/build/evidence/P05-sponsor-mobile-fixture.png',fullPage:true})
    await page.setViewportSize({width:1280,height:1000})
    await page.screenshot({path:'docs/build/evidence/P05-sponsor-fixture.png',fullPage:true})
    await page.getByRole('button',{name:/Revoke access for/}).click()
    await page.getByText('Guest access revoked. Current sessions can no longer use this invitation.',{exact:true}).waitFor()
    evidence.checks.push('Simulated sponsor component: zero-record preview, create/link display/revoke flow; long email, 320px reflow and 44px controls')
    assert.deepEqual(evidence.errors,[])
    fs.writeFileSync('docs/build/evidence/P05-browser.json',JSON.stringify(evidence,null,2)+'\n')
    console.log(JSON.stringify(evidence,null,2))
  }finally{await browser.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1})
