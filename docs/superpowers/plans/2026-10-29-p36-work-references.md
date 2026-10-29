# P36-R1 readable work references implementation plan

> **Execution:** Follow the user-authorized execution method with available tools. No agents, chats or worktrees.

**Goal:** Issue immutable TASK/DEL references without changing UUIDs, receipts, work versions or request tracking.

**Architecture:** Separate forced-RLS/raw-denied per-term/kind counters and issued-reference rows. Server trigger issues new references in the same creation transaction. Legacy backfill is ordered by created_at/id and commits in bounded operator batches; an incomplete term/kind marker closes new creation until that backlog is finished. Existing authorized summary/detail projections add reference metadata; exact lookup reauthorizes the record and returns the same null for missing/denied. Copy actions include the term label and retain UUID URLs.

**Tech Stack:** Existing PostgreSQL migrations/PGlite fixtures, React/TypeScript, Vitest and compiled browser checks.

One assistant simulated member, security/skeptical and migration-operator perspectives. Member: title-first references and copy controls remove transcription. Security: knowing a reference grants nothing; private tables and current record checks prevent existence/count disclosure. Operator: a separate append-only allocation avoids work-version/audit mutation and permits interrupted backfill. Alternative assigning numbers ahead of unfinished legacy rows was rejected because interleaving would make backfill numbering harder to review. Briefly closing creation for that term/kind until its bounded backfill completes is explicit. Real independent provider concurrency remains a separate required verification.

- [x] Write and observe failing local SQL regressions for interrupted/resumed deterministic upgrade, new creation/identical retry/rollback, immutability/999 boundary, private lookup/guest expiry, preserved UUID/request tracking and raw-table denial.
- [x] Implement the allocator, guarded trigger/backfill, authorized reference projections and resolver; generate catalog types and run SQL checks.
- [x] Write failing UI/API tests for validated references, title-first list/detail display and copy success/failure/term context; implement using incumbent controls.
- [x] Verify compiled member/head/guest role flows, lookup denial, copy/old UUID links, 320px and keyboard; run required tests/typechecks/lint/build.
- [x] Review and record P36 U1/U2 separately from unimplemented A1-A3/U3, commit/push and verify local/fetched/live tree equality and clean status.

P35 shared configuration publication remains absent. This explicitly requested independent R1 work can proceed; R2 form publication cannot claim success or bypass P35. No P37, provider activation, reset or institutional policy changes.
