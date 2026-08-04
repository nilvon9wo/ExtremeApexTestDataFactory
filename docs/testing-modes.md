# Testing Modes

XFTY separates two independent concerns:

1. **Should related records be generated?**
2. **Should generated records be inserted into the database?**

These concerns are controlled independently using:

- `XFTY_InsertInclusivityEnum`
- `XFTY_InsertModeEnum`

Keeping these decisions separate allows tests to precisely control both the size of the generated object graph and the amount of database interaction.

---

# The Two Axes

Relationship generation and persistence are independent.

For example:

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
```

generates:

- a Contact
- any required related records
- realistic Salesforce Ids

without performing any DML.

Conversely,

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.NONE)
.setInsertMode(XFTY_InsertModeEnum.NOW)
```

inserts only the explicitly requested records.

Thinking about these settings independently makes the API much easier to understand.

---

# Insert Modes

Insert Modes determine what happens **after** records have been generated.

| Mode | Behaviour |
|------|-----------|
| `NEVER` | Generate records without Ids. |
| `MOCK` | Generate mock Salesforce Ids without performing DML. |
| `RELATED_ONLY` | Insert only generated related records. |
| `NOW` | Insert all generated records. |
| `LATER` | Behaves like `NEVER` while documenting that insertion will occur later. |

The generated data itself is identical regardless of Insert Mode.

Only persistence changes.

---

# NEVER

```apex
.setInsertMode(XFTY_InsertModeEnum.NEVER)
```

Records are generated but are not inserted.

No Salesforce Ids are assigned.

This mode is useful when:

- the test never inspects Id fields
- the caller intends to insert records manually
- testing object construction only

---

# MOCK

```apex
.setInsertMode(XFTY_InsertModeEnum.MOCK)
```

Records are **not** inserted.

Instead, XFTY generates realistic-looking Salesforce Ids.

This allows unit tests to exercise code that depends on record Ids without paying the cost of DML.

For example:

```apex
Contact contact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
        .setInsertMode(XFTY_InsertModeEnum.MOCK)
        .supply();

System.assertNotEquals(null, contact.Id);
```

Because no records exist in the database, these Ids should never be queried or updated.

---

# RELATED_ONLY

```apex
.setInsertMode(XFTY_InsertModeEnum.RELATED_ONLY)
```

This mode inserts only generated related records.

The primary objects requested by the test remain uninserted.

This is useful when a test needs valid lookup targets but wants to control the insertion of the primary records itself.

Internally, XFTY temporarily upgrades relationship generation to `NOW` while leaving the primary records untouched.

---

# NOW

```apex
.setInsertMode(XFTY_InsertModeEnum.NOW)
```

Every generated record is inserted.

This includes:

- requested records
- required related records
- optional related records (when applicable)

Use this mode for integration tests that interact with the Salesforce database.

---

# LATER

```apex
.setInsertMode(XFTY_InsertModeEnum.LATER)
```

`LATER` behaves exactly like `NEVER`.

The difference is semantic rather than technical.

It communicates the intention that the caller expects to insert the records later.

This can make tests easier to understand by documenting intent directly in the setup code.

---

# Choosing an Insert Mode

Most tests naturally fall into one of these categories.

| Scenario | Recommended Mode |
|-----------|------------------|
| Pure unit test | `MOCK` |
| Testing object construction | `NEVER` |
| Test inserts records itself | `LATER` |
| Need inserted lookup targets only | `RELATED_ONLY` |
| Integration test | `NOW` |

When in doubt, prefer the least amount of database interaction necessary.

---

# Relationship Inclusivity

Relationship Inclusivity determines how much of the object graph should be generated.

| Mode | Behaviour |
|------|-----------|
| `NONE` | Generate no related records. |
| `REQUIRED` | Generate only required relationships. |
| `ALL` | Generate required and optional relationships. |
| `PREVENT_CASCADE` | Generate only direct relationships without recursively generating their relationships. |

Unlike Insert Mode, Inclusivity affects **what** is generated rather than **how** it is persisted.

---

# NONE

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.NONE)
```

No relationships are generated.

The caller is responsible for supplying every related record.

Use this mode when tests intentionally want complete control over the generated object graph.

---

# REQUIRED

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
```

Only relationships explicitly marked as required are generated.

This is the recommended default.

It produces valid records while keeping generated object graphs relatively small.

---

# ALL

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.ALL)
```

Both required and optional relationships are generated.

This produces richer test data but may significantly increase the size of generated object graphs.

Use this mode only when tests genuinely benefit from additional relationships.

---

# PREVENT_CASCADE

Relationship generation is normally recursive.

Suppose an `OpportunityLineItem` requires an `Opportunity`, and an
`Opportunity` requires an `Account`.

Using `REQUIRED` produces:

```text
OpportunityLineItem
└── Opportunity
    └── Account
```

Sometimes Providers naturally form recursive or circular relationship graphs.

For example:

```text
Account
└── Primary Contact
    └── Account
        ...
```

`PREVENT_CASCADE` allows the first Provider to generate its immediate relationships, but instructs every subsequently invoked Provider to behave as though relationship generation were `NONE`.

The resulting graph becomes:

```text
Account
└── Primary Contact
```

rather than continuing recursively.

Although this also reduces the size of generated object graphs, preventing recursive relationship generation is its primary purpose.

---

# Recommended Defaults

Most tests should begin with:

```apex
new XFTY_DummySObjectProvider(Contact.SObjectType, providerLookup)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
```

This combination:

- avoids DML
- generates realistic Ids
- creates required related records
- keeps generated object graphs compact

For many projects, this represents an ideal balance between isolation and convenience.

---

# Unit Tests vs Integration Tests

One of XFTY's design goals is to support both unit tests and integration tests without changing how test data is described.

A unit test might use:

```apex
.setInsertMode(MOCK)
.setInclusivity(REQUIRED)
```

while an integration test changes only the Insert Mode:

```apex
.setInsertMode(NOW)
.setInclusivity(REQUIRED)
```

The same Provider definitions can therefore support both styles of testing.

---

# Why Separate These Concepts?

Many test data libraries combine relationship generation and persistence into a single operation.

XFTY deliberately separates them.

This allows a test to answer two independent questions:

- How much data should exist?
- How much of that data should actually be inserted?

Keeping these concerns independent makes the framework considerably more flexible while keeping Provider implementations simple.

---

# Best Practices

- Prefer `MOCK` for unit tests.
- Prefer `NOW` only when database interaction is genuinely required.
- Use `REQUIRED` as the default relationship inclusivity.
- Reserve `ALL` for tests that need richer object graphs.
- Use `PREVENT_CASCADE` when working with recursive or circular relationships.
- Prefer the smallest generated object graph that satisfies the needs of the test.

---

# Next Steps

The remaining guides focus on the framework itself rather than everyday usage.

- **Limitations** explains Salesforce platform behaviors that affect XFTY, including the important interaction with `@TestSetup`.
- **Internals** explores the architectural decisions and implementation details behind the framework for developers interested in extending or contributing to XFTY.