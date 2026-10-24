const assert = require('node:assert/strict')
const fs = require('node:fs')
const { chromium } = require(process.env.TEDX_PLAYWRIGHT_PATH || 'C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')
;(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true })
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 1000 } })
    const errors = []
    page.on('pageerror', error => errors.push(error.message))
    const main = await (await fetch('http://127.0.0.1:5173/src/main.tsx')).text()
    const suffix = main.match(/react-router[.]js(\?v=[^"]+)/)[1]
    const html = `<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><script type="module">
      import RefreshRuntime from '/@react-refresh';RefreshRuntime.injectIntoGlobalHook(window);window.$RefreshReg$=()=>{};window.$RefreshSig$=()=>type=>type;window.__vite_plugin_react_preamble_installed__=true;
      </script></head><body><p>Local test fixture · simulated gateway · fictional people</p><div id="root"></div><script type="module">
      import React from '/node_modules/.vite/deps/react.js${suffix}';
      import ReactDOMClient from '/node_modules/.vite/deps/react-dom_client.js${suffix}';
      import {createMemoryRouter,RouterProvider} from '/node_modules/.vite/deps/react-router.js${suffix}';
      import {createAppRoutes} from '/src/app/router.tsx';
      import '/src/styles/tokens.css';import '/src/styles/global.css';import '/node_modules/@fontsource-variable/karla/index.css';
      const people={read:async()=>({people:[{id:'m',name:'Fictional member with a deliberately long name',contact:'fictional@student.ateneo.edu',units:['Fictional event production and logistics','Fictional speaker support'],roles:['Fictional reader'],course:null,year:null,phone:null,externalContact:null}],processes:[{id:'u',name:'Fictional event production and logistics',primary:[{id:'m',name:'Fictional member with a deliberately long name'}],backup:[]}]})};
      const context={state:'authorized',memberId:'m',displayName:'Fictional local reader',organizationId:'o',termId:'t',termMembershipId:'tm',expiresAt:new Date(Date.now()+3600000).toISOString(),capabilities:['directory.read']};
      let profileRow={memberId:'m',displayName:'Fictional local reader',version:0,course:null,yearLevel:null,phone:null,externalContact:null,shareCourse:false,shareYearLevel:false,sharePhone:false,shareExternalContact:false};
      const profile={read:async()=>profileRow,save:async(t,values)=>{profileRow={...profileRow,...values,version:profileRow.version+1};return profileRow},share:async(t,values)=>{profileRow={...profileRow,...values,version:profileRow.version+1};return profileRow}};
      const gateway={people,profile,readContext:async()=>context,onChange:()=>()=>{},exchange:async()=>{},signOut:async()=>{},beginGoogle:async()=>{}};
      ReactDOMClient.createRoot(document.getElementById('root')).render(React.createElement(RouterProvider,{router:createMemoryRouter(createAppRoutes({state:'not_configured',issues:[]},gateway),{initialEntries:['/people']})}));
      </script></body></html>`
    await page.route('**/__p06_fixture', route => route.fulfill({ contentType: 'text/html', body: html }))
    await page.goto('http://127.0.0.1:5173/__p06_fixture')
    await page.getByText('1 person found').waitFor()
    assert.equal(await page.getByRole('heading', { name: 'Fictional member with a deliberately long name', exact: true }).count(), 1)
    assert(await page.getByText(/Backup: Not assigned/).isVisible())
    await page.screenshot({ path: 'docs/build/evidence/P06-people-fixture.png', fullPage: true })
    await page.setViewportSize({ width: 320, height: 740 })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), 320)
    await page.screenshot({ path: 'docs/build/evidence/P06-people-mobile-fixture.png', fullPage: true })
    const search = page.getByRole('searchbox', { name: 'Search people' })
    await search.fill('speaker')
    await page.getByText('1 person found').waitFor()
    await search.fill('absent')
    await page.getByText('No people found', { exact: true }).waitFor()
    assert(await page.getByText(/Backup: Not assigned/).isVisible())
    assert(await page.getByRole('main').getByRole('link', { name: 'My tasks', exact: true }).isVisible())
    await page.locator('header').getByRole('link', { name: 'Account', exact: true }).click()
    await page.getByLabel('Course', { exact: true }).waitFor()
    await page.getByLabel('Course', { exact: true }).fill('Fictional private course')
    await page.getByRole('button', { name: 'Save private details', exact: true }).click()
    await page.getByText('Private details saved. Your sharing choices were kept.', { exact: true }).waitFor()
    assert(!await page.getByLabel('Share course', { exact: true }).isChecked())
    await page.getByLabel('Share course', { exact: true }).check()
    await page.getByRole('button', { name: 'Save sharing choices', exact: true }).click()
    await page.getByText('Sharing choices saved. Unchecked details are hidden from the directory.', { exact: true }).waitFor()
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), 320)
    assert.equal(await page.evaluate(() => localStorage.length + sessionStorage.length), 0)
    await page.evaluate(() => { document.activeElement?.blur(); window.scrollTo(0,0) })
    await page.screenshot({ path: 'docs/build/evidence/P06-profile-mobile-fixture.png', fullPage: true })
    await page.setViewportSize({ width:1280,height:1000 })
    await page.screenshot({ path: 'docs/build/evidence/P06-profile-fixture.png', fullPage: true })
    assert.deepEqual(errors, [])
    fs.writeFileSync('docs/build/evidence/P06-browser.json', JSON.stringify({ target: 'test-only simulated gateway; fictional data, no fixture endpoint ships', checks: ['P06_A3: one person across two units, missing backup, 320px reflow', 'Name/unit/role search and empty result; help persists independently', 'Profile editor separate saves, opt-in checkbox, 320px and desktop; no private browser storage', 'No browser runtime errors'], errors }, null, 2) + '\n')
    console.log('PASS P06 desktop/mobile directory fixture and search')
  } finally { await browser.close() }
})().catch(error => { console.error(error.message); process.exitCode = 1 })
