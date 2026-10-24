import { expect, it } from 'vitest'
import { getMobilePrimaryNavigation, getVisibleNavigation, setupNavigation } from './navigation'

it('P01_A3: setup navigation exposes no privileged desk and filtering never supplies authorization', () => {
  expect(getVisibleNavigation(setupNavigation).some((item) => item.capability)).toBe(false)
  const items = getVisibleNavigation({ audience: 'core', capabilities: ['finance.review'] })
  expect(items.some((item) => item.id === 'finance')).toBe(true)
  expect(items.some((item) => item.id === 'admin')).toBe(false)
})

it('P01_A2: guests retain labeled shared navigation even with unrelated capabilities', () => {
  const context = { audience: 'guest' as const, capabilities: ['admin.configure' as const] }
  expect(getVisibleNavigation(context).map((item) => item.id)).toEqual(['shared', 'tasks', 'calendar', 'resources', 'notifications', 'account'])
  expect(getMobilePrimaryNavigation(context).map((item) => item.id)).toEqual(['shared', 'tasks', 'calendar', 'resources'])
})
