# Possible Future Enhancements

Although XFTY is stable, several ideas have been considered for future versions.

## Implicit Exact Values — implemented

`put(...)` now accepts a bare literal and wraps it in `XFTY_DummyDefaultValueExact`
automatically. See [Customization → Implicit Exact Values](customization.md#implicit-exact-values).

---

## Multi-Variant Providers — implemented

Providers are now keyed by `XFTY_LookupKeyIntf` - `SObjectType`, optionally +
record type (`XFTY_RecordTypeLookupKey`), optionally + arbitrary predicates on
the record (`XFTY_FlavouredLookupKey` + `XFTY_FieldPredicate`). A record can match
several keys; `keysFor` returns them all and the most specific wins. See
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

**Design (feedback incorporated).** Two per-invocation toggles - both wanted, not
just "include optional":

```apex
new XFTY_DummySObjectProvider(Opportunity.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .includeOptional(Opportunity.Pricebook2Id)          // this optional one, on top of REQUIRED
    .excludeRelationship(Opportunity.OwnerId)           // skip this one entirely
```

These affect **only the instance they are called on** - no global or nested side
effects.

Going deeper needs an explicit path down the graph:

```apex
.includeOptionalAncestor(new List<SObjectField>{ Opportunity.Pricebook2Id, Pricebook2.OwnerId })
// => for this invocation, make the generated Opportunity's Pricebook's Owner required
```

The engine walks the path, and at each hop hands the remaining tail to the child
Provider's generation as a scoped override.

**Explicit errors:** toggling a relationship whose target SObjectType has no
registered Provider must throw a clear error, not silently no-op.

**Open question.** `excludeRelationship` on a *required* field deliberately
produces an invalid record (useful for validation-rule tests) - or is that
strictly `removeFromMasterTemplate`'s job? Probably keep them distinct:
`exclude` skips *generation* but leaves the field for the test to set;
`removeFromMasterTemplate` drops the field's default entirely.

---

## Mixed-Type Template Lists — idea

`new XFTY_DummySObjectProvider(List<SObject> templates, lookup)` (and
`setOverrideTemplateList`) currently require every template to be the same
`SObjectType` (`ConflictException` otherwise). A future version could **chunk a
mixed-type list by `SObjectType`**, resolve a Provider per chunk, and return a
Bundle spanning all of them - one call to seed a heterogeneous set of records.

Open questions: what do `supply()` / `supplyList()` return when the result is
heterogeneous (probably restricted to `supplyBundle()`); how the per-chunk
variant is chosen; interaction with `withVariant` (which becomes per-chunk).
Ties into the depth-batched mixed-type insert in
[design/shared-ancestors.md](design/shared-ancestors.md).

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

Context means **both** sibling fields on the same record (`isOver18` from `age`)
**and** values from generated ancestors / other generated related records.

**Sketch.** `XFTY_DummyDefaultValueIntf.get()` takes no arguments, so a
context-aware generator needs more. Options, not mutually exclusive:

- a second interface `XFTY_DummyDefaultValue2Intf` (or similar) with
  `get(XFTY_GenerationContext context)`;
- additional `get(...)` overloads for whatever turns out useful
  (`get(SObject record)`, `get(XFTY_GenerationContext)`);
- more than one `XFTY_DummyDefault*Intf` if different shapes are worth it.

Since we are already making breaking changes, changing `XFTY_DummyDefaultValueIntf`
itself is also on the table.

`XFTY_GenerationContext` would expose the record being built (and its
already-set fields) plus the generated ancestor bundle.

**Ordering.** The factory discovers the graph child-first (see *Dynamic Ancestor
Configuration* below), so a *sibling* read is straightforward - evaluate that
field after the fields it depends on, on the same record. An *ancestor* read
needs the ancestor generated first, which the child-first walk already does; the
value is copied in a pass after ancestors exist but before the child's own
lookups are wired.

Concrete built-ins worth shipping: `XFTY_CopyFromSibling(field)`,
`XFTY_CopyFromAncestor(pathToField)`.

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

**How the graph is actually built.** XFTY discovers the object graph
*child-first*: it iterates a child's Master Template to learn which parents it
needs, generates those, then reads *their* Master Templates to learn which
grandparents *they* need, and so on until nothing new is required. (As Brian puts
it: children siring their own parents and grandparents.) So a value that flows
*down* the tree (grandparent value used on a parent used on the child) is
naturally available - the ancestor is generated before the descendant that reads
from it.

The genuinely twisty case is a value that flows *up* - an ancestor field whose
value depends on a descendant. That descendant doesn't exist yet when the
ancestor is first generated, so it needs a deferred pass: generate the whole
graph structurally, then evaluate "up-flowing" context-aware values once every
record exists in memory, then wire lookups and insert.

**Sketch.** This collapses into *Context-Aware Value Generation* above:

```apex
XFTY_DummyDefaultRelationship.of(new Account())
    .put(Account.Site, new XFTY_CopyFromDescendant(Contact.Department))
```

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

### Decision: drop `@IsTest` entirely?

The `@IsTest`-vs-deployable question is now close to a real decision, because the
framework is at **100% line coverage** (measured by temporarily stripping
`@IsTest`; org-wide coverage came out at 100%). Stripping permanently would:

**enable** running the engine outside a test context - i.e. sandbox seeding, and
letting consumers run generation from anonymous Apex / batch jobs.

**cost:**

1. **Org Apex character limit.** The framework is small (tens of KB) against the
   6,000,000-character org limit (higher on higher editions) - well under 1%.
   Negligible in practice.
2. **Perception.** A consumer still *sees* "this test framework added N classes
   to my production code" and may balk regardless of the actual number.
3. **Coverage.** Non-`@IsTest` framework lines count toward the org's 75% deploy
   requirement, so XFTY's own suite must hold it near 100% forever (it does now).
   This *raises the bar* permanently rather than being a one-off.
4. **Consumer ripple.** Consumers' own Providers and value generators extend the
   framework, so they would strip `@IsTest` too - re-raising (1)-(3) for them.
   Mitigation: their generator/Provider code is almost certainly covered by the
   tests they write anyway.

**Middle path:** split into `xfty-core` (deployable engine - factory, bundle,
master template, lookup, the value/relationship interfaces + generators) and
`xfty-test-support` (test-only helpers: `XFTY_IdMocker`,
`XFTY_DefaultUserDataProvider`'s admin bootstrap, the bundled Default Providers).
Consumers who only want the test factory install just `xfty-test-support`
(`@IsTest`, no limits); consumers who want seeding also install `xfty-core`.

A thin `XFTY_Seeder` (a list of `XFTY_DummySObjectProvider` configs -> `insert`)
is the only genuinely new surface either way.

The `namespace` / AppExchange work in [packaging.md](../packaging.md) forces the
same core/test-support split, so doing it once serves both goals.

### Two-package variant of the same idea

Rather than one package with an optional core, publish **two** similar packages:
one that keeps `@IsTest` (pure test factory, zero production footprint) and one
that strips it (seeding-capable), and let the consumer pick. Open question:
whether the `@IsTest` strip can be done reliably **as part of the publish
pipeline** (a source transform before `sf package version create`) so the two
packages build from one set of source files. If so, this is cheaper than
maintaining a real module split.

### Prior seeder recipe (from an earlier, now-lost implementation)

The last working sandbox seeder was crude but effective:

1. Strip `@IsTest` from every framework + Provider class.
2. Take the Provider Lookup's registered keys as the list of `SObjectType`s to
   populate (iterate `keysFor` / the key set).
3. Build a **chain of queueables**, one per type, each running roughly:

   ```apex
   new XFTY_DummySObjectProvider(sObjectType, providerLookup)
       .setQuantityPerTemplate(100)
       .setInsertMode(XFTY_InsertModeEnum.NOW)
       .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
       .supplyList();
   ```

   with best-effort exception swallowing so one bad type doesn't stop the chain.

A few types reliably failed - recollection is something around federated users
and/or unique-value collisions (`User.FederationIdentifier`, usernames). A real
implementation would need per-type opt-out and a way to feed `NOW`-inserted
ancestors back in rather than regenerating them.

---

## Framework Test Coverage — done

The framework is at **100% org-wide line coverage** (verified by temporarily
stripping `@IsTest` and running
`sf apex run test --code-coverage --detailed-coverage`), with no
intentionally-unreachable lines left in the engine - the `sObjectType == null`
guards and the `XFTY_DefaultAccountDataProvider` `masterTemplate == null` guard
were reviewed and removed once proven unreachable (see
[known-issues.md](known-issues.md)). Broadly-useful helper surface (the full
`XFTY_FieldPredicate` comparator, `XFTY_RecordTypeMatching`'s id fallback) is
kept and covered by tests rather than deleted - it exists to anticipate consumer
needs.

`XFTY_InsertModeEnum` / `XFTY_InsertInclusivityEnum` / the base
`XFTY_DummySObjectFtyProviderException` show 0% but have no coverable lines and
are excluded from the org-wide figure.

Salesforce computes only *line* coverage and none for `@IsTest` classes, so this
is a manual strip-to-measure exercise - re-run it whenever the engine changes.
Tests run in CI on a Person-Accounts-enabled scratch org (which also carries the
`test-support/` Person Account Provider).

Remaining gaps worth closing: deeper multi-level graphs, circular-relationship
edge cases beyond `PREVENT_CASCADE`, and the open items in
[known-issues.md](known-issues.md).

