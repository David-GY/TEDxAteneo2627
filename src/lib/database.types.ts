// Generated from the migrated PostgreSQL catalog by pnpm db:types. Do not edit.
// Supabase-compatible table shape; full Supabase CLI comparison awaits Docker.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: {
      guest_contact_profiles: {
        Row: {
          user_id: string
          display_name: string | null
          contact_route: string | null
          version: number
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          user_id: string
          display_name?: string | null
          contact_route?: string | null
          version?: number
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          user_id?: string
          display_name?: string | null
          contact_route?: string | null
          version?: number
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
        ]
      }
      guest_invitation_events: {
        Row: {
          id: string
          invitation_id: string
          actor_id: string
          event: string
          occurred_at: string
          request_id: string | null
        }
        Insert: {
          id?: string
          invitation_id: string
          actor_id: string
          event: string
          occurred_at?: string
          request_id?: string | null
        }
        Update: {
          id?: string
          invitation_id?: string
          actor_id?: string
          event?: string
          occurred_at?: string
          request_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "guest_invitation_events_invitation_id_fkey"
            columns: ["invitation_id"]
            isOneToOne: false
            referencedRelation: "guest_invitations"
            referencedColumns: ["id"]
          },
        ]
      }
      guest_invitations: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          sponsor_id: string
          email: string
          token_hash: string
          scope_mode: string
          created_at: string
          expires_at: string
          redeemed_by: string | null
          redeemed_at: string | null
          revoked_at: string | null
          version: number
          request_id: string
          replaces_id: string | null
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          sponsor_id: string
          email: string
          token_hash: string
          scope_mode?: string
          created_at?: string
          expires_at?: string
          redeemed_by?: string | null
          redeemed_at?: string | null
          revoked_at?: string | null
          version?: number
          request_id: string
          replaces_id?: string | null
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          sponsor_id?: string
          email?: string
          token_hash?: string
          scope_mode?: string
          created_at?: string
          expires_at?: string
          redeemed_by?: string | null
          redeemed_at?: string | null
          revoked_at?: string | null
          version?: number
          request_id?: string
          replaces_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "guest_invitations_replaces_id_fkey"
            columns: ["replaces_id"]
            isOneToOne: false
            referencedRelation: "guest_invitations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guest_invitations_sponsor_id_organization_id_term_id_fkey"
            columns: ["sponsor_id","organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id","organization_id","term_id"]
          },
        ]
      }
      guest_profile_commands: {
        Row: {
          user_id: string
          request_id: string
          invitation_id: string
          fingerprint: string
          result_version: number
          occurred_at: string
        }
        Insert: {
          user_id: string
          request_id: string
          invitation_id: string
          fingerprint: string
          result_version: number
          occurred_at?: string
        }
        Update: {
          user_id?: string
          request_id?: string
          invitation_id?: string
          fingerprint?: string
          result_version?: number
          occurred_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "guest_profile_commands_invitation_id_fkey"
            columns: ["invitation_id"]
            isOneToOne: false
            referencedRelation: "guest_invitations"
            referencedColumns: ["id"]
          },
        ]
      }
      members: {
        Row: {
          id: string
          organization_id: string
          auth_user_id: string | null
          email: string
          normalized_email: string
          display_name: string
          account_state: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          auth_user_id?: string | null
          email: string
          normalized_email?: never
          display_name: string
          account_state?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          auth_user_id?: string | null
          email?: string
          normalized_email?: never
          display_name?: string
          account_state?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "members_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      org_units: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          code: string
          name: string
          delivery_committee: boolean
          review_service: boolean
          archived_at: string | null
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          code: string
          name: string
          delivery_committee?: boolean
          review_service?: boolean
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          code?: string
          name?: string
          delivery_committee?: boolean
          review_service?: boolean
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "org_units_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
        ]
      }
      organizations: {
        Row: {
          id: string
          slug: string
          name: string
          state: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          slug: string
          name: string
          state?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          slug?: string
          name?: string
          state?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
        ]
      }
      private_profiles: {
        Row: {
          member_id: string
          organization_id: string
          course: string | null
          year_level: string | null
          phone: string | null
          external_contact: string | null
          share_course: boolean
          share_year_level: boolean
          share_phone: boolean
          share_external_contact: boolean
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
          skills: string | null
          pronunciation: string | null
          share_skills: boolean
          share_pronunciation: boolean
          share_affiliation: boolean
        }
        Insert: {
          member_id: string
          organization_id: string
          course?: string | null
          year_level?: string | null
          phone?: string | null
          external_contact?: string | null
          share_course?: boolean
          share_year_level?: boolean
          share_phone?: boolean
          share_external_contact?: boolean
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
          skills?: string | null
          pronunciation?: string | null
          share_skills?: boolean
          share_pronunciation?: boolean
          share_affiliation?: boolean
        }
        Update: {
          member_id?: string
          organization_id?: string
          course?: string | null
          year_level?: string | null
          phone?: string | null
          external_contact?: string | null
          share_course?: boolean
          share_year_level?: boolean
          share_phone?: boolean
          share_external_contact?: boolean
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
          skills?: string | null
          pronunciation?: string | null
          share_skills?: boolean
          share_pronunciation?: boolean
          share_affiliation?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "private_profiles_organization_id_member_id_fkey"
            columns: ["organization_id","member_id"]
            isOneToOne: true
            referencedRelation: "members"
            referencedColumns: ["organization_id","id"]
          },
        ]
      }
      profile_commands: {
        Row: {
          member_id: string
          request_id: string
          actor_id: string
          command: string
          fingerprint: string
          result_version: number
          occurred_at: string
          actor_display_name: string | null
        }
        Insert: {
          member_id: string
          request_id: string
          actor_id: string
          command: string
          fingerprint: string
          result_version: number
          occurred_at?: string
          actor_display_name?: string | null
        }
        Update: {
          member_id?: string
          request_id?: string
          actor_id?: string
          command?: string
          fingerprint?: string
          result_version?: number
          occurred_at?: string
          actor_display_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profile_commands_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
      role_assignments: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          term_membership_id: string
          role_id: string
          scope_type: string
          unit_id: string | null
          status: string
          effective_from: string
          effective_to: string
          granted_by: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          term_membership_id: string
          role_id: string
          scope_type: string
          unit_id?: string | null
          status?: string
          effective_from: string
          effective_to: string
          granted_by: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          term_membership_id?: string
          role_id?: string
          scope_type?: string
          unit_id?: string | null
          status?: string
          effective_from?: string
          effective_to?: string
          granted_by?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "role_assignments_organization_id_term_id_granted_by_fkey"
            columns: ["organization_id","term_id","granted_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_term_id_role_id_fkey"
            columns: ["organization_id","term_id","role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_term_id_term_membership_i_fkey"
            columns: ["organization_id","term_id","term_membership_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_term_id_unit_id_fkey"
            columns: ["organization_id","term_id","unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          role_id: string
          capability: string
          resource: string
          action: string
          allowed_scope: string
          privileged: boolean
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          role_id: string
          capability: string
          resource?: never
          action?: never
          allowed_scope: string
          privileged?: never
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          role_id?: string
          capability?: string
          resource?: never
          action?: never
          allowed_scope?: string
          privileged?: never
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_organization_id_term_id_role_id_fkey"
            columns: ["organization_id","term_id","role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
      roles: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          code: string
          name: string
          privileged: boolean
          state: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          code: string
          name: string
          privileged?: boolean
          state?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          code?: string
          name?: string
          privileged?: boolean
          state?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "roles_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
        ]
      }
      term_memberships: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          member_id: string
          membership_kind: string
          status: string
          joined_at: string
          ends_at: string
          affiliation_tag: string | null
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          member_id: string
          membership_kind?: string
          status?: string
          joined_at: string
          ends_at: string
          affiliation_tag?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          member_id?: string
          membership_kind?: string
          status?: string
          joined_at?: string
          ends_at?: string
          affiliation_tag?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "term_memberships_organization_id_member_id_fkey"
            columns: ["organization_id","member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["organization_id","id"]
          },
          {
            foreignKeyName: "term_memberships_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
        ]
      }
      terms: {
        Row: {
          id: string
          organization_id: string
          label: string
          event_date: string
          starts_on: string
          closes_on: string
          state: string
          frozen_at: string | null
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          label: string
          event_date: string
          starts_on: string
          closes_on: string
          state?: string
          frozen_at?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          label?: string
          event_date?: string
          starts_on?: string
          closes_on?: string
          state?: string
          frozen_at?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "terms_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      unit_memberships: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          term_membership_id: string
          unit_id: string
          deployment_type: string
          status: string
          effective_from: string
          effective_to: string
          approved_by: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          term_membership_id: string
          unit_id: string
          deployment_type: string
          status?: string
          effective_from: string
          effective_to: string
          approved_by: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          term_membership_id?: string
          unit_id?: string
          deployment_type?: string
          status?: string
          effective_from?: string
          effective_to?: string
          approved_by?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "unit_memberships_organization_id_term_id_approved_by_fkey"
            columns: ["organization_id","term_id","approved_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "unit_memberships_organization_id_term_id_term_membership_i_fkey"
            columns: ["organization_id","term_id","term_membership_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "unit_memberships_organization_id_term_id_unit_id_fkey"
            columns: ["organization_id","term_id","unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
    }
    Views: { [_ in never]: never }
    Functions: {
      create_guest_invitation: {
        Args: {
          p_term_id: string
          p_email: string
          p_request_id: string
          p_expires_at?: string | null
          p_replaces_id?: string | null
          p_expected_version?: number | null
        }
        Returns: Json | null
      }
      current_term_membership: {
        Args: {
          p_term_id: string
        }
        Returns: string | null
      }
      explain_access: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      has_capability: {
        Args: {
          p_term_id: string
          p_capability: string
          p_unit_id?: string | null
        }
        Returns: boolean | null
      }
      list_guest_invitations: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      owns_active_member: {
        Args: {
          p_member_id: string
          p_write?: boolean | null
        }
        Returns: boolean | null
      }
      read_directory: {
        Args: {
          p_term_id: string
        }
        Returns: {
          member_id: string
          display_name: string
        }[]
      }
      read_guest_contacts: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_own_profile: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_people_directory: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_process_contacts: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      redeem_guest_invitation: {
        Args: {
          p_token: string
        }
        Returns: Json | null
      }
      resolve_auth_context: {
        Args: Record<string, never>
        Returns: Json | null
      }
      revoke_guest_access: {
        Args: {
          p_invitation_id: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      save_guest_contact_profile: {
        Args: {
          p_term_id: string
          p_values: Json
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      save_private_profile: {
        Args: {
          p_term_id: string
          p_values: Json
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      set_profile_visibility: {
        Args: {
          p_term_id: string
          p_visibility: Json
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
    }
    Enums: { [_ in never]: never }
    CompositeTypes: { [_ in never]: never }
  }
}
