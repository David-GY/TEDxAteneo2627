# P14 synergy domain implementation plan

> **Execution:** Follow the user-authorized execution method with available tools. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Versioned two-committee negotiations activate one canonical contribution/task only after the correct revision is confirmed.
**Architecture:** Agreement heads, immutable revisions/confirmations/source references and a contribution backed by one existing typed task. Safe read RPCs separate negotiation visibility from parent/file access. Current scoped authority, expected versions, exact retries and redacted audit/outbox guard commands.
**Tech Stack:** Existing Postgres/Supabase/TypeScript and isolated SQL/preview tooling, no dependencies.
**Spec:** F04 and section6 propose_synergy/respond_to_synergy only.

## Global constraints

No agents/chats/worktrees/provider changes/deployment/external messages/P15. Synthetic records only. Preserve P02–P13 blockers, immutable evidence and independent FIN/MCD/acceptance. Existing live preview stays visible; P14 adds domain/API, not the later committee UI.

## Review focus

Counters cannot activate before requester confirmation; current authority/owner/deployment/cross-term checks; receiving heads learn no private parent/file data; accepted old terms survive renegotiation; same-key and competing-key accepts create one contribution and one command event; generic task edits cannot rewrite agreed terms.

### Task 1: Domain and SQL

- [x] Add migration019_synergy.sql: agreement/revision/confirmation/source/contribution tables, immutable history, RLS before exposure, safe reads and propose/respond commands.
- [x] Activate one canonical task/grants/revision atomically, preserving parent isolation and existing accepted terms during renegotiation. Add real task/contribution FK and material-edit protections.
- [x] Add named P14_A1–A3 plus scope/stale/retry/source/revision regressions; generate/check types.

### Task 2: Adapter and verification

- [x] Add typed src/features/synergies/api.ts and adapter regressions, actual isolated SQL/transport checks, relevant full-schema regressions/typecheck/lint/build and retained preview.
- [x] Review diff/access/idempotency; document contracts, STATE/P14 and actual usage/blockers. Commit/push reviewed existing branch and verify fetched remote commit/tree and preserve unrelated newer roadmap edits (whole-worktree cleanliness blocked by those edits).
