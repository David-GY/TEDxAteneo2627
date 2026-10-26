// Generated from the migrated PostgreSQL catalog by pnpm db:types. Do not edit.
// Supabase-compatible table shape; full Supabase CLI comparison awaits Docker.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: {
      actual_finance_events: {
        Row: {
          id: string
          record_id: string
          kind: string
          authorization_id: string
          entry_id: string | null
          actor_id: string
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          record_id: string
          kind: string
          authorization_id: string
          entry_id?: string | null
          actor_id: string
          reason: string
          recorded_at?: string
        }
        Update: {
          id?: string
          record_id?: string
          kind?: string
          authorization_id?: string
          entry_id?: string | null
          actor_id?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "actual_finance_events_authorization_id_fkey"
            columns: ["authorization_id"]
            isOneToOne: false
            referencedRelation: "financial_authorizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "actual_finance_events_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: true
            referencedRelation: "budget_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "actual_finance_events_record_id_fkey"
            columns: ["record_id"]
            isOneToOne: false
            referencedRelation: "actual_finance_records"
            referencedColumns: ["id"]
          },
        ]
      }
      actual_finance_records: {
        Row: {
          id: string
          request_id: string
          term_id: string
          authorization_id: string
          kind: string
          amount_centavos: number
          evidence_asset_id: string
          evidence_sha256: string
          reference: string
          recorded_on: string
          recorded_by: string
          recorded_at: string
        }
        Insert: {
          id?: string
          request_id: string
          term_id: string
          authorization_id: string
          kind: string
          amount_centavos: number
          evidence_asset_id: string
          evidence_sha256: string
          reference: string
          recorded_on: string
          recorded_by: string
          recorded_at?: string
        }
        Update: {
          id?: string
          request_id?: string
          term_id?: string
          authorization_id?: string
          kind?: string
          amount_centavos?: number
          evidence_asset_id?: string
          evidence_sha256?: string
          reference?: string
          recorded_on?: string
          recorded_by?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "actual_finance_records_authorization_id_fkey"
            columns: ["authorization_id"]
            isOneToOne: false
            referencedRelation: "financial_authorizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "actual_finance_records_evidence_asset_id_request_id_fkey"
            columns: ["evidence_asset_id","request_id"]
            isOneToOne: false
            referencedRelation: "assets"
            referencedColumns: ["id","origin_work_item_id"]
          },
          {
            foreignKeyName: "actual_finance_records_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: false
            referencedRelation: "finance_cases"
            referencedColumns: ["request_id"]
          },
          {
            foreignKeyName: "actual_finance_records_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["id"]
          },
        ]
      }
      agreement_confirmations: {
        Row: {
          id: string
          agreement_id: string
          revision: number
          agreement_version: number
          side: string
          decision: string
          member_id: string
          actor_id: string
          selected_owner_id: string | null
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          agreement_id: string
          revision: number
          agreement_version: number
          side: string
          decision: string
          member_id: string
          actor_id: string
          selected_owner_id?: string | null
          reason: string
          recorded_at?: string
        }
        Update: {
          id?: string
          agreement_id?: string
          revision?: number
          agreement_version?: number
          side?: string
          decision?: string
          member_id?: string
          actor_id?: string
          selected_owner_id?: string | null
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "agreement_confirmations_agreement_id_revision_fkey"
            columns: ["agreement_id","revision"]
            isOneToOne: false
            referencedRelation: "agreement_revisions"
            referencedColumns: ["agreement_id","revision"]
          },
          {
            foreignKeyName: "agreement_confirmations_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "agreement_confirmations_selected_owner_id_fkey"
            columns: ["selected_owner_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
      agreement_revision_sources: {
        Row: {
          agreement_id: string
          revision: number
          manifest_id: string
        }
        Insert: {
          agreement_id: string
          revision: number
          manifest_id: string
        }
        Update: {
          agreement_id?: string
          revision?: number
          manifest_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "agreement_revision_sources_agreement_id_revision_fkey"
            columns: ["agreement_id","revision"]
            isOneToOne: false
            referencedRelation: "agreement_revisions"
            referencedColumns: ["agreement_id","revision"]
          },
          {
            foreignKeyName: "agreement_revision_sources_manifest_id_fkey"
            columns: ["manifest_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id"]
          },
        ]
      }
      agreement_revisions: {
        Row: {
          agreement_id: string
          revision: number
          parent_version: number
          output: string
          criteria: string
          effort_band: string
          due_on: string
          owner_candidate_id: string | null
          proposer_side: string
          proposer_member_id: string
          actor_id: string
          reason: string
          recorded_at: string
        }
        Insert: {
          agreement_id: string
          revision: number
          parent_version: number
          output: string
          criteria: string
          effort_band: string
          due_on: string
          owner_candidate_id?: string | null
          proposer_side: string
          proposer_member_id: string
          actor_id: string
          reason: string
          recorded_at?: string
        }
        Update: {
          agreement_id?: string
          revision?: number
          parent_version?: number
          output?: string
          criteria?: string
          effort_band?: string
          due_on?: string
          owner_candidate_id?: string | null
          proposer_side?: string
          proposer_member_id?: string
          actor_id?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "agreement_revisions_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: false
            referencedRelation: "synergy_agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "agreement_revisions_owner_candidate_id_fkey"
            columns: ["owner_candidate_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "agreement_revisions_proposer_member_id_fkey"
            columns: ["proposer_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
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
      approval_assignments: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          request_id: string
          revision_id: string
          instance_id: string
          stage_key: string
          generation: number
          slot: number
          reviewer_id: string
          reviewer_name: string
          authority_id: string
          authority_version: number
          expires_at: string
          assigned_at: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          request_id: string
          revision_id: string
          instance_id: string
          stage_key: string
          generation: number
          slot: number
          reviewer_id: string
          reviewer_name: string
          authority_id: string
          authority_version: number
          expires_at: string
          assigned_at?: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          request_id?: string
          revision_id?: string
          instance_id?: string
          stage_key?: string
          generation?: number
          slot?: number
          reviewer_id?: string
          reviewer_name?: string
          authority_id?: string
          authority_version?: number
          expires_at?: string
          assigned_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_assignments_organization_id_term_id_authority_id_fkey"
            columns: ["organization_id","term_id","authority_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "approval_assignments_organization_id_term_id_request_id_re_fkey"
            columns: ["organization_id","term_id","request_id","revision_id","instance_id"]
            isOneToOne: false
            referencedRelation: "workflow_instances"
            referencedColumns: ["organization_id","term_id","request_id","revision_id","id"]
          },
          {
            foreignKeyName: "approval_assignments_organization_id_term_id_reviewer_id_fkey"
            columns: ["organization_id","term_id","reviewer_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
      approval_decisions: {
        Row: {
          id: string
          assignment_id: string
          organization_id: string
          term_id: string
          request_id: string
          revision_id: string
          instance_id: string
          stage_key: string
          generation: number
          action: string
          reason: string
          payload_hash: string
          evidence_manifest_id: string | null
          decided_at: string
        }
        Insert: {
          id?: string
          assignment_id: string
          organization_id: string
          term_id: string
          request_id: string
          revision_id: string
          instance_id: string
          stage_key: string
          generation: number
          action: string
          reason: string
          payload_hash: string
          evidence_manifest_id?: string | null
          decided_at?: string
        }
        Update: {
          id?: string
          assignment_id?: string
          organization_id?: string
          term_id?: string
          request_id?: string
          revision_id?: string
          instance_id?: string
          stage_key?: string
          generation?: number
          action?: string
          reason?: string
          payload_hash?: string
          evidence_manifest_id?: string | null
          decided_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_decisions_assignment_id_request_id_revision_id_in_fkey"
            columns: ["assignment_id","request_id","revision_id","instance_id","stage_key","generation"]
            isOneToOne: true
            referencedRelation: "approval_assignments"
            referencedColumns: ["id","request_id","revision_id","instance_id","stage_key","generation"]
          },
          {
            foreignKeyName: "approval_decisions_evidence_manifest_id_request_id_fkey"
            columns: ["evidence_manifest_id","request_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "approval_decisions_organization_id_term_id_request_id_revi_fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: false
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
        ]
      }
      asset_links: {
        Row: {
          asset_id: string
          work_item_id: string
          created_by: string
          created_at: string
        }
        Insert: {
          asset_id: string
          work_item_id: string
          created_by: string
          created_at?: string
        }
        Update: {
          asset_id?: string
          work_item_id?: string
          created_by?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "asset_links_asset_id_fkey"
            columns: ["asset_id"]
            isOneToOne: false
            referencedRelation: "assets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "asset_links_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      asset_manifest_items: {
        Row: {
          manifest_id: string
          asset_id: string
        }
        Insert: {
          manifest_id: string
          asset_id: string
        }
        Update: {
          manifest_id?: string
          asset_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "asset_manifest_items_asset_id_fkey"
            columns: ["asset_id"]
            isOneToOne: false
            referencedRelation: "assets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "asset_manifest_items_manifest_id_fkey"
            columns: ["manifest_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id"]
          },
        ]
      }
      asset_manifests: {
        Row: {
          id: string
          work_item_id: string
          work_version: number
          entries: Json
          sha256: string
          size_bytes: number
          created_by: string
          created_at: string
        }
        Insert: {
          id?: string
          work_item_id: string
          work_version: number
          entries: Json
          sha256: string
          size_bytes: number
          created_by: string
          created_at?: string
        }
        Update: {
          id?: string
          work_item_id?: string
          work_version?: number
          entries?: Json
          sha256?: string
          size_bytes?: number
          created_by?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "asset_manifests_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      assets: {
        Row: {
          id: string
          origin_work_item_id: string
          kind: string
          classification: string
          filename: string
          mime_type: string | null
          size_bytes: number | null
          sha256: string | null
          object_path: string | null
          source_url: string | null
          access_notes: string | null
          source_label: string | null
          source_snapshot: Json | null
          state: string
          version: number
          created_by: string
          created_at: string
          updated_at: string
          expires_at: string | null
        }
        Insert: {
          id?: string
          origin_work_item_id: string
          kind: string
          classification: string
          filename: string
          mime_type?: string | null
          size_bytes?: number | null
          sha256?: string | null
          object_path?: string | null
          source_url?: string | null
          access_notes?: string | null
          source_label?: string | null
          source_snapshot?: Json | null
          state: string
          version?: number
          created_by: string
          created_at?: string
          updated_at?: string
          expires_at?: string | null
        }
        Update: {
          id?: string
          origin_work_item_id?: string
          kind?: string
          classification?: string
          filename?: string
          mime_type?: string | null
          size_bytes?: number | null
          sha256?: string | null
          object_path?: string | null
          source_url?: string | null
          access_notes?: string | null
          source_label?: string | null
          source_snapshot?: Json | null
          state?: string
          version?: number
          created_by?: string
          created_at?: string
          updated_at?: string
          expires_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "assets_origin_work_item_id_fkey"
            columns: ["origin_work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["id"]
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
      budget_accounts: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          unit_id: string
          fund_source: string
          ceiling_centavos: number
          enabled: boolean
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          unit_id: string
          fund_source: string
          ceiling_centavos: number
          enabled: boolean
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          unit_id?: string
          fund_source?: string
          ceiling_centavos?: number
          enabled?: boolean
          official_reference?: string
          confirmed_by?: string
          effective_from?: string
          effective_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "budget_accounts_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budget_accounts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budget_accounts_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budget_accounts_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
        ]
      }
      budget_entries: {
        Row: {
          id: string
          account_id: string
          authorization_id: string
          kind: string
          reserved_delta_centavos: number
          expense_delta_centavos: number
          revenue_delta_centavos: number
          reverses_entry_id: string | null
          actor_id: string
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          account_id: string
          authorization_id: string
          kind: string
          reserved_delta_centavos?: number
          expense_delta_centavos?: number
          revenue_delta_centavos?: number
          reverses_entry_id?: string | null
          actor_id: string
          reason: string
          recorded_at?: string
        }
        Update: {
          id?: string
          account_id?: string
          authorization_id?: string
          kind?: string
          reserved_delta_centavos?: number
          expense_delta_centavos?: number
          revenue_delta_centavos?: number
          reverses_entry_id?: string | null
          actor_id?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "budget_entries_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "budget_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budget_entries_authorization_id_fkey"
            columns: ["authorization_id"]
            isOneToOne: false
            referencedRelation: "financial_authorizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "budget_entries_reverses_entry_id_fkey"
            columns: ["reverses_entry_id"]
            isOneToOne: true
            referencedRelation: "budget_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      calendar_event_versions: {
        Row: {
          work_item_id: string
          version: number
          actor_id: string
          snapshot: Json
          reason: string
          recorded_at: string
        }
        Insert: {
          work_item_id: string
          version: number
          actor_id: string
          snapshot: Json
          reason: string
          recorded_at?: string
        }
        Update: {
          work_item_id?: string
          version?: number
          actor_id?: string
          snapshot?: Json
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "calendar_event_versions_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "calendar_events"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      calendar_events: {
        Row: {
          work_item_id: string
          visibility: string
          title: string
          description: string
          location: string
          all_day: boolean
          start_on: string | null
          end_on: string | null
          starts_at: string | null
          ends_at: string | null
          state: string
        }
        Insert: {
          work_item_id: string
          visibility: string
          title: string
          description?: string
          location?: string
          all_day: boolean
          start_on?: string | null
          end_on?: string | null
          starts_at?: string | null
          ends_at?: string | null
          state: string
        }
        Update: {
          work_item_id?: string
          visibility?: string
          title?: string
          description?: string
          location?: string
          all_day?: boolean
          start_on?: string | null
          end_on?: string | null
          starts_at?: string | null
          ends_at?: string | null
          state?: string
        }
        Relationships: [
          {
            foreignKeyName: "calendar_events_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "announcements"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      comment_evidence: {
        Row: {
          comment_id: string
          revision: number
          purpose: string
          task_work_id: string | null
          task_version: number | null
          deliverable_work_id: string | null
          deliverable_version: number | null
        }
        Insert: {
          comment_id: string
          revision: number
          purpose: string
          task_work_id?: string | null
          task_version?: number | null
          deliverable_work_id?: string | null
          deliverable_version?: number | null
        }
        Update: {
          comment_id?: string
          revision?: number
          purpose?: string
          task_work_id?: string | null
          task_version?: number | null
          deliverable_work_id?: string | null
          deliverable_version?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "comment_evidence_comment_id_revision_fkey"
            columns: ["comment_id","revision"]
            isOneToOne: false
            referencedRelation: "comment_revisions"
            referencedColumns: ["comment_id","revision"]
          },
          {
            foreignKeyName: "comment_evidence_deliverable_work_id_deliverable_version_fkey"
            columns: ["deliverable_work_id","deliverable_version"]
            isOneToOne: false
            referencedRelation: "deliverable_revisions"
            referencedColumns: ["work_item_id","work_version"]
          },
          {
            foreignKeyName: "comment_evidence_task_work_id_task_version_fkey"
            columns: ["task_work_id","task_version"]
            isOneToOne: false
            referencedRelation: "task_revisions"
            referencedColumns: ["work_item_id","work_version"]
          },
        ]
      }
      comment_revisions: {
        Row: {
          comment_id: string
          revision: number
          body: string
          reason: string
          state: string
          mentions: string[]
          actor_id: string
          recorded_at: string
        }
        Insert: {
          comment_id: string
          revision: number
          body: string
          reason: string
          state: string
          mentions?: string[]
          actor_id: string
          recorded_at?: string
        }
        Update: {
          comment_id?: string
          revision?: number
          body?: string
          reason?: string
          state?: string
          mentions?: string[]
          actor_id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "comment_revisions_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: false
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          id: string
          work_item_id: string
          author_id: string
          author_name: string
          version: number
          state: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          work_item_id: string
          author_id: string
          author_name: string
          version?: number
          state: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          work_item_id?: string
          author_id?: string
          author_name?: string
          version?: number
          state?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      contributions: {
        Row: {
          work_item_id: string
          organization_id: string
          term_id: string
          agreement_id: string
          active_revision: number
          parent_work_item_id: string
          requester_unit_id: string
          receiver_unit_id: string
          owner_member_id: string
          owner_name: string
          created_at: string
          updated_at: string
        }
        Insert: {
          work_item_id: string
          organization_id: string
          term_id: string
          agreement_id: string
          active_revision: number
          parent_work_item_id: string
          requester_unit_id: string
          receiver_unit_id: string
          owner_member_id: string
          owner_name: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          work_item_id?: string
          organization_id?: string
          term_id?: string
          agreement_id?: string
          active_revision?: number
          parent_work_item_id?: string
          requester_unit_id?: string
          receiver_unit_id?: string
          owner_member_id?: string
          owner_name?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "contributions_agreement_id_active_revision_fkey"
            columns: ["agreement_id","active_revision"]
            isOneToOne: true
            referencedRelation: "agreement_revisions"
            referencedColumns: ["agreement_id","revision"]
          },
          {
            foreignKeyName: "contributions_agreement_id_fkey"
            columns: ["agreement_id"]
            isOneToOne: true
            referencedRelation: "synergy_agreements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "contributions_organization_id_term_id_owner_member_id_fkey"
            columns: ["organization_id","term_id","owner_member_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","member_id"]
          },
          {
            foreignKeyName: "contributions_organization_id_term_id_parent_work_item_id_fkey"
            columns: ["organization_id","term_id","parent_work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "contributions_organization_id_term_id_receiver_unit_id_fkey"
            columns: ["organization_id","term_id","receiver_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "contributions_organization_id_term_id_requester_unit_id_fkey"
            columns: ["organization_id","term_id","requester_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "contributions_organization_id_term_id_work_item_id_fkey"
            columns: ["organization_id","term_id","work_item_id"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "contributions_parent_work_item_id_fkey"
            columns: ["parent_work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "contributions_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      delegation_ceilings: {
        Row: {
          id: string
          term_id: string
          grantor_membership_id: string
          source_assignment_id: string
          source_assignment_version: number
          source_role_version: number
          capability: string
          scope_type: string
          unit_id: string | null
          work_id: string | null
          sensitive_authorized: boolean
          starts_at: string
          ends_at: string
          approved_by: string
          approval_reference: string
          revoked_at: string | null
        }
        Insert: {
          id?: string
          term_id: string
          grantor_membership_id: string
          source_assignment_id: string
          source_assignment_version: number
          source_role_version: number
          capability: string
          scope_type: string
          unit_id?: string | null
          work_id?: string | null
          sensitive_authorized?: boolean
          starts_at: string
          ends_at: string
          approved_by: string
          approval_reference: string
          revoked_at?: string | null
        }
        Update: {
          id?: string
          term_id?: string
          grantor_membership_id?: string
          source_assignment_id?: string
          source_assignment_version?: number
          source_role_version?: number
          capability?: string
          scope_type?: string
          unit_id?: string | null
          work_id?: string | null
          sensitive_authorized?: boolean
          starts_at?: string
          ends_at?: string
          approved_by?: string
          approval_reference?: string
          revoked_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "delegation_ceilings_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delegation_ceilings_grantor_membership_id_fkey"
            columns: ["grantor_membership_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delegation_ceilings_source_assignment_id_fkey"
            columns: ["source_assignment_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delegation_ceilings_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delegation_ceilings_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "delegation_ceilings_work_id_fkey"
            columns: ["work_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      deliverable_external_authorizations: {
        Row: {
          id: string
          work_item_id: string
          policy_id: string
          criteria_revision: number
          authority_stamp: string
          material_hash: string
          manifest_id: string
          manifest_hash: string
          authority_id: string
          authority_version: number
          actor_id: string
          official_reference: string
          reason: string
          expires_at: string
          recorded_at: string
        }
        Insert: {
          id?: string
          work_item_id: string
          policy_id: string
          criteria_revision: number
          authority_stamp: string
          material_hash: string
          manifest_id: string
          manifest_hash: string
          authority_id: string
          authority_version: number
          actor_id: string
          official_reference: string
          reason: string
          expires_at: string
          recorded_at?: string
        }
        Update: {
          id?: string
          work_item_id?: string
          policy_id?: string
          criteria_revision?: number
          authority_stamp?: string
          material_hash?: string
          manifest_id?: string
          manifest_hash?: string
          authority_id?: string
          authority_version?: number
          actor_id?: string
          official_reference?: string
          reason?: string
          expires_at?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_external_authorizatio_manifest_id_work_item_id_fkey"
            columns: ["manifest_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "deliverable_external_authorizations_authority_id_fkey"
            columns: ["authority_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_external_authorizations_policy_id_work_item_id_fkey"
            columns: ["policy_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverable_readiness_policies"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "deliverable_external_authorizations_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
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
      deliverable_readiness_events: {
        Row: {
          id: string
          sequence: number
          work_item_id: string
          kind: string
          policy_id: string
          criteria_revision: number
          fingerprint: string
          submission_id: string | null
          actor_id: string
          authority_id: string | null
          authority_version: number | null
          evidence: string
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          sequence: number
          work_item_id: string
          kind: string
          policy_id: string
          criteria_revision: number
          fingerprint: string
          submission_id?: string | null
          actor_id: string
          authority_id?: string | null
          authority_version?: number | null
          evidence: string
          reason: string
          recorded_at?: string
        }
        Update: {
          id?: string
          sequence?: number
          work_item_id?: string
          kind?: string
          policy_id?: string
          criteria_revision?: number
          fingerprint?: string
          submission_id?: string | null
          actor_id?: string
          authority_id?: string | null
          authority_version?: number | null
          evidence?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_readiness_events_authority_id_fkey"
            columns: ["authority_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_readiness_events_policy_id_work_item_id_fkey"
            columns: ["policy_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverable_readiness_policies"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "deliverable_readiness_events_submission_id_work_item_id_fkey"
            columns: ["submission_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverable_readiness_events"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "deliverable_readiness_events_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      deliverable_readiness_policies: {
        Row: {
          id: string
          work_item_id: string
          version: number
          acceptor_authority_id: string
          acceptor_authority_version: number
          external_required: boolean
          external_authority_id: string | null
          external_authority_version: number | null
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Insert: {
          id?: string
          work_item_id: string
          version: number
          acceptor_authority_id: string
          acceptor_authority_version: number
          external_required: boolean
          external_authority_id?: string | null
          external_authority_version?: number | null
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Update: {
          id?: string
          work_item_id?: string
          version?: number
          acceptor_authority_id?: string
          acceptor_authority_version?: number
          external_required?: boolean
          external_authority_id?: string | null
          external_authority_version?: number | null
          official_reference?: string
          confirmed_by?: string
          effective_from?: string
          effective_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_readiness_policies_acceptor_authority_id_fkey"
            columns: ["acceptor_authority_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_readiness_policies_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_readiness_policies_external_authority_id_fkey"
            columns: ["external_authority_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_readiness_policies_work_item_id_fkey"
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
      deliverable_scope_exceptions: {
        Row: {
          id: string
          work_item_id: string
          task_id: string
          task_version: number
          criteria_revision: number
          policy_id: string
          authority_id: string
          authority_version: number
          actor_id: string
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          work_item_id: string
          task_id: string
          task_version: number
          criteria_revision: number
          policy_id: string
          authority_id: string
          authority_version: number
          actor_id: string
          reason: string
          recorded_at?: string
        }
        Update: {
          id?: string
          work_item_id?: string
          task_id?: string
          task_version?: number
          criteria_revision?: number
          policy_id?: string
          authority_id?: string
          authority_version?: number
          actor_id?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "deliverable_scope_exceptions_authority_id_fkey"
            columns: ["authority_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "deliverable_scope_exceptions_policy_id_work_item_id_fkey"
            columns: ["policy_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverable_readiness_policies"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "deliverable_scope_exceptions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "deliverable_scope_exceptions_work_item_id_fkey"
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
          work_types: string[]
          finance_required: boolean
          publicity_required: boolean
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
          work_types?: string[]
          finance_required?: boolean
          publicity_required?: boolean
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
          work_types?: string[]
          finance_required?: boolean
          publicity_required?: boolean
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
      finance_authority_designations: {
        Row: {
          authority_id: string
          authority_version: number
          alternate_for_id: string | null
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Insert: {
          authority_id: string
          authority_version: number
          alternate_for_id?: string | null
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Update: {
          authority_id?: string
          authority_version?: number
          alternate_for_id?: string | null
          official_reference?: string
          confirmed_by?: string
          effective_from?: string
          effective_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_authority_designations_alternate_for_id_fkey"
            columns: ["alternate_for_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_authority_designations_authority_id_fkey"
            columns: ["authority_id"]
            isOneToOne: true
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_authority_designations_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_authorization_policies: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          request_type_id: string
          workflow_version_id: string
          version: number
          stage_key: string
          primary_authority_id: string
          external_requirement: string
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
          budget_account_id: string | null
          reconciliation_enabled: boolean
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          request_type_id: string
          workflow_version_id: string
          version: number
          stage_key: string
          primary_authority_id: string
          external_requirement: string
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
          budget_account_id?: string | null
          reconciliation_enabled?: boolean
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          request_type_id?: string
          workflow_version_id?: string
          version?: number
          stage_key?: string
          primary_authority_id?: string
          external_requirement?: string
          official_reference?: string
          confirmed_by?: string
          effective_from?: string
          effective_to?: string
          budget_account_id?: string | null
          reconciliation_enabled?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "finance_authorization_policie_organization_id_term_id_requ_fkey"
            columns: ["organization_id","term_id","request_type_id"]
            isOneToOne: false
            referencedRelation: "request_types"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "finance_authorization_policie_request_type_id_workflow_ver_fkey"
            columns: ["request_type_id","workflow_version_id"]
            isOneToOne: false
            referencedRelation: "workflow_versions"
            referencedColumns: ["request_type_id","id"]
          },
          {
            foreignKeyName: "finance_authorization_policies_budget_account_id_fkey"
            columns: ["budget_account_id"]
            isOneToOne: false
            referencedRelation: "budget_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_authorization_policies_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_authorization_policies_primary_authority_id_fkey"
            columns: ["primary_authority_id"]
            isOneToOne: false
            referencedRelation: "finance_authority_designations"
            referencedColumns: ["authority_id"]
          },
        ]
      }
      finance_case_metadata: {
        Row: {
          request_id: string
          contact_label: string
          updated_at: string
        }
        Insert: {
          request_id: string
          contact_label: string
          updated_at?: string
        }
        Update: {
          request_id?: string
          contact_label?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_case_metadata_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: true
            referencedRelation: "finance_cases"
            referencedColumns: ["request_id"]
          },
        ]
      }
      finance_cases: {
        Row: {
          request_id: string
          organization_id: string
          term_id: string
          created_by: string
          created_at: string
        }
        Insert: {
          request_id: string
          organization_id: string
          term_id: string
          created_by: string
          created_at?: string
        }
        Update: {
          request_id?: string
          organization_id?: string
          term_id?: string
          created_by?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_cases_organization_id_term_id_request_id_fkey"
            columns: ["organization_id","term_id","request_id"]
            isOneToOne: true
            referencedRelation: "requests"
            referencedColumns: ["organization_id","term_id","work_item_id"]
          },
        ]
      }
      finance_lines: {
        Row: {
          finance_revision_id: string
          line_no: number
          description: string
          quantity_milli: number
          unit_amount_centavos: number
          total_centavos: number
        }
        Insert: {
          finance_revision_id: string
          line_no: number
          description: string
          quantity_milli: number
          unit_amount_centavos: number
          total_centavos: number
        }
        Update: {
          finance_revision_id?: string
          line_no?: number
          description?: string
          quantity_milli?: number
          unit_amount_centavos?: number
          total_centavos?: number
        }
        Relationships: [
          {
            foreignKeyName: "finance_lines_finance_revision_id_fkey"
            columns: ["finance_revision_id"]
            isOneToOne: false
            referencedRelation: "finance_revisions"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_review_bindings: {
        Row: {
          assignment_id: string
          policy_id: string
        }
        Insert: {
          assignment_id: string
          policy_id: string
        }
        Update: {
          assignment_id?: string
          policy_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_review_bindings_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: true
            referencedRelation: "approval_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_review_bindings_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "finance_authorization_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_revisions: {
        Row: {
          id: string
          request_id: string
          organization_id: string
          term_id: string
          request_revision_id: string
          revision_no: number
          case_kind: string
          currency: string
          purpose: string
          fund_source: string
          beneficiary_member_id: string
          related_deliverable_id: string | null
          planned_on: string | null
          terms_risks: string
          requested_total_centavos: number
          unit_price_centavos: number | null
          forecast_quantity_milli: number | null
          forecast_revenue_centavos: number | null
          manifest_id: string | null
          manifest_hash: string
          payload_hash: string
          hash_version: string
          submitted_by: string
          submitted_at: string
        }
        Insert: {
          id?: string
          request_id: string
          organization_id: string
          term_id: string
          request_revision_id: string
          revision_no: number
          case_kind: string
          currency: string
          purpose: string
          fund_source: string
          beneficiary_member_id: string
          related_deliverable_id?: string | null
          planned_on?: string | null
          terms_risks: string
          requested_total_centavos: number
          unit_price_centavos?: number | null
          forecast_quantity_milli?: number | null
          forecast_revenue_centavos?: number | null
          manifest_id?: string | null
          manifest_hash: string
          payload_hash: string
          hash_version?: string
          submitted_by: string
          submitted_at?: string
        }
        Update: {
          id?: string
          request_id?: string
          organization_id?: string
          term_id?: string
          request_revision_id?: string
          revision_no?: number
          case_kind?: string
          currency?: string
          purpose?: string
          fund_source?: string
          beneficiary_member_id?: string
          related_deliverable_id?: string | null
          planned_on?: string | null
          terms_risks?: string
          requested_total_centavos?: number
          unit_price_centavos?: number | null
          forecast_quantity_milli?: number | null
          forecast_revenue_centavos?: number | null
          manifest_id?: string | null
          manifest_hash?: string
          payload_hash?: string
          hash_version?: string
          submitted_by?: string
          submitted_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_revisions_beneficiary_member_id_fkey"
            columns: ["beneficiary_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_revisions_manifest_id_request_id_fkey"
            columns: ["manifest_id","request_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "finance_revisions_organization_id_term_id_request_id_fkey"
            columns: ["organization_id","term_id","request_id"]
            isOneToOne: false
            referencedRelation: "finance_cases"
            referencedColumns: ["organization_id","term_id","request_id"]
          },
          {
            foreignKeyName: "finance_revisions_organization_id_term_id_request_id_reque_fkey"
            columns: ["organization_id","term_id","request_id","request_revision_id"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
          {
            foreignKeyName: "finance_revisions_related_deliverable_id_fkey"
            columns: ["related_deliverable_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "finance_revisions_request_id_request_revision_id_revision__fkey"
            columns: ["request_id","request_revision_id","revision_no"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["request_id","id","revision_no"]
          },
        ]
      }
      financial_authorization_events: {
        Row: {
          id: string
          authorization_id: string
          kind: string
          reason: string
          actor_id: string
          manifest_id: string | null
          recorded_at: string
        }
        Insert: {
          id?: string
          authorization_id: string
          kind: string
          reason: string
          actor_id: string
          manifest_id?: string | null
          recorded_at?: string
        }
        Update: {
          id?: string
          authorization_id?: string
          kind?: string
          reason?: string
          actor_id?: string
          manifest_id?: string | null
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "financial_authorization_events_authorization_id_fkey"
            columns: ["authorization_id"]
            isOneToOne: false
            referencedRelation: "financial_authorizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_authorization_events_manifest_id_fkey"
            columns: ["manifest_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id"]
          },
        ]
      }
      financial_authorizations: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          request_id: string
          finance_revision_id: string
          request_revision_id: string
          policy_id: string
          assignment_id: string
          decision_id: string
          payload_hash: string
          requested_total_centavos: number
          ceiling_centavos: number
          purpose: string
          conditions: string
          expires_at: string
          external_outcome: string
          external_manifest_id: string | null
          recorded_at: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          request_id: string
          finance_revision_id: string
          request_revision_id: string
          policy_id: string
          assignment_id: string
          decision_id: string
          payload_hash: string
          requested_total_centavos: number
          ceiling_centavos: number
          purpose: string
          conditions: string
          expires_at: string
          external_outcome: string
          external_manifest_id?: string | null
          recorded_at?: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          request_id?: string
          finance_revision_id?: string
          request_revision_id?: string
          policy_id?: string
          assignment_id?: string
          decision_id?: string
          payload_hash?: string
          requested_total_centavos?: number
          ceiling_centavos?: number
          purpose?: string
          conditions?: string
          expires_at?: string
          external_outcome?: string
          external_manifest_id?: string | null
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "financial_authorizations_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: true
            referencedRelation: "approval_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_authorizations_assignment_id_policy_id_fkey"
            columns: ["assignment_id","policy_id"]
            isOneToOne: true
            referencedRelation: "finance_review_bindings"
            referencedColumns: ["assignment_id","policy_id"]
          },
          {
            foreignKeyName: "financial_authorizations_decision_id_assignment_id_request_fkey"
            columns: ["decision_id","assignment_id","request_id","request_revision_id"]
            isOneToOne: true
            referencedRelation: "approval_decisions"
            referencedColumns: ["id","assignment_id","request_id","revision_id"]
          },
          {
            foreignKeyName: "financial_authorizations_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: true
            referencedRelation: "approval_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_authorizations_external_manifest_id_request_id_fkey"
            columns: ["external_manifest_id","request_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "financial_authorizations_finance_revision_id_fkey"
            columns: ["finance_revision_id"]
            isOneToOne: true
            referencedRelation: "finance_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "financial_authorizations_finance_revision_id_request_id_re_fkey"
            columns: ["finance_revision_id","request_id","request_revision_id","payload_hash"]
            isOneToOne: true
            referencedRelation: "finance_revisions"
            referencedColumns: ["id","request_id","request_revision_id","payload_hash"]
          },
          {
            foreignKeyName: "financial_authorizations_organization_id_term_id_request_i_fkey"
            columns: ["organization_id","term_id","request_id","request_revision_id"]
            isOneToOne: false
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
          {
            foreignKeyName: "financial_authorizations_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "finance_authorization_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      form_versions: {
        Row: {
          id: string
          request_type_id: string
          version: number
          state: string
          restricted: boolean
          schema_json: Json
          published_at: string | null
        }
        Insert: {
          id?: string
          request_type_id: string
          version: number
          state: string
          restricted?: boolean
          schema_json: Json
          published_at?: string | null
        }
        Update: {
          id?: string
          request_type_id?: string
          version?: number
          state?: string
          restricted?: boolean
          schema_json?: Json
          published_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "form_versions_request_type_id_fkey"
            columns: ["request_type_id"]
            isOneToOne: false
            referencedRelation: "request_types"
            referencedColumns: ["id"]
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
      handoff_decisions: {
        Row: {
          id: string
          handoff_id: string
          revision: number
          handoff_version: number
          action: string
          member_id: string
          reason: string
          actor_id: string
          recorded_at: string
        }
        Insert: {
          id?: string
          handoff_id: string
          revision: number
          handoff_version: number
          action: string
          member_id: string
          reason: string
          actor_id: string
          recorded_at?: string
        }
        Update: {
          id?: string
          handoff_id?: string
          revision?: number
          handoff_version?: number
          action?: string
          member_id?: string
          reason?: string
          actor_id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "handoff_decisions_handoff_id_revision_fkey"
            columns: ["handoff_id","revision"]
            isOneToOne: false
            referencedRelation: "handoff_revisions"
            referencedColumns: ["handoff_id","revision"]
          },
          {
            foreignKeyName: "handoff_decisions_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
      handoff_receipts: {
        Row: {
          id: string
          handoff_id: string
          revision: number
          receiver_member_id: string
          manifest_id: string
          manifest_sha256: string
          criteria: string
          next_task_id: string | null
          next_version: number | null
          notes: string
          actor_id: string
          accepted_at: string
        }
        Insert: {
          id?: string
          handoff_id: string
          revision: number
          receiver_member_id: string
          manifest_id: string
          manifest_sha256: string
          criteria: string
          next_task_id?: string | null
          next_version?: number | null
          notes: string
          actor_id: string
          accepted_at?: string
        }
        Update: {
          id?: string
          handoff_id?: string
          revision?: number
          receiver_member_id?: string
          manifest_id?: string
          manifest_sha256?: string
          criteria?: string
          next_task_id?: string | null
          next_version?: number | null
          notes?: string
          actor_id?: string
          accepted_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "handoff_receipts_handoff_id_revision_fkey"
            columns: ["handoff_id","revision"]
            isOneToOne: true
            referencedRelation: "handoff_revisions"
            referencedColumns: ["handoff_id","revision"]
          },
          {
            foreignKeyName: "handoff_receipts_manifest_id_fkey"
            columns: ["manifest_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "handoff_receipts_next_task_id_fkey"
            columns: ["next_task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "handoff_receipts_receiver_member_id_fkey"
            columns: ["receiver_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
        ]
      }
      handoff_revisions: {
        Row: {
          id: string
          handoff_id: string
          revision: number
          source_version: number
          next_version: number | null
          receiver_member_id: string
          receiver_unit_id: string
          manifest_id: string
          manifest_sha256: string
          files: Json
          output: string
          criteria: string
          due_on: string
          next_terms: Json | null
          reason: string
          created_by: string
          recorded_at: string
        }
        Insert: {
          id?: string
          handoff_id: string
          revision: number
          source_version: number
          next_version?: number | null
          receiver_member_id: string
          receiver_unit_id: string
          manifest_id: string
          manifest_sha256: string
          files: Json
          output: string
          criteria: string
          due_on: string
          next_terms?: Json | null
          reason: string
          created_by: string
          recorded_at?: string
        }
        Update: {
          id?: string
          handoff_id?: string
          revision?: number
          source_version?: number
          next_version?: number | null
          receiver_member_id?: string
          receiver_unit_id?: string
          manifest_id?: string
          manifest_sha256?: string
          files?: Json
          output?: string
          criteria?: string
          due_on?: string
          next_terms?: Json | null
          reason?: string
          created_by?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "handoff_revisions_handoff_id_fkey"
            columns: ["handoff_id"]
            isOneToOne: false
            referencedRelation: "handoffs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "handoff_revisions_manifest_id_fkey"
            columns: ["manifest_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "handoff_revisions_receiver_member_id_fkey"
            columns: ["receiver_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "handoff_revisions_receiver_unit_id_fkey"
            columns: ["receiver_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
        ]
      }
      handoffs: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          source_task_id: string
          next_task_id: string | null
          sender_member_id: string
          receiver_member_id: string
          receiver_unit_id: string
          version: number
          current_revision: number
          state: string
          created_by: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          source_task_id: string
          next_task_id?: string | null
          sender_member_id: string
          receiver_member_id: string
          receiver_unit_id: string
          version?: number
          current_revision?: number
          state?: string
          created_by: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          source_task_id?: string
          next_task_id?: string | null
          sender_member_id?: string
          receiver_member_id?: string
          receiver_unit_id?: string
          version?: number
          current_revision?: number
          state?: string
          created_by?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "handoff_current_revision"
            columns: ["id","current_revision"]
            isOneToOne: true
            referencedRelation: "handoff_revisions"
            referencedColumns: ["handoff_id","revision"]
          },
          {
            foreignKeyName: "handoffs_next_task_id_fkey"
            columns: ["next_task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "handoffs_organization_id_term_id_next_task_id_fkey"
            columns: ["organization_id","term_id","next_task_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "handoffs_organization_id_term_id_receiver_unit_id_fkey"
            columns: ["organization_id","term_id","receiver_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "handoffs_organization_id_term_id_source_task_id_fkey"
            columns: ["organization_id","term_id","source_task_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "handoffs_receiver_member_id_fkey"
            columns: ["receiver_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "handoffs_sender_member_id_fkey"
            columns: ["sender_member_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "handoffs_source_task_id_fkey"
            columns: ["source_task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
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
      notification_preferences: {
        Row: {
          membership_id: string
          mode: string
          version: number
          updated_at: string
        }
        Insert: {
          membership_id: string
          mode?: string
          version?: number
          updated_at?: string
        }
        Update: {
          membership_id?: string
          mode?: string
          version?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_preferences_membership_id_fkey"
            columns: ["membership_id"]
            isOneToOne: true
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          id: string
          job_id: string
          recipient_id: string
          target_kind: string
          target_id: string
          read_at: string | null
          version: number
          created_at: string
        }
        Insert: {
          id?: string
          job_id: string
          recipient_id: string
          target_kind: string
          target_id: string
          read_at?: string | null
          version?: number
          created_at?: string
        }
        Update: {
          id?: string
          job_id?: string
          recipient_id?: string
          target_kind?: string
          target_id?: string
          read_at?: string | null
          version?: number
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_job_id_fkey"
            columns: ["job_id"]
            isOneToOne: false
            referencedRelation: "outbox_jobs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_progress: {
        Row: {
          term_membership_id: string
          item: string
          revision: number
          state: string
          version: number
          updated_at: string
        }
        Insert: {
          term_membership_id: string
          item: string
          revision: number
          state: string
          version: number
          updated_at?: string
        }
        Update: {
          term_membership_id?: string
          item?: string
          revision?: number
          state?: string
          version?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "onboarding_progress_term_membership_id_fkey"
            columns: ["term_membership_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
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
      organization_changes: {
        Row: {
          control_id: string
          version: number
          action: string
          target_id: string | null
          metadata: Json
          actor_id: string
          reason: string
          created_at: string
        }
        Insert: {
          control_id: string
          version: number
          action: string
          target_id?: string | null
          metadata: Json
          actor_id: string
          reason: string
          created_at?: string
        }
        Update: {
          control_id?: string
          version?: number
          action?: string
          target_id?: string | null
          metadata?: Json
          actor_id?: string
          reason?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_changes_control_id_fkey"
            columns: ["control_id"]
            isOneToOne: false
            referencedRelation: "organization_control"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      organization_control: {
        Row: {
          term_id: string
          work_item_id: string
        }
        Insert: {
          term_id: string
          work_item_id: string
        }
        Update: {
          term_id?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_control_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: true
            referencedRelation: "terms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_control_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "announcements"
            referencedColumns: ["work_item_id"]
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
          event_id: string | null
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
          lease_token: string | null
          lease_until: string | null
          last_error: string | null
          delivered_at: string | null
          dispatch_version: number
          reminder_key: string | null
        }
        Insert: {
          id?: string
          event_id?: string | null
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
          lease_token?: string | null
          lease_until?: string | null
          last_error?: string | null
          delivered_at?: string | null
          dispatch_version?: number
          reminder_key?: string | null
        }
        Update: {
          id?: string
          event_id?: string | null
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
          lease_token?: string | null
          lease_until?: string | null
          last_error?: string | null
          delivered_at?: string | null
          dispatch_version?: number
          reminder_key?: string | null
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
      publicity_approval_events: {
        Row: {
          id: string
          approval_id: string
          reason: string
          actor_id: string
          recorded_at: string
        }
        Insert: {
          id?: string
          approval_id: string
          reason: string
          actor_id: string
          recorded_at?: string
        }
        Update: {
          id?: string
          approval_id?: string
          reason?: string
          actor_id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "publicity_approval_events_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "publicity_approvals"
            referencedColumns: ["id"]
          },
        ]
      }
      publicity_approvals: {
        Row: {
          id: string
          publicity_review_id: string
          request_id: string
          request_revision_id: string
          payload_hash: string
          decision_id: string
          assignment_id: string
          policy_id: string
          conditions: string
          expires_at: string
          recorded_at: string
        }
        Insert: {
          id?: string
          publicity_review_id: string
          request_id: string
          request_revision_id: string
          payload_hash: string
          decision_id: string
          assignment_id: string
          policy_id: string
          conditions: string
          expires_at: string
          recorded_at?: string
        }
        Update: {
          id?: string
          publicity_review_id?: string
          request_id?: string
          request_revision_id?: string
          payload_hash?: string
          decision_id?: string
          assignment_id?: string
          policy_id?: string
          conditions?: string
          expires_at?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "publicity_approvals_assignment_id_policy_id_fkey"
            columns: ["assignment_id","policy_id"]
            isOneToOne: true
            referencedRelation: "publicity_review_bindings"
            referencedColumns: ["assignment_id","policy_id"]
          },
          {
            foreignKeyName: "publicity_approvals_decision_id_assignment_id_request_id_r_fkey"
            columns: ["decision_id","assignment_id","request_id","request_revision_id"]
            isOneToOne: true
            referencedRelation: "approval_decisions"
            referencedColumns: ["id","assignment_id","request_id","revision_id"]
          },
          {
            foreignKeyName: "publicity_approvals_publicity_review_id_request_id_request_fkey"
            columns: ["publicity_review_id","request_id","request_revision_id","payload_hash"]
            isOneToOne: true
            referencedRelation: "publicity_reviews"
            referencedColumns: ["id","request_id","request_revision_id","payload_hash"]
          },
        ]
      }
      publicity_authority_designations: {
        Row: {
          authority_id: string
          authority_version: number
          alternate_for_id: string | null
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Insert: {
          authority_id: string
          authority_version: number
          alternate_for_id?: string | null
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Update: {
          authority_id?: string
          authority_version?: number
          alternate_for_id?: string | null
          official_reference?: string
          confirmed_by?: string
          effective_from?: string
          effective_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "publicity_authority_designations_alternate_for_id_fkey"
            columns: ["alternate_for_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "publicity_authority_designations_authority_id_fkey"
            columns: ["authority_id"]
            isOneToOne: true
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "publicity_authority_designations_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      publicity_review_bindings: {
        Row: {
          assignment_id: string
          policy_id: string
        }
        Insert: {
          assignment_id: string
          policy_id: string
        }
        Update: {
          assignment_id?: string
          policy_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "publicity_review_bindings_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: true
            referencedRelation: "approval_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "publicity_review_bindings_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "publicity_review_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      publicity_review_policies: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          request_type_id: string
          workflow_version_id: string
          version: number
          stage_key: string
          primary_authority_id: string
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          request_type_id: string
          workflow_version_id: string
          version: number
          stage_key: string
          primary_authority_id: string
          official_reference: string
          confirmed_by: string
          effective_from: string
          effective_to: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          request_type_id?: string
          workflow_version_id?: string
          version?: number
          stage_key?: string
          primary_authority_id?: string
          official_reference?: string
          confirmed_by?: string
          effective_from?: string
          effective_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "publicity_review_policies_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "publicity_review_policies_organization_id_term_id_request__fkey"
            columns: ["organization_id","term_id","request_type_id"]
            isOneToOne: false
            referencedRelation: "request_types"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "publicity_review_policies_primary_authority_id_fkey"
            columns: ["primary_authority_id"]
            isOneToOne: false
            referencedRelation: "publicity_authority_designations"
            referencedColumns: ["authority_id"]
          },
          {
            foreignKeyName: "publicity_review_policies_request_type_id_workflow_version_fkey"
            columns: ["request_type_id","workflow_version_id"]
            isOneToOne: false
            referencedRelation: "workflow_versions"
            referencedColumns: ["request_type_id","id"]
          },
        ]
      }
      publicity_reviews: {
        Row: {
          id: string
          request_id: string
          term_id: string
          request_revision_id: string
          revision_no: number
          manifest_id: string
          manifest_hash: string
          payload: Json
          payload_hash: string
          related_deliverable_id: string
          finance_revision_id: string | null
          submitted_by: string
        }
        Insert: {
          id?: string
          request_id: string
          term_id: string
          request_revision_id: string
          revision_no: number
          manifest_id: string
          manifest_hash: string
          payload: Json
          payload_hash: string
          related_deliverable_id: string
          finance_revision_id?: string | null
          submitted_by: string
        }
        Update: {
          id?: string
          request_id?: string
          term_id?: string
          request_revision_id?: string
          revision_no?: number
          manifest_id?: string
          manifest_hash?: string
          payload?: Json
          payload_hash?: string
          related_deliverable_id?: string
          finance_revision_id?: string | null
          submitted_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "publicity_reviews_finance_revision_id_fkey"
            columns: ["finance_revision_id"]
            isOneToOne: false
            referencedRelation: "finance_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "publicity_reviews_manifest_id_request_id_fkey"
            columns: ["manifest_id","request_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "publicity_reviews_related_deliverable_id_fkey"
            columns: ["related_deliverable_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "publicity_reviews_request_id_request_revision_id_revision__fkey"
            columns: ["request_id","request_revision_id","revision_no"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["request_id","id","revision_no"]
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
      request_assignment_shells: {
        Row: {
          id: string
          instance_id: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          stage_key: string
          review_mode: string
          configured_member_id: string | null
          state: string
        }
        Insert: {
          id?: string
          instance_id: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          stage_key: string
          review_mode: string
          configured_member_id?: string | null
          state?: string
        }
        Update: {
          id?: string
          instance_id?: string
          request_id?: string
          revision_id?: string
          organization_id?: string
          term_id?: string
          stage_key?: string
          review_mode?: string
          configured_member_id?: string | null
          state?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_assignment_shells_organization_id_term_id_configur_fkey"
            columns: ["organization_id","term_id","configured_member_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "request_assignment_shells_organization_id_term_id_request__fkey"
            columns: ["organization_id","term_id","request_id","revision_id","instance_id"]
            isOneToOne: false
            referencedRelation: "workflow_instances"
            referencedColumns: ["organization_id","term_id","request_id","revision_id","id"]
          },
        ]
      }
      request_drafts: {
        Row: {
          request_id: string
          organization_id: string
          term_id: string
          choice_snapshots: Json
          payload_json: Json
          requested_centavos: number | null
          requested_on: string | null
        }
        Insert: {
          request_id: string
          organization_id: string
          term_id: string
          choice_snapshots?: Json
          payload_json?: Json
          requested_centavos?: number | null
          requested_on?: string | null
        }
        Update: {
          request_id?: string
          organization_id?: string
          term_id?: string
          choice_snapshots?: Json
          payload_json?: Json
          requested_centavos?: number | null
          requested_on?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "request_drafts_organization_id_term_id_request_id_fkey"
            columns: ["organization_id","term_id","request_id"]
            isOneToOne: true
            referencedRelation: "requests"
            referencedColumns: ["organization_id","term_id","work_item_id"]
          },
        ]
      }
      request_events: {
        Row: {
          id: string
          request_id: string
          organization_id: string
          term_id: string
          revision_no: number
          action: string
          actor_name: string
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          request_id: string
          organization_id: string
          term_id: string
          revision_no: number
          action: string
          actor_name: string
          reason?: string
          recorded_at?: string
        }
        Update: {
          id?: string
          request_id?: string
          organization_id?: string
          term_id?: string
          revision_no?: number
          action?: string
          actor_name?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_events_organization_id_term_id_request_id_fkey"
            columns: ["organization_id","term_id","request_id"]
            isOneToOne: false
            referencedRelation: "requests"
            referencedColumns: ["organization_id","term_id","work_item_id"]
          },
        ]
      }
      request_finance_values: {
        Row: {
          revision_id: string
          request_id: string
          organization_id: string
          term_id: string
          requested_centavos: number
        }
        Insert: {
          revision_id: string
          request_id: string
          organization_id: string
          term_id: string
          requested_centavos: number
        }
        Update: {
          revision_id?: string
          request_id?: string
          organization_id?: string
          term_id?: string
          requested_centavos?: number
        }
        Relationships: [
          {
            foreignKeyName: "request_finance_values_organization_id_term_id_request_id__fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
        ]
      }
      request_revisions: {
        Row: {
          id: string
          request_id: string
          organization_id: string
          term_id: string
          revision_no: number
          form_version_id: string
          workflow_version_id: string
          title_snapshot: string
          ordinary_payload_json: Json | null
          choice_snapshots: Json
          payload_classification: string
          manifest_id: string | null
          manifest_hash: string
          requested_on: string | null
          submitted_at: string
          submitted_by: string
        }
        Insert: {
          id?: string
          request_id: string
          organization_id: string
          term_id: string
          revision_no: number
          form_version_id: string
          workflow_version_id: string
          title_snapshot: string
          ordinary_payload_json?: Json | null
          choice_snapshots: Json
          payload_classification: string
          manifest_id?: string | null
          manifest_hash: string
          requested_on?: string | null
          submitted_at?: string
          submitted_by: string
        }
        Update: {
          id?: string
          request_id?: string
          organization_id?: string
          term_id?: string
          revision_no?: number
          form_version_id?: string
          workflow_version_id?: string
          title_snapshot?: string
          ordinary_payload_json?: Json | null
          choice_snapshots?: Json
          payload_classification?: string
          manifest_id?: string | null
          manifest_hash?: string
          requested_on?: string | null
          submitted_at?: string
          submitted_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_revisions_manifest_id_request_id_fkey"
            columns: ["manifest_id","request_id"]
            isOneToOne: false
            referencedRelation: "asset_manifests"
            referencedColumns: ["id","work_item_id"]
          },
          {
            foreignKeyName: "request_revisions_organization_id_term_id_request_id_fkey"
            columns: ["organization_id","term_id","request_id"]
            isOneToOne: false
            referencedRelation: "requests"
            referencedColumns: ["organization_id","term_id","work_item_id"]
          },
          {
            foreignKeyName: "request_revisions_request_id_form_version_id_workflow_vers_fkey"
            columns: ["request_id","form_version_id","workflow_version_id"]
            isOneToOne: false
            referencedRelation: "requests"
            referencedColumns: ["work_item_id","form_version_id","workflow_version_id"]
          },
        ]
      }
      request_triage_events: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          request_id: string
          revision_id: string
          kind: string
          note: string
          accepted_on: string | null
          actor_name: string
          recorded_at: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          request_id: string
          revision_id: string
          kind: string
          note: string
          accepted_on?: string | null
          actor_name: string
          recorded_at?: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          request_id?: string
          revision_id?: string
          kind?: string
          note?: string
          accepted_on?: string | null
          actor_name?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_triage_events_organization_id_term_id_request_id_r_fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: false
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
        ]
      }
      request_types: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          stable_key: string
          label: string
          need: string
          governed_kind: string
          payload_classification: string
          form_version_id: string | null
          workflow_version_id: string | null
          receiving_unit_id: string | null
          primary_contact_id: string | null
          backup_contact_id: string | null
          guest_eligible: boolean
          authority_confirmed: boolean
          live_enabled: boolean
          lead_time_days: number | null
          official_url: string | null
          process_note: string
          archived_at: string | null
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          stable_key: string
          label: string
          need: string
          governed_kind: string
          payload_classification?: string
          form_version_id?: string | null
          workflow_version_id?: string | null
          receiving_unit_id?: string | null
          primary_contact_id?: string | null
          backup_contact_id?: string | null
          guest_eligible?: boolean
          authority_confirmed?: boolean
          live_enabled?: boolean
          lead_time_days?: number | null
          official_url?: string | null
          process_note: string
          archived_at?: string | null
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          stable_key?: string
          label?: string
          need?: string
          governed_kind?: string
          payload_classification?: string
          form_version_id?: string | null
          workflow_version_id?: string | null
          receiving_unit_id?: string | null
          primary_contact_id?: string | null
          backup_contact_id?: string | null
          guest_eligible?: boolean
          authority_confirmed?: boolean
          live_enabled?: boolean
          lead_time_days?: number | null
          official_url?: string | null
          process_note?: string
          archived_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "request_types_id_form_version_id_fkey"
            columns: ["id","form_version_id"]
            isOneToOne: true
            referencedRelation: "form_versions"
            referencedColumns: ["request_type_id","id"]
          },
          {
            foreignKeyName: "request_types_id_workflow_version_id_fkey"
            columns: ["id","workflow_version_id"]
            isOneToOne: true
            referencedRelation: "workflow_versions"
            referencedColumns: ["request_type_id","id"]
          },
          {
            foreignKeyName: "request_types_organization_id_term_id_backup_contact_id_fkey"
            columns: ["organization_id","term_id","backup_contact_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "request_types_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
          {
            foreignKeyName: "request_types_organization_id_term_id_primary_contact_id_fkey"
            columns: ["organization_id","term_id","primary_contact_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "request_types_organization_id_term_id_receiving_unit_id_fkey"
            columns: ["organization_id","term_id","receiving_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
        ]
      }
      request_workflow_events: {
        Row: {
          id: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          stage_key: string
          generation: number
          action: string
          actor_name: string
          reason: string
          recorded_at: string
        }
        Insert: {
          id?: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          stage_key: string
          generation: number
          action: string
          actor_name: string
          reason: string
          recorded_at?: string
        }
        Update: {
          id?: string
          request_id?: string
          revision_id?: string
          organization_id?: string
          term_id?: string
          stage_key?: string
          generation?: number
          action?: string
          actor_name?: string
          reason?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_workflow_events_organization_id_term_id_request_id_fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: false
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
        ]
      }
      request_workflow_outcomes: {
        Row: {
          id: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          decision_id: string
          category: string
          recorded_at: string
        }
        Insert: {
          id?: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          decision_id: string
          category: string
          recorded_at?: string
        }
        Update: {
          id?: string
          request_id?: string
          revision_id?: string
          organization_id?: string
          term_id?: string
          decision_id?: string
          category?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_workflow_outcomes_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: true
            referencedRelation: "approval_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "request_workflow_outcomes_organization_id_term_id_request__fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: false
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
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
          request_type_id: string | null
          form_version_id: string | null
          workflow_version_id: string | null
          receiving_unit_id: string | null
          type_label: string | null
          service_label: string | null
          payload_classification: string | null
          request_state: string
          current_revision: number
          current_revision_id: string | null
          tracking_counter_id: string | null
          tracking_prefix_snapshot: string | null
          sequence_no: number | null
          tracking_id: string | null
          original_requested_on: string | null
          accepted_on: string | null
          revision_resume_stage_key: string | null
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
          request_type_id?: string | null
          form_version_id?: string | null
          workflow_version_id?: string | null
          receiving_unit_id?: string | null
          type_label?: string | null
          service_label?: string | null
          payload_classification?: string | null
          request_state?: string
          current_revision?: number
          current_revision_id?: string | null
          tracking_counter_id?: string | null
          tracking_prefix_snapshot?: string | null
          sequence_no?: number | null
          tracking_id?: string | null
          original_requested_on?: string | null
          accepted_on?: string | null
          revision_resume_stage_key?: string | null
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
          request_type_id?: string | null
          form_version_id?: string | null
          workflow_version_id?: string | null
          receiving_unit_id?: string | null
          type_label?: string | null
          service_label?: string | null
          payload_classification?: string | null
          request_state?: string
          current_revision?: number
          current_revision_id?: string | null
          tracking_counter_id?: string | null
          tracking_prefix_snapshot?: string | null
          sequence_no?: number | null
          tracking_id?: string | null
          original_requested_on?: string | null
          accepted_on?: string | null
          revision_resume_stage_key?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "requests_organization_id_term_id_receiving_unit_id_fkey"
            columns: ["organization_id","term_id","receiving_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "requests_organization_id_term_id_request_type_id_fkey"
            columns: ["organization_id","term_id","request_type_id"]
            isOneToOne: false
            referencedRelation: "request_types"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "requests_organization_id_term_id_tracking_counter_id_fkey"
            columns: ["organization_id","term_id","tracking_counter_id"]
            isOneToOne: false
            referencedRelation: "tracking_counters"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "requests_organization_id_term_id_work_item_id_kind_fkey"
            columns: ["organization_id","term_id","work_item_id","kind"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id","kind"]
          },
          {
            foreignKeyName: "requests_request_type_id_form_version_id_fkey"
            columns: ["request_type_id","form_version_id"]
            isOneToOne: false
            referencedRelation: "form_versions"
            referencedColumns: ["request_type_id","id"]
          },
          {
            foreignKeyName: "requests_request_type_id_workflow_version_id_fkey"
            columns: ["request_type_id","workflow_version_id"]
            isOneToOne: false
            referencedRelation: "workflow_versions"
            referencedColumns: ["request_type_id","id"]
          },
          {
            foreignKeyName: "requests_tracking_counter_id_term_id_tracking_prefix_snaps_fkey"
            columns: ["tracking_counter_id","term_id","tracking_prefix_snapshot"]
            isOneToOne: false
            referencedRelation: "tracking_counters"
            referencedColumns: ["id","term_id","prefix"]
          },
          {
            foreignKeyName: "requests_work_item_id_current_revision_id_current_revision_fkey"
            columns: ["work_item_id","current_revision_id","current_revision"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["request_id","id","revision_no"]
          },
        ]
      }
      resource_aliases: {
        Row: {
          term_id: string
          alias: string
          resource_id: string
        }
        Insert: {
          term_id: string
          alias: string
          resource_id: string
        }
        Update: {
          term_id?: string
          alias?: string
          resource_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_aliases_resource_id_fkey"
            columns: ["resource_id"]
            isOneToOne: false
            referencedRelation: "resources"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "resource_aliases_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_versions: {
        Row: {
          resource_id: string
          version: number
          label: string
          body: string
          alias: string
          owner_id: string
          review_on: string
          service_id: string | null
          targets: Json
          published: boolean
          actor_id: string
          created_at: string
        }
        Insert: {
          resource_id: string
          version: number
          label: string
          body: string
          alias: string
          owner_id: string
          review_on: string
          service_id?: string | null
          targets: Json
          published: boolean
          actor_id: string
          created_at?: string
        }
        Update: {
          resource_id?: string
          version?: number
          label?: string
          body?: string
          alias?: string
          owner_id?: string
          review_on?: string
          service_id?: string | null
          targets?: Json
          published?: boolean
          actor_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "resource_versions_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_versions_resource_id_fkey"
            columns: ["resource_id"]
            isOneToOne: false
            referencedRelation: "resources"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "resource_versions_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
        ]
      }
      resources: {
        Row: {
          work_item_id: string
          visibility: string
          published_version: number | null
          kind: string
          essential: boolean
        }
        Insert: {
          work_item_id: string
          visibility: string
          published_version?: number | null
          kind: string
          essential?: boolean
        }
        Update: {
          work_item_id?: string
          visibility?: string
          published_version?: number | null
          kind?: string
          essential?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "resources_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "announcements"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "resources_work_item_id_published_version_fkey"
            columns: ["work_item_id","published_version"]
            isOneToOne: true
            referencedRelation: "resource_versions"
            referencedColumns: ["resource_id","version"]
          },
        ]
      }
      restricted_request_payloads: {
        Row: {
          revision_id: string
          request_id: string
          organization_id: string
          term_id: string
          payload_json: Json
        }
        Insert: {
          revision_id: string
          request_id: string
          organization_id: string
          term_id: string
          payload_json: Json
        }
        Update: {
          revision_id?: string
          request_id?: string
          organization_id?: string
          term_id?: string
          payload_json?: Json
        }
        Relationships: [
          {
            foreignKeyName: "restricted_request_payloads_organization_id_term_id_reques_fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
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
      synergy_agreements: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          parent_work_item_id: string
          requester_unit_id: string
          receiver_unit_id: string
          requester_member_id: string
          version: number
          current_revision: number
          active_revision: number | null
          state: string
          created_by: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          parent_work_item_id: string
          requester_unit_id: string
          receiver_unit_id: string
          requester_member_id: string
          version?: number
          current_revision?: number
          active_revision?: number | null
          state?: string
          created_by: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          parent_work_item_id?: string
          requester_unit_id?: string
          receiver_unit_id?: string
          requester_member_id?: string
          version?: number
          current_revision?: number
          active_revision?: number | null
          state?: string
          created_by?: string
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "synergy_active_revision"
            columns: ["id","active_revision"]
            isOneToOne: true
            referencedRelation: "agreement_revisions"
            referencedColumns: ["agreement_id","revision"]
          },
          {
            foreignKeyName: "synergy_agreements_organization_id_term_id_parent_work_ite_fkey"
            columns: ["organization_id","term_id","parent_work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "synergy_agreements_organization_id_term_id_receiver_unit_i_fkey"
            columns: ["organization_id","term_id","receiver_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "synergy_agreements_organization_id_term_id_requester_membe_fkey"
            columns: ["organization_id","term_id","requester_member_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","member_id"]
          },
          {
            foreignKeyName: "synergy_agreements_organization_id_term_id_requester_unit__fkey"
            columns: ["organization_id","term_id","requester_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "synergy_agreements_parent_work_item_id_fkey"
            columns: ["parent_work_item_id"]
            isOneToOne: false
            referencedRelation: "deliverables"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "synergy_current_revision"
            columns: ["id","current_revision"]
            isOneToOne: true
            referencedRelation: "agreement_revisions"
            referencedColumns: ["agreement_id","revision"]
          },
        ]
      }
      task_collaborators: {
        Row: {
          organization_id: string
          term_id: string
          work_item_id: string
          member_id: string
        }
        Insert: {
          organization_id: string
          term_id: string
          work_item_id: string
          member_id: string
        }
        Update: {
          organization_id?: string
          term_id?: string
          work_item_id?: string
          member_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_collaborators_organization_id_term_id_member_id_fkey"
            columns: ["organization_id","term_id","member_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","member_id"]
          },
          {
            foreignKeyName: "task_collaborators_organization_id_term_id_work_item_id_fkey"
            columns: ["organization_id","term_id","work_item_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "task_collaborators_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      task_dependencies: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          predecessor_task_id: string
          successor_task_id: string
          dependency_type: string
          required: boolean
          created_by: string
          created_at: string
          removed_at: string | null
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          predecessor_task_id: string
          successor_task_id: string
          dependency_type: string
          required: boolean
          created_by: string
          created_at?: string
          removed_at?: string | null
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          predecessor_task_id?: string
          successor_task_id?: string
          dependency_type?: string
          required?: boolean
          created_by?: string
          created_at?: string
          removed_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "task_dependencies_organization_id_term_id_predecessor_task_fkey"
            columns: ["organization_id","term_id","predecessor_task_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "task_dependencies_organization_id_term_id_successor_task_i_fkey"
            columns: ["organization_id","term_id","successor_task_id"]
            isOneToOne: false
            referencedRelation: "work_items"
            referencedColumns: ["organization_id","term_id","id"]
          },
          {
            foreignKeyName: "task_dependencies_predecessor_task_id_fkey"
            columns: ["predecessor_task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
          {
            foreignKeyName: "task_dependencies_successor_task_id_fkey"
            columns: ["successor_task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
          },
        ]
      }
      task_dependency_events: {
        Row: {
          id: string
          dependency_id: string
          operation: string
          reason: string
          actor_id: string
          recorded_at: string
        }
        Insert: {
          id?: string
          dependency_id: string
          operation: string
          reason: string
          actor_id: string
          recorded_at?: string
        }
        Update: {
          id?: string
          dependency_id?: string
          operation?: string
          reason?: string
          actor_id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_dependency_events_dependency_id_fkey"
            columns: ["dependency_id"]
            isOneToOne: false
            referencedRelation: "task_dependencies"
            referencedColumns: ["id"]
          },
        ]
      }
      task_revisions: {
        Row: {
          work_item_id: string
          work_version: number
          state: string
          assignee_id: string | null
          assignee_name: string | null
          assigned_unit_id: string | null
          collaborators: Json
          title: string
          due_on: string | null
          due_at: string | null
          body: string
          checklist: Json
          evidence: string | null
          reason: string
          actor_id: string
          recorded_at: string
        }
        Insert: {
          work_item_id: string
          work_version: number
          state: string
          assignee_id?: string | null
          assignee_name?: string | null
          assigned_unit_id?: string | null
          collaborators: Json
          title: string
          due_on?: string | null
          due_at?: string | null
          body: string
          checklist: Json
          evidence?: string | null
          reason: string
          actor_id: string
          recorded_at?: string
        }
        Update: {
          work_item_id?: string
          work_version?: number
          state?: string
          assignee_id?: string | null
          assignee_name?: string | null
          assigned_unit_id?: string | null
          collaborators?: Json
          title?: string
          due_on?: string | null
          due_at?: string | null
          body?: string
          checklist?: Json
          evidence?: string | null
          reason?: string
          actor_id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_revisions_assigned_unit_id_fkey"
            columns: ["assigned_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_revisions_assignee_id_fkey"
            columns: ["assignee_id"]
            isOneToOne: false
            referencedRelation: "members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_revisions_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["work_item_id"]
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
          assignee_id: string | null
          assigned_unit_id: string | null
          workflow_state: string
          checklist: Json
          task_type: string
          blocked_reason: string | null
          completion_evidence: string | null
          assignee_name: string | null
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
          assignee_id?: string | null
          assigned_unit_id?: string | null
          workflow_state?: string
          checklist?: Json
          task_type?: string
          blocked_reason?: string | null
          completion_evidence?: string | null
          assignee_name?: string | null
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
          assignee_id?: string | null
          assigned_unit_id?: string | null
          workflow_state?: string
          checklist?: Json
          task_type?: string
          blocked_reason?: string | null
          completion_evidence?: string | null
          assignee_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "task_assignee_term"
            columns: ["organization_id","term_id","assignee_id"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["organization_id","term_id","member_id"]
          },
          {
            foreignKeyName: "task_unit_term"
            columns: ["organization_id","term_id","assigned_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["organization_id","term_id","id"]
          },
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
      tracking_counters: {
        Row: {
          id: string
          organization_id: string
          term_id: string
          namespace_key: string
          prefix: string
          next_value: number
        }
        Insert: {
          id?: string
          organization_id: string
          term_id: string
          namespace_key: string
          prefix: string
          next_value: number
        }
        Update: {
          id?: string
          organization_id?: string
          term_id?: string
          namespace_key?: string
          prefix?: string
          next_value?: number
        }
        Relationships: [
          {
            foreignKeyName: "tracking_counters_organization_id_term_id_fkey"
            columns: ["organization_id","term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["organization_id","id"]
          },
        ]
      }
      unit_aliases: {
        Row: {
          term_id: string
          alias: string
          unit_id: string
        }
        Insert: {
          term_id: string
          alias: string
          unit_id: string
        }
        Update: {
          term_id?: string
          alias?: string
          unit_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "unit_aliases_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: false
            referencedRelation: "terms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "unit_aliases_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
        ]
      }
      unit_links: {
        Row: {
          source_unit_id: string
          target_unit_id: string
          created_at: string
        }
        Insert: {
          source_unit_id: string
          target_unit_id: string
          created_at?: string
        }
        Update: {
          source_unit_id?: string
          target_unit_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "unit_links_source_unit_id_fkey"
            columns: ["source_unit_id"]
            isOneToOne: true
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "unit_links_target_unit_id_fkey"
            columns: ["target_unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
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
      verified_app_custodians: {
        Row: {
          assignment_id: string
          assignment_version: number
          role_version: number
          verified_by: string
          verification_reference: string
          verified_at: string
          effective_to: string
          revoked_at: string | null
        }
        Insert: {
          assignment_id: string
          assignment_version: number
          role_version: number
          verified_by: string
          verification_reference: string
          verified_at: string
          effective_to: string
          revoked_at?: string | null
        }
        Update: {
          assignment_id?: string
          assignment_version?: number
          role_version?: number
          verified_by?: string
          verification_reference?: string
          verified_at?: string
          effective_to?: string
          revoked_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verified_app_custodians_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: true
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verified_app_custodians_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "term_memberships"
            referencedColumns: ["id"]
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
          planned_start_on: string | null
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
          planned_start_on?: string | null
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
          planned_start_on?: string | null
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
      work_unit_origins: {
        Row: {
          work_item_id: string
          unit_id: string | null
        }
        Insert: {
          work_item_id: string
          unit_id?: string | null
        }
        Update: {
          work_item_id?: string
          unit_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "work_unit_origins_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "org_units"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "work_unit_origins_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      workflow_instances: {
        Row: {
          id: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          workflow_version_id: string
          current_stage_key: string
          state: string
          pause_reason: string
          generation: number
          review_context_id: string
        }
        Insert: {
          id?: string
          request_id: string
          revision_id: string
          organization_id: string
          term_id: string
          workflow_version_id: string
          current_stage_key: string
          state?: string
          pause_reason?: string
          generation?: number
          review_context_id?: string
        }
        Update: {
          id?: string
          request_id?: string
          revision_id?: string
          organization_id?: string
          term_id?: string
          workflow_version_id?: string
          current_stage_key?: string
          state?: string
          pause_reason?: string
          generation?: number
          review_context_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workflow_instances_organization_id_term_id_request_id_revi_fkey"
            columns: ["organization_id","term_id","request_id","revision_id"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["organization_id","term_id","request_id","id"]
          },
          {
            foreignKeyName: "workflow_instances_request_id_revision_id_workflow_version_fkey"
            columns: ["request_id","revision_id","workflow_version_id"]
            isOneToOne: true
            referencedRelation: "request_revisions"
            referencedColumns: ["request_id","id","workflow_version_id"]
          },
          {
            foreignKeyName: "workflow_instances_workflow_version_id_fkey"
            columns: ["workflow_version_id"]
            isOneToOne: false
            referencedRelation: "workflow_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      workflow_versions: {
        Row: {
          id: string
          request_type_id: string
          version: number
          state: string
          definition_json: Json
          published_at: string | null
        }
        Insert: {
          id?: string
          request_type_id: string
          version: number
          state: string
          definition_json: Json
          published_at?: string | null
        }
        Update: {
          id?: string
          request_type_id?: string
          version?: number
          state?: string
          definition_json?: Json
          published_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "workflow_versions_request_type_id_fkey"
            columns: ["request_type_id"]
            isOneToOne: false
            referencedRelation: "request_types"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: { [_ in never]: never }
    Functions: {
      accept_deliverable: {
        Args: {
          p_work_item_id: string
          p_evidence: string
          p_reason: string
          p_expected_version: number
          p_criteria_revision: number
          p_fingerprint: string
          p_request_id: string
        }
        Returns: Json | null
      }
      accept_handoff: {
        Args: {
          p_handoff_id: string
          p_expected_version: number
          p_expected_revision: number
          p_notes: string
          p_request_id: string
        }
        Returns: Json | null
      }
      activate_finance_review: {
        Args: {
          p_work_item_id: string
          p_reviewer_id: string
          p_expected_revision: number
          p_expected_version: number
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      activate_publicity_review: {
        Args: {
          p_work_item_id: string
          p_reviewer_id: string
          p_expected_revision: number
          p_expected_version: number
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      activate_request_workflow: {
        Args: {
          p_work_item_id: string
          p_expected_revision: number
          p_expected_stage: string
          p_expected_version: number
          p_reviewers: string[]
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      add_comment: {
        Args: {
          p_work_item_id: string
          p_body: string
          p_mentions: string[]
          p_draft: boolean
          p_request_id: string
        }
        Returns: Json | null
      }
      add_task_dependency: {
        Args: {
          p_predecessor_id: string
          p_successor_id: string
          p_type: string
          p_required: boolean
          p_expected_predecessor_version: number
          p_expected_successor_version: number
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      assign_task: {
        Args: {
          p_work_item_id: string
          p_data: Json
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      attach_asset: {
        Args: {
          p_work_item_id: string
          p_asset_id: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      authorize_asset_download: {
        Args: {
          p_work_item_id: string
          p_asset_id: string
          p_request_id: string
        }
        Returns: Json | null
      }
      begin_request_revision: {
        Args: {
          p_work_item_id: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      can_access_work: {
        Args: {
          p_work_item_id: string
          p_level: string
        }
        Returns: boolean | null
      }
      can_read_comment: {
        Args: {
          p_comment_id: string
        }
        Returns: boolean | null
      }
      can_read_manifest: {
        Args: {
          p_id: string
        }
        Returns: boolean | null
      }
      can_read_work_grant: {
        Args: {
          p_grant_id: string
        }
        Returns: boolean | null
      }
      cancel_request: {
        Args: {
          p_work_item_id: string
          p_expected_version: number
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      change_financial_authorization: {
        Args: {
          p_authorization_id: string
          p_kind: string
          p_reason: string
          p_manifest_id: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      claim_notification_jobs: {
        Args: {
          p_limit?: number | null
        }
        Returns: Json | null
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
      create_request_draft: {
        Args: {
          p_term_id: string
          p_type_id: string
          p_form_version_id: string
          p_workflow_version_id: string
          p_title: string
          p_request_id: string
        }
        Returns: Json | null
      }
      create_task: {
        Args: {
          p_term_id: string
          p_data: Json
          p_request_id: string
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
      decide_finance_request: {
        Args: {
          p_work_item_id: string
          p_expected_revision: number
          p_expected_version: number
          p_action: string
          p_reason: string
          p_ceiling_centavos: string
          p_conditions: string
          p_expires_at: string
          p_external_outcome: string
          p_external_manifest_id: string
          p_request_id: string
        }
        Returns: Json | null
      }
      decide_publicity_request: {
        Args: {
          p_work_item_id: string
          p_expected_revision: number
          p_expected_version: number
          p_action: string
          p_reason: string
          p_conditions: string
          p_expires_at: string
          p_request_id: string
        }
        Returns: Json | null
      }
      declare_deliverable_work_types: {
        Args: {
          p_work_item_id: string
          p_types: string[]
          p_reason: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      deliver_notification_job: {
        Args: {
          p_job_id: string
          p_lease: string
        }
        Returns: Json | null
      }
      enqueue_notification_reminders: {
        Args: {
          p_limit?: number | null
        }
        Returns: number | null
      }
      explain_access: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      explain_my_access: {
        Args: {
          p_term_id: string
          p_work_id?: string | null
        }
        Returns: Json | null
      }
      finalize_upload: {
        Args: {
          p_work_item_id: string
          p_asset_ids: string[]
          p_expected_version: number
          p_request_id: string
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
      handoff_submission_options: {
        Args: {
          p_source_task_id: string
          p_handoff_id?: string | null
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
      list_finance_cases: {
        Args: {
          p_term_id: string
          p_page?: number | null
        }
        Returns: Json | null
      }
      list_finance_reviews: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      list_guest_invitations: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      list_handoffs: {
        Args: {
          p_term_id: string
          p_view?: string | null
          p_work_item_id?: string | null
          p_page?: number | null
        }
        Returns: Json | null
      }
      list_my_requests: {
        Args: {
          p_term_id: string
          p_page?: number | null
        }
        Returns: Json | null
      }
      list_review_inbox: {
        Args: {
          p_term_id: string
          p_view?: string | null
          p_page?: number | null
        }
        Returns: Json | null
      }
      list_synergies: {
        Args: {
          p_term_id: string
          p_view?: string | null
          p_parent_id?: string | null
          p_page?: number | null
        }
        Returns: Json | null
      }
      mention_candidates: {
        Args: {
          p_work_item_id: string
          p_search?: string | null
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
      preflight_access_change: {
        Args: {
          p_term_id: string
          p_values: Json
        }
        Returns: Json | null
      }
      preview_organization_change: {
        Args: {
          p_term_id: string
          p_action: string
          p_values: Json
        }
        Returns: Json | null
      }
      preview_synthetic_access: {
        Args: {
          p_term_id: string
          p_values: Json
        }
        Returns: Json | null
      }
      propose_synergy: {
        Args: {
          p_parent_id: string
          p_receiver_unit_id: string
          p_terms: Json
          p_expected_parent_version: number
          p_request_id: string
          p_agreement_id?: string | null
          p_expected_agreement_version?: number | null
        }
        Returns: Json | null
      }
      publicity_options: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      publish_organization_change: {
        Args: {
          p_term_id: string
          p_action: string
          p_values: Json
          p_expected_version: number
          p_fingerprint: string
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      read_access_admin: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_calendar: {
        Args: {
          p_term_id: string
          p_from: string
          p_to: string
          p_unit_id?: string | null
          p_page?: number | null
        }
        Returns: Json | null
      }
      read_calendar_event: {
        Args: {
          p_term_id: string
          p_key: string
        }
        Returns: Json | null
      }
      read_comment_history: {
        Args: {
          p_comment_id: string
        }
        Returns: Json | null
      }
      read_comments: {
        Args: {
          p_work_item_id: string
          p_page?: number | null
        }
        Returns: Json | null
      }
      read_committee_timeline: {
        Args: {
          p_term_id: string
          p_filters?: Json | null
          p_page?: number | null
          p_page_size?: number | null
        }
        Returns: Json | null
      }
      read_contribution: {
        Args: {
          p_work_item_id: string
        }
        Returns: Json | null
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
      read_deliverable_readiness: {
        Args: {
          p_work_item_id: string
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
      read_files: {
        Args: {
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_finance_gate: {
        Args: {
          p_term_id: string
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_finance_intake: {
        Args: {
          p_term_id: string
          p_work_item_id: string
          p_revision?: number | null
        }
        Returns: Json | null
      }
      read_finance_ledger: {
        Args: {
          p_term_id: string
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_finance_review: {
        Args: {
          p_term_id: string
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_finance_revision: {
        Args: {
          p_term_id: string
          p_work_item_id: string
          p_revision?: number | null
        }
        Returns: Json | null
      }
      read_guest_contacts: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_handoff: {
        Args: {
          p_handoff_id: string
        }
        Returns: Json | null
      }
      read_notification_failures: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_notifications: {
        Args: {
          p_term_id: string
          p_page?: number | null
        }
        Returns: Json | null
      }
      read_organization: {
        Args: {
          p_term_id: string
        }
        Returns: Json | null
      }
      read_overview: {
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
      read_owned_tasks: {
        Args: {
          p_term_id: string
          p_page?: number | null
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
      read_publicity_gate: {
        Args: {
          p_term_id: string
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_publicity_request: {
        Args: {
          p_term_id: string
          p_work_item_id: string
          p_revision?: number | null
        }
        Returns: Json | null
      }
      read_request: {
        Args: {
          p_term_id: string
          p_work_item_id: string
          p_revision?: number | null
          p_history_page?: number | null
        }
        Returns: Json | null
      }
      read_request_catalog: {
        Args: {
          p_term_id: string
          p_type_id?: string | null
        }
        Returns: Json | null
      }
      read_request_workflow: {
        Args: {
          p_term_id: string
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_resources: {
        Args: {
          p_term_id: string
          p_alias?: string | null
        }
        Returns: Json | null
      }
      read_synergy: {
        Args: {
          p_agreement_id: string
        }
        Returns: Json | null
      }
      read_task: {
        Args: {
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_task_dependencies: {
        Args: {
          p_successor_id: string
          p_search?: string | null
        }
        Returns: Json | null
      }
      read_tasks: {
        Args: {
          p_term_id: string
          p_view?: string | null
          p_page?: number | null
        }
        Returns: Json | null
      }
      read_work_parent: {
        Args: {
          p_work_item_id: string
        }
        Returns: Json | null
      }
      read_work_schedule: {
        Args: {
          p_work_item_id: string
        }
        Returns: Json | null
      }
      reconcile_finance_actual: {
        Args: {
          p_record_id: string
          p_action: string
          p_reason: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      record_deliverable_scope_exception: {
        Args: {
          p_work_item_id: string
          p_task_id: string
          p_task_version: number
          p_reason: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      record_finance_actual: {
        Args: {
          p_work_item_id: string
          p_kind: string
          p_amount_centavos: string
          p_evidence_asset_id: string
          p_reference: string
          p_recorded_on: string
          p_reason: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      redeem_guest_invitation: {
        Args: {
          p_token: string
        }
        Returns: Json | null
      }
      release_finance_budget: {
        Args: {
          p_authorization_id: string
          p_reason: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      remove_task_dependency: {
        Args: {
          p_dependency_id: string
          p_expected_predecessor_version: number
          p_expected_successor_version: number
          p_reason: string
          p_scope_exception: boolean
          p_request_id: string
        }
        Returns: Json | null
      }
      reopen_deliverable: {
        Args: {
          p_work_item_id: string
          p_evidence: string
          p_reason: string
          p_expected_version: number
          p_criteria_revision: number
          p_fingerprint: string
          p_request_id: string
        }
        Returns: Json | null
      }
      request_form_options: {
        Args: {
          p_term_id: string
          p_type_id: string
          p_work_item_id?: string | null
        }
        Returns: Json | null
      }
      reserve_upload: {
        Args: {
          p_work_item_id: string
          p_name: string
          p_mime: string
          p_size: number
          p_sha256: string
          p_source_id: string
          p_source_version: number
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      resolve_auth_context: {
        Args: Record<string, never>
        Returns: Json | null
      }
      respond_to_handoff: {
        Args: {
          p_handoff_id: string
          p_action: string
          p_expected_version: number
          p_expected_revision: number
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      respond_to_synergy: {
        Args: {
          p_agreement_id: string
          p_action: string
          p_expected_version: number
          p_expected_revision: number
          p_owner_id: string
          p_terms: Json
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      retry_notification_job: {
        Args: {
          p_term_id: string
          p_job_id: string
          p_expected_version: number
          p_reason: string
          p_request_id: string
        }
        Returns: Json | null
      }
      revise_comment: {
        Args: {
          p_comment_id: string
          p_body: string
          p_mentions: string[]
          p_action: string
          p_reason: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      revise_request: {
        Args: {
          p_work_item_id: string
          p_values: Json
          p_requested_centavos: number
          p_requested_on: string
          p_title: string
          p_expected_version: number
          p_request_id: string
        }
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
      revoke_publicity_approval: {
        Args: {
          p_approval_id: string
          p_reason: string
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
      save_calendar_event: {
        Args: {
          p_term_id: string
          p_work_item_id?: string | null
          p_values?: Json | null
          p_expected_version?: number | null
          p_request_id?: string | null
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
      save_request_draft: {
        Args: {
          p_work_item_id: string
          p_values: Json
          p_requested_centavos: number
          p_requested_on: string
          p_title: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      save_resource: {
        Args: {
          p_term_id: string
          p_id?: string | null
          p_values?: Json | null
          p_expected_version?: number | null
          p_request_id?: string | null
        }
        Returns: Json | null
      }
      save_working_link: {
        Args: {
          p_work_item_id: string
          p_asset_id: string
          p_url: string
          p_name: string
          p_notes: string
          p_label: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      seal_upload: {
        Args: {
          p_asset_id: string
          p_sha256: string
          p_size: number
          p_mime: string
        }
        Returns: Json | null
      }
      set_notification_preference: {
        Args: {
          p_term_id: string
          p_mode: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      set_notification_read: {
        Args: {
          p_notification_id: string
          p_read: boolean
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      set_onboarding_progress: {
        Args: {
          p_term_id: string
          p_item: string
          p_revision: number
          p_state: string
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
      submit_deliverable: {
        Args: {
          p_work_item_id: string
          p_evidence: string
          p_reason: string
          p_expected_version: number
          p_criteria_revision: number
          p_fingerprint: string
          p_request_id: string
        }
        Returns: Json | null
      }
      submit_finance_request: {
        Args: {
          p_work_item_id: string
          p_values: Json
          p_requested_on: string
          p_title: string
          p_finance_payload: Json
          p_expected_version: number
          p_request_id: string
          p_revision?: boolean | null
        }
        Returns: Json | null
      }
      submit_handoff: {
        Args: {
          p_source_task_id: string
          p_receiver_member_id: string
          p_receiver_unit_id: string
          p_manifest_id: string
          p_terms: Json
          p_next_task_id: string
          p_expected_source_version: number
          p_expected_next_version: number
          p_request_id: string
          p_handoff_id?: string | null
          p_expected_handoff_version?: number | null
        }
        Returns: Json | null
      }
      submit_publicity_request: {
        Args: {
          p_work_item_id: string
          p_values: Json
          p_requested_on: string
          p_title: string
          p_payload: Json
          p_expected_version: number
          p_request_id: string
          p_revision?: boolean | null
        }
        Returns: Json | null
      }
      submit_request: {
        Args: {
          p_work_item_id: string
          p_values: Json
          p_requested_centavos: number
          p_requested_on: string
          p_title: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      synergy_options: {
        Args: {
          p_term_id: string
          p_parent_id: string
        }
        Returns: Json | null
      }
      task_options: {
        Args: {
          p_term_id: string
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
      transition_request: {
        Args: {
          p_work_item_id: string
          p_assignment_id: string
          p_expected_revision: number
          p_expected_stage: string
          p_expected_version: number
          p_action: string
          p_reason: string
          p_evidence_manifest_id: string
          p_request_id: string
        }
        Returns: Json | null
      }
      transition_task: {
        Args: {
          p_work_item_id: string
          p_data: Json
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      triage_request: {
        Args: {
          p_work_item_id: string
          p_expected_revision: number
          p_expected_version: number
          p_action: string
          p_note: string
          p_accepted_on: string
          p_request_id: string
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
      update_finance_metadata: {
        Args: {
          p_work_item_id: string
          p_contact_label: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      update_task: {
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
      update_work_schedule: {
        Args: {
          p_work_item_id: string
          p_planned_start_on: string
          p_expected_version: number
          p_request_id: string
        }
        Returns: Json | null
      }
      validate_request_form: {
        Args: {
          p_term_id: string
          p_type_id: string
          p_form_version_id: string
          p_values: Json
          p_requested_centavos?: number | null
          p_work_item_id?: string | null
        }
        Returns: Json | null
      }
      verify_deliverable_external: {
        Args: {
          p_work_item_id: string
          p_manifest_id: string
          p_official_reference: string
          p_expires_at: string
          p_reason: string
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
