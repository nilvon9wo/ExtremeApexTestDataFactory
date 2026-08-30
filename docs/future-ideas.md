# Possible Future Enhancements

Although XFTY is stable, several ideas have been considered for future versions.

## Implicit Exact Values — implemented

`put(...)` now accepts a bare literal and wraps it in `XFTY_DummyDefaultValueExact`
automatically. See [Customization → Implicit Exact Values](customization.md#implicit-exact-values).

---

## Multi-Variant Providers — implemented

Providers are now keyed by `XFTY_LookupKeyIntf` (`SObjectType`, optionally +
record type via `XFTY_RecordTypeLookupKey` or + flavor via
`XFTY_FlavorLookupKey`). See
[Providers → Record Types and Variants](providers.md#record-types-and-variants)
and [docs/design/multi-variant-providers.md](design/multi-variant-providers.md).

---

## Shared Parent Records — proposal drafted

Currently, each generated child receives its own generated parent; hierarchical
data often wants several children under one shared parent.

The merged relationship model makes this a second implementation of
`XFTY_DummyDefaultRelationshipIntf` (`XFTY_SharedAncestor.of(...)`) plus a
`parentCountFor(childCount)` method on the interface and a small change to the
factory's wiring. Full proposal, including the `BUNDLE` vs `TRANSACTION` scope
question and the `bundle.getList` contract: **[design/shared-ancestors.md](design/shared-ancestors.md)**.

---

## More Granular Relationship Generation

Relationship generation currently supports `NONE` / `REQUIRED` / `ALL` /
`PREVENT_CASCADE` - a single global setting per `supply()` call.

**Sketch.** Rather than a new enum value, let a test opt specific optional
relationships in or out by field:

```apex
new XFTY_DummySObjectProvider(Opportunity.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .includeOptional(Opportunity.Pricebook2Id)          // this one, on top of REQUIRED
    .excludeRelationship(Opportunity.OwnerId)           // skip this required one
```

Implementation: `XFTY_DummySObjectProvider` carries an overrides map
(`SObjectField -> INCLUDE | EXCLUDE`); it is passed alongside the base
inclusivity into `XFTY_DummySObjectFactory`, which consults it per field in
`createRelatedRecords` before falling back to the global rule. The recursive
call to child Providers passes only the base inclusivity (overrides are
top-level, matching how `PREVENT_CASCADE` already behaves).

**Open questions.** Do overrides propagate by field path (`Account.OwnerId` two
levels down) or only at the top level? Does `excludeRelationship` on a *required*
field produce an invalid record deliberately (useful for validation-rule tests)
or is that a separate `removeFromMasterTemplate` concern?

---

## Relationship Consolidation — implemented

`XFTY_DummyDefaultRelationshipRequired` and `XFTY_DummyDefaultRelationshipOptional`
were merged into `XFTY_DummyDefaultRelationship`. Requiredness is decided by the
Master Template slot (`putRequired` / `putOptional`), so a
single implementation - including a future shared-ancestor implementation - can
serve either role.

---

## Context-Aware Value Generation

Current value generators operate independently.

Each field is generated without knowledge of sibling fields, parent records, or previously generated values.

For many data models this is entirely sufficient.

In real Salesforce implementations, however, data is often intentionally duplicated across multiple fields or even across multiple generations of related records. Validation rules, integrations, and governor-limit optimizations frequently require this kind of denormalized data.

As a result, integration tests sometimes need to override values that XFTY would ideally generate automatically.

A future version may introduce context-aware value generators capable of inspecting other generated values within the object graph.

Examples include:

- copying a value from a parent record
- deriving a value from a sibling field
- inheriting data from an ancestor
- generating values based on previously generated related records

Whether this should be -- or even can be -- implemented as an extension of `XFTY_DummyDefaultValueIntf` or as a new abstraction remains an open design question.

**Sketch.** `XFTY_DummyDefaultValueIntf.get()` takes no arguments, so a
context-aware generator needs more. A second interface avoids disturbing the
simple case:

```apex
public interface XFTY_ContextAwareValueIntf {
    Object get(XFTY_GenerationContext context);
}
```

where `XFTY_GenerationContext` exposes the record being built, its already-set
fields, and the generated parent bundle so far. The factory would check
`instanceof XFTY_ContextAwareValueIntf` in `cloneAndCompleteNonRelationshipValues`
and pass a context; plain `XFTY_DummyDefaultValueIntf` generators are unchanged.

The hard part is *ordering*: relationships are wired in phase 3, after
non-relationship values in phase 1, so "copy `Account.Name` onto the child" needs
either a phase-1.5 pass or a dependency-aware evaluation order. A pragmatic first
version: only allow context-aware generators to read **parent** values (available
once phase 2 assigns Ids), evaluated in a new pass between phases 2 and 3.

Concrete built-ins worth shipping: `XFTY_CopyFromParent(parentField)`,
`XFTY_CopyFromSibling(siblingField)`.

---

## Dynamic Ancestor Configuration

Relationship override templates already allow customization of generated parent records.

For example:

```apex
.putRequired(
    Foo__c.Account__c,
    new XFTY_DummyDefaultRelationship(
        new Account(Bar__c = someId)
    )
)
```

This allows tests to specify static values on generated parents, grandparents, and even more distant ancestors.

However, these templates are entirely declarative. There is currently no mechanism for computing ancestor values dynamically during graph generation or for making those values depend on the generated graph itself.

Although relatively uncommon, some integration testing scenarios would benefit from being able to configure ancestors programmatically as the graph is constructed.

This would likely require extending the generation engine rather than simply adding another implementation of `XFTY_DummyDefaultValueIntf`, and it remains an area for future investigation.

**Sketch.** This largely collapses into *Context-Aware Value Generation* above:
a generated ancestor is customised by putting an `XFTY_ContextAwareValueIntf` on
that ancestor's override template, e.g.

```apex
XFTY_DummyDefaultRelationship.of(new Account())
    .put(Account.Site, new XFTY_CopyFromDescendant(Contact.Department))
```

If context-aware generation lands, dynamic ancestor configuration is mostly a
matter of making the `XFTY_GenerationContext` reachable while *parent* records
are being completed (they are currently completed before the child exists, so
this needs the parent-completion pass to run late, or a deferred re-evaluation).
Treat it as a follow-on to context-aware generation, not a separate effort.

---

## Sandbox Data Seeding

Although XFTY was designed as a test data factory for automated testing, its declarative model is also well suited to generating representative sandbox data.

In principle, relatively little of the architecture would need to change.

The primary obstacle is that the framework currently exists almost entirely as `@IsTest` code, allowing it to remain outside Salesforce production code limits.

Moreover, it allows -- and encourages -- developers to implement `XFTY_DummyDefaultValueIntf` and `XFTY_DummySobjectProviderIntf`,
also allowing these necessary extensions to the framework to remain outside those code limits.

Supporting sandbox seeding would require promoting the entire framework, including those implementations, into deployable production code, introducing additional considerations such as:
- package size
- code coverage
- deployment complexity
- distribution of custom Providers and value generators

The code coverage requirement would likely be a significant obstacle against adoption and use.

While this is not currently a development priority, the underlying architecture was designed in a way that could easily support this style of usage in the future.

**Sketch.** The `@IsTest`-vs-deployable tension does not have to be resolved
all-or-nothing:

- Split the repo into two package directories - `xfty-core` (the engine:
  factory, bundle, master template, lookup, value/relationship interfaces and
  the bundled generators) built **without** `@IsTest`, and `xfty-test-support`
  (anything only meaningful in a test, e.g. `XFTY_IdMocker`,
  `XFTY_DefaultUserDataProvider`'s admin-user bootstrapping) that stays
  `@IsTest`.
- `xfty-core` then needs real coverage. The existing behavioural suite already
  provides most of it; it would move to `xfty-core` test classes and lose the
  `System.runAs`/DML-only bits.
- Custom Providers and value generators written by *consumers* stay deployable
  code in their own package - which is normal, since they reference that
  package's SObjects anyway.
- A thin `XFTY_Seeder` entry point (list of `XFTY_DummySObjectProvider`
  configurations -> `insert`) would be the only genuinely new surface.

The `namespace` / AppExchange work in [packaging.md](../packaging.md) forces the
same split, so doing it once serves both goals.

---

## Framework Test Coverage — largely done

A behavioural suite now covers every value strategy, the Id mocker, bundles,
master templates, the provider fluent API, the factory (inclusivity x insert
modes, `relatedField`, quantity), the lookup and lookup keys, multi-variant
resolution, and the bundled Providers. ~100 tests, run in CI on a scratch org.

Remaining gaps worth closing: deeper multi-level graphs, circular-relationship
edge cases beyond `PREVENT_CASCADE`, and the open items in
[known-issues.md](known-issues.md).

