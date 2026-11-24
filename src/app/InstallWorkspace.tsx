import { useEffect, useState } from 'react'

type InstallPrompt = Event & {
  prompt(): Promise<{ outcome: 'accepted' | 'dismissed' }>
}

// The install event can arrive before a user opens Account.
let availablePrompt: InstallPrompt | null = null
if (import.meta.env.PROD) {
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault()
    availablePrompt = event as InstallPrompt
    window.dispatchEvent(new Event('workspace-install-changed'))
  })
  window.addEventListener('appinstalled', () => {
    availablePrompt = null
    window.dispatchEvent(new Event('workspace-install-changed'))
  })
}

export function InstallWorkspace() {
  const [prompt, setPrompt] = useState(availablePrompt)
  const [status, setStatus] = useState('')
  useEffect(() => {
    const update = () => setPrompt(availablePrompt)
    window.addEventListener('workspace-install-changed', update)
    return () => window.removeEventListener('workspace-install-changed', update)
  }, [])

  async function install() {
    if (!prompt || availablePrompt !== prompt) return
    availablePrompt = null
    setPrompt(null)
    try {
      const { outcome } = await prompt.prompt()
      setStatus(outcome === 'accepted' ? 'Workspace installation accepted.' : 'You can install again from your browser menu when available.')
    } catch {
      setStatus('Installation could not start. Check your browser menu for an install or home screen option.')
    }
  }

  if (!import.meta.env.PROD || window.matchMedia('(display-mode: standalone)').matches
    || (navigator as Navigator & { standalone?: boolean }).standalone) return null
  return <details className="panel">
    <summary>Install workspace</summary>
    <p>Install a shortcut for quick access. Work and approvals require an internet connection.</p>
    {prompt?<button className="button" onClick={()=>void install()}>Install workspace</button>:
      <p>Look for Install or Add to Home Screen in your browser menu. On iPhone or iPad, check Safari’s Share menu.</p>}
    <p role="status">{status}</p>
  </details>
}
