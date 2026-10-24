import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'
import { PeoplePage } from './pages'
import type { PeopleGateway } from './gateway'

const api: PeopleGateway = { read: async () => ({ people: [{ id: 'one', name: 'Fictional member', contact: null, units: ['Fictional delivery', 'Fictional support'], roles: [], course: null, year: null, phone: null, externalContact: null }], processes: [{ id: 'service', name: 'Fictional support', primary: [{ id: 'one', name: 'Fictional member' }], backup: [] }] }) }
describe('P06 directory', () => {
  it('P06_A2/A3: keeps help links with blank affiliation and one person across multiple units; searches and names missing backup', async () => {
    render(<MemoryRouter><PeoplePage api={api} termId="fictional" /></MemoryRouter>)
    await screen.findByText('1 person found')
    expect(screen.getAllByRole('heading', { name: 'Fictional member' })).toHaveLength(1)
    expect(screen.getByText(/Backup: Not assigned/)).toBeTruthy()
    expect(screen.getByRole('link', { name: 'My tasks' })).toBeTruthy()
    expect(screen.getByRole('link', { name: 'Resources & Start Here' })).toBeTruthy()
    fireEvent.change(screen.getByLabelText('Search people'), { target: { value: 'support' } })
    expect(screen.getByText('1 person found')).toBeTruthy()
    fireEvent.change(screen.getByLabelText('Search people'), { target: { value: 'missing' } })
    expect(screen.getByText('No people found')).toBeTruthy()
    expect(screen.getByText('Fictional support')).toBeTruthy()
  })
  it('recovers from a failed read without exposing raw server details', async () => {
    let failed = true
    const flaky: PeopleGateway = { read: async term => { if (failed) { failed = false; throw new Error('private payload') }; return api.read(term) } }
    render(<MemoryRouter><PeoplePage api={flaky} termId="fictional" /></MemoryRouter>)
    await screen.findByText('Directory unavailable')
    expect(screen.queryByText('private payload')).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }))
    await screen.findByText('1 person found')
  })
})
