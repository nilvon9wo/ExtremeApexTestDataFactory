# XFTY Internals

This document describes the internal architecture of XFTY and the design decisions behind it.

Most users only need the public API documented elsewhere. This guide is intended for developers who want to understand how the framework works internally, extend it, or contribute to its development.

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
| `XFTY_GenerationContext` | The per-run state the engine threads everywhere: Provider Lookup, insert mode, inclusivity (and, in future, the record being built + its ancestors). |
| `XFTY_DummySObjectFactory` | Engine that constructs the object graph. |
| `XFTY_DummySObjectBundle` | Represents the generated graph. |
| `XFTY_DummyDefaultValueIntf` | Strategy interface for generating field values. |
| `XFTY_DummyDefaultRelationship` | Strategy for generating related records. |
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
         new XFTY_DummyDefaultValueIncrementingString("Account"))
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

# Two-Phase Graph Construction

Object creation occurs in multiple phases.

## Phase 1 – Create Objects

The Factory recursively creates every required `SObject`.

At this stage the objects exist, but relationships have not yet been wired together.

## Phase 2 – Assign Ids

Depending on the selected insert mode, objects are either:

- inserted
- assigned mock Ids
- left without Ids

Performing this as a separate phase allows every object at the current level to be inserted using a single DML operation rather than one insert per relationship or object type.

## Phase 3 – Wire Relationships

Once related records possess Ids, lookup fields can be populated.

This separation greatly simplifies recursion while ensuring every lookup points at a valid record.

## Value passes

Field values are filled in **two passes**, so a strategy can be aware of the rest
of the record:

1. **Plain values** - the `XFTY_DummyDefaultValueIntf` strategies (Master Template
   `defaultBySObjectFieldMap`), in the order the fields were `put` (the template
   keeps an explicit order list - Apex `Map` iteration order is not guaranteed).
2. **Context-aware values** - the `XFTY_ContextAwareValueIntf` strategies (a
   separate map, `contextAwareBySObjectFieldMap`), after the ancestor records
   exist and lookups are wired. Each is handed a `XFTY_GenerationContext` scoped
   to its record (`recordBeingBuilt`, `bundleSoFar`, `rowIndex`).

A context-aware value therefore sees all plain values, all wired lookups, and any
context-aware value `put` before it. It cannot see a later context-aware value or
a field on a generated *child* (which does not exist yet - that would need a
deferred pass; see [design/context-aware-values.md](design/context-aware-values.md)).

---

# The Generation Context

Every step of one `supply*()` call - the top-level build and each level of
relationship recursion - needs the same three things: the Provider Lookup, the
insert mode, and the relationship inclusivity. These travel together as an
`XFTY_GenerationContext` rather than as separate arguments.

The context is also where the two **recursion transforms** live, in
`context.forRelated()` - the context handed to a child (ancestor) build:

| Parent context | Child context | Why |
|----------------|---------------|-----|
| `insertMode = RELATED_ONLY` | `insertMode = NOW` | The parents of a not-inserted primary record must still be inserted, or the primary can't reference them. |
| `inclusivity = PREVENT_CASCADE` | `inclusivity = NONE` | The direct relationships are generated, but they do not generate their own - the cascade stops one level down. |
| anything else | unchanged | |

Because the transform is in one method, "what does `PREVENT_CASCADE` actually
prevent" has a single, readable answer.

The context is the intended extension point for context-aware value generation
(it would carry the record being built and the generated ancestor bundle) and for
the shared-ancestor insert-mode declaration - see
[future-ideas.md](future-ideas.md) and
[design/shared-ancestors.md](design/shared-ancestors.md).

---

# Value Providers

Rather than storing literal values, Master Templates store **strategies** for generating values.

Every value provider implements:

```apex
XFTY_DummyDefaultValueIntf
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
it. See [docs/design/multi-variant-providers.md](design/multi-variant-providers.md).

---

# Design Trade-offs

Several implementation decisions intentionally favour simplicity over maximum flexibility.

Examples include:

- every child currently receives its own generated parent
- relationship generation is controlled by broad inclusion modes
- Provider Lookup uses only `SObjectType` as its key

These choices keep the framework predictable while covering the overwhelming majority of testing scenarios.

---

# Final Thoughts

XFTY intentionally separates *describing* test data from *constructing* test data.

Tests remain focused on the behaviour being verified.

Providers describe valid business objects.

The Factory constructs complete graphs.

Bundles preserve those graphs.

This separation of responsibilities keeps the public API compact while allowing the framework's internal engine to handle the complexity of generating realistic Salesforce test data.