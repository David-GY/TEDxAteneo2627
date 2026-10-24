# P12 private files and manifests contract

Independent local implementation delivered. Real Supabase17/Auth/Storage/Deno transport, JWT revocation, concurrent sessions and human/privacy verification remain blocked. No provider configuration or deployment was performed. Existing P02–P11 gates remain.

## Scope and storage

Migration017_assets.sql adds assets, asset_links, asset_manifests and asset_manifest_items with forced RLS before authenticated reads and no direct client writes. Schema37tables/425columns/53public functions. Assets retain an immutable originating work/classification boundary. An extra link requires editable same-term target and current origin detail access; every subsequent metadata/download/manifest read still requires both origin and target access. A link never grants permission. Ordinary summaries are insufficient. Guests keep explicitly scoped read-only downloads; no new guest upload field is invented.

The work-private bucket is private with5242880-byte and PDF/JPEG/PNG limits. Migration checks existing bucket configuration and Storage RLS, failing on disagreement. A restrictive policy denies every anon/authenticated operation in this bucket even when another permissive policy exists. Direct paths, listing, upload/upsert and signed-URL creation are closed to clients. There is no signing endpoint. Only the trusted Edge service uses an elevated key, held entirely server-side. This design follows the distinction between [private bucket RLS](https://supabase.com/docs/guides/storage/buckets/fundamentals) and [service-key bypass](https://supabase.com/docs/guides/storage/security/access-control); actual provider behavior still requires verification.

## Upload/finalize flow

The Files API sends multipart bytes and metadata to supabase/functions/files. The handler verifies a bearer session through Auth, bounds the whole request, validates bytes and computes SHA-256 before calling reserve_upload as that user. That RPC checks current editable record, active core membership/term, expected work version, source version,5MiB/file and20MiB staged quota. It creates an expiring20-minute reservation at a random two-UUID path, carrying the originating classification and captured source metadata. No client hash becomes evidence without the trusted seal.

The trusted service writes once with upsert disabled. A duplicate-object response is accepted only when stored bytes match the expected hash. The user's reservation permission is checked again before seal_upload; that RPC is executable only by service_role and accepts only matching reserved hash/size/MIME. Clients cannot manufacture validation receipts. Failure can leave quarantined rows/orphaned bytes; they are not finalized evidence. Expired reservations stop consuming staged quota. No automatic retention purge, remote reset or unreviewed cleanup is introduced; real orphan reconciliation remains an operational verification item.

finalize_upload accepts1–20 distinct validated/finalized same-origin asset IDs, expected work version and an exact request key. It enforces20971520 bytes per manifest, records sorted immutable entries and their canonical SHA-256, links real asset FKs and freezes newly finalized assets. Entries include byte hash/size/MIME/classification and any source URL/version/export label/access notes captured at reservation. Later working-link edits or new uploads cannot rewrite those entries, bytes or hash. Finalization records a snapshot, not FIN/MCD/deliverable acceptance. It does not verify that a manually exported file semantically matches its source.

## Content controls and remaining file risk

Accept only matching extension, declared MIME and validated content for PDF/JPEG/PNG. Reject executables, HTML, SVG, archives, unsupported/truncated content, MIME mismatch, over5MiB and trailing image polyglots. PNG checks signature/chunks/CRC, bounded actual deflate output, scanline length/filter and dimensions; the initial profile accepts8-bit grayscale/RGB/RGBA, noninterlaced images up to4096 per dimension and4,194,304 pixels. Other PNG profiles are rejected. JPEG checks marker/segment/scan/frame boundaries and dimensions, not full DCT decoding. PDF accepts a conservative1.0–1.7 header/xref/EOF profile and rejects active actions, encoded JavaScript names, embedded files/forms, encryption and object streams. Complex legitimate exports may need a simpler export.

These are content/structure restrictions, **not antivirus or proof that every accepted document is harmless**. There is no assumed free malware scanner. All downloads use attachment disposition, generic safe names, application/octet-stream, nosniff, CSP sandbox and no-store; no inline private preview, PWA cache or persistent browser draft/file storage. Uploaded/downloaded copies cannot be technically recalled. Real logging redaction and organizational privacy/retention gates still apply.

## Working sources and downloads

save_working_link accepts only canonical HTTPS Drive file, Docs document, Sheets spreadsheet, Slides presentation and Canva design paths on exact allowlisted hosts. The client removes query/fragment; database validation independently rejects noncanonical URLs, credentials, spoofed hosts and unsupported paths. Name, owner/access notes and source/export label are required. Existing sources use their own expected version; adding a source uses expected work version. Provider sharing remains separate; no provider permission, ownership, availability or school API access is inferred, and no remote URL is fetched by the service.

Opening a source or downloading calls authorize_asset_download with exact work/asset/request IDs. It rechecks current origin/linked-record detail access before every receipt, including retries, and appends a redacted asset_open/asset_download audit with opaque asset ID. Downloads are authorized before fetching and again before returning verified hash/size bytes. Audit records an authorized attempt, not proof a person opened a document. No raw contents, source URLs, access notes or tokens enter audit/outbox. Working-source opening is a deliberate new-window action; browser popup policy may require allowing that window. Lost provider sharing yields honest unavailable access; app access does not expand provider access.

## RPCs, UI and retries

- reserve_upload(work,name,MIME,size,hash,optional source ID/version,expected work version,key) returns assetId/random path/version. Cached receipts still require current writable scope/active term; version checks are skipped only for exact authorized retries.
- seal_upload(asset,hash,size,MIME) is trusted-service-only and idempotent, returning validated/finalized state.
- finalize_upload(work,asset IDs,expected work version,key) returns immutable manifestId/hash.
- save_working_link(work,optional existing asset,canonical URL,name,notes,label,expected version,key) returns assetId/version.
- attach_asset(target work,asset,expected target version,key) adds no access and returns assetId.
- authorize_asset_download(work,asset,key), read_files(work) and can_read_manifest(manifest) independently enforce read access.

Public commands derive identity from session and use existing exact actor/command/key/payload transactions/redacted audit/outbox. File metadata is additive and does not overwrite parent work/version. Stale inputs keep original work/source versions. Unconfirmed operations freeze and retry the same key, File object and metadata; no optimistic or synthetic success. Upload/finalize/source saves preserve other unsent inputs. Explicit navigation/reload may discard local drafts.

src/features/files API/Files component is shared by TaskDetail and DeliverablePage through the existing AuthGateway/router/SDK. The UI shows current permission, working vs validated vs finalized state, hashes, manifest IDs and original captured source versions. Edge implementation is handler.ts/validation.ts/backend.ts/index.ts; backend.ts uses fixed Supabase Auth/PostgREST/Storage endpoints, never a supplied URL/path. Runtime requires server-only SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY plus exact APP_ORIGIN; missing configuration fails closed. No credentials or provider choices were created here.

scripts/files-preview.cjs uses the same handler/validator with actual isolated SQL and a synthetic in-memory byte adapter. scripts/preview-p12.cjs serves that explicitly labeled preview on5178. This is **not Supabase Storage or JWT proof**. Named SQL/byte/browser evidence and next provider checks are in docs/build/steps/P12.md. P13 was not executed.

P17 adds exact handoff-revision download contexts to authorize_asset_download; see docs/handoffs.md. Only explicitly offered finalized files are shared, with current receiver/sender scope and the unchanged attachment/hash/no-store/double-authorization streaming protocol. Raw origin assets/manifests and parent/financial scope stay closed. The legacy origin/linked-work authorization path is retained.
