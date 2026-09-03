# Using XFTY

You are here to **write tests for your own code** with XFTY generating the data.

New? Read [getting-started](getting-started.md) top to bottom, then come back to
the per-feature pages as you need them. Each feature page opens with the simplest
example and builds up.

---

## Reading order

1. [getting-started](getting-started.md) — the guided tour
2. [generating-records](generating-records.md) — `supply` / `supplyList` / `supplyBundle`, quantity, shorthand constructors
3. [override-templates](override-templates.md) — set only the fields your test cares about; precedence; removal
4. [value-expressions](value-expressions.md) — change *how* a value is generated
5. [relationships](relationships.md) — required / optional, inclusivity, cascading
6. [bundles](bundles.md) — read the generated object graph
7. [insert-modes](insert-modes.md) — `MOCK` vs `NOW` and the rest

Then, as needed:

- [context-aware-values](context-aware-values.md) — a field derived from a sibling, an ancestor, or (under `DEFERRED`) a child
- [per-call-relationships](per-call-relationships.md) — one-off `includeOptional` / `excludeRelationship` for a single call
- [child-records](child-records.md) — `with` / `withChildren`: generate the records *below* a primary
- [enrichment](enrichment.md) — `inject` / `injectAll`: put parents, subqueries and read-only fields onto the SObject for the code under test
- [sobject-injector](sobject-injector.md) — `XFTY_SObjectInjector`: the same round-trip on a plain `List<SObject>`, no bundle
- [shared-ancestors](shared-ancestors.md) — many children under one parent (flat or deep, auto-detected)
- [deferred-insert](deferred-insert.md) — `DEFERRED` + `.depthBatched()`
- [org-seeding](org-seeding.md) — `XFTY_Seeder.seed(bundle)`: leave a generated graph in the org (preview, `@IntegrationTest`)
- [provider-variants](provider-variants.md) — pick a record-type / flavour variant
- [test-user-helpers](test-user-helpers.md) — `TEST_ADMIN_USER`, `profileIdFor`, `roleIdFor`
- [advanced/](advanced/) — combining features

---

## Feature matrix

Every consumer-facing capability, its page, and the test that proves the page's
examples compile and behave as documented.

| Feature | Page | Runnable test |
|---------|------|---------------|
| `supply` / `supplyList` / `supplyBundle` | [generating-records](generating-records.md) | `XFTY_Ex_GeneratingRecordsTest` |
| `setQuantityPerTemplate`, `setOverrideTemplateList` | [generating-records](generating-records.md) | `XFTY_Ex_GeneratingRecordsTest` |
| shorthand constructors (template / list / key) | [generating-records](generating-records.md) | `XFTY_Ex_GeneratingRecordsTest` |
| `setOverrideTemplate`, precedence | [override-templates](override-templates.md) | `XFTY_Ex_OverrideTemplatesTest` |
| `removeFromMasterTemplate` | [override-templates](override-templates.md) | `XFTY_Ex_OverrideTemplatesTest` |
| `put(field, expression)`, implicit literal | [value-expressions](value-expressions.md) | `XFTY_Ex_ValueExpressionsTest` |
| the 6 bundled `XFTY_*Expression` classes | [value-expressions](value-expressions.md) | `XFTY_Ex_ValueExpressionsTest` |
| `XFTY_CopyFromSiblingExpression` / `XFTY_CopyFromAncestorExpression` | [context-aware-values](context-aware-values.md) | `XFTY_ContextAwareExpressionTest` |
| `XFTY_CopyFromDescendantExpression` — up-flow, `DEFERRED` only | [context-aware-values](context-aware-values.md) | `XFTY_CopyFromDescendantExpressionTest` |
| custom `XFTY_ContextAwareExpressionIntf` + `context.siblingValue` | [context-aware-values](context-aware-values.md) | `XFTY_ContextAwareExpressionTest` |
| `putRequired` / `putOptional`, `setInclusivity` | [relationships](relationships.md) | `XFTY_Ex_RelationshipsTest` |
| `PREVENT_CASCADE`, self-referential cycle guard | [relationships](relationships.md) | `XFTY_Ex_RelationshipsTest` |
| `includeOptional(field)` / `includeOptional(path)` / `excludeRelationship` | [per-call-relationships](per-call-relationships.md) | `XFTY_Ex_PerCallRelationshipsTest` |
| `with` / `withChildren` / `XFTY_SObjectChildProvider` (downward) | [child-records](child-records.md) | `XFTY_DummySObjectProviderChildGenTest` |
| `put(List<SObjectField>, value)` — path-scoped ancestor values (literal / expression / context-aware / relationship) | [value-expressions](value-expressions.md#setting-a-value-on-a-generated-ancestor) | `XFTY_PathValueTest` |
| `XFTY_SharedAncestor` — `get` / `put` / `putAsTemplate` / `putIfAbsent` / `getId` | [shared-ancestors](shared-ancestors.md) | `XFTY_SharedAncestorTest` |
| `XFTY_SharedAncestor` — deep chains, batched pre-phase, `resolveNow` | [shared-ancestors](shared-ancestors.md) | `XFTY_SharedAncestorHierarchyTest` |
| `bundle.getList` / `getBundle` / navigation | [bundles](bundles.md) | `XFTY_Ex_BundlesTest` |
| `bundle.inject(field, config)` / `injectAll*`, `XFTY_InjectConfig` | [enrichment](enrichment.md) | `XFTY_Ex_EnrichmentTest` |
| `XFTY_SObjectInjector` — standalone round-trip (parents, subqueries, values, compound, `Blob`) | [sobject-injector](sobject-injector.md) | `XFTY_Ex_SObjectInjectorTest` |
| insert modes `NEVER` / `MOCK` / `RELATED_ONLY` / `NOW` / `LATER` | [insert-modes](insert-modes.md) | `XFTY_Ex_InsertModesTest` |
| `DEFERRED` + `XFTY_DeferredInserter.flush()`, `.depthBatched()` | [deferred-insert](deferred-insert.md) | `XFTY_Ex_DeferredInsertTest` |
| `XFTY_Seeder.seed(bundle)` / `XFTY_SeedResult` — leave a graph in the org (`@IntegrationTest`) | [org-seeding](org-seeding.md) | `XFTY_Ex_OrgSeedingTest` |
| `withVariant` / lookup-key ctor (flavour keys) | [provider-variants](provider-variants.md) | `XFTY_Ex_ProviderVariantsTest` |
| record-type override template | [provider-variants](provider-variants.md) | `XFTY_RecordTypeRealRtTest` (org-only) |
| `TEST_ADMIN_USER` | [test-user-helpers](test-user-helpers.md) | `XFTY_Ex_TestUserHelpersTest` |
| `profileIdFor` / `roleIdFor` | [test-user-helpers](test-user-helpers.md) | `XFTY_DefaultUserDataProviderTest` |

Runnable tests live in `test-support/main/default/classes/examples/` and run as
the `XFTY_Examples` suite — see
[../contribute/test-suites.md](../contribute/test-suites.md).
