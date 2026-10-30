const assert=require('node:assert/strict'),fs=require('node:fs/promises')
const{chromium}=require(process.env.TEDX_PLAYWRIGHT_PATH||'C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')
;(async()=>{const p=await require('./preview-p37.cjs').createWorkflowPreview(5200);let browser;try{
 browser=await chromium.launch({channel:'msedge',headless:true});const context=await browser.newContext({viewport:{width:320,height:850}}),page=await context.newPage()
 await page.goto(p.url+'/search?synthetic=associate');const input=page.getByLabel('Search titles or references');await input.fill('Prepare your first event checklist');await input.press('Enter')
 const result=page.getByRole('link',{name:'Prepare your first event checklist',exact:true});await result.waitFor();assert.equal(await result.getAttribute('href'),'/tasks/'+p.firstTask)
 const ref=(await p.db.query('select reference_text from public.work_references where work_item_id=$1',[p.firstTask])).rows[0].reference_text
 await input.fill(ref);await input.press('Enter');await result.waitFor();assert.equal(await result.getAttribute('href'),'/tasks/'+p.firstTask)
 assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await result.focus();assert.equal(await page.evaluate(()=>document.activeElement.tagName),'A')
 await page.screenshot({path:'docs/build/evidence/P43-search-mobile.png'})
 await page.getByRole('button',{name:'Clear search',exact:true}).click();assert.equal(await input.inputValue(),'');assert.equal(await result.count(),0)
 await input.fill('PRIVATE OUTPUT');await input.press('Enter');await page.getByText('No permitted matches. Try a title or reference in this term.',{exact:true}).waitFor()
 await fs.writeFile('docs/build/evidence/P43-search-browser.json',JSON.stringify({result:'PASS',target:'Compiled isolated PGlite/synthetic member, not provider or human acceptance',checks:['320px no overflow','Enter submit/title link focus','exact title/ref same UUID link','clear removes results/input','private query no permitted match'],remaining:['requests/guides/contacts/aliases','typeahead','native zoom/assistive/human/provider gates']},null,2)+'\n');console.log('P43 operational search browser PASS')
 }finally{if(browser)await browser.close();await p.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1})
