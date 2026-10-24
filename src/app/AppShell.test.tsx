import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { expect, it } from 'vitest'
import { AppShell } from './AppShell'
import { TextField } from '../components/TextField'

it('P01_A1: More moves focus, Escape restores it, and navigation focuses the main landmark', async () => {
  const router = createMemoryRouter([{ element: <AppShell />, children: [
    { path: '/', element: <h1>Overview</h1> },
    { path: '/resources', element: <h1>Resources</h1> },
  ] }])
  render(<RouterProvider router={router} />)
  expect(screen.getByRole('link', { name: 'Skip to main content' }).getAttribute('href')).toBe('#main-content')
  const more = screen.getByRole('button', { name: 'More' })
  fireEvent.click(more)
  const close = screen.getByRole('button', { name: 'Close pages' })
  expect(document.activeElement).toBe(close)
  fireEvent.keyDown(close, { key: 'Escape' })
  expect(document.activeElement).toBe(more)
  expect(more.getAttribute('aria-expanded')).toBe('false')
  fireEvent.click(more)
  fireEvent.click(within(screen.getByRole('navigation', { name: 'Additional workspace navigation' })).getByRole('link', { name: 'Resources & Start Here' }))
  await waitFor(() => expect(screen.getByRole('heading', { name: 'Resources' })).toBeTruthy())
  expect(document.activeElement).toBe(screen.getByRole('main'))
  expect(more.getAttribute('aria-expanded')).toBe('false')
})

it('P01_A3: a pending route announces loading and clears it when the route resolves', async () => {
  let finish!: () => void
  const pending = new Promise<void>((resolve) => { finish = resolve })
  const router = createMemoryRouter([{ element: <AppShell />, children: [
    { path: '/', element: <h1>Overview</h1> },
    { path: '/tasks', loader: () => pending, element: <h1>Tasks loaded</h1> },
  ] }])
  render(<RouterProvider router={router} />)
  let navigation!: Promise<void>
  await act(async () => { navigation = router.navigate('/tasks') })
  expect(screen.getByRole('status').textContent).toContain('Opening workspace page')
  expect(screen.getByRole('main').getAttribute('aria-busy')).toBe('true')
  await act(async () => { finish(); await navigation })
  expect(screen.getByRole('heading', { name: 'Tasks loaded' })).toBeTruthy()
  expect(screen.queryByRole('status')).toBeNull()
})

it('P01_A2: long field names retain their label, hint and validation association', () => {
  const label = 'Responsible person for the cross-committee deliverable with an extended descriptive name'
  render(<TextField id="owner" label={label} hint="Use the assigned member" error="An owner is required" required />)
  const input = screen.getByRole('textbox', { name: `${label} (required)` })
  expect(input.getAttribute('aria-invalid')).toBe('true')
  const descriptions = input.getAttribute('aria-describedby')!.split(' ').map((id) => document.getElementById(id)?.textContent)
  expect(descriptions).toEqual(['Use the assigned member', 'An owner is required'])
})
