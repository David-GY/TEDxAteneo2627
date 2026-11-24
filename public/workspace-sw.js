/* global self, caches, fetch, Request, Response, URL */
const prefix = 'tedx-public-shell-'
const cacheName = prefix + '2'
const offlinePath = '/offline/'
const publicFiles = [offlinePath, '/manifest.webmanifest', '/workspace-192.png', '/workspace-512.png']

self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache => cache.addAll(publicFiles.map(path =>
    new Request(path, { cache: 'reload', credentials: 'omit', redirect: 'error' }),
  ))))
})

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys()
    await Promise.all(names.filter(name => name.startsWith(prefix) && name !== cacheName)
      .map(name => caches.delete(name)))
    await self.clients.claim()
  })())
})

self.addEventListener('fetch', event => {
  const request = event.request
  const url = new URL(request.url)
  if (request.method !== 'GET' || url.origin !== self.location.origin || request.headers.has('authorization')) return

  if (!url.search && publicFiles.includes(url.pathname)) {
    event.respondWith(caches.open(cacheName).then(async cache => (await cache.match(url.pathname)) || fetch(request)))
    return
  }

  const appNavigation = /^\/(?:$|(?:login|shared|account|announcements|privacy|privacy-notice|tasks|deliverables|working-together|requests|reviews|finance|publicity|resources|calendar|people|committee|department|reports|search|notifications|guests|admin|rooms|inventory|mentoring|prism|archive|handover)(?:\/[\w/-]*)?$)/
  if (request.mode === 'navigate' && appNavigation.test(url.pathname)) {
    event.respondWith(fetch(request, { cache: 'no-store' }).catch(async () =>
      (await (await caches.open(cacheName)).match(offlinePath)) || Response.error(),
    ))
  }
})
