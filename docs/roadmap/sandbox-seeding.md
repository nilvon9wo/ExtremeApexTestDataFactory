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

- **Bulk API / Composite Graph path** — for volumes past one transaction's
  ceiling, and to (ab)use an external-Id field to load several generations
  concurrently in one callout. Needs an org self-callout to work from an
  `@IntegrationTest` (endpoint is free via `URL.getOrgDomainUrl()`; the open
  question is a usable session in that context). A separate spike.
- **A spec-list entry point** — `seed(lookup, List<XFTY_SeedSpec>)` generating
  then seeding, with `reusingParent` etc. The parked `sandbox-seeding` branch had
  this API; carry it forward if wanted.
- **Sandbox support** — the `@IntegrationTest` preview is scratch-org-only for
  now.

## Superseded

The `sandbox-seeding` branch (`XFTY_Seeder` + `scripts/build-deployable.sh`
`@IsTest` strip) is obsolete — keep it only for the `XFTY_SeedSpec` API sketch.
