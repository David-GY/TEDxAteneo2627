# Synergy interface Implementation Plan

> **Execution:** Follow the user-authorized execution method with available tools. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Implement P15 negotiation and contribution screens using the P14 commands.

**Architecture:** Extend scoped reads for discovery and server-derived actions. Reuse canonical task/overview records and the existing UI components; preserve drafts across refresh and exact-key retries across uncertain replies.

**Tech Stack:** Existing React/TypeScript/Vite/Supabase/PGlite tooling.

**Spec:** build-prompts/15-synergy-interface.md; specification F04/F05 and section 4 Working Together.

## Global Constraints

Existing branch and checkout; no agents/worktrees/provider changes/deployment/messages. Karla, #b82320, visible focus and 44px controls. Synthetic local evidence discharges no provider/human gates. P16/P16A excluded.

## Review Focus

- Lists/counts/options must not infer parent, sibling, finance or file access.
- Both heads use the same agreement ID, with actions derived from current authority.
- Stale/failed responses retain safe input and never report success.
- Lost replies retry the identical payload/key; refreshing cannot discard an uncertain command.
- Accepted work and original deadline survive amendment proposals; tasks never imply acceptance.

## Tasks

- [x] Add migration020 scoped discovery/options/action metadata; named SQL P15_A1/A2 checks; regenerate types.
- [x] Add WorkingTogetherPage, AgreementPage, request/response forms and contribution panel; wire routes/deep links/task and overview links. Test P15_A3 draft/refresh/retry and action visibility.
- [x] Run named SQL/browser checks, existing relevant regressions, typechecks/lint/build and visual/mobile/keyboard review. Record failures and corrections.
- [x] Review diff, update STATE/P15 evidence/usage/blockers, commit/push and verify remote commit/tree and clean worktree.
