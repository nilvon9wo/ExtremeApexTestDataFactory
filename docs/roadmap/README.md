# XFTY Roadmap

The single source of truth for **what is built, what is in progress, and what is
only proposed**. Every status claim elsewhere in the docs links here.

Legend: ✅ done &nbsp;·&nbsp; 🔧 in progress / built but not merged &nbsp;·&nbsp; 📋 proposed (not built)

| Plan | Status | Where it lives | Open questions |
|------|--------|----------------|----------------|
| Multi-variant Providers — record-type / flavour lookup keys | ✅ done (on `xfty-4.0-beta`) | [multi-variant-providers.md](multi-variant-providers.md); use: [provider-variants](../use/provider-variants.md), extend: [provider-variants](../extend/provider-variants.md) | — |
| Context-aware values — sibling + ancestor reads | ✅ done | [context-aware-values.md](context-aware-values.md); use: [context-aware-values](../use/context-aware-values.md) | — |
| Context-aware values — loud guard for a mis-ordered sibling read | ✅ done (`deferred-persistence` `31264ed`) | use: [context-aware-values](../use/context-aware-values.md) | — |
| Per-call relationship control — `includeOptional(field)` / `includeOptional(path)` / `excludeRelationship` | ✅ done | use: [per-call-relationships](../use/per-call-relationships.md) | — |
| Shared ancestors — on-demand path (`XFTY_SharedAncestor`) | ✅ done | [shared-ancestors.md](shared-ancestors.md); use: [shared-ancestors](../use/shared-ancestors.md) | two known bugs — mixed-insert-mode Id drift, and `bundle.getBundle(field)` returns null for a shared-ancestor field |
| 100% framework line coverage + split test suites | ✅ done | [../contribute/coverage-standards.md](../contribute/coverage-standards.md), [../contribute/test-suites.md](../contribute/test-suites.md) | branch coverage is hand-checked — the platform cannot measure or enforce it |
| Deferred persistence — `.depthBatched()` + the `DEFERRED` insert mode | 🔧 built on branch `deferred-persistence`, awaiting review / merge to `xfty-4.0-beta` | [deferred-persistence.md](deferred-persistence.md); use: [deferred-insert](../use/deferred-insert.md) | no shared-ancestor support yet; the bundle-walk cost wants load-testing at volume |
| Shared ancestors — declared ancestors, deep chains, DML-batched resolution | 📋 proposed (design decisions resolved, nothing built) | [shared-ancestors.md](shared-ancestors.md) | the S0–S2 batched pre-phase; `XFTY_SharedAncestor.context(mode)` for pre-generation `getId` |
| Descendant (up-flowing) value reads — a parent field derived from a generated child | 📋 proposed | [descendant-value-reads.md](descendant-value-reads.md) | the light `context.requestingChildTemplate` vs. a value pass inside `DEFERRED` `flush()` |
| Sandbox data seeding | 📋 proposed, feasibility unknown | [sandbox-seeding.md](sandbox-seeding.md) | can a consumer install a deployable base without the `@IsTest` layer cleanly? needs a scratch-org experiment |
| Namespace / AppExchange listing | 📋 proposed | [namespace-appexchange.md](namespace-appexchange.md) | step 4 — promoting the framework out of `@IsTest` |

## Open defects (not roadmap features)

Tracked in [../reference/known-issues.md](../reference/known-issues.md):

- A single mismatched override template silently retargets the Provider instead
  of throwing.
- `ALL` inclusivity + a self-referential optional relationship
  (e.g. optional `Account.ParentId → Account`) recurses until the stack blows —
  needs cycle detection in the engine. `PREVENT_CASCADE` is the workaround.

## Remaining coverage work

The framework is at 100% **line** coverage, but line coverage is a fragile
proxy — the goal is **branch** coverage, which Salesforce can neither measure
nor enforce. Every new guard / `switch` / ternary needs a test for each side,
checked by hand. Scenarios still worth explicit tests as the engine grows:
many-level graphs, circular relationships beyond `PREVENT_CASCADE`, and the open
items above. See [../contribute/coverage-standards.md](../contribute/coverage-standards.md).
