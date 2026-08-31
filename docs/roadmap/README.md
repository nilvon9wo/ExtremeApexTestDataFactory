# XFTY Roadmap

The single source of truth for **what is built, what is left to build, and the
few genuine decisions still open**.

Legend: ✅ built &nbsp;·&nbsp; 📋 designed, not built. Everything ✅ is on
`xfty-4.0-beta`; `master` carries only a pointer to that branch.

## Status

| Plan | Status | Detail |
|------|--------|--------|
| Multi-variant Providers — record-type / flavour lookup keys | ✅ (on `xfty-4.0-beta`) | [multi-variant-providers.md](multi-variant-providers.md) |
| Context-aware values — sibling + ancestor reads | ✅ | [context-aware-values.md](context-aware-values.md), [../use/context-aware-values.md](../use/context-aware-values.md) |
| Context-aware values — loud guard for a mis-ordered sibling read | ✅ (`31264ed`) | [../use/context-aware-values.md](../use/context-aware-values.md) |
| Per-call relationship control — `includeOptional` / `excludeRelationship` | ✅ | [../use/per-call-relationships.md](../use/per-call-relationships.md) |
| Shared ancestors — on-demand path (`XFTY_SharedAncestor`) | ✅ | [shared-ancestors.md](shared-ancestors.md), [../use/shared-ancestors.md](../use/shared-ancestors.md) |
| 100% framework line coverage + split test suites | ✅ | [../contribute/coverage-standards.md](../contribute/coverage-standards.md) |
| Deferred persistence — `.depthBatched()` + `DEFERRED` mode | ✅ (`407d38a`) | [deferred-persistence.md](deferred-persistence.md), [../use/deferred-insert.md](../use/deferred-insert.md) |
| Governor-limit warnings + volume tests | ✅ | [../reference/volume-and-limits.md](../reference/volume-and-limits.md) |
| Downward generation — `with` / `withChildren` / `XFTY_SObjectChildProvider` (nested, DEFERRED-aware) | ✅ | [../use/child-records.md](../use/child-records.md) |
| Shared ancestors — declared / deep chains / batched resolution | ✅ (per-ancestor depth-batch — not one pass across the whole set; no decision-3 load data yet) | [shared-ancestors.md](shared-ancestors.md), [../use/shared-ancestors.md](../use/shared-ancestors.md) |
| Descendant (up-flowing) value reads | 📋 | [descendant-value-reads.md](descendant-value-reads.md) |
| Path-scoped value overrides — `put(List<SObjectField>, value)` into an ancestor | ✅ | [path-scoped-values.md](path-scoped-values.md) |
| Sandbox data seeding | 📋 | [sandbox-seeding.md](sandbox-seeding.md) |
| Namespace / AppExchange listing | 📋 | [namespace-appexchange.md](namespace-appexchange.md) |

---

## Remaining work (decided, needs building)

Ordered roughly by dependency. (The two known-issue fixes at the top of the
list are **done** — `142c6d9`, and the commit after it.)

1. ~~Constructor retarget fix~~ — **done.** An explicit `SObjectType` /
   lookup-key constructor argument wins, and an override-template list of a
   different type throws `ConflictException`.
2. ~~Ancestor cycle detection~~ — **done.** `XFTY_AncestorCycleGuard` threads the
   chain of in-progress Provider lookup-key hashes; `XFTY_AncestorGenerator`
   throws when it would recurse into one already in progress. One level of
   self-reference still works (the guard fires on the second repeat); distinct
   per-level Providers recurse freely; `.allowAncestorCycles()` on the Provider
   suppresses the guard. `PREVENT_CASCADE` unchanged.
3. ~~Merge deferred persistence to `xfty-4.0-beta`~~ — **done** (`407d38a`).
   ~~Volume measurement~~ — **done**: the `XFTY_Load` suite now pins the
   ceilings ([../reference/volume-and-limits.md](../reference/volume-and-limits.md));
   `DEFERRED` `flush()` costs ~5 s CPU at 4,000 records, so the practical
   ceiling is ~1,000–1,500 primaries per transaction. Still open on the branch:
   shared-ancestor support under `.depthBatched()` / `DEFERRED` (refused today
   with a clear error).
4. **Descendant (up-flowing) value reads — build option B** (a value pass inside
   `DEFERRED` `flush()`). Decided: skip the light `requestingChildTemplate`
   (option A). Rationale and the constraint this imposes:
   [descendant-value-reads.md](descendant-value-reads.md).
5. ~~Declared shared ancestors~~ — **done.** `XFTY_SharedAncestor.declared(...)` /
   `.require(...)` / `.context(mode)` / `.resolveDeclared(lookup)`, the S0–S2
   batched pre-phase (`XFTY_DeclaredAncestorResolver`), nested auto-require, cycle
   + depth guards, "undeclared → throw". **Still open:** one S2 pass across the
   whole declared set (currently per ancestor); decision-3 load-test data +
   documented limits + off-switches; on-demand + `.depthBatched()`/`DEFERRED`.
6. **Namespace steps 1–3** ([namespace-appexchange.md](namespace-appexchange.md))
   — mechanical; gated on the distribution-model decision below only for step 4.
7. ~~Test-class cleanup~~ — **done.** `XFTY_DummySObjectProviderTests` →
   `XFTY_DummySObjectProviderScenarioTest` (end-to-end scenarios, now `private`,
   `Assert.*`, duplicate null-type test dropped); `XFTY_DummySObjectProviderTest`
   → `XFTY_DummySObjectProviderApiTest` (one test per fluent-API affordance).
   Both in `core/` beside `XFTY_DummySObjectProvider`. Part of the wider
   test-co-location reorg.

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
