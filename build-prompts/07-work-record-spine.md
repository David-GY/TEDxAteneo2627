# P07 — Create common work records, grants, audit and safe commands

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

```text
Implement P07: Create common work records, grants, audit and safe commands.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Section 8 work items/audit; section 6 command contracts.
Code/interface prerequisites: P03, P05. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*work_items.sql; src/lib/commands.ts; supabase/tests/work_access.test.sql; docs/build/CONTRACTS.md

Interfaces / invariants:
work_items, record_grants, status_definitions, audit_events, idempotency_keys and outbox_jobs; commands derive actor and enforce expected version.

Implement and verify this bounded slice:
1. Create minimal common work-item spine and typed child creation convention with same-term integrity. Add record-scoped role/invite FKs deferred earlier.
2. Add RLS for ordinary summaries vs participant details and restricted classifications. Implement append-only redacted mutation audit and reusable idempotency/concurrency convention without a generic entity platform.
3. Provide transparent client command error mapping and generated types. Ensure direct status/owner/approval changes cannot bypass business commands.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P07_A1: Read access to a child/grant does not leak unrelated parent/sibling or sensitive content.
- P07_A2: Identical command retry returns its earlier result; changed payload under reused key fails.
- P07_A3: Concurrent stale update fails cleanly; denied mutation creates no successful business/audit/outbox side effects.

Update docs/build/steps/P07.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
