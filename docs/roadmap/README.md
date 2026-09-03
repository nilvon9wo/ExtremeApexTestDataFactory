# XFTY Roadmap

What is built, what is left, and the one decision still open.

**Everything marked ✅ is on `4.0-beta`** — there are no unmerged feature
branches. `master` carries only a pointer to `4.0-beta`. Commit hashes are
not tracked here; `git log --grep` on the branch finds any of them.

Legend: ✅ built · 📋 designed, not built.

## Built (`4.0-beta`)

| Feature | Tests | Docs | Notes / limits |
|---------|-------|------|----------------|
| **Multi-variant Providers** — record-type / flavour lookup keys, `withVariant`, the lookup-key constructor | `XFTY_MultiVariantProviderTest`, `XFTY_LookupKeyTest`, `XFTY_RecordTypeMatchingTest`, `XFTY_RecordTypeRealRtTest` (org) | [use](../use/provider-variants.md), [extend](../extend/provider-variants.md), [detail](multi-variant-providers.md) | — |
| **Context-aware values** — `XFTY_CopyFromSiblingExpression`, `XFTY_CopyFromAncestorExpression` (multi-hop), custom `XFTY_ContextAwareExpressionIntf`, `context.siblingValue` | `XFTY_ContextAwareExpressionTest`, `XFTY_Ex_ContextAwareTest`, `XFTY_LoadTest` (value pass at 3 000 rows) | [use](../use/context-aware-values.md), [extend](../extend/custom-value-expressions.md), [detail](context-aware-values.md) | Reading a parent's **non-Id** fields works in every mode. Its **Id**: a consistent mock under `MOCK`, the real one under `NOW`, `null` under `NEVER` / `DEFERRED` (the value pass runs before `flush()`) — [per mode](../extend/custom-value-expressions.md), proven in `XFTY_Ex_Extend_CustomExpressionsTest` |
| **Loud guard for a mis-ordered sibling read** | `XFTY_ContextAwareExpressionTest` | [use](../use/context-aware-values.md) | — |
| **Per-call relationship control** — `includeOptional(field \| path)`, `excludeRelationship` | `XFTY_Ex_PerCallRelationshipsTest`, `XFTY_AncestorCycleTest` | [use](../use/per-call-relationships.md) | — |
| **Path-scoped value overrides** — `put(List<SObjectField>, …)` into a generated ancestor | `XFTY_PathValueTest` | [use](../use/value-expressions.md#setting-a-value-on-a-generated-ancestor), [detail](path-scoped-values.md) | — |
| **Downward generation** — `with` / `withChildren` / `XFTY_SObjectChildProvider`, nested grandchildren, DEFERRED-aware | `XFTY_DummySObjectProviderChildGenTest`, `XFTY_LoadTest` (3-level fan-out) | [use](../use/child-records.md) | Row count multiplies down the tree; the governor budget warns |
| **Deferred / depth-batched insert** — `DEFERRED` + `flush()`, `.depthBatched()` | `XFTY_DeferredInserterTest`, `XFTY_DeferredInsertBufferTest`, `XFTY_DepthBatchedInserterTest`, `XFTY_DeferredLoadTest` | [use](../use/deferred-insert.md), [detail](deferred-persistence.md) | `flush()` ≈ 5 s CPU at 4 000 records → ~1 000–1 500 primaries / transaction ([limits](../reference/volume-and-limits.md)) |
| **Descendant (up-flowing) value reads** — `XFTY_CopyFromDescendantExpression` | `XFTY_CopyFromDescendantExpressionTest`, `XFTY_Ex_Adv_MatchingValuesTest` | [use](../use/context-aware-values.md#reading-up-from-a-child), [detail](descendant-value-reads.md) | `DEFERRED` / `.depthBatched()` only (throws otherwise); first matching child, single hop. **Not built:** multi-hop path, aggregates across children, a loud error when `flush()` is never called |
| **Shared ancestors** — `XFTY_SharedAncestor.put/get`, flat + deep auto-detected, nested, cycle + depth guards, `XFTY_SharedAncestorProvider` per-record config, `XFTY_SharedAncestorDefaultsIntf` packaged defaults, `disable` / `manualResolutionOnly` / batch `resolveNow` | `XFTY_SharedAncestorTest`, `XFTY_SharedAncestorHierarchyTest`, `XFTY_SharedAncestorLoadTest`, `XFTY_SharedAncestorDeepHierarchyTest` (org) | [use](../use/shared-ancestors.md), [extend](../extend/shared-ancestors-in-templates.md), [detail](shared-ancestors.md) | S2 is one depth-batched pass **per sub-graph** — independent heavy shared ancestors cost a few extra inserts ([known limit](shared-ancestors.md)) |
| **Governor-limit warnings + volume tests** — `XFTY_GovernorBudget`, `XFTY_Settings__c` | `XFTY_GovernorBudgetTest`, `XFTY_LoadTest` | [limits](../reference/volume-and-limits.md) | — |
| **Serialization enrichment** — `bundle.inject(field, config)` / `injectAll` / `injectAllParents` / `injectAllChildren`, `XFTY_InjectConfig`, standalone `XFTY_SObjectInjector` | `XFTY_BundleEnricherTest`, `XFTY_SObjectInjectorTest`, `XFTY_EnrichmentSelectionTest`, `XFTY_Ex_EnrichmentTest`, `XFTY_Ex_SObjectInjectorTest`, `XFTY_EnrichmentLoadTest` (+ helper unit tests) | [use](../use/enrichment.md), [injector](../use/sobject-injector.md) | JSON round-trip returning `List<SObject>`; recursive (ancestors + inverse child + one child level, deeper with `breakSoqlLimits()`). `MOCK`-only in spirit — forced data is fiction a real `insert` overwrites. Polymorphic, compound and `Blob` round-trips verified on a real org |
| **Framework coverage + split test suites** — `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` / `XFTY_Examples` / `XFTY_OrgOnly` / `XFTY_PersonAccount` | — | [coverage](../contribute/coverage-standards.md), [suites](../contribute/test-suites.md) | Line coverage is verified by stripping `@IsTest` and running on an org (the local runtime's coverage is unreliable); branch coverage is hand-checked (the platform can't measure it) |

## Designed, not built

| Feature | Detail |
|---------|--------|
| Org data seeding — `XFTY_Seeder.seed(bundle)` via `@IntegrationTest` (DML path built on branch `org-seeding`; Bulk API path not built) | [sandbox-seeding.md](sandbox-seeding.md), [use](../use/org-seeding.md) |
| Namespace / AppExchange listing | [namespace-appexchange.md](namespace-appexchange.md) |

---

## The one open question

Does XFTY commit to a **deployable, non-`@IsTest` distribution**? Everything else
is decided. [open-questions.md](open-questions.md).

---

## Standing constraints (facts, not tasks)

- **Branch coverage cannot be measured by the platform** — hand-checked on every
  change. [coverage-standards.md](../contribute/coverage-standards.md).
- **`@TestSetup` resets static variables**, breaking XFTY's incrementing / unique
  value expressions. Platform behaviour; documented, not fixable.
  [salesforce-considerations.md](../reference/salesforce-considerations.md).
- **The local Apex runtime fakes some org schema / query semantics** — those
  tests live in `test-support/classes/orgonly/` and run on a scratch org.
  [about-nimbus.md](../contribute/about-nimbus.md).
