// Generated from the migrated PostgreSQL catalog by pnpm db:types. Do not edit.
// Supabase-compatible table shape; full Supabase CLI comparison awaits Docker.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: {
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
    }
    Views: { [_ in never]: never }
    Functions: {
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
      explain_access: {
        Args: {
          p_term_id: string
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
      redeem_guest_invitation: {
        Args: {
          p_token: string
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
      set_profile_visibility: {
        Args: {
          p_term_id: string
          p_visibility: Json
          p_expected_version: number
          p_request_id: string
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
      transition_task: {
        Args: {
          p_work_item_id: string
          p_data: Json
          p_expected_version: number
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
    }
    Enums: { [_ in never]: never }
    CompositeTypes: { [_ in never]: never }
  }
}
