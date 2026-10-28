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

Newcomer adoption work (required, in the listed order):
Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. Mapped findings: AD01, AD02, AD03, AD04, AD05, AD06, AD07, AD08, AD09.
- Reconcile every adoption finding and P35-P62 U result against the exact eligible release revision: implemented evidence, observed human result, owner/impact for residual issues, or deliberately disabled optional scope. Recheck the real enabled ordinary-member/guest/head/custodian experience, not a feature count.
- Require actual representative newcomer first-work/contact/service/status/ref/recovery journeys and the original two-minute/90%essential-flow proposed targets, with task results/time/wrong turns/help. Repeat affected checks after material fixes; no green gate from a generated guide or simulated council.
- Prepare short role-specific operating/fallback instructions that match the released screens; include actual second-custodian/successor operation. Essential/high adoption barriers join existing security/privacy/restore/provider blockers before release; if blocked, deliver an honest candidate, not a false deployment claim.
These additions are part of this step, not a request to finish every batch in one execution. Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code.

Implement and verify this bounded slice:
1. Read current state/contracts and targeted high-risk code, not all files indiscriminately. Audit transitive access, same-term/guest revocation, stale approvals, config privilege changes, outbox, recovery and private exports; add focused regression tests for genuine findings.
2. Reconcile all required F01–F26 coverage against implemented or deliberately disabled optional scope. Verify actual mixed-background human UAT, authority/privacy decisions and restore evidence; do not pretend simulated review is independent security certification.
3. This prompt includes deployment of the tested eligible build to the already identified organization-owned production targets if gates passed, account access exists and migrations/backups/rollback are verified. Ask only for genuinely missing target/input. Otherwise deliver a complete candidate with precise blockers. Prepare head/admin/custodian instructions and event/manual-fallback rehearsal; do not send rollout messages or invoke live end-term closure.

Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):
- P63_A1: Zero open critical/high release blockers and required checks pass on the actual release revision; no skipped optional module is misreported as complete.
- P63_A2: Production smoke tests, privacy boundaries and OAuth verified if released; otherwise final status explicitly remains candidate/blocked.
- P63_A3: Second-custodian/successor tasks and account custody are recorded; handover requires real acknowledgment, not a generated claim.

Additional adoption acceptance (preserve A1-A3 above):
Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. Do not add tests that only mirror wording or mark human UAT passed from automation.
- P63_U1: Every AD finding has a truthful disposition and supporting release-revision evidence; unfinished essential usability/accessibility work or missing actual newcomer UAT blocks a green release.
- P63_U2: Production smoke/role instructions agree on readable IDs, applicable review states, working help/first action, disabled modules and safe error recovery; no optional connection or affiliation disclosure is required for essential work.
Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. A plan or new label does not close an adoption finding.

Update docs/build/steps/P63.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.
Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.
If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.
```
