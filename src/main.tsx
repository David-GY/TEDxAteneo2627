import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { RouterProvider } from 'react-router'
import { createAppRouter } from './app/router'
import '@fontsource-variable/karla'
import './styles/tokens.css'
import './styles/global.css'

if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  // Registration is optional. Online access works even if the browser blocks installation.
  void navigator.serviceWorker.register('/workspace-sw.js', { updateViaCache: 'none' }).catch(() => {})
}

const root = document.getElementById('root')
if (!root) throw new Error('The application root is missing from index.html.')

createRoot(root).render(
  <StrictMode>
    <RouterProvider router={createAppRouter()} />
  </StrictMode>,
)
