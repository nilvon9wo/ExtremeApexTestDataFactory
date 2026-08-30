# Possible Future Enhancements

Although XFTY is stable, several ideas have been considered for future versions.

## Implicit Exact Values — implemented

`put(...)` now accepts a bare literal and wraps it in `XFTY_DummyDefaultValueExact`
automatically. See [Customization → Implicit Exact Values](customization.md#implicit-exact-values).

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

