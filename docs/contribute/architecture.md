# XFTY Architecture

This document describes the internal architecture of XFTY and the design decisions behind it.

Most users only need the public API in [../use/](../use/) and [../extend/](../extend/). This guide is for developers who want to understand how the framework works internally, or contribute to it.

Unlike the other documentation, this guide focuses on *why* the framework was designed the way it was rather than simply describing individual classes.

---

# Design Goals

XFTY is first and foremost a **test data factory**.

Its goal is to make Salesforce test setup:

- concise
- maintainable
- declarative
- reusable

To achieve this, XFTY includes a small engine responsible for constructing complete object graphs, applying default values, generating related records, and optionally persisting them.

The engine exists so that test code doesn't have to.

A typical test should describe only the data it actually cares about, while XFTY supplies everything else.

---

# High-Level Architecture

The overall architecture can be viewed as a pipeline.

```text
Tests
   │
   ▼
XFTY_DummySObjectProvider
   │
   ▼
Provider Lookup
   │
   ▼
SObject Provider
   │
   ▼
Master Template
   │
   ▼
Factory Engine
   │
   ▼
Bundle
```

Each component has a single responsibility.

| Component | Responsibility |
|-----------|----------------|
| `XFTY_DummySObjectProvider` | Public fluent API used by tests. |
| `XFTY_DummySObjectProviderLookupIntf` | Resolves which Provider should generate a particular `SObject`. |
| `XFTY_DefaultSObjectProviderLookup` | Copy-me starter implementation (also XFTY's own self-test lookup). |
| `XFTY_ProviderLookups` | Reusable lookup mechanics, so a project's lookup stays a few one-liners over a `Map`. |
| `XFTY_LookupKeyIntf` / `XFTY_LookupKey` | Identifies a Provider variant (`SObjectType`, optionally + record type / flavour). |
| `XFTY_DummySobjectProviderIntf` | Describes how one `SObject` type should be generated. |
| `XFTY_DummySObjectMasterTemplate` | Declarative description of default values and relationships. |
| `XFTY_GenerationContext` | The per-run state the engine threads everywhere: Provider Lookup, insert mode, inclusivity, forced-relationship paths, `batchedInsertPending`, and — during the value pass — the record being built, its ancestor bundle, and the field currently being generated (`valueFieldPass`). |
| `XFTY_DummySObjectFactory` | Thin coordinator — drives the phase classes below. |
| `XFTY_AncestorGenerator` | Phase: generate one level of related (ancestor) records. |
| `XFTY_LookupWiring` | Phase: point each record's lookup fields at its generated parents. |
| `XFTY_PlainValueFiller` | Phase: fill the plain (`XFTY_ValueExpressionIntf`) values. |
| `XFTY_ContextAwareValuePass` | Phase: run the $1 expressions, one field at a time. |
| `XFTY_DescendantValuePass` / `XFTY_DeferredGraph` | Up-flow value pass at the top of the `DEFERRED` flush: fill each `XFTY_DeferredExpressionIntf` (`XFTY_CopyFromDescendantExpression`) from that record's now-generated children, read through the collected parent links. |
| `XFTY_ValueFieldPass` | The narrowest scope — one context-aware field + the set of sibling context-aware fields not yet generated (drives `context.siblingValue`'s loud guard). |
| `XFTY_RelationshipForcer` | Applies `includeOptional(...)` / `put(path,...)` relationship-prefix paths to a per-call copy of the Master Template. |
| `XFTY_PathValue` / `XFTY_PathValueApplier` | A `put(List<SObjectField>, value)` override targeted at a generated ancestor; the applier lands the at-target ones on the level's template. |
| `XFTY_SObjectChildProvider` | Config for one downward child collection (`with(...)` / `withChildren(...)`); builds the child Provider + templates, recursively for grandchildren. |
| `XFTY_SharedRelationshipWiring` | Wires an `XFTY_SharedAncestor` (one resolved record, every child pointed at it). |
| `XFTY_SharedAncestorResolver` | The S0–S2 pre-phase for shared ancestors: collect (dependency-ordered, nested, cycle/depth/re-entrancy guards) → generate `NEVER` → depth-batched persist per sub-graph. Runs for every configured `XFTY_SharedAncestor`; talks only to `XFTY_SharedAncestorProvider`. |
| `XFTY_SharedAncestorProvider` | The single recipe for one shared ancestor's record — key ± override template plus the same per-record API a generated parent takes (value expressions, its own relationships, `includeOptional`, path values, inclusivity). No multi-record knobs, so no runtime guard. The resolver works from this and never branches on configuration kind. |
| `XFTY_RecordCloneFactory` | Deep-clones templates so no two generated records share an instance. |
| `XFTY_IndexedRecord` | An `(index, record)` pair — records are identified by position, since Apex `SObject` equality is by value. |
| `XFTY_DepthBatchedInserter` | Kahn-style layered insert: one `insert` per dependency depth. |
| `XFTY_DeferredInserter` / `XFTY_DeferredInsertBuffer` | The `DEFERRED` registry and its bundle-walk; `flush()` runs `XFTY_DepthBatchedInserter` over the union. |
| `XFTY_DummySObjectBundle` | Represents the generated graph. |
| `XFTY_ValueExpressionIntf` / `XFTY_ContextAwareExpressionIntf` / `XFTY_DeferredExpressionIntf` | Expression interfaces for generating field values (plain / context-aware / up-flow). |
| `XFTY_DummyDefaultRelationshipIntf` / `XFTY_DummyDefaultRelationship` / `XFTY_SharedRelationshipIntf` / `XFTY_SharedAncestor` | Interfaces + implementations for generating related records. |
| `XFTY_LookupKeyIntf` / `XFTY_LookupKey` / `XFTY_RecordTypeLookupKey` / `XFTY_FlavouredLookupKey` | Identify a Provider variant. |
| `XFTY_SObjectPredicateIntf` + `XFTY_Field{EqualTo,GreaterThan,LessThan,InSet}Predicate` / `XFTY_ValueComparison` / `XFTY_{AllOf,AnyOf,Negation}Predicate` / `XFTY_FieldPredicate` + `XFTY_Predicates` (facades) | Conditions a flavoured key matches a record against - one small class per operator, no branching. |
| `XFTY_IdMocker` | Generates realistic Salesforce Ids without DML. |

Keeping these responsibilities separate makes each component relatively small and easy to reason about.

---

# Declarative Rather Than Imperative

One of the fundamental design goals was to avoid imperative construction of test data.

Instead of writing code such as:

```apex
Account account = new Account(...);
insert account;

Contact contact = new Contact(...);
contact.AccountId = account.Id;
insert contact;
```

Providers instead declare *what* should exist.

```apex
new XFTY_DummySObjectMasterTemplate(Account.Id)
    .put(Account.Name,
         new XFTY_IncrementingStringExpression("Account"))
    .putRequired(Account.OwnerId,
         new XFTY_DummyDefaultRelationship(
             new User()
         ));
```

The framework is responsible for determining *how* that object graph should be created.

Separating the description of the graph from its construction makes Providers much smaller and easier to maintain.

---

# Master Templates

The `XFTY_DummySObjectMasterTemplate` class is the declarative heart of XFTY.

A Master Template describes:

- default field values
- required relationships
- optional relationships

Internally these are simply stored in three maps.

```text
Default Values
Required Relationships
Optional Relationships
```

Each map is keyed by `SObjectField`, allowing the template to describe exactly how every field should be populated.

The fluent `put(...)` methods make Provider implementations concise while keeping the template itself immutable once cloned for use.

---

# Why Relationships Are Keyed by `SObjectField`

Relationships are intentionally keyed by **the field that stores the lookup Id**, not by `SObjectType`.

This serves several purposes.

First, it tells XFTY exactly which field needs to be populated.

Second, it keeps graph construction and graph navigation consistent.

Finally, it naturally supports multiple relationships to the same object type.

For example:

```text
PrimaryContact__c
SecondaryContact__c
BillingContact__c
```

may all reference `Contact`, but they represent different relationships.

Treating the field as the identity of the relationship avoids ambiguity throughout the framework.

---

# Object Graphs

The Factory constructs complete object graphs rather than isolated records.

For example:

```text
Contact
    │
    ▼
Account
    │
    ▼
Owner
```

Each relationship is represented by its own nested `XFTY_DummySObjectBundle`.

This preserves the recursive structure of the generated graph.

Destroying that hierarchy and flattening everything into collections would require additional work while losing useful structural information.

---

# Why Bundles Contain Bundles

A `Bundle` stores two kinds of information.

- the generated `SObject` instances
- child Bundles representing generated relationships

This allows callers to retrieve either:

```apex
bundle.getList(Contact.AccountId)
```

or

```apex
bundle.getBundle(Contact.AccountId)
```

depending on whether they need the related records themselves or the entire subgraph beneath them.

Because the internal representation mirrors the generated graph, recursive construction becomes straightforward and the implementation remains simple.

---

# Graph construction phases

`XFTY_DummySObjectFactory` is a thin coordinator; each phase is its own class.
For one Provider's records:

0. **Shared ancestors** (`XFTY_SharedAncestorResolver`, from
   `XFTY_DummySObjectProvider.supplyBundle()` →
   `XFTY_SharedAncestorResolver.resolveAllConfigured`) — every
   `XFTY_SharedAncestor` configured this test method is collected
   (dependency-ordered, following nested shared ancestors), generated in memory
   (`NEVER`), and persisted one depth-batched pass per sub-graph, **before**
   step 1, honouring the call's insert mode (`DEFERRED` / `RELATED_ONLY` → `NOW`
   so the shared Id is ready). Flat ancestors (Provider has no relationships)
   collapse to a single record. One configured after this ran (a later
   `supply*()` call) resolves itself the same way when first referenced.
1. **Ancestors** (`XFTY_AncestorGenerator`) — recursively generate one level of
   related records. At this point the objects exist but lookups are not wired.
   A relationship named in an `includeOptional(...)` / `put(path, ...)` path is
   generated here whatever the inclusivity, and *fully formed* (its own required
   relationships fill in). An `XFTY_SharedRelationshipIntf` value means "0 to
   generate — wire the one resolved record".
2. **Id assignment** — depending on the insert mode the records are inserted
   (`NOW`), given mock Ids (`MOCK`), or left Id-less. Doing this as a separate
   phase lets every record at a level be inserted in one DML operation rather
   than one per type. `.depthBatched()` / `DEFERRED` move this out of the
   recursion entirely (`XFTY_DepthBatchedInserter`).
3. **Lookup wiring** (`XFTY_LookupWiring`) — once parents have Ids, point each
   child's lookup fields at them.
4. **Plain value pass** (`XFTY_PlainValueFiller`).
5. **Context-aware value pass** (`XFTY_ContextAwareValuePass`) — below.
6. **Up-flow value pass** (`XFTY_DescendantValuePass`) — only under `DEFERRED` /
   `.depthBatched()`, at the top of the flush, once every record exists. Fields
   with an $1 expression are left unresolved by phase 5 and
   filled here from that record's collected children. A non-batched build that
   carries one throws in phase 5 instead.

## Value passes

Field values are filled in **two in-line passes plus one deferred pass**, so a
expression can be aware of the rest of the record:

1. **Plain values** - the $1 expressions (Master Template
   `defaultBySObjectFieldMap`), in the order the fields were `put` (the template
   keeps an explicit order list - Apex `Map` iteration order is not guaranteed).
2. **Context-aware values** - the $1 expressions (a
   separate map, `contextAwareBySObjectFieldMap`), after the ancestor records
   exist and lookups are wired. Each is handed a `XFTY_GenerationContext` scoped
   to its record (`recordBeingBuilt`, `bundleSoFar`, `rowIndex`) and to the one
   field being generated (`valueFieldPass`, which also carries the set of
   context-aware fields not yet reached).

A context-aware value therefore sees all plain values, all wired lookups, and any
context-aware value `put` before it. Reading a *later* context-aware value, or a
circular pair, throws from `context.siblingValue(field)` - naming both fields and
the `put` order that fixes it - rather than returning a silent wrong `null`;
the not-yet-reached set is what separates that case from a sibling that was
genuinely generated to `null`.

3. **Up-flow values** - the $1 expressions (a third map,
   `deferredValueBySObjectFieldMap`). A field on a generated *child* cannot be
   read in-line - the child does not exist yet - so these are left unresolved
   and filled by `XFTY_DescendantValuePass` at the top of the `DEFERRED` flush,
   reading the child through `XFTY_DeferredGraph.childrenOf(index, field)` over
   the parent links `XFTY_DeferredInsertBuffer` collected. A build that is not
   `DEFERRED` / `.depthBatched()` and carries one throws - the forest never
   exists otherwise. See
   [roadmap/descendant-value-reads.md](../roadmap/descendant-value-reads.md).

Design rationale: [roadmap/context-aware-values.md](../roadmap/context-aware-values.md).

---

# The Generation Context

Every step of one `supply*()` call - the top-level build and each level of
relationship recursion - needs the same run-wide state: the Provider Lookup, the
insert mode, the relationship inclusivity, the forced-relationship paths, and the
`batchedInsertPending` flag. These travel together as an `XFTY_GenerationContext`
rather than as separate arguments. During the value pass a derived context also
carries the record being built, the bundle so far, the row index, and the field
currently being generated (`valueFieldPass`); everywhere else those are null.

The context is also where the two **recursion transforms** live, in
`context.forRelated()` - the context handed to a child (ancestor) build:

| Parent context | Child context | Why |
|----------------|---------------|-----|
| `insertMode = RELATED_ONLY` | `insertMode = NOW` | The parents of a not-inserted primary record must still be inserted, or the primary can't reference them. |
| `inclusivity = PREVENT_CASCADE` | `inclusivity = NONE` | The direct relationships are generated, but they do not generate their own - the cascade stops one level down. |
| anything else | unchanged | |

Because the transform is in one method, "what does `PREVENT_CASCADE` actually
prevent" has a single, readable answer.

The context also carries the `put(List<SObjectField>, value)` path values
(`pathValues`), filtered head-first through `forRelated(field)` like the forced
paths, and `withInclusivity(...)` for generating a forced ancestor fully formed.
The shared-ancestor pre-phase takes its insert mode from the `supply*()` call
that triggers it (or from `XFTY_SharedAncestor.resolveNow(lookup, mode)` when a
test resolves one before any call). The up-flow value pass
(`XFTY_DescendantValuePass`) runs at the top of that same flush, over the parent
links the buffer collected — see
[roadmap/descendant-value-reads.md](../roadmap/descendant-value-reads.md).

---

# Value Providers

Rather than storing literal values, Master Templates store **expressions** for generating values.

Every value provider implements:

```apex
XFTY_ValueExpressionIntf
```

This allows generated values to be:

- constant
- incrementing
- unique
- calculated
- completely custom

without changing any framework code.

---

# Stateful Value Providers

Some value providers intentionally maintain internal state.

For example:

```text
Account 1
Account 2
Account 3
```

is usually preferable to repeatedly generating:

```text
Account 1
Account 1
Account 1
```

Similarly, unique email providers coordinate generation to avoid duplicate values.

This behaviour exists solely to improve the realism of generated data while keeping Provider implementations concise.

---

# Immutability

XFTY clones templates aggressively.

Whenever records are generated, the framework creates new instances rather than modifying shared objects.

This avoids accidental sharing between generated records and prevents Providers from unexpectedly affecting one another.

Although cloning introduces a small amount of overhead, the improved predictability is well worth the cost in test code.

---

# Mock Id Generation

One of XFTY's distinguishing features is its ability to generate realistic Salesforce Ids without performing DML.

`XFTY_IdMocker` combines:

- the object's Salesforce key prefix
- a fixed identifier
- an incrementing counter

to produce unique 15-character Ids.

These Ids behave like normal Salesforce Ids for almost all testing purposes while avoiding the cost of database inserts.

---

# Provider Lookup

Rather than using a global registry, XFTY requires callers to explicitly provide a Provider Lookup.

This allows different applications or packages to define different Provider collections.

One important use case is SFDX packaging.

Some Providers reference metadata that exists only within particular packages.

Separating Provider Lookups allows each package to expose only the Providers that it can successfully compile, avoiding cross-package compilation dependencies.

It also naturally supports different Provider sets for different projects, test suites, or organizational conventions.

---

# Why `getPrimaryTargetField()` Exists

Most standard Salesforce objects identify records using the `Id` field.

However, not every Salesforce data type follows this pattern.

Rather than assuming every generated object can be identified by `Id`, Providers explicitly expose their primary target field.

This field is used internally when:

- retrieving generated records from Bundles
- wiring relationships
- identifying the Provider's primary output

Although this is usually `Id`, using a configurable field makes the framework more flexible and avoids baking unnecessary assumptions into the engine.

---

# Record Types and Variants

Provider Lookup keys a Provider by an `XFTY_LookupKeyIntf`, not a bare
`SObjectType`. The default key (`XFTY_LookupKey`) *is* just the type, so the
common case is unchanged; refined keys add a discriminator:
`XFTY_RecordTypeLookupKey` (record type), `XFTY_FlavouredLookupKey` (optional
record type + arbitrary `XFTY_SObjectPredicateIntf` conditions), or a custom one.
`getSpecificity()` orders them (0 / 10 / 20+).

All keys are flyweights (`.get(...)`) and override `equals`/`hashCode` by
`getHashKey()`, so they work as `Map` keys directly. A lookup is therefore just a
`Map<XFTY_LookupKeyIntf, Type>` (or `..., provider instance>`) plus three
one-line methods delegating to `XFTY_ProviderLookups` - no base class, no
registry, no mutation. When a relationship supplies only an override template,
`keysFor(sObj)` returns every registered key that matches (a record can match
several) and `XFTY_ProviderLookups.resolve` picks the most specific; the result
is memoised on the relationship, and an equally-specific tie is an error.

Every project writes its own lookup: editing a shipped class hurts upgrades, and
in a multi-package org a lookup may only reference Providers that compile in its
context - the reason Providers resolve through an interface at all.
`@IsTest` classes cannot be abstract or virtual, so the pattern is copy, not
extend; `XFTY_DefaultSObjectProviderLookup` is the copy-me example (and XFTY's
own self-test lookup). Refined keys wrap an `XFTY_LookupKey` rather than subclass
it. See [roadmap/multi-variant-providers.md](../roadmap/multi-variant-providers.md).

---

# Design Trade-offs

Several implementation decisions intentionally favour simplicity over maximum flexibility.

Examples include:

- by default every child receives its own generated parent
  ([shared ancestors](../use/shared-ancestors.md) opt out of this)
- relationship generation is controlled by broad inclusion modes, with per-call
  exceptions ([includeOptional / excludeRelationship](../use/per-call-relationships.md))
- insertion is one DML per Provider by default
  ([`.depthBatched()` / `DEFERRED`](../use/deferred-insert.md) collapse it)

These choices keep the framework predictable while covering the overwhelming majority of testing scenarios.

---

# Final Thoughts

XFTY intentionally separates *describing* test data from *constructing* test data.

Tests remain focused on the behaviour being verified.

Providers describe valid business objects.

The Factory constructs complete graphs.

Bundles preserve those graphs.

This separation of responsibilities keeps the public API compact while allowing the framework's internal engine to handle the complexity of generating realistic Salesforce test data.