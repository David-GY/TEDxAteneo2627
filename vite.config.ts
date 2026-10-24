import react from '@vitejs/plugin-react'
import { loadEnv } from 'vite'
import { defineConfig } from 'vitest/config'
import { readClientEnvironment } from './src/lib/env.ts'

export default defineConfig(({ command, mode }) => {
  const values = loadEnv(mode, process.cwd(), 'VITE_')
  const input = {
    VITE_SUPABASE_URL: values.VITE_SUPABASE_URL,
    VITE_SUPABASE_PUBLISHABLE_KEY: values.VITE_SUPABASE_PUBLISHABLE_KEY,
  }
  const hasSettings = Boolean(input.VITE_SUPABASE_URL?.trim() || input.VITE_SUPABASE_PUBLISHABLE_KEY?.trim())
  // Client-side rejection is too late: VITE_ values can already be in the bundle.
  if (command === 'build' && hasSettings && readClientEnvironment(input).state !== 'configured') {
    throw new Error('Invalid public Supabase configuration. Use a valid origin and publishable key, or leave both settings blank.')
  }

  return {
    plugins: [react()],
    test: {
      environment: 'jsdom',
      setupFiles: ['./src/test/setup.ts'],
      include: ['src/**/*.test.{ts,tsx}'],
    },
  }
})
