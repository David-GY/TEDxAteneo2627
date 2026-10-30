const assert=require('node:assert/strict'),fs=require('node:fs/promises')
const{chromium}=require(process.env.TEDX_PLAYWRIGHT_PATH||'C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')
;(async()=>{const p=await require('./preview-p08.cjs').createPreview({port:5200,authoring:true,tasks:true,financeAuthorityPreview:true,notificationPreview:true});let browser;try{
 await require('./notification-preview-fixtures.cjs').seedNotificationPreview(p)
 browser=await chromium.launch({channel:'msedge',headless:true});const context=await browser.newContext({viewport:{width:320,height:850}}),page=await context.newPage(),calls=[]
 page.on('request',r=>{if(r.url().endsWith('/__rpc')){try{calls.push(r.postDataJSON().name)}catch{/* No payload recorded. */}}})
 await page.goto(p.url+'/notifications');await page.getByText('Try notification timing proposals',{exact:true}).click()
 await page.getByLabel('Proposed channel').selectOption('email');await page.getByLabel('Proposed reminder time · Manila').selectOption('21')
 const before=calls.length;await page.getByRole('button',{name:'Preview fictional timing (send nothing)',exact:true}).click()
 const preview=page.getByRole('region',{name:'Fictional timing preview'});assert(await preview.isVisible());assert((await preview.textContent()).includes('not connected'))
 assert(!calls.slice(before).some(n=>!['read_notifications','read_process_summary'].includes(n)),'Fictional preview must not mutate or look up recipients')
 assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth))
 await page.getByLabel('Proposed channel').focus();await page.keyboard.press('Tab');assert(await page.evaluate(()=>document.activeElement.labels[0].textContent.startsWith('Optional delivery mode')))
 await preview.scrollIntoViewIfNeeded();await page.screenshot({path:'docs/build/evidence/P41-proposals-mobile.png'})
 const member=await context.newPage();await member.goto(p.url+'/notifications?synthetic=receiver');await member.getByRole('heading',{name:'Your updates',exact:true}).waitFor();assert.equal(await member.getByText('Try notification timing proposals',{exact:true}).count(),0)
 await fs.writeFile('docs/build/evidence/P41-proposals-browser.json',JSON.stringify({result:'PASS',target:'Isolated PGlite and compiled UI, synthetic custodian/member; no real JWT/recipient/provider proof',checks:['320px reflow','keyboard channel-to-mode focus','external unavailable fallback','fictional preview performs no mutation/recipient lookup','ordinary member has no admin proposal controls'],limitations:['No server rule persistence','No actual recipient dry-run','No durable digest/reminder scheduling','No live cadence or external delivery']},null,2)+'\n');console.log('P41 no-send proposal browser PASS')
 }finally{if(browser)await browser.close();await p.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1})
