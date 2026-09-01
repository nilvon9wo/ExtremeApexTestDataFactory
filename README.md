# XFTY (Extreme Apex Test Data Factory)

XFTY is a declarative test data factory for Salesforce Apex.

Instead of manually constructing complete `SObject` graphs for every test, you describe only the values your test actually cares about. XFTY supplies sensible defaults, automatically creates related records, and optionally inserts them or assigns realistic mock Ids.

By centralizing test data definitions, XFTY dramatically reduces boilerplate and makes tests more resilient to changing validation rules, required fields, and evolving business logic.

> ## 🚧 XFTY 4.0 is in beta
>
> The next major version is feature-complete and open for testing on the
> [`4.0-beta`](../../tree/4.0-beta) branch (also published as the
> [`v4.0.0-beta.1`](../../releases) pre-release). Highlights:
>
> - **Context-aware values** — a field derived from a sibling, an ancestor, or (deferred) a child
> - **Shared ancestors** — many children under one generated parent; flat or deep record-type hierarchies
> - **Downward generation** — `with(...)` generates the records *below* a primary, nested
> - **Per-call relationship control** — force or skip one relationship for a single call
> - **Deferred & depth-batched insert** — far fewer DML statements for large graphs
> - **Verified** — 100% line coverage on an org, and every documentation example backed by a runnable test
>
> It also carries **breaking API changes** (mostly mechanical renames) — the
> [4.0 migration guide](../../blob/4.0-beta/docs/reference/migration.md) has the
> exact before/after, and [CHANGELOG.md](CHANGELOG.md) the full list. Feedback →
> [start a Discussion](../../discussions) (or [open an issue](../../issues) for a
> bug). APIs may still shift before 4.0 final.

---

# Why XFTY?

As Salesforce projects grow, so does the amount of code required simply to create valid test data.

A `Contact` requires an `Account`. Later, a validation rule requires additional `Account` fields. Eventually another related object becomes mandatory. Over time, hundreds or even thousands of tests can end up duplicating nearly identical setup code.

XFTY centralizes that knowledge.

Instead of every test knowing how to construct a valid object graph, Providers define that logic once, allowing individual tests to override only the fields they actually care about.

The result is test code that is:

- shorter
- easier to read
- easier to maintain
- more resilient to application changes

---

# Features

- Declarative test data generation
- Automatic relationship generation
- Centralized default values
- Configurable relationship inclusivity
- Multiple persistence strategies
- Mock Salesforce Id generation without DML
- Extensible Provider architecture
- Suitable for both isolated unit tests and integration tests

---

# Quick Example

Generate a `Contact` with sensible defaults:

```apex
XFTY_DefaultSObjectProviderLookup providerLookup = new XFTY_DefaultSObjectProviderLookup();

Contact contact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .supply();
```

Override only the fields your test actually cares about:

```apex
Contact contact =
    (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .setOverrideTemplate(new Contact(
                FirstName = 'Alice'
        ))
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .supply();
```

Generate complete related object graphs:

```apex
XFTY_DummySObjectBundle bundle =
    new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .setInclusivity(XFTY_InsertInclusivityEnum.ALL)
        .supplyBundle();

Contact contact = (Contact) bundle.getList(Contact.Id)[0];
Account account = (Account) bundle.getList(Contact.AccountId)[0];

System.assertEquals(account.Id, contact.AccountId);
```

---

# Documentation

Detailed documentation is available in the `docs` directory.

| Document                                         | Description |
|--------------------------------------------------|-------------|
| [Getting Started](docs/getting-started.md)       | Introduction to XFTY and the basic API. |
| [Customization](docs/customization.md)           | Override templates, custom value generators, and advanced customization. |
| [Relationships](docs/relationships.md)           | Relationship generation, bundles, and navigating generated object graphs. |
| [Providers](docs/providers.md)                   | Creating Providers for additional `SObject` types. |
| [Testing Modes](docs/testing-modes.md)           | Insert modes and relationship inclusivity. |
| [Limitations](docs/salesforce-considerations.md) | Current limitations, recommended practices, and known trade-offs. |
| [Internals](docs/internals.md)                   | Architecture, implementation details, and design decisions. |
| [Future Ideas](docs/future-ideas.md)                   | Architecture, implementation details, and design decisions. |

---

# Design Philosophy

XFTY was designed around a simple idea:

> Tests should describe only what makes them unique.

Everything else should be generated automatically.

Rather than scattering test data throughout an entire codebase, XFTY moves that knowledge into reusable Providers that declaratively describe valid Salesforce objects and their relationships.

The framework then constructs those object graphs automatically, allowing test code to remain focused on the behaviour being tested rather than on setup.

---

# Roadmap

Ideas currently being considered for future versions include:

- Multiple Provider variants (`SObjectType + RecordType + Flavor`)
- Shared parent generation
- More granular relationship generation
- Automatic wrapping of literal values in `XFTY_DummyDefaultValueExact`
- Context-aware value generation across related records
- Dynamic ancestor customization
- Optional sandbox data seeding support
- Expanded framework test coverage

These are long-term ideas rather than committed features, but the architecture has been intentionally designed to make this kind of evolution possible.

---

# Contributing

Contributions, bug reports, feature requests, and discussions are welcome.

If you would like to contribute:

- Open an issue to discuss proposed changes.
- Keep Provider implementations declarative whenever possible.
- Preserve backwards compatibility unless a compelling reason exists not to.
- Prefer simplicity and readability over additional abstraction.

---

# License

This project is released under the MIT License.