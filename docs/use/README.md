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
4. [value-strategies](value-strategies.md) — change *how* a value is generated
5. [relationships](relationships.md) — required / optional, inclusivity, cascading
6. [bundles](bundles.md) — read the generated object graph
7. [insert-modes](insert-modes.md) — `MOCK` vs `NOW` and the rest

Then, as needed:

- [context-aware-values](context-aware-values.md) — a field derived from a sibling or ancestor
- [per-call-relationships](per-call-relationships.md) — one-off `includeOptional` / `excludeRelationship`
- [shared-ancestors](shared-ancestors.md) — many children under one parent
- [deferred-insert](deferred-insert.md) — `DEFERRED` + `.depthBatched()`
- [provider-variants](provider-variants.md) — pick a record-type / flavour variant
- [test-user-helpers](test-user-helpers.md) — `TEST_ADMIN_USER`, `profileIdFor`, `roleIdFor`
- [advanced/](advanced/) — combining features

---

## Feature matrix

Every consumer-facing capability, its page, and the test that proves the page's
examples compile and behave as documented.

| Feature | Page | Runnable test |
|---------|------|---------------|
| `supply` / `supplyList` / `supplyBundle` | [generating-records](generating-records.md) | _(pending)_ |
| `setQuantityPerTemplate`, `setOverrideTemplateList` | [generating-records](generating-records.md) | _(pending)_ |
| shorthand constructors (template / list / key) | [generating-records](generating-records.md) | _(pending)_ |
| `setOverrideTemplate`, precedence | [override-templates](override-templates.md) | _(pending)_ |
| `removeFromMasterTemplate` | [override-templates](override-templates.md) | _(pending)_ |
| `put(field, strategy)`, implicit literal | [value-strategies](value-strategies.md) | _(pending)_ |
| the 6 bundled `XFTY_DummyDefaultValue*` strategies | [value-strategies](value-strategies.md) | _(pending)_ |
| `XFTY_CopyFromSibling` / `XFTY_CopyFromAncestor` | [context-aware-values](context-aware-values.md) | _(pending)_ |
| custom `XFTY_ContextAwareValueIntf` + `context.siblingValue` | [context-aware-values](context-aware-values.md) | _(pending)_ |
| `putRequired` / `putOptional`, `setInclusivity` | [relationships](relationships.md) | _(pending)_ |
| `PREVENT_CASCADE` | [relationships](relationships.md) | _(pending)_ |
| `includeOptional(field)` / `includeOptional(path)` / `excludeRelationship` | [per-call-relationships](per-call-relationships.md) | _(pending)_ |
| `XFTY_SharedAncestor` (on-demand) | [shared-ancestors](shared-ancestors.md) | _(pending)_ |
| `bundle.getList` / `getBundle` / navigation | [bundles](bundles.md) | _(pending)_ |
| insert modes `NEVER` / `MOCK` / `RELATED_ONLY` / `NOW` / `LATER` | [insert-modes](insert-modes.md) | _(pending)_ |
| `DEFERRED` + `XFTY_DeferredInserter.flush()`, `.depthBatched()` | [deferred-insert](deferred-insert.md) | _(pending)_ |
| `withVariant` / lookup-key ctor / record-type template | [provider-variants](provider-variants.md) | _(pending)_ |
| `TEST_ADMIN_USER` / `profileIdFor` / `roleIdFor` | [test-user-helpers](test-user-helpers.md) | _(pending)_ |

Runnable tests live in `test-support/main/default/classes/examples/` and run as
the `XFTY_Examples` suite — see
[../contribute/test-suites.md](../contribute/test-suites.md).
