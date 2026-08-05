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
| `XFTY_DummySobjectProviderIntf` | Describes how one `SObject` type should be generated. |
| `XFTY_DummySObjectMasterTemplate` | Declarative description of default values and relationships. |
| `XFTY_DummySObjectFactory` | Engine that constructs the object graph. |
| `XFTY_DummySObjectBundle` | Represents the generated graph. |
| `XFTY_DummyDefaultValueIntf` | Strategy interface for generating field values. |
| `XFTY_DummyDefaultRelationship...` | Strategy for generating related records. |
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
    .put(Account.OwnerId,
         new XFTY_DummyDefaultRelationshipRequired(
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

# Record Types

Record Types are one area where XFTY intentionally remains simple.

Provider Lookup currently maps a single Provider to each `SObjectType`.

As a result, supporting multiple Record Types for the same object currently requires custom Provider logic.

A common approach is for the Provider to inspect the override template and choose the appropriate Master Template internally.

Although somewhat manual, this keeps the framework itself relatively simple.

---

# Design Trade-offs

Several implementation decisions intentionally favour simplicity over maximum flexibility.

Examples include:

- every child currently receives its own generated parent
- relationship generation is controlled by broad inclusion modes
- Provider Lookup uses only `SObjectType` as its key

These choices keep the framework predictable while covering the overwhelming majority of testing scenarios.

---

# Possible Future Enhancements

Although XFTY is stable, several ideas have been considered for future versions.

## Implicit Exact Values

Most fields in a Master Template are populated with fixed values.

Currently these must be wrapped explicitly using `XFTY_DummyDefaultValueExact`.

```apex
.put(Account.Type, new XFTY_DummyDefaultValueExact("Customer"))
```

Although this makes the implementation consistent, it also introduces a considerable amount of boilerplate because exact values are a very common case.

A future version may allow arbitrary values to be passed directly to `put(...)`.

```apex
.put(Account.Type, "Customer")
```

If the supplied object does not implement either `XFTY_DummyDefaultValueIntf` or `XFTY_DummyDefaultRelationshipIntf`, the framework could automatically wrap it in `XFTY_DummyDefaultValueExact`.

This would preserve the existing extensibility model while making Provider implementations significantly cleaner and more readable.

---

## Multi-Variant Providers

Instead of resolving Providers using only `SObjectType`, a future implementation may support keys such as:

```text
SObjectType
+ Record Type
+ Flavor
```

where *Flavor* is an arbitrary identifier chosen by the developer.

This would allow multiple default configurations for the same object without custom Provider logic.

---

## Shared Parent Records

Currently, each generated child receives its own generated parent.

Although tests can re-parent records afterwards, some scenarios—particularly hierarchical data—would benefit from declaratively generating shared parents.

---

## More Granular Relationship Generation

Relationship generation currently supports:

- `NONE`
- `REQUIRED`
- `ALL`
- `PREVENT_CASCADE`

Future versions may allow finer-grained control over which optional relationships are generated.

---

## Relationship Consolidation

`XFTY_DummyDefaultRelationshipRequired` and `XFTY_DummyDefaultRelationshipOptional` currently exist as separate types.

Although this provides clean polymorphism, a future implementation may instead represent requiredness as metadata within a single relationship class, simplifying the API while enabling more sophisticated inclusion policies.

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

---

## Dynamic Ancestor Configuration

Relationship override templates already allow customization of generated parent records.

For example:

```apex
.put(
    Foo__c.Account__c,
    new XFTY_DummyDefaultRelationshipRequired(
        new Account(Bar__c = someId)
    )
)
```

This allows tests to specify static values on generated parents, grandparents, and even more distant ancestors.

However, these templates are entirely declarative. There is currently no mechanism for computing ancestor values dynamically during graph generation or for making those values depend on the generated graph itself.

Although relatively uncommon, some integration testing scenarios would benefit from being able to configure ancestors programmatically as the graph is constructed.

This would likely require extending the generation engine rather than simply adding another implementation of `XFTY_DummyDefaultValueIntf`, and it remains an area for future investigation.

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

---

## Framework Test Coverage

Although XFTY has been exercised extensively through real-world use, expanding the framework's own automated test suite remains a desirable future improvement.

---

# Final Thoughts

XFTY intentionally separates *describing* test data from *constructing* test data.

Tests remain focused on the behaviour being verified.

Providers describe valid business objects.

The Factory constructs complete graphs.

Bundles preserve those graphs.

This separation of responsibilities keeps the public API compact while allowing the framework's internal engine to handle the complexity of generating realistic Salesforce test data.