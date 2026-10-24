import type { createSupabaseClient } from '../../lib/supabase'
export type ProfileValues = { course: string | null; yearLevel: string | null; phone: string | null; externalContact: string | null }
export type ProfileVisibility = { shareCourse: boolean; shareYearLevel: boolean; sharePhone: boolean; shareExternalContact: boolean }
export type OwnProfile = ProfileValues & ProfileVisibility & { memberId: string; displayName: string; version: number }
export interface ProfileGateway {
  read(termId: string): Promise<OwnProfile>
  save(termId: string, values: ProfileValues, version: number, requestId: string): Promise<OwnProfile>
  share(termId: string, visibility: ProfileVisibility, version: number, requestId: string): Promise<OwnProfile>
}
function profile(data: unknown): OwnProfile {
  if (!data || typeof data !== 'object') throw new Error('Your profile could not be loaded. Check access and try again.')
  const value = data as Record<string, unknown>
  if (typeof value.memberId !== 'string' || typeof value.displayName !== 'string' || !Number.isInteger(value.version) || (value.version as number) < 0
    || !['course','yearLevel','phone','externalContact'].every(key => value[key] === null || typeof value[key] === 'string')
    || !['shareCourse','shareYearLevel','sharePhone','shareExternalContact'].every(key => typeof value[key] === 'boolean')) throw new Error('Your profile could not be loaded. Check access and try again.')
  return value as OwnProfile
}
export function createProfileGateway(ready: ReturnType<typeof createSupabaseClient>): ProfileGateway {
  const failure = (code?: string) => new Error(code === '40001' ? 'Your profile changed elsewhere. Reload the profile before saving again.' : code === '42501' ? 'Profile access is unavailable or the term is frozen. Check with your workspace maintainer.' : 'The profile request could not be confirmed. Retry with the same details, or reload the profile.')
  return {
    async read(termId) {
      const client = await ready
      if (!client) throw failure()
      const { data, error } = await client.rpc('read_own_profile', { p_term_id: termId })
      if (error) throw failure(error.code)
      return profile(data)
    },
    async save(termId, values, version, requestId) {
      const client = await ready
      if (!client) throw failure()
      try {
        const { data, error } = await client.rpc('save_private_profile', { p_term_id: termId, p_values: values, p_expected_version: version, p_request_id: requestId })
        if (error) throw failure(error.code)
        return profile(data)
      } catch (error) { if (error instanceof Error && error.message.startsWith('Your profile changed')) throw error; if (error instanceof Error && error.message.startsWith('Profile access')) throw error; throw failure() }
    },
    async share(termId, visibility, version, requestId) {
      const client = await ready
      if (!client) throw failure()
      try {
        const { data, error } = await client.rpc('set_profile_visibility', { p_term_id: termId, p_visibility: visibility, p_expected_version: version, p_request_id: requestId })
        if (error) throw failure(error.code)
        return profile(data)
      } catch (error) { if (error instanceof Error && error.message.startsWith('Your profile changed')) throw error; if (error instanceof Error && error.message.startsWith('Profile access')) throw error; throw failure() }
    },
  }
}
