import { expect, it } from 'vitest'
import { callbackUrl, readCallback, safeReturnPath } from './redirects'

it('P04_A3: return paths and OAuth origins require exact permitted values', () => {
  for (const value of ['https://evil.test','//evil.test','/\\evil.test','/%2f%2fevil.test','/auth/callback','/login','/preview','/tasks\n']) expect(safeReturnPath(value)).toBe('/')
  expect(safeReturnPath('/tasks?token=do-not-forward#secret')).toBe('/tasks')
  expect(callbackUrl('http://127.0.0.1:5173')).toBe('http://127.0.0.1:5173/auth/callback')
  expect(callbackUrl('http://127.0.0.1:5173.evil.test')).toBeNull()
  expect(callbackUrl('https://unapproved.example')).toBeNull()
  expect(readCallback('?code=one&code=two')).toBeNull()
  expect(readCallback('?error=denied&code=one')).toBeNull()
  expect(readCallback('?code=valid-code')).toBe('valid-code')
})
