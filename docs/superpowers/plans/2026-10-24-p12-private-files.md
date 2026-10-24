# P12 private files implementation plan

> **Execution:** Follow the user-authorized execution method with available tools. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Scoped private uploads, working links and immutable hashed manifests.
**Architecture:** Browser sends bytes through an authenticated Edge Function; only that trusted service can store validated objects and seal reservations. User RPCs reserve/finalize and authorize every streamed download. Storage denies all direct client access and signing. Assets keep their originating access boundary even when linked elsewhere.
**Tech Stack:** Existing React/TypeScript/Supabase/Postgres and test harness; standard Web APIs, no new dependencies.
**Spec:** Implementation plan F07/F23 and section11 file controls only.

## Global constraints

Synthetic records only;5MiB/file,20MiB/manifest. PDF/JPEG/PNG only. Preserve DESIGN/Karla/#b82320/44px controls, current access/idempotency/audit conventions. No agents/chats/worktrees, deployment/provider changes/external messages/P13.

## Review focus

Untrusted MIME/extension/signatures and polyglot trailing bytes; same-key lost replies without overwrites; expired/revoked/guest scope on every download; links cannot widen originating access; finalized source metadata/hash must survive working-link replacements.

### Task 1: SQL/Storage boundary

- [x] Add migration017_assets.sql and files.test.sql: reservations, asset_links, immutable manifests; current scope, limits, expected versions/idempotency/redacted audit and trusted-only sealing.
- [x] Add private bucket with restrictive client deny policy. Extend isolated harness with explicitly shaped Storage catalog, never claim it is Storage/JWT verification.
- [x] Run named P12_A1/A3 and relevant regressions; regenerate catalog types.

### Task 2: File service and shared UI

- [x] Add supabase/functions/files validation/handler/REST backend and tests for P12_A2, streaming reauthorization, safe headers, service-only storage writes and immutable retries.
- [x] Add src/features/files API/UI and task/deliverable/gateway/preview integration. Bound requests; no auto source fetching, inline rendering, signed URLs or browser caching.
- [x] Test actual SQL with isolated byte adapter/browser at desktop/320px; preserve retry inputs, working-source notes and immutable manifests.

### Task 3: Review/checkpoint

- [x] Run targeted/full frontend/typecheck/lint/build/type checks, inspect captures and review security/diff.
- [x] Update file contracts, STATE/P12 with evidence, usage and exact carried blockers/next action.
- [x] Commit/push reviewed existing branch and verify remote commit/tree plus clean worktree.
