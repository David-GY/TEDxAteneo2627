const assert=require('node:assert/strict')
const fs=require('node:fs')
const {chromium}=require(process.env.TEDX_PLAYWRIGHT_PATH||'C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')
;(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true})
  try{
    const page=await browser.newPage({viewport:{width:1280,height:1000}})
    const errors=[]
    page.on('pageerror',e=>errors.push(e.message))
    const main=await(await fetch('http://127.0.0.1:5173/src/main.tsx')).text()
    const suffix=main.match(/react-router[.]js(\?v=[^"]+)/)[1]
    const html=`<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><script type="module">
      import RefreshRuntime from '/@react-refresh';RefreshRuntime.injectIntoGlobalHook(window);window.$RefreshReg$=()=>{};window.$RefreshSig$=()=>type=>type;window.__vite_plugin_react_preamble_installed__=true;
      </script></head><body><p>Local P07 test fixture · simulated gateway · fictional exact-record contact</p><div id="root"></div><script type="module">
      import React from '/node_modules/.vite/deps/react.js${suffix}';
      import ReactDOMClient from '/node_modules/.vite/deps/react-dom_client.js${suffix}';
      import {createMemoryRouter,RouterProvider} from '/node_modules/.vite/deps/react-router.js${suffix}';
      import {createAppRoutes} from '/src/app/router.tsx';
      import '/src/styles/tokens.css';import '/src/styles/global.css';import '/node_modules/@fontsource-variable/karla/index.css';
      const context={state:'authorized',audience:'guest',guestAccessId:'fixture',displayName:'Fictional scoped guest',organizationId:'o',termId:'t',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:[]};
      let reads=0;
      const guestContacts={read:async()=>({own:{displayName:'Fictional guest',verifiedEmail:'fictional-guest@example.invalid',contactRoute:null,version:0},sharedContacts:reads++===0?[{id:'owner',name:'Fictional owner of the specifically shared work record',organizationContact:'fictional+work@student.ateneo.edu'}]:[],scopeMode:reads===1?'explicit_records':'awaiting_record_attachment'}),save:async()=>{throw new Error('Not exercised by this fixture')}};
      const gateway={guestContacts,readContext:async()=>context,onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}};
      ReactDOMClient.createRoot(document.getElementById('root')).render(React.createElement(RouterProvider,{router:createMemoryRouter(createAppRoutes({state:'not_configured',issues:[]},gateway),{initialEntries:['/account']})}));
      </script></body></html>`
    await page.route('**/__p07_fixture',route=>route.fulfill({contentType:'text/html',body:html}))
    await page.goto('http://127.0.0.1:5173/__p07_fixture')
    const contact=page.getByRole('link',{name:'Email Fictional owner of the specifically shared work record',exact:true})
    await contact.waitFor()
    assert.equal(await contact.getAttribute('href'),'mailto:fictional%2Bwork%40student.ateneo.edu')
    assert.equal(await page.getByRole('link',{name:'People',exact:true}).count(),0)
    assert.equal(await page.getByLabel('Course',{exact:true}).count(),0)
    await page.screenshot({path:'docs/build/evidence/P07-scoped-contact-fixture.png',fullPage:true})
    await page.setViewportSize({width:320,height:740})
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),320)
    await page.screenshot({path:'docs/build/evidence/P07-scoped-contact-mobile-fixture.png',fullPage:true})
    await page.getByRole('button',{name:'Reload contacts and discard unsaved edits',exact:true}).click()
    await page.getByText(/No other contacts are shared/).waitFor()
    assert.equal(await contact.count(),0)
    assert.equal(await page.evaluate(()=>localStorage.length+sessionStorage.length),0)
    assert.deepEqual(errors,[])
    fs.writeFileSync('docs/build/evidence/P07-browser.json',JSON.stringify({target:'test-only fictional simulated exact-record contact; not backend/JWT transport evidence',checks:['Explicit record-owner contact, safe encoded mail route, no core directory/profile controls','320px reflow; contact disappears after scope reload; no browser storage/runtime errors'],errors},null,2)+'\n')
    console.log('PASS P07 scoped-contact UI desktop/mobile, withdrawal and route encoding')
  }finally{await browser.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1})
