# XFTY Roadmap

The single source of truth for **what is built, what is left to build, and the
few genuine decisions still open**.

Legend: ✅ done &nbsp;·&nbsp; 🔧 built but not merged &nbsp;·&nbsp; 📋 designed, not built

## Status

| Plan | Status | Detail |
|------|--------|--------|
| Multi-variant Providers — record-type / flavour lookup keys | ✅ (on `xfty-4.0-beta`) | [multi-variant-providers.md](multi-variant-providers.md) |
| Context-aware values — sibling + ancestor reads | ✅ | [context-aware-values.md](context-aware-values.md), [../use/context-aware-values.md](../use/context-aware-values.md) |
| Context-aware values — loud guard for a mis-ordered sibling read | ✅ (`31264ed`) | [../use/context-aware-values.md](../use/context-aware-values.md) |
| Per-call relationship control — `includeOptional` / `excludeRelationship` | ✅ | [../use/per-call-relationships.md](../use/per-call-relationships.md) |
| Shared ancestors — on-demand path (`XFTY_SharedAncestor`) | ✅ | [shared-ancestors.md](shared-ancestors.md), [../use/shared-ancestors.md](../use/shared-ancestors.md) |
| 100% framework line coverage + split test suites | ✅ | [../contribute/coverage-standards.md](../contribute/coverage-standards.md) |
| Deferred persistence — `.depthBatched()` + `DEFERRED` mode | 🔧 built on `deferred-persistence` | [deferred-persistence.md](deferred-persistence.md), [../use/deferred-insert.md](../use/deferred-insert.md) |
| Shared ancestors — declared / deep chains / DML-batched resolution | 📋 | [shared-ancestors.md](shared-ancestors.md) |
| Descendant (up-flowing) value reads | 📋 | [descendant-value-reads.md](descendant-value-reads.md) |
| Sandbox data seeding | 📋 | [sandbox-seeding.md](sandbox-seeding.md) |
| Namespace / AppExchange listing | 📋 | [namespace-appexchange.md](namespace-appexchange.md) |

---

## Remaining work (decided, needs building)

Ordered roughly by dependency.

1. **Constructor retarget fix**
   ([../reference/known-issues.md](../reference/known-issues.md)): an explicit
   `SObjectType` / lookup-key constructor argument wins **and** an
   override-template list of a different type throws `ConflictException` — the
   two are not alternatives.
2. **Ancestor cycle detection.** Thread the chain of resolved Provider lookup
   keys down `XFTY_GenerationContext.forRelated`; when `XFTY_AncestorGenerator`
   would recurse into a key already on the chain, **throw** a clear error naming
   the field and the repeated type, telling the author to use distinct per-level
   Providers or `PREVENT_CASCADE`. Detection exists to handle the cycle — a
   silent skip defeats the purpose, and a warning just delays an infinite
   recursion nobody wants. Cost is small — one `Set` on the context, one add per
   level, one membership check per relationship; depth is tiny in practice.
   Because the check is by *resolved lookup key*, one level of self-reference (a
   record with a parent of the same type) still works, and a deliberate
   multi-level hierarchy built with distinct per-level Providers recurses freely.
   Ship an off-switch (`.allowAncestorCycles()` or a context flag) for a
   deliberate cycle and as a safety valve if detection accuracy is ever in
   doubt. `PREVENT_CASCADE` stays as the explicit "exactly one level" tool and
   for legacy.
3. **Merge deferred persistence** to `xfty-4.0-beta` — after: shared-ancestor
   support under `.depthBatched()` / `DEFERRED` (refused today), and a
   `XFTY_Load` measurement of the bundle-walk cost at volume.
4. **Descendant (up-flowing) value reads — build option B** (a value pass inside
   `DEFERRED` `flush()`). Decided: skip the light `requestingChildTemplate`
   (option A). Rationale and the constraint this imposes:
   [descendant-value-reads.md](descendant-value-reads.md).
5. **Declared shared ancestors.** Every design decision in
   [shared-ancestors.md](shared-ancestors.md) is settled — build the S0–S2
   batched pre-phase, `XFTY_SharedAncestor.require(...)` / `.declared(...)`, and
   `XFTY_SharedAncestor.context(mode)`, per that document's implementation plan.
6. **Namespace steps 1–3** ([namespace-appexchange.md](namespace-appexchange.md))
   — mechanical; gated on the distribution-model decision below only for step 4.
7. **Test-class cleanup.** Two provider test classes exist for historical
   reasons, not by design. `XFTY_DummySObjectProviderTests` (trailing `s`) is the
   legacy end-to-end behavioural suite — `public` not `private`, old
   `System.assert*`, `testXxx` names, Arrange/Act/Assert markers; it exercises
   full `supply*()` scenarios ("ask for a Contact, get an Account graph too",
   persistence, MOCK-doesn't-touch-DB). `XFTY_DummySObjectProviderTest` is the
   newer suite — one `@IsTest` method per fluent-API affordance (constructors,
   `withVariant`, `put` routing, `includeOptional` / `excludeRelationship`,
   precedence).

   - Rename `…Tests` → **`XFTY_DummySObjectProviderScenarioTest`** (add scenario
     tests here); modernise its asserts to `Assert.*`; make it `private`.
   - Rename `…Test` → **`XFTY_DummySObjectProviderApiTest`** (add tests for a new
     builder method or a new guard here).
   - Drop the one real duplicate (the null-`SObjectType` check —
     `…Test.constructorRejectsNullSObjectType` is the richer one).
   - Do **not** merge — both are long and test different levels.

---

## Open questions

There is currently **one**, and it is
[in its own file](open-questions.md): does XFTY commit to a deployable
(non-`@IsTest`) distribution? Everything else on this page is decided.

---

## Standing constraints (facts, not tasks)

- **Branch coverage cannot be measured or enforced by the platform.** Salesforce
  measures only line coverage. Branch coverage is checked by hand on every
  change. There is no fix short of a third-party tool or building our own.
  See [../contribute/coverage-standards.md](../contribute/coverage-standards.md).
- **`@TestSetup` resets static variables**, which breaks XFTY's incrementing /
  unique value strategies. Inherent to the platform; documented, not fixable by
  us. See [../reference/salesforce-considerations.md](../reference/salesforce-considerations.md).
