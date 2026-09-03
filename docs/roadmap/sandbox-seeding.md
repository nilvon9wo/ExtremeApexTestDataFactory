# Roadmap: Org Data Seeding

Status: **🔧 prototype on branch `org-seeding`** — `XFTY_Seeder.seed(bundle)`
(DML path) built and proven on a scratch org. See
**[docs/use/org-seeding.md](../use/org-seeding.md)** for usage.

**No longer blocked on the `@IsTest` distribution question.** The earlier design
assumed seeding needed a deployable, non-`@IsTest` build of the framework.
Salesforce's **Apex Integration Tests** (`@IntegrationTest`, Winter '27 developer
preview) removed that: `@IntegrationTest` methods commit real DML with no
rollback, and — while they cannot themselves be `@IsTest` — they *can* call
`@IsTest` code. So the `@IsTest` framework seeds real data directly, from a
consumer's `@IntegrationTest` class. No strip, no module split, no config.

---

## Proven (scratch org, API 68.0 preview)

- `@IntegrationTest` class deploys and runs; cannot also be `@IsTest`; can call
  `@IsTest` code, whose DML **persists** (verified by external `sf data query`).
- The whole `@IsTest` XFTY framework deploys and is driven from an
  `@IntegrationTest` class.
- `XFTY_Seeder.seed(bundle)` lands the whole graph — ancestors, primaries,
  downward children, mixed SObjectTypes, foreign keys wired — best effort, and
  reports each rejected record (`DUPLICATES_DETECTED`, `REQUIRED_FIELD_MISSING`,
  …) via `XFTY_SeedResult` instead of throwing.

## The DML path (built)

`XFTY_Seeder.seed(bundle)` → `XFTY_SeedResult`, over
`XFTY_DepthBatchedInserter.seedAll` (best-effort variant of the existing
depth-batched inserter) and `XFTY_DeferredInsertBuffer.flatten` (the existing
whole-graph walk). One transaction, so the per-transaction DML-row / CPU limits
apply.

## Not built

- **A spec-list entry point** — `seed(lookup, List<XFTY_SeedSpec>)` generating
  then seeding, with `reusingParent` etc. The parked `sandbox-seeding` branch had
  this API; carry it forward if wanted.
- **Sandbox support** — the `@IntegrationTest` preview is scratch-org-only for
  now.

## Not viable (spiked)

The **Bulk API / Composite Graph path** — one callout for volumes past a single
transaction, and an external-Id field to load several generations concurrently —
was spiked on a Winter '27 preview scratch org and does not work config-free:

- Callouts to the org's own My Domain URL succeed with **no Remote Site Setting**
  (`URL.getOrgDomainUrl()` + an unauthenticated `/services/data/` → 200).
- But `UserInfo.getSessionId()` in an `@IntegrationTest` returns the fake
  `…!ApexTestSession` placeholder — authenticated self-API calls get
  `401 INVALID_SESSION_ID`. A real token needs a Connected App + Named Credential.
- `Queueable` / `Batch` jobs enqueued from an `@IntegrationTest` are created but
  **never execute** (stuck `Queued`), so chunking across transactions from inside
  a seed method is out too.

So `XFTY_Seeder` is one transaction; a large seed is several `@IntegrationTest`
methods. A Bulk API path stays possible only as an **opt-in** that asks the
consumer to wire a self-Named-Credential.

## Superseded

The `sandbox-seeding` branch (`XFTY_Seeder` + `scripts/build-deployable.sh`
`@IsTest` strip) is obsolete — keep it only for the `XFTY_SeedSpec` API sketch.
