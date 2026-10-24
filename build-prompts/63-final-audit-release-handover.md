# P63 — Audit the integrated build, release eligible scope and hand over

**Select before sending:** GPT-6 Astra · High

**Phase:** Final release gate

Copy the prompt below into the project chat, or ask Codex to execute this file.

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
