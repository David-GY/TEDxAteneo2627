# P49 — Prepare Cloudflare/Supabase release and deploy a synthetic preview

**Select before sending:** GPT-6.1 Sol · High

**Phase:** Core

Copy the prompt below into the project chat, or ask Codex to execute this file.

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
