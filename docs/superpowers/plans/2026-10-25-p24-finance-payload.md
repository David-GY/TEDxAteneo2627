# P24 Finance Payload Implementation Plan

> **Execution:** Follow the user-authorized execution method with available tools. No agents, chats or worktrees.

**Goal:** Freeze restricted typed finance plans with exact PHP arithmetic and request/evidence revision binding.

**Architecture:** Add three closed, RLS-enabled finance tables and an atomic submission RPC reusing P21/P22. Only the current requester can read the typed payload in P24; future independent FIN authority remains closed. Monetary API values are decimal integer strings, with a maximum of 9007199254740991 centavos.

**Tech Stack:** Existing PostgreSQL/PGlite, TypeScript/BigInt, Vitest; no new dependency.

**Spec:** TEDx-Core-Dashboard-Implementation-Plan.md F09 and section 8 finance entities; build-prompts/24-finance-payload.md.

## Global Constraints

- PHP integer centavos; no binary floating money. Quantity scale 3, positive cost lines/zero-permitted forecasts up to 1000000; round each nonnegative line half up to centavos, then sum.
- Current session identity, exact version/key/payload retries, immutable revisions, atomic redacted audit/outbox.
- Synthetic local data only; provider/authority/privacy/human gates stay open. No approval, payment, actual revenue, deployment or P25 UI.

## Review Focus

- Half-cent quantities and maximum-range totals must agree in SQL and TypeScript.
- A changed payload with the same key must fail without changing source history.
- A service head or former requester must not gain typed payload or evidence access.
- Cross-request, cross-term or unfinalized evidence must not bind to finance.
- Forecast losses and zero-cost plans must stay forecasts; invalid inputs and late failures must roll back.

## Tasks

- [x] Write failing P24 money tests; implement `parsePhp`, `lineTotal`, `sumCentavos`, `forecastRevenue` with bounded string serialization.
- [x] Write failing isolated SQL command/security assertions, then migration032: `finance_cases`, `finance_revisions`, `finance_lines`, `submit_finance_request`, `read_finance_revision`. Reuse request submission, current ownership and exact selected manifests; never install FIN approval hooks.
- [x] Verify P24_A1 arithmetic, invalid inputs and rollback; P24_A2 API/table/list/count/file denial; P24_A3 immutable forecast/revision history and absence of actuals.
- [x] Generate catalog types; run frontend/Edge typechecks, tests, lint, build and relevant P22/P23/P12 regressions.
- [ ] Review diff and privacy boundaries in-session; update contracts/STATE/P24 evidence, commit/push authorized checkpoint, verify live remote commit/tree and clean worktree.
