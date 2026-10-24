import type { createSupabaseClient } from '../../lib/supabase'

export type Person = { id: string; name: string; contact: string | null; units: string[]; roles: string[]; course: string | null; year: string | null; phone: string | null; externalContact: string | null; skills: string | null; pronunciation: string | null; affiliation: string | null }
export type ProcessContact = { id: string; name: string; primary: { id: string; name: string }[]; backup: { id: string; name: string }[] }
export interface PeopleGateway { read(termId: string): Promise<{ people: Person[]; processes: ProcessContact[] }> }
export function createPeopleGateway(ready: ReturnType<typeof createSupabaseClient>): PeopleGateway {
  return { async read(termId) {
    try {
      const client = await ready
      if (!client) throw new Error()
      const [people, processes] = await Promise.all([
        client.rpc('read_people_directory', { p_term_id: termId }),
        client.rpc('read_process_contacts', { p_term_id: termId }),
      ])
      if (people.error || processes.error || !Array.isArray(people.data) || !Array.isArray(processes.data)) throw new Error()
      return { people: people.data as unknown as Person[], processes: processes.data as unknown as ProcessContact[] }
    } catch { throw new Error('The directory could not be loaded. Check your access and try again.') }
  } }
}
