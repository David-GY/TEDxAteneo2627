# Task dependencies Implementation Plan

> **Execution:** Follow the user-authorized execution method with available tools.

**Goal:** Deliver P16 authorized dependency editing and readiness gates.

**Architecture:** Task-specific same-term edges plus immutable event history; serialized graph edits and state transitions. Scoped RPCs expose permitted edges and neutral restricted blockers. Reuse canonical contribution tasks and incumbent form/retry patterns.

**Tech Stack:** Existing React/TypeScript/Supabase SQL/PGlite/Vite.

**Spec:** build-prompts/16-dependencies.md; F03/F05 and section8 task_dependencies.

## Global Constraints

Existing checkout/branch, no agents/worktrees/provider changes/deployments/messages. No P16A. Original deadlines, independent FIN/MCD and parent acceptance gates remain. Shared usage baseline69%, effective21 points, wind-down85used/ceiling90used.

## Review Focus

- Self/cyclic/inverse edges and graph edits racing readiness.
- Unfinished/cancelled/archived predecessors never become completion.
- Restricted predecessor IDs/titles/counts/reasons never leak.
- Required removal needs a reasoned explicit current managerial scope exception.
- Stale/uncertain commands retain safe drafts and exact retry keys.

## Tasks

- [x] Add schema/RPCs, serialized gates, scoped projection and named P16_A1-A3 SQL checks; regenerate types.
- [x] Add Dependencies task UI and contribution blocker/next-step information, adapter/error/retry tests and browser verification.
- [x] Run relevant regressions/typechecks/lint/build, review rendered mobile/keyboard behavior and record actual limitations.
- [x] Update STATE/P16/contracts/usage, review, commit/push and verify remote commit/tree and clean worktree.
