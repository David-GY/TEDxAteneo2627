# TEDx app: sequential build prompts

Prepared October 24, 2026. This pack contains **65 implementation prompts: P00–P63 plus P16A**, and a continuation prompt. Current implementation status is recorded in docs/build/STATE.md.

## Start here

October28 midway revision: P35 now begins with bounded repairs to existing member screens before configuration expansion. P36 adds the missing compact display-reference implementation before the form editor. Every P35–P63 prompt includes concrete adoption work and named U checks alongside its unchanged A1–A3. See [adoption delivery map](../docs/build/ADOPTION-DELIVERY.md), [audit](../docs/build/ADOPTION-AUDIT.md) and [experience contract](../docs/newcomer-experience.md). These are planned fixes, not completed application work. Current P34 mutation code is delivered locally; do not rebuild it. P35/P36 remain unimplemented; begin at the current checkpoint, not P00.

1. Use this TEDx workspace. Open P00 below, select the listed model/effort, and paste its text block into the project chat. Alternatively send: `Execute build-prompts/00-foundation.md and follow build-prompts/BUILD-CONTRACT.md.`
2. Run one numbered step at a time. Continue a partial step with [CONTINUE.md](CONTINUE.md) before moving on. Later steps reuse the code/contracts already built.
3. P00–P50 build and verify the core pilot/v1. P51–P61 cover all planned optional modules/integrations. P62 is required turnover functionality and P63 is the final audit/release/handover, even if optional modules are deferred.
4. To build the complete planned feature set, run all 65, subject to actual provider and privacy prerequisites. Run P16A after P16 and before P17; later IDs and P17's code prerequisites are unchanged. To protect April 17, ship core first, choose optional scope, then always return to P62/P63. Required launch gates cannot be waived by skipping a prompt.
5. Keep the current chat while context remains focused. A fresh chat can resume in the same workspace by reading STATE and the numbered prompt; do not repaste the whole specification or create a new worktree by default. Never run concurrent prompts against the same migrations/state.

**First prompt:** `Execute build-prompts/00-foundation.md. Use the build contract, implement the bounded step, verify it, and leave the checkpoint.`

## Budget and model guidance

The target is a best-effort ceiling near **40 percentage points of the total five-hour allowance per execution**, not two hours of runtime or 40% of remaining allowance. The prompts wind down five points before their effective ceiling and leave a checkpoint. A step may take more than one execution; this is not a promise of exactly 65 runs or a measured quota forecast. Finish early when done. Account usage is shared, so observed deltas are approximate. Full protocol: [BUILD-CONTRACT.md](BUILD-CONTRACT.md).

Official OpenAI documentation says model, context, reasoning, tools, retrieval and caching affect usage, and similar tasks can consume different amounts; prompt length is not a dependable quota estimate. [Usage documentation](https://learn.chatgpt.com/docs/pricing)

Use **GPT-6.1 Sol Medium** for most UI work and **High** for permissions, state machines, concurrency, finances, sensitive integrations and recovery. P63 recommends **GPT-6 Astra High** for the final cross-module audit; **Sol 6.1 High** is its lower-usage fallback, not a downgrade of the acceptance criteria. These per-step assignments are engineering judgments, not official per-task benchmarks. No automatic Max/Ultra, subagents, or speed-mode changes are requested.

Select settings with the model/effort control before sending each prompt; writing a model name in text does not change the selected model. Higher effort uses more time/tokens. Sol 6.1 supports Low, Medium, High, Extra High and Max in the documented API; these build prompts deliberately stay at Medium/High. [Model controls](https://learn.chatgpt.com/docs/models), [Sol 6.1](https://developers.openai.com/api/docs/models/gpt-6.1-sol), [Model selection](https://developers.openai.com/api/docs/guides/model-selection)

If a Medium step repeatedly fails due to a genuinely difficult defect, first checkpoint the failing test and narrow the issue; resume that step at High. Do not increase the whole project's effort globally. Use Astra only for the final audit or a clearly scoped unresolved blocker, preserving the original quota ceiling. If a provider gate is blocked, local independent code can continue, but live activation remains blocked and evidence must say so.

## Full sequence and settings

The table is the execution order; optional modules have explicit prerequisites in their prompt, so you may skip one without pretending it is implemented. Every row links to a copy-ready prompt.

| Step | Build result | Model | Effort | Stage |
| --- | --- | --- | --- | --- |
| [P00](00-foundation.md) | Create the runnable project and build ledger | GPT-6.1 Sol | Medium | Core |
| [P01](01-accessible-shell.md) | Recreate the prototype navigation and visual shell | GPT-6.1 Sol | Medium | Core |
| [P02](02-identity-schema.md) | Define members, terms, units and scoped roles | GPT-6.1 Sol | High | Core |
| [P03](03-authorization-foundation.md) | Implement and test identity authorization boundaries | GPT-6.1 Sol | High | Core |
| [P04](04-google-login.md) | Connect Google login and protected routes | GPT-6.1 Sol | High | Core |
| [P05](05-guest-invitations.md) | Add scoped off-domain guest invitations | GPT-6.1 Sol | High | Core |
| [P06](06-people-directory.md) | Build the permitted member directory and process contacts | GPT-6.1 Sol | Medium | Core |
| [P07](07-work-record-spine.md) | Create common work records, grants, audit and safe commands | GPT-6.1 Sol | High | Core |
| [P08](08-deliverables-reading.md) | Build the Core Deliverables list and detail view | GPT-6.1 Sol | Medium | Core |
| [P09](09-deliverable-authoring.md) | Add deliverable ownership, criteria and acceptance commands | GPT-6.1 Sol | High | Core |
| [P10](10-tasks.md) | Implement task creation, assignment and progress | GPT-6.1 Sol | High | Core |
| [P11](11-comments.md) | Add comments, history and eligible mentions | GPT-6.1 Sol | Medium | Core |
| [P12](12-private-files.md) | Implement private uploads, Drive links and immutable manifests | GPT-6.1 Sol | High | Core |
| [P13](13-personal-overview.md) | Build next actions and Who is waiting on you | GPT-6.1 Sol | Medium | Core |
| [P14](14-synergy-domain.md) | Implement versioned committee synergy agreements | GPT-6.1 Sol | High | Core |
| [P15](15-synergy-interface.md) | Build Working Together and negotiation screens | GPT-6.1 Sol | Medium | Core |
| [P16](16-dependencies.md) | Enforce task dependencies and meaningful blocked states | GPT-6.1 Sol | High | Core |
| [P16A](16A-committee-gantt.md) | Build the permitted committee Gantt timeline | GPT-6.1 Sol | High | Core |
| [P17](17-handoff-domain.md) | Implement immutable handoff packages and acceptance | GPT-6.1 Sol | High | Core |
| [P18](18-handoff-interface.md) | Build incoming and outgoing handoff actions | GPT-6.1 Sol | Medium | Core |
| [P19](19-request-definitions.md) | Create versioned request types and initial service catalog | GPT-6.1 Sol | High | Core |
| [P20](20-form-renderer.md) | Render and validate configured request forms | GPT-6.1 Sol | High | Core |
| [P21](21-request-submission.md) | Implement tracked submission, revisions and requester views | GPT-6.1 Sol | High | Core |
| [P22](22-workflow-engine.md) | Execute authorized sequential review workflows | GPT-6.1 Sol | High | Core |
| [P23](23-review-inboxes.md) | Build department triage and reviewer decision screens | GPT-6.1 Sol | Medium | Core |
| [P24](24-finance-payload.md) | Create restricted finance revisions and exact money calculations | GPT-6.1 Sol | High | Core |
| [P25](25-finance-intake.md) | Build cost and fundraising/sales request experiences | GPT-6.1 Sol | Medium | Core |
| [P26](26-finance-authorization.md) | Enforce independent FIN authorization and revision invalidation | GPT-6.1 Sol | High | Core |
| [P27](27-finance-reconciliation.md) | Add budget reservations and recorded actuals | GPT-6.1 Sol | High | Core |
| [P28](28-mcd-final-review.md) | Implement final publicity review with immutable evidence | GPT-6.1 Sol | High | Core |
| [P29](29-readiness-gates.md) | Unify deliverable acceptance across contributions and approvals | GPT-6.1 Sol | High | Core |
| [P30](30-notifications-inapp.md) | Deliver deduplicated in-app notifications and reliable jobs | GPT-6.1 Sol | High | Core |
| [P31](31-calendar-local.md) | Build the shared calendar and explicit event exports | GPT-6.1 Sol | Medium | Core |
| [P32](32-resources-onboarding.md) | Publish guides, glossary and an inclusive onboarding hub | GPT-6.1 Sol | Medium | Core |
| [P33](33-organization-admin.md) | Manage roster, deployments, unit rename/merge/archive | GPT-6.1 Sol | High | Core |
| [P34](34-permission-admin.md) | Build safe role editing and access explanations | GPT-6.1 Sol | High | Core |
| [P35](35-config-publication.md) | Repair everyday workflows and implement shared configuration publication | GPT-6.1 Sol | High | Core |
| [P36](36-form-builder.md) | Add readable work references and build the request form editor | GPT-6.1 Sol | High | Core |
| [P37](37-workflow-builder.md) | Build the bounded workflow and approval editor | GPT-6.1 Sol | High | Core |
| [P38](38-statuses-phases-services.md) | Edit phases, semantic statuses and service routing | GPT-6.1 Sol | Medium | Core |
| [P39](39-site-edit-branding.md) | Implement general site Edit Mode, labels and branding | GPT-6.1 Sol | Medium | Core |
| [P40](40-dashboard-layouts.md) | Configure widgets and layouts by role | GPT-6.1 Sol | Medium | Core |
| [P41](41-notification-rules.md) | Configure notification rules, schedules and preferences | GPT-6.1 Sol | High | Core |
| [P42](42-announcements.md) | Publish scoped announcements and acknowledgments | GPT-6.1 Sol | Medium | Core |
| [P43](43-global-search.md) | Implement permission-filtered keyword search | GPT-6.1 Sol | High | Core |
| [P44](44-reports-metrics.md) | Build workload, readiness and meaningful-usage reports | GPT-6.1 Sol | High | Core |
| [P45](45-csv-interoperability.md) | Add previewed Sheets-compatible CSV import and scoped export | GPT-6.1 Sol | High | Core |
| [P46](46-privacy-controls.md) | Implement privacy notice, restricted access logs and retention controls | GPT-6.1 Sol | High | Core |
| [P47](47-backup-recovery.md) | Implement encrypted backup and prove identity/file recovery | GPT-6.1 Sol | High | Core |
| [P48](48-mobile-pwa-accessibility.md) | Verify essential mobile flows and add a safe PWA shell | GPT-6.1 Sol | Medium | Core |
| [P49](49-deployment-candidate.md) | Prepare Cloudflare/Supabase release and deploy a synthetic preview | GPT-6.1 Sol | High | Core |
| [P50](50-pilot-uat.md) | Run the core pilot release gate and prepare human UAT | GPT-6.1 Sol | High | Core gate |
| [P51](51-drive-picker.md) | Connect scoped Google Drive selection | GPT-6.1 Sol | High | Optional v2 |
| [P52](52-drive-approved-exports.md) | Export selected final evidence safely between app and Drive | GPT-6.1 Sol | High | Optional v2 |
| [P53](53-google-calendar-sync.md) | Implement one-way core-calendar publishing | GPT-6.1 Sol | High | Optional v2 |
| [P54](54-telegram-alerts.md) | Add opt-in Telegram alerts without reading group chats | GPT-6.1 Sol | High | Optional v2 |
| [P55](55-email-and-nongoogle-guests.md) | Add a verified email sender and optional non-Google guest login | GPT-6.1 Sol | High | Optional v2 |
| [P56](56-room-booking-domain.md) | Implement conflict-safe Logistics room booking | GPT-6.1 Sol | High | Optional v2 |
| [P57](57-room-booking-interface.md) | Build room intake, Logistics confirmation and calendar views | GPT-6.1 Sol | Medium | Optional v2 |
| [P58](58-inventory-borrowing.md) | Build SUS inventory reservation, checkout and return | GPT-6.1 Sol | High | Optional v2 |
| [P59](59-mentoring-goals.md) | Build opt-in goals and scoped mentor check-ins | GPT-6.1 Sol | High | Optional v2 |
| [P60](60-prism-private-domain.md) | Create restricted evaluation rounds, submissions and release rules | GPT-6.1 Sol | High | Optional sensitive module |
| [P61](61-prism-interface.md) | Build PRISM desk, released summaries and safe aggregates | GPT-6.1 Sol | High | Optional sensitive module |
| [P62](62-turnover-archive.md) | Implement verified term freeze, archive and successor handover | GPT-6.1 Sol | High | Required turnover |
| [P63](63-final-audit-release-handover.md) | Audit the integrated build, release eligible scope and hand over | GPT-6 Astra | High | Final release gate |

## Coverage against the implementation plan

| Feature | Implementation steps |
| --- | --- |
| F01 — Login and guests | [P02](02-identity-schema.md), [P03](03-authorization-foundation.md), [P04](04-google-login.md), [P05](05-guest-invitations.md), [P34](34-permission-admin.md), [P55](55-email-and-nongoogle-guests.md) |
| F02 — Personal overview | [P13](13-personal-overview.md), [P18](18-handoff-interface.md), [P23](23-review-inboxes.md), [P30](30-notifications-inapp.md), [P40](40-dashboard-layouts.md) |
| F03 — Core Deliverables | [P08](08-deliverables-reading.md), [P09](09-deliverable-authoring.md), [P16](16-dependencies.md), [P16A](16A-committee-gantt.md), [P29](29-readiness-gates.md) |
| F04 — Committee synergies | [P14](14-synergy-domain.md), [P15](15-synergy-interface.md), [P16A](16A-committee-gantt.md) |
| F05 — Cross-committee tasks/dependencies | [P10](10-tasks.md), [P14](14-synergy-domain.md), [P15](15-synergy-interface.md), [P16](16-dependencies.md), [P16A](16A-committee-gantt.md) |
| F06 — Handoffs | [P17](17-handoff-domain.md), [P18](18-handoff-interface.md) |
| F07 — Tasks/comments/files | [P10](10-tasks.md), [P11](11-comments.md), [P12](12-private-files.md) |
| F08 — Tracked requests | [P19](19-request-definitions.md), [P20](20-form-renderer.md), [P21](21-request-submission.md), [P22](22-workflow-engine.md), [P23](23-review-inboxes.md) |
| F09 — FIN | [P24](24-finance-payload.md), [P25](25-finance-intake.md), [P26](26-finance-authorization.md), [P27](27-finance-reconciliation.md), [P29](29-readiness-gates.md) |
| F10 — MCD | [P28](28-mcd-final-review.md), [P29](29-readiness-gates.md) |
| F11 — Rooms | [P56](56-room-booking-domain.md), [P57](57-room-booking-interface.md) |
| F12 — Calendar | [P31](31-calendar-local.md), [P53](53-google-calendar-sync.md), [P57](57-room-booking-interface.md) |
| F13 — People/directory | [P06](06-people-directory.md), [P33](33-organization-admin.md), [P45](45-csv-interoperability.md) |
| F14 — Onboarding | [P06](06-people-directory.md), [P32](32-resources-onboarding.md), [P50](50-pilot-uat.md) |
| F15 — Mentoring | [P59](59-mentoring-goals.md) |
| F16 — PRISM | [P46](46-privacy-controls.md), [P60](60-prism-private-domain.md), [P61](61-prism-interface.md) |
| F17 — Inventory | [P58](58-inventory-borrowing.md) |
| F18 — Announcements | [P42](42-announcements.md) |
| F19 — Notifications | [P07](07-work-record-spine.md), [P30](30-notifications-inapp.md), [P41](41-notification-rules.md), [P54](54-telegram-alerts.md), [P55](55-email-and-nongoogle-guests.md) |
| F20 — Search | [P43](43-global-search.md) |
| F21 — Reports/analytics | [P44](44-reports-metrics.md), [P45](45-csv-interoperability.md) |
| F22 — Admin configurability | [P19](19-request-definitions.md), [P20](20-form-renderer.md), [P33](33-organization-admin.md), [P34](34-permission-admin.md), [P35](35-config-publication.md), [P36](36-form-builder.md), [P37](37-workflow-builder.md), [P38](38-statuses-phases-services.md), [P39](39-site-edit-branding.md), [P40](40-dashboard-layouts.md), [P41](41-notification-rules.md) |
| F23 — Drive/Sheets/Canva | [P12](12-private-files.md), [P45](45-csv-interoperability.md), [P51](51-drive-picker.md), [P52](52-drive-approved-exports.md) |
| F24 — Turnover/archive | [P46](46-privacy-controls.md), [P47](47-backup-recovery.md), [P62](62-turnover-archive.md), [P63](63-final-audit-release-handover.md) |
| F25 — Mobile/accessibility/PWA | [P01](01-accessible-shell.md), [P16A](16A-committee-gantt.md), [P20](20-form-renderer.md), [P39](39-site-edit-branding.md), [P40](40-dashboard-layouts.md), [P48](48-mobile-pwa-accessibility.md) |
| F26 — Operations/recovery | [P00](00-foundation.md), [P03](03-authorization-foundation.md), [P34](34-permission-admin.md), [P47](47-backup-recovery.md), [P49](49-deployment-candidate.md), [P50](50-pilot-uat.md), [P62](62-turnover-archive.md), [P63](63-final-audit-release-handover.md) |


## Human/provider inputs that prompts must not invent

Actual eight-committee roster; FIN/MCD delegates and school approval rules; privacy custodian/lawful basis/retention; organization-owned Supabase/Cloudflare/Google targets; required credentials via secure configuration; approved licensed logo; real mixed-background UAT; real restore and custody acknowledgment. Missing inputs permit synthetic/local implementation, not a claim of live approval or production verification.

Prompt P49 prepares deployment and an identified synthetic preview. P50 records actual UAT/gates. P63 includes release to an identified production target only if those gates actually passed. No prompt sends rollout messages, buys services, or closes the live term as a test. P62 implements and rehearses archive functionality; executing real end-of-term closure remains a separate operational instruction.

## Files and maintenance

- [Execution contract](BUILD-CONTRACT.md): constraints, budget observations, current-state/handoff protocol.
- [Continuation prompt](CONTINUE.md): resume partial work without restarting the project.
- Individual numbered Markdown files: paste their text block or ask the agent to execute that file.
- [Complete prompt book](../docs/superpowers/plans/2026-10-24-tedx-build-prompts.md): same sequence in one document, with shared constraints rather than duplicated specification text.
- `_source/*.json` and `_source/generate.py`: editable authoring source. Regeneration overwrites generated numbered files, this README and the complete book; edit the source catalog if changes should persist.

The pack was checked for 65 unique ordered IDs (including P16A between P16/P17), earlier-only dependencies, model/effort on every step, three original actions and A1–A3 per prompt, concrete adoption work/U checks on all29 remaining prompts, and coverage of all26 feature IDs. This validates prompt structure, not application acceptance. P16A's approved scope addendum is docs/committee-timeline-spec.md.
