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
| `DEFERRED` | Generate like `NEVER`, but register every record so `XFTY_DeferredInserter.flush()` can insert the whole set - across many `supplyBundle()` calls - in one depth-batched pass. |

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

For a `LATER`-style flow where XFTY should do the eventual insert, use `DEFERRED`.

---

# DEFERRED

```apex
XFTY_DummySObjectBundle accounts = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(3)
        .supplyBundle();

XFTY_DummySObjectBundle contacts = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .supplyBundle();

XFTY_DeferredInserter.flush();   // every graph from every DEFERRED call, inserted now
```

`DEFERRED` generates exactly like `NEVER` - no Ids, no DML - but registers every
record. `XFTY_DeferredInserter.flush()` then inserts everything registered so far,
**depth-batched** (one `insert` per dependency depth, across all the graphs), and
because the records handed back are the same instances, their `Id` fields are now
populated.

Use it when a test - or a chain of setup helpers - builds its data in several
`supplyBundle()` calls and wants a single insert phase at the end.

- A test that never calls `flush()` gets `NEVER` semantics - no surprise DML.
- Records inserted by a `NOW` call in between are not in the registry and are
  left untouched; a `DEFERRED` record pointing at one keeps that Id.
- `flush()` clears the registry - generation after a `flush()` starts fresh.
- Not supported with `@TestSetup` (it resets statics) or shared ancestors
  (refused during generation).

**`DEFERRED` does not give you a parent's Id mid-generation.** If a later
`supplyBundle()` call needs the real Id of a record an earlier call produced -
to pass in a template, or to drive record-type selection - `flush()` the earlier
call first, then generate the later one:

```apex
XFTY_DummySObjectBundle parents = parentProvider.setInsertMode(DEFERRED).supplyBundle();
XFTY_DeferredInserter.flush();                                    // parents now have Ids

Id parentId = parents.getList(Account.Id)[0].Id;
childProvider.setOverrideTemplate(new Contact(AccountId = parentId))
        .setInsertMode(DEFERRED).supplyBundle();
XFTY_DeferredInserter.flush();
```

Within a single `flush()` group, XFTY only wires lookups it generated itself -
it does not reorder your intent.

---

# Choosing an Insert Mode

Most tests naturally fall into one of these categories.

| Scenario | Recommended Mode |
|-----------|------------------|
| Pure unit test | `MOCK` |
| Testing object construction | `NEVER` |
| Test inserts records itself | `LATER` |
| Data built over several calls, one insert phase | `DEFERRED` |
| Need inserted lookup targets only | `RELATED_ONLY` |
| Integration test | `NOW` |

When in doubt, prefer the least amount of database interaction necessary.

---

# Depth-Batched Persistence (`.depthBatched()`)

By default, `NOW` runs one `insert` per Provider in the graph: a `Task` with an
`Account` parent and a `Contact` parent costs three (`Account`, `Contact`,
`Task`). For a wide graph that adds up.

`.depthBatched()` on the Provider collapses that to **one `insert` per dependency
depth**, regardless of how many types sit at each depth - the `Task` example
drops to two, and a record with five parents of five types drops from six to two:

```apex
new XFTY_DummySObjectProvider(Task.SObjectType, lookup)
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .setInsertMode(XFTY_InsertModeEnum.NOW)
        .depthBatched()
        .supplyBundle();
```

The generated records are identical; only the number and **order** of `insert`
statements changes. It is opt-in for exactly that reason - a test that asserts an
exact DML count, or depends on the order its triggers fire during generation,
should leave it off.

- Only affects `NOW`. The other modes do no framework DML, so it is a no-op.
- Not supported with shared ancestors yet - a depth-batched call that references
  an `XFTY_SharedAncestor` throws a clear error.
- A lookup cycle (record A points at B, B points at A) cannot be one `insert`
  order and throws `XFTY_DepthBatchedInserter.CyclicGraphException`.

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