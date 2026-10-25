# Restricted finance payloads (P24)

Migration032 adds `finance_cases`, `finance_revisions` and `finance_lines`. All are forced-RLS, append-only and denied direct access to public/anon/authenticated/service_role. No finance joins were added to ordinary requests, search, counts, Overview or department inboxes. Existing independently authorized triage envelope metadata remains governed by P23; it confers no typed payload or evidence access.

## Submission contract

`submit_finance_request(p_work_item_id uuid, p_values jsonb, p_requested_on date, p_title text, p_finance_payload jsonb, p_expected_version integer, p_request_id uuid, p_revision boolean default false)`

The current core requester owns the existing FIN/restricted draft. Identity, route, form validation, term, current version and request lifecycle come from P21/P22; the command reuses `app_private.submit_request_revision` in the same transaction. `p_revision=true` submits an explicit revision draft. The existing `requested_centavos` form adapter, when present, receives the validated typed line total; callers cannot supply another amount. `p_values` contains configured envelope/file-selection values only, never finance lines or approval fields.

`p_request_id` is an actor/command-scoped idempotency UUID. Identical complete payload/key returns the original receipt after current ownership/admission checks. Changed payload/key is `22023`; stale version is `40001`; denied current scope is `42501`; wrong type/lifecycle/untyped later revision is `55000`. No optimistic success is implied. Keep the identical input and key to recover an uncertain result. The receipt extends P21 with `financeRevisionId` and `requestRevisionId` and contains no sensitive payload or money.

The closed finance object is:

```ts
{
  schemaVersion: 1,
  currency: 'PHP',
  kind: 'cost' | 'budget' | 'expense' | 'reimbursement' | 'fundraising' | 'sales',
  purpose: string,                 // nonblank, <=2000 characters
  fundSource: string,              // nonblank, <=500
  beneficiaryMemberId: string,     // current active core member in the same term
  relatedDeliverableId?: string | null, // same-term, unarchived, independently readable
  plannedOn?: string | null,       // date-only YYYY-MM-DD, years 0001..9999
  termsRisks: string,              // nonblank, <=4000
  requestedTotalCentavos: string,
  lines: [{                       // 1..100, <=100000 bytes for the entire input
    description: string,          // nonblank, <=500
    quantity: string,
    unitAmountCentavos: string,
    totalCentavos: string
  }],
  // Required only for fundraising/sales; forbidden for other kinds:
  pricing?: {
    unitPriceCentavos: string,
    forecastQuantity: string,
    forecastRevenueCentavos: string
  }
}
```

Unknown keys, numeric money JSON values, negative amounts, exponents, leading zero integers, wrong currency, malformed quantities/dates and inconsistent declared totals fail. Neither beneficiary selection nor a related deliverable grants access or authority. This slice intentionally supports member beneficiaries only; external beneficiaries need an explicit future privacy/design decision.

## Exact money and quantity policy

All monetary inputs/outputs are canonical decimal integer strings in **centavos**, range `0..9007199254740991`. The explicit upper bound also keeps the underlying generated bigint table types within JavaScript's safe range; those tables are not client-readable. Never widen the bound without changing serialization and tests. No PostgreSQL bigint beyond this bound is coerced to a JavaScript number.

Quantity is a canonical decimal string with up to three fractional digits, maximum `1000000`. Cost lines require quantity `>=0.001`; forecast quantity may be zero. The database stores exact integer thousandths as `quantity_milli` / `forecast_quantity_milli`, the equivalent of the specification's quantity_numeric. Each nonnegative product rounds half up: `floor((quantity_milli * unit_centavos + 500) / 1000)`. Requested total sums the already rounded cost lines. Forecast revenue applies the same rule to price and forecast quantity. Products and sums use PostgreSQL numeric / TypeScript BigInt before range checks. Decimal PHP text is parsed without `Number`, `parseFloat` or binary floating money. Zero cost, zero forecast and negative derived forecast margin are valid plans.

`src/features/finance/money.ts` exports `parsePhp`, `lineTotal`, `sumCentavos` and `forecastRevenue` for P25's presentation. PostgreSQL repeats all trusted validation.

## Immutable revision and evidence binding

The command freezes typed columns/lines beside the exact submitted request revision. The selected P12 request manifest and its SHA-256 are copied from that revision, never supplied as finance hashes or mutable external links. P21's exact finalized, same-request file selection remains authoritative; P12 reauthorizes every byte download. No file access is widened. No evidence policy is invented: mandatory school/receipt evidence remains an institutional configuration/acceptance gate.

`payload_hash` is lowercase SHA-256 over PostgreSQL UTF-8 jsonb text of `{hashVersion:'sha256-jsonb-v1', requestRevisionId, manifestHash, payload: normalizedFinanceObject}`. Normalization replaces quantities with integer thousandths and normalizes line/price totals to strings. P26 must verify/use the server-owned exact finance revision/hash, not a caller claim or a browser's serialization. The payload hash identifies a plan; it is not an approval or signature.

Once a case has a typed finance snapshot, a deferred constraint trigger requires every later request revision to have its own typed snapshot at commit. An old generic FIN envelope without a finance case remains an unbound, paused P21/P22 envelope; it cannot become financial authorization. To add typed data, the requester begins an explicit revision and uses this atomic command. Generic revisions cannot bypass a typed case's requirement. New snapshots never overwrite earlier payloads/files/hashes.

## Audited read boundary and remaining gates

`read_finance_revision(p_term_id uuid, p_work_item_id uuid, p_revision integer default null)` returns the requested or current typed revision only to the current admitted core requester with current work access. Unrelated readers receive null; invalid admission is denied. Success appends a redacted access audit with no amounts, descriptions, fund, beneficiary or evidence contents. The response includes typed header/lines, string money, optional forecast/margin, exact manifest/files and server hashes. No storage paths or signed URLs are returned. Use P12's existing download command for bytes.

P24 installs **no FIN participant/reviewer authority**. Service heads, associates, beneficiary status and labels do not grant typed access. P26 owns independently authorized FIN participants/reviews. FIN/MCD hooks stay fail-closed. Forecasts create no actual revenue, reservation, authorization or payment; P27 owns documented actuals/ledger work. P25 owns forms/detail/desk UI and has not been implemented.

Local isolated P24_A1–A3 evidence is in `docs/build/steps/P24.md` and `docs/build/evidence/P24-domain.json`. Real Supabase17/Auth/Storage/JWT access/revocation, independent concurrent sessions, deployed redaction, approved authority/privacy/retention/evidence policy and human acceptance remain unverified; all earlier gates persist.
