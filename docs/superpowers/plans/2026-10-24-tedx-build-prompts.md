# TEDx Dashboard Build Prompts Implementation Plan

> **Execution:** Follow the user-authorized execution method with available tools. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build all scoped dashboard features through bounded, verified sessions with recoverable checkpoints and a model/effort choice per step.

**Architecture:** React/TypeScript static frontend, Supabase identity/PostgreSQL/private files, transactional business RPCs, small trusted integration functions, and a bounded admin configuration system. Each task implements one interface or vertical slice and carries forward unresolved provider/human evidence honestly.

**Tech Stack:** React, TypeScript, Vite, Supabase, Cloudflare Pages; existing approved Google Workspace/notification services as configured.

**Spec:** `C:/Users/david/OneDrive/Documents/ChatGPT/TEDx/TEDx-Core-Dashboard-Implementation-Plan.md`.

## Global Constraints

Read and follow `build-prompts/BUILD-CONTRACT.md`: exact school domain `student.ateneo.edu`, event April 17, 2027, Asia/Manila, ₱0 hosting target, Karla/calm interface, FIN/MCD authority, RLS/private evidence, descriptive affiliation, versioned configuration, no invented policy, targeted checks and honest checkpoints. Budget targets are observational soft ceilings, never wall-clock or token guarantees.

## Review Focus

- Same-domain nonmember, expired guest and revoked deployment: denied even with a valid token. Owned by P03–P05/P34; assert negative database and route behavior.
- Changed approved asset/caption/financial purpose: old decision remains, readiness requires the correct new review. Owned by P26/P28/P29.
- Concurrent graph edges, accept/cancel, budget reservations and room confirmations: one consistent allowed result. Owned by P14/P16/P17/P27/P56.
- Unit merges/configuration labels/role delegation: no implicit privilege expansion or history rewrite. Owned by P33–P38.
- Exports/restores/Drive copies: no private-payload leaks, missing file bytes, identity mismatch or resurrection of purged records. Owned by P45–P47/P52/P62.

## How to run

Use `build-prompts/README.md` as the navigation/index. Select each row's model/effort in the UI and send only that step. Read the shared contract once per execution; target relevant specification sections instead of reloading this entire book. All 64 steps cover the full feature set; P51–P61 remain optional to ship before the event, while P62/P63 remain required. A partial task resumes with `build-prompts/CONTINUE.md`.

The original 465-hour estimate is a human planning envelope, not a quota conversion. A prompt can finish below 40 points or need continuation; no exact number of sessions or usage percentage is guaranteed. Per-step model choices are recommendations. Official sources and feature coverage are in the prompt-pack README.

## Tasks

### Task P00: Create the runnable project and build ledger

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** package.json; src/main.tsx; src/app/router.tsx; .env.example; .gitignore; docs/build/STATE.md; docs/build/CONTRACTS.md

**Interfaces:** Establish working npm scripts typecheck, lint, test, build and later test:e2e; record real commands and runtime prerequisites. No placeholder scripts returning success.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P00: Create the runnable project and build ledger.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Sections 1, 8 conventions, 9; F25/F26.
Code/interface prerequisites: None; initial step. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
package.json; src/main.tsx; src/app/router.tsx; .env.example; .gitignore; docs/build/STATE.md; docs/build/CONTRACTS.md

Interfaces / invariants:
Establish working npm scripts typecheck, lint, test, build and later test:e2e; record real commands and runtime prerequisites. No placeholder scripts returning success.

Implement and verify this bounded slice:
1. Inspect existing repo/runtime; scaffold Vite React/TypeScript only if no app exists. Keep dependency choices small, preserve unrelated files, and ignore secrets/build artifacts.
2. Add an app route, error boundary, environment validation with a useful not-configured screen, and one meaningful mount/configuration test. Add a fake-free local README.
3. Create state/checkpoint conventions and contracts for UUID IDs, Manila dates, structured command errors, expectedVersion and idempotencyKey. Document PostgreSQL as the authority and synthetic staging boundaries.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P00_A1: Clean dependency install and actual typecheck/lint/test/build pass; an unavailable runtime is a recorded blocker, never a passing check.
- P00_A2: App boots locally with no credentials without exposing secrets or pretending to load real work.
- P00_A3: Repository has no committed secrets and state identifies P01 as next; application code only changes within this foundation.

Update docs/build/steps/P00.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P01: Recreate the prototype navigation and visual shell

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/app/AppShell.tsx; src/app/navigation.ts; src/styles/tokens.css; src/styles/global.css; DESIGN.md

**Interfaces:** Create reusable accessible page, panel, form/error and navigation patterns; expose role-filterable navigation without treating it as authorization.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P01: Recreate the prototype navigation and visual shell.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Section 4; F25; section 11 branding.
Code/interface prerequisites: P00. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/app/AppShell.tsx; src/app/navigation.ts; src/styles/tokens.css; src/styles/global.css; DESIGN.md

Interfaces / invariants:
Create reusable accessible page, panel, form/error and navigation patterns; expose role-filterable navigation without treating it as authorization.

Implement and verify this bounded slice:
1. Inspect the supplied demo or its locally available source and preserve Karla, neutral palette, compact panels, interface accent and focus language; record tokens in DESIGN.md.
2. Implement desktop/sidebar and mobile labeled navigation, skip link, headings, keyboard focus, route-level loading/empty/error states. Use an approved logo asset if supplied; otherwise a plainly labeled temporary text identity.
3. Make synthetic preview content explicitly development-only; do not ship fake success buttons or recreate all feature pages now.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P01_A1: Shell works at 320px width and 200% zoom with keyboard navigation and visible focus.
- P01_A2: 44px controls and meaningful accessible names survive long unit/person labels.
- P01_A3: Route errors show a recovery action; production routes do not display synthetic metrics as real data.

Update docs/build/steps/P01.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P02: Define members, terms, units and scoped roles

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/config.toml; supabase/migrations/*identity.sql; supabase/seed.sql; supabase/tests/identity.test.sql; src/lib/database.types.ts

**Interfaces:** organizations, terms, members, term_memberships, private_profiles, org_units, unit_memberships, roles, role_permissions and role_assignments. Actor linkage is server controlled.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P02: Define members, terms, units and scoped roles.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Sections 3, 8 identity entities; F01/F13.
Code/interface prerequisites: P00. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/config.toml; supabase/migrations/*identity.sql; supabase/seed.sql; supabase/tests/identity.test.sql; src/lib/database.types.ts

Interfaces / invariants:
organizations, terms, members, term_memberships, private_profiles, org_units, unit_memberships, roles, role_permissions and role_assignments. Actor linkage is server controlled.

Implement and verify this bounded slice:
1. Initialize Supabase local configuration if absent, verify the target is local, and document Docker/CLI prerequisites. Add foundational identity/organization tables with real FKs, same-term checks, unique normalized identity, active/expired states, dated deployments and role assignments. Enable RLS/revoke exposed grants immediately; P03 adds permitted policies.
2. Keep committee delivery flags separate from service flags. MEAn affiliation is nullable descriptive data. Defer work-item scope FK until P07 rather than adding dangling references.
3. Seed clearly fictional local roles/members/units, not an invented official eight. Generate database types and document the identity contracts.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P02_A1: Cross-term membership/unit links fail and duplicate normalized identities are rejected.
- P02_A2: Changing MEAn affiliation creates no authorization change or new role assignment.
- P02_A3: Fresh local migration/seed succeeds and all foundational tables have appropriate initial deny-by-default exposure.

Update docs/build/steps/P02.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P03: Implement and test identity authorization boundaries

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*authorization.sql; supabase/tests/authorization.test.sql; docs/permissions.md

**Interfaces:** Current-membership and effective-capability helpers derive auth.uid(); narrowly granted SQL functions use fixed search_path and no untrusted metadata.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P03: Implement and test identity authorization boundaries.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Section 3; F01/F26; section 11 controls.
Code/interface prerequisites: P02. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*authorization.sql; supabase/tests/authorization.test.sql; docs/permissions.md

Interfaces / invariants:
Current-membership and effective-capability helpers derive auth.uid(); narrowly granted SQL functions use fixed search_path and no untrusted metadata.

Implement and verify this bounded slice:
1. Enable RLS and minimal grants for identity/unit/role tables; separate permitted directory projection from private profiles. Add safe read helpers and role assignment restrictions.
2. Prevent member edits to auth linkage, grant scope, expiry, organization and private-profile visibility belonging to someone else. Treat project-owner bypass as documented infrastructure risk.
3. Create authenticated-principal fixtures for PM/head/member/associate/guest; add negative tests and a concise permission explanation contract. No UI or service-role-only proof.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P03_A1: Same-domain nonmember, expired guest and suspended member read no workspace rows even with valid identity.
- P03_A2: Equivalent MEAn/non-MEAn grants yield identical results; deployment grants only the configured unit.
- P03_A3: Direct API attempts to self-grant roles or read another private profile fail; allowed writes assert the actual changed row.

Update docs/build/steps/P03.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P04: Connect Google login and protected routes

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/auth/*; src/lib/supabase.ts; src/app/router.tsx; supabase/functions or auth hooks; docs/integrations.md

**Interfaces:** Authenticated session resolves to an active member/term context; routes never infer organization access from email alone.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P04: Connect Google login and protected routes.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01; section 10 identity.
Code/interface prerequisites: P01, P03. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/auth/*; src/lib/supabase.ts; src/app/router.tsx; supabase/functions or auth hooks; docs/integrations.md

Interfaces / invariants:
Authenticated session resolves to an active member/term context; routes never infer organization access from email alone.

Implement and verify this bounded slice:
1. Implement Supabase Google PKCE callback, exact redirect allowlist configuration, account switching/sign-out, and roster validation through trusted server/database logic.
2. Enforce exact student.ateneo.edu plus roster for ordinary core entry, not suffix tricks or hosted-domain hints. Reserve explicit guest path for P05.
3. Handle unavailable config, rejected school OAuth, expired sessions and safe post-login return routes. Document provider setup using secret references, not credentials in source.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P04_A1: Approved school member enters; a different school student and lookalike domain do not.
- P04_A2: Expired/suspended membership cannot bypass by opening a route or using an old token.
- P04_A3: Real Google callback tested if credentials exist; otherwise local authorization tests pass and live OAuth verification is explicitly blocked, not claimed complete.

Update docs/build/steps/P04.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P05: Add scoped off-domain guest invitations

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/guests/*; supabase/migrations/*guests.sql; supabase/tests/guests.test.sql

**Interfaces:** create_guest_invitation, redeem_guest_invitation, revoke_guest_access use hashed one-time tokens, verified identity, sponsor, exact record scopes and expiry.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P05: Add scoped off-domain guest invitations.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01; section 3 guest rules.
Code/interface prerequisites: P04. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/guests/*; supabase/migrations/*guests.sql; supabase/tests/guests.test.sql

Interfaces / invariants:
create_guest_invitation, redeem_guest_invitation, revoke_guest_access use hashed one-time tokens, verified identity, sponsor, exact record scopes and expiry.

Implement and verify this bounded slice:
1. Implement invitation storage and server commands with exact verified-email binding, default 14-day access, single-use redemption and audit. Record-scoped targets attach once P07 exists.
2. Build sponsor admin form with clear scope preview, copy-link action, expiry/renew/revoke. External Google accounts work; no automatic email sending.
3. Ensure current DB checks revoke existing sessions' data access. Keep invitation model provider independent; do not add untested non-Google OTP.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P05_A1: Forwarded token cannot be used by another email; double redemption and expired tokens fail.
- P05_A2: Off-domain guest receives no full directory or membership-wide scope by default.
- P05_A3: Revocation is enforced with a previously issued JWT, and no raw invite token is stored or logged.

Update docs/build/steps/P05.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P06: Build the permitted member directory and process contacts

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/people/*; src/features/account/*; supabase/tests/directory.test.sql

**Interfaces:** Directory query returns safe name/unit/role/contact-route fields; private profile updates and visibility choices are separate commands.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P06: Build the permitted member directory and process contacts.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F13/F14; section 3 private data.
Code/interface prerequisites: P01, P04. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/people/*; src/features/account/*; supabase/tests/directory.test.sql

Interfaces / invariants:
Directory query returns safe name/unit/role/contact-route fields; private profile updates and visibility choices are separate commands.

Implement and verify this bounded slice:
1. Build searchable basic people/unit/contact views, own profile editor and optional affiliation/skills/course/contact fields with clear sharing controls.
2. Make process contacts primary/backup and display plain descriptions rather than requiring acronyms. Use synthetic units until official roster arrives.
3. Keep guest directory limited to own/shared contacts; names in past records remain attributable without granting access to old private profiles.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P06_A1: Head cannot change another member's optional disclosure or see unshared contact/course fields.
- P06_A2: Affiliation left blank does not block tasks/onboarding or remove help links.
- P06_A3: Multi-unit membership and missing backup contact render clearly on mobile without duplicate people.

Update docs/build/steps/P06.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P07: Create common work records, grants, audit and safe commands

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*work_items.sql; src/lib/commands.ts; supabase/tests/work_access.test.sql; docs/build/CONTRACTS.md

**Interfaces:** work_items, record_grants, status_definitions, audit_events, idempotency_keys and outbox_jobs; commands derive actor and enforce expected version.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

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

### Task P08: Build the Core Deliverables list and detail view

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/deliverables/api.ts; src/features/deliverables/DeliverablesPage.tsx; src/features/deliverables/DeliverablePage.tsx; supabase/migrations/*deliverables.sql

**Interfaces:** deliverables subtype and permission-filtered list/detail queries with owner, lead unit, date, readiness, next action and safe gate fields.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P08: Build the Core Deliverables list and detail view.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03; section 4 Core Deliverables.
Code/interface prerequisites: P06, P07. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/deliverables/api.ts; src/features/deliverables/DeliverablesPage.tsx; src/features/deliverables/DeliverablePage.tsx; supabase/migrations/*deliverables.sql

Interfaces / invariants:
deliverables subtype and permission-filtered list/detail queries with owner, lead unit, date, readiness, next action and safe gate fields.

Implement and verify this bounded slice:
1. Add deliverable child schema and real queries, including pagination/filter state and stable deep links. Seed one clearly synthetic shared-output example locally.
2. Implement required columns, phase/unit/owner/blocked/overdue/involves-my-unit filters, mobile rows, loading/error/empty states.
3. Use provisional pending-gate states until P29 installs authoritative acceptance; no client-generated approval badges or completion percentages masquerading as readiness.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P08_A1: Restricted deliverables and private details are absent from unauthorized rows/counts.
- P08_A2: Multi-unit filter uses one canonical output without duplicating it.
- P08_A3: List/detail render real DB changes and provide a useful state for no records or denied deep links.

Update docs/build/steps/P08.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P09: Add deliverable ownership, criteria and acceptance commands

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/deliverables/DeliverableEditor.tsx; supabase/migrations/*deliverable_commands.sql; supabase/tests/deliverables.test.sql

**Interfaces:** create_deliverable and update_deliverable require active owner, lead unit, outcome, date and criteria; acceptance evaluates server readiness.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P09: Add deliverable ownership, criteria and acceptance commands.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03; section 6 create_deliverable.
Code/interface prerequisites: P08. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/deliverables/DeliverableEditor.tsx; supabase/migrations/*deliverable_commands.sql; supabase/tests/deliverables.test.sql

Interfaces / invariants:
create_deliverable and update_deliverable require active owner, lead unit, outcome, date and criteria; acceptance evaluates server readiness.

Implement and verify this bounded slice:
1. Build authorized create/edit/propose/reassign flows; preserve original deadline and reasoned changes. Members propose commitments for heads rather than assigning arbitrary people.
2. Implement draft/in-progress/submit-for-acceptance/accept/cancel with typed semantic states. Until P29, fail closed when unresolved mandatory gates exist.
3. Capture acceptance criteria revisions and final evidence; owner departure queues reassignment rather than silently becoming ownerless.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P09_A1: Inactive/cross-term owner rejected; ordinary member cannot create a top-level event commitment directly.
- P09_A2: Original deadline survives a later extension and change is attributed.
- P09_A3: Direct API completion or acceptance with unmet criteria/gates fails; an authorized clean case succeeds.

Update docs/build/steps/P09.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P10: Implement task creation, assignment and progress

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/tasks/*; supabase/migrations/*tasks.sql; supabase/tests/tasks.test.sql

**Interfaces:** create_task, update_task, assign_task and transition_task; tasks relate to one canonical work item and optional deliverable/contribution.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P10: Implement task creation, assignment and progress.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F05/F07; section 3 task permissions.
Code/interface prerequisites: P09. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/tasks/*; supabase/migrations/*tasks.sql; supabase/tests/tasks.test.sql

Interfaces / invariants:
create_task, update_task, assign_task and transition_task; tasks relate to one canonical work item and optional deliverable/contribution.

Implement and verify this bounded slice:
1. Implement My Tasks and task detail/editor with checklist, assignee, collaborators, dates, blocked reason and typed status categories.
2. Enforce own/unit/shared editing and prevent cross-unit assignment until accepted agreement exists. Preserve expected-version conflicts and original dates.
3. Treat Done as completion evidence/review appropriate to task type, never as authority to approve financial/publicity work.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P10_A1: Duplicate retry creates one task; unauthorized assignee/owner changes fail.
- P10_A2: Different committee cannot receive an imposed task before agreement/head acceptance.
- P10_A3: Assignee can update allowed progress; overdue/date-only behavior is correct in Manila.

Update docs/build/steps/P10.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P11: Add comments, history and eligible mentions

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/comments/*; supabase/migrations/*comments.sql; supabase/tests/comments.test.sql

**Interfaces:** add_comment and revise_comment preserve author/edit history; mention candidates come from eligible participants only.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P11: Add comments, history and eligible mentions.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F07; section 3 inherited access.
Code/interface prerequisites: P10. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/comments/*; supabase/migrations/*comments.sql; supabase/tests/comments.test.sql

Interfaces / invariants:
add_comment and revise_comment preserve author/edit history; mention candidates come from eligible participants only.

Implement and verify this bounded slice:
1. Build plain-text or safely sanitized Markdown comments shared by task/deliverable records. Show author, timestamps, edits and current permission state.
2. Retain original comment revisions referenced in submissions or decisions. Implement own draft removal and reasoned redaction rather than deleting evidence history.
3. Emit outbox mention events without sending external messages. Do not expose private directory candidates through autocomplete.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P11_A1: Script/HTML payload does not execute; pasted unsafe links do not become executable content.
- P11_A2: Unrelated user cannot enumerate comments, revisions or mention candidates.
- P11_A3: Editing a decision-referenced comment preserves original evidence and shows later amendment.

Update docs/build/steps/P11.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P12: Implement private uploads, Drive links and immutable manifests

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/files/*; supabase/functions/files/*; supabase/migrations/*assets.sql; supabase/tests/files.test.sql

**Interfaces:** assets and asset_links with classification, hash, size and source; finalize_upload creates immutable manifest; downloads reauthorize and audit.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P12: Implement private uploads, Drive links and immutable manifests.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F07/F23; section 11 file controls.
Code/interface prerequisites: P07, P11. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/files/*; supabase/functions/files/*; supabase/migrations/*assets.sql; supabase/tests/files.test.sql

Interfaces / invariants:
assets and asset_links with classification, hash, size and source; finalize_upload creates immutable manifest; downloads reauthorize and audit.

Implement and verify this bounded slice:
1. Implement private PDF/JPEG/PNG uploads with proposed 5MB/file and 20MB/submission limits, content validation, random paths and safe download behavior.
2. Add validated Drive/Docs/Sheets/Slides/Canva working links with access notes. A working URL is not approved evidence; support snapshot hashes/versions.
3. Inherit effective record access for file operations, prevent widening through extra links, and record restricted downloads without logging contents/tokens.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P12_A1: Anonymous/other-unit/revoked user cannot download object via direct path or issue a signed URL.
- P12_A2: MIME mismatch, executable/SVG/HTML/archive and oversize files are rejected.
- P12_A3: Replacing a working source does not overwrite a finalized snapshot; hashes and manifest stay stable.

Update docs/build/steps/P12.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P13: Build next actions and Who is waiting on you

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/overview/*; supabase/migrations/*overview_queries.sql

**Interfaces:** Authorized overview result separates actionable work from waiting-on-others and supports later request/handoff/approval sources.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P13: Build next actions and Who is waiting on you.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F02; section 4 Overview.
Code/interface prerequisites: P10, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/overview/*; supabase/migrations/*overview_queries.sql

Interfaces / invariants:
Authorized overview result separates actionable work from waiting-on-others and supports later request/handoff/approval sources.

Implement and verify this bounded slice:
1. Aggregate real assigned due/overdue/blocked work and owned deliverables with next action/person/date. Integrate only sources already implemented, not invented pending approvals.
2. Add sensible empty/error/loading states, direct authorized links and committee context.
3. Define small source extensions so P18/P23/P30 add handoffs/reviews/inbox without duplicating counts or bypassing scopes.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P13_A1: Widget count equals its visible actionable rows.
- P13_A2: Restricted work does not leak through aggregate totals or hidden titles.
- P13_A3: An action completed elsewhere disappears after real invalidation/refetch; no hardcoded demo numbers.

Update docs/build/steps/P13.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P14: Implement versioned committee synergy agreements

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*synergy.sql; supabase/tests/synergy.test.sql; src/features/synergies/api.ts

**Interfaces:** propose_synergy and respond_to_synergy support accept/decline/counterproposal against immutable agreement_revisions, creating named contributions on agreement.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P14: Implement versioned committee synergy agreements.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F04; section 6 propose_synergy/respond_to_synergy.
Code/interface prerequisites: P09, P10. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*synergy.sql; supabase/tests/synergy.test.sql; src/features/synergies/api.ts

Interfaces / invariants:
propose_synergy and respond_to_synergy support accept/decline/counterproposal against immutable agreement_revisions, creating named contributions on agreement.

Implement and verify this bounded slice:
1. Model requester/receiver units, output, criteria, effort band, date, named owner and revision confirmations. Grant receiving heads only a safe proposal preview.
2. Require valid receiving-head authority and requester acceptance of counters. Accepted terms are immutable; material changes negotiate a revision.
3. Create canonical contribution/grants/tasks transactionally; no duplicate copies per committee and no implicit whole-parent access.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P14_A1: Counterproposal does not activate work before requester confirms that revision.
- P14_A2: Unrelated head or expired role cannot accept; unknown owner/cross-term links fail.
- P14_A3: Concurrent accept/retry produces one contribution and one audit/outbox result.

Update docs/build/steps/P14.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P15: Build Working Together and negotiation screens

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/synergies/WorkingTogetherPage.tsx; src/features/synergies/AgreementPage.tsx; src/features/deliverables/*

**Interfaces:** UI uses P14 commands and displays same agreement in requesting/receiving committee views with versioned accepted terms.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P15: Build Working Together and negotiation screens.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F04/F05; section 4 Working Together.
Code/interface prerequisites: P14, P13. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/synergies/WorkingTogetherPage.tsx; src/features/synergies/AgreementPage.tsx; src/features/deliverables/*

Interfaces / invariants:
UI uses P14 commands and displays same agreement in requesting/receiving committee views with versioned accepted terms.

Implement and verify this bounded slice:
1. Create outgoing/incoming agreements and contribution views, request-help form, accept/decline/counterproposal actions and clear pending ownership.
2. Add deliverable contributions panel and assigned work links; integrate accepted contributions in My Tasks/Overview.
3. Display proposed versus agreed deadlines and immutable history. Preserve mobile/keyboard usability.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P15_A1: Two scoped users see one agreement with correct actions rather than duplicated independent records.
- P15_A2: Receiver cannot edit other contributions/finance data through shared parent links.
- P15_A3: A failed/stale negotiation keeps entered safe data and offers refresh without fake success.

Update docs/build/steps/P15.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P16: Enforce task dependencies and meaningful blocked states

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/tasks/Dependencies.tsx; supabase/migrations/*dependencies.sql; supabase/tests/dependencies.test.sql

**Interfaces:** add_task_dependency and remove_task_dependency enforce finish-to-start/informational types, no cycles and required dependency readiness.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P16: Enforce task dependencies and meaningful blocked states.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F05/F03; section 8 task_dependencies.
Code/interface prerequisites: P15. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/tasks/Dependencies.tsx; supabase/migrations/*dependencies.sql; supabase/tests/dependencies.test.sql

Interfaces / invariants:
add_task_dependency and remove_task_dependency enforce finish-to-start/informational types, no cycles and required dependency readiness.

Implement and verify this bounded slice:
1. Add dependency schema and commands with authorization on both records and no metadata leaks. Serialize graph edits sufficiently to prevent concurrent cycle creation.
2. Expose blocker/next-step information in task and contribution views; distinguish informational links from required gates.
3. Handle cancelled predecessors and explicit scope exceptions with reasons without waiving FIN/MCD rules.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P16_A1: Self-edge, A→B→A cycle and concurrent inverse edges cannot corrupt graph.
- P16_A2: Required unfinished predecessor blocks readiness; informational link does not.
- P16_A3: Restricted predecessor shows only permitted neutral information and no private title/count leak.

Update docs/build/steps/P16.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P17: Implement immutable handoff packages and acceptance

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*handoffs.sql; supabase/tests/handoffs.test.sql; src/features/handoffs/api.ts

**Interfaces:** submit_handoff, respond_to_handoff and accept_handoff bind receiver, package revision/manifest, criteria and agreed next task.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P17: Implement immutable handoff packages and acceptance.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F06; section 6 accept_handoff.
Code/interface prerequisites: P16, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*handoffs.sql; supabase/tests/handoffs.test.sql; src/features/handoffs/api.ts

Interfaces / invariants:
submit_handoff, respond_to_handoff and accept_handoff bind receiver, package revision/manifest, criteria and agreed next task.

Implement and verify this bounded slice:
1. Store offered package snapshots, sender/receiver, due date, states and resubmission revisions. Sender remains responsible until explicit acceptance.
2. Make acceptance atomic with immutable receipt, scoped grants and activation of the next agreed task; keep deliverable owner unchanged.
3. Recheck current receiver authority and original package state; audit transitions and emit outbox events.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P17_A1: Changed file source cannot silently change the offered snapshot.
- P17_A2: Accept racing cancellation has one valid outcome, not two contradictory states.
- P17_A3: Decline/revision request creates no next task; repeated successful acceptance does not duplicate work.

Update docs/build/steps/P17.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P18: Build incoming and outgoing handoff actions

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/handoffs/*; src/features/overview/*; src/features/synergies/*

**Interfaces:** Screens consume immutable package/receipt and P17 transitions; overview gains authorized incoming handoffs and sender revision actions.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P18: Build incoming and outgoing handoff actions.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F06/F02; section 4 Working Together.
Code/interface prerequisites: P17, P13. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/handoffs/*; src/features/overview/*; src/features/synergies/*

Interfaces / invariants:
Screens consume immutable package/receipt and P17 transitions; overview gains authorized incoming handoffs and sender revision actions.

Implement and verify this bounded slice:
1. Add package submission, file/criteria preview, accept/request-changes/decline/withdraw actions and readable history.
2. Show who currently owes the next action, proposed date and explicit acceptance state in Working Together/task detail.
3. Connect accepted next work to both committee views without changing accountability or granting unrelated records.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P18_A1: Receiver can review package on mobile/keyboard and understands changes requested versus accepted.
- P18_A2: Sender cannot mark own package accepted by editing UI state or replaying endpoint.
- P18_A3: Overview deduplicates handoff/task events and removes resolved actions after refresh.

Update docs/build/steps/P18.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P19: Create versioned request types and initial service catalog

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*request_definitions.sql; src/features/requests/catalog/*; supabase/tests/request_definitions.test.sql

**Interfaces:** request_types points to immutable form_versions/workflow_versions, receiving service, primary/backup contacts and guest eligibility.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P19: Create versioned request types and initial service catalog.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F22; section 6 form/workflow definitions.
Code/interface prerequisites: P07, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*request_definitions.sql; src/features/requests/catalog/*; supabase/tests/request_definitions.test.sql

Interfaces / invariants:
request_types points to immutable form_versions/workflow_versions, receiving service, primary/backup contacts and guest eligibility.

Implement and verify this bounded slice:
1. Define stable request/form/stage identifiers and bounded schema types matching section 6. Seed general, FIN and MCD configurations with unconfirmed authority clearly flagged.
2. Build a plain-language catalog/read-only published form definition query and contact/lead-time/official-link display.
3. Protect typed financial/approval fields from arbitrary ordinary JSON and keep confidential custom fields restricted by type/payload classification.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P19_A1: Published schema cannot be edited in place and an archived service cannot receive new live requests.
- P19_A2: Unknown/conflicting field keys or unsafe executable conditions are rejected.
- P19_A3: No generic form-definition read exposes private financial data, secrets or case notes.

Update docs/build/steps/P19.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P20: Render and validate configured request forms

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/forms/*; supabase/functions or SQL validators; src/features/forms/validation.test.ts

**Interfaces:** FormDefinition and typed field/condition evaluator supports fixed operators; browser and trusted submit validation agree on required fields and classifications.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P20: Render and validate configured request forms.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F22; section 6 Form builder specification.
Code/interface prerequisites: P19. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/forms/*; supabase/functions or SQL validators; src/features/forms/validation.test.ts

Interfaces / invariants:
FormDefinition and typed field/condition evaluator supports fixed operators; browser and trusted submit validation agree on required fields and classifications.

Implement and verify this bounded slice:
1. Implement accessible fields: text, numeric/currency, dates, choice/multichoice, checkbox, eligible member/unit, URL, file, repeatable lines.
2. Add required/help/error handling and bounded AND/OR equality/membership/numeric conditions. Preserve stable option IDs and display snapshots.
3. Implement trusted validation, field/section/line caps, eligible selector validation and handling of values in newly hidden fields. Do not trust client hidden values.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P20_A1: Required conditional field omitted via direct API fails; client/server accept the same valid case.
- P20_A2: 50-field/10-section/100-line proposed limits and bounded condition nesting are enforced.
- P20_A3: Keyboard/screen-reader errors target the correct control; malicious scripts/regex definitions never execute.

Update docs/build/steps/P20.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P21: Implement tracked submission, revisions and requester views

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/requests/*; supabase/migrations/*request_submission.sql; supabase/tests/request_submission.test.sql

**Interfaces:** submit_request allocates shared per-term/service namespace IDs, freezes validated payload/asset manifest and creates pinned workflow instance; revise_request appends revision.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P21: Implement tracked submission, revisions and requester views.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08; section 8 requests/tracking counters.
Code/interface prerequisites: P20, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/requests/*; supabase/migrations/*request_submission.sql; supabase/tests/request_submission.test.sql

Interfaces / invariants:
submit_request allocates shared per-term/service namespace IDs, freezes validated payload/asset manifest and creates pinned workflow instance; revise_request appends revision.

Implement and verify this bounded slice:
1. Create requests, immutable revisions, tracking_counters and current state with same-term integrity. All FIN types share FIN counter, all MCD types share MCD counter.
2. Build draft/save/submit/revise/cancel/my-requests/tracking detail with next action, requested/accepted dates and history.
3. Pin form/workflow versions and create workflow assignment shell; P22 provides decision execution. Keep unconfigured authority visibly paused.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P21_A1: Concurrent different MCD form submissions cannot both emit MCD-027; IDs never recycle.
- P21_A2: Retry creates one submission; newer form publication does not rewrite prior payload/schema.
- P21_A3: Another requester cannot read/edit private request data; submitted revision is immutable.

Update docs/build/steps/P21.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P22: Execute authorized sequential review workflows

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*workflow_engine.sql; supabase/tests/workflow_engine.test.sql; src/features/approvals/api.ts

**Interfaces:** transition_request supports assigned sequential stages with one/all reviewers, pinned workflow/revision, revision route, conditions and external evidence; actor is session-derived.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P22: Execute authorized sequential review workflows.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F09/F10; section 6 workflow engine and transition_request.
Code/interface prerequisites: P21. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*workflow_engine.sql; supabase/tests/workflow_engine.test.sql; src/features/approvals/api.ts

Interfaces / invariants:
transition_request supports assigned sequential stages with one/all reviewers, pinned workflow/revision, revision route, conditions and external evidence; actor is session-derived.

Implement and verify this bounded slice:
1. Implement assignments and append-only decisions; lock current stage/revision, check effective role, independence, expiry, required documents and idempotency.
2. Advance only after configured quorum; missing/revoked approver pauses for authorized reassignment. Stage labels do not change protected semantics.
3. Commit business state, decision, safe outcome, audit and outbox together. FIN/MCD typed authority hooks fail closed until their modules are installed.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P22_A1: Unassigned/self/revoked approver, direct status update and stale-revision action fail.
- P22_A2: All-reviewer stage cannot advance after only one decision; duplicate retries do not count twice.
- P22_A3: Failed transition rolls back all effects; pinned old workflow remains consistent after new publication.

Update docs/build/steps/P22.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P23: Build department triage and reviewer decision screens

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/approvals/*; src/features/requests/*; src/features/overview/*

**Interfaces:** Authorized queue and assignment/decision UI use P22, exposing only reviewable version and permissible actions.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P23: Build department triage and reviewer decision screens.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F08/F02; section 4 Department Inbox.
Code/interface prerequisites: P22, P18. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/approvals/*; src/features/requests/*; src/features/overview/*

Interfaces / invariants:
Authorized queue and assignment/decision UI use P22, exposing only reviewable version and permissible actions.

Implement and verify this bounded slice:
1. Implement unassigned/assigned/aging/revision inboxes, reviewer assignment, requested versus accepted dates and safe triage notes.
2. Add review package preview, required reasons, revise/reject/approve/complete as allowed by server, and reassignment of lost authority.
3. Integrate actionable reviews and revisions into overview; distinguish operational request approval from FIN authorization and MCD release.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P23_A1: Department associate sees assigned cases only unless explicitly granted broader scope.
- P23_A2: Revoked reviewer loses action immediately after DB authorization check, even with an open page.
- P23_A3: UI shows server conflict/validation and never optimistically labels a failed decision approved.

Update docs/build/steps/P23.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P24: Create restricted finance revisions and exact money calculations

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*finance_payload.sql; supabase/tests/finance_payload.test.sql; src/features/finance/money.ts

**Interfaces:** finance_cases/revisions/lines and audited restricted reads separate from ordinary request JSON; PHP amounts use integer centavos and defined quantity rounding.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P24: Create restricted finance revisions and exact money calculations.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09; section 8 finance entities.
Code/interface prerequisites: P22, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*finance_payload.sql; supabase/tests/finance_payload.test.sql; src/features/finance/money.ts

Interfaces / invariants:
finance_cases/revisions/lines and audited restricted reads separate from ordinary request JSON; PHP amounts use integer centavos and defined quantity rounding.

Implement and verify this bounded slice:
1. Model costs, budget/expenses/reimbursement and fundraising/sales plan payloads, fund/purpose/beneficiary, pricing, forecast and governed evidence.
2. Implement trusted line/total validation with explicit quantity scale/rounding and safe serialization; never binary floating money. Keep sensitive joins out of ordinary views.
3. Bind finance revision to submitted request revision and immutable private evidence; define payload hash fields for later authorizations.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P24_A1: PHP 0.10 + 0.20 equals 0.30; inconsistent totals, negative invalid inputs and out-of-range values fail.
- P24_A2: Ordinary head/member cannot read another FIN case through API/search/counts/attachments.
- P24_A3: Forecast sales do not create actual revenue or a payment record; source payload remains immutable.

Update docs/build/steps/P24.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P25: Build cost and fundraising/sales request experiences

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/finance/FinanceRequestForm.tsx; src/features/finance/FinanceCasePage.tsx; src/features/finance/FinanceDesk.tsx

**Interfaces:** Typed intake and reviewer detail use P24, showing requested/forecast/authorized/actual as distinct concepts.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P25: Build cost and fundraising/sales request experiences.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09; section 6 FIN defaults.
Code/interface prerequisites: P24, P23. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/finance/FinanceRequestForm.tsx; src/features/finance/FinanceCasePage.tsx; src/features/finance/FinanceDesk.tsx

Interfaces / invariants:
Typed intake and reviewer detail use P24, showing requested/forecast/authorized/actual as distinct concepts.

Implement and verify this bounded slice:
1. Build itemized cost/expense forms and fundraising/sales plan forms with prices, quantities, projected revenue/costs, terms, purpose and school evidence requirements.
2. Show confidential case contents only to eligible participants; show neutral gate summary to ordinary deliverable participants.
3. Explain that submission authorizes no commitment/payment and zero-cost fundraising still requires FIN review; expose missing requirements clearly.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P25_A1: Zero-cost fundraiser takes FIN path rather than skipping approval.
- P25_A2: Partial-line edits recompute exact totals with useful field errors.
- P25_A3: Shared task link exposes safe status, never receipts, amounts or private financial title.

Update docs/build/steps/P25.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P26: Enforce independent FIN authorization and revision invalidation

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*financial_authorization.sql; supabase/tests/financial_authorization.test.sql; src/features/finance/*

**Interfaces:** FIN decision creates financial_authorization for exact revision/ceiling/purpose/conditions/expiry with required external authorization status.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P26: Enforce independent FIN authorization and revision invalidation.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09; section 6 material-change rules.
Code/interface prerequisites: P25. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*financial_authorization.sql; supabase/tests/financial_authorization.test.sql; src/features/finance/*

Interfaces / invariants:
FIN decision creates financial_authorization for exact revision/ceiling/purpose/conditions/expiry with required external authorization status.

Implement and verify this bounded slice:
1. Connect typed FIN capability to P22. Block requester/beneficiary self-approval, require officially authorized alternate, and support partial approval without altering request.
2. Implement governed changes/new revision and superseded/expired/revoked authorization state with old decision preserved.
3. Build FIN decision/conditions/ceiling view and external evidence/not-required policy outcome. No invented threshold or PM substitute.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P26_A1: Sole FIN approver's own case pauses rather than self-approves or routes to an unauthorized PM.
- P26_A2: Amount/purpose/pricing/quantity/evidence change invalidates old readiness; harmless excluded metadata does not silently rewrite evidence.
- P26_A3: Concurrent approve/reject or retry records one valid transition and preserves original request amount.

Update docs/build/steps/P26.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P27: Add budget reservations and recorded actuals

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*finance_ledger.sql; supabase/tests/finance_ledger.test.sql; src/features/finance/Reconciliation.tsx

**Interfaces:** Optional budget_accounts and immutable reservation/release/reconciliation entries; actual expense/revenue records require evidence and do not process payments.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P27: Add budget reservations and recorded actuals.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F09/F21; section 8 budget ledger.
Code/interface prerequisites: P26. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*finance_ledger.sql; supabase/tests/finance_ledger.test.sql; src/features/finance/Reconciliation.tsx

Interfaces / invariants:
Optional budget_accounts and immutable reservation/release/reconciliation entries; actual expense/revenue records require evidence and do not process payments.

Implement and verify this bounded slice:
1. Implement configured budget ceilings with atomic reservation on authorization, explicit cancellation release and reversing entries rather than destructive edits.
2. Record authorized actual expenses/revenue and evidence; detect duplicates and overrun requiring new review. Label booked/forecast/actual distinctly.
3. Expose restricted FIN ledger and safe delivery gate outcome without publishing balances/receipts to general core.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P27_A1: Two simultaneous requests cannot reserve more than enabled available budget.
- P27_A2: Cancelled authorization releases once; retry and reversal cannot double-credit budget.
- P27_A3: Overrun is flagged/re-reviewed; projected sales never count as actual receipts and no payment integration exists.

Update docs/build/steps/P27.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P28: Implement final publicity review with immutable evidence

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/publicity/*; supabase/migrations/*publicity_review.sql; supabase/tests/publicity_review.test.sql

**Interfaces:** publicity_reviews bind final rendition manifest, copy/caption, credits, channel/use and intended date to request revision and MCD decision.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P28: Implement final publicity review with immutable evidence.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F10; section 10 approved snapshot.
Code/interface prerequisites: P23, P12, P26. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/publicity/*; supabase/migrations/*publicity_review.sql; supabase/tests/publicity_review.test.sql

Interfaces / invariants:
publicity_reviews bind final rendition manifest, copy/caption, credits, channel/use and intended date to request revision and MCD decision.

Implement and verify this bounded slice:
1. Build final-publicity intake/reviewer pages separate from draft creative collaboration. Require frozen app evidence or exported rendition plus source link.
2. Use explicit MCD capability and P22 decisions; govern asset/caption/credit/channel/use changes through new revision, preserving old approvals.
3. Expose safe MCD gate results and independent FIN requirement for cost-bearing publicity. Do not post to social accounts.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P28_A1: Mutable Canva/Drive URL alone cannot be accepted as final approval evidence.
- P28_A2: Caption-only or source-asset replacement invalidates current publication readiness.
- P28_A3: FIN approval cannot substitute for MCD, and MCD approval cannot clear unpaid/unapproved financial gates.

Update docs/build/steps/P28.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P29: Unify deliverable acceptance across contributions and approvals

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** supabase/migrations/*readiness.sql; supabase/tests/readiness.test.sql; src/features/deliverables/*; src/features/overview/*

**Interfaces:** Authoritative readiness/accept_deliverable checks required contribution acceptance, tasks/dependencies, criteria, valid revision-bound FIN/MCD and external authorization.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P29: Unify deliverable acceptance across contributions and approvals.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F03/F05/F09/F10; section 4 readiness.
Code/interface prerequisites: P18, P26, P27, P28. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*readiness.sql; supabase/tests/readiness.test.sql; src/features/deliverables/*; src/features/overview/*

Interfaces / invariants:
Authoritative readiness/accept_deliverable checks required contribution acceptance, tasks/dependencies, criteria, valid revision-bound FIN/MCD and external authorization.

Implement and verify this bounded slice:
1. Implement safe gate aggregation and derived readiness categories without treating task-percent complete as acceptance.
2. Wire deliverable owner submission and authorized final acceptance to actual checks; update list/detail/overview next action and blockers.
3. Apply protected policy triggers on work type even if an admin removes/renames a workflow label; record explicit permitted scope exceptions separately.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P29_A1: All tasks Done with required handoff or FIN/MCD pending cannot accept deliverable.
- P29_A2: A formerly accepted deliverable affected by a governed change shows required re-review according to documented reopening rule.
- P29_A3: Unauthorized user learns no confidential amount/title through blocked reasons; clean authorized example completes end to end.

Update docs/build/steps/P29.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P30: Deliver deduplicated in-app notifications and reliable jobs

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/notifications/*; supabase/functions/dispatch-notifications/*; supabase/tests/notifications.test.sql

**Interfaces:** Transactional outbox -> authorized notifications with unique recipient/event key, read state, retries, dead-letter visibility and current access checks.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P30: Deliver deduplicated in-app notifications and reliable jobs.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F19; section 6 outbox contracts.
Code/interface prerequisites: P29. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/notifications/*; supabase/functions/dispatch-notifications/*; supabase/tests/notifications.test.sql

Interfaces / invariants:
Transactional outbox -> authorized notifications with unique recipient/event key, read state, retries, dead-letter visibility and current access checks.

Implement and verify this bounded slice:
1. Implement inbox/badge and required actionable events from tasks, agreements, handoffs, requests and decisions; handle already-resolved actions.
2. Dispatch after commit with bounded backoff, idempotency and persistent failure status. Keep external adapters disabled until their own steps.
3. Add read/unread preferences skeleton and safe notification text for restricted cases; prevent stale content after access revocation.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P30_A1: Job crash/retry creates one visible notification, not duplicates.
- P30_A2: Business decision remains committed if dispatch fails; failed queue is visible to custodian.
- P30_A3: Revoked member cannot read stale restricted notification or use a deep link to regain access.

Update docs/build/steps/P30.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P31: Build the shared calendar and explicit event exports

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/calendar/*; supabase/migrations/*calendar.sql; src/features/calendar/ics.test.ts

**Interfaces:** calendar_events preserve source/visibility; single-event ICS and Add to Google Calendar are explicitly copies, not live sync.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P31: Build the shared calendar and explicit event exports.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F12; section 10 Calendar.
Code/interface prerequisites: P30. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/calendar/*; supabase/migrations/*calendar.sql; src/features/calendar/ics.test.ts

Interfaces / invariants:
calendar_events preserve source/visibility; single-event ICS and Add to Google Calendar are explicitly copies, not live sync.

Implement and verify this bounded slice:
1. Build month/list/mobile event views with permitted core/committee events and source-linked milestones/deadlines.
2. Implement accurate Manila timed/all-day export, escaping ICS content, updates/cancellation labels and no duplicate source events.
3. Keep private finance/feedback/mentoring details out of shared calendars and defer automatic Google API integration to P53.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P31_A1: Manila midnight, all-day dates and cancellation export correctly without date shifts.
- P31_A2: Guest/other-unit user cannot see private event title/location through calendar counts.
- P31_A3: Add-to-calendar is labeled copy and never claims continuous synchronization.

Update docs/build/steps/P31.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P32: Publish guides, glossary and an inclusive onboarding hub

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/resources/*; src/features/onboarding/*; supabase/migrations/*resources.sql

**Interfaces:** Versioned resources/glossary and onboarding_progress use owner/review dates, visibility, checklist version and stable term aliases.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P32: Publish guides, glossary and an inclusive onboarding hub.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F14/F13; section 12 rollout.
Code/interface prerequisites: P31, P06. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/resources/*; src/features/onboarding/*; supabase/migrations/*resources.sql

Interfaces / invariants:
Versioned resources/glossary and onboarding_progress use owner/review dates, visibility, checklist version and stable term aliases.

Implement and verify this bounded slice:
1. Build Start Here checklist, contextual acronym explanations, service/process guides, who's-who links and practice sandbox task/request.
2. Provide head/publisher authoring with drafts, safe content, review reminders, ownership and published version. Treat MEA expansion as unconfirmed until supplied.
3. Allow skipped optional tours, late joiners and incomplete-task empty states; all core backgrounds receive equal guidance.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P32_A1: A member with no affiliation/course disclosure can complete essential onboarding.
- P32_A2: Renamed glossary label retains old alias and links without breaking forms.
- P32_A3: Restricted resource/file does not become public through guide links or preview; sandbox never submits a real FIN case.

Update docs/build/steps/P32.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P33: Manage roster, deployments, unit rename/merge/archive

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/organization/*; supabase/migrations/*organization_commands.sql; supabase/tests/unit_changes.test.sql

**Interfaces:** Organization commands preview impact, preserve UUID/history, reassign active work explicitly and create aliases; deployments are scoped dated grants.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P33: Manage roster, deployments, unit rename/merge/archive.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F13/F22; section 6 organization changes.
Code/interface prerequisites: P32. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/organization/*; supabase/migrations/*organization_commands.sql; supabase/tests/unit_changes.test.sql

Interfaces / invariants:
Organization commands preview impact, preserve UUID/history, reassign active work explicitly and create aliases; deployments are scoped dated grants.

Implement and verify this bounded slice:
1. Build add/edit/archive unit and roster/deployment screens with active owners and service contacts. Avoid hardcoding the illustrative eight committees.
2. Implement rename/merge impact preview including open work, active reviewers and access deltas; old records preserve original unit identity.
3. Require replacement for orphaned active ownership/approval; merge does not silently union all privileges or move restricted case contents.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P33_A1: Renaming MCD/unit keeps original tracking IDs and deep links.
- P33_A2: Merge cannot unexpectedly grant another committee access to FIN/PRISM or historical private tasks.
- P33_A3: Archiving a head/unit with active cases either assigns an authorized replacement or leaves explicit blocked work.

Update docs/build/steps/P33.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P34: Build safe role editing and access explanations

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/access/*; supabase/migrations/*delegation.sql; supabase/tests/delegation.test.sql

**Interfaces:** Role administration chooses fixed resource/action/scope capabilities, dated assignments and delegation ceilings; preview explains effective access without real impersonation.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P34: Build safe role editing and access explanations.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F26; section 3 matrix.
Code/interface prerequisites: P33. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/access/*; supabase/migrations/*delegation.sql; supabase/tests/delegation.test.sql

Interfaces / invariants:
Role administration chooses fixed resource/action/scope capabilities, dated assignments and delegation ceilings; preview explains effective access without real impersonation.

Implement and verify this bounded slice:
1. Build roles/permission grid, unit/record scope assignment, expiry, revoke and audit history for authorized grantors.
2. Protect last super admin, sensitive-review capabilities, emergency access boundary and no self-escalation; distinguish app roles from provider-console ownership.
3. Provide synthetic role preview and access-explanation results with current grants/mandatory constraints; no administrative read-all endpoint.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P34_A1: Delegated head cannot grant FIN/PRISM/admin beyond grantor ceiling or edit own privileges upward.
- P34_A2: Last technical custodian cannot be removed without a verified replacement path.
- P34_A3: Membership/role expiry is honored immediately; synthetic preview cannot expose another user's real sensitive record.

Update docs/build/steps/P34.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P35: Implement shared configuration draft, validation and publication

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/config/*; supabase/migrations/*config_versions.sql; supabase/tests/config_publish.test.sql

**Interfaces:** publish_configuration(expectedVersion, idempotencyKey) creates immutable version; rollback creates a new version and revalidates privilege/invariants.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P35: Implement shared configuration draft, validation and publication.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 configuration contract.
Code/interface prerequisites: P34, P19. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/config/*; supabase/migrations/*config_versions.sql; supabase/tests/config_publish.test.sql

Interfaces / invariants:
publish_configuration(expectedVersion, idempotencyKey) creates immutable version; rollback creates a new version and revalidates privilege/invariants.

Implement and verify this bounded slice:
1. Establish supported configuration kinds and draft storage, version history, diff, validation, synthetic preview and explicit publish.
2. Validate same-term references, capability ceilings, reserved semantics and required gates before activation; preserve pinned historical requests.
3. Add conflict handling for simultaneous editors and canonical audit/outbox publication. No arbitrary JSON console bypass for business users.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P35_A1: Invalid/missing references or removed mandatory FIN/MCD gate cannot publish.
- P35_A2: Two administrators cannot overwrite each other's published version silently.
- P35_A3: Rollback preserves intervening history and never rewrites open cases' pinned workflow/schema.

Update docs/build/steps/P35.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P36: Build the no-code request form editor

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/forms/*; src/features/forms/*; supabase/tests/form_publication.test.sql

**Interfaces:** Editor produces the same FormDefinition accepted by P20, preserving stable keys/options and routing confidential payloads correctly.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P36: Build the no-code request form editor.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 Form builder.
Code/interface prerequisites: P35, P20. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/forms/*; src/features/forms/*; supabase/tests/form_publication.test.sql

Interfaces / invariants:
Editor produces the same FormDefinition accepted by P20, preserving stable keys/options and routing confidential payloads correctly.

Implement and verify this bounded slice:
1. Implement field/section add/edit/reorder/remove-draft, supported types, help, required conditions, options and repeatable lines with keyboard controls.
2. Add synthetic preview and schema validation; enforce limits and fixed operators. Reserved finance/approval values remain typed protected fields.
3. Publish through P35; show impact on drafts and explicit migration rather than changing submitted data. Explain why confidential fields need restricted storage/type.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P36_A1: Renaming a label does not change stored field key/old answer meaning.
- P36_A2: A confidential custom field cannot publish into broad ordinary JSON.
- P36_A3: Published old form submissions remain readable under their version; unsafe condition/code and excessive schema size fail.

Update docs/build/steps/P36.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P37: Build the bounded workflow and approval editor

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/workflows/*; supabase/tests/workflow_publication.test.sql

**Interfaces:** Workflow editor emits P22-compatible sequential stable stages, one/all eligible reviewers, revision routes and bounded conditions; publication uses P35.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P37: Build the bounded workflow and approval editor.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22; section 6 workflow engine.
Code/interface prerequisites: P36, P22. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/workflows/*; supabase/tests/workflow_publication.test.sql

Interfaces / invariants:
Workflow editor emits P22-compatible sequential stable stages, one/all eligible reviewers, revision routes and bounded conditions; publication uses P35.

Implement and verify this bounded slice:
1. Implement stage ordering, reviewer/role/scope resolution, required evidence, decision routes, authorized delegates and reminder settings.
2. Preview synthetic cases including requester conflict and missing authority; show open cases pinned to previous versions.
3. Reject unbounded loops, unsafe scripts, nonexistent approvers and configurations bypassing FIN/MCD protected policy. No generic BPM product.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P37_A1: Head can configure a service review without editing source code.
- P37_A2: Removing a required financial/creative authority or assigning only requester as reviewer fails publication.
- P37_A3: New version applies to new instances; an active old case continues or explicitly migrates with audited authority.

Update docs/build/steps/P37.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P38: Edit phases, semantic statuses and service routing

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/admin/phases/*; src/features/admin/statuses/*; src/features/admin/services/*

**Interfaces:** Admin controls edit display labels/order, phase dates and service contacts while stable IDs/semantic categories remain authoritative.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P38: Edit phases, semantic statuses and service routing.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F08; section 6 configuration table.
Code/interface prerequisites: P37. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/phases/*; src/features/admin/statuses/*; src/features/admin/services/*

Interfaces / invariants:
Admin controls edit display labels/order, phase dates and service contacts while stable IDs/semantic categories remain authoritative.

Implement and verify this bounded slice:
1. Add phase management and current-phase display; validate active phase selection and date order without assuming prototype phase names.
2. Add status-label/color/order editor with protected semantics and accessible contrast; cannot turn a pending state into an approved decision.
3. Add service name/description, receiving unit, primary/backup contacts, official form link, lead-time text and guest eligibility with impact validation.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P38_A1: Renamed PRISM/status/phase does not change authority, routes or historical meaning.
- P38_A2: Invalid phase date range or inactive required contact is reported before publish.
- P38_A3: A status called Approved without a valid decision still fails readiness; published copy updates through versioned config.

Update docs/build/steps/P38.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P39: Implement general site Edit Mode, labels and branding

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/admin/site/*; src/features/admin/branding/*; src/app/*; src/styles/tokens.css

**Interfaces:** Site pages use safe block catalog and label/theme config via P35; approved-logo asset separate from interface font/accent.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P39: Implement general site Edit Mode, labels and branding.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F25; section 11 brand/accessibility.
Code/interface prerequisites: P38, P01. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/site/*; src/features/admin/branding/*; src/app/*; src/styles/tokens.css

Interfaces / invariants:
Site pages use safe block catalog and label/theme config via P35; approved-logo asset separate from interface font/accent.

Implement and verify this bounded slice:
1. Implement authenticated contextual Edit Mode for supported text/link/card blocks, navigation wording/order, guide copy and branding tokens.
2. Add draft/preview/diff/publish/revert and role-aware synthetic previews. Keep licensed logo shape/name/color protected by approved-asset selection and MCD review record.
3. Check contrast and focus visibility; keep Karla/calm tokens by default. No arbitrary HTML/CSS/JavaScript injection or fresh decorative redesign.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P39_A1: Typing in Edit Mode is private until publish and rollback records a new version.
- P39_A2: Renaming labels does not break deep links, workflow semantics or permission keys.
- P39_A3: Unsafe block content or inaccessible token combination is rejected/warned with a concrete repair; ordinary members cannot enter editor.

Update docs/build/steps/P39.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P40: Configure widgets and layouts by role

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/admin/layouts/*; src/features/overview/*; src/app/widgetCatalog.ts

**Interfaces:** Role/unit layout config selects fixed widget IDs and supported options; each widget independently queries authorized data.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P40: Configure widgets and layouts by role.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F22/F02; section 6 widget catalog.
Code/interface prerequisites: P39, P30, P31. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/layouts/*; src/features/overview/*; src/app/widgetCatalog.ts

Interfaces / invariants:
Role/unit layout config selects fixed widget IDs and supported options; each widget independently queries authorized data.

Implement and verify this bounded slice:
1. Implement role layouts, responsive placement/order/size, saved operational views and preview. Provide keyboard Move Up/Down, not drag-only controls.
2. Offer existing task/waiting/deliverables/synergy/review/calendar/resource widgets only; optional-module widgets appear only when enabled.
3. Retain a required route/action path so layout cannot hide all next actions; prevent arbitrary SQL/query definition.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P40_A1: A member cannot obtain FIN data by adding a FIN widget to a layout.
- P40_A2: Same layout remains usable on 320px screen and with keyboard reordering.
- P40_A3: Missing/retired widget produces a clear safe fallback and configuration validation, not a broken dashboard.

Update docs/build/steps/P40.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P41: Configure notification rules, schedules and preferences

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/notifications/*; src/features/notifications/preferences/*; supabase/functions/notification-scheduler/*

**Interfaces:** Rules select fixed events/audiences/channels with dedup, bounded schedule and Manila quiet hours; delivery preference does not remove required work.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P41: Configure notification rules, schedules and preferences.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F19/F22; section 6 notification settings.
Code/interface prerequisites: P40, P30. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/notifications/*; src/features/notifications/preferences/*; supabase/functions/notification-scheduler/*

Interfaces / invariants:
Rules select fixed events/audiences/channels with dedup, bounded schedule and Manila quiet hours; delivery preference does not remove required work.

Implement and verify this bounded slice:
1. Add admin rules, recipient dry-run, safe templates, due/overdue reminders, digest/mute choices and channel availability.
2. Implement default two-days-before/due-day/daily-overdue scheduling and 20:00–08:00 quiet period as editable proposals, using tested Manila dates.
3. Use durable deduplication and outbox dispatch; external channels remain disabled until configured/verified in optional steps.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P41_A1: Scheduler retry/window overlap creates no duplicate digest or reminder.
- P41_A2: Muted external delivery does not hide the in-app pending obligation.
- P41_A3: Recipient preview respects access; private payload cannot be inserted into external-message templates.

Update docs/build/steps/P41.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P42: Publish scoped announcements and acknowledgments

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/features/announcements/*; supabase/migrations/*announcements.sql; supabase/tests/announcements.test.sql

**Interfaces:** Published announcement has audience, immutable revisions, pin/expiry, publisher and acknowledgments against material revision.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P42: Publish scoped announcements and acknowledgments.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F18; section 3 publishing.
Code/interface prerequisites: P41, P32. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/announcements/*; supabase/migrations/*announcements.sql; supabase/tests/announcements.test.sql

Interfaces / invariants:
Published announcement has audience, immutable revisions, pin/expiry, publisher and acknowledgments against material revision.

Implement and verify this bounded slice:
1. Build draft/publish/edit/pin/expire and core/committee audience selection for authorized publishers.
2. Add acknowledgment and material-edit renewed acknowledgment without treating it as a legal waiver.
3. Wire overview/inbox and private file visibility. Guests need explicit share; resource-draft ability is not announcement publisher authority.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P42_A1: Other committee/guest cannot enumerate unshared announcement contents or counts.
- P42_A2: Materially edited announcement does not reuse prior acknowledgment silently.
- P42_A3: Narrower attachment remains restricted even when announcement audience is wider.

Update docs/build/steps/P42.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P43: Implement permission-filtered keyword search

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/search/*; supabase/migrations/*search.sql; supabase/tests/search_access.test.sql

**Interfaces:** search_workspace(query, filters, cursor) applies authorization before snippets/counts across operational titles/IDs, guides and allowed contacts.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P43: Implement permission-filtered keyword search.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F20; section 3 search rules.
Code/interface prerequisites: P42, P33. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/search/*; supabase/migrations/*search.sql; supabase/tests/search_access.test.sql

Interfaces / invariants:
search_workspace(query, filters, cursor) applies authorization before snippets/counts across operational titles/IDs, guides and allowed contacts.

Implement and verify this bounded slice:
1. Add suitable PostgreSQL full-text/trigram indexes and exact term-aware tracking lookup; support renamed-unit aliases.
2. Build categorized accessible results, empty/error states and safe restricted-result behavior.
3. Exclude finance raw payload, evaluations, private profile fields and attachment extraction from global index. No external AI search.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P43_A1: Searching a known private title/amount/contact or restricted ID reveals no existence/count/snippet.
- P43_A2: Exact ID distinguishes terms and maps renamed unit aliases without collisions.
- P43_A3: Typeahead/keyboard/mobile behavior works; SQL parameters and pagination cannot widen scope.

Update docs/build/steps/P43.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P44: Build workload, readiness and meaningful-usage reports

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/reports/*; supabase/migrations/*reports.sql; docs/analytics.md

**Interfaces:** Scoped SQL reports use documented event allowlist and Monday–Sunday Manila periods; minimal first-party events, no sensitive bodies.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P44: Build workload, readiness and meaningful-usage reports.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F21; section 14 metrics.
Code/interface prerequisites: P43, P29. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/reports/*; supabase/migrations/*reports.sql; docs/analytics.md

Interfaces / invariants:
Scoped SQL reports use documented event allowlist and Monday–Sunday Manila periods; minimal first-party events, no sensitive bodies.

Implement and verify this bounded slice:
1. Implement readiness, overdue/original dates, blocked duration, queue age, handoff/approval turnaround and assigned workload with clear definitions.
2. Add meaningful weekly active numerator/eligible-core denominator, excluding guests/tests/bots; instrument safe work views/actions and retention for usage events.
3. Restrict supervisory breakdowns and exports; no public member ranking, affiliation comparison or fake utilization percentages.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P44_A1: At 89 eligible members, at least 72 meaningful active members meets 80%; logins/bot pings alone do not.
- P44_A2: Multi-unit users are counted once and Manila week boundary is correct.
- P44_A3: Changing deadline does not erase original overdue history; small/private groups do not reveal protected records.

Update docs/build/steps/P44.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P45: Add previewed Sheets-compatible CSV import and scoped export

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/imports/*; src/features/exports/*; supabase/functions/imports/*; src/features/imports/csv.test.ts

**Interfaces:** Import preview/mapping/validation commits through authorized existing commands with stable IDs; export uses effective scope and spreadsheet-safe values.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P45: Add previewed Sheets-compatible CSV import and scoped export.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F23/F13/F21; section 10 Sheets.
Code/interface prerequisites: P44, P33. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/imports/*; src/features/exports/*; supabase/functions/imports/*; src/features/imports/csv.test.ts

Interfaces / invariants:
Import preview/mapping/validation commits through authorized existing commands with stable IDs; export uses effective scope and spreadsheet-safe values.

Implement and verify this bounded slice:
1. Support roster/tasks import templates, row-level error report, deduplication, dry-run and confirmation of exact mapped changes.
2. Do not turn role columns or imported identity fields into unreviewed privileges; sensitive financial imports use separate authorized template/reconciliation.
3. Export permitted operations with stable IDs and neutralize spreadsheet formula prefixes; preserve dates/UTF-8/newlines correctly. No bidirectional Sheets sync.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P45_A1: Repeated import does not duplicate records and partial errors are reported consistently with chosen atomicity.
- P45_A2: CSV containing =,+,-,@ formula payloads cannot execute when opened in a spreadsheet as exported user content.
- P45_A3: Unauthorized export/import changes fail; role field cannot grant admin and unrelated private rows never appear.

Update docs/build/steps/P45.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P46: Implement privacy notice, restricted access logs and retention controls

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** src/features/admin/privacy/*; supabase/migrations/*retention.sql; supabase/functions/privacy-requests/*; docs/privacy-and-retention.md

**Interfaces:** Versioned privacy notice, category retention_rules, legal_holds, auditable access/export and timed emergency grants; routine private reads use audited restricted endpoints.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P46: Implement privacy notice, restricted access logs and retention controls.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F16/F24/F26; section 11 privacy/retention.
Code/interface prerequisites: P45, P34. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/privacy/*; supabase/migrations/*retention.sql; supabase/functions/privacy-requests/*; docs/privacy-and-retention.md

Interfaces / invariants:
Versioned privacy notice, category retention_rules, legal_holds, auditable access/export and timed emergency grants; routine private reads use audited restricted endpoints.

Implement and verify this bounded slice:
1. Build notice/optional sharing acknowledgments, custodian request intake, authorized access/correction/export handling, retention policy configuration and hold review.
2. Implement dry-run disposition/purge planning without running live deletion; distinguish archive from erasure, preserve necessary minimal ledger and restore replay.
3. Add time-bounded emergency access with reason/notification and no routine broad admin contents. Block sensitive-module activation without owner/basis/retention decisions.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P46_A1: Legal hold prevents scheduled disposal and dry-run lists affected records/files without exposing their contents.
- P46_A2: Admin cannot silently self-grant indefinite raw FIN/PRISM access through UI.
- P46_A3: All normal restricted reads/exports are logged through authorized endpoints; raw sensitive payloads/tokens do not enter telemetry.

Update docs/build/steps/P46.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P47: Implement encrypted backup and prove identity/file recovery

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** scripts/backup/*; scripts/restore/*; docs/recovery.md; src/features/admin/health/*

**Interfaces:** Backup manifest covers app data/config, schema, file bytes/hashes, identity linkage recovery, retention/purge replay and separate key custody; freshness visible to custodians.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P47: Implement encrypted backup and prove identity/file recovery.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F24/F26; section 11 recovery.
Code/interface prerequisites: P46, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
scripts/backup/*; scripts/restore/*; docs/recovery.md; src/features/admin/health/*

Interfaces / invariants:
Backup manifest covers app data/config, schema, file bytes/hashes, identity linkage recovery, retention/purge replay and separate key custody; freshness visible to custodians.

Implement and verify this bounded slice:
1. Implement documented encrypted export and verify tools' actual Auth/Storage inclusion/exclusion. Keep backups/secrets out of Git artifacts and ordinary member folders.
2. Add restoration into an explicitly verified isolated local/authorized recovery target; preserve stable member IDs or test verified provider re-linking.
3. Rehearse login, permissions, immutable decisions/files and purge replay; record actual RPO/RTO, missing prerequisites and second-custodian runbook. Do not invent a successful rehearsal.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P47_A1: Restored user can log in to correct scope; unauthorized user cannot read recovered private files.
- P47_A2: Manifest counts/file hashes match and expired/purged data does not silently resurrect.
- P47_A3: Stale/failed backup appears in health; missing device/provider/key makes verification blocked, not green.

Update docs/build/steps/P47.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P48: Verify essential mobile flows and add a safe PWA shell

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Core

**Files:** src/app/*; public/manifest.webmanifest; service-worker configuration; tests/e2e/accessibility.spec.ts; docs/accessibility.md

**Interfaces:** Installable shell caches public assets only; responsive and keyboard behavior applies to implemented work/review/admin flows.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P48: Verify essential mobile flows and add a safe PWA shell.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F25; section 11 accessibility; section 14 tests.
Code/interface prerequisites: P47. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/app/*; public/manifest.webmanifest; service-worker configuration; tests/e2e/accessibility.spec.ts; docs/accessibility.md

Interfaces / invariants:
Installable shell caches public assets only; responsive and keyboard behavior applies to implemented work/review/admin flows.

Implement and verify this bounded slice:
1. Add manifest/install affordance and useful offline state without caching authenticated APIs, files, OAuth callbacks or private drafts.
2. Audit 320px/zoom, visible focus/contrast, modal focus, labels/errors, screen-reader updates and keyboard alternatives in actual essential flows.
3. Fix discovered barriers in shared components and targeted screens; capture real screenshots/check results with synthetic data. Do not redesign the app.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P48_A1: Signing out/offline cannot expose previous user's finance/task payload or service-worker cache.
- P48_A2: Keyboard-only user completes task, handoff and review; mobile controls remain 44px and usable at 200% zoom.
- P48_A3: Automated axe plus manual evidence recorded; no blanket WCAG certification based only on an automated scan.

Update docs/build/steps/P48.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P49: Prepare Cloudflare/Supabase release and deploy a synthetic preview

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core

**Files:** Cloudflare build/headers config; .env.example; docs/deployment.md; docs/integrations.md; deployment verification scripts

**Interfaces:** Reproducible static build plus explicit environment matrix/redirects/secrets references, verified migration plan and rollback; preview and production remain isolated.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P49: Prepare Cloudflare/Supabase release and deploy a synthetic preview.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F26; sections 9/10/11; roadmap v1 readiness.
Code/interface prerequisites: P48. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
Cloudflare build/headers config; .env.example; docs/deployment.md; docs/integrations.md; deployment verification scripts

Interfaces / invariants:
Reproducible static build plus explicit environment matrix/redirects/secrets references, verified migration plan and rollback; preview and production remain isolated.

Implement and verify this bounded slice:
1. Prepare Cloudflare Pages static build/routing/headers/CSP and Supabase environment/provider settings, migration order, capacity check, credential custody and rollback instructions.
2. Deploy synthetic preview only to an existing explicitly identified organization-controlled preview target when access is available. This prompt authorizes that named preview deployment; request missing target selection rather than guessing.
3. Verify external auth redirects, denied anonymous APIs, secret-free bundle and source/project ownership. Produce production candidate package, not automatic real-data rollout.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P49_A1: Fresh clean build runs on preview; SPA deep links and correct OAuth return work or exact provider block is recorded.
- P49_A2: Preview contains synthetic data only; client bundle has no elevated credentials and private APIs remain protected.
- P49_A3: Production target and backup/migration/rollback prerequisites are documented without running destructive remote commands.

Update docs/build/steps/P49.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P50: Run the core pilot release gate and prepare human UAT

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Core gate

**Files:** tests/e2e/core-pilot.spec.ts; docs/uat/*; docs/build/release-gate.md; feature fixes as justified

**Interfaces:** Reproducible synthetic core slice and a human-test checklist with separate observed/automated/human-pending results.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P50: Run the core pilot release gate and prepare human UAT.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01–F14 core subset/F19/F22–F26; sections 12/14.
Code/interface prerequisites: P49. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
tests/e2e/core-pilot.spec.ts; docs/uat/*; docs/build/release-gate.md; feature fixes as justified

Interfaces / invariants:
Reproducible synthetic core slice and a human-test checklist with separate observed/automated/human-pending results.

Implement and verify this bounded slice:
1. Exercise school member/head/FIN/MCD/guest flows: deliverable -> synergy -> task/dependency -> handoff -> versioned reviews -> acceptance, including required denials.
2. Prepare role-specific UAT scripts for both MEAn and non-MEAn participants, first-task guidance, steward instructions, privacy gate and defect triage.
3. Fix supported P0/P1 implementation defects within this session budget. Human UAT needs actual user evidence; do not fabricate participants, feedback or approvals and do not send invitations/messages.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P50_A1: Core happy path and negative access/revision/self-approval cases pass with release revision recorded.
- P50_A2: Human results remain pending until observed; zero open P0/P1 is required for a green release gate.
- P50_A3: Actual restore, relevant school authority/privacy decisions and named custodians are verified or explicitly listed as blockers.

Update docs/build/steps/P50.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P51: Connect scoped Google Drive selection

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/integrations/drive/*; supabase/functions/google-oauth/*; docs/integrations.md

**Interfaces:** Separate Drive OAuth connection and Picker use drive.file or least necessary scope; server-only refresh-token storage, revoke/reconnect and selected-file metadata.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P51: Connect scoped Google Drive selection.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F23; section 10 Drive levels.
Code/interface prerequisites: P49, P45, P12. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/drive/*; supabase/functions/google-oauth/*; docs/integrations.md

Interfaces / invariants:
Separate Drive OAuth connection and Picker use drive.file or least necessary scope; server-only refresh-token storage, revoke/reconnect and selected-file metadata.

Implement and verify this bounded slice:
1. Implement explicit Connect Drive consent separate from login, approved redirect/state checks and provider-owner custody. No all-drive crawling.
2. Add Picker-based selected files for authorized work, validating provider IDs, current record permission and selected file access.
3. Handle school admin denial, revoked scopes and testing-mode token expiry; retain working link/private upload fallback.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P51_A1: Client receives no refresh token/client secret and cannot nominate arbitrary unselected Drive files for broad reads.
- P51_A2: Different dashboard member cannot use connection to bypass their record/file access.
- P51_A3: Real selected-file flow verified if school/provider setup exists; otherwise adapter code/local tests marked external-blocked, not fully integrated.

Update docs/build/steps/P51.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P52: Export selected final evidence safely between app and Drive

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/integrations/drive/exports/*; supabase/functions/drive-export/*; docs/drive-custody.md

**Interfaces:** User-triggered rendition/export creates new immutable app asset/Drive copy with manifest and destination classification; source and approved snapshot stay distinct.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P52: Export selected final evidence safely between app and Drive.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F23/F10/F24; section 10 Drive custody.
Code/interface prerequisites: P51, P28, P46, P47. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/drive/exports/*; supabase/functions/drive-export/*; docs/drive-custody.md

Interfaces / invariants:
User-triggered rendition/export creates new immutable app asset/Drive copy with manifest and destination classification; source and approved snapshot stay distinct.

Implement and verify this bounded slice:
1. Export explicitly selected Google-native final rendition into private app evidence, hashing bytes and binding caption/use in the submitted revision.
2. Implement authorized selected-file/data copy into approved Drive folder with current destination-permission check and audit. Separate FIN/PRISM destinations; no membership-wide sensitive mirroring.
3. Add resumable progress/error handling and duplicate-copy prevention; preserve originals until a verified archival disposition.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P52_A1: Changed Drive/Canva source cannot rewrite approved app snapshot or retained decision hash.
- P52_A2: Private FIN/PRISM file cannot be copied into broader folder without explicit authorized reclassification/policy; deny unsafe destination.
- P52_A3: Retry does not create endless duplicate files; revoked destination access yields clear recoverable failure.

Update docs/build/steps/P52.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P53: Implement one-way core-calendar publishing

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/integrations/calendar/*; supabase/functions/calendar-sync/*; supabase/migrations/*calendar_mappings.sql

**Interfaces:** App remains authoritative; explicit core-safe app events map to one approved core calendar, with source version, remote IDs, tombstones and durable token lifecycle.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P53: Implement one-way core-calendar publishing.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F12; section 10 Calendar sync.
Code/interface prerequisites: P49, P31, P30. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/calendar/*; supabase/functions/calendar-sync/*; supabase/migrations/*calendar_mappings.sql

Interfaces / invariants:
App remains authoritative; explicit core-safe app events map to one approved core calendar, with source version, remote IDs, tombstones and durable token lifecycle.

Implement and verify this bounded slice:
1. Implement separately authorized connection and explicit app-to-Google publish/update/cancel jobs; document external-edit conflict policy.
2. Add idempotent mapping, retry/backoff, revoked-auth repair, last-sync/error view, and safe token storage. No private task/mentee/finance data in general calendar.
3. If reconciliation reads use incremental tokens, handle HTTP410 by rebuilding mapped remote cache without deleting canonical app events.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P53_A1: Create/update/retry/cancel results in one correctly timed remote event, no resurrection after tombstone.
- P53_A2: Expired/testing/revoked token shows stale state and fallback; never claims synced after failure.
- P53_A3: Private event/export preferences cannot leak through shared calendar title/description/location.

Update docs/build/steps/P53.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P54: Add opt-in Telegram alerts without reading group chats

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/integrations/telegram/*; supabase/functions/telegram-webhook/*; supabase/functions/notification-adapters/*

**Interfaces:** One-time account-link code binds started bot chat to authenticated member; webhook secret validation and minimal outbox adapter.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P54: Add opt-in Telegram alerts without reading group chats.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F19; section 10 Telegram.
Code/interface prerequisites: P41, P46, P49. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/telegram/*; supabase/functions/telegram-webhook/*; supabase/functions/notification-adapters/*

Interfaces / invariants:
One-time account-link code binds started bot chat to authenticated member; webhook secret validation and minimal outbox adapter.

Implement and verify this bounded slice:
1. Build opt-in link/unlink flow after member starts bot; hash short-lived binding code and prevent chat takeover/reuse.
2. Implement authenticated provider webhook handling and dispatch safe generic restricted alerts with deep links, quiet-hours/digest preferences and bounded retries.
3. Provide failure/relink status; no group-chat scraping, automatic personal-account messaging or unrequested announcements.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P54_A1: Stolen/expired/reused linking code cannot attach another member; invalid webhook source rejected.
- P54_A2: Revoked member or removed channel stops new deliveries and cannot open protected deep link.
- P54_A3: Repeated dispatch deduplicates logically and carries no private financial/evaluation contents.

Update docs/build/steps/P54.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P55: Add a verified email sender and optional non-Google guest login

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/integrations/email/*; supabase/functions/email-adapter/*; src/features/auth/*; docs/email-operations.md

**Interfaces:** Approved sender with tested quota/domain and server-only credentials; optional guest OTP identity must still redeem exact invite and scope.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P55: Add a verified email sender and optional non-Google guest login.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F01/F19; section 10 email/SMTP.
Code/interface prerequisites: P05, P41, P46, P49. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/integrations/email/*; supabase/functions/email-adapter/*; src/features/auth/*; docs/email-operations.md

Interfaces / invariants:
Approved sender with tested quota/domain and server-only credentials; optional guest OTP identity must still redeem exact invite and scope.

Implement and verify this bounded slice:
1. Connect existing approved free/organization sender only; implement minimal digest/transactional adapter with rate caps, dedup, retry and delivery health. No assumed Supabase default SMTP production service.
2. If provider delivery is verified, add email OTP/magic-link guest entry with verified address, single-use exact invitation and safe return URL. Do not activate it on an untested sender.
3. Handle bounce/quota/revocation and identity-linking/account-takeover risks; leave in-app/Google/manual invite link fallback working.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P55_A1: Wrong email/expired invite/OTP replay cannot gain guest access; unverified email cannot link to existing school member.
- P55_A2: Sensitive email is generic with authenticated link and never contains receipt/feedback text.
- P55_A3: Missing sender/DNS/quota blocks external verification and activation rather than returning fake sent messages.

Update docs/build/steps/P55.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P56: Implement conflict-safe Logistics room booking

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** supabase/migrations/*room_booking.sql; supabase/tests/room_booking.test.sql; src/features/rooms/api.ts

**Interfaces:** confirm_booking enforces official evidence and database exclusion over room/buffered half-open range for confirmed/persisted active holds.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P56: Implement conflict-safe Logistics room booking.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F11; section 8 rooms/bookings.
Code/interface prerequisites: P22, P31, P38. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*room_booking.sql; supabase/tests/room_booking.test.sql; src/features/rooms/api.ts

Interfaces / invariants:
confirm_booking enforces official evidence and database exclusion over room/buffered half-open range for confirmed/persisted active holds.

Implement and verify this bounded slice:
1. Model rooms/accessibility/equipment and requests, expiring holds, confirmation and cancellation with Logistics authority.
2. Expire stale holds in confirmation transaction and serialize competing transitions; a worker is not sole protection against stuck holds.
3. Require external school reservation evidence or official not-required policy; create calendar source only for confirmed room.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P56_A1: Two concurrent overlapping confirmations cannot both succeed; adjacent nonbuffered slots behave correctly.
- P56_A2: Expired hold cannot block indefinitely if scheduler is down; setup/cleanup buffers count.
- P56_A3: Request submission or a calendar event alone cannot masquerade as official room reservation.

Update docs/build/steps/P56.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P57: Build room intake, Logistics confirmation and calendar views

**Model / effort:** GPT-6.1 Sol · Medium

**Phase:** Optional v2

**Files:** src/features/rooms/*; src/features/calendar/*; src/features/requests/*

**Interfaces:** Room UI uses P56 commands, showing desired vs confirmed slot, evidence and conflict/alternative negotiation.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P57: Build room intake, Logistics confirmation and calendar views.
Recommended setting: GPT-6.1 Sol · Medium.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F11/F12; section 7 room flow.
Code/interface prerequisites: P56. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/rooms/*; src/features/calendar/*; src/features/requests/*

Interfaces / invariants:
Room UI uses P56 commands, showing desired vs confirmed slot, evidence and conflict/alternative negotiation.

Implement and verify this bounded slice:
1. Build accessible room/time/requirements request, Logistics availability/conflict view and alternative-slot acceptance.
2. Add official reference/evidence, confirmed/cancelled details and linked calendar entry. Initial recurring sessions are separate explicit instances.
3. Handle stale availability and concurrent-conflict response without false confirmation or losing requester's safe input.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P57_A1: Mobile/keyboard requester can submit and distinguish pending from confirmed.
- P57_A2: Change/cancel updates actual reservation/calendar without stale duplicates.
- P57_A3: Unauthorized role cannot confirm, and private meeting details remain scoped despite room availability display.

Update docs/build/steps/P57.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P58: Build SUS inventory reservation, checkout and return

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/inventory/*; supabase/migrations/*inventory.sql; supabase/tests/inventory.test.sql

**Interfaces:** Item master, custodians and immutable quantity/condition movements; atomic reserve/issue/partial-return/cancel, FIN linkage for costs.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P58: Build SUS inventory reservation, checkout and return.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F17/F09; section 5 inventory.
Code/interface prerequisites: P33, P26, P46. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/inventory/*; supabase/migrations/*inventory.sql; supabase/tests/inventory.test.sql

Interfaces / invariants:
Item master, custodians and immutable quantity/condition movements; atomic reserve/issue/partial-return/cancel, FIN linkage for costs.

Implement and verify this bounded slice:
1. Add stock/borrower/dates/condition/location schema and authorized request/custodian screens with simple ledger rather than overwritable available count.
2. Implement concurrent reservation, physical issue confirmation, returns, partial returns and loss/damage notes with evidence.
3. Distinguish consumables from returnable items; route purchase/replacement costs to FIN and queue departed-custodian reassignment.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P58_A1: Simultaneous borrowers cannot reserve more than available and repeat return cannot inflate stock.
- P58_A2: Partial return/lost item yields consistent balance/condition/audit rather than silent negative inventory.
- P58_A3: Replacement expense cannot be approved by inventory role without FIN authority; unauthorized borrower details stay private.

Update docs/build/steps/P58.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P59: Build opt-in goals and scoped mentor check-ins

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional v2

**Files:** src/features/growth/*; supabase/migrations/*mentoring.sql; supabase/tests/mentoring.test.sql

**Interfaces:** mentorships have approved effective dates; owned goals/sharing and author-attributed check-ins are separate from evaluations.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P59: Build opt-in goals and scoped mentor check-ins.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F15; section 3 goals and mentoring.
Code/interface prerequisites: P06, P32, P46. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/growth/*; supabase/migrations/*mentoring.sql; supabase/tests/mentoring.test.sql

Interfaces / invariants:
mentorships have approved effective dates; owned goals/sharing and author-attributed check-ins are separate from evaluations.

Implement and verify this bounded slice:
1. Build goals, target/progress and sharing choice, assigned-mentor list, check-in schedule/actions and attributable notes.
2. Enforce relationship expiry/reassignment and withdrawal of sharing; mentor cannot edit mentee's goal wording or read evaluation cases.
3. Connect private check-in calendar only through permitted audience/explicit opt-in export; apply category retention and member export.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P59_A1: Former mentor with live session loses access after relationship expiry/revoke.
- P59_A2: Head/PM/PRISM roles have no automatic raw goal access unless explicit appropriate grant.
- P59_A3: Private check-in title/notes do not leak through core calendar/search/reports.

Update docs/build/steps/P59.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P60: Create restricted evaluation rounds, submissions and release rules

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional sensitive module

**Files:** supabase/migrations/*evaluations.sql; supabase/tests/evaluations.test.sql; src/features/evaluations/api.ts

**Interfaces:** feedback_rounds/submissions/revisions/reviewer notes and separate evaluation_releases; audited restricted RPC reads, no broad table SELECT.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P60: Create restricted evaluation rounds, submissions and release rules.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F16; section 3 feedback; section 11 retention.
Code/interface prerequisites: P22, P46, P47. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
supabase/migrations/*evaluations.sql; supabase/tests/evaluations.test.sql; src/features/evaluations/api.ts

Interfaces / invariants:
feedback_rounds/submissions/revisions/reviewer notes and separate evaluation_releases; audited restricted RPC reads, no broad table SELECT.

Implement and verify this bounded slice:
1. Implement round purpose/template/subject/reviewer/retention/release policy with explicit conflicts and reviewer assignments.
2. Keep author's submitted record immutable, append amendments, separate raw third-party feedback from released subject summary and apply holds/dispositions.
3. Require recorded custodian/basis/retention before real-data activation; use synthetic fixtures and explain anonymity limits.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P60_A1: Subject, mentor, PM and ordinary admin cannot read raw third-party feedback by knowing IDs or querying joins.
- P60_A2: Revoked/conflicted reviewer cannot submit/release; wrong-subject summary cannot be published.
- P60_A3: Restricted reads/downloads/export audit without raw text, and retention respects hold and backup replay.

Update docs/build/steps/P60.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P61: Build PRISM desk, released summaries and safe aggregates

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Optional sensitive module

**Files:** src/features/evaluations/*; src/features/reports/*; tests/e2e/evaluations.spec.ts

**Interfaces:** UI consumes restricted P60 APIs; author/assigned-reviewer/subject-release views distinct; aggregation suppresses groups below five and reconstructive filters.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P61: Build PRISM desk, released summaries and safe aggregates.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F16/F21; section 14 privacy tests.
Code/interface prerequisites: P60, P43, P44. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/evaluations/*; src/features/reports/*; tests/e2e/evaluations.spec.ts

Interfaces / invariants:
UI consumes restricted P60 APIs; author/assigned-reviewer/subject-release views distinct; aggregation suppresses groups below five and reconstructive filters.

Implement and verify this bounded slice:
1. Build feedback submission, assigned PRISM queue, attributable reviewer notes, controlled summary review/release and subject-visible results.
2. Add explicit export control and minimum-group reporting; prevent differencing/drilldown that reconstructs identities.
3. Publish clear anonymity/rights/retention text, route formal complaints to approved school process, and verify no raw content enters global search or notifications.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P61_A1: Subject sees only released summary; author edits produce a revision, not overwritten submitted evidence.
- P61_A2: Groups under five and difference-of-filters reconstruction cannot expose individuals.
- P61_A3: Real sensitive activation stays blocked without actual owner/policy/UAT; screenshots and test fixtures contain synthetic data only.

Update docs/build/steps/P61.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P62: Implement verified term freeze, archive and successor handover

**Model / effort:** GPT-6.1 Sol · High

**Phase:** Required turnover

**Files:** src/features/admin/turnover/*; supabase/migrations/*term_closure.sql; supabase/functions/archive/*; docs/turnover.md

**Interfaces:** freeze_term and run_archive create resumable scoped manifests, records/files dispositions and verification; new-term roles are explicitly regranted.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P62: Implement verified term freeze, archive and successor handover.
Recommended setting: GPT-6.1 Sol · High.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: F24/F26; sections 7/11 turnover and retention.
Code/interface prerequisites: P45, P46, P47, P33, P29. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
src/features/admin/turnover/*; supabase/migrations/*term_closure.sql; supabase/functions/archive/*; docs/turnover.md

Interfaces / invariants:
freeze_term and run_archive create resumable scoped manifests, records/files dispositions and verification; new-term roles are explicitly regranted.

Implement and verify this bounded slice:
1. Build closure checklists per unit/deliverable, unresolved obligation resolution/carry-forward, freeze, classified archive plan and legal holds.
2. Implement resumable records/config/file export with counts/hashes/errors and actual restore sample, plus successor acceptance/custody checklist.
3. Preserve raw FIN/PRISM boundaries; revoke outgoing scopes only through named transfer workflow. Rehearse synthetically now; do not freeze the live term or purge real data just to test.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P62_A1: Missing file/failed hash/unfinished export cannot show turnover complete.
- P62_A2: Frozen term rejects ordinary mutation while controlled correction/retention operations remain audited.
- P62_A3: Successor gets explicitly granted records, not automatic raw evaluations; every record has archive/dispose/hold/carry disposition.

Update docs/build/steps/P62.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```

### Task P63: Audit the integrated build, release eligible scope and hand over

**Model / effort:** GPT-6 Astra · High

**Phase:** Final release gate

**Files:** docs/build/release-gate.md; docs/uat/*; docs/admin-guide.md; docs/deployment.md; docs/recovery.md; docs/turnover.md; targeted fixes/tests

**Interfaces:** Final report names exact release revision, enabled/disabled/externally-blocked modules, security/UAT/recovery evidence, verified production target and successor operations.

- [ ] Read the scoped contract/spec and verify required preceding interfaces.
- [ ] Implement the bounded actions and meaningful regression assertions below.
- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.

```text
Implement P63: Audit the integrated build, release eligible scope and hand over.
Recommended setting: GPT-6 Astra · High. Use GPT-6.1 Sol High if Astra is unavailable or quota is tight.
The human selects the model/effort in the picker; do not spawn another agent or chat to change it.

Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.
Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.
Read only these relevant parts of TEDx-Core-Dashboard-Implementation-Plan.md: Sections 3/6/11/12/14/15; all enabled feature acceptance criteria.
Code/interface prerequisites: P50, P62. Carry real provider/human blockers forward as the contract specifies.

Files (use existing equivalent paths if already established; record mappings):
docs/build/release-gate.md; docs/uat/*; docs/admin-guide.md; docs/deployment.md; docs/recovery.md; docs/turnover.md; targeted fixes/tests

Interfaces / invariants:
Final report names exact release revision, enabled/disabled/externally-blocked modules, security/UAT/recovery evidence, verified production target and successor operations.

Implement and verify this bounded slice:
1. Read current state/contracts and targeted high-risk code, not all files indiscriminately. Audit transitive access, same-term/guest revocation, stale approvals, config privilege changes, outbox, recovery and private exports; add focused regression tests for genuine findings.
2. Reconcile all required F01–F26 coverage against implemented or deliberately disabled optional scope. Verify actual mixed-background human UAT, authority/privacy decisions and restore evidence; do not pretend simulated review is independent security certification.
3. This prompt includes deployment of the tested eligible build to the already identified organization-owned production targets if gates passed, account access exists and migrations/backups/rollback are verified. Ask only for genuinely missing target/input. Otherwise deliver a complete candidate with precise blockers. Prepare head/admin/custodian instructions and event/manual-fallback rehearsal; do not send rollout messages or invoke live end-term closure.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P63_A1: Zero open critical/high release blockers and required checks pass on the actual release revision; no skipped optional module is misreported as complete.
- P63_A2: Production smoke tests, privacy boundaries and OAuth verified if released; otherwise final status explicitly remains candidate/blocked.
- P63_A3: Second-custodian/successor tasks and account custody are recorded; handover requires real acknowledgment, not a generated claim.

Update docs/build/steps/P63.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
