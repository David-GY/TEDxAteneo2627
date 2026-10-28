# Midway adoption audit: current system and plans through P63

October28,2026 · source935df248c8777328c68d92138a660793fdb84238 · branch codex/core-build-checkpoints.

**Verdict: aligned in purpose, not yet demonstrated easy for a newcomer. Proceed with focused simplification before expanding the interface.** The original brief explicitly prioritizes plain-language next actions, contacts, safe practice and mixed-background UAT. The current implementation preserves those security/process goals, but too much implementation vocabulary and too many parallel controls reach the user. Completing every future prompt does not automatically prove adoption.

This is an audit and future-plan checkpoint, not a UI redesign or a claim that findings were fixed. Shared build criteria now point to [the newcomer experience contract](../newcomer-experience.md). The priority is ordinary work first, bounded administration second, optional modules only after core adoption. No application, migration, provider setting or live data changed in this audit.

## Scope, evidence and limits

- Read the original executive principles/personas/information architecture, F14, configuration contract, rollout section12, roadmap/optional selection section13 and UAT section14; current navigation, work/task/request/file/onboarding/admin components and request-ID allocator; every remaining P35–P63 prompt's interfaces, bounded scope and acceptance checks. Current implementation extends through P34; P35/P36 remain context checkpoints.
- Inspected nine distinct synthetic routes: Overview, deliverable list/detail, My tasks, Working together, Department requests, Resources, Organization administration and Roles & access. Desktop1280×800; onboarding390×844 and320×800; mobile More and a real Tab focus spot-check. Screenshots were visually inspected in the tool, not saved as a complete screenshot archive. Evidence summary: [ADOPTION-AUDIT.json](evidence/ADOPTION-AUDIT.json).
- Restored owned loopback preview with existing scripts after checking no owned process/listener remained: Vite88820/5173, P34 preview5888/5178. Kept a visible retained Resources tab. The app is a synthetic, administrator/head fixture; its full navigation/authority is not an ordinary member's account. Production Auth/Storage and frontend usability were not tested.
- My tasks shows a connection placeholder in this particular preview because preview-p34 does not enable the tasks gateway. Task implementation exists in src/features/tasks and the production router. This is a demo/coverage gap, not proof the task feature is absent or broken in production. Empty guides/contact assignments and unavailable service routing are unconfigured fixture/organizational inputs, not fabricated live failures.
- Counts below describe this fixture, not human cognitive-load measurements. The initial generic control probe overcounted children of closed details; those control counts are excluded. Corrected DOM counting excludes closed details. Unsupported probe APIs were discarded. This audit does not claim bundled full-probe, full axe, screen-reader, real-device, native zoom, all-role, populated-file or actual human-UAT completion.
- Findings are reasoned usability judgments. No composite usability score or invented participant results. House44px is stronger than WCAG2.2 SC2.5.8's24px minimum; the small More finding below is not labeled a WCAG failure. [W3C target-size explanation](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).

## What already aligns

Overview distinguishes actions from waiting work and names owner/date/next person. Titles, rather than UUIDs, lead inspected member links. Requests use compact FIN/MCD references, allocated transactionally across forms within a namespace. Service search asks What do you need help with? Core identity/permissions do not depend on affiliation. Start Here supports late joining, optional fields, skippable/revisitable tours, static fallback and an API-free practice sandbox. Existing history and revision binding protect trust; keep them.

Mobile has four primary routes plus More. Onboarding had no horizontal overflow at390 or320CSS pixels. A real Tab reached Open account with a3px interface-accent outline; More moved focus to Close pages and closing returned focus to More. These are spot checks, not full keyboard/accessibility acceptance.

## Current findings — all open

### AD01 · Major · Work details lack a focused working surface

The loaded deliverable fixture has21visible headings,45main-content controls and6,396characters. Overview/facts, readiness, full editor, workflow action, separate start-date save, contributions, FIN/MCD gates, file tools and comments render together. Source: src/features/deliverables/DeliverablePage.tsx:39–44 and TaskDetail.tsx:29–30. A newcomer must infer which section matters now.

Fix: keep title/owner/date/state and one specific next-action area first; open Edit deliberately; group files/activity/advanced checks separately and reveal only relevant actions. Preserve required blockers and permitted evidence. Verify first work/owner/date/action without scrolling through unrelated editors, including a non-editor account. Remediation owns existing P08–P18/P29/P31 surfaces; P40/P48/P50 must not compound it.

### AD02 · Major · Visible technical language expects insider knowledge

Observed Immutable manifests, Finalize immutable manifest, Authoritative readiness and Apply workflow action; source additionally prints SHA-256, Manifest UUID and Snapshot file UUID in Files.tsx:19–20 and package hashes in RequestPages.tsx:69. No populated file UUID/hash was observed in the empty live fixture; that part is source-confirmed, not live byte evidence. Role publication exposes role publish, assignment grant, committee.manage and raw scope values.

Fix: member labels such as Submit final files, Ready to submit? and Send for review; a collapsed scoped Verification details view for technical proof. Administrator permissions need a plain explanation beside stable keys. Keep essential process warnings concise and contextual; do not delete the underlying evidence or legal/process distinctions. Verify a newcomer can explain submission versus approval in their own words. P35–P39/P46/P62 inherit this requirement.

### AD03 · Major · Short references are only partly standardized

FIN/MCD tracking already supports readable `FIN-027` / `MCD-027`; keep it. General request prefixes derive from org_units.code; tracking_counters permits40characters (request_submission migration lines19,224–230). Tasks/deliverables use UUID-backed title links and do not provide a comparable short display reference in reviewed summaries. Long UUIDs in URLs are acceptable; making people read/type them is the issue.

Fix: adopt a reviewed display-reference policy before expanding numbering. Titles first; stable short issued references, copy link, separate term context across terms, scoped exact lookup. Illustrative new task/deliverable formats `TASK-027` / `DEL-012` require a real server allocator/backfill design and tests; none was implemented here. New ordinary prefixes should be short and recognizable; preserve every old ID/alias, reject collisions and never use UUID truncation. P38/P43/P45/P58/P62 must preserve this policy. The [experience contract](../newcomer-experience.md) distinguishes proposals from current behavior.

### AD04 · Major · Statuses and generic blockers leave the next step ambiguous

The same fixture says Finance: not required / Final publicity: not required in its summary, yet lower panels say FIN review not verified / Final-publicity review not verified. Readiness exposes a more accurate applicable-gate model, while its headline says Resolve the required checks, then submit current evidence. Sources: Readiness.tsx:22, FinanceDesk.tsx:12, Publicity.tsx:35. These are separate models rendered on one screen; this is not evidence an unauthorized approval occurred.

Fix: show applicability consistently and only meaningful current requirements. Explain the actual outstanding acceptance authority/evidence and the permitted resolution/contact, without revealing private cases. Keep Not required, Pending review, Approved for this revision and Unavailable distinct. P29 remediation plus P38/P40/P57 must share this model. Test ordinary/nonfinancial, governed, pending and lost-access cases.

### AD05 · Major · Refresh presents an avoidable loss-of-work trap

The detail page prominently warns Reloading the whole deliverable discards unsaved forms. TaskDetail also offers Reload task (discard unsaved edits). Multiple independent Refresh/Reload variants ask members to understand implementation boundaries. Source confirms the remount/discard behavior; this audit did not type and destroy an edit.

Fix: preserve safe in-memory input during refresh; explicit discard confirmation only when necessary; use one consistent saved/unsaved/saving/conflict vocabulary. Preserve privacy and exact retry keys. P35–P37/P45/P57 must retain input and explain recovery rather than silently overwriting or duplicating. Test edit→refresh/conflict/timeout→recover.

### AD06 · Moderate · Navigation and onboarding can accumulate choices

The privileged fixture has13desktop workspace links. Source navigation gives an ordinary core account11before extra role workspaces; roles are already filtered, so do not claim every member sees administration. Start Here has five separate confirmation buttons, Skip/Revisit, practice inputs, published guides, publisher tools for authorized users and process contacts. Confirmation is not a direct navigation action. More/help is discoverable but Start Here begins with account setup rather than the first useful work.

Fix: retain a small stable everyday navigation and group tools; make Open my work / Find help / Try safely obvious. Separate publisher editing from learning, keep guide acknowledgment when meaningful, and give an actual permitted no-work contact route. Do not turn an arbitrary menu-item count into a universal limit or hide useful tasks merely to hit a number. P39/P40/P42 and every optional module need this check.

### AD07 · Major · Administrator configuration still reads like a developer tool

Roles & access has14headings,39controls and5,293characters in the fixture. It puts real publication, inspection, synthetic draft and prospective preflight on one long page. AccessEditor.tsx:31 renders raw review.values key/value pairs, which can include internal IDs after review; this was source-confirmed without invoking publication. Date strings are also shown as ISO instants in assignments.

Fix: a named-change entry point with human permission descriptions, named scoped selectors, short dates, clear draft/simulation state and an understandable impact review. Separate reference/diagnostic tools from the common path. Preserve independent ceilings, exact scope, custody acknowledgment and version binding. P35–P40 must reuse one bounded pattern; do not build six unrelated consoles. A new steward should configure one ordinary service using controls and a short guide, without developer assistance.

### AD08 · Major · Current demo cannot prove the first-task promise

Clicking My tasks in the retained P34 preview shows This area is not connected yet. preview-p34 passes no tasks:true; preview-p08 gateway installation is conditional. Other source modules implement TasksPage/TaskDetail, so this is a fixture completeness gap. Current guides/service contacts are also not populated with an approved operating model.

Fix: before claiming end-to-end learnability, provide a reviewed coherent synthetic newcomer/member/guest/admin scenario with assigned work, active scoped contacts and clear configured/unconfigured states. Reuse real components and rules; keep the truthful fixture banner. P49/P50/P63 must exercise the actual deployed eligible revision and real scoped identities. Do not seed a real roster or call the demo a user study.

### AD09 · Minor · Mobile More narrowly misses the house target

At320×800, More measured42.921875×63CSS pixels; other measured primary links were at least54.64pixels wide. The project requests44pixel controls. This is a house-standard gap, not a demonstrated SC2.5.8 failure. Fix minimum target/layout spacing without overflow; recheck all five targets at320px, zoom and long labels in P01/P48 remediation. The no-space mobile text identity also merits copy cleanup, preserving the approved-name/logo constraints.

## Future-plan audit — every remaining prompt

These are risks and added review expectations, not claims that future code exists or will fail. All29prompts already read BUILD-CONTRACT; its shared newcomer requirement now applies without duplicating or regenerating each prompt.

| Prompt | Alignment / adoption requirement |
| --- | --- |
| P35 Configuration publication | Good draft/preview/history foundation. Use a single understandable impact/review/publish flow; keep raw JSON and concurrency terms out of routine editing. |
| P36 Form builder | Good stable keys and keyboard controls. Start from a bounded template, reveal conditions/repeaters only when needed; test the resulting requester form, not just the editor. |
| P37 Workflow builder | Keep sequential bounded stages. Use named people and plain decision routes; show why missing/self approver blocks publication. No general BPM canvas. |
| P38 Statuses/phases/services | Preserve semantics, concise consistent labels and old IDs. Show a readable actual contact route and applicability; reject misleading Approved labels. |
| P39 Site Edit Mode | Separate editor mode clearly; preserve members' familiar navigation/terms and stable links after wording changes. No design-your-own-site burden on ordinary users. |
| P40 Dashboard layouts | A layout should prioritize the next action, not show every widget. Provide a useful default and safe fallback; no mandatory personalization. |
| P41 Notification rules | Explain audience/channel/time in human terms; dry run with no send. Useful grouped alerts, quiet hours and actionable deep links; no competing obligation queues. Existing no-schedule authorization remains. |
| P42 Announcements | Do not overwhelm the first screen or require acknowledgment of every trivial edit. Clearly distinguish Read from a task or approval; preserve material-revision rules. |
| P43 Search | Titles, short refs, aliases and contextual results. No dependence on knowing an ID; safe no-result/denied behavior, copy link and term disambiguation. |
| P44 Reports | Define metrics beside them; keep managerial analysis separate from the member's next action. No rankings or dense dashboard as default home. |
| P45 CSV | Give a simple template, named mapping, understandable row errors and exact impact preview. Preserve refs; no role codes required for ordinary task import. |
| P46 Privacy | Plain choices and a real help route; optional disclosure stays optional. Retention/emergency operations stay with authorized custodians. Do not simplify away security. |
| P47 Recovery | A short stepwise custodian runbook with actual observations, not a new member page. Separate advanced technical manifests and preserve identity/file recovery requirements. |
| P48 Mobile/accessibility | Essential on all existing flows now and later. Repair content hierarchy/keyboard/reflow as well as CSS. Do not wait until P48 to address current barriers. |
| P49 Deployment candidate | Deploy a coherent synthetic first-work journey; test fresh-account/deep-link/config-unavailable behavior. Source counts or a connected schema do not prove a usable hosted app. |
| P50 Pilot UAT | Original two-minute first-action/90%essential-flow targets need real observations, wrong-turn/help records and consented participants. Add each unresolved adoption finding to triage. |
| P51 Drive Picker · optional | Separate optional connection from sign-in; link/upload fallback remains useful. Disabled Drive creates no connection nag or blank destination. |
| P52 Drive exports · optional | Say which final copy goes where; use plain progress/retry and prevent duplicate copies. Keep approved snapshots/private destination policy intact. |
| P53 Calendar sync · optional | Distinguish Add a copy from verified sync and show last successful state. Preserve app calendar when disconnected; no private-event leakage. |
| P54 Telegram · optional | Opt-in link/unlink with understandable status; no requirement to use Telegram for authoritative work. No automatic messages in this audit. |
| P55 Email/guest entry · optional | One clear entry route/fallback, exact invite and expiry help. Do not make guests troubleshoot provider jargon or identity linking. |
| P56 Room domain · optional | Keep Requested, Held and Officially confirmed distinct and versioned; complexity stays in authoritative rules. |
| P57 Room UI · optional | One request journey with readable alternatives, confirmation evidence and preserved input on conflict. Do not add another generic tracking console. |
| P58 Borrowing · optional | Show quantity/dates/request/issue/return clearly, with a compact reference. Keep ledger internals and stock conflicts behind understandable actions. |
| P59 Mentoring · optional | Simple goal/check-in/sharing choices; separate from evaluations and core work. Not a mandatory member tab or disclosure flow. |
| P60 Feedback domain · optional sensitive | Fixed privacy/authority first; no simplification by widening scope. Explain purpose, actual anonymity limits and release rules. |
| P61 Feedback UI · optional sensitive | Distinct author/reviewer/released-summary views, clear privacy/help and rights text. Not a generic approval dashboard. |
| P62 Turnover · required | A custodian checklist with understandable unresolved items, successor acknowledgment and resumable progress. Hide technical export proofs behind details; never claim success on partial archive. |
| P63 Final release · required | Audit the enabled experience with newcomers on the exact revision. Require adoption/UAT evidence, deliberately disabled optional scope and real operations custody; feature count is not a release criterion. |

## Simulated council assessment

One assistant generated these perspectives; no independent reviewers/agents participated.

| Lens | Assessment |
| --- | --- |
| Newcomer | The primary work/owner model is sound. Raw terms, long pages and indirect first actions undermine the promised independence. Prioritize AD01–AD06. |
| Accessibility | Responsive layout and focus have useful foundations; no overflow in the checked onboarding states. Long-page cognitive burden and a44px house gap remain; actual assistive/human evidence is pending. |
| Operations/governance | Submission, acceptance, FIN/MCD and custody distinctions are necessary. Simplify their presentation and context, while retaining current authority and immutable proof. |
| Skeptical delivery/successor | More editors/integrations could produce a configurable but hard-to-operate platform. Fix one coherent everyday journey and a bounded admin pattern before optional expansion. |

Credible alternative: complete the feature roadmap first and compensate with longer training. Rejected as the default: it postpones evidence of the main user promise and compounds inconsistent controls. A radical one-page application is also unnecessary; role-appropriate focused pages with progressive disclosure preserve familiar tasks and recoverability. Confidence is high in the source/observed issues and moderate in the precise layout/label remedy until novice testing.

## Recommended execution order and proof

1. **Existing member workflow cleanup:** specific next-action/blocker/applicability, plain labels, consistent refresh recovery, focused detail sections, first-work/help entry and coherent preview. Keep APIs/approval semantics unchanged where possible. Use named regression tests for retained input, authorization and actions; do not test copy/styling mechanically.
2. **Display-reference implementation:** decide short formats and term context, then implement only the missing server allocation/backfill/search/copy path with collision/concurrency/alias tests. Preserve old request IDs and UUID deep links. No migration was made by this audit.
3. **Bounded administrator improvements and future builds:** apply the shared [experience contract](../newcomer-experience.md) as P35–P48 are implemented, reusing common editing/review language. Do not rebuild P34's delivered security engine.
4. **Actual adoption gate:** P49/P50 observed core journeys, fix severe/essential friction, then selected optional features only if core usability/reliability/capacity allow. P62/P63 verify actual successor tasks and enabled-user experience. Provider/privacy/security/recovery gates remain open independently.

The existing provider cleanup remains authorized work but is not performed during this audit. This report recommends a bounded adoption-remediation slice; it does not automatically execute P35 or an optional step.

Method basis: [Nielsen usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) for language, recognition, error recovery and minimal relevant information; [GOV.UK question pages](https://design-system.service.gov.uk/patterns/question-pages/) as a useful focused-form pattern rather than an instruction to make every field a new page. Product-specific menu counts, reference lengths and priorities are design judgments, not standards. Human success remains unmeasured.
