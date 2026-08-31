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

1. **Bug fixes** ([../reference/known-issues.md](../reference/known-issues.md)):
   - explicit constructor type wins **and** a mismatched override-template list
     throws `ConflictException`;
   - `bundle.getBundle(field)` populated for a shared ancestor supplied via
     `XFTY_SharedAncestor.put(name, record)` (only the *generated* path fills it
     today).
2. **Ancestor cycle detection.** Thread the chain of resolved Provider lookup
   keys down `XFTY_GenerationContext.forRelated`; when `XFTY_AncestorGenerator`
   would recurse into a key already on the chain, stop. Cost is small — one
   `Set` on the context, one add per level, one membership check per
   relationship; depth is tiny in practice. This **allows one level of
   self-reference** (a record with a parent) and, because the check is by
   *resolved lookup key*, a deliberate multi-level hierarchy built with distinct
   per-level Providers still recurses freely. `PREVENT_CASCADE` stays as the
   explicit "exactly one level" tool and for legacy. Behaviour when it fires is
   [an open question](#open-questions).
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
7. **Test-class cleanup.** `XFTY_DummySObjectProviderTests` (trailing `s`) is the
   legacy end-to-end behavioural suite (old `System.assert*`, `testXxx` names,
   `public` not `private`); `XFTY_DummySObjectProviderTest` is the newer
   fluent-API-surface suite. Rename `…Tests` →
   `XFTY_DummySObjectProviderScenarioTest` (or similar), modernise its asserts,
   make it `private`, drop its one real duplicate (the null-type check —
   `XFTY_DummySObjectProviderTest.constructorRejectsNullSObjectType` is richer).
   Do **not** merge them — both are long and test different levels.

---

## Open questions

Only two. Everything else above is decided.

### 1. Does XFTY commit to a deployable (non-`@IsTest`) distribution?

Shipping the engine as real, deployable code — not `@IsTest` — is what
**sandbox data seeding** ([sandbox-seeding.md](sandbox-seeding.md)) needs and
what a **managed / AppExchange package**
([namespace-appexchange.md](namespace-appexchange.md) step 4) requires. The cost:
the engine then needs real production test coverage, and so do consumers' own
custom Providers and value strategies.

A consumer almost certainly **cannot** install a deployable base and opt into the
`@IsTest` layer later (you cannot replace a file from another package). So this is
one decision for the project, not a per-consumer switch: **ship `@IsTest`-only
(unlocked package, no seeding, ever) or ship deployable (seeding + AppExchange
possible, coverage burden on everyone)?**

### 2. When ancestor cycle detection fires, what should it do?

When detection stops an infinite chain (same Provider key already being
generated further up), should it:

- **(a)** silently skip that relationship, exactly as `NONE` inclusivity would —
  "`ALL` gave you one level of parent, as designed"; or
- **(b)** skip it but `System.debug(LoggingLevel.WARN)` naming the field and the
  repeated type; or
- **(c)** throw a clear `XFTY_DummySObjectFtyProviderException` telling the
  author to use distinct per-level Providers or `PREVENT_CASCADE`?

(a) is the least surprising default; (c) is most in keeping with "the framework
must be loud"; (b) is the middle path the design doc uses elsewhere.

---

## Standing constraints (facts, not tasks)

- **Branch coverage cannot be measured or enforced by the platform.** Salesforce
  measures only line coverage. Branch coverage is checked by hand on every
  change. There is no fix short of a third-party tool or building our own.
  See [../contribute/coverage-standards.md](../contribute/coverage-standards.md).
- **`@TestSetup` resets static variables**, which breaks XFTY's incrementing /
  unique value strategies. Inherent to the platform; documented, not fixable by
  us. See [../reference/salesforce-considerations.md](../reference/salesforce-considerations.md).
