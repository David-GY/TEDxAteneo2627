"""Render the reviewed TEDx prompt catalog into individual prompts and a guide."""

import json
import re
from collections import Counter
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

HERE = Path(__file__).resolve().parent
PACK = HERE.parent
ROOT = PACK.parent
SPEC_NAME = "TEDx-Core-Dashboard-Implementation-Plan.md"
PLAN = ROOT / "docs/superpowers/plans/2026-10-24-tedx-build-prompts.md"

tasks = []
for path in sorted(HERE.glob("[0-9][0-9]-[0-9][0-9].json")):
    tasks.extend(json.loads(path.read_text(encoding="utf-8-sig")))
tasks.sort(key=lambda task: task["id"])
assert [t["id"] for t in tasks] == list(range(64)), "Need exactly P00–P63"
for path in sorted(HERE.glob("*-additions.json")):
    tasks.extend(json.loads(path.read_text(encoding="utf-8-sig")))

def step_order(step):
    match = re.fullmatch(r"(\d{1,2})([A-Z]?)", str(step))
    assert match, f"Invalid step ID: {step}"
    return int(match[1]), match[2]

def step_label(step):
    number, suffix = step_order(step)
    return f"P{number:02d}{suffix}"

tasks.sort(key=lambda task: step_order(task["id"]))
by_id = {task["id"]: task for task in tasks}
assert len({step_label(t["id"]) for t in tasks}) == len(tasks), "Duplicate step IDs"
assert (ROOT / SPEC_NAME).is_file(), "Missing implementation specification"
assert (PACK / "BUILD-CONTRACT.md").is_file(), "Missing execution contract"
assert len({t["slug"] for t in tasks}) == len(tasks)

coverage = {
    "F01": [2, 3, 4, 5, 34, 55], "F02": [13, 18, 23, 30, 40],
    "F03": [8, 9, 16, "16A", 29], "F04": [14, 15, "16A"], "F05": [10, 14, 15, 16, "16A"],
    "F06": [17, 18], "F07": [10, 11, 12], "F08": [19, 20, 21, 22, 23],
    "F09": [24, 25, 26, 27, 29], "F10": [28, 29], "F11": [56, 57],
    "F12": [31, 53, 57], "F13": [6, 33, 45], "F14": [6, 32, 50],
    "F15": [59], "F16": [46, 60, 61], "F17": [58], "F18": [42],
    "F19": [7, 30, 41, 54, 55], "F20": [43], "F21": [44, 45],
    "F22": [19, 20, 33, 34, 35, 36, 37, 38, 39, 40, 41],
    "F23": [12, 45, 51, 52], "F24": [46, 47, 62, 63],
    "F25": [1, "16A", 20, 39, 40, 48], "F26": [0, 3, 34, 47, 49, 50, 62, 63],
}
assert set(coverage) == {f"F{i:02d}" for i in range(1, 27)}

feature_names = {
    "F01": "Login and guests", "F02": "Personal overview", "F03": "Core Deliverables",
    "F04": "Committee synergies", "F05": "Cross-committee tasks/dependencies",
    "F06": "Handoffs", "F07": "Tasks/comments/files", "F08": "Tracked requests",
    "F09": "FIN", "F10": "MCD", "F11": "Rooms", "F12": "Calendar",
    "F13": "People/directory", "F14": "Onboarding", "F15": "Mentoring",
    "F16": "PRISM", "F17": "Inventory", "F18": "Announcements",
    "F19": "Notifications", "F20": "Search", "F21": "Reports/analytics",
    "F22": "Admin configurability", "F23": "Drive/Sheets/Canva",
    "F24": "Turnover/archive", "F25": "Mobile/accessibility/PWA", "F26": "Operations/recovery",
}

def label(task):
    return step_label(task["id"])

def filename(task):
    return f"{label(task)[1:]}-{task['slug']}.md"

def model_name(task):
    return "GPT-6 Astra" if task.get("model") == "gpt-6-astra" else "GPT-6.1 Sol"

def settings(task):
    return f"{model_name(task)} · {task['effort'].title()}"

def relative_prompt_link(step, prefix=""):
    task = by_id[step]
    return f"[{label(task)}]({prefix}{filename(task)})"

def body(task):
    step = label(task)
    dependency = ", ".join(step_label(i) for i in task["needs"]) or "None; initial step"
    fallback = " Use GPT-6.1 Sol High if Astra is unavailable or quota is tight." if task.get("model") else ""
    lines = [
        f"Implement {step}: {task['title']}.",
        f"Recommended setting: {settings(task)}.{fallback}",
        "The human selects the model/effort in the picker; do not spawn another agent or chat to change it.",
        "",
        "Read build-prompts/BUILD-CONTRACT.md and follow it, including the best-effort 40-percentage-point usage ceiling and mandatory resumable checkpoint.",
        "Read docs/build/STATE.md and this step's checkpoint if present; P00 creates them initially.",
        f"Read only these relevant parts of {SPEC_NAME}: {task['refs']}.",
        *([f"Also read {task['additional_context']}."] if task.get("additional_context") else []),
        f"Code/interface prerequisites: {dependency}. Carry real provider/human blockers forward as the contract specifies.",
        "",
        "Files (use existing equivalent paths if already established; record mappings):",
        task["files"],
        "",
        "Interfaces / invariants:",
        task["interface"],
        *(["", task["execution_notes"]] if task.get("execution_notes") else []),
        *(["", "Newcomer adoption work (required, in the listed order):",
           "Read docs/newcomer-experience.md and docs/build/ADOPTION-AUDIT.md. "
           + "Mapped findings: " + ", ".join(task["adoption"]["findings"]) + ".",
           *[f"- {item}" for item in task["adoption"]["work"]],
           "These additions are part of this step, not a request to finish every batch in one execution. "
           "Checkpoint each coherent batch within BUILD-CONTRACT usage limits; carry actual provider/human gates forward. "
           "Do not advance with missing required local adoption behavior. Do not rebuild verified preceding code."]
          if task.get("adoption") else []),
        "",
        "Implement and verify this bounded slice:",
    ]
    lines += [f"{i}. {s}" for i, s in enumerate(task["steps"], 1)]
    lines += ["", "Acceptance checks (implement named regression assertions for nontrivial behavior; record actual results):"]
    lines += [f"- {step}_A{i}: {check}" for i, check in enumerate(task["checks"], 1)]
    if task.get("adoption"):
        lines += ["", "Additional adoption acceptance (preserve A1-A3 above):",
                  "Automate meaningful state/security/recovery assertions; use recorded visual/manual checks for presentation. "
                  "Do not add tests that only mirror wording or mark human UAT passed from automation."]
        lines += [f"- {step}_U{i}: {check}" for i, check in enumerate(task["adoption"]["checks"], 1)]
        lines += ["Record A and U results separately, open AD findings and batch completion in the mandatory checkpoint. "
                  "A plan or new label does not close an adoption finding."]
    lines += [
        "",
        f"Update docs/build/steps/{step}.md and docs/build/STATE.md with delivered behavior, exact commands/results, remaining acceptance items, observed usage and next smallest action.",
        "Run targeted checks and required typecheck/lint/build. Do not expand into the next prompt, fabricate external verification, or commit/push without authorization.",
        "If budget requires a partial checkpoint, keep this step active and name build-prompts/CONTINUE.md; otherwise name the next dependency-eligible step. Finish with a short result, verification and material limitation.",
    ]
    return "\n".join(lines)

for task in tasks:
    assert task["effort"] in {"low", "medium", "high", "xhigh"}
    assert all(n in by_id and step_order(n) < step_order(task["id"]) for n in task["needs"]), task
    assert len(task["steps"]) == 3 and len(task["checks"]) == 3
    if step_order(task["id"])[0] >= 35:
        assert task.get("adoption"), f"Missing adoption scope: {label(task)}"
        assert task["adoption"]["work"] and task["adoption"]["checks"]
        assert all(re.fullmatch(r"AD0[1-9]", item) for item in task["adoption"]["findings"])
    text = f"# {label(task)} — {task['title']}\n\n**Select before sending:** {settings(task)}\n\n**Phase:** {task['phase']}\n\nCopy the prompt below into the project chat, or ask Codex to execute this file.\n\n```text\n{body(task)}\n```\n"
    (PACK / filename(task)).write_text(text, encoding="utf-8")

intro = """# TEDx app: sequential build prompts

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
"""
table = "\n".join(
    f"| [{label(t)}]({filename(t)}) | {t['title']} | {model_name(t)} | {t['effort'].title()} | {t['phase']} |"
    for t in tasks
)
coverage_text = "\n\n## Coverage against the implementation plan\n\n| Feature | Implementation steps |\n| --- | --- |\n"
for key, indices in coverage.items():
    assert indices and all(i in by_id for i in indices)
    coverage_text += f"| {key} — {feature_names[key]} | {', '.join(relative_prompt_link(i) for i in indices)} |\n"
tail = """

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
"""
(PACK / "README.md").write_text(intro + table + coverage_text + tail, encoding="utf-8")

header = """# TEDx Dashboard Build Prompts Implementation Plan

> **Execution:** Follow the user-authorized execution method with available tools. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build all scoped dashboard features through bounded, verified sessions with recoverable checkpoints and a model/effort choice per step.

**Architecture:** React/TypeScript static frontend, Supabase identity/PostgreSQL/private files, transactional business RPCs, small trusted integration functions, and a bounded admin configuration system. Each task implements one interface or vertical slice and carries forward unresolved provider/human evidence honestly.

**Tech Stack:** React, TypeScript, Vite, Supabase, Cloudflare Pages; existing approved Google Workspace/notification services as configured.

**Spec:** `C:/Users/david/OneDrive/Documents/ChatGPT/TEDx/TEDx-Core-Dashboard-Implementation-Plan.md`.

## Global Constraints

Read and follow `build-prompts/BUILD-CONTRACT.md`: exact school domain `student.ateneo.edu`, event April 17, 2027, Asia/Manila, ₱0 hosting target, Karla/calm interface, FIN/MCD authority, RLS/private evidence, descriptive affiliation, versioned configuration, no invented policy, targeted checks and honest checkpoints. Budget targets are observational soft ceilings, never wall-clock or token guarantees.

October28 adoption revision: required P35 repair batches precede editor expansion; P36 implements missing display references. P35–P63 carry explicit adoption scope/U acceptance in addition to original A1–A3. Read docs/build/ADOPTION-DELIVERY.md and docs/newcomer-experience.md. No current finding is fixed merely by these plan changes.

## Review Focus

- Same-domain nonmember, expired guest and revoked deployment: denied even with a valid token. Owned by P03–P05/P34; assert negative database and route behavior.
- Changed approved asset/caption/financial purpose: old decision remains, readiness requires the correct new review. Owned by P26/P28/P29.
- Concurrent graph edges, accept/cancel, budget reservations and room confirmations: one consistent allowed result. Owned by P14/P16/P17/P27/P56.
- Unit merges/configuration labels/role delegation: no implicit privilege expansion or history rewrite. Owned by P33–P38.
- Exports/restores/Drive copies: no private-payload leaks, missing file bytes, identity mismatch or resurrection of purged records. Owned by P45–P47/P52/P62.

## How to run

Use `build-prompts/README.md` as the navigation/index. Select each row's model/effort in the UI and send only that step. Read the shared contract once per execution; target relevant specification sections instead of reloading this entire book. All 65 steps cover the full feature set, including P16A after P16 and before P17; P51–P61 remain optional to ship before the event, while P62/P63 remain required. A partial task resumes with `build-prompts/CONTINUE.md`.

The original 465-hour estimate is a human planning envelope, not a quota conversion. A prompt can finish below 40 points or need continuation; no exact number of sessions or usage percentage is guaranteed. Per-step model choices are recommendations. Official sources and feature coverage are in the prompt-pack README.

## Tasks
"""
sections = []
for task in tasks:
    sections.append(
        f"\n### Task {label(task)}: {task['title']}\n\n"
        f"**Model / effort:** {settings(task)}\n\n"
        f"**Phase:** {task['phase']}\n\n"
        f"**Files:** {task['files']}\n\n"
        f"**Interfaces:** {task['interface']}\n\n"
        "- [ ] Read the scoped contract/spec and verify required preceding interfaces.\n"
        "- [ ] Implement the bounded actions and meaningful regression assertions below.\n"
        "- [ ] Run checks, record actual evidence/blockers, and leave the mandatory checkpoint.\n\n"
        f"```text\n{body(task)}\n```\n"
    )
PLAN.parent.mkdir(parents=True, exist_ok=True)
PLAN.write_text(header + "".join(sections), encoding="utf-8")

# Include approved additions and their spec in a reproducible portable prompt pack.
archive_paths = [*PACK.glob("*.md"), *HERE.glob("*.json"), HERE / "generate.py",
                 PLAN, ROOT / SPEC_NAME, ROOT / "docs/committee-timeline-spec.md",
                 ROOT / "docs/newcomer-experience.md", ROOT / "docs/build/ADOPTION-AUDIT.md",
                 ROOT / "docs/build/ADOPTION-DELIVERY.md",
                 ROOT / "docs/build/evidence/ADOPTION-AUDIT.json"]
with ZipFile(ROOT / "TEDx-Build-Prompts.zip", "w", compression=ZIP_DEFLATED) as archive:
    for path in sorted(archive_paths, key=lambda p: p.relative_to(ROOT).as_posix()):
        info = ZipInfo(path.relative_to(ROOT).as_posix(), date_time=(2026, 10, 24, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes())

print(json.dumps({
    "prompts": len(tasks), "feature_ids_covered": len(coverage),
    "model_effort": dict(Counter(settings(t) for t in tasks)),
    "readme": str(PACK / "README.md"), "complete_book": str(PLAN),
}, indent=2))
