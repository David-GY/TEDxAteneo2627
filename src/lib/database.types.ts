// Generated from the migrated PostgreSQL catalog by pnpm db:types. Do not edit.
// Supabase-compatible table shape; full Supabase CLI comparison awaits Docker.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: {
      announcements: {
        Row: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind: string
          body: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          work_item_id?: string
          organization_id?: string
          term_id?: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "announcements_organization_id_term_id_work_item_id_kind_fkey"
            columns: ["organization_id","term_id","work_item_id","kind"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id","kind"]
          },
        ]
      }
      audit_events: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          actor_id: string
          actor_display_name: string
          action: string
          work_item_id: string
          revision: number
          occurred_at: string
          request_id: string
          redacted_diff: Json
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          actor_id: string
          actor_display_name: string
          action: string
          work_item_id: string
          revision: number
          occurred_at?: string
          request_id: string
          redacted_diff: Json
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          actor_id?: string
          actor_display_name?: string
          action?: string
          work_item_id?: string
          revision?: number
          occurred_at?: string
          request_id?: string
          redacted_diff?: Json
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_organization_id_term_id_work_item_id_fkey"
            columns: ["organization_id","term_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
      deliverable_gate_assessments: {
        Row: {
          work_item_id: string
          work_version: number
          gate: string
          disposition: string
          reason: string
          assessed_by: string
          assessed_at: string
        }
        Insert: {
          work_item_id: string
          work_version: number
          gate: string
          disposition: string
          reason: string
          assessed_by: string
          assessed_at?: string
        }
        Update: {
          work_item_id?: string
          work_version?: number
          gate?: string
          disposition?: string
          reason?: string
          assessed_by?: string
          assessed_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_gate_assessments_assessed_by_fkey"
            columns: ["assessed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_gate_assessments_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      deliverable_revisions: {
        Row: {
          id: string
          work_item_id: string
          work_version: number
          criteria_revision: number
          workflow_state: string
          title: string
          outcome: string
          acceptance_criteria: string
          owner_member_id: string
          due_on: string | null
          due_at: string | null
          reason: string
          final_evidence: string | null
          review_evidence: string | null
          actor_id: string
          recorded_at: string
        }
        Insert: {
          id?: string
          work_item_id: string
          work_version: number
          criteria_revision: number
          workflow_state: string
          title: string
          outcome: string
          acceptance_criteria: string
          owner_member_id: string
          due_on?: string | null
          due_at?: string | null
          reason: string
          final_evidence?: string | null
          review_evidence?: string | null
          actor_id: string
          recorded_at?: string
        }
        Update: {
          id?: string
          work_item_id?: string
          work_version?: number
          criteria_revision?: number
          workflow_state?: string
          title?: string
          outcome?: string
          acceptance_criteria?: string
          owner_member_id?: string
          due_on?: string | null
          due_at?: string | null
          reason?: string
          final_evidence?: string | null
          review_evidence?: string | null
          actor_id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_revisions_owner_member_id_fkey"
            columns: ["owner_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_revisions_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      deliverable_units: {
        Row: {
          organization_id: string
          term_id: string
          work_item_id: string
          unit_id: string
        }
        Insert: {
          organization_id: string
          term_id: string
          work_item_id: string
          unit_id: string
        }
        Update: {
          organization_id?: string
          term_id?: string
          work_item_id?: string
          unit_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_units_organization_id_term_id_unit_id_fkey"
            columns: ["organization_id","term_id","unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "deliverable_units_organization_id_term_id_work_item_id_fkey"
            columns: ["organization_id","term_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["organization_id","term_id","work_item_id"]
          },
        ]
      }
      deliverables: {
        Row: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind: string
          body: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
          phase_key: string | null
          outcome: string | null
          acceptance_criteria: string | null
          is_blocked: boolean
          safe_blocker_summary: string | null
          workflow_state: string
          criteria_revision: number
          final_evidence: string | null
        }
        Insert: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
          phase_key?: string | null
          outcome?: string | null
          acceptance_criteria?: string | null
          is_blocked?: boolean
          safe_blocker_summary?: string | null
          workflow_state?: string
          criteria_revision?: number
          final_evidence?: string | null
        }
        Update: {
          work_item_id?: string
          organization_id?: string
          term_id?: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
          phase_key?: string | null
          outcome?: string | null
          acceptance_criteria?: string | null
          is_blocked?: boolean
          safe_blocker_summary?: string | null
          workflow_state?: string
          criteria_revision?: number
          final_evidence?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "deliverables_organization_id_term_id_work_item_id_kind_fkey"
            columns: ["organization_id","term_id","work_item_id","kind"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id","kind"]
          },
        ]
      }
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
      idempotency_keys: {
        Row: {
          actor_id: string
          command: string
          client_key: string
          organization_id: string
          term_id: string
          payload_hash: string
          result_reference: Json
          created_at: string
          expires_at: string | null
        }
        Insert: {
          actor_id: string
          command: string
          client_key: string
          organization_id: string
          term_id: string
          payload_hash: string
          result_reference: Json
          created_at?: string
          expires_at?: string | null
        }
        Update: {
          actor_id?: string
          command?: string
          client_key?: string
          organization_id?: string
          term_id?: string
          payload_hash?: string
          result_reference?: Json
          created_at?: string
          expires_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "idempotency_keys_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
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
      outbox_jobs: {
        Row: {
          id: string
          event_id: string
          work_item_id: string
          event_type: string
          payload: Json
          state: string
          attempts: number
          next_at: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          id?: string
          event_id: string
          work_item_id: string
          event_type: string
          payload: Json
          state?: string
          attempts?: number
          next_at?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          id?: string
          event_id?: string
          work_item_id?: string
          event_type?: string
          payload?: Json
          state?: string
          attempts?: number
          next_at?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "outbox_jobs_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: true
            referencedRelation: "audit_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outbox_jobs_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["id"]
          },
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
      record_grants: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          work_item_id: string
          member_id: string | null
          unit_id: string | null
          guest_invitation_id: string | null
          grant_kind: string
          starts_at: string
          expires_at: string
          revoked_at: string | null
          grantor_id: string
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
          work_item_id: string
          member_id?: string | null
          unit_id?: string | null
          guest_invitation_id?: string | null
          grant_kind: string
          starts_at?: string
          expires_at: string
          revoked_at?: string | null
          grantor_id: string
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
          work_item_id?: string
          member_id?: string | null
          unit_id?: string | null
          guest_invitation_id?: string | null
          grant_kind?: string
          starts_at?: string
          expires_at?: string
          revoked_at?: string | null
          grantor_id?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "record_grants_organization_id_term_id_grantor_id_fkey"
            columns: ["organization_id","term_id","grantor_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "record_grants_organization_id_term_id_guest_invitation_id_fkey"
            columns: ["organization_id","term_id","guest_invitation_id"]
            isOneToOne: false
            referencedRelation: "guest_invitations"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "record_grants_organization_id_term_id_member_id_fkey"
            columns: ["organization_id","term_id","member_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","member_id"]
          },
          {
            foreignKeyName: "record_grants_organization_id_term_id_unit_id_fkey"
            columns: ["organization_id","term_id","unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "record_grants_organization_id_term_id_work_item_id_fkey"
            columns: ["organization_id","term_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
      requests: {
        Row: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind: string
          body: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          work_item_id?: string
          organization_id?: string
          term_id?: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "requests_organization_id_term_id_work_item_id_kind_fkey"
            columns: ["organization_id","term_id","work_item_id","kind"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id","kind"]
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
          work_id: string | null
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
          work_id?: string | null
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
          work_id?: string | null
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
          {
            foreignKeyName: "role_assignments_organization_id_term_id_work_id_fkey"
            columns: ["organization_id","term_id","work_id"]
            isOneToOne: false
            referencedRelation: "work_items"
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
      status_definitions: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          resource_kind: string
          stable_key: string
          semantic_category: string
          label: string
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
          resource_kind: string
          stable_key: string
          semantic_category: string
          label: string
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
          resource_kind?: string
          stable_key?: string
          semantic_category?: string
          label?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "status_definitions_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
        ]
      }
      tasks: {
        Row: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind: string
          body: string
          created_at: string
          created_by: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          work_item_id: string
          organization_id: string
          term_id: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          work_item_id?: string
          organization_id?: string
          term_id?: string
          kind?: string
          body?: string
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "tasks_organization_id_term_id_work_item_id_kind_fkey"
            columns: ["organization_id","term_id","work_item_id","kind"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id","kind"]
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
      work_items: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          kind: string
          title: string
          safe_summary: string
          classification: string
          owner_member_id: string
          owner_display_name: string
          lead_unit_id: string | null
          status_id: string
          parent_work_item_id: string | null
          due_at: string | null
          due_on: string | null
          original_due_at: string | null
          original_due_on: string | null
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
          kind: string
          title: string
          safe_summary?: string
          classification: string
          owner_member_id: string
          owner_display_name: string
          lead_unit_id?: string | null
          status_id: string
          parent_work_item_id?: string | null
          due_at?: string | null
          due_on?: string | null
          original_due_at?: string | null
          original_due_on?: string | null
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
          kind?: string
          title?: string
          safe_summary?: string
          classification?: string
          owner_member_id?: string
          owner_display_name?: string
          lead_unit_id?: string | null
          status_id?: string
          parent_work_item_id?: string | null
          due_at?: string | null
          due_on?: string | null
          original_due_at?: string | null
          original_due_on?: string | null
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "work_items_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
          {
            foreignKeyName: "work_items_organization_id_term_id_lead_unit_id_fkey"
            columns: ["organization_id","term_id","lead_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "work_items_organization_id_term_id_owner_member_id_fkey"
            columns: ["organization_id","term_id","owner_member_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","member_id"]
          },
          {
            foreignKeyName: "work_items_organization_id_term_id_parent_work_item_id_fkey"
            columns: ["organization_id","term_id","parent_work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "work_items_organization_id_term_id_status_id_kind_fkey"
            columns: ["organization_id","term_id","status_id","kind"]
            isOneToOne: false
            referencedRelation: "status_definitions"
            referencedColumns: ["organization_id","term_id","id","resource_kind"]
          },
        ]
      }
    }
    Views: { [_ in never]: never }
    Functions: {
      can_access_work: {
        Args: {
          p_work_item_id: string
          p_level: string
        }
        Returns: boolean | null
      }
      can_read_work_grant: {
        Args: {
          p_grant_id: string
        }
        Returns: boolean | null
      }
      create_deliverable: {
        Args: {
          p_term_id: string
          p_data: Json
          p_propose: boolean
          p_request_id: string
        }
        Returns: Json | null
      }
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
      create_work_item: {
        Args: {
          p_term_id: string
          p_kind: string
          p_title: string
          p_safe_summary: string
          p_body: string
          p_classification: string
          p_lead_unit_id?: string | null
          p_parent_id?: string | null
          p_expected_parent_version?: number | null
          p_request_id?: string | null
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
      grant_work_access: {
        Args: {
          p_work_item_id: string
          p_member_id?: string | null
          p_unit_id?: string | null
          p_guest_invitation_id?: string | null
          p_grant_kind?: string | null
          p_expires_at?: string | null
          p_expected_version?: number | null
          p_request_id?: string | null
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
      has_work_capability: {
        Args: {
          p_work_item_id: string
          p_capability: string
        }
        Returns: boolean | null
      }
      list_deliverables: {
        Args: {
          p_term_id: string
          p_phase?: string | null
          p_unit_id?: string | null
          p_owner_id?: string | null
          p_blocked?: boolean | null
          p_overdue?: boolean | null
          p_involves_my_unit?: boolean | null
          p_review_pending?: boolean | null
          p_page?: number | null
          p_page_size?: number | null
        }
        Returns: Json | null
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
      read_deliverable: {
        Args: {
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_deliverable_authoring: {
        Args: {
          p_term_id: string
          p_work_item_id?: string | null
        }
        Returns: Json | null
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
      read_work_parent: {
        Args: {
          p_work_item_id: string
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
      revoke_work_access: {
        Args: {
          p_grant_id: string
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
      transition_deliverable: {
        Args: {
          p_work_item_id: string
          p_action: string
          p_reason: string
          p_evidence: string
          p_expected_version: number
          p_request_id: string
          p_criteria_revision?: number | null
        }
        Returns: Json | null
      }
      update_deliverable: {
        Args: {
          p_work_item_id: string
          p_data: Json
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      update_work_item: {
        Args: {
          p_work_item_id: string
          p_title: string
          p_safe_summary: string
          p_body: string
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
