# P33 Organization commands Implementation Plan

> **Execution:** Existing checkout/branch; no agents/chats/worktrees.

**Goal:** Previewed structural changes with immutable identity/history and explicit access boundaries.
**Architecture:** Current admin.configure plus roles.manage for structural commands; a versioned neutral control spine supplies exact receipts/audit/outbox. Unit aliases/merge links do not participate in authorization. Impact checks block destructive changes until active work/reviewer/service obligations have replacements; ordinary work remapping is explicit and restricted/governed cases never move through a merge.
**Tech Stack:** Existing React/TypeScript/Vite/Supabase/PGlite, existing tokens and identity-bound retry memory.
**Spec:** build-prompts/33-organization-admin.md, F13/F22 and section6 organization changes.

## Global Constraints
Preserve UUIDs, request tracking IDs, original unit references, private content and fixed authority invariants. No illustrative committee list. No affiliation/profile overrides or role grant from a deployment label. No deployment/provider/schedule/external message. All inherited external gates persist.

## Review Focus
- Dormant role assignments can become effective when a deployment is added: expose impact and require preview-bound confirmation.
- Active or restricted cases must block archive/merge without leaking their titles/counts.
- Roster suspension/expiry and head/contact removal must not orphan work/review or remove administrative continuity.
- Names/codes can change while aliases and record links stay stable.
- Stale preview, exact retry, late audit/outbox failure and term freeze must preserve atomicity.

## Task 1: Domain commands
Files: supabase/migrations/*organization_commands.sql; supabase/tests/unit_changes.test.sql; scripts/{organization-fixtures,test-organization}.cjs; catalog types.
Interfaces: read_organization(term), preview_organization_change(term,action,values), publish_organization_change(term,action,values,expected_version,impact_fingerprint,request_id).
- [x] Write/run failing named P33_A1–A3 tests.
- [x] Implement add/edit/alias/archive/merge, approved roster and dated deployments; scoped safe impact/current blockers; immutable changes and exact audit/outbox.
- [x] Implement explicit permitted ordinary-work remapping, preserving original unit identity; block protected or unresolved cases rather than transferring private contents/authority.
- [x] Verify denial/retry/stale preview/history/last-admin/contact/rollback/freeze and no scope union.

## Task 2: Existing Administration route
Files: src/features/admin/organization/*; auth gateway/router; preview harness.
- [x] Write/run failing UI regressions.
- [x] Render units, safe roster/deployments/owners/contacts, editable drafts, impact preview and explicit publish; maintain current-scope retries and44px/focus/mobile behavior.
- [x] Run compiled browser acceptance and affected regressions.

## Task 3: Mandatory checkpoint
- [x] Run frontend/Edge typechecks, tests, lint/build/catalog and review diff.
- [x] Record exact acceptance/remaining scope/external gates/usage in P33/STATE/CONTRACTS/custody.
- [ ] Commit/push reviewed checkpoint and verify local/fetched/live commit/tree equality and clean status. Retain visible owned preview. No P34.
