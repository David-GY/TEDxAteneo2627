// Local browser regression evidence; fixtures are injected only into the test DOM.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const { chromium } = require(process.env.TEDX_PLAYWRIGHT_PATH || 'C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright')
const base = process.env.TEDX_PREVIEW_URL || 'http://127.0.0.1:5173'

;(async () => {
  const browser = await chromium.launch({ headless: true, channel: 'msedge' })
  const evidence = { base, checks: [], errors: [], externalRequests: [] }
  try {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } })
    const page = await context.newPage()
    page.on('pageerror', (error) => evidence.errors.push(error.message))
    page.on('request', (request) => { if (!request.url().startsWith(base)) evidence.externalRequests.push(request.url()) })
    await page.goto(base)
    await page.getByRole('heading', { name: 'Overview', exact: true }).waitFor()
    await page.evaluate(() => document.fonts.ready)
    assert(await page.evaluate(() => document.fonts.check('16px "Karla Variable"')))
    await page.keyboard.press('Tab')
    assert.equal(await page.locator(':focus').textContent(), 'Skip to main content')
    assert.equal(await page.locator(':focus').evaluate((element) => getComputedStyle(element).outlineWidth), '3px')
    await page.keyboard.press('Enter')
    assert.equal(await page.locator(':focus').getAttribute('id'), 'main-content')
    await page.locator('body').click({ position: { x: 1260, y: 20 } })
    await page.screenshot({ path: 'docs/build/evidence/P01-desktop.png', fullPage: true })

    for (const viewport of [{ width: 320, height: 740 }, { width: 640, height: 450 }]) {
      await page.setViewportSize(viewport)
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), viewport.width)
      const mobile = page.getByRole('navigation', { name: 'Mobile workspace navigation', exact: true })
      for (const control of await mobile.locator('a, button').all()) {
        const box = await control.boundingBox()
        assert(box.width >= 44 && box.height >= 44)
        assert((await control.textContent()).trim())
      }
      const more = mobile.getByRole('button', { name: 'More', exact: true })
      await more.focus()
      await page.keyboard.press('Enter')
      assert.equal(await page.locator(':focus').textContent(), 'Close pages')
      await page.keyboard.press('Escape')
      assert.equal(await page.locator(':focus').textContent(), 'More')
      await more.click()
      await page.getByRole('navigation', { name: 'Additional workspace navigation' }).getByRole('link', { name: 'Resources & Start Here' }).click()
      await page.getByRole('heading', { name: 'Resources & Start Here', exact: true }).waitFor()
      assert.equal(await page.locator(':focus').getAttribute('id'), 'main-content')
      await page.goto(base)
    }
    evidence.checks.push('P01_A1: 320px and 640px reflow; keyboard skip, visible 3px focus, More open/Escape/route focus')
    // Match a 1280x900 display at 200% browser zoom: 640x450 CSS pixels, DPR 2.
    const zoom = await browser.newContext({ viewport: { width: 640, height: 450 }, deviceScaleFactor: 2 })
    const zoomPage = await zoom.newPage()
    await zoomPage.goto(base)
    assert.equal(await zoomPage.evaluate(() => document.documentElement.scrollWidth), 640)
    await zoomPage.keyboard.press('Tab')
    await zoomPage.keyboard.press('Enter')
    assert.equal(await zoomPage.locator(':focus').getAttribute('id'), 'main-content')
    await zoomPage.screenshot({ path: 'docs/build/evidence/P01-zoom-200.png', fullPage: true })
    evidence.checks.push('P01_A1: 200% zoom metrics emulated (640 CSS px, DPR 2); native browser toolbar zoom not operated')
    await zoom.close()

    await page.setViewportSize({ width: 320, height: 740 })
    await page.screenshot({ path: 'docs/build/evidence/P01-mobile.png', fullPage: true })
    await page.evaluate(() => {
      const identity = document.createElement('div')
      identity.className = 'identity-details'
      const name = document.createElement('strong')
      name.textContent = 'Fictional local test person with an exceptionally long multi-part descriptive name'
      const unit = document.createElement('span')
      unit.textContent = 'Fictional committee for cross-committee contributions and extended descriptive unit labels'
      identity.append(name, unit)
      document.querySelector('.account-summary > span').replaceWith(identity)
    })
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth), 320)
    const account = page.locator('.account-summary').getByRole('link', { name: 'Account', exact: true })
    const box = await account.boundingBox()
    assert(box.width >= 44 && box.height >= 44)
    assert.equal(await page.locator('.identity-details').evaluate((element) => element.scrollWidth <= element.clientWidth), true)
    await page.screenshot({ path: 'docs/build/evidence/P01-long-labels.png', fullPage: true })
    evidence.checks.push('P01_A2: 44px mobile controls, Account name/target and wrapping with explicitly fictional DOM stress labels')

    for (const route of ['/', '/deliverables', '/working-together', '/finance', '/admin']) {
      await page.goto(base + route)
      assert.equal(await page.getByRole('heading', { level: 1 }).count(), 1)
      assert.equal(await page.getByRole('button').count(), 1) // Only the functional More button.
      if (route !== '/') assert(await page.getByText('This area is not connected yet', { exact: true }).isVisible())
    }
    await page.goto(base + '/missing')
    await page.getByRole('link', { name: 'Return to start' }).click()
    await page.getByRole('heading', { name: 'Overview', exact: true }).waitFor()
    assert.deepEqual(evidence.errors, [])
    assert.deepEqual(evidence.externalRequests, [])
    evidence.checks.push('P01_A3: production placeholders have no success actions or synthetic metrics; unknown route recovers; no runtime errors/external requests')
    fs.writeFileSync('docs/build/evidence/P01-browser.json', JSON.stringify(evidence, null, 2) + '\n')
    console.log(JSON.stringify(evidence, null, 2))
  } finally { await browser.close() }
})().catch((error) => { console.error(error); process.exitCode = 1 })
