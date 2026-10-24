import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { RouterProvider } from 'react-router'
import { createAppRouter } from './app/router'
import '@fontsource-variable/karla'
import './styles/tokens.css'
import './styles/global.css'

const root = document.getElementById('root')
if (!root) throw new Error('The application root is missing from index.html.')

createRoot(root).render(
  <StrictMode>
    <RouterProvider router={createAppRouter()} />
  </StrictMode>,
)
