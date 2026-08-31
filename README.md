# XFTY (Extreme Apex Test Data Factory)

[![CI](https://github.com/nilvon9wo/ExtremeApexTestDataFactory/actions/workflows/ci.yml/badge.svg)](https://github.com/nilvon9wo/ExtremeApexTestDataFactory/actions/workflows/ci.yml)

XFTY is a declarative test data factory for Salesforce Apex.

Instead of manually constructing complete `SObject` graphs for every test, you describe only the values your test actually cares about. XFTY supplies sensible defaults, automatically creates related records, and optionally inserts them or assigns realistic mock Ids.

By centralizing test data definitions, XFTY dramatically reduces boilerplate and makes tests more resilient to changing validation rules, required fields, and evolving business logic.

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

Full documentation is in [`docs/`](docs/README.md), organised by audience:

| I want to… | Go to |
|------------|-------|
| **Use XFTY to write tests** | [docs/use/](docs/use/) — start with [getting-started](docs/use/getting-started.md) |
| **Teach XFTY about my org's SObjects** | [docs/extend/](docs/extend/) |
| **Work on XFTY itself** | [docs/contribute/](docs/contribute/) — [architecture](docs/contribute/architecture.md) |
| **Look something up** | [docs/reference/](docs/reference/) — [migration](docs/reference/migration.md), [known-issues](docs/reference/known-issues.md) |
| **See what's built / planned** | [docs/roadmap/](docs/roadmap/README.md) |

---

# Design Philosophy

XFTY was designed around a simple idea:

> Tests should describe only what makes them unique.

Everything else should be generated automatically.

Rather than scattering test data throughout an entire codebase, XFTY moves that knowledge into reusable Providers that declaratively describe valid Salesforce objects and their relationships.

The framework then constructs those object graphs automatically, allowing test code to remain focused on the behaviour being tested rather than on setup.

---

# Roadmap

Recently landed (see [migration](docs/reference/migration.md) for the breaking changes):

- Provider variants by `SObjectType` + record type + flavour
- Implicit literal wrapping in `put(...)`
- Context-aware value generation (sibling + ancestor reads), with a loud guard for mis-ordered reads
- Per-call relationship control (`includeOptional`, `excludeRelationship`)
- Shared ancestors (on-demand)
- 100% framework line coverage; split unit / integration / load test suites

The full status table — done, in progress, and proposed, with the open question
on each — is [docs/roadmap/README.md](docs/roadmap/README.md).

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